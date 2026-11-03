# Build receiver overlap and cost implications

Source audit: 2026-11-01, current ESIR checkout and Factorio 2.1.24. This maps
admission and lifecycle ownership, not measured per-handler time. Startup settings,
research, native prototype capabilities and optional dependencies can narrow the
sets further. The exact native run inputs are recorded by the accompanying suite.

## Which entities need multiple owners?

Yes, some do. Most named feature families are separate, but the dispatcher also
delivers observation and shared-service work. It cannot be replaced by a single
exclusive `elseif` chain without losing legitimate secondary consumers.

| Entity/family | Required feature overlap beyond early observation | Consequence |
| --- | --- | --- |
| Ordinary chest | No named feature owner in this build fan-out | Most feature calls are relevance misses; terrain/admin can still observe the build. |
| Pipe, pipe-to-ground, storage tank; eligible elevated pipe | Shared fluid handling | Skip unrelated named systems in a future routing pass, while preserving the fluid exclusion policy. |
| Exotic assembler | Matter stabilization; beacon overload when enabled/eligible | Both owners must run. Their registrations are different persistent relationships. |
| ESIR fusion reactor | Fusion controls and neutron-source updates; beacon admission depends on effect eligibility | An exact reactor route still needs secondary shared consumers. |
| Steam locomotive placement | Steam conversion/wheels, then fueler registration for the final locomotive | A route based only on the original placement name misses the final native type. |
| Sawblade ammo turret | Sawblade effects/runtime and fueler target registration | Its dedicated owner does not replace generic ammunition service. |
| ANISETRON | ANISETRON visuals/mobility plus fueler admission as a spider vehicle | Spider-vehicle type alone does not prove membership in the configurable Spidertron catalog. |
| Catalog-supported Spidertron | Spider preferences/refit work and fueler target registration | Keep both, including internal-transaction rules and item restoration. |
| Emerald Apocalypse car | Emerald systems and fueler target registration | Vehicle-specific ownership and generic service are additive. |
| Rocket silo | Orbital-logistics cache/cohort invalidation; beacon eligibility | A handler can affect nearby/force state without registering the entity as its own named feature. |
| Combustion turbine | Turbine shell/GUI ownership | Current beacon and fueler type sets exclude both turbine shells. Calling those receivers does not imply useful overlap. |
| Induction core | Matrix topology/proxy ownership | Duplicate resolution can remove another core. Never register that existing survivor as this new placement. |

Evidence owners: [matter](../../../exotic-space-industries-remembrance/scripts/control/matter-stabilizer.lua),
[fusion](../../../exotic-space-industries-remembrance/scripts/control/fusion-reactor.lua),
[neutron](../../../exotic-space-industries-remembrance/scripts/control/neutron-collector.lua),
[beacon](../../../exotic-space-industries-remembrance/scripts/control/beacon-overload.lua),
[fueler](../../../exotic-space-industries-remembrance/scripts/control/fueler/fueler.lua),
[orbital logistics](../../../exotic-space-industries-remembrance/scripts/control/orbital-logistics.lua).

## Complete receiver admission map

The six shell owners below run before general registration. Their own registration
may occur during that call; they are not called again in the final fan-out.

