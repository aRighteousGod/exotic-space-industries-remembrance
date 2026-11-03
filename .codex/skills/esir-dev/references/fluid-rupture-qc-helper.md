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

## Managed staging

The save catalogue's required helpers now stage automatically for `qc-runtime`, `qc-preview`, `qc-full` and `runtime-benchmark`. Missing or incompatible helpers fail before engine launch. This helper still carries historical 2.0 metadata; port its metadata and APIs together before claiming current 2.1.24 acceptance. Use the explicit catalogue family and preserve historical receipts. Do not copy into shared `fmqc/mods-live` directories. See [native testing](native-testing.md).

For an already compatible catalogued save, select its `SaveId` through the wrapper. Keep the scenario's full tick budget and required reports; short runtime smoke remains separate from complete functional acceptance.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
