# EI Lib Surface

Use this as the fast map before you read the whole library file.

## Search

```powershell
rg -n '^function ei_lib\.' exotic-space-industries-remembrance/lib/lib.lua
```

`ei_lib` is loaded at the top of both `data.lua` and `control.lua`, so shared helpers here are available across the usual ESIR Lua surfaces.

## Function Families

- General utility:
  `endswith`, `startswith`, `contains`, `is_valid_number`, `clean_nils`, `clamp`, `unique_values_only`, `table_contains_value`, `patch_nested_value`, `get_random_different_value`, `table_to_string`, `switch_string`, `get_event_tick`, `config`, `getn`
- Runtime entity safety:
  `entity_check`, `get_valid_entity`, `get_entity_unit_number`
- Prototype and raw access:
  `modify_data_raw`, `raw`, `recursive_copy`, `recursive_insert`, `set_properties`
- Localization and prototype text:
  `overwrite_entity_and_description`, `overwrite_entity_name`, `overwrite_description`
- Recipe and technology mutation:
  `recipe_swap`, `fix_recipe`, `recipe_output_add`, `recipe_add`, `recipe_remove`, `recipe_new`, `recipe_hard_overwrite`, `set_prerequisites`, `add_prerequisite`, `remove_prerequisite`, `remove_tech_ingredient`, `remove_unlock_recipe`, `add_unlock_recipe`, `convert_short_ingredients_to_full`, `set_science_packs`, `set_age_packs`, `copy_science_packs`, `remove_tech`, `disable`, `enable`, `enable_from_start`
- Graphics and entity helpers:
  `empty_sprite`, `make_4way_animation_from_spritesheet`, `make_circuit_connector`, `entity_icon_scaler`, `get_entity_area`, `get_box_area`, `get_entity_area_change`, `add_item_level`, `merge_fluid`, `do_fluid_merge`, `merge_item`, `do_item_merge`, `debug_crafting_categories`, `strike_lightning`
- Echo, color, and notification helpers:
  `format_echo`, `lerp_color`, `rgb_to_hex`, `hex_to_rgb_normalized`, `hex_to_rgb_raw`, `get_adjective_and_tint`, `pick_tint_from_intent`, `generate_crystal_gradient_stops`, `pick_gradient_stops`, `crystal_echo`, `crystal_echo_floating`, `get_player_setting_value`, `player_allows_notification`, `notify_connected_players`

## House Notes

- `startswith` and `starts_with` already both exist. Do not add a third spelling.
- `lerp_color` and `rgb_to_hex` are each defined twice later in the file. If you touch them, update carefully and confirm which definition wins.
- Prefer `ei_lib.raw` or `ei_lib.modify_data_raw` before open-coded `data.raw` mutation when the operation is a shared mutation pattern rather than a one-off prototype tweak.
- If a helper is almost right, favor a backward-compatible improvement over a sibling helper with a near-identical name.
- `ei_lib.get_event_tick` and `ei_lib.config` are general runtime utilities, not the runtime scheduling abstraction. For queues, delayed buckets, telemetry gates, counters, cadence, and status snapshots, check `exotic-space-industries-remembrance/lib/runtime-scheduler.lua` first.
- `ei_lib.get_entity_unit_number` is a safe `.unit_number` read, not a validity check. When later code needs the entity itself, pair it with `entity_check` or `get_valid_entity`.
