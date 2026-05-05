# Agent Options

Use these prompts for read-only sidecars and forward-testing. Sidecars should report files inspected, commands run, conclusions, and confirmation that they made no writes.

## Touched-File Typing Review

```text
Use $esir-lua-types at .codex/skills/esir-lua-types. Read only. Review <module path> and identify the highest-value LuaLS annotations for the functions, option tables, state tables, event payloads, and exports touched by the current patch. Return a concise checklist, not a patch.
```

## Whole-Module Typing Audit

```text
Use $esir-lua-types at .codex/skills/esir-lua-types. Read only. Audit <module path> for a whole-module LuaLS annotation pass. Identify runtime/data-stage context, storage roots, option tables, major record shapes, exported module signatures, event handlers, queue payloads, and places where annotations would be noisy. Return a staged implementation checklist.
```

## Factorio API Type Lookup

```text
Use $esir-lua-types and $factorio-lua-docs. Read only. For <symbols or file path>, resolve the correct Factorio LuaLS type names for runtime events, LuaObjects, or data-stage prototypes. Return only confirmed type names and where each should be applied.
```

## Noisy-Annotation Reduction Review

```text
Use $esir-lua-types at .codex/skills/esir-lua-types. Read only. Review <module path> for annotations that are redundant, misleading, too broad, or likely to reduce editor signal. Return specific removals or rewrites with reasons.
```

## Option Shape Explorer

```text
Use $esir-lua-types at .codex/skills/esir-lua-types. Read only. Review <module path> for anonymous option/config tables that cross helper boundaries. Recommend named `---@class` shapes only where they improve completion or prevent wrong calls.
```

## Forward-Test Scenarios

- Runtime scenario: "Use `$esir-lua-types` to plan touched-code annotations for a runtime GUI click handler, option table, and storage-backed entity state. Do not edit files."
- Prototype scenario: "Use `$esir-lua-types` to annotate a data-stage assembling-machine prototype and generated recipe list. Do not edit files."
- Audit scenario: "Use `$esir-lua-types` to audit `exotic-space-industries-remembrance/scripts/control/auric-inoculation-vat.lua` for whole-module typing opportunities. Do not edit files."
