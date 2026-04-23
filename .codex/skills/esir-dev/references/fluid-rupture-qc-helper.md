# Fluid Rupture QC Helper

Use this helper when ESIR work needs a deterministic rupture scenario instead of inferring rupture behavior from generic smoke saves.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-fluid-rupture-qc_0.0.1`](../assets/zzz-fluid-rupture-qc_0.0.1)
- Main helper file: [`../assets/zzz-fluid-rupture-qc_0.0.1/control.lua`](../assets/zzz-fluid-rupture-qc_0.0.1/control.lua)

## What It Builds

- One isolated QC compound on `nauvis` near `x=5600, y=5600`
- Four fluid-safety carriers:
  - normal pipe with [fluid=ei-computing-power] data contamination
  - normal pipe with [fluid=ei-liquid-nitrogen] cryogenic boiloff
  - normal pipe with `lava` thermal rupture
  - storage tank with `electrolyte` chemical rupture
- One flammable rupture source:
  - storage tank filled with `crude-oil`, then destroyed by script after the fluid-safety pass

## Important Behavior

- The helper emits structured `FLUID_RUPTURE_QC ...` log lines for every action and checkpoint.
- It also attempts to mirror those records into `fluid-rupture-qc.jsonl` under script output when the active benchmark write-data surface honors file writes.
- It uses the QC-only remote surface `exotic-industries-qc` to:
  - rebuild fluid runtime registration after the scene is authored
  - service the fluid-safety queue directly for deterministic early snapshots
  - capture a combined rupture snapshot with fluid-safety and rupture-scheduler status
- Snapshot checkpoints record:
  - live case state for each authored carrier
  - combined rupture runtime status
  - compact pass/fail validation for the authored expectations
- Authored expectations are:
  - the data pipe case dies
  - the cryogenic line survives and phase-shifts to `ei-nitrogen-gas`
  - the thermal line dies
  - the chemical tank dies
  - the flammable oil tank survives until the scripted kill, then dies while the rupture scheduler plays back

## Staging Steps

1. Copy `assets/zzz-fluid-rupture-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-fluid-rupture-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\fluid-rupture.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Keep the helper staged for direct helper-aware playback, for example:
   - `factorio.exe --mod-directory .factorio-qc\\fmqc\\mods-live --disable-audio --benchmark .factorio-qc\\fluid-rupture.zip --benchmark-ticks 90 --benchmark-runs 1`
5. Repo-side runtime benchmarks now honor the save catalog's `helper_mods`, so this path will restage and enable `zzz-fluid-rupture-qc` automatically:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task runtime-benchmark -SaveId fluid-rupture`
6. Wrapper-driven runtime lanes still rebuild `mods-live` without replaying helper mods automatically, so treat `qc-runtime -SaveId fluid-rupture` as a save-selection convenience only after manual helper staging or until the lower QC sync path grows save-aware helper staging.
7. Disable or remove the helper again before unrelated QC runs.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
