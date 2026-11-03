# Factory passage acceptance — 2026-11-01

Implemented under ESIR **1.4.03**, without a version bump, deployment, commit or issue
post. The final production modules match the full-profile native acceptance hashes
byte for byte. Concurrent work outside this subsystem was preserved.

## Behavior and ownership

Five startup booleans enable the master, Production, Power, Logistics and Turrets
by default. The sixth setting selects **Vanilla**, **Squeak Through** or **ESIR**,
with ESIR as default. All eight locales contain the names, explanations and mode
labels, including restart requirements and the Squeak Through 2 override.

The [conceptual model](../blueprints/factory-passage.md) owns the geometry, category,
lifecycle, scheduling and compatibility contract. The
[focused fixture instructions](../../../scripts/qc/factory-passage/README.md) explain
reproduction and managed closeout.

The native-first experiment found that native pipe connection collision can trap a
character during forced construction. The final implementation therefore uses an
escapable pipe core and deferred joint helpers for affected connections. Existing
walkable heat bodies and underground spans retain native passage. Unsupported
geometry preserves original collision; it does not silently receive incomplete
ESIR barriers. Silent connection changes by integrations use
`remote.call("ei_factory_passage", "refresh_entity", entity)`.

## Native evidence

Factorio **2.1.24, build 87808**, Windows x64. Final full-profile run:
`b8d341b5492641a08eaf4e50b9242a27`.

- **17 case groups, 17,164 assertion records passed.** These are records across
  separate runs, not 17,164 unique scenarios.
- Steam crusher and burner heater obstruction reproduced with passage off;
  passage on permits native walking. Steam assemblers remain the working control.
- All three modes, all six directed transitions, ordinary save/reload, master
  off/on and all four category switches passed. Ordinary reload preserves helper
  identities without a topology rebuild.
- Movement covers straight runs, diagonal and accelerated approaches, corners,
  T-junctions, crosses, connected grids, separate parallel runs, underground
  entrances, native walkable heat pipes and a collidable heat fixture.
- Pump, tank, chemical-plant and valve couplings cover four rotations. Native
  flame/acid turret ports cover eight headings. Large eight-way solid turrets
  cover both same-heading and mixed-heading neighbors.
- Native player, robot and platform actions cover placement, blueprint revival,
  mining, death, upgrades, cloning, rotation, flipping, teleport notification,
  surface clearing/deletion and cleanup. A newly built thruster beside an existing
  pipe receives its barrier. Grounded mech-armor escape and flying passage passed.
- Fluid amounts/temperatures, quality, circuits, connections, heat transfer and
  reactor neighbor bonuses passed the fixture assertions. Helpers are excluded
  from native blueprints and construction collision. No unsupported runtime joint,
  orphan helper or continuing helper churn remained.
- Final promoted-source companion run `ab70613a808c4f9e9cb186f59b0c9fb8` passed with
  the actual installed **Squeak Through 2 0.2.0** package. ESIR makes no collision
  mutations and maintains zero helpers under that override.

[Native evidence archive](../../../.factorio-qc/managed/b8d341b5492641a08eaf4e50b9242a27/evidence.zip)
contains `reports/native-acceptance.json`, exact source manifests, the promotion
snapshot, receipts and logs. The
[companion archive](../../../.factorio-qc/managed/ab70613a808c4f9e9cb186f59b0c9fb8/evidence.zip)
retains the separate override proof.

## Performance evidence

Final run: `0feee405fffe4da899613895c01bde4e`. Base plus the exact passage modules and
shared scheduler, on an AMD Ryzen 7 5700X3D / Windows 10 host. Functional coverage
above uses the full development profile; these measurements isolate this subsystem.

Both modes use seed 137013, identical 1,000-column grids, and settled checkpoints at
tick 512. Five independent processes per case alternate baseline/candidate order.
Every checkpoint hash and module hash is checked. No accepted measurement overlaps
another Factorio process. Each idle trial measures 6,000 updates; each burst trial
measures 1,000 updates while removing and restoring the same 1,000-pipe interior row.

| Pipes | Vanilla idle mean | ESIR idle mean | Added mean | ESIR helpers | Queue drain |
|---:|---:|---:|---:|---:|---:|
| 10,000 | 0.100415 ms/tick | 0.108255 ms/tick | 0.007840 ms/tick | 18,990 | 40 ticks |
| 100,000 | 0.106411 ms/tick | 0.123992 ms/tick | 0.017581 ms/tick | 198,900 | 391 ticks |