| Receiver | Relevant inputs / effect | Lifetime or ordering implication |
| --- | --- | --- |
| Air scrubber normalizer | Unprefixed nonnormal-quality `atan-air-scrubber` | Can replace and synchronously notify other mods; notification guard and revalidation required. |
| Terrain evolution | Any valid placement while ecological work is active; drill subregistry separately filters | Broad surface/position wake is intentional, including later-rejected placements. |
| Administration | Eligible non-enemy/non-neutral entities while tracking is active | Records native placement attribution before later mutation. |
| Sweeping radar | Owned chassis/placement variants, relevant ghosts, copied helpers | Can replace chassis or consume cloned helpers. |
| Flamethrower fuels | Owned fuel variants, their ghosts and base turret according to enablement | Can replace ghost and rewrite the event; supports retained restoration work while disabled. |
| Water turret | Water turret, fires when its index is active, copied power helper | Fire indexing is an extra interest beyond its named turret; clone helper may be consumed. |
| ANISETRON | Vehicle visual/mobility ownership and exact voice helpers | Copied voices are destroyed before the Spidertron transaction guard. |
| Combustion turbine | Solid/fluid turbine shells | Tagged placement may replace; failed creation retains original. |
| Induction matrix | Core and named components in `only_on_tile` | Floor legality and duplicate-core resolution precede general registration. |
| Gaia | Pump reject/swap tables and configured decay names | Rejection wins over swapping. Current decay-name table is empty. |
| Crystal accumulator | Live base/Gaia shell names | Surface profile can replace the incoming shell. |
| Steam train | Placement wrapper or real steam locomotive | Conversion and wheel ownership; unrelated builds now bypass global setup. |
| Tesla | Four public/exotic basic/advanced coil identities | Variant normalization; unrelated builds now bypass state and force-cache setup. |
| Spider vehicles | `spider-vehicle` plus catalog-recognized family | Restores placement preferences/items and queues refits; generic spider type is insufficient. |
| Shared fluids / steam priming | Fluid-policy-approved pipe/tank types, elevated pipe exception; otherwise `rp-steam-pump` | Shared registry and pump priming are distinct branches; retain exact policy and quantities. |
| Fusion reactor | Exact ESIR fusion reactor | Registers controls, recipe and initial service. |
| Beacon overload | Beacon or eligible assembler/furnace/lab/silo/drill; enabled, exclusions and effects checked | Broad secondary owner; never prune solely on an ESIR name prefix. |
| Neutron collector | Collector or names in `neutron_sources` | Currently calls `ensure_runtime_ready` before relevance; can opportunistically rebuild on unrelated builds. |
| Matter stabilizer | Two stabilizers or exotic assembler | Currently calls `check_global` and possible rebuild before name admission. |
| Black hole | Black hole and injector/extractor pylons | Pylons invalidate nearby black holes; one family has three interests. |
| Gate | Gate container or receiver | Container constructs its paired hidden gate; main container survives. |
| Auric vat | Exact vat | Registers basin state and updates nearby placement guides. |
| Loaders | Named ESIR loaders; transport belt/underground/splitter types | A belt can trigger adjacent-loader work without itself being a loader. |
| Fueler | Fueler tower or locomotive/car/spider/ammo-turret/artillery-turret/artillery-wagon | Shared target registry; not all burners or generators qualify. |
| EM trains | Charger names, authored rail-name set, train names | Rail construction can affect nearby charger topology. |
| Orbital combinator | Exact scanner with unit number | Registers scanner and rebuilds scanner banks. |
| Orbital logistics | Any rocket silo; named transponder/selector/coordinator/uplink | Silo route invalidates caches/cohorts; named devices have separate records. |
| Railgun cooling | Exact railgun turret | Creates/maintains coolant and recovery ownership. |
| Campfire | Exact campfire | Registers its own runtime work. |
| Singularity Lance | Exact lance | Registers combat owner. |
| Sawblade turret | Exact sawblade turret | Registers animation/combat owner. |
| Gaian saucer wake | Exact saucer, visual setting enabled | Registers wake visuals. |
| Emerald Apocalypse | Exact tank | Registers vehicle-specific systems. |
| Alien system | No build behavior after validity check | Dispatcher call removed; export retained for compatibility. |

The implementation remains in [control.lua](../../../exotic-space-industries-remembrance/control.lua)
and its directly imported owners; the table is an audit aid, not another runtime
registry or an authoritative duplicate of module-owned name lists.

## What this means for optimization

1. **Separate routing overhead from useful overlap.** A chest reaching 31 receivers
   does not mean 31 features adopt it. Many return immediately, but every dispatch,
   validation and pre-admission setup still has a cost.
2. **Prune setup before adding a routing framework.** Neutron and matter are the
   clearest follow-up targets. Move relevance ahead of setup only after confirming
   init/configuration/service paths still own repair; removing incidental repair
   triggers is a lifecycle change, even if ordinary populated saves look identical.
3. **Use additive routing for shared consumers.** Exact-name feature selection can
   coexist with type-based services. Exclusive routing is appropriate only for
   proven-disjoint families. Keep lookup sets with their owners to avoid drift.
4. **Route the final identity.** Steam, Tesla, crystal, turbine and scrubber swaps
   can change native capabilities or unit numbers. Cache name/type only after a
   successful handoff; do not reuse classification of a destroyed shell.
5. **Keep required checks at mutation boundaries.** One successful entry check
   cannot validate an entity after a synchronous external event or a shell swap.
   Conversely, repeated checks inside a stable scope are candidates for removal.
6. **Measure construction workload.** This is build-event cost, concentrated during
   placement, robot/blueprint bursts, revives and scripted construction. This patch
   adds no tick dispatcher, periodic scan, or general registry. Correct final-shell
   enrollment can legitimately activate a pre-existing feature such as fuel service.

The current focused repair produces these measured call counts:

| Placement | Receiver calls before / after | Shared `ei_lib.entity_check` calls before / after |
| --- | ---: | ---: |
| Ordinary chest | 32 / 31 | 40 / 38 |
| Pipe | 32 / 31 | 41 / 39 |
| Unchanged turbine | 32 / 31 | 45 / 42 |
| Unchanged crystal | 32 / 31 | 42 / 40 |
| Unchanged Tesla | 32 / 31 | 40 / 39 |

These counters do not include every native validity read, setup invocation or
prove elapsed-time/UPS improvement. Tagged-turbine baseline dispatch aborts,
so its lower call count cannot be used as a performance comparison with the fixed
successful route. Broad type/name dispatch pruning is deliberately not implemented
as part of this lifetime repair.
