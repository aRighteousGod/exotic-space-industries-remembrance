# Control UPS follow-up verification

This follow-up compares frozen baseline `77940728839eedf200ce5badc94f284eee58e311`
with the published runtime candidate `83f356882dd7564b0ef0059f7b984a0b966c8729`.
Both use ESIR 1.3.40 on installed Factorio 2.0.77. The follow-up changes QC
fixtures, runners, validators, and documentation; it does not change shipping
gameplay code, scheduling, priorities, or budgets.

## Orbital fairness acceptance

The fixture now establishes uplink A's sticky Alpha lease before preparing its
fairness lane. Uplink B/C's competing jobs become fixed manual Beta/Gamma targets
for the rotation check. A policy selector can retarget during repeated service
passes, so its previous setup did not isolate lane rotation.

`cu/g/bo4` and `cu/g/co4` pass the normal strict validator: **16 actions and 12
checkpoints**, with **all 31 complete records exactly equal**. At tick 360 B
leases Gamma/selector C; at tick 390 it leases Beta/selector B. A retains Alpha
throughout those fairness actions. Production manual/policy priorities are
unchanged. The orbital helper's 28 missing-player GUI samples remain explicit
skips; the separate connected-player fixture covers black-hole/matrix GUIs.

## Real queue persistence

`cu/g/qs-b4` / `qs-c4` create genuine server saves with pending Gaia and alien
jobs referencing actual LuaEntity/LuaSurface objects. Each source reloads its own
save ordinarily and through a helper-version-triggered configuration change:
`ql-b4-ordinary`, `ql-c4-ordinary`, `ql-b4-configuration`, and
`ql-c4-configuration`.

All four pass, with **23 exactly equal ordered drain records and six spawned
chests**. The fixture covers legacy-array migration, earlier/later insertion
after warming the due cache, immediate jobs, same-tick rescheduling after a due
snapshot, recurring Gaia damage, an entity invalidated before its job is due,
and final empty queues. Both ordinary loads unconditionally compare their saved
due minima; both configuration loads assert production invalidates the minima.
The original dispatcher performs all draining and service.

Gaia's test producer and the alien preset are staging-only fixtures. This proves
real engine serialization and timing for seeded queues; it does not imply that
ordinary gameplay currently produces new Gaia damage jobs. The baseline has no
cached minima; the candidate preserves both due ticks at relative 40. Work
inserted for tick 30 after the drain snapshot executes at tick 31 on both sources.

## Populated-save provenance and coverage

Input: `_autosave9.zip`, 96,379,671 bytes, saved September 24, 2026, Factorio
2.0.77 / ESIR 1.3.40. SHA-256:

`30FEA966BBAC323AEB9E6BBA30B35C6D0E56E88F3B433073FDF765AB3263B03D`

The comparison reconstructs all 269 startup settings from the hash-checked save.
All 269 match both engine censuses exactly. Two newer defaults appear equally:
`ei-water-turret-fire-check-seconds=2` and `ei-thrower-performance-profile=original`.
The live profile was not used: its Tesla balance, technology scaling, and rupture
visual settings differed. Runtime-global and saved-player settings are recorded
in both engine censuses. The staged external settings contain no runtime overrides.

Both profiles use the same 43 enabled mods: the save's 44 minus standalone
`extinguisher`, which both compared source revisions replace/incompatibly exclude.
The five additions to the original dependency seed are AspctTrainPatch 1.1.0,
module-inserter 1.0.4, visible-planets 1.7.2, vp-scale 1.4.1, and
recipe-icons-improvement-for-esir 1.1.26. Source, save, settings and dependency
hashes are retained in each manifest. The input save is never overwritten.

The engine census starts at tick 150984001 with **414,201 player-force entities
across 29 surfaces** and one connected saved player. Selected populations:

| System | Population at the start |
| --- | ---: |
| Neutron collectors / connected sources | 187 / 7 |
| Singularity lances | 19 |
| Orbital combinator banks / cached platforms | 1 / 23 |
| Active fumaroles / dormant chunks | 117 / 14,724 |
| Fluid entries / segments | 75,505 / 7,560 |
| Fueler towers / ready targets | 16 / 5,416 |
| Beacon-tracked machines / beacons | 14,734 / 1,083 |
| Induction core-table keys / proxies | 173 / 172 |
| Fusion reactors / gates | 8 / 11 |
| Flamethrower adaptation / railgun cooling records | 512 / 41 |

