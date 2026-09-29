# Sweeping radar implementation and verification

Target: Factorio 2.0.77, ESIR 1.3.40. This helper is an isolated QC mod. Its remote
bridge and optional LuaProfiler probes are appended only to staged copies; they
are never registered by the shipping mod.

## Runtime contract

The two chassis, recipes, finite research branches, limits, circuit fields and
defaults are defined in `lib/sweeping-radar-config.lua` and
`prototypes/sweeping-radar.lua`. `control.lua` remains the sole event dispatcher;
the existing sixteen-step ESIR cycle is unchanged. The radar service receives
`event.tick` every tick and runs its own bounded stages within that dispatcher.
Its init/configuration discovery hooks use `game.tick`, because those hooks do
not carry a tick. No radar event-handler call chain reads `game.tick`.

Coverage preparation tests chunk cells incrementally, buckets them by angle and
flattens one cell or empty bucket per operation. It does not sort a whole disk.
North is zero; increasing angles turn clockwise. Start/stop always describe the
clockwise coverage interval, including intervals crossing north; traversal can
run in the opposite direction. Fixed bearing uses a 32-tile-wide strip.

Global limits per tick are four control services, 64 geometry operations, two
chart submissions/queries, 64 aggregation records, 64 maintenance operations
(including deadline wakeups), two circuit publications and one GUI viewer.
Viewers refresh at most every 15 ticks. Terrain generation has one global
submission per 30 ticks. There are at most 32 outstanding jobs, with at most 16
waiting for generation so exploration cannot consume every existing-terrain
slot. Each radar has at most one job and one unprocessed batch. This is stricter
than the planned allowance of two jobs per radar.

Circular ready lists rotate independently for preparation, observations, generation admission, aggregation
and maintenance. Re-entering records join immediately before the next-to-serve
cursor, after every existing waiter; swap removal and a fixed-head tail would
allow cooldown arrivals to starve older work. Sleeping scans and expiry use
indexed deadlines (at most two per radar), updated in place. The feature-specific indexed heap is needed because
the shared scheduler's delayed buckets do not support cancellation in place.
Shared scheduler GUI queues and module status remain in use. GUI queue compaction
is bounded by pending players, not scan history; its internal copy is not a
constant-time primitive. These limits are operation limits, not time guarantees.

Unpaid generation waiters have one marker per radar and do not hold admitted-job
slots. Their separate circular lane rotates only when generation admission is
available, using the first of the same two observation attempts. New requests
always join behind existing waiters. Fair observation visits alone are insufficient:
a periodic 30-tick admission gate can repeatedly favor the same positions in an
otherwise fair observation ring. QC reports unpaid queue occupancy separately from
the 32-job cap. Requested paid jobs return to ordinary observation processing.

One hidden electrical interface owns both the native fixed standby load and
explicit observation debits. No second scripted standby debit exists. Accepted
observations are paid once, including generation waits and reloads. Explicit
pause, invalid input or freezing cancels unfinished work without refund; the
cursor stays at that chunk and elapsed delay never becomes catch-up work.
Copies and repaired buffers start empty. Upgrades transfer only existing stored
energy, capped by the replacement buffer. Sweeping hardware uses 1 MW standby,
8 MJ/observation, 64 MW input and 16 MJ storage; Phased-array uses 2 MW,
5 MJ/observation, 128 MW input and 10 MJ storage. Helpers always use Normal
quality. Electric interfaces retain saved electrical properties after prototype
changes, so a revision change replaces the helper in bounded control service,
transferring its existing joules up to the new limit. Enlarging a buffer never
fills the new capacity; ordinary helper repair still starts empty.

Only the selected contact policy runs. Queries request at most 129 candidates,
retain at most 128 snapshots and flag the sentinel as incomplete. A working set
holds at most 2,048 distinct contacts. Indexed expiry and nearest heaps update in
place. Reports contain observed positions, not moving entity references.
Completed-pass and current-beam publication swap buffers atomically and retire
the previous buffer incrementally. Recent reporting suppresses validity while a
partially aggregated batch or overdue expiry is outstanding.

Red wire reads individually enabled overrides, including zero; green wire
publishes eleven distinct signals, including separate publication, sample and
nearest-contact ages. Native radar wireless coupling and scanning are disabled.
An accepted pulse latches its scanning acknowledgement through at least one
circuit publication, even if that short pass finishes first. Geometry changes
preserve trigger edge history, so a held high input does not become another edge.
Quality retains native health and adds scripted range, requested capacity and
observation efficiency. Fixed level anchors 0/1/2/3/5 add 0/1/2/3/4 chunks,
multiply rate by 1/1.10/1.20/1.35/1.50 and observation cost by 1/.95/.90/.85/.80.
Intermediate levels interpolate, range rounds down, and outside levels clamp.
Research and quality combine independently; neither changes shared work limits.
The bounded control service refreshes capability caches, preserving selected
manual geometry and the default 12-chunk radius. The ordinary radar is
untouched by this feature. The stock dish is placeholder art; only the rendered
beam indicates completed scanning work.

## Reproduce functional checks

