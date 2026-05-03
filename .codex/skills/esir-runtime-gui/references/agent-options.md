# Agent Options

Use these prompts for read-only sidecars and forward-testing. Sidecars should report files inspected, commands run, conclusions, and confirmation that they made no writes.

## GUI Surface Explorer

```text
Use $esir-runtime-gui at .codex/skills/esir-runtime-gui. Read only. For a new ESIR entity console attached to <entity/prototype family>, choose the correct GUI surface, relative anchor, dispatcher events, tag schema, and close/update lifecycle. Compare against the existing canonical modules and explain any screen fallback only if needed.
```

## Legacy GUI Audit Explorer

```text
Use $esir-runtime-gui at .codex/skills/esir-runtime-gui. Read only. Audit <module path> for ESIR runtime GUI standardization. Identify its surfaces, root names, relative anchors, parent_gui/action tags, event handlers, stale-root cleanup, entity revalidation, and layout style drift. Return a migration checklist, not a patch.
```

## Pattern Reference Explorer

```text
Use $esir-runtime-gui at .codex/skills/esir-runtime-gui. Read only. Compare <module path> against the best canonical examples for its GUI surface. Recommend which existing ESIR module should be copied conceptually and which parts should not be copied.
```

## Forward-Test Scenarios

- New panel scenario: "Use `$esir-runtime-gui` to design a relative GUI for a new assembling-machine-style reactor console with status bars, two mode buttons, and an informatron action. Do not edit files."
- Legacy migration scenario: "Use `$esir-runtime-gui` to audit `exotic-space-industries-remembrance/scripts/control/railgun-cooling.lua` and produce a standardization checklist. Do not edit files."
- Hybrid exception scenario: "Use `$esir-runtime-gui` to explain when `player.gui.screen` is still appropriate for an ESIR entity-related GUI. Compare `induction-matrix.lua`, `orbital-logistics.lua`, and `crystal-accumulator.lua`. Do not edit files."
