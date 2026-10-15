# Terrain Evolution acceptance

Factorio **2.0.77**, current ESIR main pack. The runner copies source into ignored
`.factorio-qc/terrain-evolution/<RunName>`; shipping code exposes no QC interfaces.
Use fresh run names. Run engine fixtures sequentially: concurrent data loads can
exhaust this workstation's memory and invalidate performance measurements.
New fixture worlds use map seed 42; `-MapSeed` permits an explicit alternative.

## Ecology V2 verification

Run the current V2 lanes below in addition to the existing planetary, ownership,
calendar and persistence fixtures. `RESULTS.md` separates current evidence from
historical V1 measurements. No shipping module exposes these fixture interfaces.

```powershell
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-static.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-regressions.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-history-order.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-alerts.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-index.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-reports.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-gui.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/terrain-evolution/v2-population.lua
python -B scripts/qc/terrain-evolution/audit-locales.py
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -V2 -Ticks 2100 -OutputRoot .factorio-qc/ev2-native
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -HelperRoot scripts/qc/terrain-evolution/v2-connected -PrepareOnly -OutputRoot .factorio-qc/ev2-gui
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-admin.ps1 -OutputRoot .factorio-qc/ev2-gui
powershell -ExecutionPolicy Bypass -File scripts/qc/terrain-evolution/run-stress-v2.ps1 -OutputRoot .factorio-qc/ev2-stress
```

The standalone lanes call real owner algorithms with mocked native boundaries:
weighted liveness, low-write Custom contention, migration/report retirement,
observation turnover, full storage, finite bootstrap and commit-time lineage.
Alert mocks cover connected-roster changes, reconnect backlog exclusion, owned-only
cleanup and failed helper creation without exceeding the shared delivery budget.
They do not establish engine timing. The `-V2` native lane checks all four drill
families, working/idle and finite/infinite targets, lifecycle membership, surface
disablement, request retention and unsupported pollutant handling. The connected
client checks the actual Simple/Advanced/Alerts GUI, preference synchronization,
remote surfaces, native alert delivery, visibility, filtering and cleanup.
It also verifies migration from the text launcher to seasonal tree sprites,
all four phase colors, remote-view fallback, and closed-report idleness while
the separate cached launcher lane changes its icon without writing daylight.
Screenshots establish layout; native alert anchor checks establish its map target,
without claiming that automated API checks exercised a mouse click.

The stress helper fills 32,768 tile histories on actual six-planet patches,
4,096 stressed-tree histories, 2,048 active entries and a 4,096-member native drill
cache. Eight additional idle drill admissions demonstrate the cache cap. Its
10,000/100,000 chunks are explicitly metadata-only native iterator populations,
not fully generated or inhabited terrain. Two 16,000-tick windows use the shipping
defaults; a separate 40,000-tick window labels its accelerated Nauvis deadlines
and probabilities, 64 due recoveries and 1,024 pending requests. Fuel, ash and
output maintenance belongs to fixture setup, outside updater profiling. Native
spreading is excluded from default Contained timing.

`run-stress-v2.ps1 -TraceEcology` stages nested component and primitive profilers
for a short part of the accelerated window. It separates history insertion,
chunk iteration, discovery bookkeeping and native queries. These diagnostic
timers and logs add overhead; the runner deliberately skips release timing
analysis for that mode. Shipping code never contains these profilers.
`-TraceOffsetTicks 30000` moves that diagnostic window later in the burst phase.

Domain-set lookup indexes use 256 deterministic buckets while retaining their
dense record arrays. Old flat lookups remain readable during incremental
conversion, sharing the four-record migration allowance. Conversion reports
count record-schema and lookup steps separately when both are required. Normal
updates and removals retire their old lookup steps without scanning either map.
Finite report publication reuses a scalar payload and suppresses identical
updates between 60-tick heartbeats. Progress and state changes publish immediately;
missing-registry adoption and retired-ID rejection retain their existing semantics.
The index fixture checks migration, churn, swap removal and registered-metatable
shape; native checkpoints establish actual save/load behavior. Bucketing limits
ordinary hash-table churn, without claiming a strict worst-case bucket size.

The owner checks at most eight observation slots per selected class, resuming
its deterministic cursor next time. This bounds repeated empty-ready searches
without enlarging any preset allowance; it can delay a mature observation by
additional class opportunities. Ticket windows already include the complete
64-slot cohort and longest class gap. No missed probability rolls accumulate.

For whole-engine comparison, stage `factory-v2` twice from the same existing
factory save, set only its private `profile.lua` enabled flag false/true, create
each checkpoint with `save-checkpoint.ps1 -NoPersistenceBridge`, then use
`run-factory-comparison.ps1 -Checkpoint -BeforeRoot ... -AfterRoot ... -ResultPath ...`.
The helper normalizes current schema defaults and clears ecology overrides in
both private saves. It asserts the effective runtime activity flag matches its
profile, requires zero enabled surfaces in the disabled profile, and records
startup integration separately. Record the save identity, surface/entity population and
dependency exclusions. Six runs per profile discard the first warm-up and compare
five-run medians; replay checksums must agree within each profile.

