# Spider vehicle weapon controls

Implementation contract for Factorio **2.0.77**, replacing the earlier feasibility proposal. Runtime behavior is in `scripts/control/spider-vehicles.lua`, dispatched by ESIR's `control.lua`; prototype names and balance come from the shared spider catalog.

## Player controls

The relative panel beside the native spidertron window provides **Artillery** for assault vehicles, **Artillery rocket launcher** for rocket vehicles, and **Weapon cycling** and **Overkill prevention** for both. Mount switches remain locked before mount research. Scouts have no mounted-weapon panel; their equipment lasers remain available.

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
| Artillery rockets | 90 ticks from first observed shot |

Assault order is cannon → MG → flamethrower → artillery. Rocket order is ordinary battery → artillery rocket. Empty, unavailable, disabled, and out-of-range groups are skipped. Timed deadlines survive target changes; empty ammunition or loss of eligible targets ends a turn early. A sole eligible group continues without an idle interval.

Eligibility includes valid hostile military targets, minimum/maximum range, the ammunition's range modifier and target filter, and the attack's range mode. Local searches cover the entire relevant area without an entity-count cutoff. Cached targets are revalidated between searches. Target refreshes use the shared scheduler at 15 ticks during engagement and 60 while idle, with a fair queue and a global cap of eight localized searches per tick. Under saturation, actual refresh intervals increase.

Factorio still owns aiming, targeting, damage and ammunition use. Changing the selected slot preserves the engine's shared firing delay; these mounts do not fire independently. A further native limitation exists when an enemy inside a long-range gun's minimum range conceals a farther valid enemy from the engine's own aiming. ESIR finds the farther enemy, but Factorio exposes no spider shooting-target setter. If the gun does not fire after the observed shared delay and 30 ticks of acquisition allowance, the selector yields to another eligible group. The long-range group becomes productive when native aiming can acquire its target, including after the closer enemy dies. No scripted projectiles or enemy-state changes are used.

Smart rocket bodies use ordinary gun cooldowns of **30/24/18 ticks**. Hold and native bodies retain **60/48/36**; native four-slot cycling provides the original **30/24/18** battery cadence. Artillery rocket cooldown remains **30/20/10/1.5** ticks. Its spider-mounted gun uses a full-circle firing arc instead of the stationary turret's narrow arc.

## Overkill prevention

**Off by default**, this per-vehicle preference is effective only with the range-aware startup setting enabled and vehicle cycling On. It remains saved while inactive; the panel explains **Requires range-aware weapon cycling**. An active automatic-fire hold displays **Holding fire: damage in flight**. The panel updates on state transitions, without a per-tick GUI rebuild.

Native launch observations reserve each spider's estimated immediate cannon, rocket, artillery and artillery-rocket damage against its actual target. A target is covered when those reservations reach **120% of its current health**. Quality, force ammunition bonuses, weapon damage modifiers and target resistances apply. Whole shots and native attacks within a tick can exceed that threshold. There is no fleet coordination or splash reservation against neighboring enemies.

Only deterministic immediate payload damage is credited. Ongoing fire, corrosion, delayed or probabilistic payloads, equipment lasers and uncertain ammunition are excluded. For scattered artillery rockets, only splash large enough to cover the intended point throughout the configured scatter contributes. Shielded entities and ambiguous position attribution fail open. Machine guns and flamethrowers reserve no damage; their launch observations only identify unsuccessful alternative-weapon probes.

The selector first tries groups with an eligible uncovered target. It cannot assign the spider's native shooting target. If native aiming still fires at a covered enemy, that group gets no further probe while the target's reservation revision remains unchanged. If no useful group remains, both native automatic-targeting flags are temporarily suppressed. Requested targeting settings are restored on release, disable, manual gunnery, mode changes, refits and boarding. Movement, logistics, equipment lasers and manual fire remain available.

