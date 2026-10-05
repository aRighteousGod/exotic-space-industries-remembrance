# Runtime Development Standards

Use this common contract before ESIR runtime design, optimization, or module API
work. Specialist scheduler, GUI, research, Factorio API, and blueprint guidance
refine it. Current source and engine results remain authoritative.

## Reduce admitted work first

Prefer native engine behavior and exact lifecycle events. Then use cheap
relevance checks, maintained counts/deadlines, bounded service, and reuse within
one service pass. Profile before adding function aliases, call caches, or other
micro-optimizations. A shared helper call is not automatically cheaper.

- List lifecycle transitions and justify continuing service. Keep broad
  discovery, repair, and migration scans outside steady-state service.
- Keep `control.lua` as the sole event/cadence dispatcher. Preserve exclusive
  script-effect ownership, engine event filters, and shared receiver order.
- New work predicates inspect existing state without `ensure_*`, rebuilding,
  discovery scans, sorting, snapshots, or per-call table allocation. Prefer
  maintained counts/deadlines when their lifecycle can be maintained correctly.
  Document insertion, removal, draining, rebuilding and migration cache rules.
- Choose an external predicate or an inline cheap idle path; do not mandate
  both. Water turret's inline queue/deadline guard is intentional. Camera and
  lance due minima illustrate inexpensive admission, not permission to skip
  paid gameplay deadlines.
- Predicates, backlog queries and service results differ. Matter's workload
  query admits missing/obsolete state for repair. Existing getters are not
  uniformly pure or constant-time; record exceptions to the new default.
- Preserve service ticks, callback order, FIFO/membership, fairness, budget
  meaning, deadlines and cleanup. Cadence, latency, budget or gameplay changes
  require a separate design decision. Keep the sixteen-slot dispatcher and
  mandatory tier unless that decision changes them.
- Define budget units and exceptions. Lance's legacy limit does not cap due
  paid packets; mechanical delivery precedes presentation limits. A limit
  parameter is not automatically a universal hard cap.

## Module invocation contract

New modules return a table and import dependencies locally at file load.
Preserve legacy globals used by other modules. Never move `require` into runtime
callbacks. Mixed-stage libraries do not make every export valid in every stage.

Ordinary ESIR exports/callers use dot syntax. Colon syntax is for deliberate
self-based interfaces such as `handle-wheels`; explicit `self` parameters are
meaningful too. Factorio LuaObject and `data:extend` calls follow their own API
contracts. Do not blanket-convert engine calls or intentional methods.

Call required module exports directly so interface drift fails visibly. Capability
checks belong to optional integrations, external remote interfaces, or
heterogeneous diagnostics. Preserve feature enablement, prototype presence,
input validity and actual work checks. Do not substitute silent `pcall` gameplay
dispatch. Defensive shared LuaObject adapters and diagnostic protected calls
retain their purposes.

| Family | Default for new boundaries | Existing contracts to preserve |
| --- | --- | --- |
| Native event receiver | `on_<event>(event)` with the original event | Do not manufacture events or discard metadata |
| Entity adapter | Explicit entity plus needed tick/context | Some `on_*` helpers receive normalized entities; names alone do not prove event input |
| Ordinary tick service | `updater(event)` | Existing `update(event)` and domain names need no cosmetic rename |
| Budgeted service | Budget first, then event/context | Define units, fairness, returns and mandatory deadline work |
| Clock-only helper | Numeric `current_tick` | Keep event adapters at the caller; avoid universal adapter allocations |
| Work predicate | Event for event services, numeric tick for clock-only services | No-argument population gates and inline idle guards remain valid |
| Lifecycle/rebuild | Explicit reason and available boundary context | Configuration changes have no tick; `on_load` cannot perform world work |
| Research burst | Force refresh plus consumed hints/tick | Preserve flush ordering and existing force/boolean/tick forms |
| Status/diagnostic | Document inputs, freshness and mutation | Getters may initialize state; snapshots may reference mutable records |

Type touched exports, payloads, options and returns with `esir-lua-types`. Keep
booleans, counts, tuples, nil and false sentinels distinct. Established exclusive
callback maps remain valid; avoid adapter closures solely for visual uniformity.

## Helper, tick, and safety boundaries

Inspect `ei_lib` for utility and `runtime-scheduler` for queue/delayed/status
plumbing. Reuse or extend compatibly only when mutation, allocation, stage,
ordering and return semantics fit. Dense sets, fairness cursors and deliberately
non-initializing probes may remain local. Avoid divergent new clones and record
intentional local behavior/debt.

Follow the [tick-source contract](runtime-scheduler-guidelines.md#tick-source).
Pass supplied ticks through timed and observational helpers. Scheduler counters,
status, snapshots, telemetry and logging accept an optional trailing numeric
tick. Zero is valid; omission preserves legacy game-available fallback.
`log_snapshot` resolves one timestamp for its snapshot and telemetry. New event
callers should supply their tick rather than rely on that compatibility path.

Scheduler `telemetry_enabled()` still calls `ensure_root()`: it gates expensive
collection/I/O but is not a pure peek. Status getters may initialize records.
Telemetry remains default-off; explicit forced diagnostics retain their override.
Do not construct payloads or full snapshots before the enable guard.

Validate entities across storage, delays, dequeue and destructive/reentrant
callbacks. Identity is not validity. Reuse a validated handle within an
uninterrupted scope; avoid redundant defensive layers on every field read.
GUI opens may require dispatch to clear an old session when a different entity
opens. Clone hooks may destroy/replace destinations; revalidate after them.

## Evidence and advisory audit

Distinguish source inspection, reduced work/call counts, measured attribution,
behavior parity and uninstrumented whole-engine timing. Do not sum nested timers
or label fewer calls a demonstrated UPS gain. Freeze current source, including
pending work, before differential checks.

```powershell
python -B .codex/skills/esir-dev/scripts/runtime_contract_audit.py --repo-root . --format markdown
```

The read-only structural audit inventories exports/signatures, literal imports,
calls, clock reads and unresolved aliases. It reports parallel registrations,
proven call-form mismatches, required-export probes and duplicate exports. It
cannot prove event coverage, purity, entity safety, budgets or performance.
Narrow path/rule/symbol exceptions with reasons and expected shapes live in
`.codex/esir/runtime-contract-exceptions.json`; stale entries are reported.
Preflight exposes `advisory_checks` separately: findings and audit unavailability
never change pass/fail, including `-Strict`. Existing blockers stay unchanged.
Standalone execution errors exit 2; findings exit 0. Default output is stdout;
saved reports belong in ignored staging.

Use [owner models](../../../esir/blueprints/index.md), focused engine fixtures,
and [control UPS verification](../../../../scripts/qc/control-ups/README.md) for
behavior/order/reload acceptance. Structural advice is not runtime evidence.
The [runtime contract fixtures](../../../../scripts/qc/runtime-contracts/README.md)
cover scheduler timestamps, required-export dispatch, research and GUI parity,
and ordinary/Strict advisory isolation.