Core-table keys include metadata; this is not a claim that every key is an active
matrix. The save has no water-turret state, Emerald tanks/shards, Tesla sync jobs,
Gaia damage jobs, or alien spawn jobs initially. Those systems' populated behavior
is covered by the dedicated fixtures, not this factory timing result.

Separate attribution profiles `cu/g/pop-prof-b1` / `pop-prof-c1` measure ticks
121 through 3600. Every wrapped method has identical baseline/candidate call
counts. Complete starting census JSON matches; the ending census differs only in
the candidate's expected `spawner_next_due_tick=false` cache metadata and its
corresponding root-key count. These are census comparisons, not full game-state
equivalence proofs.

Neutron `check_global` consumes 123.900 ms baseline / 24.191 ms candidate over
4,575 calls, supporting the earlier allocation microprofile on a populated save.
The candidate's larger inclusive module totals are gate update 315.152 ms,
induction update 232.169 ms, fluid service 227.128 ms, beacon update 176.709 ms,
orbital update 141.642 ms, orbital pending-work query 112.796 ms, and Spidertron
script effects 108.112 ms. These are single-run attribution totals with nested
timers, not additive costs or controlled evidence of module regressions.

## Whole-engine result

Uninstrumented profiles `cu/g/pop-b` / `pop-c` ran six alternating pairs of 3,600
ticks, one Factorio process at a time. Pair zero was discarded as warm-up; each
run reloaded the same original save. Candidate ran first in odd-numbered pairs,
baseline first in even-numbered pairs.

| Measured pair | Baseline ms/tick | Candidate ms/tick |
| --- | ---: | ---: |
| 1 | 13.971057 | 14.166291 |
| 2 | 14.023398 | 13.668671 |
| 3 | 13.580207 | 14.131149 |
| 4 | 13.579949 | 13.931556 |
| 5 | 13.668734 | 13.537732 |
| **Median** | **13.668734** | **13.931556** |

The candidate median is **1.92% slower in this sample**. Ranges overlap:
baseline 13.579949–14.023398, candidate 13.537732–14.166291 ms/tick. Two pairs
favor the candidate and three favor the baseline. **This does not demonstrate a
whole-factory UPS improvement.** The populated neutron helper reduction is real
in the separate attribution lane, but it is small relative to this factory's
total update time. No additional performance claim is inferred from it.

Runtime checksums are stable across all six repetitions within each revision:
baseline `2886643341`, candidate `1335516288`. They differ across revisions,
which also differ in persisted cache metadata; these checksums are not a proof of
cross-revision behavior equivalence. Dedicated exact traces and the limited raw
census comparison supply that evidence within their stated scopes.

Factorio normalizes the staged settings on loading. Both final settings files
have SHA-256 `86D19634D545110C0B997E6A15E800585334AD2C8DC0FADB7CC8BB997D83AA52`.
The original save hash remains unchanged. Raw timing logs and manifests remain
in the two profiles; `.factorio-qc/control-ups-20260926/populated-results.json`
contains the independently parsed summary. The initial runner's checksum regex
matched the prototype checksum; it was corrected to the anchored final runtime
checksum, and the result records now retain both fields. Timing values were not
changed by that correction.

## Connected-player GUI lifecycle

The two isolated client runs, `cu/g/gui-b3` / `gui-c3`, pass with **123 exactly
equal ordered records**. The fixture asserts an actual connected LuaPlayer,
sets `player.opened` to real entities/proxies, and records the resulting native
open/close events through the original central dispatcher. Coverage includes
black-hole open/retarget/close, destruction while open, matrix proxy open and
retarget, GUI identity retagging, core destruction, and a valid matrix rebuild
that preserves its core and proxy mapping.

Mechanical registries are then isolated empty to test GUI-only fallback work.
Orphans created at absolute tick `% 30 == 1` close after exactly **14 ticks for
the matrix** and **29 for the black hole**. The fixture also records existing
behavior that must be preserved: matrix retagging changes the target identity
without moving the existing camera, and destroying a matrix core can leave its
screen open with values updated on the normal GUI cadence.

