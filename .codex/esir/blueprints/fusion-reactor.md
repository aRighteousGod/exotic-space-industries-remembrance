<a id="contract"></a>
# Fusion reactor control and telemetry

## Implementation sources

- [fusion-reactor.lua](../../../exotic-space-industries-remembrance/scripts/control/fusion-reactor.lua)

## Ownership and reference flow

The reactor remains a native recipe-driven machine. `storage.ei.fusion_reactor` owns reactor records, indexed service order, manual/effective selections, control-source mode, wire proxies, and open players. Selection normalization maps fuel pair, temperature, and injection mode onto an existing recipe.

```mermaid
flowchart LR
  A["Manual GUI or circuit inputs"] --> B["Normalize effective selection"]
  B --> C["Apply and lock existing recipe"]
  C --> D["Invalidate nearby neutron collectors"]
  C --> E["Circuit telemetry and open GUI"]
```

<a id="tick-flow"></a>
## Tick flow and invariants

The staggered dispatcher supplies a budget/event to `update`; service walks the reactor index with a persistent cursor. Build and GUI recipe updates accept an event or numeric tick, with `game.tick` fallback for context-free callers. Preserve manual selections when circuit control supplies effective values, and only notify neutron collectors when the native recipe changes. Telemetry output must not be mistaken for external circuit input.

<a id="lifecycle"></a>
## Lifecycle and cleanup

Init/configuration rebuild destroys old/orphan wire proxies and reconstructs reactor entries from current world recipes. Build registers and services immediately; settings paste carries control settings through normalization. Destruction removes registry membership, proxy, and affected GUI sessions. Rebuild currently reconstructs control entries rather than promising preservation of every historical GUI choice.

<a id="verification"></a>
## Verification contract

Test manual/circuit transitions, absent or partial circuit signals, recipe changes observed by neutron collectors, copy/paste, proxy destruction, open-console removal, and configuration rebuild. Use runtime QC and inspect both recipe identity and circuit outputs. No new engine validation is asserted here.
