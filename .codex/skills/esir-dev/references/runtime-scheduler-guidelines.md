# Runtime Scheduler Guidelines

Use this when editing queued runtime modules under `exotic-space-industries-remembrance/scripts/control/`.

## First Principles

- `control.lua` remains the single top-level dispatcher.
- `lib/runtime-scheduler.lua` is the shared helper spine for queue math, delayed buckets, counters, status snapshots, and gated telemetry.
- Feature modules own their local state and semantics, but should not duplicate generic scheduler plumbing that the shared library already provides.
- A scheduler migration is not complete if shared helper semantics changed but the skill/reference guidance still describes the old behavior.
- Before changing a scheduling/state contract, use [esir-conceptual-blueprints](../../esir-conceptual-blueprints/SKILL.md) and update the owning model with its source commentary in the same patch.

## Tick Source

- When a callback supplies `event.tick`, including `on_tick` and `on_nth_tick`, pass that numeric tick through every timing-dependent helper, GUI/status update, and scheduled-work call. A helper without an event parameter still has event context when its caller can supply the tick; do not reread `game.tick` in that chain.
- Resolve `game.tick` once at a runtime entry boundary that supplies no tick and where `game` is available, such as initialization, configuration changes, migrations, commands, or remote calls. Prefer an explicitly supplied numeric tick even at these entry points, and pass the resolved value onward.
- `ConfigurationChangedData` does not supply a tick. Top-level loading and `on_load` cannot read `game.tick`; defer world work to an appropriate lifecycle/event boundary. These contracts were checked against the installed Factorio 2.0.77 API documentation.
- Preserve tick zero as a valid supplied timestamp. `ei_lib.get_event_tick` is an input normalizer: it returns the supplied number, a table's `tick`, or zero, and never reads `game.tick`. It cannot distinguish absent input from a supplied zero. Do not use its zero result as evidence of a real current tick or as a missing-value test for a fallback.
- For delayed work, distinguish the original event tick, due tick, and current execution tick. Service normally propagates its callback tick; retain origin timestamps only where feature semantics require them.
- Preserve existing explicit-tick/fallback interfaces and identify remaining deviations in the owner model. Do not create a new file-local current-time wrapper or change shared helper semantics as a side effect of documentation work.

## Runtime Entity Safety

- `lib/runtime-scheduler.lua` is payload-agnostic. Queue helpers, delayed buckets, counters, and telemetry helpers do not validate `LuaEntity` values for you.
- Use `ei_lib.entity_check(entity)` before reading entity fields or calling methods on a runtime handle.
- Use `ei_lib.get_valid_entity(entity)` when normalizing an uncertain runtime entity input into `entity-or-nil`.
- Use `ei_lib.get_entity_unit_number(entity)` only for a safe `.unit_number` read. Treat it as key extraction, not as proof of validity.
- For queued, delayed, stored, or cross-event entity references, validate at enqueue time if that helps local semantics, and validate again at dequeue time before dereferencing because the entity may have died while waiting.
- Raw `entity.unit_number` is still fine when validity and unit expectations are established immediately in the same scope, especially in tight event-local paths. Avoid it in generic helpers and long-lived runtime state bridges.

## Queue Primitives

Prefer these shared helpers before inventing local queue code:

- `ensure_queue`
- `compact_queue`
- `queue_peek`
- `queue_push`
- `queue_push_unique`
- `queue_pop`
- `queue_pop_matching`
- `queue_pop_queued`
- `queue_remove_value`
- `clear_queue`
- `queue_length`
- `queue_item_count`
- `audit_queue`

Local queue structs are still fine when a module has a very specific representation, but shared queue behavior should not be reimplemented casually.

If a module needs to force compaction after many removals, prefer `compact_queue` over rolling a private re-pack pass.

If a module keeps stale or unscheduled values in `queue.items` and relies on `queue.queued` as the live-set, do not replace its dequeue loop with plain `queue_pop`. Prefer `queue_pop_queued` or extend the shared scheduler with a compatible helper first.

If a module keeps queue liveness in module-owned state such as `entry.queued`, prefer `queue_pop_matching` before rebuilding another local dequeue loop.

Dense-set schedulers with swap-remove indexes, fairness cursors, or membership-position tables are not failed scheduler migrations. Keep those local unless the shared helper surface grows to express that shape cleanly.

If a migration intentionally stops short, record the file, reason, and next safe move in `.codex/esir/REVISIT_NOTES.md` so the partial state is discoverable later.

## Delayed Work

Prefer these delayed-bucket helpers before inventing local delayed tick tables:

- `ensure_delayed_buckets`
- `delayed_schedule`
- `delayed_take_due`
- `delayed_bucket_count`
- `delayed_item_count`

If a module still carries a legacy flat queue, migrate it into delayed buckets and keep the compatibility drain clearly temporary.

## Status And Telemetry

- Use `ensure_module_state` and `bump_counter` for module-level counters or QC bookkeeping.
- Use `set_module_status` for shared runtime status.
- Use `get_module_status`, `status_snapshot`, and `/ei_runtime_status` for shared debug surfaces.
- Do not add a new periodic telemetry heartbeat unless it is clearly worth the cost.
- If periodic telemetry exists, it must be truly gated behind `telemetry_enabled()` or an equivalent cheap guard.
- Use `write_telemetry` for structured emissions and keep `log_snapshot` for explicit debug/QC snapshots, not routine tick-time logging.

## Smells

These are strong signs that the edit should be rethought:

- repeating queue head/tail bookkeeping already covered by the shared helper
- duplicating delayed-tick bucket logic
- recomputing tick sources in multiple layers of the same call path
- adding a second top-level scheduler outside `control.lua`
- polling shared runtime status every N ticks without a hard gate

## Naming

- Name runtime modules for what they actually do now, not for the historical feature that happened to host the first version.
- Example: `fluid-safety.lua` is the fluid safety runtime; it is not a "powered beacon" module anymore.
