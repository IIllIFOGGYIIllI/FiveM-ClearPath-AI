Config = {}

-- Master switch.
Config.Enabled = true

-- When should AI start yielding?
-- 'audio'  = emergency vehicle must have the siren audio active.
-- 'lights' = emergency warning/siren state is active (useful for some light controllers).
-- 'either' = either condition activates the system.
Config.ActivationMode = 'audio'

-- Class 18 is GTA/FiveM's Emergency vehicle class.
Config.RequireEmergencyVehicle = true

-- Add custom emergency vehicles here if they are not class 18.
-- Use spawn names, for example: 'valor10charger'.
Config.AdditionalEmergencyVehicles = {
    -- 'valor10charger',
}

-- AI scanning frequency. Higher numbers use less CPU but react slightly later.
Config.ScanIntervalMs = 250
Config.IdleScanIntervalMs = 900
Config.StateUpdateIntervalMs = 150

-- Normal AI vehicle detection.
Config.DetectionDistance = 135.0
Config.HeavyDetectionDistance = 180.0
Config.TrailerDetectionDistance = 200.0

-- Ignore AI that is well behind the responding unit.
Config.BehindAllowance = 12.0
Config.ReleaseBehindDistance = 28.0

-- Forward search corridor. It widens with distance so traffic on curves and
-- multi-lane roads can still react without grabbing every vehicle nearby.
Config.CorridorBaseWidth = 15.0
Config.CorridorGrowth = 0.24
Config.CorridorMaxWidth = 46.0
Config.VerticalTolerance = 8.0

-- Where AI aims before it parks/yields.
Config.CarAheadDistance = 28.0
Config.HeavyAheadDistance = 38.0
Config.TrailerAheadDistance = 48.0
Config.JunctionExtraAheadDistance = 20.0

-- Pull-over distance to the driver's right side of the road.
Config.CarPullOverOffset = 4.2
Config.HeavyPullOverOffset = 5.2
Config.TrailerPullOverOffset = 5.8
Config.HighwayExtraOffset = 2.5
Config.MaxPullOverOffset = 9.0

-- Speeds are metres per second (approximately 3.6 km/h per 1.0 m/s).
Config.CarYieldSpeed = 7.0
Config.HeavyYieldSpeed = 5.2
Config.TrailerYieldSpeed = 4.3
Config.RejoinSpeed = 14.0

-- AI behaviour while yielding.
Config.DrivingStyle = 786603
Config.ParkMode = 1
Config.ParkRadius = 20.0
Config.HoldDistance = 8.0
Config.MinimumYieldTimeMs = 1200
Config.HoldRefreshMs = 2200
Config.FailsafeReleaseMs = 30000
Config.ReleaseCooldownMs = 2200

-- Do not hijack vehicles deliberately owned by another scripted mission/resource.
Config.IgnoreMissionEntities = true

-- Skip AI emergency vehicles which are themselves responding with sirens.
Config.IgnoreActiveEmergencyAI = true

-- Non-road vehicle classes to ignore.
-- 14 Boats, 15 Helicopters, 16 Planes, 21 Trains.
Config.ExcludedVehicleClasses = {
    [14] = true,
    [15] = true,
    [16] = true,
    [21] = true,
}

-- Heavy classes receive earlier detection and gentler manoeuvres.
-- 10 Industrial, 11 Utility, 12 Vans, 17 Service, 20 Commercial.
Config.HeavyVehicleClasses = {
    [10] = true,
    [11] = true,
    [12] = true,
    [17] = true,
    [20] = true,
}

-- FiveM added a native siren-reaction override that can tell ambient traffic
-- to pull right instead of using GTA's default reaction. The script checks
-- whether the native exists before using it, so older clients will still run.
Config.UseNativeSirenReactionOverride = true
Config.NativeSirenReaction = 1 -- 0 = Left, 1 = Right, 2 = Stop

-- Debugging.
Config.Debug = false
Config.DebugCommand = 'sirentrafficdebug'
