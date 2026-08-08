local yieldStates = {}
local cooldowns = {}
local emergencyModelHashes = {}
local forcedActive = false

local debugStats = {
    pool = 0,
    valid = 0,
    relevant = 0,
    controlFail = 0,
    assigned = 0,
    emergencyVehicle = 0,
    emergencyClass = -1,
    sirenOn = false,
    audioOn = false,
}

local function cacheEmergencyModels()
    emergencyModelHashes = {}
    for _, modelName in ipairs(Config.AdditionalEmergencyVehicles) do
        emergencyModelHashes[GetHashKey(modelName)] = true
    end
end

local function isEmergencyVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if GetVehicleClass(vehicle) == 18 then return true end
    return emergencyModelHashes[GetEntityModel(vehicle)] == true
end

local function getSirenStates(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, false
    end
    return IsVehicleSirenOn(vehicle), IsVehicleSirenAudioOn(vehicle)
end

local function isEmergencySystemActive(vehicle)
    if forcedActive then return true end

    local warningState, audioState = getSirenStates(vehicle)

    if Config.ActivationMode == 'lights' then
        return warningState
    elseif Config.ActivationMode == 'either' then
        return warningState or audioState
    end

    return warningState and audioState
end

local function getPlayerVehicleRegardlessOfActivation()
    local ped = PlayerPedId()
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then return 0 end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return 0 end
    return vehicle
end

local function getPlayerEmergencyVehicle()
    if not Config.Enabled then return 0 end

    local vehicle = getPlayerVehicleRegardlessOfActivation()
    if vehicle == 0 then return 0 end

    if Config.RequireEmergencyVehicle and not isEmergencyVehicle(vehicle) then
        return 0
    end

    if not isEmergencySystemActive(vehicle) then
        return 0
    end

    return vehicle
end

local function isValidAIVehicle(vehicle, emergencyVehicle)
    if vehicle == 0 or vehicle == emergencyVehicle or not DoesEntityExist(vehicle) then
        return false
    end

    local class = GetVehicleClass(vehicle)
    if Config.ExcludedVehicleClasses[class] then return false end

    if Config.IgnoreMissionEntities and IsEntityAMissionEntity(vehicle) then
        return false
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or not DoesEntityExist(driver) then return false end
    if IsPedAPlayer(driver) or IsPedDeadOrDying(driver, true) then return false end

    if Config.IgnoreMissionEntities and IsEntityAMissionEntity(driver) then
        return false
    end

    if Config.IgnoreActiveEmergencyAI
        and class == 18
        and (IsVehicleSirenOn(vehicle) or IsVehicleSirenAudioOn(vehicle)) then
        return false
    end

    return true, driver
end

local function isRelevantToEmergency(vehicle, emergencyVehicle, profile)
    local emergencyCoords = GetEntityCoords(emergencyVehicle)
    local vehicleCoords = GetEntityCoords(vehicle)

    if math.abs(vehicleCoords.z - emergencyCoords.z) > Config.VerticalTolerance then
        return false
    end

    local distance = ClearPath.Distance(vehicleCoords, emergencyCoords)
    if distance > profile.detectionDistance then return false end

    local relative = GetOffsetFromEntityGivenWorldCoords(
        emergencyVehicle,
        vehicleCoords.x,
        vehicleCoords.y,
        vehicleCoords.z
    )

    if relative.y < -Config.BehindAllowance then return false end

    local forwardDistance = math.max(relative.y, 0.0)
    local corridorWidth = Config.CorridorBaseWidth + (forwardDistance * Config.CorridorGrowth)
    corridorWidth = ClearPath.Clamp(corridorWidth, Config.CorridorBaseWidth, Config.CorridorMaxWidth)

    if math.abs(relative.x) > corridorWidth then return false end

    return true, distance, relative
end

local function restoreAmbientDriver(driver, vehicle)
    SetVehicleIndicatorLights(vehicle, 1, false)
    SetBlockingOfNonTemporaryEvents(driver, false)
    SetPedKeepTask(driver, false)
    SetDriveTaskCruiseSpeed(driver, Config.RejoinSpeed)
    SetDriveTaskMaxCruiseSpeed(driver, Config.RejoinSpeed)
    SetDriveTaskDrivingStyle(driver, Config.DrivingStyle)
    TaskVehicleDriveWander(driver, vehicle, Config.RejoinSpeed, Config.DrivingStyle)
end

local function releaseVehicle(vehicle, reason)
    local state = yieldStates[vehicle]
    if not state then return end

    if DoesEntityExist(vehicle) then
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
            if ClearPath.TryControl(vehicle) and ClearPath.TryControl(driver) then
                restoreAmbientDriver(driver, vehicle)
            end
        end
    end

    cooldowns[vehicle] = GetGameTimer() + Config.ReleaseCooldownMs
    yieldStates[vehicle] = nil
    ClearPath.Debug(('released vehicle %s (%s)'):format(vehicle, reason or 'unknown'))
end

local function releaseAll(reason)
    local vehicles = {}
    for vehicle in pairs(yieldStates) do vehicles[#vehicles + 1] = vehicle end
    for _, vehicle in ipairs(vehicles) do releaseVehicle(vehicle, reason) end
end

local function applyYieldTask(vehicle, driver, state, requestedSpeed)
    SetVehicleIndicatorLights(vehicle, 1, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedKeepTask(driver, true)
    SetDriveTaskDrivingStyle(driver, Config.DrivingStyle)

    local taskSpeed = requestedSpeed or state.profile.yieldSpeed
    SetDriveTaskCruiseSpeed(driver, taskSpeed)
    SetDriveTaskMaxCruiseSpeed(driver, taskSpeed)

    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        state.target.x,
        state.target.y,
        state.target.z,
        taskSpeed,
        Config.DrivingStyle,
        Config.HoldDistance
    )

    state.lastTaskAt = GetGameTimer()
end

local function assignYield(vehicle, driver, emergencyVehicle, profile)
    local now = GetGameTimer()
    local cooldownUntil = cooldowns[vehicle]
    if cooldownUntil and cooldownUntil > now then return end

    if yieldStates[vehicle] then
        yieldStates[vehicle].lastRelevantAt = now
        return
    end

    local controlVehicle = ClearPath.TryControl(vehicle)
    local controlDriver = ClearPath.TryControl(driver)
    if not controlVehicle or not controlDriver then
        debugStats.controlFail = debugStats.controlFail + 1
        return
    end

    local target, targetHeading = ClearPath.BuildYieldTarget(vehicle, profile)
    if not target then return end

    local state = {
        driver = driver,
        emergencyVehicle = emergencyVehicle,
        profile = profile,
        target = target,
        targetHeading = targetHeading,
        state = 'YIELDING',
        assignedAt = now,
        lastRelevantAt = now,
        lastTaskAt = 0,
        lastParkRefreshAt = 0,
        passedAt = nil,
    }

    yieldStates[vehicle] = state
    applyYieldTask(vehicle, driver, state)
    debugStats.assigned = debugStats.assigned + 1
    ClearPath.Debug(('assigned %s vehicle %s'):format(profile.kind, vehicle))
end

local function scanTraffic(emergencyVehicle)
    local pool = GetGamePool('CVehicle')

    debugStats.pool = #pool
    debugStats.valid = 0
    debugStats.relevant = 0
    debugStats.controlFail = 0
    debugStats.assigned = 0

    for i = 1, #pool do
        local vehicle = pool[i]
        local valid, driver = isValidAIVehicle(vehicle, emergencyVehicle)

        if valid then
            debugStats.valid = debugStats.valid + 1
            local profile = ClearPath.GetVehicleProfile(vehicle)
            local relevant = isRelevantToEmergency(vehicle, emergencyVehicle, profile)

            if relevant then
                debugStats.relevant = debugStats.relevant + 1
                assignYield(vehicle, driver, emergencyVehicle, profile)
            end
        end
    end
end

local function updateYieldState(vehicle, state, activeEmergencyVehicle)
    if not DoesEntityExist(vehicle) then
        yieldStates[vehicle] = nil
        cooldowns[vehicle] = nil
        return
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or driver ~= state.driver or not DoesEntityExist(driver) or IsPedAPlayer(driver) then
        yieldStates[vehicle] = nil
        return
    end

    if activeEmergencyVehicle == 0 or state.emergencyVehicle ~= activeEmergencyVehicle then
        releaseVehicle(vehicle, 'emergency inactive/changed')
        return
    end

    local now = GetGameTimer()
    if now - state.assignedAt > Config.FailsafeReleaseMs then
        releaseVehicle(vehicle, 'failsafe timeout')
        return
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    local emergencyCoords = GetEntityCoords(activeEmergencyVehicle)
    local relative = GetOffsetFromEntityGivenWorldCoords(
        activeEmergencyVehicle,
        vehicleCoords.x,
        vehicleCoords.y,
        vehicleCoords.z
    )

    -- Do not release a yielding vehicle merely because the responder has just
    -- moved alongside or slightly ahead of it. Start a pass-confirmation timer once
    -- the AI is clearly behind, then require both longitudinal clearance and a
    -- profile-specific hold time before allowing it to rejoin traffic.
    if relative.y <= -Config.PassDetectionBehindDistance then
        if not state.passedAt then
            state.passedAt = now
        end
    elseif relative.y > 0.0 then
        -- The responder dropped back behind the AI again; cancel the pending release.
        state.passedAt = nil
    end

    if state.passedAt
        and relative.y <= -state.profile.releaseBehindDistance
        and (now - state.passedAt) >= state.profile.postPassHoldMs then
        releaseVehicle(vehicle, 'emergency fully clear')
        return
    end

    local distanceFromEmergency = ClearPath.Distance(vehicleCoords, emergencyCoords)
    -- If the emergency vehicle has diverted away while the AI is still ahead, release
    -- normally. When the AI is behind the responder, the stricter pass-clearance rules
    -- above take precedence so it cannot merge back too early.
    if relative.y >= 0.0 and distanceFromEmergency > (state.profile.detectionDistance + 75.0) then
        releaseVehicle(vehicle, 'out of range')
        return
    end

    if not ClearPath.TryControl(vehicle) or not ClearPath.TryControl(driver) then return end

    if state.state == 'YIELDING' then
        local distanceToTarget = ClearPath.Distance(vehicleCoords, state.target)
        local elapsed = now - state.assignedAt

        -- Reassert periodically. As the AI gets close to the shoulder target,
        -- reduce speed so it completes the lateral move instead of braking early.
        if now - state.lastTaskAt >= Config.YieldTaskRefreshMs then
            local taskSpeed = state.profile.yieldSpeed
            if distanceToTarget <= Config.FinalApproachDistance then
                taskSpeed = state.profile.finalYieldSpeed
            end
            applyYieldTask(vehicle, driver, state, taskSpeed)
        end

        -- Only switch to HOLDING once the vehicle centre is actually close to the
        -- shoulder target. v0.1.2 used 9 m here, which was enough for a car to stop
        -- while still occupying part of the live lane.
        if distanceToTarget <= Config.HoldDistance and elapsed >= Config.MinimumYieldTimeMs then
            TaskVehiclePark(
                driver,
                vehicle,
                state.target.x,
                state.target.y,
                state.target.z,
                state.targetHeading,
                Config.ParkMode,
                Config.ParkRadius,
                true
            )
            state.state = 'HOLDING'
            state.lastParkRefreshAt = now
        end
    elseif state.state == 'HOLDING' then
        local distanceToTarget = ClearPath.Distance(vehicleCoords, state.target)

        -- Ambient AI can occasionally creep back toward the lane even while held.
        -- If it drifts too far from the shoulder target, put it back into the final
        -- approach phase and make it finish pulling over again.
        if distanceToTarget > Config.HoldDriftTolerance then
            state.state = 'YIELDING'
            applyYieldTask(vehicle, driver, state, state.profile.finalYieldSpeed)
            return
        end

        if now - state.lastParkRefreshAt >= Config.HoldRefreshMs then
            TaskVehiclePark(
                driver,
                vehicle,
                state.target.x,
                state.target.y,
                state.target.z,
                state.targetHeading,
                Config.ParkMode,
                Config.ParkRadius,
                true
            )
            state.lastParkRefreshAt = now
        end
    end
end

local function countYieldStates()
    local count = 0
    for _ in pairs(yieldStates) do count = count + 1 end
    return count
end

local function updateDebugVehicleStatus()
    local vehicle = getPlayerVehicleRegardlessOfActivation()
    debugStats.emergencyVehicle = vehicle
    debugStats.emergencyClass = vehicle ~= 0 and GetVehicleClass(vehicle) or -1
    debugStats.sirenOn, debugStats.audioOn = getSirenStates(vehicle)
end

CreateThread(function()
    cacheEmergencyModels()

    if Config.UseNativeSirenReactionOverride and type(OverrideReactionToVehicleSiren) == 'function' then
        OverrideReactionToVehicleSiren(true, Config.NativeSirenReaction)
    end

    while true do
        updateDebugVehicleStatus()
        local emergencyVehicle = getPlayerEmergencyVehicle()

        if emergencyVehicle ~= 0 then
            scanTraffic(emergencyVehicle)
            Wait(Config.ScanIntervalMs)
        else
            if next(yieldStates) ~= nil then releaseAll('siren inactive') end
            Wait(Config.IdleScanIntervalMs)
        end
    end
end)

CreateThread(function()
    while true do
        if next(yieldStates) == nil then
            Wait(Config.IdleScanIntervalMs)
        else
            local activeEmergencyVehicle = getPlayerEmergencyVehicle()
            local vehicles = {}
            for vehicle in pairs(yieldStates) do vehicles[#vehicles + 1] = vehicle end

            for _, vehicle in ipairs(vehicles) do
                local state = yieldStates[vehicle]
                if state then updateYieldState(vehicle, state, activeEmergencyVehicle) end
            end

            Wait(Config.StateUpdateIntervalMs)
        end
    end
end)

CreateThread(function()
    while true do
        if not Config.Debug then
            Wait(400)
        else
            updateDebugVehicleStatus()
            ClearPath.DrawText(0.015, 0.030, 'ClearPath AI v0.1.3 DEBUG', 0.34)
            ClearPath.DrawText(0.015, 0.052, ('Vehicle: %s  class: %s  emergency: %s'):format(
                debugStats.emergencyVehicle,
                debugStats.emergencyClass,
                tostring(debugStats.emergencyVehicle ~= 0 and isEmergencyVehicle(debugStats.emergencyVehicle) or false)
            ), 0.30)
            ClearPath.DrawText(0.015, 0.072, ('lights/siren state: %s  audio: %s  forced: %s  mode: %s'):format(
                tostring(debugStats.sirenOn), tostring(debugStats.audioOn), tostring(forcedActive), Config.ActivationMode
            ), 0.30)
            ClearPath.DrawText(0.015, 0.092, ('pool: %d  valid AI: %d  relevant: %d  yielding: %d  control failures: %d'):format(
                debugStats.pool, debugStats.valid, debugStats.relevant, countYieldStates(), debugStats.controlFail
            ), 0.30)

            for vehicle, state in pairs(yieldStates) do
                if DoesEntityExist(vehicle) then
                    local vc = GetEntityCoords(vehicle)
                    DrawLine(vc.x, vc.y, vc.z + 1.0, state.target.x, state.target.y, state.target.z + 0.5, 255, 255, 255, 180)
                    DrawMarker(1, state.target.x, state.target.y, state.target.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.5, 255, 255, 255, 130, false, false, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
    end
end)

local function toggleDebug()
    Config.Debug = not Config.Debug
    print(('[clearpath_ai] Debug %s'):format(Config.Debug and 'ENABLED' or 'DISABLED'))
end

RegisterCommand(Config.DebugCommand, toggleDebug, false)
RegisterCommand(Config.LegacyDebugCommand, toggleDebug, false)

RegisterCommand(Config.ForceCommand, function()
    forcedActive = not forcedActive
    print(('[clearpath_ai] Forced activation %s'):format(forcedActive and 'ENABLED' or 'DISABLED'))
end, false)

RegisterCommand(Config.StatusCommand, function()
    updateDebugVehicleStatus()
    local vehicle = debugStats.emergencyVehicle
    print(('[clearpath_ai] status vehicle=%s class=%s emergency=%s warning=%s audio=%s forced=%s active=%s yielding=%d'):format(
        vehicle,
        debugStats.emergencyClass,
        tostring(vehicle ~= 0 and isEmergencyVehicle(vehicle) or false),
        tostring(debugStats.sirenOn),
        tostring(debugStats.audioOn),
        tostring(forcedActive),
        tostring(getPlayerEmergencyVehicle() ~= 0),
        countYieldStates()
    ))
end, false)

exports('SetForcedActive', function(active)
    forcedActive = active == true
end)

exports('IsForcedActive', function()
    return forcedActive
end)

RegisterNetEvent('clearpath_ai:setForcedActive', function(active)
    forcedActive = active == true
end)

-- Compatibility with the original v0.1.0 event name.
RegisterNetEvent('smart_emergency_traffic:setForcedActive', function(active)
    forcedActive = active == true
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    releaseAll('resource stop')

    if Config.UseNativeSirenReactionOverride and type(OverrideReactionToVehicleSiren) == 'function' then
        OverrideReactionToVehicleSiren(false, Config.NativeSirenReaction)
    end
end)
