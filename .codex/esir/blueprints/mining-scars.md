<a id="contract"></a>
# Mining scar event path

## Implementation sources

- [mining-scars.lua](../../../exotic-space-industries-remembrance/scripts/control/mining-scars.lua)

## Related ecology sources

- [terrain-evolution.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-evolution.lua)
- [terrain-ecology-work.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-ecology-work.lua)

## Ownership and reference flow

The mining owner forwards finite-resource depletion to the bounded
[terrain service](terrain-evolution.md#contract). The event names a resource,
not its causing drill. The precise contract is **finite deposits exhausted within
eligible drill coverage**. The four existing quarry/drill names, radius 56,
patch radius 3 and probability 0.7 remain configurable defaults.

One immediate local coverage query per tick examines at most 32 named drills.
Native mining_area accounts for quality. Resource categories and finite deposits
are checked before admitting a coalesced cosmetic descriptor. Saturation skips
new admissions rather than deleting accepted requests. Deferred qualification
retains exact position, resource category, event tick and up to four chunk tokens;
it never needs the depleted entity to survive. Saturated local results subdivide
boundedly. Accepted/partly applied mining requests have no age expiry.

An event-maintained registry adds independent periodic scars from working drills.
It retains the four approved names, capped at 4,096 identities globally, including
valid idle drills. Creation, revival, cloning, committed removal, death, registered
destruction, teleportation and surface/configuration lifecycle maintain membership.
Native mining targets must be valid finite resources on the drill's surface.
At most min(4, configured history allowance) cached checks per service spend remaining
candidate work and perform no entity searches. Initial deadlines are deterministic;
late visits get one opportunity. Defaults are 10% per 300 base seconds (600 under
Restrained before seasonal modulation), independently of patch probability 0.7.
Old-save discovery shares H query grants with hazards and reports limited coverage
when capped results/candidate allowance cannot verify a whole chunk.
Effective surface disablement stops queries, periodic checks, admission and writes;
accepted requests pause. Cheap membership maintenance may continue.

<a id="tick-flow"></a>
## Tick flow

Pass event.tick through admission. control.lua alone services the shared global
budget. Immutable transitions live in terrain-policy.lua, including the corrected
Gleba target midland-cracked-lichen-dark. Final loaded prototypes determine edges.

<a id="lifecycle"></a>
## Protection and recovery

The shared guarded application path protects infrastructure, resources, paving,
liquids, hidden layers, foundations, cultivated flora, Auric claims and Gaia sites.
Mining recovery defaults on, starting at the pre-mining tile and recording repeated
mining steps exactly. Disabling recovery makes new mining damage permanent and
removes older ecological recovery claims. Earlier unrecorded scars cannot be reconstructed.

<a id="verification"></a>
## Verification

The isolated terrain fixtures cover real resources and quality-aware mining areas.
Coverage cannot identify the actual causing drill when eligible drills overlap.
See scripts/qc/terrain-evolution/README.md for commands and measured evidence.
