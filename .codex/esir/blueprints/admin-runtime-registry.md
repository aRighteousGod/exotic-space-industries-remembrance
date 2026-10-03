<a id="contract"></a>
# Admin runtime registry, diagnostics and repair ownership

## Implementation sources

- [registry.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/registry.lua)

## Ownership and public interface

The admin control owner injects already-loaded module references through `configure`.
The static registry maps every existing runtime source to a gameplay owner, helper,
stateless adapter or documented inactive/data-only exception. Only explicit stateful
owners expose repair actions. Existing aliases remain the responsibility of their
command owners. `repair` rechecks startup enablement and player admin access.

`peek(id,tick)` reads a fixed allowlist of scalar fields and existing cached telemetry.
It does not call module getters, initialize schemas, query entities, audit queues,
serialize data, write counters or enable the dormant telemetry heartbeat. Absent
measurements remain absent. Scheduler timestamps mean cache publication, not proof
of gameplay activity.
Explicit scheduler aliases map registry IDs to the owner's actual publication
keys. Enabled state uses direct feature switches or existing boolean owner/cache
fields when available; the detail pane labels other owners Not sampled. These
reads never invoke gameplay getters. Emerald's paid charge collections and real
charge/pulse deadlines are included under their authoritative storage paths.

<a id="inspection"></a>
## On-demand detailed inspections

One explicit inspection runs globally. It visits at most 64 collection entries per
dispatcher tick and stops at one million records. No inspection means no runtime
service. Stored cursors contain only owner IDs, paths and scalar keys, never aliases
to gameplay tables. A removed cursor key ends that collection with an incomplete
marker. Reports are sampled across a changing world, not atomic gameplay snapshots.
They contain counts and admin metadata, not LuaEntity or other live object handles.
Inspection can be cancelled; loss of authorization discards pending work.

<a id="repair"></a>
## Preservation contract

Repairs use module-owned entry points. Repairing derived registration, scheduling,
proxies and GUI ownership must retain paid work, resource contents, configuration,
research, currency and progression. Dangerous rebuilds are replaced by explicit
in-place repair entry points for reactors, crystals, railguns, Emerald, water turrets
and spiders. Destructive gameplay reset/recreation remains a separate explicit action.

## Verification

Check source coverage against the runtime import graph; validate every registered
repair provider exists in the injected module map. Summary reads must leave gameplay
state unchanged. With no requested inspection, open and closed admin menus cause
zero registry service work. Inspect large collections to verify the 64-entry budget,
cancel and revoke admin rights mid-job, remove cursor entries between slices, and
save/reload with pending work. Test preservation while each mechanic is active.
