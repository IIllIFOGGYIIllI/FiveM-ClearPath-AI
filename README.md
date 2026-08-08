# ClearPath AI

Standalone FiveM resource that improves ambient AI traffic behaviour around responding emergency vehicles.

## v0.1.4 — Night ERS compatibility

This patch keeps ClearPath focused on **ordinary ambient traffic** and prevents it from taking over AI that is already being controlled by Nights Software Emergency Response Simulator (ERS) or another gameplay resource.

### Night ERS safeguards

- Detects `night_ers` automatically when the resource is running.
- Protects ERS/scripted mission vehicles and drivers from ClearPath tasks.
- Protects fleeing ERS drivers as a pursuit-safe fallback.
- Protects drivers actively in combat with the player.
- Listens for the documented `ErsIntegration::OnPursuitStarted` and `ErsIntegration::OnPursuitEnded` lifecycle events and synchronizes the protected suspect network ID to nearby/all ClearPath clients when an ID is available.
- If a vehicle becomes protected **after** ClearPath already started yielding it, ClearPath immediately releases that vehicle and stops replacing its driving task.
- Disables ClearPath's global Cfx siren-reaction override while Night ERS is running. This is important because that native affects pedestrian-driven traffic globally; normal ambient traffic still receives ClearPath's own per-vehicle predictive yield tasks.
- Adds generic protection exports so other scripts can mark their own scripted peds/vehicles as off-limits to ClearPath.

This means an ERS pursuit suspect should continue fleeing normally instead of suddenly trying to pull onto the shoulder because the pursuing police vehicle has a siren active.

## Install

Place `clearpath_ai` in your server resources, for example:

```text
resources/[standalone]/clearpath_ai
```

Add:

```cfg
ensure clearpath_ai
```

If you use Night ERS, start it before ClearPath where practical:

```cfg
ensure night_ers
ensure clearpath_ai
```

ClearPath does **not** require Night ERS; the integration is optional and detected automatically.

## Debug

Use:

```text
/clearpathdebug
```

The debug panel now also shows whether Night ERS is running, how many network IDs are explicitly protected, and whether the global siren-reaction override is active.

## Compatibility API

Client-side:

```lua
exports['clearpath_ai']:SetEntityProtected(vehicleOrPed, true)
exports['clearpath_ai']:SetEntityProtected(vehicleOrPed, false)

exports['clearpath_ai']:SetNetIdProtected(netId, true)
exports['clearpath_ai']:SetNetIdProtected(netId, false)
```

Server-side:

```lua
exports['clearpath_ai']:SetProtectedNetId(netId, true)
exports['clearpath_ai']:SetProtectedNetId(netId, false)
```

These hooks let any scripted pursuit/callout resource tell ClearPath not to alter a particular AI entity.

## Current behaviour retained

v0.1.4 retains the v0.1.3 full-shoulder yielding changes, truck/trailer profiles, delayed merge-back behaviour, debug tools and configurable detection distances.
