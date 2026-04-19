# Orbital Logistics QC Helper

Use this helper when ESIR work needs a deterministic orbital logistics cohort save instead of relying on ad hoc hand-built test pads.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-orbital-logistics-qc_0.0.1`](../assets/zzz-orbital-logistics-qc_0.0.1)
- Main helper file: [`../assets/zzz-orbital-logistics-qc_0.0.1/control.lua`](../assets/zzz-orbital-logistics-qc_0.0.1/control.lua)

## What It Builds

- One isolated QC compound on `nauvis` near `x=4800, y=4800`
- One powered orbital scanner, two coordinators, three selectors, two rocket silos, and two dispatch uplinks
- Three same-surface platforms:
  - `QC Alpha`
  - `QC Beta`
  - `QC Gamma`
- One transponder on each platform surface
- One deterministic runtime bootstrap:
  - rebuild orbital logistics state
  - discover live platform IDs from the transponders
  - set selector A to manual `QC Alpha`
  - set selector B to policy mode
  - leave selector C idle until the fairness window
  - bind uplinks to their adjacent silos
  - set one uplink to `sticky` and one to `threshold`

## Important Behavior

- The helper writes `orbital-logistics-qc.jsonl` into script output.
- The `configured` record is the key handoff point; it captures:
  - the first rebuilt snapshot
  - the discovered platform ID map
  - the QC configuration result
  - the post-configuration snapshot
- Every checkpoint snapshot now also captures:
  - `gui_smoke` to verify that the transponder, selector, coordinator, and uplink side panels actually open and expose their expected controls
  - `gui_validation` as a compact pass/fail summary over that side-panel smoke
  - `baseline_validation` to compare the live runtime snapshot against the authored QC cohort shape without hand-parsing every record
- Timed mutations then force:
  - duplicate manual claims and policy recovery
  - active coordinator destruction and automatic failover
  - invalid manual target repair
  - manual retargeting across both live platforms
  - real silo destruction, missing-binding detection, rebuild, and explicit rebind onto the replacement unit
- a contested-lane fairness window that rotates service between `QC Beta` and `QC Gamma` once explicit manual claims have been satisfied
- Later checkpoints at `t+1`, `t+30`, `t+60`, `t+120`, `t+180`, `t+240`, `t+270`, `t+300`, `t+330`, and `t+420` service the cohort and dump snapshots without rebuilding away lease state.
- The stock `qc-runtime` wrapper is still useful as a quick smoke pass, but it only benchmarks `60` ticks. Use a direct helper-aware benchmark of at least `420` ticks when you actually need the full mutation sequence.
- `gui_validation` may report `skipped=true` with `skip_reason=missing-player` under fully headless runs that do not expose a runtime player. Treat that as "GUI smoke unavailable", not as a cohort failure.

## Staging Steps

1. Copy `assets/zzz-orbital-logistics-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-orbital-logistics-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\orbital-cohort.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Use the wrapper smoke pass when you only want a fast "does the save still boot?" check:
   - `qc-runtime -SaveId orbital-cohort`
5. For the full helper scenario, keep the helper staged and run Factorio directly from `.factorio-qc\\fmqc\\mods-live` for at least `420` ticks so every checkpoint fires:
   - `factorio.exe --mod-directory .factorio-qc\\fmqc\\mods-live --config .factorio-qc\\fmqc\\factorio-orbital-helper.ini --disable-audio --benchmark .factorio-qc\\orbital-cohort.zip --benchmark-ticks 420 --benchmark-runs 1`
6. The wrapper currently rebuilds `mods-live` before runtime lanes, so restage the helper after wrapper sync or use the direct helper-aware run above until the sync path grows save-aware helper staging.
7. Disable or remove the helper again before unrelated QC runs.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
