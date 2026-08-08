ClearPath = ClearPath or {}

function ClearPath.Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function ClearPath.Distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

function ClearPath.HeadingDelta(a, b)
    return ((a - b + 180.0) % 360.0) - 180.0
end

function ClearPath.ForwardFromHeading(heading)
    local r = math.rad(heading)
    return vector3(-math.sin(r), math.cos(r), 0.0)
end

function ClearPath.RightFromHeading(heading)
    local r = math.rad(heading)
    return vector3(math.cos(r), math.sin(r), 0.0)
end

function ClearPath.Debug(message)
    if Config.Debug then
        print(('[clearpath_ai] %s'):format(message))
    end
end

function ClearPath.TryControl(entity)
    if entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    if not NetworkGetEntityIsNetworked(entity) then
        return true
    end

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)
    return NetworkHasControlOfEntity(entity)
end

function ClearPath.IsHighwayAt(coords)
    local found, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    if not found or not flags then return false end
    return (flags & 64) ~= 0
end

function ClearPath.IsJunctionAt(coords)
    local found, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    if not found or not flags then return false end
    return (flags & 128) ~= 0
end

function ClearPath.GetVehicleProfile(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)
    local heavy = Config.HeavyVehicleClasses[vehicleClass] == true
    local trailer = IsVehicleAttachedToTrailer(vehicle)

    if trailer then
        return {
            kind = 'trailer',
            detectionDistance = Config.TrailerDetectionDistance,
            aheadDistance = Config.TrailerAheadDistance,
            pullOverOffset = Config.TrailerPullOverOffset,
            yieldSpeed = Config.TrailerYieldSpeed,
            finalYieldSpeed = Config.TrailerFinalYieldSpeed,
            releaseBehindDistance = Config.TrailerReleaseBehindDistance,
            postPassHoldMs = Config.TrailerPostPassHoldMs,
        }
    end

    if heavy then
        return {
            kind = 'heavy',
            detectionDistance = Config.HeavyDetectionDistance,
            aheadDistance = Config.HeavyAheadDistance,
            pullOverOffset = Config.HeavyPullOverOffset,
            yieldSpeed = Config.HeavyYieldSpeed,
            finalYieldSpeed = Config.HeavyFinalYieldSpeed,
            releaseBehindDistance = Config.HeavyReleaseBehindDistance,
            postPassHoldMs = Config.HeavyPostPassHoldMs,
        }
    end

    return {
        kind = 'car',
        detectionDistance = Config.DetectionDistance,
        aheadDistance = Config.CarAheadDistance,
        pullOverOffset = Config.CarPullOverOffset,
        yieldSpeed = Config.CarYieldSpeed,
        finalYieldSpeed = Config.CarFinalYieldSpeed,
        releaseBehindDistance = Config.CarReleaseBehindDistance,
        postPassHoldMs = Config.CarPostPassHoldMs,
    }
end

function ClearPath.BuildYieldTarget(vehicle, profile)
    local coords = GetEntityCoords(vehicle)
    local vehicleHeading = GetEntityHeading(vehicle)
    local aheadDistance = profile.aheadDistance

    if ClearPath.IsJunctionAt(coords) then
        aheadDistance = aheadDistance + Config.JunctionExtraAheadDistance
    end

    local forward = ClearPath.ForwardFromHeading(vehicleHeading)
    local sample = vector3(
        coords.x + (forward.x * aheadDistance),
        coords.y + (forward.y * aheadDistance),
        coords.z
    )

    local found, nodeCoords, roadHeading = GetClosestVehicleNodeWithHeading(
        sample.x, sample.y, sample.z, 1, 3.0, 0
    )

    if not found or not nodeCoords then
        return nil
    end

    -- Match the road-node heading to the AI vehicle's direction of travel.
    if math.abs(ClearPath.HeadingDelta(vehicleHeading, roadHeading)) > 90.0 then
        roadHeading = (roadHeading + 180.0) % 360.0
    end

    local offset = profile.pullOverOffset
    if ClearPath.IsHighwayAt(nodeCoords) then
        offset = offset + Config.HighwayExtraOffset
    end
    offset = ClearPath.Clamp(offset, 0.0, Config.MaxPullOverOffset)

    local roadRight = ClearPath.RightFromHeading(roadHeading)
    local target = vector3(
        nodeCoords.x + (roadRight.x * offset),
        nodeCoords.y + (roadRight.y * offset),
        nodeCoords.z
    )

    return target, roadHeading
end

function ClearPath.DrawText(x, y, text, scale)
    SetTextFont(0)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end
