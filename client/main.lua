local yieldStates = {}
local cooldowns = {}
local emergencyModelHashes = {}
local forcedActive = false
local lastEmergencyVehicle = 0

local function cacheEmergencyModels()
    emergencyModelHashes = {}
    for _, modelName in ipairs(Config.AdditionalEmergencyVehicles) do
        emergencyModelHashes[GetHashKey(modelName)] = true
    end
end

local function isEmergencyVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    if GetVehicleClass(vehicle) == 18 then
        return true
    end

    return emergencyModelHashes[GetEntityModel(vehicle)] == true
end

local function isEmergencySystemActive(vehicle)
    if forcedActive then
        return true
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local warningState = IsVehicleSirenOn(vehicle)
    local audioState = IsVehicleSirenAudioOn(vehicle)

    if Config.ActivationMode == 'lights' then
        return warningState
    elseif Config.ActivationMode == 'either' then
        return warningState or audioState
    end

    -- Default: require an actual audible siren response.
    return warningState and audioState
end

local function getPlayerEmergencyVehicle()
    if not Config.Enabled then
        return 0
    end

    local ped = PlayerPedId()
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then
        return 0
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return 0
    end

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

    local vehicleClass = GetVehicleClass(vehicle)
    if Config.ExcludedVehicleClasses[vehicleClass] then
        return false
    end

    if Config.IgnoreMissionEntities and IsEntityAMissionEntity(vehicle) then
        return false
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or not DoesEntityExist(driver) then
        return false
    end

    if IsPedAPlayer(driver) or IsPedDeadOrDying(driver, true) then
        return false
    end

    if Config.IgnoreMissionEntities and IsEntityAMissionEntity(driver) then
        return false
    end

    if Config.IgnoreActiveEmergencyAI
        and vehicleClass == 18
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

    local distance = SETraffic.Distance(vehicleCoords, emergencyCoords)
    if distance > profile.detectionDistance then
        return false
    end

    local relative = GetOffsetFromEntityGivenWorldCoords(
        emergencyVehicle,
        vehicleCoords.x,
        vehicleCoords.y,
        vehicleCoords.z
    )

    if relative.y < -Config.BehindAllowance then
        return false
    end

    local forwardDistance = math.max(relative.y, 0.0)
    local corridorWidth = Config.CorridorBaseWidth + (forwardDistance * Config.CorridorGrowth)
    corridorWidth = SETraffic.Clamp(corridorWidth, Config.CorridorBaseWidth, Config.CorridorMaxWidth)

    if math.abs(relative.x) > corridorWidth then
        return false
    end

    return true, distance, relative
end

local function releaseVehicle(vehicle, reason)
    local state = yieldStates[vehicle]
    if not state then
        return
    end

    if DoesEntityExist(vehicle) then
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) then
            if SETraffic.TryControl(vehicle) and SETraffic.TryControl(driver) then
                SetVehicleIndicatorLights(vehicle, 1, false)
                SetDriveTaskCruiseSpeed(driver, Config.RejoinSpeed)
                SetDriveTaskMaxCruiseSpeed(driver, Config.RejoinSpeed)
                SetDriveTaskDrivingStyle(driver, Config.DrivingStyle)
                TaskVehicleDriveWander(driver, vehicle, Config.RejoinSpeed, Config.DrivingStyle)
            end
        end
    end

    cooldowns[vehicle] = GetGameTimer() + Config.ReleaseCooldownMs
    yieldStates[vehicle] = nil
    SETraffic.Debug(('released vehicle %s (%s)'):format(vehicle, reason or 'unknown'))
end

local function releaseAll(reason)
    local vehicles = {}
    for vehicle in pairs(yieldStates) do
        vehicles[#vehicles + 1] = vehicle
    end

    for _, vehicle in ipairs(vehicles) do
        releaseVehicle(vehicle, reason)
    end
end

local function assignYield(vehicle, driver, emergencyVehicle, profile)
    local now = GetGameTimer()
    local cooldownUntil = cooldowns[vehicle]
    if cooldownUntil and cooldownUntil > now then
        return
    end

    if yieldStates[vehicle] then
        yieldStates[vehicle].lastRelevantAt = now
        return
    end

    if not SETraffic.TryControl(vehicle) or not SETraffic.TryControl(driver) then
        return
    end

    local target, targetHeading = SETraffic.BuildYieldTarget(vehicle, profile)
    if not target then
        return
    end

    SetVehicleIndicatorLights(vehicle, 1, true)
    SetDriveTaskDrivingStyle(driver, Config.DrivingStyle)
    SetDriveTaskCruiseSpeed(driver, profile.yieldSpeed)
    SetDriveTaskMaxCruiseSpeed(driver, profile.yieldSpeed)

    -- First stage: smoothly drive toward a point ahead and to the roadside.
    -- Parking is only requested when the vehicle is already close, which helps
    -- avoid violent sideways steering.
    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        target.x,
        target.y,
        target.z,
        profile.yieldSpeed,
        Config.DrivingStyle,
        Config.HoldDistance
    )

    yieldStates[vehicle] = {
        driver = driver,
        emergencyVehicle = emergencyVehicle,
        profile = profile,
        target = target,
        targetHeading = targetHeading,
        state = 'YIELDING',
        assignedAt = now,
        lastRelevantAt = now,
        lastParkRefreshAt = 0,
    }

    SETraffic.Debug(('assigned %s vehicle %s at %.1fm/s'):format(profile.kind, vehicle, profile.yieldSpeed))
