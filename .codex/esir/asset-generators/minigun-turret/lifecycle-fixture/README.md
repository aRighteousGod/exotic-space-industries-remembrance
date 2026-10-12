# Native lifecycle fixture — execution pending

This helper is implemented and reviewed but **has not been staged into a managed run or executed in Factorio**. Native load, state decoding, thermal timing, real save creation/replay, circuit behavior, and the visual clips remain pending. No shipping prototype is changed by these files. The installed entrypoint is `.codex/esir/asset-generators/minigun-turret/lifecycle-fixture/invoke-lifecycle-fixture.ps1`; the retained staging commands below remain usable. Read `output/minigun-implementation/STATUS.md` first when resuming.

The helper name deliberately remains `zzz-esir-minigun-firing`: the exact full candidate Lua already uses that mod name for PNG paths. Its isolated managed directory contains lifecycle code instead of firing-alignment code. A lifecycle run and a firing run never share a mutable payload. SD/HD and doctrine settings are explicit. All four firing configurations remain a separate mandatory gate; this is the mechanical lifecycle matrix and representative final-art state evidence.

## What it records

The fixture runs 18 cases, each using the actual frozen full256 candidate: save/load, ammo shortage, power shortage, script disable, circuit disable, and freeze/thaw, each during preparing, sustained running, and folding. Every case includes restoration/reacquisition and subsequent real shots. A private piercing magazine keeps the original damage/delivery graphs and adds one source-only shot observer. Ammo accounting checks the observer independently.

It uses native electrical supply through a pole/interface, not the existing fixtures' every-tick energy refill. The shortage case destroys the supply and drains the charged buffer once. Circuit disable uses a wired constant combinator and the turret's native on/off control. Freezing occurs on actual Aquilo with the existing `heating_energy="100kW"` turret and a private radius-6 heat interface controlled with `set_heat_setting`. Actual read-only `frozen`/`is_freezable` values must prove the freeze and thaw; the fixture never assigns them.

There is no runtime API for the native turret animation phase. A diagnostic base layer uses supported `enabled_states` to draw a small barcode below the unchanged real art. The analyzer decodes it at the **actual effective interruption**, not simply at the scheduled command tick. Preparation/folding midpoint commands use the candidate timing. A wrong scheduling or thermal delay fails the gate. `-FoldDelayTicks` and `-FreezeLeadTicks` can be calibrated in a fresh run if the first native observations show that the requested phase was missed. Do not alter reports or loosen the phase check to make it pass.

The baseline also compares legacy and candidate sustained firing over the same 660-tick window. Both must fire 660 native shots with matching ammo accounting. The prototype audit rejects changes to range, cooldown, damage and ammo delivery, health, footprint and other non-graphics entity behavior. Graphs are compared after removing only the fixture's one private observer.

## Save/load isolation

At each save/load phase, the helper requests `game.auto_save` after storing its checkpoint identity. The baseline continues uninterrupted. After it exits, the wrapper verifies the actual `_autosave-<unique-prefix>-<phase>.zip` exists and starts one graphics benchmark for each checkpoint. It verifies that replay did not mutate the checkpoint bytes.

`on_load` only sets a local flag. The next `on_tick` switches to `resume-<phase>`, using the same saved turret and fixture cursor. Replay captures have distinct paths; pre-checkpoint captures keep their baseline paths and are never rewritten. The analyzer compares unit number, exact shot ticks, ammo, energy, orientation, active/disabled/frozen flags and at least 60 resumed snapshots against the baseline at the same world ticks. It retains the actual saves and all four original native reports with hashes.

There is no documented autosave-complete event in installed 2.0.77. If a graphics benchmark suppresses or delays the explicit autosave, or if the next-tick boundary differs from expectations, the tool fails with the evidence retained. It does not substitute a newly created save or fresh turret.

## Commands (do not run during rendering)

First run offline checks:

```powershell
python -B output/minigun-implementation/final-lifecycle-next/test_lifecycle.py
```

