# Quality And Elevated Rails Prototype Libs

Survey sources:

- `C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\quality\prototypes`
- `C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\elevated-rails\prototypes`

These surfaces require the corresponding vanilla mod dependency or guarded usage. Do not assume Quality or Elevated Rails helpers are available in every data-stage context.
This reference tracks installed game files. Do not update its survey assumptions from the hosted Lua API docs alone.

## Quality

- `__quality__/prototypes/recycling`: returns `lib` with `generate_recycling_recipe(recipe, can_recycle)` and `generate_self_recycling_recipe(item)`.
- The recycling helper uses vanilla Quality defaults, skips many category/item cases, builds recycling recipes, and supports an optional `can_recycle` predicate for custom eligibility.
- ESIR uses this in `scripts/data-final-updates/recycling.lua` to regenerate recycling recipes after recipe changes.
- `__quality__.prototypes.entity.recycler-pictures`: returns recycler graphics data; use as read-only picture precedent unless intentionally matching the vanilla recycler table shape.

Prefer the Quality recycling helper when ESIR wants vanilla recycling semantics after prototype mutations. Prefer `ei_lib` when the change is ESIR recipe ownership, visibility policy, or compatibility filtering before calling the vanilla generator.

## Elevated Rails

- `__elevated-rails__.prototypes.sloped-trains-updates`: returns an update helper with `apply_all_base()` for Elevated Rails train/base updates.
- `__elevated-rails__.prototypes.elevated-rail-pictures`: exposes elevated rail and rail ramp picture helpers, including rail/remnant/fence/ramp picture construction and graphics shifting helpers.

Use Elevated Rails modules as narrow vanilla precedent. Avoid importing the picture helper surface unless ESIR is deliberately matching Elevated Rails rail graphics structure and the dependency is guaranteed.

## Re-Check Commands

```powershell
$quality = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\quality\prototypes'
$rails = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\elevated-rails\prototypes'
rg --no-heading --line-number 'generate_recycling_recipe|generate_self_recycling_recipe|return lib' $quality -g '*.lua'
rg --no-heading --line-number 'apply_all_base|rail_pictures|return updates' $rails -g '*.lua'
rg --no-heading --line-number '__(quality|elevated-rails)__' exotic-space-industries-remembrance -g '*.lua'
```