**All 40 trials passed.** Both the five-run means and every paired idle delta are
within the agreed larger-of-5%-or-0.1-ms/tick limit. In these measurements the
applicable allowance is 0.1 ms/tick. Idle topology queries and helper churn remain
zero, and reconciliation never exceeds 256 work items per tick with the default
256 budget used for this historical run.

| Idle measurement process | Peak working set | Sampled private-byte maximum |
|---|---:|---:|
| 10,000 / Vanilla | 460.6 MiB | 401.0 MiB |
| 10,000 / ESIR | 479.1 MiB | 433.9 MiB |
| 100,000 / Vanilla | 461.5 MiB | 406.7 MiB |
| 100,000 / ESIR | 1,468.1 MiB | 1,492.5 MiB |

Memory numbers are whole-process maxima, including load, rather than an isolated
Lua allocation measurement. Private bytes are sampled every 200 ms. The ESIR
hosted checkpoint processes took 13.6 s and 39.1 s respectively, including loading,
rebuild, waiting for the common checkpoint tick and saving. Queue-drain ticks above
are separate measurements and must not be presented as wall-clock durations.

| Pipes / burst | Vanilla mean over 1,000 updates | ESIR mean over 1,000 updates | Worst Vanilla tick | Worst ESIR tick |
|---|---:|---:|---:|---:|
| 10,000 | 0.693451 ms/tick | 2.546128 ms/tick | 574.1 ms | 698.5 ms |
| 100,000 | 57.787250 ms/tick | 60.231671 ms/tick | 57,876.7 ms | 58,966.2 ms |

The deliberately single-tick 1,000-pipe mutation of a 100,000-pipe connected grid
is expensive in the Vanilla baseline too. These burst figures are separate from
the steady-state acceptance gate. ESIR's removal and construction reconciliation
each drained in **20 ticks in every burst trial**, restored the exact original
pipe/helper counts, then completed 60 further ticks without topology work or churn.
Burst process working-set maxima reached 591.7 MiB at 10k and 1,554.3 MiB at 100k.

[Performance evidence archive](../../../.factorio-qc/managed/0feee405fffe4da899613895c01bde4e/evidence.zip)
contains `reports/performance-acceptance.json`, all 40 receipts, native timing logs,
source/checkpoint hashes and process monitors. JSON receipts live inside the archive
after compaction; the readable index records their hashes and provenance.

## Rendered, static and multiplayer boundaries

- [Factory passage movement](../../../.factorio-qc/managed/b8d341b5492641a08eaf4e50b9242a27/movement/factory-passage.webp)
- [Three pipe modes](../../../.factorio-qc/managed/b8d341b5492641a08eaf4e50b9242a27/movement/pipe-modes.webp)
- [Leaving an occupied new joint](../../../.factorio-qc/managed/b8d341b5492641a08eaf4e50b9242a27/movement/occupied-joint.webp)

The demonstrations assemble 384 hash-verified native frames; no character motion
is synthesized. Their exact source manifests are retained. These ordinary-machine
and pipe scenes were captured before the final unrelated custom-receiver/eight-way
admission refinements; the final native matrix repeats their movement invariants.

Focused syntax, headers, blueprint ownership/links and all-eight-locale schema and
UTF-8 checks passed. Standalone Lua syntax checks use luac 5.4.8; native semantics
are established separately by Factorio 2.1.24. Locale checks establish completeness
and encoding, not independent native-speaker review. The broad preflight passed
11 checks; its sole failure remains the pre-existing suspected mojibake in
`scripts/qc/singularity-lance/angular-results.json`.

Existing presentation/death definitions are inherited without mutation. Native
death/cleanup behavior passed; this is not a new exhaustive death-VFX render review.
Hosted server save/reload passed. **Two-client multiplayer synchronization was not
run.** Surface import is wired and source-reviewed; clear/delete paths have native
actor coverage. Arbitrary silent changes by other mods cannot be guaranteed.

Final successful runs were closed and compacted. Three superseded development
payloads (`12e831b0623e4a249d24fff2bd822a9a`, `81ae950761d44dfca0fcefc2f5929e29`,
`fb130e4664c943e6a876d32f8887c3bc`) were released after investigation but remain
protected by source-change checks. They were not forcibly deleted or relabeled as
passing final evidence.
