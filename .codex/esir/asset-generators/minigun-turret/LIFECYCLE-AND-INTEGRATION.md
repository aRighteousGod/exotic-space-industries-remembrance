# Pending native lifecycle fixture and atomic integration

This is the concrete remaining work identified from the current shipping turret, graphics factory, emitter, and native fixtures. It is a proposal for the next scoped fixture task, not executed evidence. Installed 2.0.77 documentation and the current source are the authority; no engine was run for this audit.

## Existing evidence does not cover these cases

The old timing fixture drops/reacquires targets during preparation and folding. It fills electrical energy every tick and replenishes ammunition; those controls prevent an energy/ammo shortage test. The firing fixture also fills energy every tick, and its shot or burst depletion does not prove mid-state interruption/recovery. Neither fixture saves and resumes a real mid-state checkpoint. A native load used to start a benchmark is not that proof.

The new fixture should use the exact frozen candidate/PNG manifest and existing production factory in an isolated helper. Preserve gameplay, ammo action graphs, projectile/flash behavior, and current connector. Keep candidate-vs-reference timing observations separate from visual review. Instrument actual native state/direction/energy/ammo/active/disabled/frozen snapshots and shot births. Never synthesize turret state or use a custom animation controller to pass a lifecycle case.

## Concrete 18-case fixture

Run each intervention at an observed preparing midpoint, a sustained running burst, and an observed folding midpoint. Use actual state observations to trigger the intervention; elapsed time alone does not establish a state. A paired uninterrupted row supplies context. Each case logs the intervention tick, pre/post snapshots, duration, native shots, recovery, and screenshots before/during/after. The observer must not replenish an intentionally withheld resource.

| Intervention | Native action and required evidence |
| --- | --- |
| Save/load | At the observed phase, call the documented `game.auto_save` with a unique checkpoint name. Stop and resume that exact resulting save in a separate serialized engine invocation. Retain/hash the save and both logs. Confirm the original entity, ammo, energy, orientation and persisted fixture cursor survive, then compare resumed state/shot behavior with the paired schedule. A fresh new turret does not count. |
| Ammo shortage | Stop the normal replenishment loop, clear usable ammo at the observed phase, retain the empty inventory/count and no-shot period, then insert the same ammo and observe native reacquisition and the next actual shot. Do not require an invented animation transition; compare what the native turret actually does. |
| Energy shortage | Disconnect the case from power and stop scripted energy filling. Drain the stored electrical energy below one-shot cost, then wait through the depleted period before restoring a real supply. Record energy, active/disabled flags, ammo consumption and shot events. Merely disconnecting a charged 666 kJ buffer is insufficient. |
| Script disable | Toggle documented `disabled_by_script`, retain its readback and the actual state/shot behavior, restore it, and observe reacquisition. Do not call this a circuit or freezing test. |
| Circuit disable | Configure the turret's supported on/off control behavior and drive an actual false/true circuit condition with an isolated signal source. Observe `disabled_by_control_behavior` and shots as well as the condition. This checks behavior, not connector placement. |
| Freeze/thaw | Use a fresh surface created by the actual Aquilo planet (`game.planets.aquilo.create_surface()`) or a reviewed private planet prototype with `entities_require_heating=true`. Supply and withdraw native heat through a controlled heat-source/pipe arrangement. Observe `is_freezable`, genuine read-only `frozen` changing false/true/false, native state and shots. The shipping turret has `heating_energy="100kW"`, so this case applies. |

On 2.0.77, `LuaEntity.frozen` is read-only; electrical turret `temperature` is not a writable freeze control. `surface.freeze_daytime` controls the day clock, not entities. `entities_require_heating` belongs to the planet prototype, not a writable surface field. Associating an arbitrary existing surface with a heating-required planet is not a valid substitute. A prototype clone, if chosen, belongs only to this isolated helper.

The case schema in the finalizer is intentionally evidence-oriented: record actual observations and an analyzer verdict, then bind the reviewed image(s). A raw producer/analyzer still needs implementation and local API inspection for exact control-behavior and connector API calls. No inferred freeze, circuit, or save/load pass should be emitted from this document. SD can carry the mechanical lifecycle matrix because the underlying entity is shared; the required SD/HD visual state cases and four full firing configurations cover both atlas profiles. Explicitly record the doctrine setting used by every native report.

## Smallest atomic shipping patch

1. Install only the finalizer's calibrated `graphics-data.lua` beside the existing `gatling-turret/graphics.lua`, and the exact complete G6/HD PNG families and generated HD example metadata from the finalized artifact map. Retain old G3 graphics for older ESIR consumers. Retire only proven superseded files in the newly touched shipping family; no broad orphan sweep.
2. Make the production factory reject draft/partial metadata unless its explicit fixture mode is used. Require the full 256 indices, calibration provenance, and measured `native_launch_contract`. Apply each measured field with its recorded present/absent state. Preserve `projectile_creation_distance` semantics exactly; do not infer that a 256-entry map overrides it.
3. Replace the legacy local `gatling_place`, `gatling_sheet`, and old muzzle helper in `gatling-turret.lua` with one factory instance. Apply only its graphics, calibrated launch registration, and selected preparation/folding timing to `ei-gatling-turret`. Preserve health, collision/selection footprint, energy and ammo costs, range, cooldown, rotations, resistances, connector, shell effects, sounds and research bonuses except an independently accepted mechanical change explicitly recorded in the tested contract.
4. Use the selected profile's item icon for both item and entity and its technology icon for research. Clear obsolete `icon_mipmaps` when the replacement file is a single icon. The recipe already has `main_product="ei-gatling-turret"` and inherits the item icon; no separate recipe art is needed. `ei-minigun` is a distinct handheld/component item and must remain untouched.
5. Preserve package metadata already staged: main 1.3.41 requires G6 >=1.0.0 and has the first optional HD dependency; G6 and `e-s-i-r-minigun-turret-graphics-hd` are each 1.0.0. HD stays an asset-only, base-only pack. Its example stays under `examples/`, never loaded by a root data entry point; GPL-3.0-or-later and attribution remain.
6. Update the focused blueprint and manifests only after this actual consumer patch. Verify the installed final-data prototype fields against the frozen contract in SD/HD × doctrine off/on and confirm item/recipe/research icon resolution, no duplicated gameplay prototypes, and the unchanged handheld minigun.
7. Load the copied standalone HD example in an isolated test mod without ESIR. Verify its measured launch contract and both explicit shadow policies: no shadow layer at all without G6; the complete declared shadow layer when all referenced packs are enabled. No incomplete per-direction/per-state shadow fallback.
8. Measure complete G6/HD ZIPs after all final Lua/support/metadata changes. Use the existing package wrapper and `measure_packages.py` overlay; strict <256,000,000 bytes each, lossless only. Preserve the draft and all prior evidence. This staging work does not authorize publishing or deployment.

## Files inspected

- Main `prototypes/electricity-age/gatling-turret.lua`, its unloaded `graphics.lua`, package `info.json` files, and the HD example factory.
- Generator `emit_graphics_data.py`, `measure_packages.py`, native-color aggregate validation, firing `build_fixture.py`, `data-final-fixes.lua`, `control.lua`, and native timing control/analyzer.
- Staged schema-2 firing `summarize_matrix.py` and `evidence_contract.py`; authoritative installed/cached 2.0.77 runtime/prototype API and vanilla Aquilo declaration.

The current shipping turret remains on legacy art until the parent integrates the accepted patch. This audit and staged finalizer do not change it.
