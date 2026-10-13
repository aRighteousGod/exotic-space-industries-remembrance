<a id="contract"></a>
# Entity hit effects, interaction sounds and native previews

The late data pass fills entity presentation through explicit machine/combat
registry entries. It owns damaged hit effects, open/close sounds and Factoriopedia
scenes. Death cores, attacks, expiry, mining and runtime entity ownership remain
with their existing systems.

## Implementation sources

- [entity-presentation.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation.lua)
- [entity-presentation-machines.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-machines.lua)
- [entity-presentation-combat.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-combat.lua)

## Ownership and order

`api.entity` records entries; `apply_entry` resolves their values and deep-copies
only unset fields unless `force.<field>` explicitly overrides them. Registry
absence does not prove missing presentation: suitable source inheritance may
satisfy the contract. Generated scenes are data-stage strings executed by the
native simulation, not by ESIR's control dispatcher.

[data-final-fixes.lua](../../../exotic-space-industries-remembrance/data-final-fixes.lua)
loads presentation before [death assignment](death-explosions.md#inheritance),
spider finalization and fuel-shell generation. The scout/assault/rocket canonical
sources receive hit effects and suitable scenes before fleet copies. ANISETRON's
own native chapel scene replaces the inherited vanilla Spidertron scene. Existing
authored sounds and unrelated scenes remain intact.

<a id="operational"></a>
## Hidden operating bodies

Default entries skip hidden or Factoriopedia-hidden prototypes. An explicit
`operational = true` registry row admits a hidden selectable real body; it does
not alter visibility, placement, flags or Factoriopedia alternatives and does not
admit nonselectable support helpers. This is a curated opt-in, not a hidden-entity
sweep.

The early-copied fluid turbine, crystal low/surged shells and radar placement
chassis resolve hit/sounds lazily from their already-presented canonical sources.
They have no independent scene. The hidden assault source receives a canonical
scene so its later fleet copies retain appropriate presentation. Boarding proxies,
radar power/output helpers and cosmetic emitters remain outside this registry.

<a id="scenes"></a>
## Native scene behavior

Scenes show the actual source body. Radar scenes add the existing native body,
shadow and optional glow helper at the configuration's north frame; canonical
radar sprites are empty. No ESIR runtime scripts or fake scanning behavior are
needed for this static hardware view.

Prediction Snare displays its armed native body after its normal arming period.
Incinerator uses its native robot body; its scene-only `update` resets preview
time-to-live and tracks the hovering body so it stays in view. `make_simulation` forwards that
update string without changing gameplay lifetime or `destroy_action`.

This module owns no persistent runtime state, dispatcher hooks or periodic game
work. Native preview updates run only inside the active simulation. Entity scene
factories currently do not consume `companions` or `main_first`; explicit
`post_init` construction is used where the new scenes need helpers.

<a id="verification"></a>
## Verification and limits

Use [entity-presentation QC](../../../scripts/qc/entity-presentation/README.md)
for final-field assertions, all fleet/fuel inheritance, preserved gameplay/death
fields, exact scene init/update execution, and native scene captures. The fixture
isolates mod controls to match scenes that load no mod runtime scripts.

Scene-content captures exercise the actual prototypes and recorded cameras; they
do not verify Factoriopedia's window geometry, gradient or navigation. Engine load
alone does not establish visible scene quality. Follow the
[development skill](../../skills/esir-entity-presentation/SKILL.md) when adding
entries or extending the registry interface.
