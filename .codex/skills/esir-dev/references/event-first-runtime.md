# Event-First Runtime Design

Use this reference when a runtime system might be able to avoid steady-state UPS cost by reacting only to real state transitions.

## Core rule

Prefer pure event wiring when a module can fully respond to discrete lifecycle changes. Use scheduler work only for fairness rotation, backlog draining, live-set scans, or eventual-consistency repair that events alone cannot cover.

## First-pass checklist

- List the actual transitions that matter before you write runtime code: build, revive, mine, destroy, script destroy, deconstruct, cancel deconstruct, GUI open or close, teleport, rotate, configuration change, and `on_object_destroyed`.
- If those hooks cover the behavior, stay event-driven and do not add a polling loop.
- If you need a one-shot wakeup from an internal or sacrificial object, consider `script.register_on_object_destroyed` plus `defines.events.on_object_destroyed` before reaching for `on_tick`.
- Keep one storage record per visible entity, keyed by `unit_number`. Treat helper entities or proxy graphs as derived state.
- Make build and teardown symmetrical. Cleanup should tolerate missing or already-invalid helpers.
- Gate the runtime on real relevance: actual prototype presence, actual tracked entities, or actual pending work.
- Keep migration repair, stale-helper cleanup, and broad surface scans out of steady-state service.
- If you still need bounded background work, write down why. "It feels safer" is not enough.

## Nonstandard Beacons pattern

The best local reference for this pattern is the current dependency copy of `zzz-nonstandard-beacons` under `output/tesla-run-mods` or the Factorio mods directory. Treat that dependency copy as an external pattern reference, not as ESIR source of truth.

What to copy from it:

- Steady-state work is event-driven. The mod wires build, destroy, deconstruction, teleport, rotate, and `on_object_destroyed` handlers instead of polling.
- It keeps one storage entry per beacon and derives helper entities from that record.
- It uses hidden helper entities only because the engine behavior really needs them.
- It gates registration on actual prototype data and returns early when there is nothing relevant to watch.
- Heavy repair logic lives in configuration-change, command, or migration paths instead of normal runtime service.

What not to cargo-cult:

- Do not copy the helper-entity graph unless the engine actually needs a proxy/source/manager split.
- Do not normalize heavy world scans into normal runtime just because the migration path contains them.
- Do not treat old cached dependency copies as canonical implementation authority.

## ESIR examples

### Event-first or event-first hybrid

- [`exotic-space-industries-remembrance/scripts/control/beacon-overload.lua`](../../../../exotic-space-industries-remembrance/scripts/control/beacon-overload.lua): good "event-first with bounded audit backstop" example. Build, destroy, and config changes drive the main work; the periodic service path is intentionally small.
- [`exotic-space-industries-remembrance/scripts/control/matter-stabilizer.lua`](../../../../exotic-space-industries-remembrance/scripts/control/matter-stabilizer.lua): good hybrid example. Entity and GUI events do most of the work, with delayed GUI refresh buckets only where batching is genuinely useful.

### Scheduler-needed examples

- [`exotic-space-industries-remembrance/scripts/control/fluid-safety.lua`](../../../../exotic-space-industries-remembrance/scripts/control/fluid-safety.lua): keep bounded scheduler service when the runtime must fairly walk live sets and cannot rely on discrete events alone.
- [`exotic-space-industries-remembrance/scripts/control/orbital-combinator.lua`](../../../../exotic-space-industries-remembrance/scripts/control/orbital-combinator.lua): keep scheduler-driven work when the module owns ongoing reconciliation, bank audits, and fairness across active work classes.

### Legacy caution

- [`exotic-space-industries-remembrance/scripts/control/register-util.lua`](../../../../exotic-space-industries-remembrance/scripts/control/register-util.lua): useful for genuinely generic paired-entity bookkeeping, fluid registration, or specialized helper ownership.
- [`exotic-space-industries-remembrance/control.lua`](../../../../exotic-space-industries-remembrance/control.lua): the commented copper and iron beacon registration path is historical reference only. Do not revive that pattern for new beacon-like systems without first proving an event-first design cannot express the behavior better.

## Questions to answer before adding scheduler work

- Which exact invariant cannot be maintained from lifecycle events alone?
- Is the scheduler maintaining fairness, draining backlog, or repairing drift, rather than just compensating for missing event handling?
- Can the expensive part move to `on_configuration_changed`, an admin command, or an explicit refresh flow?
- Would a one-shot delayed bucket or `on_object_destroyed` callback cover the need without a permanent loop?
- If helper entities are involved, are they derived state with explicit cleanup, or are they becoming an unbounded second runtime to babysit?

## Agent hint

When the runtime shape is unclear, spawn an `event-lifecycle explorer` to compare the target module against the event-first and scheduler-needed examples above and summarize which path actually fits.
