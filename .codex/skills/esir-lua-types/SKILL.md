---
name: esir-lua-types
description: "Use when editing or auditing ESIR Lua annotations for LuaLS/EmmyLua editor fidelity, including Factorio runtime events, data-stage prototype types, module export tables, storage/state shapes, option tables, scheduler payloads, GUI handlers, and whole-module or whole-codebase typing sweeps."
---

# ESIR Lua Types

Use this skill when ESIR Lua work should leave the editor with sharper completion, hover text, and diagnostics. The default is touched-code coverage: annotate the functions, tables, event payloads, options, and module exports involved in the patch without forcing unrelated churn.

## Workflow

1. Classify the Lua context before annotating:
   - runtime/control module
   - prototype/data stage file
   - migration
   - shared helper library
   - QC/support Lua
2. Add high-value LuaLS annotations around touched code:
   - `---@param` for non-obvious function inputs and Factorio event payloads
   - `---@return` when callers benefit from completion or nil-awareness
   - `---@type` for important locals, module exports, prototype tables, and data lists
   - `---@class`, `---@field`, and `---@alias` for reused state, option, payload, tag, and record shapes
3. Prefer authoritative Factorio and ESIR types:
   - runtime API examples: `LuaEntity`, `LuaPlayer`, `LuaSurface`, `LuaGuiElement`
   - event payload examples: `EventData.on_gui_click`, `EventData.on_built_entity`
   - data stage examples: `data.AssemblingMachinePrototype`, `data.RecipePrototype`, `data.TechnologyPrototype`
4. Keep annotations useful:
   - annotate boundaries, persistent state, callbacks, exported helpers, and tables with mixed fields
   - define option table classes near the function that consumes them or near the module constants they configure
   - skip obvious one-line primitives unless the type resolves ambiguity
   - do not invent false certainty for uncertain LuaObject validity or optional fields
5. Verify with the most relevant non-mutating check available, usually:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task preflight
```

## Coverage Modes

- **Touched-code mode**: default. Improve only the symbols touched by the requested change.
- **Whole-module mode**: use when the user asks for a module typing pass. Annotate major local helpers, exports, state shapes, event handlers, and prototype records in that file.
- **Whole-codebase audit mode**: use when the user asks for broad typing cleanup. Produce an inventory and staged plan before editing many files.

## Working Rules

- Match existing Factorio LuaLS style: `---@param name Type description`, `---@return Type|nil`, and narrow `---@class` records placed near the data they describe.
- For runtime modules, annotate persistent `storage` shapes, module-owned state tables, and exported handler signatures before adding scattered local annotations.
- For GUI handlers, type the event payload and any `tags` table shape used for routing.
- For scheduler queues or delayed buckets, type the payload record and document whether it carries unit numbers, positions, ticks, or LuaObjects.
- For data-stage files, annotate prototype tables and `data:extend` arrays using `data.*` prototype names when known.
- For option tables, prefer named classes such as `AuricVatOpenOptions` over anonymous `table` params once a table has two or more meaningful fields.
- For module tables, annotate the export surface once with a `---@class` and `---@type`; avoid repeating obvious field types at every assignment.
- Keep LuaObject validity separate from type shape. `---@type LuaEntity` says what the value is meant to be; it does not prove `.valid` is true.
- If a Factorio API type is uncertain, use `factorio-lua-docs` before guessing.
- If a Lua decision depends on Factorio sandbox or lifecycle behavior, use `factorio-lua-assumptions`.
- If helper signatures change in `ei_lib` or `runtime-scheduler.lua`, update relevant annotations and any matching ESIR skill guidance in the same patch.

## Stop Conditions

Stop annotating when the next annotation would only restate Lua syntax. A good pass should improve editor behavior at module boundaries and mixed-shape tables, not bury the code under commentary.

## Read Next

- [references/annotation-patterns.md](./references/annotation-patterns.md): ESIR annotation examples for runtime, GUI, queues, prototypes, and LuaObject validity.
- [references/agent-options.md](./references/agent-options.md): read-only sidecar prompts for typing audits and review.
