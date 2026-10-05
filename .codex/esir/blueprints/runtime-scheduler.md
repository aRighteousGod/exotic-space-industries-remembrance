<a id="contract"></a>
# Shared runtime scheduler

## Implementation sources

- [runtime-scheduler.lua](../../../exotic-space-industries-remembrance/lib/runtime-scheduler.lua)

## Behavior and ownership

`queue_peek_last` reads the final non-nil stored FIFO value without removing it or
touching uniqueness membership. Domain/membership liveness belongs to the caller.
Sparse canceled tails may require a backward walk; owners
such as the lance cache their tail on admission and use this helper for migration
or lifecycle repair, not every shot.

`scheduler` provides queue operations, delayed buckets, counters, status snapshots, and optional telemetry. It registers no events and owns no gameplay cadence. Feature queues and bucket tables belong to their callers; only status/counter/telemetry records live beneath `storage.ei.runtime_scheduler`.

```mermaid
flowchart LR
  F[Feature lifecycle event] --> Q[Caller-owned queue or delayed buckets]
  C[control.lua service callback] --> D[Feature work guard and budget]
  D --> Q
  Q --> V[Feature validates payload and applies behavior]
  V --> R[Shared counters and status]
  R --> T[Explicit or enabled telemetry]
```

## Queue and due-work invariants

`ensure_queue` normalizes `items`, `head`, `tail`, and `queued`. `queue_length` is the index span; `queue_item_count` counts non-nil entries, so neither should silently replace the other in a budget calculation. `audit_queue` reports both, plus holes and unique membership.

`queue_push_unique` uses an explicit membership key, which may differ from the payload. `queue_pop(queue, unique_key)` can clear that explicit key. `queue_pop_queued` treats `queued[value]` as the live set, while `queue_pop_matching` consumes stale candidates until its predicate accepts one. Preserve the owner's membership representation when choosing a helper. Compaction retains remaining item order and does not redefine domain liveness.

`delayed_take_due` consumes only the exact tick bucket. `delayed_take_due_through` consumes all nonempty buckets through the supplied tick, sorted by due tick and then insertion order. A caller that can skip ticks needs the latter or an equivalent explicit catch-up policy. `delayed_next_due_tick` returns the earliest nonempty bucket or `false` for known emptiness; do not confuse that sentinel with an uninitialized cache.

<a id="tick-flow"></a>
## Tick flow

Queue and bucket operations use caller-supplied values and ticks. Pass the callback tick through observation APIs too: `bump_counter`, `set_module_status`, `status_snapshot`, `write_telemetry`, and `log_snapshot` accept an optional trailing numeric tick. Supplied zero is valid and bypasses clock access. Omission preserves the legacy `game.tick` or zero fallback. `log_snapshot` resolves one tick for both nested snapshot and telemetry; existing unticked callers remain compatibility debt, not a precedent for new event callers. No state schema or migration changes.

<a id="lifecycle"></a>
## Lifecycle and failure boundaries

`ensure_root` creates the scheduler root and schema version, module records, and telemetry configuration; telemetry defaults to disabled. Even a status getter may initialize state, so these APIs are not safe substitutes for read-only `on_load` rebinding. `status_snapshot` references the current module/counter/telemetry tables; it is not a deep immutable snapshot.

Queues are payload-agnostic. They do not validate LuaEntity handles, remove helper entities, enforce a feature's fairness policy, or bound total backlog. Those obligations remain with the caller. `clear_queue` resets queue state; feature teardown must separately release domain objects and registrations.

`write_telemetry` ordinarily requires the enable flag; explicit forced snapshots may bypass it. Disabled writes return before clock lookup, encoding and I/O but still normalize the scheduler root. `telemetry_enabled()` is also initializing, not a pure state peek. `log_snapshot` is an intentional diagnostic operation. Do not add a periodic writer merely because the helper exists.

<a id="verification"></a>
## Verification and limits

The [scheduler guidance](../../skills/esir-dev/references/runtime-scheduler-guidelines.md) defines reuse policy; keep it synchronized with interface changes. The [control queue lifecycle fixture](../../../scripts/qc/control-ups/queue-save.lua) and [lifecycle checker](../../../scripts/qc/control-ups/check-lifecycle.py) supply regression entrypoints.

Verify sparse queues, unique-key cleanup, stale membership rejection, stable compaction order, exact versus overdue buckets, empty due minima, save/load continuation, and disabled telemetry. The [runtime contract fixture](../../../scripts/qc/runtime-contracts/README.md) additionally checks explicit and legacy timestamps, consistent nested logging, return identity and disabled encoding/I/O in the installed engine. Timestamp acceptance does not establish queue/save parity or a UPS gain.
