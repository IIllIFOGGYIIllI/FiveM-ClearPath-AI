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


function ClearPath.Dot2D(a, b)
    return (a.x * b.x) + (a.y * b.y)
end

function ClearPath.Cross2D(a, b)
    return (a.x * b.y) - (a.y * b.x)
end

-- Returns the forward-path intersection between two vehicles. Distances are in
-- metres along each vehicle's current heading. This lets ClearPath distinguish
-- ordinary same-direction traffic from cross-traffic that is about to occupy the
-- responder's path through a junction.
function ClearPath.GetForwardPathIntersection(entityA, entityB, maxDistanceA, maxDistanceB)
    if entityA == 0 or entityB == 0 or not DoesEntityExist(entityA) or not DoesEntityExist(entityB) then
        return nil
    end

    local a = GetEntityCoords(entityA)
    local b = GetEntityCoords(entityB)
    local r = ClearPath.ForwardFromHeading(GetEntityHeading(entityA))
    local s = ClearPath.ForwardFromHeading(GetEntityHeading(entityB))
    local denominator = ClearPath.Cross2D(r, s)

    if math.abs(denominator) < 0.05 then return nil end

    local qmp = vector3(b.x - a.x, b.y - a.y, 0.0)
    local distanceA = ClearPath.Cross2D(qmp, s) / denominator
    local distanceB = ClearPath.Cross2D(qmp, r) / denominator

    if distanceA < 0.0 or distanceB < 0.0 then return nil end
    if maxDistanceA and distanceA > maxDistanceA then return nil end
    if maxDistanceB and distanceB > maxDistanceB then return nil end

    return vector3(
        a.x + (r.x * distanceA),
        a.y + (r.y * distanceA),
        (a.z + b.z) * 0.5
    ), distanceA, distanceB
end

function ClearPath.GetForwardProgressFromPoint(entity, point, heading)
    local coords = GetEntityCoords(entity)
    local forward = ClearPath.ForwardFromHeading(heading or GetEntityHeading(entity))
    local delta = vector3(coords.x - point.x, coords.y - point.y, 0.0)
    return ClearPath.Dot2D(delta, forward)
end

function ClearPath.DistancePointToSegment2D(point, segmentStart, segmentEnd)
    local abx = segmentEnd.x - segmentStart.x
    local aby = segmentEnd.y - segmentStart.y
    local apx = point.x - segmentStart.x
    local apy = point.y - segmentStart.y
    local lengthSq = (abx * abx) + (aby * aby)

    if lengthSq <= 0.0001 then
        local dx = point.x - segmentStart.x
        local dy = point.y - segmentStart.y
        return math.sqrt((dx * dx) + (dy * dy))
    end

    local t = ((apx * abx) + (apy * aby)) / lengthSq
    t = ClearPath.Clamp(t, 0.0, 1.0)

    local closestX = segmentStart.x + (abx * t)
    local closestY = segmentStart.y + (aby * t)
    local dx = point.x - closestX
    local dy = point.y - closestY
    return math.sqrt((dx * dx) + (dy * dy))
end

function ClearPath.TargetPathPassesNearEntity(vehicle, target, entity, radius)
    if vehicle == 0 or entity == 0 or not target then return false, math.huge end
    if not DoesEntityExist(vehicle) or not DoesEntityExist(entity) then return false, math.huge end

    local start = GetEntityCoords(vehicle)
    local point = GetEntityCoords(entity)
    local distance = ClearPath.DistancePointToSegment2D(point, start, target)
    return distance <= (radius or 0.0), distance
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


