# Smart Emergency Traffic v0.1.0

Standalone FiveM client resource that makes ambient AI traffic react earlier and more predictably to a player-driven emergency vehicle using lights/sirens.

## What v0.1.0 does

- Detects AI road traffic well before the emergency vehicle reaches it.
- Makes normal cars pull toward the driver's right side of the road.
- Gives trucks, buses, commercial vehicles and utility vehicles earlier detection and gentler movement.
- Detects vehicles towing trailers and gives them the earliest/slowest yield profile.
- Uses a two-stage yield: drive toward a roadside target, then park/hold.
- Lets vehicles clear a junction before attempting to pull over.
- Uses wider shoulder offsets on highway nodes.
- Ignores player-driven vehicles.
- Ignores boats, aircraft and trains.
- Can avoid scripted mission entities to reduce conflicts with other resources.
- Releases AI back to normal wandering once the emergency vehicle has passed or the siren stops.
- Optionally uses FiveM's native NPC siren-reaction override to make ambient traffic prefer pulling right.
- Supports custom emergency vehicle spawn names.
- Includes an export/event for custom ELS or siren-controller integration.

## Installation

1. Put the folder in your server resources, for example:

   `resources/[standalone]/smart_emergency_traffic`

2. Add this to `server.cfg`:

   `ensure smart_emergency_traffic`

3. Restart the resource/server.

No framework, database, ox_lib, QBCore or ESX dependency is required.

## Recommended first test

Use a normal GTA emergency vehicle first (Police/EMS/Fire) to establish a baseline:

1. Drive behind normal city traffic with the siren off. AI should behave normally.
2. Activate the audible siren and approach traffic from roughly 100-130 metres away.
3. Test a sedan, van, bus/utility vehicle and semi/trailer.
4. Test a multi-lane road/highway.
5. Test an intersection and confirm AI tends to clear it before pulling over.
6. Turn the siren off and confirm held traffic returns to normal driving.

## Activation modes

In `config.lua`:

- `audio` (default): full system activates only when siren audio is active.
- `lights`: activates from the emergency warning/siren state even without audio.
- `either`: either state can activate it.

If your custom siren resource does not expose its state through GTA/FiveM's normal siren natives, call the export:

```lua
exports['smart_emergency_traffic']:SetForcedActive(true)
exports['smart_emergency_traffic']:SetForcedActive(false)
```

Or locally trigger:

```lua
TriggerEvent('smart_emergency_traffic:setForcedActive', true)
TriggerEvent('smart_emergency_traffic:setForcedActive', false)
```

## Custom emergency vehicles

If an addon police/fire/ambulance vehicle is not reported as class 18, add its spawn name:

```lua
Config.AdditionalEmergencyVehicles = {
    'valor10charger',
    'myambulance',
    'customfiretruck',
}
```

## Truck behaviour

Heavy classes (Industrial, Utility, Vans, Service and Commercial) use:

- 180 m default detection.
- Lower target speed.
- More distance before moving toward the roadside.
- Larger roadside offset.

A towing vehicle uses the trailer profile:

- 200 m default detection.
- Slowest yield speed.
- Longest lead-in distance.
- Largest roadside offset.

These values are all configurable.

## Debugging

Run:

`/sirentrafficdebug`

This toggles client console debug messages for assignment, holding and release decisions.

## Important tuning notes

GTA V road geometry and AI pathfinding vary significantly between downtown streets, highways, custom maps and addon MLO areas. The values in v0.1.0 are conservative starting values, not a promise that every road will be perfect.

The most useful settings to tune after your first live test are:

- `DetectionDistance`
- `HeavyDetectionDistance`
- `TrailerDetectionDistance`
- `CarPullOverOffset`
- `HeavyPullOverOffset`
- `TrailerPullOverOffset`
- `HighwayExtraOffset`
- `CarYieldSpeed`
- `HeavyYieldSpeed`
- `TrailerYieldSpeed`
- `CorridorGrowth`
- `CorridorMaxWidth`

## Compatibility

The resource guards the newer `OverrideReactionToVehicleSiren` native before using it. If the native is unavailable on a particular client build, the predictive yielding code still runs without that enhancement.

If another resource aggressively retasks ambient drivers every frame, the two resources can fight over AI control. In that case either disable that conflicting behaviour or set this resource's mission-entity protection/configuration appropriately.
