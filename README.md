# ClearPath AI

Standalone FiveM resource that improves ambient AI traffic behaviour around responding emergency vehicles.

## v0.1.3 full-shoulder patch

This patch makes the first build much more assertive and adds diagnostics so you can see exactly why a vehicle is or is not being handled.

### Changes from v0.1.2

- Greatly tightened the final pull-over tolerance so vehicles do not stop while straddling the live lane and shoulder.
- Reduced the park radius from 20.0 m to 2.5 m.
- Reduced the distance at which ClearPath considers the shoulder target reached from 9.0 m to 2.75 m.
- Added a slower final-approach phase for the last 14 m of the manoeuvre.
- Increased roadside offsets for cars, heavy vehicles and trailer combinations.
- Increased the additional highway shoulder offset.
- Added hold-drift detection: if a yielded vehicle creeps back toward the lane before the responder has passed, ClearPath sends it back toward the shoulder target.
- Retains the v0.1.2 delayed rejoin/pass-clearance logic.

These values are configurable in `config.lua`.

## Install

Place `clearpath_ai` in your server resources, for example:

```text
resources/[standalone]/clearpath_ai
```

Add:

```cfg
ensure clearpath_ai
```

## First diagnostic test

1. Restart the resource.
2. Enter an emergency vehicle as the driver.
3. Run `/clearpathdebug`.
4. Turn on emergency lights/siren and approach AI traffic.
5. Watch the debug line for `valid AI`, `relevant`, `yielding`, and `control failures`.
6. If `active` appears to be the problem, run `/clearpathforce` temporarily. If traffic then reacts, your siren controller needs integration or a different activation mode.

Addon emergency vehicles that are not GTA class 18 can be added in `Config.AdditionalEmergencyVehicles`.