Use fresh run names. The wrapper stages the main pack, existing dependency ZIPs
and graphics companions without deploying to the user's installed mod folder.
The player fixture below is local and ignored; replace it with an equivalent
connected-player fixture on another workstation.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task preflight
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-assets
python -B scripts/qc/sweeping-radar/audit.py
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName gate -Fixture gate -Ticks 1300
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName acceptance -Fixture acceptance -SaveInput .factorio-qc/wtr/player/fixture.zip -Ticks 3550
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName quality -Fixture quality -SaveInput .factorio-qc/wtr/player/fixture.zip -Ticks 1600
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName dump -DumpOnly
python -B scripts/qc/sweeping-radar/inspect_data.py .factorio-qc/radar/dump/script-output/data-raw-dump.json .factorio-qc/radar/final-prototypes.json
```

Persistence uses `-Fixture persistence -Save` to start an isolated private server
and capture a paid 128-candidate batch after 64 aggregation records. Reload its
`saves/radar-transition.zip` with `-Ticks 180`, once normally and once with
`-ForceConfig`. Check fresh `radar-qc.json` reports, not merely engine exit status.

`-Fixture generation-persistence -Save` captures four unpaid generation waiters;
reload with `-Ticks 500` to check ordered admission and one new-price debit.
`-Fixture energy-migration -Save -SourceRoot <pre-change main pack>` captures
partially filled old buffers. Reload with the current pack and `-ForceConfig
-Ticks 100` to verify capability refresh and no free energy when buffers expand.
For this migration, both shared config and runtime must come from the old pack.
The quality fixture includes seven qualities (five native and two QC-only modded
levels) across no research, capacity-only research and all radar research, plus
power accounting, quality upgrades and full-range Watch geometry.

The visual fixture uses `-Fixture visual -Visual -Ticks 480` with a player save.
It exercises the linked open-entity handler for all five modes and captures
coverage, screen GUI and remote view. `-GraphicsArchiveDirectory` accepts an
existing graphics ZIP staging directory when Windows folder path length prevents
graphics loading. The fixture invokes input/GUI handlers programmatically; it
does not constitute a physical mouse/keyboard interaction test.

## Benchmark method

The Heavy infrastructure / Balanced quality update was functionally validated
without new performance benchmarks, at the user's request. The method and old
measurements below are retained as historical material; they do not measure the
new power/quality configuration. The wrapper also uses Factorio's finite-tick
benchmark runner for functional fixtures, without profiling or timing analysis.

Freeze the entire main pack and pass it as `-SourceRoot` on every run. Use
`-Fixture benchmark -Ticks 72010 -SaveInput <same player fixture>` for the complete
24-case matrix: 1/10/50/100 radars, each idle, generated terrain, exploration,
dense contacts, repeated geometry changes and small simultaneous pass completion.
All radar research is enabled; fleets alternate both chassis. Ordinary coverage
uses radius four chunks; completion uses radius one. Fleets use a six-tile grid,
so nearby radars share generated terrain. `-SpreadOut` adds 1,024 tiles between
each radar for a separate exploration-admission stress test. Dense scenes deliberately
overlap 129 hostile turrets per chunk. Churn changes one radar every five ticks.

Alternate `-Baseline` and candidate runs. The baseline retains the same physical
radars, buffers and output helpers but disables the scripted radar service.
Therefore absolute update time includes native helper overhead, while the delta
does not represent installation cost relative to an empty world. QC sampling and
other enabled mods are present on both sides. Keep separate profiler runs with
`-Profile`; never treat instrumented whole-engine time as the release timing.

Each case discards 600 warm-up ticks and measures 2,400 ticks. The analyzer excludes
the final transition tick that constructs the next fixture, leaving 2,399 timing
samples. It reports engine average/p95/worst, attributed stage timings in a
separate run, delivered observations/s, last pass durations, queue occupancy,
maximum pending-job wait, publication/sample ages and unavailable/throttled
samples. It also records the longest sampled gap since an eligible radar's last
observation and each radar's measurement-window observation delta. Active scanning
cases fail if any radar makes no progress in that window; idle and continuous
geometry churn are exempt. Churn can prevent preparation from finishing and
therefore deliver no observations. Pending-job wait is not a
maximum waiting-time guarantee for every scheduler stage. No profiler value
chooses simulation work.

```powershell
python -B scripts/qc/sweeping-radar/analyze.py .factorio-qc/radar/matrix-b7 .factorio-qc/radar/matrix-c7 --output .factorio-qc/radar/analysis.json
```

The recorded sequence is baseline `matrix-b7`, candidate `matrix-c7`, separate
profile `matrix-p4`, repeat baseline `matrix-b8`, repeat candidate `matrix-c8`.
`report.py` assembles those runs, verifies complete ordered matrices, checks
2,399 engine timing samples per case and compares delivered work across repeats
and profiling. `-SingleCase -Population 100 -Workload warm -MeasureTicks 9000
-Ticks 9610` extends measurement to 150 seconds; the dense follow-up uses
`-MeasureTicks 24000 -Ticks 24610` for 400 seconds. These longer runs measure full
passes that are censored by the short matrix windows. A focused exploration run
also asserts the 30-tick global generation-submission spacing; add `-SpreadOut`
and use the 150-second measurement for the 100-radar dispersed case.

The maximum theoretical fleet admission rate is 120 observations/s. Generation,
contact density, circuit churn, power and fair scheduling can lower delivered
throughput substantially. Lower processing cost that comes from fewer completed
observations is not a free UPS improvement. There is no fixed “50 radars under
one millisecond” release claim.

## Validation scope

See [art-validation.md](art-validation.md) for the integrated 256-facing models,
icons, bounded animation service and focused engine/image checks. `-Fixture art`
checks the render/lifecycle contract; `art-visual` captures day/night views and
native inventory icons using a connected-player fixture.

See `quality-validation.md` for the Heavy/Balanced functional results, and
`validation.md` / `results.json` for the earlier measurements. Tests cover engine
prototype loading, stage caps, all modes, overflow/expiry, hostility, native
charting, cloning, blueprints, player fast replacement, helper repair/removal,
force changes, teleports, Aquilo freezing and persistence. The robot test drives
the upgrade transaction and event sequence; it does not fly an actual robot.
No multiplayer desynchronization or native-speaker locale approval is claimed.
