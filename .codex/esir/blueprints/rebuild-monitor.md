<a id="contract"></a>
# Rebuild activity monitor

## Implementation sources

- [rebuild-monitor.lua](../../../exotic-space-industries-remembrance/scripts/control/rebuild-monitor.lua)

## Ownership and presentation

The scheduler owns reports; `storage.ei.rebuild_monitor` owns GUI handles, dragged positions and per-player dismissal. Owners retain all gameplay queues, cursors, retries and budgets. Public rows expose module, phase, counts and game-time ETA. Admin Diagnostics additionally exposes trigger and scope. The native screen frame never assigns `player.opened` or focus.

The top-left `mod_gui` button exists during queued/running asynchronous work. After 120 ticks, the small draggable window opens per player. Closing dismisses automatic opening for the current episode, including jobs joining later; manual reopening remains available. Waiting-only or completed work removes public UI; resumption starts a new episode. Position survives closing and loading and is clamped after resolution/scale changes.

## Cadence and persistence

`control.lua` is the sole dispatcher. The idle admission predicate is constant-time and pure. Active refresh shares one snapshot, serves at most eight viewers per tick, and updates each viewer's captions no more than once per 60 ticks. Auto-open decisions use a per-viewer episode marker so a larger viewer set drains across ticks. Only visible authorized Diagnostics viewers receive activity-only refresh. Idle work schedules no refresh and performs no player enumeration, owner calls or world queries.

No storage/GUI mutation occurs during `on_load`. Progress IDs, dismissal, queues and native GUI locations persist. Configuration and player events reconcile presentation. Owners adopt already-running work at their existing batch boundaries, using unknown totals when required.

## Verification

`scripts/qc/terrain-evolution/v2-reports.lua` covers report lifecycle and bounded publication. The connected ecology fixture covers native GUI integration; persistence fixtures verify saved report IDs. The shared monitor is observation-only and adds no gameplay scheduling. Outputs belong to ignored managed staging.