After the full candidate and firing atlas manifest are frozen, stage only:

```powershell
powershell -ExecutionPolicy Bypass -File output/minigun-implementation/final-lifecycle-next/invoke-lifecycle-fixture.ps1 `
  -Task Stage -Profile sd -Mode on `
  -CandidateData <full-emission>/candidate-graphics-data.lua `
  -CandidateAssets <full-emission>/candidate-assets `
  -MechanicalData <exact-tested>/candidate-mechanical-data.lua `
  -Anchors <exact-tested>/muzzle-anchors.json `
  -AssetsManifest <exact-full-firing>/candidate-assets-manifest.json `
  -EvidenceContract output/minigun-implementation/final-firing-next/evidence_contract.py
```

Use the canonical evidence-contract path instead once that reviewed code has been integrated. Stage verifies copied PNG hashes/bytes/dimensions against the exact firing manifest; its output identifies a unique managed `RunPath`. The parent owns serial engine scheduling. The wrapper refuses another Factorio/background Blender process, verifies 2.0.77 and source/helper hashes, uses the existing pinned QC dependency seed, creates a hidden engine process, and executes baseline then three checkpoint replays sequentially.

```powershell
powershell -ExecutionPolicy Bypass -File output/minigun-implementation/final-lifecycle-next/invoke-lifecycle-fixture.ps1 `
  -Task Run -RunPath <the-managed-path>
```

Run begins with a fresh create/load, then a conservative 33,400-tick upper bound for the baseline and 2,000 ticks per checkpoint replay. Capture work stops when the bounded case matrix finishes. The fixture holds one active lifecycle turret, its native target/supply, and at most two comparison turrets for parity; it does not put all 18 cases in the scene at once. It captures all frames around effective transitions and recovery, every tick while waiting for thermal/circuit disable, and sparse context frames elsewhere. The exact screenshot count depends on native thermal latency and is recorded after execution. Thermal failure is capped by 1,800 ticks per case.

For an offline reanalysis, choose a **new** output directory:

```powershell
powershell -ExecutionPolicy Bypass -File output/minigun-implementation/final-lifecycle-next/invoke-lifecycle-fixture.ps1 `
  -Task Analyze -RunPath <the-managed-path> `
  -AnalysisOutput output/minigun-implementation/lifecycle-results/<new-analysis-name>
```

## Finalizer review handoff

`lifecycle-observations.json` contains the normalized 18 cases, exact lineage, prototype audit, original-native-report hashes, state pixel decodes, baseline/resume snapshots, and checkpoint-save references. Native PNGs and candidate PNGs are retained with verified hardlinks when available, otherwise exact copies. Paths are long-path safe on Windows. `summary.json` always leaves `lifecycle_gate_passed=false` and `production_approved=false` because native picture review is still required.

Copy `review-template.json` to a new review file. Inspect the actual real-art sequence for each case: before interruption, the effective held condition, recovery and reacquisition; for save/load compare the original and resumed frames. Populate each case's `captures` with actual `{path,sha256}` entries from that raw case's capture list, write concrete observations in `notes`, identify the reviewer, and approve only reviewed cases. Keep `passed=false` and pending/failure entries whenever anything remains uncertain. Connector placement remains user-owned; this circuit case tests behavior without approving placement.

Only after all 18 native checks and image reviews pass, the resulting `esir.minigun.lifecycle-acceptance.v1` file can be used as the `lifecycle` reference in the finalizer request. The visual/consumer acceptance file (icons, HD selection, shadows and state appearance) is separate. The finalizer now also checks each raw report's global automated verdict and every referenced original native report, so a combat-parity or global decoder failure cannot be hidden by selecting individual passing rows.

The current implementation needs its first actual 2.0.77 Stage/Run gate. Specific unresolved engine measurements: thermal/circuit delay vs requested midpoint; native screenshot state-marker registration; autosave behavior in graphics benchmark; default electrical charge startup; and deterministic snapshot equality across checkpoint replay. These are explicit potential failures, not validated claims.
