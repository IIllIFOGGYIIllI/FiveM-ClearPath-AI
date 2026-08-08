# ClearPath AI

Standalone FiveM resource that improves ambient AI traffic behaviour around responding emergency vehicles.

## v0.1.9 — Stable turn-lane hold

This patch fixes left-turn/inside-lane vehicles steering back and forth while an emergency vehicle approaches.

### Turn-lane behaviour

- Detects AI vehicles signalling left near a junction.
- Remembers a recently observed left indicator across the normal indicator blink cycle.
- Detects when a right-shoulder yield would require an unsafe multi-lane lateral move.
- Uses a dedicated straight braking/hold action instead of preserving GTA's ambient turn task.
- Prevents GTA's own siren response and ClearPath from fighting over the same steering task.
- Keeps the vehicle in its current turn lane while the responder approaches/passes.
- Releases back to normal ambient driving once the emergency vehicle is safely clear or the vehicle has cleared the junction.
- Keeps the global FiveM siren-reaction override disabled by default so it cannot independently force turn-lane traffic right.

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
ClearPath AI | Version v0.1.9
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
