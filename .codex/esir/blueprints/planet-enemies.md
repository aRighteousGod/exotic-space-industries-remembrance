<a id="contract"></a>
# Planetary enemy populations

Twelve native new-game rows independently cover Nauvis ordinary, explosive, cold,
Arachnid, Toxic and Armoured enemies; Vulcanus explosive enemies and demolishers;
Aquilo cold enemies; Fulgora/Gaia electric enemies; and Gleba pentapods. Every
resolved enemy-category control exposes its native checkbox, without changing
hidden visibility or resource/terrain controls. Defaults retain current generation,
including Gaia electric size 5. Combat difficulty remains a separate system.

## Implementation sources

- [planet-enemies-config.lua](../../../exotic-space-industries-remembrance/lib/planet-enemies-config.lua)
- [planet-enemies.lua (data)](../../../exotic-space-industries-remembrance/scripts/data-final-updates/planet-enemies.lua)
- [planet-enemies.lua (runtime)](../../../exotic-space-industries-remembrance/scripts/control/planet-enemies.lua)

<a id="generation"></a>
## Native generation

Per-planet property-expression aliases rebind dependency radius/frequency to
independent controls, retaining original seeds, climate and starting exclusions.
Explicit entity whitelists and probability gates retain the original bodies and
make zero frequency or size suppress the rebound family. No enemy clones exist.

Nauvis Arachnid, Toxic and Armoured nests copy the native radius, frequency,
probability and autoplace-function closure, rebinding enemy-base dependencies.
The control-free intensity expression stays shared. Default seeds, masks and
starting exclusions remain. Explicit map preset values inherit into absent new
controls. Armoured Biters retains its selectable `ab-enable-nest` startup setting.
The Armoured row applies only when separate nests are enabled. With shared nests,
vanilla spawners retain snapper spawn results and snapper births follow the ordinary
enemy-base policy; the Armoured row has no effect. Both menus document this boundary.
Upgrades copy saved enemy-base
frequency/size/richness into absent split controls, including zero, with explicit
new values winning. Existing nests are not backfilled or replaced.

Demolisher radius is floor(clamp(384 * sqrt(max(size, 0.000001) / max(1, frequency)),
128, 65535)). Below frequency 1, native Voronoi IDs (stable random values in [0,1])
select empty cells. Above 1, territories shrink within native minimum-size limits.
At 1/1 placement is unchanged. Negative variation disables occupied territory;
native starting exclusions, distance-based creature sizes and no-enemies remain.

Gleba Off restores effective frequency/size 1 for ordinary raft placement, including
starting/coastal branches. Rafts have no direct checkbox autoplace exclusion.
Explicit raft whitelist entries also survive upgrades. Runtime disables their
spawning but retains their force, appearance and egg loot.
Positive controls retain native placement meaning; there is no replacement recipe.

<a id="seed-compatibility"></a>
## Factorio 2.0 seed compatibility

Factorio 2.0.77 incorrectly shares spot-noise state between expressions with equal
placement seeds even when their density/radius differs. Nauvis ordinary, Arachnid,
Toxic and Armoured expressions share seed 123; Cold and Explosive share 735155.
At frequency/size 1/1 each keeps its original seed and exact default distribution.
Any nondefault frequency or size selects a stable seed unique to that family
(2000123 through 2000128). Only the spot-noise seed changes: local blob seeds,
native masks, starting exclusions, intensity and random penalties remain intact.
Returning to 1/1 returns to the original seed. Adjusted placements may move;
existing generated terrain is untouched. Ordinary/Cold/Explosive aliases are
Nauvis-specific so the original Space Age distributions remain unchanged.
Upgrades add absent native aliases but retain custom saved probability aliases.

This is the user-approved compatibility tradeoff, not an engine-independent
placement redesign. Revisit on Factorio 2.1 with the recorded multi-seed default,
single-family and mixed-family matrix before changing saved-map behavior. See
[the upgrade note](../REVISIT_NOTES.md) and [upstream report](https://forums.factorio.com/131528).

<a id="births"></a>
## Runtime lifecycle

The sole dispatcher is control.lua. One exclusive created-effect notification
observes known hostile unit, spider-unit, unit-spawner and turret bodies, preserving
existing effects. Policy reads the actual surface's control; missing controls
preserve behavior. Global no-enemies wins on supported family/surface pairs.
Peaceful mode, player/neutral/allied forces and unsupported planets remain unchanged.
Vault guardians inheriting a custom hostile force follow the same suppression policy.
Ordinary Nauvis bodies use an explicit whitelist; they cannot absorb other families.
Arachnid coverage includes all twenty bodies. Toxic includes bosses and exact
infected ship/radar/gun/laser/artillery bodies; unrelated player turrets are excluded.

Blocked births become disabled by script. Egg rafts stay destructible. Other
blocked bodies become indestructible and enter the shared FIFO at
storage.ei.planet_enemies with entity, key and due_tick=event.tick+1. Dependencies
can finish using their returned entity, notably Fulgora's boosted vault guardian.
Mandatory service silently destroys at most 128 records per tick, including stale
references, without death events, loot or offspring. Idle admission only inspects
the head/deadline. Save/load preserves the FIFO; no recurring world scans exist.

Only rafts this version newly disables receive an object-destruction registration
and ownership record. On restores owned rafts through the shared queue, at most
64 records per tick, while respecting current global/family Off. Destruction and
surface events prune records. Pre-v2 or externally disabled rafts are never adopted.
Authorized admin summons use a one-creation surface/name/force exemption restored
on success or error; subsequent offspring still follow the surface's live policy.

Demolishers use on_segmented_unit_created and immediate whole-unit destroy(),
which that API supports during creation. Head creation is not observed: a segment
may reappear on an old unit, which must not be mistaken for a new hostile birth.

<a id="gaia"></a>
## Gaia and upgrades

[Gaia's owner](gaia-and-alien-systems.md#contract) retains association/reforge
ownership. Native planet.create_surface preserves menu settings. Fallback uses
save defaults; reforge captures source settings before purge/deletion. Controls,
seed, starting settings, cliff choices and peace/no-enemies flags survive; final prototypes supply
current noise aliases. Explicit new values win over translated legacy values,
including zero. Configuration changes translate Gaia electric, Vulcanus hot and
Aquilo frost controls and install owned aliases. Existing enemies and chunks are
not scanned, purged or regenerated; changes govern future generation and births.
The [map-settings owner](map-settings.md#lifecycle) merges sparse saved overrides
before fallback/reforge staging and rechecks them when the replacement is ready.

<a id="verification"></a>
## Verification

Focused fixtures under scripts/qc/planet-enemies cover resolved controls, native
placement, independence, scripted births, egg supply, whole demolishers, queue
bounds and persistence. Actual menu, runtime and source checks are separate
evidence. Unrelated broad-wrapper scratch failures do not establish engine failure
or a successful full preflight for this subsystem.
