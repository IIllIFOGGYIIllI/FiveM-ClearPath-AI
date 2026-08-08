SETraffic = SETraffic or {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

SETraffic.Clamp = clamp

function SETraffic.Distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

function SETraffic.HeadingDelta(a, b)
    return ((a - b + 180.0) % 360.0) - 180.0
end

function SETraffic.ForwardFromHeading(heading)
    local radians = math.rad(heading)
    return vector3(-math.sin(radians), math.cos(radians), 0.0)
end

function SETraffic.RightFromHeading(heading)
    local radians = math.rad(heading)
    return vector3(math.cos(radians), math.sin(radians), 0.0)
end

function SETraffic.Debug(message)
    if Config.Debug then
        print(('[smart_emergency_traffic] %s'):format(message))
    end
end

function SETraffic.TryControl(entity)
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

function SETraffic.IsHighwayAt(coords)
    local found, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    if not found or not flags then
        return false
    end

    -- eVehicleNodeProperties.HIGHWAY = 1 << 6 = 64
    return (flags & 64) ~= 0
end

function SETraffic.IsJunctionAt(coords)
    local found, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    if not found or not flags then
        return false
    end

    -- eVehicleNodeProperties.JUNCTION = 1 << 7 = 128
    return (flags & 128) ~= 0
end

function SETraffic.GetVehicleProfile(vehicle)
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
        }
    end

    if heavy then
        return {
            kind = 'heavy',
            detectionDistance = Config.HeavyDetectionDistance,
            aheadDistance = Config.HeavyAheadDistance,
            pullOverOffset = Config.HeavyPullOverOffset,
            yieldSpeed = Config.HeavyYieldSpeed,
        }
    end

    return {
        kind = 'car',
        detectionDistance = Config.DetectionDistance,
        aheadDistance = Config.CarAheadDistance,
        pullOverOffset = Config.CarPullOverOffset,
        yieldSpeed = Config.CarYieldSpeed,
    }
end

function SETraffic.BuildYieldTarget(vehicle, profile)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleHeading = GetEntityHeading(vehicle)
    local aheadDistance = profile.aheadDistance

    -- If the AI is currently in/near a junction, let it clear the junction
    -- before trying to park at the roadside.
    if SETraffic.IsJunctionAt(vehicleCoords) then
        aheadDistance = aheadDistance + Config.JunctionExtraAheadDistance
    end

    local vehicleForward = SETraffic.ForwardFromHeading(vehicleHeading)
    local sample = vector3(
        vehicleCoords.x + (vehicleForward.x * aheadDistance),
        vehicleCoords.y + (vehicleForward.y * aheadDistance),
        vehicleCoords.z
    )

    local found, nodeCoords, roadHeading = GetClosestVehicleNodeWithHeading(
        sample.x,
        sample.y,
        sample.z,
        1,
        3.0,
        0
    )

    if not found or not nodeCoords then
        return nil
    end

    -- Vehicle nodes can report the same road in the opposite direction.
    -- Align the node heading to the AI vehicle's actual direction of travel.
    if math.abs(SETraffic.HeadingDelta(vehicleHeading, roadHeading)) > 90.0 then
        roadHeading = (roadHeading + 180.0) % 360.0
    end

    local pullOverOffset = profile.pullOverOffset
    if SETraffic.IsHighwayAt(nodeCoords) then
        pullOverOffset = pullOverOffset + Config.HighwayExtraOffset
    end
    pullOverOffset = clamp(pullOverOffset, 0.0, Config.MaxPullOverOffset)

    local roadRight = SETraffic.RightFromHeading(roadHeading)
    local target = vector3(
        nodeCoords.x + (roadRight.x * pullOverOffset),
        nodeCoords.y + (roadRight.y * pullOverOffset),
        nodeCoords.z
    )

    return target, roadHeading
end
