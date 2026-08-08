# ClearPath AI

Standalone FiveM resource that improves ambient AI traffic behaviour around responding emergency vehicles.

## v0.1.7 — Junction conflict handling

This patch fixes cross-traffic entering or stopping broadside in front of an approaching emergency vehicle at intersections.

### Junction behaviour

- Predicts where the emergency vehicle's current path and cross-traffic path intersect.
- Detects cross-traffic earlier even when it sits outside the normal forward traffic corridor.
- Vehicles that still have room are instructed to **wait before the conflict point** instead of entering the intersection.
- Vehicles that are already committed are instructed to **continue through and clear the intersection** instead of braking or attempting a roadside pull-over in the responder's lane.
- If a waiting vehicle rolls too far forward and becomes committed, ClearPath automatically changes it to a clear-through manoeuvre rather than stopping it broadside.
- Cross-traffic is released after the responder has safely cleared the conflict point.
- Normal same-direction, opposing, highway and shoulder-yield behaviour remains unchanged.

The junction behaviour is configurable in `config.lua` under the `Config.Junction...` settings.

## Existing behaviour

- Early predictive yielding for normal AI road traffic.
- Separate profiles for cars, heavy vehicles, and vehicles towing trailers.
- More complete shoulder positioning and a slower final pull-over phase.
- Delayed merge-back so vehicles do not re-enter the lane while the responder is still passing.
- Night ERS compatibility safeguards for pursuits/callouts/scripted AI.
- Generic compatibility exports so other resources can protect their own scripted entities.
- Debug commands for live traffic/yield diagnostics.
- Startup version banner in the server console, with the version read directly from `fxmanifest.lua`.

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

## Startup log

ClearPath prints a startup banner similar to:

```text
==================================================================
ClearPath AI | Version v0.1.7
Intelligent Emergency Traffic Yielding
Resource started successfully.
==================================================================
```

FiveM adds the normal `[script:clearpath_ai]` prefix in the server console.

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

These hooks let scripted pursuit/callout resources tell ClearPath not to alter a particular AI entity.
