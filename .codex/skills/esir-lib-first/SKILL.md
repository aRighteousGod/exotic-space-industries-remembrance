---
name: esir-lib-first
description: "Prefer the shared `ei_lib` helper surface in `exotic-space-industries-remembrance/lib/lib.lua` before creating new Lua local functions. Use when Codex edits ESIR runtime, data-stage, prototype, migration, or support Lua files and might add utility helpers, table or string helpers, recipe or technology mutation helpers, notification helpers, color or formatting helpers, or wrappers around `data.raw`. For runtime queue, delayed-bucket, telemetry-gate, counter, or status-snapshot plumbing, prefer `exotic-space-industries-remembrance/lib/runtime-scheduler.lua` instead. Inspect `ei_lib` first when the helper is general utility; if it almost fits, extend or harden the shared function instead of inventing a one-off local helper."
---

# ESIR Lib First

Open [`exotic-space-industries-remembrance/lib/lib.lua`](../../../exotic-space-industries-remembrance/lib/lib.lua) before adding any new helper with shared utility shape.

`ei_lib` is already loaded by both [`data.lua`](../../../exotic-space-industries-remembrance/data.lua) and [`control.lua`](../../../exotic-space-industries-remembrance/control.lua), so it is the default shared helper layer for this repo.

## Working Rules

- Reuse an existing `ei_lib` function when it already covers the need.
- If the gap is small and the behavior is broadly useful, extend or harden `ei_lib` instead of adding another file-local helper.
- Do not add `*_if_present` wrappers around `ei_lib.add_unlock_recipe`; it already nil-guards missing techs and recipes and leaves the caller cleaner when used directly.
- When a patch needs to replace recipe ingredients and also clear legacy `normal`/`expensive` variants or force `enabled`, prefer `ei_lib.recipe_new(..., opts)` over a file-local `set_recipe_ingredients` helper.
- When multiple files need the same layered icon composition, prefer `ei_lib.make_icons(...)` over cloning another local `make_icons` helper.
- For runtime queue, delayed-bucket, telemetry-gate, counter, cadence, or status-snapshot plumbing, inspect `exotic-space-industries-remembrance/lib/runtime-scheduler.lua` before adding or extending `ei_lib`.
- For runtime entity safety, prefer `ei_lib.entity_check`, `ei_lib.get_valid_entity`, and `ei_lib.get_entity_unit_number` over reviving file-local `entity ~= nil and entity.valid` clones. `get_entity_unit_number` is only safe key extraction, not proof the entity can be dereferenced.
- For shared quality scaling, prefer `ei_lib.get_normalized_quality_factor(entity_or_stack)` over cloning module-local normalizers.
- If a runtime module relies on tombstoned queue entries, live-set tracking, or other queue semantics that the shared scheduler almost covers, extend `runtime-scheduler.lua` compatibly before reviving a private dequeue helper.
- When shared helper behavior moves between local code, `ei_lib`, and `runtime-scheduler.lua`, update the associated skill/reference wording in the same patch.
- If helper consolidation intentionally stops short because semantics still differ, add a follow-up note to [`.codex/esir/REVISIT_NOTES.md`](../../esir/REVISIT_NOTES.md) in the same patch.
- Keep new local helpers only for behavior that is genuinely module-specific, closure-bound, or tied to local state or event wiring in a way that would make `ei_lib` awkward.
- Preserve compatibility when upgrading `ei_lib`. Prefer optional parameters, nil-safe guards, and broadened behavior over signature churn.
- Before adding a new helper name, scan the existing surface with:

```powershell
rg -n '^function ei_lib\.' exotic-space-industries-remembrance/lib/lib.lua
```

- Before changing shared behavior, scan likely callers with:

```powershell
rg -n 'ei_lib\.<name>' exotic-space-industries-remembrance -g '*.lua'
```

## Prefer These Surfaces

Read [references/ei-lib-surface.md](./references/ei-lib-surface.md) when you want the quick map.

- String and table utility: `contains`, `startswith`, `starts_with`, `endswith`, `clean_nils`, `unique_values_only`, `table_contains_value`, `getn`, `clamp`, `switch_string`, `table_to_string`
- General runtime and player utility, excluding queue/delayed-bucket/status plumbing: `config`, `get_event_tick`, `entity_check`, `get_valid_entity`, `get_entity_unit_number`, `get_normalized_quality_factor`, `get_player_setting_value`, `player_allows_notification`, `notify_connected_players`, `crystal_echo`, `crystal_echo_floating`
- Prototype and `data.raw` mutation: `raw`, `modify_data_raw`, `recursive_copy`, `recursive_insert`, `set_properties`, `patch_nested_value`
- Recipe and technology mutation: `recipe_*`, `set_prerequisites`, `add_prerequisite`, `remove_prerequisite`, `remove_unlock_recipe`, `add_unlock_recipe`, `set_science_packs`, `set_age_packs`, `copy_science_packs`, `disable`, `enable`
- Graphics, icons, animation, and tint helpers: `empty_sprite`, `make_4way_animation_from_spritesheet`, `make_circuit_connector`, `entity_icon_scaler`, `lerp_color`, `hex_to_rgb_*`, `rgb_to_hex`, `pick_tint_from_intent`

## Decision Test

Before writing a new local function, ask:

1. Is this really only for this file and this one call path?
2. Is there already an `ei_lib` helper that does most of it?
3. Would another ESIR module plausibly need the same guard, transform, or mutation pattern?

If the answers are "no", "yes", or "probably", prefer `ei_lib`.
