# ClearPath AI

Standalone FiveM resource that improves ambient AI traffic behaviour around responding emergency vehicles.

## v0.1.10 — Responder safety envelope

This patch fixes protected turn-lane/nearby traffic drifting sideways into the emergency vehicle while being held.

### Safety behaviour

- Adds a hard responder safety envelope around the active emergency vehicle.
- Rejects ClearPath yield targets whose projected path would cut through that envelope.
- Converts unsafe nearby manoeuvres into an in-lane hold instead of a right-side pull-over.
- Neutralises steering once held traffic has slowed enough, preventing residual turn input from carrying it sideways.
- Applies the handbrake only once the AI is almost stopped, avoiding abrupt high-speed locking.
- Lets committed junction traffic keep its existing GTA route instead of forcing a straight-line clear target, so cars already turning do not get driven across the responder.
- Uses a tighter emergency collision radius even for committed junction traffic as a final no-contact safeguard.
- Releases the safety hold only after the responder has regained separation.
- Retains the v0.1.9 turn-lane protection, Night ERS safeguards and junction state machine.

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
ClearPath AI | Version v0.1.10
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
