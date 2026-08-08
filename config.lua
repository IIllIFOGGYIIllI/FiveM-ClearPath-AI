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

-- FiveM/Cfx siren-reaction override. This is a fallback/assist; ClearPath still
-- applies its own earlier predictive tasks to relevant AI traffic.
Config.UseNativeSirenReactionOverride = true
Config.NativeSirenReaction = 1 -- 0 left, 1 right, 2 stop

-- Debug/test commands.
Config.Debug = false
Config.DebugCommand = 'clearpathdebug'
Config.ForceCommand = 'clearpathforce'
Config.StatusCommand = 'clearpathstatus'
Config.LegacyDebugCommand = 'sirentrafficdebug'