## Defaults and work limits

The startup integration and all ecology switches default on, including mining
recovery, aging/decay, shoreline changes, cliffs, blood effects, paving corrosion
and seasonal ecology. Wildfire defaults to Contained; native spreading remains a
selectable alternative. Intensity is Restrained; performance is Lean. Each feature
remains independently configurable. Existing saved settings and surface overrides
retain their selected values. Fulgora never acquires seasonal daylight ownership.

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

The historical Lean preset used 8 histories every 32 ticks. The current preset
halves those batches and the interval; current timing evidence is in `RESULTS.md`.
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
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName presets -Presets -Ticks 8000
powershell -ExecutionPolicy Bypass -File scripts/invoke-terrain-evolution-qc.ps1 -RunName wildfire -Wildfire -Ticks 16000 -DumpAfter
```

The main and lifecycle suites cover exact recovery, self/external tile events,
history caps, regenerated chunks, native surface clear, calendar geometry,
phase-preserving year changes, external/frozen ownership, Fulgora exclusion and
live settings. The main fixture checks loaded default-on settings first, then
explicitly disables unrelated ecology modules for its fixed-deadline scar/recovery
phase. That phase does not measure coverage with every module active.
It writes a compact `terrain-defaults-snapshot.json` with loaded settings and
applicable transitions before overrides. This can verify defaults when a full
`--dump-data` export exceeds available memory; it is not a complete prototype dump.
The extended fixture tests all four eligible drill types,
legendary coverage boundaries, disallowed drills, finite/infinite resources,
category mismatch, overlap, burst limits and an actual fueled quarry depletion.
It also exercises all six planets, protective terrain/infrastructure/Gaia anchors,
aging, rot, ordinary cliffs and contained ignition.

The extended fixture deliberately gives the independently paced search allowance time to visit
all queued patches. Admission is postponed beyond fixture chunk-generation bursts.
Increasing the deadline does not increase the shipping budget.

The elapsed wildfire lane checks autonomous ignition with degradation enabled in
dense forests, both modes, native tree burning/descendant identities in Spreading,
contained nonspread/removal within 600 ticks, and per-service query caps. It also
checks Off, zero probability, clean samples, infrastructure protection, mode
rearming, optional-hazard fairness and first-tick repair of legacy derived caches.
Ownership checks cover exhaustive expired-record cleanup, settings preserving
earlier service deadlines, changed cadence and last-surface disablement.
Contained retains finite native ground flames; it does not invoke native forest
propagation. A sparse forest need not have a reachable native spread neighbor.
The fixture retains the default ignition radius of two tiles, replenishes pollution
in its two controlled chunks, and observes each autonomous phase for at least
1,200 ticks after ignition, with a 3,600-tick phase limit. This verifies ignition
and fire mechanics under sustained exposure, not default wildfire frequency.
Attempt, fuel, protection, creation and target-health diagnostics distinguish a
missing opportunity from a failed ignition or native damage result.
The isolated wildfire bridge suppresses deferred authored-site generation on
fixture Nauvis. Otherwise that unrelated producer can insert protected alien
flowers into the controlled forest after setup. The production protection rules
remain enabled; the planetary guard suite separately checks authored-site safety.
Native pollution greying alone is not accepted as proof that fire damaged a tree.

Use a newly registered housekeeping payload with -OutputRoot for task-owned runs.
-AllowRunningFactorio is an explicit opt-in for isolated mechanics fixtures while
the user's game is running. These are not valid workstation timing comparisons;
the default runner still refuses concurrent Factorio processes.
The positive Gaia test selects an unprotected location through a staged-only
probe; it never clears authored-site protection to obtain a passing mutation.
Guard fixtures wait for native deferred chunk/surface deletion events, then test
regeneration and ownership. Gleba/fire fixtures exercise every approved wild-tree
species, native wetland habitats and the separate contained/spreading fire modes.
Direct entity-action fixtures retain the same resumable descriptor across bounded
substeps. Synthetic tree exposure is injected into the V2 observation record,
separately from the native check that Gleba spores are unsupported pollution.
Full fire tokens and ignition throttling defer a valid request; they do not mark
it conclusively ineligible.

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
The suite checks default-on modules and independently retained disabled selections
across every intensity and performance preset. Independent cursors separate
query-bearing turns from intervening validation work;
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
The V2 checkpoint also saves all four registered lookup-index facades and a mixed
legacy/new lookup. Reload checks their native metatables, remaining conversion
work, lookups and mutation. Reloading an older flat-index checkpoint separately
verifies incremental adoption without inventing historical observations.

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
