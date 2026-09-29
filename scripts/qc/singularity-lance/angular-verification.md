# Angular acquisition verification

This report belongs to runtime schema **14**, Factorio **2.0.77**. The numerical
contract and maintenance commentary are in [the lance reference](../../../docs/singularity-lance.md).
Historical schema-13 evidence remains in `sweep-verification.md`; it is not the
current angular timing result.

## Delivered results: 2026-09-29

These results predate the follow-up changes that start Wound's +20% on the second
hit and randomize beam middle/end lighting within the existing artwork palette.
Those changes were not rerun through QC or benchmarks, as requested by the user.
Saved reports and source hashes below describe the earlier tested snapshot.

Functional validation passed **6,495 assertions** across eight final mechanics
runs and eight actual-save reload runs. The matrix covers all five fidelity
presets, scaling/flattening variants, and schema-11/12/13/14 preservation,
including legacy Cartesian contacts and a new angular turn with a queued successor.
The analyzer verifies that the final runtime, configuration and scheduler match
the tested candidate, and all seven locales pass key, parameter and UTF-8 checks.

Preflight, `qc-fast`, `qc-runtime` and `qc-assets` completed without errors in
their final results, retaining unrelated repository/mod warnings. The final
Factorio 2.0.77 prototype dump confirms native range, cadence, power and the
upgrade research progression. Graphical acceptance remains with the user.

The user requested wrap-up after the functional checks. The remaining benchmark
batch was stopped, so **performance validation is incomplete**. Four matched
pairs completed a discarded warmup plus five measured runs per version. Direct-only
median update time was **0.908 → 0.921 ms (+1.43%)**. Normal-power was
**8.782 → 9.255 ms (+5.39%)**, with non-overlapping measured ranges; that increase
remains unexplained. Matching per-lance counters, Wound state and pending-contact
snapshots rule out accumulated acquisition backlog at the sampled tick, but do
not establish the source of the added cost. No matched phase profiles finished.

Diagonal, research-flood, wide-native, wide-burst and dense comparisons remain
unfinished. Their fixtures and reproduction commands are present; no tracking-cost
or dense p95 improvement is claimed. The existing unmet dense 1 ms p95 objective
remains unresolved. `angular-results.json` deliberately records `complete: false`
for this incomplete performance matrix. See the [partial measured table](angular-performance.md).

## Reproduction and evidence ownership

Capture the main pack before changing the lance; the local comparison uses
`.factorio-qc/angular/before` for schema 13 and `after` for schema 14. Both snapshots
freeze unrelated integration work at the same existing fixture profile. Overlay
only lance-owned runtime/configuration/locale and the required shared scheduler
helper for the candidate. Graphics remain the existing shipping artwork.

The dedicated runner accepts `-CurrentSource -BaselineSource <snapshot>` and
`-FixtureSource <same helper snapshot>`. The updated helper is frozen at
`.factorio-qc/angular/fixture` for **both** benchmark sides. Source paths and SHA-256
values in `angular-results.json` identify the measured runtime. The analyzer checks
candidate runtime/configuration/scheduler code against the live tree, checks
matching benchmark drivers, and compares finalized technology rows. Ignored
snapshots and raw saves/logs are local evidence inputs, not promised clone assets.

`analyze-angular.py` generates [machine-readable results](angular-results.json)
and [performance tables](angular-performance.md). It does not run the engine.
Completion markers are required; a process exit or a partially written log does
not count as validation.

## Runtime cases

`angular-cases.lua` uses literal reserved deadlines rather than the inherited
synchronous-damage adapter. It covers first acquisition, exact 0/30/45/60/90/120/180
degree timing, clockwise half-turns in every quadrant, opposite-side arcs without
center crossing, angle wrapping, moving goals, separate radius interpolation,
cosmetic rebuilds, full queued turns, compression at 60 ticks, shared synthetic
deadlines, null-target identity, contact-time Wound expiry, and reentrant admission
from a damage callback after the target moved. Engine position rounding is kept
separate from exact mathematical timing examples.

