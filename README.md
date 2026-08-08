# ClearPath AI

Standalone FiveM resource that improves ambient AI traffic behaviour around responding emergency vehicles.

## v0.1.8 — Turn-lane preservation

This patch prevents traffic in dedicated left-turn/inside lanes from cutting across live lanes just to reach the right shoulder.

### Turn-lane behaviour

- Detects AI vehicles signalling left near a junction.
- Remembers a recently observed left indicator across the normal indicator blink cycle.
- Detects when the calculated right-shoulder target would require an unsafe multi-lane lateral move.
- Preserves the AI driver's existing GTA route/turn task instead of replacing it with a right-shoulder drive task.
- Temporarily reduces the vehicle's speed while the responder approaches.
- Releases the vehicle as soon as it completes the turn/leaves the junction or the emergency vehicle is safely clear.
- Does not overwrite the preserved turn route with `TaskVehicleDriveWander` when releasing it.
- Disables the global FiveM siren-reaction override by default so it cannot independently force left-turn traffic to the right; ClearPath's per-vehicle logic remains active.

## Existing behaviour

- Early predictive yielding for normal AI road traffic.
- Separate profiles for cars, heavy vehicles, and vehicles towing trailers.
- Full shoulder positioning with a slower final pull-over phase.
- Delayed merge-back so traffic stays clear until the responder has fully passed.
- Junction conflict handling: cross-traffic waits before the conflict point or clears through if already committed.
- Night ERS compatibility safeguards for pursuits/callouts/scripted AI.
- Generic compatibility exports for other scripted AI resources.
- Debug commands for live traffic/yield diagnostics.
- Versioned startup banner in the server console.

## Install

Place the resource folder exactly as:

```text
resources/[standalone]/ClearPath_AI
```

Add:

```cfg
ensure ClearPath_AI
```

If you use Night ERS, start it before ClearPath where practical:

```cfg
ensure night_ers
ensure ClearPath_AI
```

ClearPath does **not** require Night ERS; the integration is optional and detected automatically.

## Startup log

ClearPath prints a startup banner similar to:

```text
==================================================================
ClearPath AI | Version v0.1.8
Intelligent Emergency Traffic Yielding
Resource started successfully.
==================================================================
```

FiveM adds the normal `[script:ClearPath_AI]` prefix in the server console.

## Debug

```text
/clearpathdebug
/clearpathstatus
/clearpathforce
```

`/clearpathdebug` shows live AI counts, siren state, Night ERS compatibility state and yield targets.

## Compatibility API

Client-side:

```lua
exports['ClearPath_AI']:SetEntityProtected(vehicleOrPed, true)
exports['ClearPath_AI']:SetEntityProtected(vehicleOrPed, false)

exports['ClearPath_AI']:SetNetIdProtected(netId, true)
exports['ClearPath_AI']:SetNetIdProtected(netId, false)
```

Server-side:

```lua
exports['ClearPath_AI']:SetProtectedNetId(netId, true)
exports['ClearPath_AI']:SetProtectedNetId(netId, false)
```

These hooks let scripted pursuit/callout resources tell ClearPath not to alter a particular AI entity.
