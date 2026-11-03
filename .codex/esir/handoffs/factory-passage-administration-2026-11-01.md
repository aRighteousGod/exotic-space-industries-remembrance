# Factory passage administration and update pace — 2026-11-01

Implemented under **ESIR 1.4.03**, with exact **Factorio 2.1.24** verification.
The six startup controls retain their meanings. This extension adds one save-wide
runtime integer, `ei-factory-passage-update-budget`: **1–1,024**, default **256**.
Mod settings → Map and Administration → Map settings → Global rules edit the same
native value. Administration adds no separate override.

## Behavior and ownership

The [configuration owner](../../../exotic-space-industries-remembrance/lib/factory-passage-config.lua)
defines the setting and bounds. The
[passage owner](../../../exotic-space-industries-remembrance/scripts/control/factory-passage.lua)
uses a persisted 6:1:1 service rotation for dirty endpoints, occupied-joint retries
and recipe-change checks. Every attempted queue operation consumes budget, including
stale or unsuccessful work. Retry/check limits are each `ceil(budget / 8)`, bounded
by their starting populations; dirty endpoints borrow unused allowance. The cursor
preserves progress at budget 1 and survives ordinary load.

**Recipe-change checks** compare recipe name, quality and fluid-port count on
eligible pipe-adjacent crafters. A changed signature queues connection reconciliation;
an unchanged signature performs no topology query. These checks continue as ordinary
maintenance and never keep a rebuild unfinished.

Lower budgets reduce queued work per tick and delay collision updates. Higher values
drain the queue faster. This is a work-item limit; it does not guarantee milliseconds
per tick. Synchronous discovery and immediate helper cleanup remain outside its cap.

Factory passage is an explicit Administration owner, with pure scalar summaries,
bounded Inspect and the authorized repair action, including
`/ei-admin-repair factory-passage`. Diagnostics distinguish configured/effective modes,
master disablement, non-ESIR modes and Squeak Through 2 precedence. Queued joint checks
and joints known to be occupied by characters are separate counters.

Explicit reconstruction reports synchronous `world-discovery` and asynchronous
`joint-reconciliation` separately, under owner `factory-passage`, global scope.
Reports retain unknown totals and do not invent endpoint percentages or ETAs.
Occupied-only work remains visible in Diagnostics while leaving the public active-work
window. An accepted repair request is a dispatch receipt; it is distinct from eventual
queue completion. Repeated repair supersedes the previous report before replacing
state. Budget changes preserve queues, report identity and progress.

The existing compatibility hook remains available:
`remote.call("ei_factory_passage", "refresh_entity", entity)`.

## Evidence

The original geometry, native-first fallback and movement demonstrations remain in
the [factory-passage acceptance handoff](factory-passage-acceptance-2026-11-01.md).
This extension leaves entity presentation, death effects and connection coordinates
unchanged.

The final Administration run is `c2b020b85cee47a2b0db92e2cbad75b0`:

- Native integer definition/default/bounds, the actual Administration editor,
  invalid values, authorization, stale native-setting conflicts, read-back and
  setting changes without helper churn passed.
- Pure summaries, absent-state reads, bounded inspection, localized repair/inspection
  receipts and detached diagnostic receipt tables passed.
- All eleven budgets — 1, 2, 7, 8, 31, 32, 63, 64, 65, 256 and 1,024 — exercised
  dirty, occupied-joint and recipe-check progress with the combined native cap.
- Active repair, a live pace change, occupied waiting, native character departure,
  completion despite permanent watchers and repeated-repair supersession passed.
- Repair preserved all **800 pipe identities** and the fixture's fluid state.
- A separate process loaded the exact saved checkpoint and verified the nondefault
  cursor, backlog, active report and native budget. Its checkpoint SHA-256 is
  `41940d9ddd23b9fc61650d56daaa7483f0edd22caad13fd6cbca4757fac49685`.
- The final native GUI captures show the budget row, public active work and the
  waiting-only Administration view. They are engine screenshots, not mockups.