Inherited combat/sweep cases retain independent damage calls, all upgrade values,
range and quality bounds, large/rotated geometry, primary exclusions and reserved
collapse slots, protection in either direction, source/surface removal, research
loss/reset/merge, scripted research, native payment, and exact relative pulse
timing. Standard, Lean, Cinematic, Maximal and Unbounded run the same mechanics.
Scaling disabled, flattening enabled and their combination retain final science
and prerequisite assertions. Core cues remain independent of decorative overload.

Actual schema-11/12 saves exercise old collapse semantics. Actual schema-13 saves
cover counter seven, same-target in-flight Testament and a retargeted in-flight
contact. The retargeted save checks its **legacy Cartesian midpoint** after
migration and then admits a new angular shot. Actual schema-14 saves cover counter
seven, an unlanded eighth shot and a wide turn with a queued successor. Reload
checks registrations, counters, Wound context, deadlines, linked pulses, queue
continuation and independent settlement; it does not merely stamp a schema number
onto a new state table.

## Benchmark method and interpretation

Each matched whole-engine scene uses seed **410728**, 600 updates per run, one
complete discarded warmup run and **five measured runs**. Before/after pairs run
sequentially by scene. Profiles are separate runs with counters/timers enabled;
ordinary whole-engine runs disable them. The profile window is ticks120–599;
counters reset at120 and the final snapshot is600. Nested phase times must not be
added together. Only `shot + update-total` represents total lance script work.

Scenes include no lance, 96 idle lances, direct-only, native normal-power, 96-lance
dense combat, diagonal penetration, unrelated research floods, and two wide-turn
scenes. Wide-native uses four separated, fully supplied lances and alternates
which of two distinct targets is hostile every40ticks, preserving shipped native
power/cadence. Wide-burst injects one paid callback per lance per tick toward
alternating distinct entities. Artificial callbacks are not evidence of native
sustainable firing. Targets have one billion health and each run asserts unchanged
population so deaths cannot silently reduce query load.

The candidate reports reservation, ordinary/locked/first/compressed sweep,
incision selection and damage, first collapse, echo, core cues and cyan lighting
separately. Counts include ordinary/compressed turns and payment-to-contact
latency. Idle and unrelated-research profiles require zero searches, target reads,
Wound cues and status/research entity refreshes. The exact-ID dispatch fixture
rejects unrelated effects before transaction/entity handling.

The dense **1ms p95 lance-script objective remains a limit to report**, not an
assumption. Headless timing excludes GPU/rendering work. Whole-engine figures
include other enabled mods, the helper, operating-system activity and normal
run variation; a local script attribution difference is not a whole-factory UPS
claim. Direct-only increases above5% require a nearby paired repeat with no-lance
control before interpretation.

## Manual graphical acceptance

The user performs visual acceptance. No isolated graphical fixture is requested.
At normal zoom, in day/night and Lean/Standard, inspect:

- Smooth90°/180° arcs around the raised crystal, including clockwise exact ties;
  radial growth only on first acquisition and no inward cut through the crystal.
- Moving-target continuity through angle boundaries, same-target lock and visible
  burst catch-up at the one-second bound; damage agrees with contact.
- Crystal opening, continuous animated beam material, impact bloom, connected
  ground-level forks and no accumulated afterimages or beam disappearance.
- Full30-tick warning after contact, first impact at contact+30 and Testament
  echo at contact+60; inner/outer warning boundaries and terminal cross readable.
- Subdued purple terrain light, five-tick cyan flash and preset cyan afterglow;
  dense96-lance readability without excessive flicker or bloom.
- Compact native baseline-DPS diode row, lore ending above its separator, detailed
  static rows and Informatron’s angle-dependent/contact-relative description.

Headless success establishes mechanics, prototype wiring and native object
lifetime, not aesthetic quality, readable tooltip wrapping or the desired feel
of a sweep in normal gameplay.
