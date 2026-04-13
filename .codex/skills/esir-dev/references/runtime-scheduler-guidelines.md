# Runtime Scheduler Guidelines

Use this when editing queued runtime modules under `exotic-space-industries-remembrance/scripts/control/`.

## First Principles

- `control.lua` remains the single top-level dispatcher.
- `lib/runtime-scheduler.lua` is the shared helper spine for queue math, delayed buckets, counters, status snapshots, and gated telemetry.
- Feature modules own their local state and semantics, but should not duplicate generic scheduler plumbing that the shared library already provides.
- A scheduler migration is not complete if shared helper semantics changed but the skill/reference guidance still describes the old behavior.

## Tick Source

- In event handlers, prefer `event.tick`.
- In `on_tick`, use the incoming tick from the callback instead of reading `game.tick` again.
- Use `game.tick` only in contexts that do not have an event object, such as status helpers, load-time repair helpers, or utility functions called outside an event callback.
- If you feel tempted to add `get_event_tick()` or another "current tick" helper in a feature module, stop and justify why `event.tick` or the shared scheduler state is not enough.

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
