# Control UPS parity and timing

This pass keeps Factorio 2.0.77 gameplay cadence, queue budgets, target order,
repair timing, and resources unchanged. Use the main Factorio 2.0 pack, not the
sibling 2.1 checkout. No shipping test interface is added.

`invoke-control-ups-qc.ps1` creates a fresh isolated profile in `.factorio-qc/cu/g`.
It copies the selected main pack, records source/dependency SHA-256 hashes,
disables unrelated QC helpers and standalone `extinguisher`, and shares unchanged
graphics companions. Choose a new short run name each time; Windows path length
limits apply to deeply nested prototype names.

## Differential probes

Freeze the main pack before editing. Supply that directory as `-BaselineSource`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-control-ups-qc.ps1 `
  -RunName probe -BaselineSource .factorio-qc/control-ups-20260926/baseline-source `
  -Probe -Ticks 2 -Runs 1
```

The staged pack gets private exports from `exports.json` and a reference copy of
each original module. `suite.lua` swaps and restores `storage.ei`, compares return
values and state after operations, and fails on a mismatch. Derived due-minimum
metadata is excluded from value comparison; its effects are checked through due
decisions and drained-job traces. Reference modules use current shared libraries;
this is valid here because the shared-library changes are strictly additive.

Coverage includes missing/malformed defaults, mutable bucket independence, Tesla
job normalization, preserved Emerald counters, all fumarole cadence decisions,
orbital mixed-key traversal/cursors/removals/cached counts, water tombstones and
legacy queue normalization, delayed queue migration/insertion/draining, and exact
lance clipping results across rotated/degenerate/boundary geometry. These are
engine-run module probes; real entity behavior needs the dedicated fixtures too.

Each microprofile runs six pairs, alternating old/new order. The analyzer discards
the first pair and reports the median of five. These are costs per function call,
not a claim about whole-game UPS. Never sum nested or synthetic probe timings.

## Whole-engine and feature checks

Omit `-Probe` for a profile with no test bridge. Use six runs (one warm-up, five
measured) and feed the identical baseline `fixture.zip` to the candidate using
`-SaveInput`. Run only one Factorio process at a time.

`-Helper` stages an existing fixture directory. Inspect the resulting report,
not just the engine exit code; several helpers intentionally use protected calls.
Use `-Runs 1` for feature acceptance: these report validators expect one scenario.
The six-run convention above applies to timing measurements.
For helper parity, load the same original tick-zero save on both sides and pass
`-ForceConfig` to both runs. It increments only the staged helper version, so both
sources execute the configuration lifecycle. Comparing an unchanged baseline load
against a candidate configuration rebuild can change unit numbers, phase, and
bootstrap work even when gameplay code is equivalent. The original tick-zero
fixture matters: the Emerald helper does not restart checkpoint indices when
loading a progressed save.
The manifest records the fixture hash, staged helper version/file hashes,
mod-list hash, and mod-settings hash when that file is present.
Orbital's full action sequence now extends through relative tick 480. Headless
missing-player GUI checks are skips, not passes.

The lance runner's `-CurrentSource -Baseline -BaselineSource <snapshot>` selects
current mechanics from the frozen source. Candidate `-CurrentSource` uses the
live main pack. Both sides enable the same upgrades. `-NoCounters` disables QC
counters in benchmark scenes; `-Profile` remains a separate attribution lane.
Use the same `-SaveInput` for matched whole-engine timings. The dense scene fires
96 lances at an artificial 60 shots/second each; it is a stress workload.

Water's `-SourceRoot <snapshot>` selects the frozen current mechanics. Omit
`-Baseline`: that older switch tests a migration from before water turrets existed.
The existing performance fixture profiles 6,000 updater calls after 1,000 warm-up
ticks. Its positive-count scene is powered, dry, idle turrets, not combat. Its
whole-engine time includes map setup and is not a mature-save performance result.
Use `-SaveInput <baseline fixture.zip> -ReplayFixture -ForceConfig` on both sources
to replay its tick-zero fixture through the same configuration lifecycle.
Without `-ReplayFixture`, the
existing save-input path selects migration/reload acceptance instead of the full
scene. Independently created maps can shift unit-number-based service phases.

```powershell
python scripts/qc/control-ups/analyze.py --probe .factorio-qc/cu/g/probe/benchmark.log
python scripts/qc/control-ups/check-features.py tesla <baseline-report.txt> <candidate-report.txt>
python scripts/qc/control-ups/check-features.py emerald <baseline-run-dir> <candidate-run-dir>
python scripts/qc/control-ups/check-features.py orbital <baseline-run-dir> <candidate-run-dir>
python scripts/qc/control-ups/check-features.py water <baseline-water-qc.json> <candidate-water-qc.json>
```

Orbital's `--report-baseline-failures` option supports investigation of an existing
helper failure: it compares complete baseline/candidate records, includes the
failed action details, and leaves `acceptance_pass` false. It never converts a
failing assertion into successful acceptance; omit it for the normal strict gate.

The completed pass, accepted changes, measured results, and deliberately retained
behavior are recorded in `verification.md`.
The subsequent orbital, populated-save, queue-reload, and GUI evidence is recorded
in [followup-verification.md](followup-verification.md).

## Follow-up lifecycle and populated-save lanes

`invoke-control-lifecycle-qc.ps1` stages the same selected source using private
bridge/export files, preserving the original load/configuration callbacks. Its
manifest records bridge/export hashes and actual lifecycle arguments. The helper
mod is a version marker; `-ForceConfig` bumps only that staged helper version.
Never edit a bridge between creating and ordinarily reloading its fixture save.

For the Gaia/alien queue fixture, run `-Mode queue-save` on each source against
the same empty input. This starts a local, unlisted, non-pausing server and saves
pending real entity/surface references at relative tick 10. Then load each
source's own `saves/control-ups-pending.zip` twice with `-Mode queue-load`, once
normally and once with `-ForceConfig`. The seeded Gaia producer is deliberately
fixture-only: ordinary new Gaia damage production remains empty in shipping code.

```powershell
python scripts/qc/control-ups/check-lifecycle.py queue <baseline-ordinary> <candidate-ordinary> <baseline-config> <candidate-config>
```

For GUI QC, use `-Mode gui -Ticks 420` with a saved player. `-HeadlessGui` uses
ordinary benchmarking and **asserts real connected-player membership** before
accepting native open/close routes, widget contents, refreshes, or orphan cleanup.
This tests engine GUI semantics, not visual layout or mouse interaction.
`-ClientGui` instead loads the disposable save in a hidden client, waits for the
completion marker, validates its autosave ZIP, then stops only its own process.
Benchmark mode does not write the requested autosave. If long staged graphics
paths fail, `-GraphicsArchiveDirectory <installed-mods>` substitutes exact-version
graphics ZIPs for staged junctions and records their hashes; shipping files are
untouched. Both sources must use identical graphics inputs.

Reload each genuine GUI autosave using `-HeadlessGui -Ticks 60`, both normally
and with `-ForceConfig`. The black-hole repair follows the real configuration
callback; matrix repair is explicitly exercised through its own rebuild helper.
Compare initial runs together, ordinary resumes together, and configuration
resumes together. Require `--expect-reload` for each resume comparison:

```powershell
python scripts/qc/control-ups/check-lifecycle.py gui <baseline> <candidate>
python scripts/qc/control-ups/check-lifecycle.py gui <baseline-resume> <candidate-resume> --expect-reload
```

The populated comparison uses the immutable `_autosave9.zip` identified in the
follow-up report. `prepare-populated-seed.py` reconstructs that save's 269 startup
settings and exact dependency additions from its hash-guarded binary payload.
It intentionally rejects other saves; the offsets are not a general decoder.
Do not use the live `mod-settings.dat`, whose balance/scaling settings differ.

```powershell
python scripts/qc/control-ups/prepare-populated-seed.py `
  --save "$env:APPDATA/Factorio/saves/_autosave9.zip" `
  --base-seed .factorio-qc/singularity-lance/dependency-seed `
  --installed-mods "$env:APPDATA/Factorio/mods" --output .factorio-qc/cu/pop-seed-new
```

Prepare two profiles with `invoke-control-ups-qc.ps1 -PrepareOnly`, identical
`-SaveInput`/`-SeedModDirectory`, and baseline `-SourceRoot` only on the baseline.
Supply no helper, bridge, or probe to this timing lane. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-control-populated-benchmark.ps1 `
  -BaselineRun <baseline-profile> -CandidateRun <candidate-profile>
python scripts/qc/control-ups/analyze.py --alternating <baseline-profile> <candidate-profile>
```

This runs six pairs sequentially, alternates which source runs first in each
pair, and discards pair zero. Every run starts from the same original save.
Run a separate pair with `-BridgePath scripts/qc/control-ups/populated-profile.lua`
for raw population/settings censuses and inclusive module attribution over ticks
121 through 3600. Profiling timers overlap when wrapped functions call each other;
never sum them or use that instrumented run as the whole-engine benchmark.
