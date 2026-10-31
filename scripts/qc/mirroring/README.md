# Scoped native mirroring repair

Original target: Factorio **2.1.24**, ESIR **1.4.01**, the standard development
dependency profile with Quality enabled and disabled. This patch makes no version
change; concurrent release work is recorded separately in the verification report.

## Policy and owners

The reviewed policy is parity plus safe, useful additions. The 18 explicit
crafting-machine opt-ins are listed in [cases.lua](cases.lua); the complete
123-prototype assessment is recorded in [DISPOSITIONS.md](DISPOSITIONS.md).

- Advanced chemistry/refining: advanced chemical plant, advanced centrifuge,
  advanced refinery, distillation tower and advanced distillation tower.
- Biological production: auric inoculation vat, bio chamber, bio reactor, grower.
- Processing: purifier, exchanger, neutron activator, nano factory.
- Large machines: excavator, fusion reactor, quantum computer.
- Vanilla machines with ESIR fluid ports: centrifuge and Space Age crusher.

Each field is set at the existing declaration or fluid-port mutation owner.
The steam oil pumpjack explicitly copies its authored graphics into
`graphics_set_flipped`, retaining its inherited native fluid geometry,
`use_mirroring` and `migrate_horizontal_mirroring`.

The cranes, mechanical/steam inserters, all mining drills, inherited mirrorable
machines and native symmetric machines retain their policies. Portless machines
and holograms do not need mirrored state. Beacon sources, cooling proxies and
the NSB manager keep their internal contracts and exclusions.

The thermal furnace remains deferred: its existing `not-rotatable` flag,
rectangular body and asymmetric heat connections require a separate connectivity
and graphics decision. Boilers, tanks, pumps, belts, loaders, turrets, rail
signals, train stops and thrusters receive no unsupported fields.

## What the controls mean

- [Crafting-machine use_mirroring](https://lua-api.factorio.com/2.1.24/prototypes/CraftingMachinePrototype.html#use_mirroring)
  opts into native mirrored state. Its default is not a guarantee that every
  previously flippable ESIR fluid machine remains eligible.
- [Inserter use_mirroring](https://lua-api.factorio.com/2.1.24/prototypes/InserterPrototype.html#use_mirroring)
  and mining-drill mirroring default to enabled; their already-working geometry
  does not require blanket overrides.
- [Mining-drill migrate_horizontal_mirroring](https://lua-api.factorio.com/2.1.24/prototypes/MiningDrillPrototype.html#migrate_horizontal_mirroring)
  controls conversion of east/west drill orientations from 2.0 saves. Preserve
  pumpjack inheritance; do not apply it to crafting machines or all drills.
- `forced_symmetry` was a legacy axis override removed in 2.1.
- `LuaEntityPrototype.allows_flipping` is a read-only engine result for blueprint
  eligibility. Native symmetry can provide this without mirrored state.

This corrects the broad crafting-machine default disposition in
[default_review_rules.py](../factorio-2.1/default_review_rules.py). Historical
upgrade receipts remain historical evidence, not retroactive acceptance.

## Reproduction

The stage uses the managed package store and a private copy of main-mod code.
Required media and other sources remain immutable. Choose a new record path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/qc/mirroring/stage.ps1 -Record .factorio-qc/mirroring-record.json
powershell -ExecutionPolicy Bypass -File scripts/qc/mirroring/run.ps1 -Record .factorio-qc/mirroring-record.json -Mode baseline -Quality enabled
powershell -ExecutionPolicy Bypass -File scripts/qc/mirroring/run.ps1 -Record .factorio-qc/mirroring-record.json -Mode candidate -Quality enabled
powershell -ExecutionPolicy Bypass -File scripts/qc/mirroring/run.ps1 -Record .factorio-qc/mirroring-record.json -Mode baseline -Quality disabled
powershell -ExecutionPolicy Bypass -File scripts/qc/mirroring/run.ps1 -Record .factorio-qc/mirroring-record.json -Mode candidate -Quality disabled
python -B scripts/qc/mirroring/check.py .factorio-qc/mirroring-record.json
powershell -ExecutionPolicy Bypass -File scripts/qc/mirroring/render.ps1 -Record .factorio-qc/mirroring-record.json
python -B scripts/qc/mirroring/check-render.py .factorio-qc/mirroring-record.json
```

The negative control removes exactly the 18 opt-ins and the pumpjack graphics
assignment in private staging. Final-data snapshots precede every graphical
adapter. The comparator allows only these 19 field changes across complete
prototypes, including graphics, death effects, sounds and Factoriopedia scenes.

Native cases cover both axes and four cardinal directions, real fluid recipes,
indexed ports, fluid identities/quantities/temperatures, conflicting neighboring
fluids, blueprint capture/build/revival, recipe copy/paste and save/reload.
Construction robots perform small-to-large crane upgrades; real cranes deliver
iron plates onto the expected belt lane. Native heat neighbors and heat transfer
exercise the distillation tower and retained heat chemical plant. Furnaces select
real recipes from supplied ingredients and verify loaded connection reflection.

The graphics fixture preserves all changed machines' sprites, connectors and
working visualisations. It reduces unrelated atlases after taking the source
snapshot, supplies native recipes/power/fuel, and captures all cardinal
directions in normal and mirrored states, with covered ports, connected pipes,
and nighttime working effects.

These scripts neither deploy a mod nor flip existing player saves. Do not run
current 2.1 source under the historical 2.0 engine. Retain focused receipts and
reviewed captures, then close only this task's managed run after all consumers
finish. Actual results and unverified boundaries belong in
[VERIFICATION.md](VERIFICATION.md).

## Historical fixture

`legacy-packages.py` resolves and verifies the preserved 1.3.41 package selection.
`legacy-stage.py` takes a separately registered legacy record, the current record,
and the user-supplied 2.0.77 ZIP; it extracts the old engine and stages only old
source. `legacy-run.ps1 -Phase donor` creates the 2.0 save.

Prepare the current record in `baseline enabled` mode, then run
`legacy-run.ps1 -Phase baseline`. Prepare `candidate enabled`, run
`legacy-run.ps1 -Phase adopt`, and call
`checkpoint.py CURRENT_RECORD LEGACY_RECORD` to create the genuine migrated save
on a private loopback server. Finally run `legacy-run.ps1 -Phase reload` and
`check-legacy.py CURRENT_RECORD`. The runner's two required record parameters
are `-LegacyRecord` and `-CurrentRecord`.

Upgrade receipts intentionally retain strict historical differences. Only the
comparison establishes whether this patch changes those results. A benchmark
does not write the requested autosave, so the server checkpoint is mandatory.

For a changed standard dependency profile, stage a separate current record and
repeat the candidate native suite in both Quality modes. Run
`check-current.py ORIGINAL_RECORD CURRENT_RECORD` to require identical complete
assessed prototypes and passing new native receipts.

After all consumers and visual review finish, `closeout.ps1 -Record RECORD -Kind
original|legacy|current` selects focused receipts, relevant saves, source identities
and captures for that run, completes it and closes its managed storage. It preserves
uncertain cleanup as a protected error. It does not operate on the user's engine
download or unrelated runs.
