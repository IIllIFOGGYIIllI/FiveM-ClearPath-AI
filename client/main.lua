local yieldStates = {}
local cooldowns = {}
local emergencyModelHashes = {}
local forcedActive = false
local protectedNetIds = {}
local localProtectedEntities = {}
local nativeOverrideApplied = false
local RESOURCE_VERSION = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown'


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
    nightERS = false,
    protected = 0,
}


local function getNightERSConfig()
    return Config.Compatibility and Config.Compatibility.NightERS or nil
end

local function isNightERSRunning()
    local compat = getNightERSConfig()
    if not compat or compat.Enabled ~= true then return false end
    return GetResourceState(compat.ResourceName or 'night_ers') == 'started'
end

local function cleanupProtectedNetIds()
    local now = GetGameTimer()
    for netId, expiresAt in pairs(protectedNetIds) do
        if expiresAt ~= 0 and expiresAt <= now then
            protectedNetIds[netId] = nil
        end
    end
end

local function setNetIdProtected(netId, protected, durationMs)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return false end

    if protected then
        local duration = tonumber(durationMs) or 0
        protectedNetIds[netId] = duration > 0 and (GetGameTimer() + duration) or 0
    else
        protectedNetIds[netId] = nil
    end
    return true
end

local function setEntityProtected(entity, protected, durationMs)
    if entity == 0 or not DoesEntityExist(entity) then return false end

    if protected then
        local duration = tonumber(durationMs) or 0
        localProtectedEntities[entity] = duration > 0 and (GetGameTimer() + duration) or 0
    else
        localProtectedEntities[entity] = nil
    end

    if NetworkGetEntityIsNetworked(entity) then
        setNetIdProtected(NetworkGetNetworkIdFromEntity(entity), protected, durationMs)
    end
    return true
end

local function isLocallyProtected(entity)
    local expiresAt = localProtectedEntities[entity]
    if expiresAt == nil then return false end
    if expiresAt ~= 0 and expiresAt <= GetGameTimer() then
        localProtectedEntities[entity] = nil
        return false
    end
    return true
end

local function isNetEntityProtected(entity)
    if entity == 0 or not DoesEntityExist(entity) or not NetworkGetEntityIsNetworked(entity) then
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local expiresAt = protectedNetIds[netId]
    if expiresAt == nil then return false end
    if expiresAt ~= 0 and expiresAt <= GetGameTimer() then
        protectedNetIds[netId] = nil
        return false
    end
    return true
end

local function isNightERSScriptedEntity(vehicle, driver)
    if not isNightERSRunning() then return false end

    local compat = getNightERSConfig()
    if not compat then return false end

    if compat.ProtectMissionEntities
        and (IsEntityAMissionEntity(vehicle) or IsEntityAMissionEntity(driver)) then
        return true
    end

    if compat.ProtectFleeingDrivers and IsPedFleeing(driver) then
        return true
    end

    if compat.ProtectCombatDrivers and IsPedInCombat(driver, PlayerPedId()) then
        return true
    end

    return false
end

local function isProtectedFromClearPath(vehicle, driver)
    if isLocallyProtected(vehicle) or isLocallyProtected(driver) then return true end
    if isNetEntityProtected(vehicle) or isNetEntityProtected(driver) then return true end
    return isNightERSScriptedEntity(vehicle, driver)
end

local function countProtectedNetIds()
    cleanupProtectedNetIds()
    local count = 0
    for _ in pairs(protectedNetIds) do count = count + 1 end
    return count
end

local function updateNativeSirenOverride()
    if not Config.UseNativeSirenReactionOverride or type(OverrideReactionToVehicleSiren) ~= 'function' then
        if nativeOverrideApplied and type(OverrideReactionToVehicleSiren) == 'function' then
            OverrideReactionToVehicleSiren(false, Config.NativeSirenReaction)
            nativeOverrideApplied = false
        end
        return
    end

    local compat = getNightERSConfig()
    local shouldApply = true
    if compat and compat.Enabled and compat.DisableGlobalSirenOverride and isNightERSRunning() then
        shouldApply = false
    end

    if shouldApply ~= nativeOverrideApplied then
        OverrideReactionToVehicleSiren(shouldApply, Config.NativeSirenReaction)
        nativeOverrideApplied = shouldApply
        ClearPath.Debug(('global siren override %s'):format(shouldApply and 'enabled' or 'disabled for compatibility'))
    end
end

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

    -- Protect vehicles currently controlled by ERS (pursuits, traffic stops, callouts,
    -- backup) or explicitly protected by another resource. ClearPath must never replace
    -- their AI driving tasks.
    if isProtectedFromClearPath(vehicle, driver) then
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

    if math.abs(relative.x) > corridorWidth then
        -- Cross-traffic approaching the same junction can sit outside the normal
        -- forward corridor until very late. Treat a valid projected junction
        -- conflict as relevant early so it can stop before entering the crossing.
        if not ClearPath.BuildJunctionPlan(vehicle, emergencyVehicle) then
            return false
        end
    end

    return true, distance, relative