Each client writes a genuine autosave at relative tick 331 with the black-hole
panel open. Ordinary resumes `gr-b3-ordinary` / `gr-c3-ordinary` and forced
configuration resumes `gr-b3-configuration` / `gr-c3-configuration` all resume at
332 and pass; **124 records match exactly within each baseline/candidate pair**.
Both the real configuration callback and saved entity/GUI state are exercised.
Matrix repair is tested through its explicit rebuild helper; the production
configuration callback does not invoke that helper.

The GUI-only predicate probe uses explicit off-cadence inputs, 50,000 calls per
repetition, six repetitions, and the median of the final five. Candidate costs:

| One connected player; empty mechanical work | Black-hole guard us/call | Matrix guard us/call |
| --- | ---: | ---: |
| No root | 4.429 | 5.436 |
| Black-hole orphan | 5.598 | 5.533 |
| Matrix orphan | 4.842 | 5.747 |
| Unrelated root | 4.865 | 5.266 |

These are bounded microprofiles of the unchanged guards, not a demonstrated
optimization or a whole-factory UPS percentage. They make cadence-gating trials
reviewable, while indicating that this one-player idle saving is modest.

The first graphical attempt failed to resolve a deeply staged drill sprite; the
asset exists in the installed archive. Retrying with exact-version graphics ZIPs
resolved the load failure. Both client profiles record identical graphics archive
hashes. Ordinary benchmark mode had proved connected-player semantics but did
not write its requested autosave, which is why real client saves were used for
the final persistence lane. No mouse-interaction or visual-layout review was
performed. Raw GUI profile summaries are in
`.factorio-qc/control-ups-20260926/gui-profiles.json`.

## Final verification

- Strict orbital, queue and GUI validators pass, including required reload labels
  and exact ordered baseline/candidate comparisons.
- All **665 shipping source files** still match the measured candidate manifest.
- Repo preflight passes Lua syntax (350 shipping files), PowerShell syntax,
  encoding, requires, locale, asset-reference and pack-version checks. Existing
  module-header warnings remain.
- The preflight Python bytecode-cache step is blocked by protected `.codex`
  paths. All **79 tracked/untracked repository Python files** compile in memory,
  without writing those caches.
- The three staging Lua bridges compile, the three modified/new PowerShell
  runners parse, and `git diff --check` passes.

The earlier rejected runs remain isolated evidence, not acceptance results. The
accepted run names above identify the final fixture contents and hashes.

## Next patch candidates

1. **Fueler budget query and lazy defaults.** Its pending-work getter spends
   62.235 ms over 217 calls scanning queues even when the cached ready-count lower
   bound already guarantees the maximum dispatcher budget. Add an optional
   dispatcher-only saturation cutoff; retain exact existing behavior below the
   threshold and for existing callers. Apply the neutron-style lazy defaults to
   the discarded empty tables in `check_global`. Compare every budget boundary,
   under/over-count, queue tombstone, delayed bucket and repair state.
2. **Fluid service bookkeeping.** Pass the already-normalized runtime through
   internal touch/enqueue helpers while keeping public repair entry points.
   Remove only the main service loop's redundant queue snapshots. Preserve all
   live segment queries, queue order, weighted cursor, entity visits and budgets.
   Validate ordered traces across budgets, invalid entities, migration, and
   segment merge/split cases. Attribute live segment-member scans separately
   before considering any cache that could postpone repair.
3. **Induction empty work and GUI fallback guards.** Retain render, dirty, wire,
   GUI order and existing wire slots. Avoid repeated normalization and verified
   empty queue/removal allocations within one update. Use the new GUI fixture
   before trying cadence-gated fallback scans; preserve exactly the existing
   refresh and stale-root closure ticks.
4. **Gate subprofiles before larger edits.** The broad gate timer does not locate
   its cost. Measure receiver refresh, proxy repair and rendering independently.
   Same-call position/surface reuse is safe to investigate; skipping refreshes
   based on apparent equality can change circuit polling and repair timing.

No additional scheduler slot is justified by these measurements yet. Adding one
remains an option only with unchanged service ticks, order, derived intervals,
and budgets. Lance top-K remains deferred until target distributions and sort-tie
behavior make a worthwhile exact-equivalence implementation demonstrable.