The full-profile populated-save matrix passed **all 16 groups**: three pipe modes,
all six directed mode changes, ordinary reload, master disable/re-enable and all
four category switches. Acceptance binds each transition to its actual source-save
hash and original mode/master state, verifies category exclusions in final prototypes,
and requires completed reconciliation with the correct effective mode/reason.

[Native evidence archive](../../../.factorio-qc/managed/c2b020b85cee47a2b0db92e2cbad75b0/evidence.zip)
contains the administration/mode/combined acceptance receipts, static checks,
source manifests, checkpoint hashes and native logs. Final rendered captures:

- [Map settings control](../../../.factorio-qc/managed/c2b020b85cee47a2b0db92e2cbad75b0/administration/map-settings.png)
- [Active rebuild](../../../.factorio-qc/managed/c2b020b85cee47a2b0db92e2cbad75b0/administration/active-rebuild.png)
- [Character-clearance waiting](../../../.factorio-qc/managed/c2b020b85cee47a2b0db92e2cbad75b0/administration/waiting-rebuild.png)

Separate exact-source runs:

- `b1017e6fa09a4f7ab69bf5f2a6ba7d5b`: all three Base movement modes passed after
  isolating each turret-port walker in a separate turret copy, with both ports
  connected. The old fixture let two characters collide before the measured joints;
  the Base and ESIR paving speeds changed that interference. The failing exploratory
  log and the corrected passing scenes are retained, rather than weakening the
  movement assertion or excluding the turret.
- `946993e42ce34cbe9cb353288cf49511`: the actual Squeak Through 2 **0.2.0** package
  takes precedence, with no ESIR collision mutations, helpers or active rebuild work.
- `31c1f45d1f5044bc85a648f689a21010`: after promoting the verified fixture fixes,
  the checked-in fixture passed all three isolated movement modes and ordinary
  save/reload again. Its [archive](../../../.factorio-qc/managed/31c1f45d1f5044bc85a648f689a21010/evidence.zip)
  contains the four-case acceptance and `delivered-source-verification.json`, binding
  the delivered fixture files to all four runs and the delivered production files
  to the full Administration run and both forty-trial performance batches.

Offline checks use the real production owner/scheduler with mocked native boundaries:
**306** fairness/status checks, **10** setting validation/conflict/rollback checks and
**41** report-lifecycle checks. Surface import/deletion report ownership and inactive
mode retirement are covered there. They are not native surface-import evidence.

## Matched performance

Base plus the exact passage modules and shared scheduler, Factorio 2.1.24, AMD Ryzen
7 5700X3D / Windows 10. Five independent processes per case alternate Vanilla/ESIR
order, using seed 137013 and settled checkpoints at tick 512. Each idle trial measures
6,000 updates; each burst measures 1,000 updates while removing/restoring the same
1,000-pipe row. Source/checkpoint hashes and process isolation are checked. Overlapping
engine runs are rejected and retried.

Budget **256**, run `70bcd56319f94466ad58555760760700`: **all 40 trials passed**.

| Pipes | Vanilla idle mean | ESIR idle mean | Added mean | Helpers | Initial queue drain |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 0.103310 ms/tick | 0.110053 ms/tick | 0.006743 ms/tick | 18,990 | 40 ticks |
| 100,000 | 0.112179 ms/tick | 0.127222 ms/tick | 0.015043 ms/tick | 198,900 | 391 ticks |

Every paired idle delta and both five-run means pass the agreed larger-of-5%-or-
0.1-ms/tick threshold. The applicable allowance here is 0.1 ms/tick. Idle topology
queries and helper churn are zero. Burst removal and construction each drain in
20 ticks in every ESIR trial.

| Pipes / budget 256 burst | Vanilla mean | ESIR mean | Worst Vanilla tick | Worst ESIR tick |
|---:|---:|---:|---:|---:|
| 10,000 | 0.727838 ms/tick | 2.623549 ms/tick | 647.019 ms | 705.158 ms |
| 100,000 | 58.647117 ms/tick | 60.934207 ms/tick | 59,321.291 ms | 59,982.782 ms |

