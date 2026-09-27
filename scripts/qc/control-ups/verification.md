# Control UPS pass — 2026-09-26

Target: main ESIR 1.3.40 pack on Factorio 2.0.77. Baseline commit:
`77940728839eedf200ce5badc94f284eee58e311`. The initially clean main pack was frozen
before edits in `.factorio-qc/control-ups-20260926/baseline-source`; its manifest
records all 665 source-file hashes. The sibling Factorio 2.1 checkout was excluded.

## Accepted changes

| Area | Removed cost | Preserved contract |
| --- | --- | --- |
| Neutron collector | Eager default maps and sixty wire buckets on warm initialization | Nil-only repair, per-field table independence, rebuild timing |
| Tesla legacy | Empty synchronization-job normalization/allocation | All nonempty job normalization and lifecycle repairs |
| Emerald tank | Rebuilding scalar counter defaults on every ensure | Existing counters, fresh independent mutable runtime tables |
| Vulcanus fumaroles | Future-bucket scans on ticks outside its existing cadence | Bootstrap and eligibility paths, all service ticks |
| Orbital combinator | Repeated full key scans during long unsuccessful probes | Original ordering, unusual surface cursor progression, wrap, cached budgets, live removals |
| Water turret | Empty delayed result arrays, empty FIFO normalization, repeated position reads | Power checks, 32-job fire budget, tombstones, search ordering, pulse timing |
| Firefighting | Duplicate entity validity check in turret suppression | Eligibility and handheld suppression semantics |
| Gaia and alien spawner | Repeated scans of future delayed buckets | Legacy migration, same due jobs and drain order, immediate rescheduling |
| Singularity lance | Two temporary corner arrays for diagonal corridor clipping | Identical arithmetic, clipping edge order, target sorting, damage and visuals |

The shared scheduler gained an earliest-due helper. Gaia/alien metadata uses nil
for unknown, false for empty, and a tick for known work; all internal writers
maintain it and configuration changes invalidate it. Orbital sorted key snapshots
last only one call and are built after two unsuccessful iterations for collections
of at least eight; immediate hits and exotic-key fallback keep their old path.

`control.lua` remains the sole dispatcher. The 16-step cycle, budgets, dispatch
order, research routes, event ownership, and settings are unchanged. Increasing the
existing scheduler modulus directly would change service ticks; this pass found its demonstrated
savings without doing so. No shipping QC interface was added.

## Behavior evidence

- Factorio differential run `cu/g/cp1`: **86,452 checks passed**. Coverage includes
  repair/default cases, counter preservation, all fumarole cadence decisions,
  mixed-key/cursor/removal orbital traversal, water malformed/empty queues and
  tombstone budgets, due-cache migration/schedule/drain/reschedule, and exact lance
  geometry. The 665 shipping source files and current suite matched that run's
  manifest/staged suite during final review.
- Lance mechanics `cu/l/bm` and `cu/l/cm`: **119 assertions passed on each side**.
  Dense benchmark runs `cu/l/bd` and `cu/l/cd` also produced **72 exactly matching
  runtime snapshots**, including pending impacts, wound meters, and force caches.
- Water mechanics `wtr/cu-bm` and `wtr/cu-cm`: **59 cases passed on each side**.
  Independent map creation changed unit-number phases in two timing details;
  matched configuration replays are the authoritative comparison below.
- Matched water `wtr/cu-bmatch` / `cu-cmatch`: **59 passing cases and complete
  reports exactly equal**, including acquisition count and blackout timing.
- Matched Tesla `cu/g/bt2` / `ct2`: **17 exactly equal snapshots**, covering four
  research completions and drained synchronization queues.
- Matched Emerald `cu/g/be2` / `ce2`: **six exactly equal combat snapshots** through
  tick 1,200, including entity identity, due ticks, shots, and damage counters.
- Matched orbital `cu/g/bo2` / `co2`: **all 31 complete report records exactly
  equal** (setup, 12 checkpoints, 16 actions). Fourteen action expectations pass.
  Two existing assertions, `rebind-fairness-lane-first` and
  `rebind-fairness-lane-second`, fail identically on the frozen baseline and the
  candidate: uplink B selects Alpha rather than the helper's expected Gamma/Beta.
  This demonstrates parity but **does not pass full orbital acceptance**. The
  validator's explicit `--report-baseline-failures` mode retains those failures
  and compares complete records; ordinary acceptance still rejects them. The 28
  GUI samples are honest `missing-player` skips. The fixture already leaves Gamma
  held by uplink A's sticky lease, while selector A remains manual Alpha; the
  existing manual-before-policy priority therefore sends Alpha to uplink B both
  times. Its authored state does not exercise the rotation that it asserts. That
  fixture setup needs a separate repair; production priority stays unchanged.