end

local function restoreAmbientDriver(driver, vehicle)
    SetVehicleIndicatorLights(vehicle, 0, false)
    SetVehicleIndicatorLights(vehicle, 1, false)
    SetBlockingOfNonTemporaryEvents(driver, false)
    SetPedKeepTask(driver, false)
    SetDriveTaskCruiseSpeed(driver, Config.RejoinSpeed)
    SetDriveTaskMaxCruiseSpeed(driver, Config.RejoinSpeed)
    SetDriveTaskDrivingStyle(driver, Config.DrivingStyle)
    TaskVehicleDriveWander(driver, vehicle, Config.RejoinSpeed, Config.DrivingStyle)
end

local function releaseVehicle(vehicle, reason, skipAmbientRestore)
    local state = yieldStates[vehicle]
    if not state then return end

    if DoesEntityExist(vehicle) then
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if not skipAmbientRestore and driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
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
    for _, vehicle in ipairs(vehicles) do
        local skipAmbientRestore = false
        if DoesEntityExist(vehicle) then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
                skipAmbientRestore = isProtectedFromClearPath(vehicle, driver)
            end
        end
        releaseVehicle(vehicle, reason, skipAmbientRestore)
    end
end

local function applyYieldTask(vehicle, driver, state, requestedSpeed)
    if state.junctionMode then
        -- Cross-traffic should keep a predictable heading through/at the junction,
        -- not signal and attempt a roadside manoeuvre while occupying the conflict area.
        SetVehicleIndicatorLights(vehicle, 0, false)
        SetVehicleIndicatorLights(vehicle, 1, false)
    else
        SetVehicleIndicatorLights(vehicle, 1, true)
    end
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

    local junctionPlan = ClearPath.BuildJunctionPlan(vehicle, emergencyVehicle)
    local target, targetHeading

    if junctionPlan then
        target = junctionPlan.target
        targetHeading = junctionPlan.targetHeading
    else
        target, targetHeading = ClearPath.BuildYieldTarget(vehicle, profile)
    end

    if not target then return end

    local initialState = 'YIELDING'
    if junctionPlan then
        initialState = junctionPlan.mode == 'clear' and 'JUNCTION_CLEARING' or 'JUNCTION_WAIT_APPROACH'
    end

    local state = {
        driver = driver,
        emergencyVehicle = emergencyVehicle,
        profile = profile,
        target = target,
        targetHeading = targetHeading,
        state = initialState,
        junctionMode = junctionPlan and junctionPlan.mode or nil,
        conflictPoint = junctionPlan and junctionPlan.conflictPoint or nil,
        vehicleHeading = junctionPlan and junctionPlan.vehicleHeading or nil,
        emergencyHeading = junctionPlan and junctionPlan.emergencyHeading or nil,
        assignedAt = now,
        lastRelevantAt = now,
        lastTaskAt = 0,
        lastParkRefreshAt = 0,
        passedAt = nil,
    }

    yieldStates[vehicle] = state

    local initialSpeed = nil
    if state.state == 'JUNCTION_CLEARING' then
        initialSpeed = Config.JunctionClearSpeed
    elseif state.state == 'JUNCTION_WAIT_APPROACH' then
        initialSpeed = Config.JunctionWaitApproachSpeed
    end

    applyYieldTask(vehicle, driver, state, initialSpeed)
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

    -- If ERS (or another resource) takes ownership of this NPC after ClearPath already
    -- started yielding it, immediately stop issuing ClearPath tasks and return control.
    if isProtectedFromClearPath(vehicle, driver) then
        releaseVehicle(vehicle, 'protected/scripted entity', true)
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

    -- Junction cross-traffic uses its own conflict-point state machine. A vehicle
    -- that has room waits before the crossing; one that is already committed keeps
    -- moving until it is fully beyond the emergency vehicle's projected path.
    -- This prevents the classic GTA behaviour where traffic stops broadside in the
    -- middle of the junction when a siren approaches.
    if state.junctionMode and state.conflictPoint then
        if not ClearPath.TryControl(vehicle) or not ClearPath.TryControl(driver) then return end

        local vehicleProgress = ClearPath.GetForwardProgressFromPoint(
            vehicle, state.conflictPoint, state.vehicleHeading
        )
        local emergencyProgress = ClearPath.GetForwardProgressFromPoint(
            activeEmergencyVehicle, state.conflictPoint, state.emergencyHeading
        )

        if state.state == 'JUNCTION_CLEARING' then
            if vehicleProgress >= Config.JunctionClearReleaseDistance then
                releaseVehicle(vehicle, 'junction cleared')
                return
            end

            if now - state.lastTaskAt >= Config.JunctionTaskRefreshMs then
                applyYieldTask(vehicle, driver, state, Config.JunctionClearSpeed)
            end
            return
        end

        if state.state == 'JUNCTION_WAIT_APPROACH' or state.state == 'JUNCTION_WAIT_HOLD' then
            -- If the vehicle failed to stop in time and becomes committed, never make
            -- it brake in the conflict zone. Convert immediately to a clear-through
            -- task and get it out of the responder's path.
            if vehicleProgress >= -Config.JunctionCommittedDistance then
                local forward = ClearPath.ForwardFromHeading(state.vehicleHeading)
                state.target = vector3(
                    state.conflictPoint.x + (forward.x * Config.JunctionClearBeyondConflictDistance),
                    state.conflictPoint.y + (forward.y * Config.JunctionClearBeyondConflictDistance),
                    vehicleCoords.z
                )
                state.state = 'JUNCTION_CLEARING'
                state.junctionMode = 'clear'
                applyYieldTask(vehicle, driver, state, Config.JunctionClearSpeed)
                return
            end

            -- Once the responder is safely through the crossing, normal ambient AI
            -- can resume. Until then the cross-traffic vehicle remains behind the
            -- conflict point even if GTA's traffic-light logic wants it to proceed.
            if emergencyProgress >= Config.JunctionEmergencyClearDistance then
                releaseVehicle(vehicle, 'responder cleared junction')
                return
            end

            local distanceToTarget = ClearPath.Distance(vehicleCoords, state.target)
            local elapsed = now - state.assignedAt

            if state.state == 'JUNCTION_WAIT_APPROACH' then
                if now - state.lastTaskAt >= Config.JunctionTaskRefreshMs then
                    applyYieldTask(vehicle, driver, state, Config.JunctionWaitApproachSpeed)
                end

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
                    state.state = 'JUNCTION_WAIT_HOLD'
                    state.lastParkRefreshAt = now
                end
            elseif now - state.lastParkRefreshAt >= Config.HoldRefreshMs then
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

            return
        end
    end

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

    updateNativeSirenOverride()

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
        updateNativeSirenOverride()
        cleanupProtectedNetIds()
        debugStats.nightERS = isNightERSRunning()
        debugStats.protected = countProtectedNetIds()
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        if not Config.Debug then
            Wait(400)
        else
            updateDebugVehicleStatus()
            ClearPath.DrawText(0.015, 0.030, ('ClearPath AI v%s DEBUG'):format(RESOURCE_VERSION), 0.34)
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
            ClearPath.DrawText(0.015, 0.112, ('Night ERS: %s  protected net IDs: %d  global siren override: %s'):format(
                tostring(isNightERSRunning()), countProtectedNetIds(), tostring(nativeOverrideApplied)
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

-- Generic compatibility API. Other resources can protect a scripted vehicle/ped
-- from ClearPath without adding a hard dependency.
exports('SetEntityProtected', function(entity, protected, durationMs)
    return setEntityProtected(entity, protected == true, durationMs)
end)

exports('SetNetIdProtected', function(netId, protected, durationMs)
    return setNetIdProtected(netId, protected == true, durationMs)
end)

exports('IsEntityProtected', function(entity)
    if entity == 0 or not DoesEntityExist(entity) then return false end
    local driver = IsEntityAVehicle(entity) and GetPedInVehicleSeat(entity, -1) or entity
    return isProtectedFromClearPath(entity, driver)
end)

RegisterNetEvent('clearpath_ai:setProtectedNetId', function(netId, protected, durationMs)
    setNetIdProtected(netId, protected == true, durationMs)
end)

-- Night ERS integration: the server relays the documented pursuit lifecycle event.
-- Protecting the suspect PED is enough; ClearPath checks both the driver and vehicle.
RegisterNetEvent('clearpath_ai:ersPursuitPed', function(pedNetId, protected)
    setNetIdProtected(pedNetId, protected == true, 0)

    if pedNetId and NetworkDoesEntityExistWithNetworkId(pedNetId) then
        local ped = NetworkGetEntityFromNetworkId(pedNetId)
        if ped ~= 0 and DoesEntityExist(ped) then
            setEntityProtected(ped, protected == true, 0)
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle ~= 0 then setEntityProtected(vehicle, protected == true, 0) end
            end
        end
    end
end)

RegisterNetEvent('clearpath_ai:protectedSnapshot', function(netIds)
    if type(netIds) ~= 'table' then return end
    for _, netId in ipairs(netIds) do
        setNetIdProtected(netId, true, 0)
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('clearpath_ai:requestProtectedSnapshot')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    releaseAll('resource stop')

    if nativeOverrideApplied and type(OverrideReactionToVehicleSiren) == 'function' then
        OverrideReactionToVehicleSiren(false, Config.NativeSirenReaction)
        nativeOverrideApplied = false
    end
end)
