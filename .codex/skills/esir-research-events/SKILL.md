---
name: esir-research-events
description: "Use when adding, refactoring, auditing, or testing ESIR runtime code that receives Factorio research completion events, handles on_research_finished or on_scripted_research_burst, reacts to scripted research floods, updates force-derived research caches, buffs, milestones, notifications, damage/status refreshes, or plans QC around the scripted research burst UPS saver."
---

# ESIR Research Events

## Native test integration

Run `qc-test -Suite research-events` for ordinary/scripted completion, coalescing, force isolation, flush ordering, derived state and persistence. Run `research-bootstrap` for progression and lab changes across all four registered startup profiles. Missing required diagnostic state fails. Use [native testing](../esir-dev/references/native-testing.md); the historical helper supplies world setup, and manual shared `fmqc/mods-live` staging is obsolete.

Follow [runtime development standards](../esir-dev/references/runtime-development-standards.md) for required calls and force/hint/tick contracts. Keep diagnostic capabilities distinct from required research fan-out.

Use this skill before changing research-aware runtime code. ESIR has a deliberate UPS saver for `event.by_script` research floods, so normal research handling and scripted burst handling must be designed together.

## Dispatch Model

1. Keep `exotic-space-industries-remembrance/control.lua` as the only top-level `script.on_event(defines.events.on_research_finished, ...)` registration.
2. For `event.by_script`, the dispatcher calls `queue_scripted_research_burst(e)` and returns. The queued state lives under `storage.ei.scripted_research_burst`, is coalesced per force, and is scheduled through the shared delayed-bucket helpers.
3. For normal research, the dispatcher first calls `flush_scripted_research_burst_for_force(research_force.index, e.tick)` if that force has a pending scripted burst, then fans out to module `on_research_finished(event)` handlers.
4. The on-tick backstop calls `flush_due_scripted_research_bursts(event.tick, state)` when the next due burst matures. Burst fan-out calls module `on_scripted_research_burst(...)` handlers.
5. Treat the current dispatcher names as canonical search anchors: `queue_scripted_research_burst`, `flush_scripted_research_burst_for_force`, `flush_due_scripted_research_bursts`, `on_research_finished`, and `on_scripted_research_burst`.

## Handler Rules

- Any module added to normal research fan-out must explicitly decide whether scripted research should reach it through `on_scripted_research_burst`.
- Add or update `on_scripted_research_burst` when research handling changes caches, notifications, milestones, buffs, damage/statuses, unlocked-tech scans, or any other force-derived state that could be stale after many scripted completions.
- Prefer force-wide refresh, rebuild, or scan behavior in burst handlers. Do not rely on a single `event.research.name`; a scripted flood may represent many completed technologies.
- Keep per-technology delta logic in `on_research_finished(event)` only when it is safe for normal one-tech completions. If scripted floods still need a narrow hint, follow the Tesla variant-sync precedent: store the smallest boolean or scalar needed on the burst entry and pass it through the existing burst dispatch.
- Validate `force`, `force.valid`, and `force.technologies` before scanning research state in burst handlers.
- Keep return values simple (`true` when useful work happened, `false` or nil otherwise). Do not make control.lua depend on broad return semantics unless the dispatcher truly needs them.

## Edit Checklist

- Search first:

```powershell
rg -n "on_research_finished|on_scripted_research_burst|by_script|scripted_research_burst" exotic-space-industries-remembrance/control.lua exotic-space-industries-remembrance/scripts/control
```

- If a module gets `on_research_finished`, update its file-map `forwarded_events` comment and decide on the burst hook in the same patch.
- Do not add parallel research dispatchers, ad hoc tick queues, `on_nth_tick` burst drains, or bypasses around `storage.ei.scripted_research_burst`.
- Use supplied `event.tick` and pass `current_tick` through burst work, status, and GUI consumers. Resolve a fallback only at a game-available boundary lacking a supplied tick; follow the [tick-source contract](../esir-dev/references/runtime-scheduler-guidelines.md#tick-source).
- Use [esir-conceptual-blueprints](../esir-conceptual-blueprints/SKILL.md) to keep research dispatch, derived-state ownership, and burst timing models synchronized with substantive changes.
- Use `esir-lua-types` when adding or changing research handler signatures, burst option payloads, or storage shapes.
- Use `factorio-lua-assumptions` before applying generic Lua event/storage advice to Factorio runtime code.

## QC Guidance

- Run the named `research-events` candidate/reload cases; the adapter owns helper staging and cleanup.
- Assert pending-force/due-bucket state, flush order, force isolation and derived Tesla/EM state. Missing required diagnostics fail.
- Immediate force flushes can leave cancelled bucket entries. Compare their saved counts on ordinary reload while requiring zero live pending forces and zero next-due tick.
- Run all four `research-bootstrap` settings profiles for progression changes, including native lab completion and exact saved progress/inventory reload.
- Preserve [the helper's historical world-setup provenance](../esir-dev/references/scripted-research-qc-helper.md); snapshot-only output is not functional acceptance.

## Read Next

- [references/agent-options.md](./references/agent-options.md): read-only sidecar prompts and forward-test scenarios.
- [`../esir-dev/references/scripted-research-qc-helper.md`](../esir-dev/references/scripted-research-qc-helper.md): staging and running the scripted research QC helper.