The differential suite's persisted-state check copies warm due-cache state; it is
not a complete engine save/reload test of a naturally populated Gaia/alien queue.
No connected-player GUI session or manual rendered review was performed. GUI
fallback changes were therefore left out of the production patch.

## Timing evidence

Isolated Factorio LuaProfiler probes, median of five measured pairs after one
warm-up pair, with alternating baseline/candidate order. Values are microseconds
per call, **not whole-factory UPS percentages**. Never sum these synthetic timings.

| Probe | Baseline us | Candidate us | Cost reduction |
| --- | ---: | ---: | ---: |
| Neutron warm ensure | 10.224 | 1.911 | 81.3% |
| Tesla empty jobs | 0.687 | 0.522 | 24.0% |
| Emerald warm ensure | 16.555 | 12.148 | 26.6% |
| Fumarole future work, off cadence | 0.653 | 0.327 | 50.0% |
| Orbital no due work, 8 banks | 15.548 | 13.964 | 10.2% |
| Orbital no due work, 64 banks | 947.963 | 168.004 | 82.3% |
| Orbital no due work, 256 banks | 15089.183 | 837.438 | 94.5% |
| Water active root, empty work | 1.570 | 0.827 | 47.3% |
| Gaia future buckets | 34.743 | 0.491 | 98.6% |
| Alien-spawner future buckets | 34.139 | 0.571 | 98.3% |
| Lance diagonal clipping | 2.662 | 1.996 | 25.0% |

Orbital immediate-hit/single-bank paths were near unchanged: roughly 17–38 ns
slower in the small cases, while large immediate-hit cases were slightly faster.
The useful result is avoiding repeated scans when many banks are not due. Gaia's
normal new-damage producer is currently empty, so its queue gain applies to legacy
or externally queued work, not an ordinary active hot path.

The 1,000 powered, dry, idle water-turret fixture profiled 6,000 updater calls after
1,000 warm-up ticks: **5,945.358 ms baseline / 5,331.621 ms candidate**, about 10.3%
less. This is one profile per side on independently created fixture maps, not a
confidence interval or combat benchmark. See `wtr/cu-b1000` and `wtr/cu-c1000`.

Whole-engine idle runs used the same saved world, 3,600 ticks per run, one warm-up
and five measured runs: median **0.306094 ms/tick baseline / 0.305838 candidate**.
The ranges overlap (baseline 0.305309–0.310777; candidate 0.300561–0.310655), so
there is **no demonstrated whole-engine idle improvement**. See `cu/g/bi` and `ci`.

The dense lance stress run uses 96 lances at an artificial 60 shots/second each,
960 targets, and disabled profiling/counters. Six runs per side, 3,600 ticks each,
discarding the first: median **52.739719 ms/tick baseline / 52.154264 candidate**,
about 1.1% lower. Ranges overlap (52.119977–53.371458 baseline;
51.270940–53.116282 candidate), so this is a modest observed difference, not a
demonstrated general speedup. Both sides loaded the same `cu/l/bd/fixture.zip`.
This mostly exercises axis-aligned geometry, whose fast path was already cheap.

Raw probe summary: `.factorio-qc/control-ups-20260926/probe-results.json`.
Per-run source/dependency manifests and logs remain under `.factorio-qc/cu`.

## Verification and deferred options

ESIR preflight passed Lua syntax (350 files), PowerShell parsing, references,
encoding, locale, assets, and pack-version checks. The wrapper's Python bytecode
step hit the protected `.codex` cache path; redirecting that cache then hit Windows
path length. All 77 Python source files were instead compiled in memory and passed.
`git diff --check` passed. Final parsing passed for the three modified PowerShell
runners, both Python analyzers, and the corrected orbital helper's Lua files.

The older orbital fixture needed a forward declaration repair, actual electrical
coverage for hidden sensors (including platforms), and cross-mod-safe runtime
presence detection. These changes are confined to its QC helper. Initial orbital
action failures and asymmetric Tesla/Emerald snapshots were rejected as acceptance
evidence rather than normalized into a pass.

Lance top-K selection remains deferred: the measured candidate pool is close to
the victim cap, and preserving exact sort-tie behavior needs a fallback that can
erase savings. GUI fallback optimization needs a connected-player repair/lifecycle
fixture. No cadence relaxation or reduced responsiveness was accepted.
