<a id="contract"></a>
# Mining scar event path

## Implementation sources

- [mining-scars.lua](../../../exotic-space-industries-remembrance/scripts/control/mining-scars.lua)

## Ownership and reference flow

The mining owner forwards finite-resource depletion to the bounded
[terrain service](terrain-evolution.md#contract). The event names a resource,
not its causing drill. The precise contract is **finite deposits exhausted within
eligible drill coverage**. The four existing quarry/drill names, radius 56,
patch radius 3 and probability 0.7 remain configurable defaults.

One immediate local coverage query per tick examines at most 32 named drills.
Native mining_area accounts for quality. Resource categories and finite deposits
are checked before admitting a coalesced cosmetic descriptor. Saturation skips
new effects; it never starts a broad drill registry or catch-up scan.

<a id="tick-flow"></a>
## Tick flow

Pass event.tick through admission. control.lua alone services the shared global
budget. Immutable transitions live in terrain-policy.lua, including the corrected
Gleba target midland-cracked-lichen-dark. Final loaded prototypes determine edges.

<a id="lifecycle"></a>
## Protection and recovery

The shared guarded application path protects infrastructure, resources, paving,
liquids, hidden layers, foundations, cultivated flora, Auric claims and Gaia sites.
Permanent mining removes older ecological recovery claims. Opt-in mining recovery
starts at the pre-mining tile, then records repeated mining steps exactly.

<a id="verification"></a>
## Verification

The isolated terrain fixtures cover real resources and quality-aware mining areas.
Coverage cannot identify the actual causing drill when eligible drills overlap.
See scripts/qc/terrain-evolution/README.md for commands and measured evidence.
