---
name: factorio-vanilla-prototype-libs
description: "Use when Codex needs to import, audit, replace, or choose Factorio vanilla prototype helper modules from `data/base`, `data/space-age`, `data/quality`, or `data/elevated-rails` in ESIR or other Factorio mod Lua. Covers `__base__.prototypes.*`, `__space-age__.prototypes.*`, `__quality__/prototypes/recycling`, `__elevated-rails__` prototype helpers, canonical sounds, hit effects, item effects, asteroid spawn definitions, planet map-gen, recycling generation, tile helpers, graphics table precedent, require forms, and when to prefer vanilla helpers, core lualib, ESIR `ei_lib`, or direct prototype mutation."
---

# Factorio Vanilla Prototype Libs

Use this skill when a task touches importable vanilla helper modules outside Factorio's `data/core/lualib` tree.

The current survey was taken from local Factorio 2.0.76:

```powershell
$factorio = 'C:\Program Files (x86)\Steam\steamapps\common\Factorio'
Get-ChildItem "$factorio\data\base\prototypes" -Recurse -Filter *.lua
Get-ChildItem "$factorio\data\space-age\prototypes" -Recurse -Filter *.lua
Get-ChildItem "$factorio\data\quality\prototypes" -Recurse -Filter *.lua
Get-ChildItem "$factorio\data\elevated-rails\prototypes" -Recurse -Filter *.lua
```

Space Age does not have a `data/space-age/lualib` directory. Its reusable Lua surfaces are prototype modules under `data/space-age/prototypes`.

## Workflow

1. Classify the import surface:
   - Core lualib: use [`factorio-core-lualib`](../factorio-core-lualib/SKILL.md).
   - Vanilla prototype module: continue with this skill.
   - Runtime API/prototype schema question: use `factorio-lua-docs`.
   - ESIR-owned helper or policy: use `esir-lib-first`.
2. Confirm the dependency exists for the pack being edited. Base is always present; Space Age, Quality, and Elevated Rails require declared dependencies or guarded usage.
3. Read the smallest reference that matches the import:
   - Base helpers: [references/base-prototype-libs.md](./references/base-prototype-libs.md)
   - Space Age helpers: [references/space-age-prototype-libs.md](./references/space-age-prototype-libs.md)
   - Quality and Elevated Rails helpers: [references/quality-elevated-rails.md](./references/quality-elevated-rails.md)
   - Require forms and decision matrix: [references/require-routing.md](./references/require-routing.md)
4. Verify exact semantics against the installed Factorio file before changing behavior. Do not vendor or copy large vanilla source into ESIR.

## Require Forms

Vanilla prototype modules commonly use both dot and slash forms:

```lua
local sounds = require("__base__.prototypes.entity.sounds")
local sounds = require("__base__/prototypes/entity/sounds")
local item_effects = require("__space-age__.prototypes.item-effects")
local asteroid_util = require("__space-age__.prototypes.planet.asteroid-spawn-definitions")
local recycling = require("__quality__/prototypes/recycling")
```

- Prefer the require style already used in the nearby file unless changing it improves clarity.
- Use explicit `__base__`, `__space-age__`, `__quality__`, or `__elevated-rails__` imports for cross-mod vanilla helper use.
- Keep `require()` at module load time. Do not add dynamic `require()` calls inside runtime event handlers, remote interfaces, or console command bodies.
- Treat vanilla helper modules as data/prototype-stage surfaces unless a file is clearly scenario or migration infrastructure.

## ESIR Decision Rules

- Prefer vanilla prototype modules for canonical Factorio sounds, hit effects, item effects, explosion or smoke animations, tile helper tables, asteroid route definitions, planet map-gen tables, recycling generation, and vanilla graphics table precedent.
- Prefer `factorio-core-lualib` for `util`, `meld`, `math2d`, `math3d`, `resource-autoplace`, `mod-gui`, `event_handler`, and other `data/core/lualib` helpers.
- Prefer `ei_lib` when the behavior is ESIR policy, shared ESIR mutation, recipe or technology ownership, tooltip/status wiring, runtime scheduler/state plumbing, or entity safety.
- Prefer direct assignment for one or two simple fields on an already-known prototype.
- Avoid importing large vanilla picture modules just to copy asset paths. Use them as read-only precedent unless ESIR intentionally wants the same vanilla graphics table shape.

## Sidecar Roles

Use read-only sidecars when useful:

- `vanilla-prototype-lib explorer`: map installed Base, Space Age, Quality, or Elevated Rails prototype helper modules and nearby ESIR usage.
- `space-age-planet explorer`: inspect Space Age asteroid spawn, route, planet map-gen, procession, and cargo-pod helper modules.
- `vanilla-graphics-precedent explorer`: summarize vanilla picture modules and sprite table shapes without copying art or large source blocks.
- `quality-recycling explorer`: verify `__quality__/prototypes/recycling` behavior and ESIR recycling regeneration precedents.

Keep the main agent responsible for edits, validation, and final synthesis.