function ClearPath.BuildJunctionPlan(vehicle, emergencyVehicle)
    if not Config.JunctionControlEnabled then return nil end

    local vehicleHeading = GetEntityHeading(vehicle)
    local emergencyHeading = GetEntityHeading(emergencyVehicle)
    local headingDifference = math.abs(ClearPath.HeadingDelta(vehicleHeading, emergencyHeading))

    -- Only special-case genuine crossing traffic. Same-direction and opposing
    -- traffic continue to use the normal right-side shoulder-yield behaviour.
    if headingDifference < Config.JunctionCrossingMinAngle
        or headingDifference > Config.JunctionCrossingMaxAngle then
        return nil
    end

    local conflictPoint, emergencyDistance, vehicleDistance = ClearPath.GetForwardPathIntersection(
        emergencyVehicle,
        vehicle,
        Config.JunctionEmergencyApproachDistance,
        Config.JunctionCrossTrafficApproachDistance
    )

    if not conflictPoint then return nil end

    local vehicleCoords = GetEntityCoords(vehicle)
    local emergencyCoords = GetEntityCoords(emergencyVehicle)
    local nearJunction = ClearPath.IsJunctionAt(conflictPoint)
        or ClearPath.IsJunctionAt(vehicleCoords)
        or ClearPath.IsJunctionAt(emergencyCoords)

    if not nearJunction then return nil end

    local forward = ClearPath.ForwardFromHeading(vehicleHeading)
    local speed = GetEntitySpeed(vehicle)
    local committedDistance = Config.JunctionCommittedDistance

    if speed >= Config.JunctionCommitSpeed then
        committedDistance = committedDistance + Config.JunctionMovingCommitExtraDistance
    end

    local committed = vehicleDistance <= committedDistance

    if committed then
        local clearDistance = vehicleDistance + Config.JunctionClearBeyondConflictDistance
        local target = vector3(
            vehicleCoords.x + (forward.x * clearDistance),
            vehicleCoords.y + (forward.y * clearDistance),
            vehicleCoords.z
        )

        return {
            mode = 'clear',
            target = target,
            targetHeading = vehicleHeading,
            conflictPoint = conflictPoint,
            vehicleHeading = vehicleHeading,
            emergencyHeading = emergencyHeading,
            emergencyDistance = emergencyDistance,
            vehicleDistance = vehicleDistance,
        }
    end

    -- Keep the vehicle on its own current travel line and stop it before the
    -- projected conflict point. Do not offset it toward the kerb while it is
    -- approaching/crossing a junction.
    local travelToStop = math.max(vehicleDistance - Config.JunctionStopBuffer, Config.JunctionMinimumStopTravel)
    local stopTarget = vector3(
        vehicleCoords.x + (forward.x * travelToStop),
        vehicleCoords.y + (forward.y * travelToStop),
        vehicleCoords.z
    )

    return {
        mode = 'wait',
        target = stopTarget,
        targetHeading = vehicleHeading,
        conflictPoint = conflictPoint,
        vehicleHeading = vehicleHeading,
        emergencyHeading = emergencyHeading,
        emergencyDistance = emergencyDistance,
        vehicleDistance = vehicleDistance,
    }
end

function ClearPath.GetIndicatorState(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) or type(GetVehicleIndicatorLights) ~= 'function' then
        return 0
    end

    -- Some GTA vehicles can return extra flag bits (for example 64+). The low two
    -- bits are the indicator state: 0 none, 1 left, 2 right, 3 both/hazards.
    local state = tonumber(GetVehicleIndicatorLights(vehicle)) or 0
    return state % 4
end

function ClearPath.GetJunctionAheadDistance(vehicle, maxDistance, step)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local coords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local forward = ClearPath.ForwardFromHeading(heading)
    local limit = maxDistance or Config.TurnLaneDetectionDistance or 55.0
    local increment = math.max(step or Config.TurnLaneSampleStep or 4.0, 1.0)

    local distance = 0.0
    while distance <= limit do
        local sample = vector3(
            coords.x + (forward.x * distance),
            coords.y + (forward.y * distance),
            coords.z
        )
        if ClearPath.IsJunctionAt(sample) then
            return distance
        end
        distance = distance + increment
    end

    return nil
end

function ClearPath.GetTargetLateralShift(vehicle, target)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not target then return 0.0 end
    local coords = GetEntityCoords(vehicle)
    local right = ClearPath.RightFromHeading(GetEntityHeading(vehicle))
    local delta = vector3(target.x - coords.x, target.y - coords.y, 0.0)
    return ClearPath.Dot2D(delta, right)
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
