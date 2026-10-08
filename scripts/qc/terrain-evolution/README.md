# Terrain Evolution acceptance

Factorio **2.0.77**, current ESIR main pack. The runner copies source into ignored
`.factorio-qc/terrain-evolution/<RunName>`; shipping code exposes no QC interfaces.
Use fresh run names. Run engine fixtures sequentially: concurrent data loads can
exhaust this workstation's memory and invalidate performance measurements.
New fixture worlds use map seed 42; `-MapSeed` permits an explicit alternative.

## Defaults and work limits

The startup integration, pollution degradation, recorded recovery, mining scars,
native tree stress, slow regrowth, thermal scars and seasonal daylight default on.
Intensity is Restrained; performance is Lean. Hazard switches remain independent
and off. Fulgora never acquires seasonal daylight ownership.

Lean uses a 16-tick service opportunity, 1 cold chunk, 2 active pollution samples,
32 tile candidates, **4 total tile/tree history inspections**, 4 writes with 2
reserved for recovery, and 4 descriptor inspections. Entity queries have their
own cadence: **one capped search allowance every 32 ticks**, with no carry-over.
Per-tick admission is 16 descriptors; depletion gets one separate
32-result coverage query. Limits remain global across all eligible surfaces.
History capacities remain 32,768 tiles and 4,096 trees.

| Preset | Service ticks | Search ticks | Searches / allowance | Histories / service | Writes / recovery reserve | Cold / active chunks | Events / service |
|---|---:|---:|---:|---:|---:|---:|---:|
| Ultra Low | 16 | 128 | 1 | 1 | 1 / 1 | 1 / 2 | 1 |
| Low | 16 | 64 | 1 | 2 | 2 / 1 | 1 / 2 | 2 |
| Lean (default) | 16 | 32 | 1 | 4 | 4 / 2 | 1 / 2 | 4 |
| Balanced | 8 | 16 | 1 | 4 | 4 / 2 | 1 / 2 | 4 |
| Detailed | 4 | 8 | 1 | 8 | 4 / 2 | 1 / 2 | 8 |
| High Fidelity | 2 | 4 | 1 | 8 | 4 / 2 | 1 / 4 | 8 |
| Ultra High Fidelity | 1 | 2 | 2 | 16 | 8 / 4 | 2 / 8 | 16 |
| Custom | Individual limits | Individual limits | Individual limits | Individual limits | Individual limits | Individual limits | Individual limits |

Every allowance is global. A search interval expires only at a service opportunity;
Custom intervals that are not multiples of the service interval round upward to
the next service, without catch-up. Candidate limits stay at 32 (64 for Ultra High
Fidelity), and all named search result limits remain 32. Custom minima of 27
candidates and 2 active samples keep Gaia's atomic regrowth and recovery sampling
reachable. Existing Custom upper ranges are preserved. Choosing another preset
does not discard committed histories when it lowers a storage cap.

The previous measured Lean preset used 8 histories every 32 ticks. The new preset
halves those batches and the interval; its timing has **not** been measured yet.
A complete tile-history inspection sweep still has a theoretical allowance-only
lower bound of 36.4 simulation minutes. Validation, tree histories, query cadence
and protections can increase that time substantially; this is not recovery completion time.
Cold discovery of 100,000 chunks needs at least 7.4 simulation hours at Lean's
maximum discovery rate; surface fairness and saturation can increase that time.
These are coverage tradeoffs, not catch-up work deferred into a later spike.

