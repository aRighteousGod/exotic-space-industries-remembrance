# Beacon Overload Geometry QC Helper

Use this helper when ESIR work needs deterministic coverage for beacon overload receiver geometry, weighted/excluded beacon rules, and beacon build/removal recount behavior.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-beacon-overload-geometry-qc_0.0.1`](../assets/zzz-beacon-overload-geometry-qc_0.0.1)
- Main helper file: [`../assets/zzz-beacon-overload-geometry-qc_0.0.1/control.lua`](../assets/zzz-beacon-overload-geometry-qc_0.0.1/control.lua)

## What It Builds

- One isolated QC strip on `nauvis` near `x=6200, y=6200`
- Six machine/beacon layouts:
  - vanilla edge-overlap receiver geometry with 5 engine-affecting beacons
  - remove/re-add churn for the edge beacon
  - 3 helper beacons registered with ESIR overload weight `2`
  - 4 normal beacons plus 1 helper beacon registered as excluded
  - 5 range-12 helper beacons placed after the machine
  - `ei-heat-steel-furnace` with vanilla beacons, validating `uses_beacon_effects=false`

## Important Behavior

- The helper registers rules through the public `exotic-industries` remote interface:
  - `set_beacon_overload_beacon_weight("zzz-bo-weighted-beacon", 2)`
  - `add_beacon_overload_beacon_exclusion("zzz-bo-excluded-beacon")`
- It emits structured `BEACON_OVERLOAD_GEOMETRY_QC ...` log lines for build, action, and checkpoint records.
- It mirrors those records into `beacon-overload-geometry-qc.jsonl` under the benchmark write-data directory when file writes are available.
- Snapshot checkpoints run at relative ticks `5`, `35`, `70`, `120`, and `720`.
- Authored expectations are:
  - edge-overlap is inactive
  - edge-churn is inactive, active after removing the edge beacon, then inactive after re-adding it
  - weighted beacons overload despite an engine count of 3
  - excluded beacon does not overload with 4 normal counted beacons
  - long-range helper beacons overload outside the old default range
  - heat steel furnace remains active because it does not use beacon effects

## Staging Steps

1. Copy `assets/zzz-beacon-overload-geometry-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-beacon-overload-geometry-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\beacon-overload-geometry.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Repo-side runtime benchmarks honor the save catalog's `helper_mods`, so this path will restage and enable `zzz-beacon-overload-geometry-qc` automatically:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task runtime-benchmark -SaveId beacon-overload-geometry`
5. Disable or remove the helper again before unrelated QC runs.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
