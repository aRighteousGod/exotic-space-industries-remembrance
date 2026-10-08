# ANISETRON UPS and behavior parity

This isolated Factorio 2.0.77 workload uses 32 normal-quality public vehicles,
native autopilot and paid native ammunition, one durable frontal enemy per lane,
and no damage research. The lanes are 192 tiles apart. Four measured windows of
900 ticks follow warmup: idle, moving, stationary firing, and moving while firing.
The inherited upgrades and native lifecycle regression remain separate fixtures.

Freeze the main pack's code before editing. The shared runner's `-SourceRoot`
selects that code; graphics/sounds continue using the reviewed repository asset
cache. Do not mutate either staged profile during paired measurements.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName ups-before -SourceRoot .factorio-qc/anisetron/ups-work/baseline -FixtureSource scripts/qc/anisetron-ups -RuntimeTicks 5401
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName ups-after -FixtureSource scripts/qc/anisetron-ups -RuntimeTicks 5401
powershell -ExecutionPolicy Bypass -File scripts/qc/anisetron-ups/repeat.ps1 -BaselineRun .factorio-qc/anisetron/ups-before -CandidateRun .factorio-qc/anisetron/ups-after -MeasuredPairs 3
python -B scripts/qc/anisetron-ups/compare.py .factorio-qc/anisetron/ups-before .factorio-qc/anisetron/ups-after --output .factorio-qc/anisetron/ups-work/parity.json
```

The staged bridge profiles inclusive `anisetron.updater` (`update` in frozen
historical sources), movement visuals, and
slowdown service. Timers are local nonserializable LuaProfilers; nested results
must not be added. Window markers measure simulation ticks independently of
invocation counts; guarded idle calls may disappear. Three measured pairs alternate run order after one discarded
warmup pair. Only one Factorio process runs at a time. The aggregate engine time
includes terrain/fixture setup, observations and instrumentation, so it is **not
a clean whole-engine or whole-factory UPS result**. Report module attribution.

Every 30 ticks the observer records actual position, speed, torso heading,
native slowdown modifiers, ammunition, paid deadlines, target locks, logical
beam endpoints, live core beams, strand visibility/orientation/scale/offset/TTL,
movement-light offsets and fleet budget state. The native damage ledger records
every packet in order. `compare.py` requires exact behavioral equality and
matching simulation windows; rendering IDs and derived cache fields are absent.

`options-edges.lua` adds dense per-tick observations around a destroyed strand,
missing cache fields (old-save shape), raised teleport, a half-turn and a live
visual rebuild during paid fire. Run it against both code sources with the same
fidelity and compare the reports. This tests handle state, not screenshot pixels.
The ordinary native fixture separately covers all six fidelity tiers, fleet
fairness, budgets, Off cleanup, resupply and native vehicle preservation.

`options-mobility.lua` gates only the automatic mobility calls in the staging
bridge, then uses real event ticks and native damaged vehicles to test exact
cohorts, urgent rescheduling, stale duplicates, early calls, ordered overdue
catch-up and final removal. Run with `-RuntimeTicks 20 -Fidelity off`. It restores
automatic service after cleanup and adds no shipping scheduling or test exports.

All scenes, logs and reports stay in ignored `.factorio-qc/anisetron`; the
shipping mod gains no test interface or profiler. See [verification](verification.md)
for measured results and evidence limits.