## Native mechanics and lifecycle

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName native -Lifecycle -Ticks 2800
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName disabled -Disabled -Ticks 120
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName extended -Scenario scripts/qc/terrain-evolution/control-extra.lua -Ticks 10300
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName guards -Guards -Ticks 200
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName gleba-fire -GlebaFire -Ticks 130
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName presets -Presets -Ticks 5000
```

The main and lifecycle suites cover exact recovery, self/external tile events,
history caps, regenerated chunks, native surface clear, calendar geometry,
phase-preserving year changes, external/frozen ownership, Fulgora exclusion and
live settings. The extended fixture tests all four eligible drill types,
legendary coverage boundaries, disallowed drills, finite/infinite resources,
category mismatch, overlap, burst limits and an actual fueled quarry depletion.
It also exercises all six planets, protective terrain/infrastructure/Gaia anchors,
aging, rot, ordinary cliffs and contained ignition.

The extended fixture deliberately gives the independently paced search allowance time to visit
all queued patches. Admission is postponed beyond fixture chunk-generation bursts.
Increasing the deadline does not increase the shipping budget.
The positive Gaia test selects an unprotected location through a staged-only
probe; it never clears authored-site protection to obtain a passing mutation.
Guard fixtures wait for native deferred chunk/surface deletion events, then test
regeneration and ownership. Gleba/fire fixtures exercise every approved wild-tree
species, native wetland habitats and the separate contained/spreading fire modes.

The preset lane changes real runtime-global settings and invokes the registered
settings receiver after each scripted write; native `control.lua` ticks alone drive
the service. It checks all seven tiers and Custom 11/32 cadence, query rotation,
finite per-service counts and total cold/active pollution samples. Run it alone.

## Standalone scheduling screening

```powershell
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/presets-static.lua
python -B scripts/qc/terrain-evolution/audit-locales.py
```

This executes the actual configuration and service/cursor loops with mocked native
boundaries. It checks preset/intensity independence, finite ranges and surface
override rejection, three-chunk tree coverage, two/eight-chunk soil coverage,
mixed Ultra Low tree/tile history recovery, and eight queued scar descriptors.
Independent cursors separate query-bearing turns from intervening validation work;
contested single-slot history turns alternate. These checks catch deterministic
starvation but do not validate Factorio APIs, real terrain changes or performance.
The locale audit checks all runtime settings and enum values against the live
schema, translated numeric limits, English anchors, placeholders and duplicates.

## Genuine persistence

`persistence-control.lua` and `persistence-bridge.lua` use a genuine server save
with owned Nauvis daylight, frozen owned Gleba, externally controlled Vulcanus,
excluded Fulgora and five committed tile histories. `-Checkpoint -PrepareOnly`
stages the profile; the checkpoint controller saves at relative tick 500.
`scripts/qc/terrain-evolution/save-checkpoint.ps1 -RunName <profile>` starts an
unlisted, non-pausing server, waits for the completed native save, and stops only
its own fixture process.

Reload the checkpoint with `-Checkpoint -SaveInput <checkpoint> -Ticks 2`;
repeat with `-Disabled`. The fixture requires a loaded checkpoint, verifies phase,
origin/expected/path depth and boundary ownership, and writes
`terrain-persistence-qc.json`. Startup-off must restore only matching owned
tuples, preserve external/Fulgora values and committed history, and admit no work.

## Connected administrator and Informatron

The `admin/` helper uses actual connected players, native elements, shipping GUI
dispatchers and the Informatron callback. Stage it with `-HelperRoot
scripts/qc/terrain-evolution/admin -SaveInput <disposable-player-save> -PrepareOnly`.
Launch with `scripts/qc/terrain-evolution/run-admin.ps1 -RunName <profile>` and wait for
`TERRAIN_ADMIN_QC COMPLETE`. Require all 37 checks in
`script-output/terrain-admin-qc.json`; a missing player is not a passing test.

Use exact-version installed graphics archives for graphics packs 1-3 and
`scripts/qc/admin-tools/assemble-visual-assets.py` for pack 4. That merges current
checkout overlays without Windows long-path extraction failures. The tested
profile used medium graphics, low video-memory usage and high-quality compression.
The fixture checks controls and idle behavior, not artistic rendering quality.

## Compatibility presence

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName compat-te2 -Compatibility TerrainEvolution2 -Ticks 1200
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName compat-te -Compatibility TerrainEvolution -Ticks 1200
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName compat-dd -Compatibility diurnal-dynamics -Ticks 1200
```

These fixtures use inert named adapters to test presence-based suspension and
boundary non-ownership. They do not claim a full behavioral run of either upstream
ecology implementation or Diurnal Dynamics.

## Operation limits and performance

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName stress -Scenario scripts/qc/terrain-evolution/control-stress.lua -Ticks 34000
python scripts/qc/terrain-evolution/analyze-stress.py .factorio-qc/terrain-evolution/stress
```

The stress profile creates six real planetary surfaces, 10,000 then 100,000 native
generated chunk records, a dense 4,096-tree forest, a full active cache, full tile
history, and burst descriptors. Remote chunk metadata is intentionally synthetic;
this is a bounded-owner stress case, not a claim to simulate 100,000 natural
forest chunks. Native map setup is outside the attributed timing window.
Native `LuaProfiler` samples wrap the real service, including seasonal daylight;
the analyzer reads engine-formatted timings, never Lua wall-clock feedback.

The gates are mean <=0.10 ms/tick, service p99 <=0.50 ms, and service max <=2 ms.
The p99 check is intentionally stricter than taking p99 over all ticks including
idle ticks. Native-spreading fire propagation is outside this script budget.

`run-factory-comparison.ps1` compares prepared `factory-before` and
`factory-after` profiles with the identical copied representative save, matched
settings/dependencies and six runs each (one warm-up, five measured). It requires
no other Factorio process and reports median update-time regression against 2%.
Keep the source/save/dependency provenance alongside results; broad preflight
and a small fresh map are not substitutes for this comparison.
The driver also requires identical native replay checksums across all repetitions
within each profile. `-ReuseBaseline` retains a completed, unchanged baseline log
when only the staged candidate needs another measurement.

## Final loaded data

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName final-data -DumpOnly
python scripts/qc/terrain-evolution/audit-final-data.py .factorio-qc/terrain-evolution/final-data/script-output/data-raw-dump.json
```

The selective audit validates all loaded transition edges, optional absent sources,
native tree/drill prototypes, planetary data, contained-fire limits, seven-locale
key/placeholder parity, duplicate keys and UTF-8 integrity without loading the
entire multi-gigabyte dump into Python objects.

## Evidence boundaries

Passing runtime fixtures does not establish manual multiplayer networking parity.
State, random calls, budget admission and saved iterators use Factorio's
deterministic runtime; real network replay remains a separate acceptance lane.
Authored Gaia bounds are exact only for newly recorded placements; legacy
protection is conservative around surviving distinguishing anchors.

No upstream processing loop is imported. Behavioral references are TerrainEvolution
and TerrainEvolution2 1.0.3, pinned at
58abf0fb90f4654200f0c5ad48bf0a89c80465f0. Credits are in the main pack.
