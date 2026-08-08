Config = {}

Config.Enabled = true

-- 'audio'  = requires warning state + audible siren.
-- 'lights' = warning/lights state only.
-- 'either' = warning state OR audible siren. Recommended for custom siren/ELS resources.
Config.ActivationMode = 'either'

-- Class 18 is GTA/FiveM's normal emergency vehicle class.
Config.RequireEmergencyVehicle = true

-- Add addon emergency vehicle spawn names here if they are not class 18.
Config.AdditionalEmergencyVehicles = {
    -- 'valor10charger',
}

-- Faster reaction than v0.1.0.
Config.ScanIntervalMs = 180
Config.IdleScanIntervalMs = 700
Config.StateUpdateIntervalMs = 120

-- Detection distances.
Config.DetectionDistance = 170.0
Config.HeavyDetectionDistance = 220.0
Config.TrailerDetectionDistance = 250.0

-- Vehicles just behind the emergency unit are ignored. Releasing is intentionally
-- much more conservative so traffic cannot merge back into the responder while it
-- is still being overtaken.
Config.BehindAllowance = 18.0
Config.PassDetectionBehindDistance = 8.0
Config.CarReleaseBehindDistance = 55.0
Config.HeavyReleaseBehindDistance = 72.0
Config.TrailerReleaseBehindDistance = 90.0
Config.CarPostPassHoldMs = 1400
Config.HeavyPostPassHoldMs = 2400
Config.TrailerPostPassHoldMs = 3400

-- Wider forward corridor than v0.1.0 so traffic on bends/multi-lane roads is caught.
Config.CorridorBaseWidth = 24.0
Config.CorridorGrowth = 0.34
Config.CorridorMaxWidth = 72.0
Config.VerticalTolerance = 10.0


-- Junction conflict management. Cross-traffic is handled differently from normal
-- lane traffic: vehicles that have not entered the conflict area wait before it,
-- while vehicles already committed are instructed to clear through instead of
-- stopping broadside in the responder's lane.
Config.JunctionControlEnabled = true
Config.JunctionCrossingMinAngle = 50.0
Config.JunctionCrossingMaxAngle = 130.0
Config.JunctionEmergencyApproachDistance = 115.0
Config.JunctionCrossTrafficApproachDistance = 70.0
Config.JunctionCommittedDistance = 6.0
Config.JunctionCommitSpeed = 5.0
Config.JunctionMovingCommitExtraDistance = 10.0
Config.JunctionStopBuffer = 9.0
Config.JunctionMinimumStopTravel = 2.0
Config.JunctionClearBeyondConflictDistance = 24.0
Config.JunctionClearReleaseDistance = 14.0
Config.JunctionEmergencyClearDistance = 20.0
Config.JunctionWaitApproachSpeed = 5.0
Config.JunctionClearSpeed = 10.5
Config.JunctionTaskRefreshMs = 650

-- Turn-lane/lane-preservation protection. Near junctions, ClearPath must not make
-- an AI vehicle cross several live lanes just to reach the right shoulder. Vehicles
-- signalling left, or vehicles whose calculated shoulder target would require an
-- unsafe multi-lane right shift, keep their existing ambient route/turn task and
-- simply reduce speed until the emergency vehicle is clear.
Config.TurnLaneProtectionEnabled = true
Config.TurnLaneDetectionDistance = 58.0
Config.TurnLaneSampleStep = 4.0
Config.TurnLaneUnsafeExtraRightShift = 2.75
Config.TurnLanePreserveSpeed = 5.0
Config.TurnLaneRefreshMs = 700
Config.TurnLaneHeadingRelease = 38.0
Config.TurnLaneReleaseDistance = 28.0
Config.TurnIntentMemoryMs = 2200

-- Roadside target sampling.
Config.CarAheadDistance = 34.0
Config.HeavyAheadDistance = 46.0
Config.TrailerAheadDistance = 58.0
Config.JunctionExtraAheadDistance = 24.0

Config.CarPullOverOffset = 5.8
Config.HeavyPullOverOffset = 6.8
Config.TrailerPullOverOffset = 7.6
Config.HighwayExtraOffset = 3.2
Config.MaxPullOverOffset = 12.0

-- m/s (1.0 m/s ~= 3.6 km/h).
Config.CarYieldSpeed = 7.5
Config.HeavyYieldSpeed = 5.5
Config.TrailerYieldSpeed = 4.5

-- Final approach is deliberately slower so the AI finishes moving onto the
-- shoulder rather than stopping as soon as it gets vaguely near the target.
Config.FinalApproachDistance = 14.0
Config.CarFinalYieldSpeed = 3.2
Config.HeavyFinalYieldSpeed = 2.6
Config.TrailerFinalYieldSpeed = 2.2

Config.RejoinSpeed = 14.0

Config.DrivingStyle = 786603
Config.ParkMode = 1
-- v0.1.2 used a very loose park radius / hold distance. That allowed GTA to
-- accept a "parked" position while the vehicle was still partly in the lane.
Config.ParkRadius = 2.5
Config.HoldDistance = 2.75
Config.HoldDriftTolerance = 4.0
Config.MinimumYieldTimeMs = 900
Config.HoldRefreshMs = 1800
Config.YieldTaskRefreshMs = 900
Config.FailsafeReleaseMs = 45000
Config.ReleaseCooldownMs = 1800

-- v0.1.0 defaulted this to true. That can exclude traffic created/owned by other resources.
-- Leave false unless you specifically need to protect scripted traffic.
Config.IgnoreMissionEntities = false

Config.IgnoreActiveEmergencyAI = true

Config.ExcludedVehicleClasses = {
    [14] = true, -- Boats
    [15] = true, -- Helicopters
    [16] = true, -- Planes
    [21] = true, -- Trains
}

Config.HeavyVehicleClasses = {
    [10] = true, -- Industrial
    [11] = true, -- Utility
    [12] = true, -- Vans
    [17] = true, -- Service
    [20] = true, -- Commercial
}

-- FiveM/Cfx global siren-reaction override. Disabled by default because the global
-- right-pull reaction can fight lane-aware turn/junction handling. ClearPath's own
-- per-vehicle predictive tasks handle ambient traffic instead.
Config.UseNativeSirenReactionOverride = false
Config.NativeSirenReaction = 1 -- 0 left, 1 right, 2 stop

-- Compatibility safeguards. ClearPath should only manage ordinary ambient traffic,
-- never vehicles/peds currently being controlled by another gameplay resource.
Config.Compatibility = {
    NightERS = {
        Enabled = true,
        ResourceName = 'night_ers',

        -- ERS uses scripted/mission entities for callouts, traffic stops, pursuits and
        -- backup. When ERS is running, leave those entities completely alone.
        ProtectMissionEntities = true,

        -- Pursuit suspects are normally fleeing/scripted. These fallbacks protect
        -- them even if an ERS pursuit event payload changes between versions.
        ProtectFleeingDrivers = true,
        ProtectCombatDrivers = true,

        -- The global siren-reaction override changes GTA behaviour for every ambient
        -- NPC on the client. Disable it while ERS is running so it cannot affect an
        -- ERS suspect; ClearPath's per-vehicle tasks still handle normal traffic.
        DisableGlobalSirenOverride = true,
    },
}

-- Debug/test commands.
Config.Debug = false
Config.DebugCommand = 'clearpathdebug'
Config.ForceCommand = 'clearpathforce'
Config.StatusCommand = 'clearpathstatus'
Config.LegacyDebugCommand = 'sirentrafficdebug'