end

local function scanTraffic(emergencyVehicle)
    local emergencyCoords = GetEntityCoords(emergencyVehicle)
    local pool = GetGamePool('CVehicle')

    for i = 1, #pool do
        local vehicle = pool[i]
        local valid, driver = isValidAIVehicle(vehicle, emergencyVehicle)

        if valid then
            local profile = SETraffic.GetVehicleProfile(vehicle)
            local relevant = isRelevantToEmergency(vehicle, emergencyVehicle, profile)

            if relevant then
                assignYield(vehicle, driver, emergencyVehicle, profile)
            elseif yieldStates[vehicle] then
                -- Do not release immediately just because one scan falls outside
                -- the corridor; the state updater handles passing/release cleanly.
                yieldStates[vehicle].lastDistance = SETraffic.Distance(GetEntityCoords(vehicle), emergencyCoords)
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

    local distanceFromEmergency = SETraffic.Distance(vehicleCoords, emergencyCoords)

    -- Once the emergency vehicle has clearly passed, return ambient AI control.
    if relative.y < -Config.ReleaseBehindDistance then
        releaseVehicle(vehicle, 'emergency passed')
        return
    end

    -- Also release vehicles that became far removed from the response path.
    if distanceFromEmergency > (state.profile.detectionDistance + 45.0) then
        releaseVehicle(vehicle, 'out of range')
        return
    end

    if not SETraffic.TryControl(vehicle) or not SETraffic.TryControl(driver) then
        return
    end

    if state.state == 'YIELDING' then
        local distanceToTarget = SETraffic.Distance(vehicleCoords, state.target)
        local elapsed = now - state.assignedAt

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
            SETraffic.Debug(('vehicle %s holding roadside'):format(vehicle))
        end
    elseif state.state == 'HOLDING' then
        -- Re-issue occasionally rather than every frame. This keeps the AI
        -- committed without creating conflicting task spam.
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

CreateThread(function()
    cacheEmergencyModels()

    if Config.UseNativeSirenReactionOverride and type(OverrideReactionToVehicleSiren) == 'function' then
        OverrideReactionToVehicleSiren(true, Config.NativeSirenReaction)
        SETraffic.Debug('native siren reaction override enabled')
    end

    while true do
        local emergencyVehicle = getPlayerEmergencyVehicle()
        lastEmergencyVehicle = emergencyVehicle

        if emergencyVehicle ~= 0 then
            scanTraffic(emergencyVehicle)
            Wait(Config.ScanIntervalMs)
        else
            if next(yieldStates) ~= nil then
                releaseAll('siren inactive')
            end
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

            for vehicle in pairs(yieldStates) do
                vehicles[#vehicles + 1] = vehicle
            end

            for _, vehicle in ipairs(vehicles) do
                local state = yieldStates[vehicle]
                if state then
                    updateYieldState(vehicle, state, activeEmergencyVehicle)
                end
            end

            Wait(Config.StateUpdateIntervalMs)
        end
    end
end)

RegisterCommand(Config.DebugCommand, function()
    Config.Debug = not Config.Debug
    print(('[smart_emergency_traffic] Debug %s'):format(Config.Debug and 'ENABLED' or 'DISABLED'))
end, false)

-- Optional integration point for ELS/custom siren controllers.
-- Another client resource can call:
-- exports['smart_emergency_traffic']:SetForcedActive(true/false)
exports('SetForcedActive', function(active)
    forcedActive = active == true
end)

exports('IsForcedActive', function()
    return forcedActive
end)

RegisterNetEvent('smart_emergency_traffic:setForcedActive', function(active)
    forcedActive = active == true
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    releaseAll('resource stop')

    if Config.UseNativeSirenReactionOverride and type(OverrideReactionToVehicleSiren) == 'function' then
        OverrideReactionToVehicleSiren(false, Config.NativeSirenReaction)
    end
end)
