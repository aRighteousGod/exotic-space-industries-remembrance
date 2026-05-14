# Agent Options

Use these prompts for read-only sidecars and forward-testing. Sidecars should report files inspected, commands run, conclusions, and confirmation that they made no writes.

## Research Receiver Audit

```text
Use $esir-research-events at .codex/skills/esir-research-events. Read only. Audit <module path or feature name> for ESIR research-event handling. Identify normal `on_research_finished` behavior, whether it updates force-derived state, whether it needs `on_scripted_research_burst`, and any file-map or dispatcher updates required. Return a concise checklist, not a patch.
```

## Scripted Burst Compatibility Review

```text
Use $esir-research-events at .codex/skills/esir-research-events. Read only. Review <module path> for compatibility with scripted `event.by_script` research floods. Check for per-technology assumptions, cache/buff/status refreshes, force validity guards, and opportunities to use force-wide rebuilds in `on_scripted_research_burst`. Return risks first, then suggested handler shape.
```

## Control Dispatch Mapping

```text
Use $esir-research-events at .codex/skills/esir-research-events. Read only. Map the current research dispatch path in `exotic-space-industries-remembrance/control.lua` and list all module receivers for `on_research_finished` and `on_scripted_research_burst`. Note any normal receiver without a burst decision and any burst receiver missing from file-map comments.
```

## QC Helper Planning

```text
Use $esir-research-events and $esir-dev. Read only. Plan a scripted research burst QC run for <change summary>. Identify whether the `zzz-scripted-research-qc` helper is relevant, which snapshot fields should be inspected, and which normal research scenarios still need separate coverage. Do not stage helper mods or run Factorio.
```

## Forward-Test Scenarios

- New receiver scenario: "Use `$esir-research-events` to review a proposed runtime module that refreshes force-wide damage bonuses on research completion. Do not edit files."
- Notification scenario: "Use `$esir-research-events` to decide whether an Informatron-style notification handler needs a scripted burst hook. Do not edit files."
- Cache scenario: "Use `$esir-research-events` to audit a cache updated by `event.research.name` and recommend a burst-safe refresh path. Do not edit files."
- Dispatcher scenario: "Use `$esir-research-events` to map `control.lua` research fan-out and find modules that need file-map or burst-hook updates. Do not edit files."
