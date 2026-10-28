# Quality, Recycler And Elevated Rails Prototype Libs

Survey sources:

- `.factorio-qc/f21/data/quality/prototypes`
- `.factorio-qc/f21/data/recycler`
- `.factorio-qc/f21/data/elevated-rails/prototypes`

Verified against full Factorio 2.1.23 build 87750. Quality's former recycling
helper and graphics now belong to the separate Recycler mod.

These surfaces require the corresponding vanilla mod dependency or guarded usage. Do not assume Quality or Elevated Rails helpers are available in every data-stage context.
This reference tracks installed game files. Do not update its survey assumptions from the hosted Lua API docs alone.

## Recycler

- `__recycler__/recycling`: returns `lib` with `generate_recycling_recipe(recipe, can_recycle)` and `generate_self_recycling_recipe(item)`.
- The helper supports an eligibility predicate, creates unlock effects on the recycling technology and disables generated recipes until research. Deleting generated recipes must remove dangling unlock effects; repeated generation must deduplicate unlocks without replacing the captured effects table.
- The 2.1 default predicate no longer excludes the old chemistry/smelting/organic/crushing families. Reverse recipes divide duration by output count, unlike 2.0. Both differences require an explicit balance decision, not just an import rename. Recipe `auto_recycle = false` can still allow the item's self-recycling fallback; item-level `auto_recycle = false` suppresses that fallback too.
- ESIR uses this in `scripts/data-final-updates/recycling.lua` to regenerate recycling recipes after recipe changes.
- `__recycler__/recycler-pictures`: returns recycler graphics data; its assets also use the `__recycler__` root.

Prefer the Recycler helper for native generated recipe structure. Keep ESIR eligibility, timing and explicit output policies in their ESIR owner; verify final data against the preserved baseline.

## Elevated Rails

- `__elevated-rails__.prototypes.sloped-trains-updates`: returns an update helper with `apply_all_base()` for Elevated Rails train/base updates.
- `__elevated-rails__.prototypes.elevated-rail-pictures`: exposes elevated rail and rail ramp picture helpers, including rail/remnant/fence/ramp picture construction and graphics shifting helpers.

Use Elevated Rails modules as narrow vanilla precedent. Avoid importing the picture helper surface unless ESIR is deliberately matching Elevated Rails rail graphics structure and the dependency is guaranteed.

## Re-Check Commands

```powershell
$recycler = '.factorio-qc/f21/data/recycler'
$rails = '.factorio-qc/f21/data/elevated-rails/prototypes'
rg --no-heading --line-number 'generate_recycling_recipe|generate_self_recycling_recipe|return lib' $recycler -g '*.lua'
rg --no-heading --line-number 'apply_all_base|rail_pictures|return updates' $rails -g '*.lua'
rg --no-heading --line-number '__(quality|elevated-rails)__' exotic-space-industries-remembrance -g '*.lua'
```
