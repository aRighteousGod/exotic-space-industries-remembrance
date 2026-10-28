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
- [working-sound-defaults.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/working-sound-defaults.lua)
- [compatibility-21-presentation.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/compatibility-21-presentation.lua)

<a id="optional-copies"></a>
## Optional copies and admission fields

Tenebris creates bioluminescent ESIR machines before final graphics repairs.
Their graphics sets are refreshed from the final canonical ESIR body, preserving
the separate Tenebris glow, void power, speed multiplier, restrictions and IDs.
This avoids mixed 64/32-frame inherited assembler layers. Death inheritance,
rendered animation and native simulation acceptance remain separately recorded.
Corrundum's red steam engine retains its 100-degree input floor on the generator's
native admission field, removing the obsolete FluidBox field. This does not alter
its conversion maximum, fluid use or power output.

<a id="working-sound-defaults"></a>
## Working-sound defaults across the 2.1 upgrade

Factorio 2.1 changes omitted `MainSound` fades from zero to eight ticks in and
twenty ticks out. ESIR's last data pass explicitly retains zero for missing fade
fields on `ei-` identities, including generated fleet and fuel bodies. Authored
fade values remain unchanged; progress-matched sounds do not receive forbidden
fade fields. Bare Sound shorthand is wrapped as a working sound when needed.
The pass copies sound definitions before mutation so shared vanilla/dependency
tables retain their own behavior. It changes no filenames, volumes, probabilities,
sound ownership or runtime scheduling. Native data comparison is distinct from
audible playback/listening acceptance.

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

The copper and iron nitrogen-beacon scenes explicitly create their existing
Nonstandard Beacons source assembler at the body's position. Preview-only updates
keep it supplied with liquid nitrogen so its native working mist remains visible.
The ordinary game retains Nonstandard Beacons' ownership and lifecycle; the scene
does not register a second gameplay helper or expose an independent helper entry.
The hypercooler keeps its existing nitrogen-production recipe and camera, with
preview-only energy/input replenishment and output clearing to sustain its mist
after the initial electric buffer and input would otherwise run out. The scene
also enables that recipe on its preview force so the native furnace can select it.

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
