# ANISETRON UPS optimization — 2026-10-07

Factorio 2.0.77 build 84539; current dirty worktree frozen before this pass under
`.factorio-qc/anisetron/ups-work/baseline`. No deployment, commit or push.
This pass preserves the preceding stability fixes, source art and spritesheets.

## Production changes

- Cache the geometry actually written to owned strand handles, separately from
  per-tick torso prediction. Native entity attachment follows translation;
  heading/angle/length/lift changes still rewrite the projected roots immediately.
- Refresh validity and finite TTL each tick; creation supplies complete geometry
  even after individual handle loss. Clear/stop/teleport/rebuild invalidate caches.
- Reuse the strand table on cleanup and compact finite contact effects in place.
  Fixed startup intensity and saved endpoint-light color avoid redundant writes.
- Take the known exact slowdown cohort directly on ordinary ticks. Keep overdue
  ordered catch-up, the final earliest-deadline scan, and next-tick hit admission.
  Reuse already initialized mobility state on repeated damage events.

The candidate-query sort was reviewed but left unchanged. No targeting,
interpolation, damage, payment, research, cadence, budget, prototype or asset
behavior changes are included. The shared scheduler itself is unchanged.

## Measured module costs

32 normal-quality cathedrals, Standard fidelity, no research bonuses. Every
measured window spans 900 ticks. Three measured paired replays alternate order
after one discarded warmup pair. Values are medians in milliseconds per tick:

| Workload | Inclusive ANISETRON before | After | Change |
| --- | ---: | ---: | ---: |
| Idle | 0.0851 | 0.0831 | -2.4% |
| Moving | 1.0299 | 0.3978 | **-61.4%** |
| Stationary firing | 2.3522 | 2.2968 | -2.4% |
| Moving and firing | 3.2885 | 2.7710 | **-15.7%** |

Movement-visual attribution fell from 0.9929 to 0.3626 ms/tick while moving
(-63.5%), and 1.0605 to 0.3816 while moving/firing (-64.0%). Small idle/stationary
differences overlap run variation and are not claimed as distinct improvements.
Inclusive timers overlap and must not be added. These are instrumented local
module results, not whole-factory UPS or GPU rendering measurements. Setup and
observation contaminate the aggregate engine benchmark, which is not used here.

All four repeated pairs, including warmup, had exact equality for 180 observed
ticks per run, 32 vehicle states at each observation, and 14,816 ordered native
damage packets. The separate exploratory first pair also matched. Stored source,
helper, seed and mod-list hashes are in `ups-work/benchmark-manifests.json`;
paired logs/reports live in `ups-before/pair-*` and `ups-after/pair-*`.
Full timing ranges and medians are in `ups-work/timings.json`.

## Acceptance

- Six fresh native fidelity suites: Off **143/143**, each enabled tier
  **151/151**, **898 checks** total. The six-way normalized mechanics comparator
  passed: payment, damage, quality, reserves and target sequences agree exactly.
- Dense cache/lifecycle parity: **655 sampled ticks for eight vehicles** and
  **3,704 ordered packets** agree exactly against the frozen baseline. Includes
  handle loss/recreation, absent cache fields, raised teleport, turning and a
  visual rebuild during active paid fire; actual strand and light properties
  were compared, including offsets and finite lifetimes.
- Dedicated slowdown scheduler probe: **13/13**. Real native damage advances
  service; repeated hits deduplicate; ordinary and stale cohorts preserve
  deadlines; overdue catch-up services each record once; removal and empty
  updates cannot resurrect pending work.
- Native movement and stacked-slow regression: **28/28**, including manual
  driving, sustained real enemy attacks, retained damage and recovery.
- Beam tracking regression: **47/47**.
- Existing paid v3 save replay at Standard: **84/84**, including inherited Lance
  payload accounting and active/queued payment preservation.
- Fresh focused final-data inspection passes: 144 prerequisite ancestors,
  18 PNG references and ten stat fields. The asset/audio supplement passes:
  128 directions, eight packed sheets, 42 beam variants and both sustained voices.
- Conceptual-link audit: **0 findings**, 46 models / 125 owned sources.
- Preflight: Lua syntax (389 sources), PowerShell syntax, requires, locales,
  asset references and pack versions pass. Full preflight remains red on the
  same **109 protected Python bytecode-cache writes** and **two existing encoding
  findings** (`scripts/qc/singularity-lance/angular-results.json` and
  `temp/anisetron-tracking-fix/blueprint-final.json`). All **150 Python sources**
  compile successfully in memory. The two existing unrelated module-header
  warnings remain. `git diff --check` passes.

Reports remain under `.factorio-qc/anisetron/ups-*`. The source preservation
snapshot records only the intended runtime, annotation, changelog and conceptual
model edits among the 909 previously existing hashed inputs. No captured input
was removed and no graphics or sound bytes changed. The runner gains only the
explicit frozen-code source option; the new UPS fixture is isolated from shipping.

After review, 26 disposable `mods`/`temp` staging directories from this pass were
removed, reclaiming approximately **149.5 MiB** of singly linked files. The
7.57 GiB logical total mostly consisted of shared hardlinks, so it is not claimed
as reclaimed disk space. All reports, logs, saves, source art, immutable cache,
frozen baseline and both repeated benchmark profiles remain. The checked path
inventory and deletion verification are in `ups-work/cleanup-*.json`.

## Limits

No new visual artwork is introduced. This pass compares actual render-handle
properties and existing native behavior checks; it is not a fresh screenshot
certification of all 128 directions. The separate intermittent physical-key
pause reported in the ASS save remains an unresolved reproduction boundary;
this performance patch does not claim to fix or reproduce it.
