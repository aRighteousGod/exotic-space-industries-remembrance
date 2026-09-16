# Spider vehicle weapon controls

Implementation contract for Factorio **2.0.77**, replacing the earlier feasibility proposal. Runtime behavior is in `scripts/control/spider-vehicles.lua`, dispatched by ESIR's `control.lua`; prototype names and balance come from the shared spider catalog.

## Player controls

The relative panel beside the native spidertron window provides **Artillery** for assault vehicles, **Doeworks launcher** for rocket vehicles, and **Weapon cycling** for both. Mount switches remain locked before mount research. Scouts have no mounted-weapon panel; their equipment lasers remain available.

| Startup `ei-spider-range-aware-cycling` | Vehicle cycling | Effective mode |
| --- | --- | --- |
| Enabled (default) | On | Scripted range-aware turns |
| Enabled | Off | Hold selected weapon |
| Disabled | On | Native Factorio cycling |
| Disabled | Off | Hold selected weapon using a cycling-disabled body |

Hold enables the selected-weapon dropdown. The native automatic-targeting controls still decide whether the vehicle targets with or without a gunner. Scripted selection yields to a manually firing gunner. Disabling the startup setting removes selector searches and ammunition bookkeeping; native mixed-range cycling limitations remain.

Requested preferences and effective mode/mount state are shown separately while a safe replacement is pending. Occupants, the native opened vehicle, stable GUI identity, and the relative panel are rebound after a successful swap. Both driver-operated mount toggles are covered by the player fixture.

## Sustained turns

| Group | Turn |
| --- | --- |
| Cannon | Two shots |
| MG / miniguns | 120 ticks from first observed shot |
| Flamethrower | 180 ticks from first observed shot |
| Artillery | One shell |
| Ordinary rocket battery | Four rockets total, advancing through eligible loaded slots |
| Doeworks | 90 ticks from first observed shot |

Assault order is cannon → MG → flamethrower → artillery. Rocket order is ordinary battery → Doeworks. Empty, unavailable, disabled, and out-of-range groups are skipped. Timed deadlines survive target changes; empty ammunition or loss of eligible targets ends a turn early. A sole eligible group continues without an idle interval.

Eligibility includes valid hostile military targets, minimum/maximum range, the ammunition's range modifier and target filter, and the attack's range mode. Local searches cover the entire relevant area without an entity-count cutoff. Cached targets are revalidated between searches. Target refreshes use the shared scheduler at 15 ticks during engagement and 60 while idle, with a fair queue and a global cap of eight localized searches per tick. Under saturation, actual refresh intervals increase.

Factorio still owns aiming, targeting, damage and ammunition use. Changing the selected slot preserves the engine's shared firing delay; these mounts do not fire independently. A further native limitation exists when an enemy inside a long-range gun's minimum range conceals a farther valid enemy from the engine's own aiming. ESIR finds the farther enemy, but Factorio exposes no spider shooting-target setter. If the gun does not fire after the observed shared delay and 30 ticks of acquisition allowance, the selector yields to another eligible group. The long-range group becomes productive when native aiming can acquire its target, including after the closer enemy dies. No scripted projectiles or enemy-state changes are used.

Smart rocket bodies use ordinary gun cooldowns of **30/24/18 ticks**. Hold and native bodies retain **60/48/36**; native four-slot cycling provides the original **30/24/18** battery cadence. Doeworks remains **30/20/10/1.5** ticks. Its spider-mounted gun uses a full-circle firing arc instead of the stationary turret's narrow arc.

## Prototypes and state

Existing native configuration names remain unchanged. Every armed configuration has a `-hold` variant; rocket configurations also have `-smart` variants. Assault scripted mode uses the Hold body. All names exist in both startup modes, avoiding missing entities when settings change.

There are **24,388 gameplay configurations**: 13 scouts, 23,400 assaults, and 975 rocket vehicles. Enhancements receives 24,388 corresponding boarding proxies. Graphics and legs are shared. Mount toggles reuse existing artillery-zero / Doeworks-zero configurations and add no extra combinations.

The original survives until the replacement candidate has received all state. Removed final-slot ammunition is inserted into compatible candidate cargo, including existing stacks, preserving quality and partial magazines. Failed capacity checks discard the candidate and leave the source intact. Re-enabling restores an available matching type/quality cargo stack to the empty mount; missing ammunition is never recreated.

Stable records retain preferences through coalesced research bursts, force refreshes, replacement, save/load and boarding. Clones copy preferences into a new identity. Player and robot mining store preferences by the mined item's `item_number`; player `consumed_items` and robot `stack` build events restore them. Registering the item's `LuaItem` for destruction removes records when it is consumed or discarded.

## Remote interface

`exotic-industries-spider-vehicles` adds:

```lua
remote.call("exotic-industries-spider-vehicles", "get_weapon_controls", entity)
remote.call("exotic-industries-spider-vehicles", "set_weapon_controls", entity, {
    cycling = false,
    special = false,       -- artillery or Doeworks, according to vehicle family
    selected_slot = 2,     -- accepted only with cycling off
})
```

Changes pass through the same validation used by the GUI. Invalid input returns `nil, error`; unknown keys, invalid booleans, unsupported vehicles, out-of-bounds slots and selecting a slot while cycling are rejected. Omitted preferences retain their current values.

Results include `vehicle_id`, requested `cycling` / `special`, actual `selected_slot`, `requested_mode`, `effective_mode`, `effective_special`, `special_unlocked`, `smart_setting`, `pending`, and `pending_reason`. A queued disable must be read as pending until its effective state changes. Existing replacement events and force/vehicle refresh hooks remain available; integrations assigning `entity.force` directly must call `refresh_vehicle`.

See [the acceptance fixture](README.md) for reproducible commands and the boundaries of headless GUI and compatibility coverage.
