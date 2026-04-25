---
name: factorio-lua-assumptions
description: "Use before applying generic Lua advice to Factorio mod code. Checks Factorio's Lua 5.2.1 sandbox, staged startup/runtime lifecycle, storage rules, require behavior, deterministic library changes, LuaObject validity, data.raw versus prototypes, and ESIR-specific helper/scheduler expectations."
---

# Factorio Lua Assumptions

Use this skill when a Lua coding decision might be influenced by habits from normal Lua, LuaJIT, Lua 5.1, or Lua 5.4. It is a guardrail, not a tutorial or linter.

## Workflow

1. Classify the code context first:
   - settings stage
   - prototype/data stage
   - runtime/control stage
   - migration
   - console command
   - remote interface
2. Check Factorio-specific Lua behavior before applying normal Lua advice.
3. Use `factorio-lua-docs` for exact API/source verification.
4. For ESIR edits, then apply the repo rules:
   - inspect `exotic-space-industries-remembrance/lib/lib.lua` and prefer `ei_lib`
   - use `exotic-space-industries-remembrance/lib/runtime-scheduler.lua` for shared runtime queue/tick plumbing
   - prefer `event.tick` over `game.tick` inside event callbacks
   - keep `control.lua` as the only top-level dispatcher

## Default Stance

- Do not assume standard Lua libraries exist.
- Do not assume top-level module state persists through save/load.
- Do not move values between startup/data and runtime by plain Lua variables.
- Do not treat `data.raw` as runtime state.
- Do not store functions in `storage`.
- Do not dereference cached `LuaObject` values without checking validity.
- Do not call `require()` from event handlers, console commands, or `remote.call()`.

## Read Next

- Core checklist: [references/assumption-checklist.md](./references/assumption-checklist.md)
- Exact official symbol lookup: use `factorio-lua-docs`
- ESIR helper preference: use `esir-lib-first`
- ESIR operator surface: use `esir-dev`

## Sidecar Roles

Use read-only sidecars when a broad Lua assumption needs independent checking:

- `stage-boundary explorer`
- `sandbox-delta explorer`
- `storage-lifecycle explorer`
- `event-determinism explorer`

Keep the main agent responsible for edits and final synthesis.