Matched native impacts retire reservations, including observed misses. Death or movement away from a fixed impact area releases obsolete reservations. Lost or ambiguous impact notifications expire after **300 ticks**; payloads whose estimated flight cannot fit safely inside that interval remain unsupported. Current health is reassessed, so regeneration can make a target eligible again. A periodic refresh alone does not renew failed probes. Enabling starts with subsequent launches; it never invents reservations for earlier shots.

This adds no prototype combinations or refits. Preferences use the existing stable record and mined-item transport. Live reservation and expiry state survives ordinary save/load; a configuration change restores targeting and discards old predictions. Prediction uses the selector's existing target cache and search budget. With prevention Off there are no prediction searches or reservation monitoring; observational script events return immediately. With the startup setting disabled, observation hooks are omitted and selector/ammunition/prediction work is absent.

## Prototypes and state

Existing native configuration names remain unchanged. Every armed configuration has a `-hold` variant; rocket configurations also have `-smart` variants. Assault scripted mode uses the Hold body. All names exist in both startup modes, avoiding missing entities when settings change.

There are **24,388 gameplay configurations**: 13 scouts, 23,400 assaults, and 975 rocket vehicles. Enhancements receives 24,388 corresponding boarding proxies. Graphics and legs are shared. Mount toggles reuse the existing configurations without the relevant mount and add no extra combinations.

The original survives until the replacement candidate has received all state. Removed final-slot ammunition is inserted into compatible candidate cargo, including existing stacks, preserving quality and partial magazines. Failed capacity checks discard the candidate and leave the source intact. Re-enabling restores an available matching type/quality cargo stack to the empty mount; missing ammunition is never recreated.

Stable records retain preferences through coalesced research bursts, force refreshes, replacement, save/load and boarding. Clones copy preferences into a new identity. Player and robot mining store preferences by the mined item's `item_number`; player `consumed_items` and robot `stack` build events restore them. Registering the item's `LuaItem` for destruction removes records when it is consumed or discarded.

## Remote interface

`exotic-industries-spider-vehicles` adds:

```lua
remote.call("exotic-industries-spider-vehicles", "get_weapon_controls", entity)
remote.call("exotic-industries-spider-vehicles", "set_weapon_controls", entity, {
    cycling = false,
    special = false,       -- artillery or artillery rocket, according to vehicle family
    selected_slot = 2,     -- accepted only with cycling off
    overkill = true,       -- retained but inactive in Hold/native mode
})
```

Changes pass through the same validation used by the GUI. Invalid input returns `nil, error`; unknown keys, invalid booleans, unsupported vehicles, out-of-bounds slots and selecting a slot while cycling are rejected. Omitted preferences retain their current values.

Results include `vehicle_id`, requested `cycling` / `special` / `overkill`, actual `selected_slot`, `requested_mode`, `effective_mode`, `effective_special`, `special_unlocked`, `smart_setting`, `pending`, and `pending_reason`. `effective_overkill` reports whether prevention is active, `holding_fire` reports effective automatic-fire suppression, and `overkill_reason` is `requires-scripted-cycling`, `pending-mode`, `damage-in-flight`, or nil. A queued disable must be read as pending until its effective state changes. Existing replacement events and force/vehicle refresh hooks remain available; integrations assigning `entity.force` directly must call `refresh_vehicle`.

See [the acceptance fixture](README.md) for reproducible commands and the boundaries of headless GUI and compatibility coverage.

With range-aware cycling disabled at startup, ammunition receives no spider observation hooks and the shared script-effect dispatcher registers no spider effect IDs. Enabled mode uses exact IDs exported by the data-stage hook pass, without per-event prefix searches. The engine filters damage events to electric hits, spider vehicles, the Emerald Apocalypse hover tank and Hemocrystal Wall; the dispatcher calls only the relevant owners. Assault reactive smoke remains available in either mode. Its handler uses the existing vehicle/research records and rejects unavailable smoke or an active cooldown before checking diplomacy or inventories. A constant-time work predicate remains each tick; future smoke and refit buckets wake the updater only when due. Lifecycle events, upgrades and GUI controls remain active.
