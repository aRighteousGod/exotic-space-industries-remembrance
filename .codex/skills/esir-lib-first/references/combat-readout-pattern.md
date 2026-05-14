# Combat Readout Pattern

Use this when a scripted weapon, turret, vehicle, or support system needs visible damage/readout truth that Factorio cannot infer from vanilla prototype damage alone.

## Repo Examples

- Singularity Lance:
  `prototypes/alien-system/singularity-lance.lua` owns prototype tooltip rows through `ei_lib.set_custom_tooltip_fields`.
  `scripts/control/singularity-lance.lua` owns the placed-entity DPS line through `entity.custom_status` and force-indexed damage caches.
- Emerald Apocalypse orbital shards:
  `prototypes/exotic-age/emerald-apocalypse-hover-tank.lua` adds shard payload tooltip rows to the vehicle and item.
  `scripts/control/emerald-apocalypse-hover-tank.lua` and `scripts/control/emerald-apocalypse-orbital-shards.lua` keep the placed tank's shard DPS status current with late laser research.

## Prototype Tooltip Rows

- Prefer `ei_lib.set_custom_tooltip_fields(prototype, fields, opts)` over assigning `prototype.custom_tooltip_fields` directly.
- Put stable, base-value rows in `[custom-tooltip]` locale. Use a short header row only when it makes scripted payload rows easier to scan.
- Use item-specific `show_in_factoriopedia = false` only when the item tooltip should differ from the placed entity or avoid duplicate Factoriopedia rows.
- Format numbers locally in the prototype file when the values are constants or startup config outputs; avoid leaking runtime-only force state into data stage.

## Runtime Custom Status

- Validate with `ei_lib.entity_check(entity)` before setting or clearing `entity.custom_status`.
- Set the readout as:

```lua
entity.custom_status = {
    diode = defines.entity_status_diode.green,
    label = {"entity-status.example-current-dps", value, {"damage-type-name.laser"}},
}
```

- Put placed-entity readout strings in `[entity-status]` locale. Keep them short; this is the small entity status line, not a GUI panel.
- Clear `entity.custom_status` on destroy or deregistration when the module already receives that lifecycle event.
- `LuaEntity::custom_status` is runtime-only. The local Factorio docs cache confirms the attribute in Factorio 2.0.76.

## Force-Scaled Numbers

- Cache force-derived values by force index when the readout depends on research, quality, or other force-owned state.
- Refresh caches and statuses on `check_global`, rebuild/configuration change, build/register, `on_research_finished`, and `on_scripted_research_burst` if scripted research can affect the value.
- Prefer `event.tick` or an explicit `current_tick` passed through the call chain; use `game.tick` only from helpers without an event context.
- Keep base tooltip values and current runtime status values intentionally distinct: tooltips teach the payload, status lines report the live force-tuned number.
