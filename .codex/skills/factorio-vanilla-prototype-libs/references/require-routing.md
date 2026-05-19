# Require Routing

Use this reference when choosing between a vanilla prototype module, core lualib, ESIR `ei_lib`, or direct mutation.

## Boundary Check

- `data/core/lualib`: use `factorio-core-lualib`.
- `data/base/prototypes`: use this skill's Base map.
- `data/space-age/prototypes`: use this skill's Space Age map.
- `data/quality/prototypes`: use this skill's Quality map.
- `data/elevated-rails/prototypes`: use this skill's Elevated Rails map.
- Official runtime/prototype API symbols: use `factorio-lua-docs`.
- Generic Lua advice in Factorio's sandbox: use `factorio-lua-assumptions`.

## Require Forms

Both dot and slash forms are seen in vanilla and ESIR:

```lua
local sounds = require("__base__.prototypes.entity.sounds")
local sounds = require("__base__/prototypes/entity/sounds")
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")
local planet_map_gen = require("__space-age__/prototypes/planet/planet-map-gen")
local recycling = require("__quality__/prototypes/recycling")
```

Use the style that best matches nearby code. Be explicit with `__mod-name__` when reaching across mod boundaries. Keep requires at module load time.

## Decision Matrix

- Use vanilla prototype modules when the desired behavior is canonical Factorio content shape: sounds, hit effects, item effects, explosion/smoke/particle animations, tile helpers, asteroid routes, planet map-gen, recycling generation, processions, cargo-pod catalogues, or graphics table precedent.
- Use `factorio-core-lualib` when the desired helper is `util`, `meld`, `math2d`, `math3d`, `resource-autoplace`, `collision-mask-util`, `mod-gui`, `event_handler`, or another core lualib module.
- Use `ei_lib` when the behavior is ESIR policy: shared recipe/technology mutation, tooltip/status fields, prototype normalization, runtime entity safety, scheduler/state plumbing, compatibility policy, or reusable ESIR table/string helpers.
- Use direct assignment when changing one or two obvious fields on a known prototype.
- Use local helper code only when none of the above surfaces express the behavior cleanly and the logic is too specific to belong in `ei_lib`.

## Dependency And Stage Notes

- Base is always present.
- Space Age, Quality, and Elevated Rails require declared dependencies or guarded data-stage paths.
- Data/prototype helper imports belong in `data.lua`, `data-updates.lua`, `data-final-fixes.lua`, or modules loaded from those stages.
- Do not move these imports into runtime event handlers, console commands, remote interfaces, or migration bodies without a stage-specific reason.
- Picture modules can execute helper/global setup while loading. Inspect the file before assuming it is a pure table export.

## Re-Survey Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task doctor

$factorio = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio'
Get-ChildItem "$factorio\data" -Directory | Select-Object -ExpandProperty Name
Get-ChildItem "$factorio\data" -Directory -Recurse -Filter lualib | Select-Object -ExpandProperty FullName

rg --no-heading --line-number 'require\("__(base|space-age|quality|elevated-rails)__[./]' exotic-space-industries-remembrance -g '*.lua'
rg --no-heading --line-number '^local [A-Za-z0-9_]+ = \{\}|^return [A-Za-z0-9_]+|^[A-Za-z0-9_]+\.[A-Za-z0-9_]+\s*=\s*function|^function [A-Za-z0-9_]+\.' "$factorio\data\base\prototypes" "$factorio\data\space-age\prototypes" "$factorio\data\quality\prototypes" "$factorio\data\elevated-rails\prototypes" -g '*.lua'
```
