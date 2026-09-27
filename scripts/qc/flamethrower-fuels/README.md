# Fuel-specific flamethrower verification

Target: installed Factorio 2.0.77, ESIR 1.3.40. The fixture copies the gameplay
pack into `.factorio-qc/flamethrower-fuels`; it does not modify live saves or mods.
Its remote interface and profiling/failure hooks are injected into that copy only.

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task qc-fast
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1 -Proof
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1 -CreationProof
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1 -Overlap -Profile 16x -Disabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1 -Disabled
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1 -FuelMatrix
powershell -ExecutionPolicy Bypass -File scripts/invoke-flamethrower-fuels-qc.ps1 -Effects
```

Pass `-SaveInput <save.zip>` to the ordinary fixture to exercise a real player's
blueprint, mining and building APIs. `-Combat -SaveInput <save.zip>` requires a
save containing a player; standalone characters do not perform player shooting
under the benchmark. The input is copied before use.

Run `check-data.py <final-data-raw-dump.json>` after `qc-fast`. It reads only the
relevant sections of the engine dump, avoiding unrelated vehicle configurations.

Use `-Budget 1`, `10`, and `100`, each with `-Performance 100`, `500`, and `1000`.
Each performance run adapts all turrets, verifies an unchanged interval without
replacements, then changes every firing buffer simultaneously. Fuel reads,
replacement transactions, and total updater time have separate engine profilers.
The mandatory read immediately before replacement counts toward the same B cap.
Failures sleep in shared delayed buckets for at least 60 ticks.
Flamethrowers run only on step 16 of the 16-step dispatcher. Each visit retains
the B-read and B-replacement caps; the scan quota accounts for the
16-tick interval. Overdue retries run on the next visit (normally 64 ticks after
a failure). Performance phases count dispatcher cycles rather than engine ticks.

For actual setting transitions, run `-Transition`, then
`-Transition -Disabled -SaveInput <previous-run/saves/flame-transition.zip>`, then
`-Transition -SaveInput <disabled-run/saves/flame-transition.zip>`. These runs use
a private local server, save the populated world, and stop their own process.

## Verified behavior

- Ordinary and all ten internal turret identities natively fire all ten fuels:
  110 combinations, held fixed so adaptation cannot conceal a mismatch.
- Sixty native combat cases cover handheld, tank and turret firing, with and
  without research. First-impact damage isolates fuel scaling from stream spread
  and different ground-fire lifetimes. Research applies once; tanks retain their
  native stream without ground-fire creation.
- Final recipes, unlocks, magazine/stack/weight parity, quality-bearing clones,
  fuel multipliers, fire growth/lifetime values, tree-fire references, research
  effects and all seven locale contracts are audited against final engine data.
- Mixed old firing-buffer/new supply fuel, supply fallback, exhaustion, forced
  rollback, indexed fluid amounts and temperatures, quality, health/statistics,
  circuit wire/condition, target priorities, clone/destruction cleanup, old-save
  unlocks, blueprint/ghost normalization, native player and robot lifecycle,
  rotation parity and scripted direction/teleport preservation have fixtures.
- Enabled/disabled/enabled save transitions preserve populated turret state.
  Disabled restoration ends with an empty registry and no further fuel checks.
  `control.lua` gates the updater with `has_tick_work(event)` on scheduled step 16.

Connected supply networks require special care: creating an overlapping turret
splits the fluid segment immediately. The transaction snapshots indexed fluid
storage before creation. Rollback refreshes the original entity's connections
with an in-place teleport before restoring the snapshot. The engine fixtures
cover rollback and commit with an attached pipe, not just isolated turrets.

The lifetime fixture uses native streams to repeatedly fuel fires. Its expiry
observations include the unchanged burnt-patch tail, so initial and maximum
lifetime comparisons subtract the crude reference and allow a ten-tick phase
difference. Creation events now keep only the newest supported attached fire
sticker and remove older supported ground fires of different prototype types
within one tile of the incoming patch's centre. Same-type patches coexist. The
removed patch loses its heat/lifetime; same-patch native
refueling still grows both. Tree fire, acid and unrelated effects are excluded.
Separate patches farther than one tile apart can still damage the same target;
this is local overlap cleanup, not a per-target damage cap. No scripted damage,
age tracking or extra periodic work is used. Saved overlaps are cleaned on the
next supported creation event, without a map-wide migration scan.
Refreshing an existing sticker or refueling a patch can reuse its entity without
a creation event; an actual new effect triggers cleanup of saved overlaps.

Run `-CreationProof` for the isolated 2.0.77 event/refueling proof, and `-Overlap
-Profile original` (also `2x`, `4x`, `8x`, `16x`, each with and without `-Disabled`)
for notification audits and runtime overlap checks. The latter covers same-tick
events, all supported effect identities, one-tile boundaries, saved effects,
unrelated stickers/fires, native turrets, handheld/tank streams, rapid fuel
alternation, heat/lifetime growth and the idle adaptation guard. These fixture
runs use `.factorio-qc/fov` to keep staged paths within Windows path limits.

## Coverage limits

The population profiling fixture uses stationary, disabled turrets. Native
combat is tested separately; the population results do not establish a sustained
firing UPS guarantee. The replacement cap follows the full configured update
budget, not a hardware performance promise. Timings from parallel fixture runs
also include machine contention.

Rendered day/night review was attempted with `-Effects -Client`, but the full
checkout's graphics load stops on the unrelated missing
`__exotic-space-industries-remembrance-graphics-4__/graphics/entities/singularity-lance/afterburn/singularity-lance-afterburn-sticker.png`.
The new effects have engine-valid prototype references; their rendered appearance
has not been approved by this run. Steam client tests use a fixture-local App ID
file and working directory so Steam does not discard the isolation arguments.

Replacing entities changes their engine references. No public replacement API
is introduced, and no compatibility guarantee is made for third-party mods that
retain those references. The ordinary build/destroy events are raised on commit.
