# Factorio 2.0.77 verification, 2026-09-24

## Fire overlap revision, 2026-09-25

Same-type clarification: ground-fire cleanup now removes only different
prototype names. Identical patches retain their native coexistence/refueling
behavior; attached stickers still have the separate one-per-target cap. The
Original/enabled follow-up passed all 78 checks, including survival of same-type
patches at 0.5 and exactly 1 tile, and removal of different types in that radius.
The parallel 16x/disabled follow-up exhausted system memory during prototype
loading and did not reach runtime; its earlier 76-check result below predates
this narrow same-type exception. The fixture now respects declared incompatible
mods when importing optional dependencies from its cached seed.

The isolated creation proof passed before runtime integration. Stickers are
attached when the event runs; destroying older effects inside the handler is
safe. Repeated native refueling emitted no new creation events and retained the
same fire entity. Existing-sticker reuse likewise need not emit a creation event.

All five thrower-performance profiles passed with adaptation enabled and
disabled: ten 620-tick runs, each with 76 checks. Final prototype audits found
notifications on every supported creation reference, including the performance
copies. Runtime coverage includes all 22 supported sticker and 22 ground-fire
identities, same-tick ordering, saved overlapping effects, cross-force cleanup,
distances 0/0.5/1/1.015625, unrelated effects and tree-fire preservation, all 11
native turret identities, handheld/tank streams, and no ground fire from tanks.
The idle adaptation guard remains false after work completes.

Rapid alternation produced sticker damage in every profile. After alternation
stopped, measured sticker damage intervals were 10 ticks (Original), 20 (2x),
and 30 (4x/8x/16x). Refueling kept the original patch, increased its sampled
damage from 2.1667 to 13, and extended burning past the unfueled control. The
separate 6,600-tick effects fixture passed all ten fuel lifetime comparisons;
both mixed-fuel and single-fuel overlap now leave one patch.

Lua/PowerShell syntax, require/asset references, encoding, locales, pack versions,
and scoped whitespace checks passed. The broad preflight wrapper could not
complete Python bytecode-cache writes under the restricted/long Windows paths;
read-only compilation of 50 support/asset Python scripts passed. Its two existing
module-header warnings are unrelated. No rendered visual review or new external
entity-reference compatibility claim is made for this revision.

## Earlier fuel/adaptation verification

Scheduler revision: the dispatcher now has 16 steps, split 1–8 and 9–16, with
flamethrowers serviced only on step 16. Overdue retry buckets are drained on the
next scheduled visit. The population timing table below records the preceding
every-tick implementation and is historical, not a benchmark of this new cadence.
The scheduled runtime recheck passed in Factorio 2.0.77 with B=10 enabled and
B=1 disabled. Both 620-tick runs assert that checks and attempts occur only on
step 16, preserve the per-visit caps, recover forced failures through overdue
retry buckets, complete native robot lifecycle checks, and finish with no idle
dispatcher work after registry cleanup or disabled restoration.

Full-budget revision: replacement attempts now use the complete configured B,
matching the fuel-read cap on each step-16 visit. Fresh 620-tick enabled and
disabled runs at B=10 passed. Disabled restoration reached ten attempts in one
visit, proving the increased allowance; both runs passed the caps, scheduled
cadence, rollback, fluid/state preservation, robot lifecycle and idle checks.
All seven tooltips document the full cap and 16-tick cadence, and passed UTF-8
and locale-key checks. The historical profiling table below predates both the
cadence change and this replacement-budget increase.

`qc-fast` completed successfully with existing repository warnings. The final
prototype and seven-locale audit passed against its engine-generated dump.
Unrelated Spidertron, railgun, asset and other worktree changes were preserved.

The native fuel matrix passed all 110 turret/fuel combinations. The combat
fixture passed 60 weapon/fuel/research cases and 30 research-ratio comparisons.
First-impact fuel ratios match the catalog within 0.001; the turret research
fixture applies the native combined 1.5 ammo and 1.7 turret factors once (2.55).
Full-window damage is recorded separately because fire duration and stream
spread intentionally affect it.

The lifetime fixture passed all ten initial and fully fueled comparisons to
crude, including diesel's doubled duration. Before overlap cleanup, native
mixed-fuel overlap produced ten distinct fire entities versus one for ten
streams of crude. The creation-event rule supersedes that stacking behavior:
the newest supported sticker and ground-fire type within one tile now survive.
Ground patches with identical prototype names are exempt from removal.
Separate patches beyond that distance can still damage the same target.

The replacement proof covers the private buffer, different supply fuel, an
attached pipe, circuit wire/settings, rollback and commit. Runtime fixtures
cover forced failed attempts, both storage temperatures/amounts, priorities,
quality, health, kills/damage, idle exhaustion, clone/destruction cleanup,
blueprints/ghosts, native player/robot mining/building, and direction/teleport
preservation. Real populated saves passed enabled → disabled → enabled,
preserving their epic turrets and fuels and ending disabled restoration with
zero registered turrets and no further fuel checks.

All nine budget/population combinations passed read and attempt caps, completion
of the initial adaptation and simultaneous fuel switch, and no replacements
during the unchanged interval. The final implementation counts replacement
rechecks toward B and parks failed work in delayed scheduler buckets.

| B | Turrets | Fuel reads, ms | Replacements, ms | Total updater, ms |
|---:|---:|---:|---:|---:|
| 1 | 100 | 13.635 | 33.820 | 79.979 |
| 1 | 500 | 15.372 | 166.072 | 219.413 |
| 1 | 1,000 | 13.944 | 343.972 | 398.342 |
| 10 | 100 | 17.740 | 30.327 | 86.615 |
| 10 | 500 | 84.680 | 187.506 | 422.455 |
| 10 | 1,000 | 98.845 | 355.076 | 629.861 |
| 100 | 100 | 18.062 | 30.986 | 87.714 |
| 100 | 500 | 77.321 | 152.234 | 356.804 |
| 100 | 1,000 | 168.438 | 300.355 | 774.212 |

These are cumulative profiler times over the 2,400-tick simultaneous-change
phase, on stationary disabled turrets. At default B=10 with 1,000 turrets, the
module averaged approximately 0.262 ms/tick over that interval. Parallel runs
introduce contention; these are not isolated hardware benchmarks, maximum-tick
measurements, or sustained-firing UPS guarantees.

Rendered day/night inspection remains unverified: graphics loading failed on an
unrelated missing Singularity Lance afterburn sticker sprite. See the exact
asset path and reproduction command in [README.md](README.md). No third-party
entity-reference integration beyond the loaded fixture pack is claimed.
