# Orbital Logistics QC Helper

For current 2.1.24 work, use the registered `orbital-logistics` suite through `invoke-esir-dev.ps1 -Task qc-test -Suite orbital-logistics`. Its checked-in fixture is `scripts/qc/orbital-logistics`, with Quality enabled/disabled and candidate/reload/configuration cases. A graphical checkpoint exercises programmatic native GUI callbacks; rendered, physical-input, multiplayer and performance evidence remain separate. Fresh matching receipts are required.

The helper described below is historical reference material. Its configuration handler recreates the world and must not be used to establish persistence acceptance for the current implementation.

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
- Later checkpoints through `t+480`, including the final ID-conflict recovery after the `t+435` mutation, service the historical cohort and dump snapshots without rebuilding away lease state.
- A short runtime smoke does not cover the historical 480-tick mutation sequence. Current acceptance belongs to the registered native suite above.
- `gui_validation` may report `skipped=true` with `skip_reason=missing-player` under fully headless runs that do not expose a runtime player. Treat that as "GUI smoke unavailable", not as a cohort failure.

## Managed staging

The save catalogue's required helpers now stage automatically for `qc-runtime`, `qc-preview`, `qc-full` and `runtime-benchmark`. Missing or incompatible helpers fail before engine launch. This helper still carries historical 2.0 metadata; port its metadata and APIs together before claiming current 2.1.24 acceptance. Use the explicit catalogue family and preserve historical receipts. Do not copy into shared `fmqc/mods-live` directories. See [native testing](native-testing.md).

For an already compatible catalogued save, select its `SaveId` through the wrapper. Keep the scenario's full tick budget and required reports; short runtime smoke remains separate from complete functional acceptance.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
