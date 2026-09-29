<a id="contract"></a>
# Black hole containment and extraction

## Implementation sources

- [black-hole.lua](../../../exotic-space-industries-remembrance/scripts/control/black-hole.lua)

## Ownership and reference flow

`storage.ei.black_hole[unit]` is the canonical record for mass, stage/progress, generated energy, cached injector/extractor references, timestamps, and presentation. Native inventories feed mass; nearby injector energy supports containment and extractor entities receive output.

```mermaid
flowchart LR
  A["Inventory and cached pylons"] --> B["Mass and available containment"]
  B --> C["Per-tick radiation/output calculation"]
  C --> D["Containment and stage progression"]
  D --> E["Extractor output, visuals, victory hook"]
```

<a id="tick-flow"></a>
## Tick flow and invariants

The gated every-tick `update(event)` services registered holes and separately cadences open GUI refresh. The simulation uses the supplied tick for cache/energy snapshots; context-free rebuild can read `game.tick`. Dormant stage-zero records use a cheaper path, but active simulation retains its original per-tick economics. Preserve pylon cache invalidation and periodic self-repair instead of adding a fresh neighborhood search per tick.

<a id="lifecycle"></a>
## Lifecycle and cleanup

Build/destruction of pylons dirties nearby hole caches. Hole registration initializes a complete record; rebuild reconciles it against the world. Removal cleans animation/helpers and any supported inventory transfer. Cached references are validated during use. Falling below required containment resets stage/progress and warns the player; GUI stage advancement must use the same canonical record.

<a id="verification"></a>
## Verification contract

Historical GUI/lifecycle parity appears in the [control follow-up record](../../../scripts/qc/control-ups/followup-verification.md). Exercise empty/dormant holes, mass insertion, pylon build/removal, insufficient energy, stage advancement, reload, and removal with a console open. Verify resource accounting and containment outcomes separately from visual appearance.
