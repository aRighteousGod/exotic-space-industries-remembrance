<a id="contract"></a>
# Fulgora day-length variation

<a id="admin-repair"></a>
## Admin repair

`repair_runtime_state` refreshes configured multiplier bounds and missing schedule defaults without drawing a random value or changing the current native day length. Cycle identity and already-applied-cycle state survive.

## Implementation sources

- [fulgora-day-length-variation.lua](../../../exotic-space-industries-remembrance/scripts/control/fulgora-day-length-variation.lua)

## Ownership and reference flow

The module changes the native Fulgora surface's `ticks_per_day`. Its actual state is `storage.ei.fulgora_day_length_variation`: multiplier bounds, cycle index, last daytime/darkness, last applied cycle, and next/pending checks. The older file-header reference to a top-level storage field is not the implementation owner.

```mermaid
flowchart LR
  A["Observe daytime wrap"] --> B["New cycle permits one change"]
  B --> C["Due brightness/stability check"]
  C --> D["Safe window or overdue fallback"]
  D --> E["Draw bounded multiplier and set day length"]
  C --> F["Pending retry"]
  F --> C
```

<a id="tick-flow"></a>
## Tick flow and invariants

The global tick path is gated by Fulgora's existence and native `freeze_daytime`; frozen daylight admits no variation work. The updater uses `event.tick` throughout: ordinary checks include a small cadence jitter, pending checks retry every 60 ticks, and a full-standard-day timeout permits progress when brightness guards keep rejecting. A cycle changes at most once. Preserve daytime-wrap observation even when an expensive check is not due.

<a id="lifecycle"></a>
## Lifecycle and cleanup

The module returns when the surface or `storage.ei` is absent and lazily initializes variation state from configured bounds. `on_admin_daytime_changed(surface, tick)` resynchronizes daytime and darkness after explicit daytime/freeze edits, preserves configured bounds and cycle identity, clears old pending timeouts, and waits for the next natural wrap. An admin rewind is not a new cycle. Surface replacement/reconfiguration must still be reviewed against retained cycle fields; the hook is not a reset. It owns no entity helpers or render objects.

<a id="verification"></a>
## Verification contract

Test absent Fulgora, first initialization, daytime wrap, bright/stable and dark/unstable windows, pending timeout, once-per-cycle behavior, bounds, and reload. Also test frozen daylight, manual rewind, unfreeze after a pending timeout, and the next natural wrap. Inspect continuity visually as well as `ticks_per_day`; a structural model does not establish that every transition is visually smooth.