The deliberately single-tick mutation of the large connected grid is expensive in
both modes. Burst cost is separate from the steady-state gate. ESIR idle-process
peak working sets were 480.2 MiB / 1,465.9 MiB at 10k / 100k; sampled private maxima
were 431.0 MiB / 1,484.0 MiB. These are whole-process measurements, including load,
not isolated Lua allocations. Private bytes are sampled every 200 ms.

Budget **1,024**, run `fda38c3acc0b465eb56a6733369d03fe`: **all 40 trials passed**.

| Pipes | Vanilla idle mean | ESIR idle mean | Added mean | Helpers | Initial queue readiness |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 0.102809 ms/tick | 0.108642 ms/tick | 0.005833 ms/tick | 18,990 | By tick 11 |
| 100,000 | 0.104858 ms/tick | 0.127872 ms/tick | 0.023014 ms/tick | 198,900 | 98 ticks |

Every paired idle delta and both means pass the same 0.1 ms/tick allowance. The
readiness probe starts at tick 11, so the 10k value is an observed upper bound,
not an exact eleven-tick drain. At both network sizes, removal and construction
queues drain in **5 ticks in all five ESIR burst trials**, with a maximum of
1,024 attempted operations per tick. Settled topology queries and helper churn
remain zero.

| Pipes / budget 1,024 burst | Vanilla mean | ESIR mean | Worst Vanilla tick | Worst ESIR tick |
|---:|---:|---:|---:|---:|
| 10,000 | 0.684748 ms/tick | 2.543335 ms/tick | 567.595 ms | 681.458 ms |
| 100,000 | 58.737062 ms/tick | 60.877859 ms/tick | 60,323.343 ms | 59,779.289 ms |

At budget 1,024, ESIR idle-process peak working sets were 478.1 MiB / 1,468.2 MiB
at 10k / 100k; sampled private maxima were 427.4 MiB / 1,488.8 MiB. Burst-process
working-set maxima across both budgets reached 587.8 MiB / 1,556.2 MiB. These
whole-process numbers and the synchronous native burst costs are separate from
the queued-work limit.

**All 80 matched trials passed.** The
[budget-256 archive](../../../.factorio-qc/managed/70bcd56319f94466ad58555760760700/evidence.zip)
and [budget-1,024 archive](../../../.factorio-qc/managed/fda38c3acc0b465eb56a6733369d03fe/evidence.zip)
retain acceptance summaries, all trials, per-process memory/timing observations,
settled-checkpoint identities and exact production hashes. The hashes of all five
measured production files match the delivered source. The private actor/load
fixture fixes are promoted separately; they do not change those production files.

## Boundaries and delivery

All eight locales contain the new setting, passage diagnostics, repair/inspection
receipts and rebuild messages. Existing generic Administration shell translations
outside the added feature are unchanged. Locale completeness/encoding checks do not
constitute independent native-speaker review.

Focused Lua/Python parsing, blueprint coverage (**66 models, 209 owned sources,
zero findings**) and module headers (**zero findings**) passed. The broad preflight
passed 11 checks; its unrelated known failure is suspected mojibake in
`scripts/qc/singularity-lance/angular-results.json`. The compact native archive
contains the full preflight and a small static receipt.

Native settings ownership/API writes and the Administration editor are tested; no
manual interaction with Factorio's built-in Mod Settings screen is claimed. Hosted
save/reload is tested; **two-client multiplayer synchronization is not tested**.
Surface-import report transitions are source-reviewed and mocked, not native import
coverage. Arbitrary silent connection changes still require the compatibility hook.

No deployment, issue posting, commit or version bump is included. Concurrent work is
preserved. Successful task-owned runs were closed and compacted, retaining the three
final GUI captures separately. The superseded setup `3da4dbb9553c41ac9315adcbd4ccad58` was released after
investigation but remains protected by source-change cleanup checks; it was not
forcibly deleted or counted as accepted evidence.
