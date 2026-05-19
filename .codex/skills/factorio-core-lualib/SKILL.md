---
name: factorio-core-lualib
description: "Use when Codex needs to import, audit, replace, or choose Factorio's bundled `data/core/lualib` helpers in ESIR or other Factorio mod Lua, especially `require(\"__core__.lualib.meld\")`, `util`, `mod-gui`, `resource-autoplace`, `collision-mask-util`, `math2d`, `math3d`, `event_handler`, `sound-util`, `circuit-connector-sprites`, `story`, `silo-script`, `space-finish-script`, `production-score`, or `kill-score`. Use before reimplementing helper behavior that Factorio core already ships, before changing existing core lualib imports, and when deciding between core lualib helpers, ESIR `ei_lib`, direct prototype mutation, or local Lua helpers."
---

# Factorio Core Lualib

Use this skill to reuse Factorio's bundled Lua helpers intentionally instead of rediscovering them or cloning their behavior into ESIR.

For importable vanilla prototype modules under `data/base`, `data/space-age`, `data/quality`, or `data/elevated-rails`, use [`factorio-vanilla-prototype-libs`](../factorio-vanilla-prototype-libs/SKILL.md) instead.

The current survey was taken from local Factorio 2.0.76:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task doctor
Get-ChildItem 'C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\core\lualib' -File
```

## Workflow

1. Classify the code stage first: data/prototype, runtime/control, scenario/tutorial, migration, or support tooling.
2. Check whether the needed helper is a native Factorio surface. Read [references/core-lualib-map.md](./references/core-lualib-map.md) for the surveyed module map.
3. If the task involves recursive prototype table patching, read [references/meld.md](./references/meld.md) before writing merge code.
4. In ESIR, prefer `ei_lib` for ESIR-owned shared helpers and policy. Prefer core lualib when matching Factorio-native prototype, GUI, autoplace, math, or scenario behavior.
5. Verify against the installed Factorio file when exact semantics matter. Do not vendor Factorio core lualib source into the repo.

## Require Forms

Factorio examples use all of these forms:

```lua
local meld = require("__core__.lualib.meld")
local resource_autoplace = require("__core__/lualib/resource-autoplace")
local util = require("util")
local math3d = require("math3d")
local mod_gui = require("mod-gui")
```

- Use explicit `__core__.lualib.<module>` or `__core__/lualib/<module>` when avoiding ambiguity or documenting that the dependency is Factorio core.
- Use short names such as `util`, `meld`, `math3d`, or `mod-gui` when matching nearby vanilla or existing ESIR style.
- Keep `require()` at module load time. Do not add dynamic `require()` calls inside runtime event handlers, remote interfaces, or console command bodies.

## Stage Guidance

- Data/prototype helpers are the safest core lualib imports for ESIR prototype work: `util`, `meld`, `resource-autoplace`, `autoplace_utils`, `collision-mask-util`, `circuit-connector-sprites`, `sound-util`, `math2d`, and `math3d`.
- Runtime/control helpers need ESIR routing. `mod-gui` is useful for persistent top buttons, but `esir-runtime-gui` still prefers `player.gui.relative` for entity panels. Avoid adopting `event_handler` as a parallel dispatcher; ESIR keeps `control.lua` as the top-level dispatcher.
- Scenario/tutorial helpers such as `story`, `silo-script`, `space-finish-script`, `crash-site`, `production-score`, and `kill-score` are primarily vanilla scenario infrastructure. Treat them as precedent unless the task is explicitly scenario-like.
- `collision-mask-util` is data-stage oriented; runtime collision checks use runtime API/prototype objects instead.

## ESIR Decision Rules

- Before adding local helper code that resembles core lualib, check this skill and `esir-lib-first`.
- Prefer `meld` when patching an existing prototype table in place and the source patch is easier to read as a partial table.
- Prefer `util.merge` when creating a new merged copy from two or more tables.
- Prefer direct assignment for one or two simple scalar/prototype fields.
- Prefer `ei_lib` when the behavior is ESIR policy, cross-module ESIR utility, recipe/technology mutation, tooltip/status wiring, scheduler/state plumbing, or entity safety.

## Sidecar Roles

Use read-only sidecars when useful:

- `lualib-surface explorer`: map installed Factorio `data/core/lualib` modules, Factorio version, and vanilla usage examples.
- `meld-pattern explorer`: choose between `meld`, `util.merge`, direct mutation, and `ei_lib`.
- `core-require explorer`: verify require forms and nearby vanilla/ESIR precedents.

Keep the main agent responsible for edits, validation, and final synthesis.
