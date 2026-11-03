<a id="contract"></a>
# Map runtime options and Administration editor

## Implementation sources

- [runtime-options-config.lua](../../../exotic-space-industries-remembrance/lib/runtime-options-config.lua)
- [runtime-options.lua](../../../exotic-space-industries-remembrance/scripts/control/runtime-options.lua)
- [admin/options.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/options.lua)

## Authority and scope

The catalog explicitly allows ESIR's runtime-global settings. Native `settings.global`
owns every value; the editor creates no parallel override store. The 29 converted
settings use their original name plus `-runtime`. Their hidden startup originals
exist only as migration inputs. Current coverage is 113 fields: 29 conversions,
79 terrain settings, two administration policies and three factory-passage settings.
Prototype metadata supplies exact types, ranges and allowed values. Provider-added
alert sets extend both default selectors and the personal selector during settings.
The catalog's legacy-name reader preserves false, zero and Off without fallback.

Singularity Lance, ANISETRON and prototype-changing settings retain their startup
contracts. Terrain's startup master switch also remains startup-only. Options edits
terrain's global defaults; Ecology continues to own explicit surface overrides.
Custom intensity and budget fields remain editable while a preset is selected,
with a visible explanation that the respective Custom preset activates them.

<a id="migration"></a>
## Initialization and migration

`storage.ei.runtime_options.migration_version` records the one-time import. Fresh
maps mark version 1 and retain their native Map selections. Existing maps without
the marker copy all 29 synchronized hidden startup values into the new map names
before ordinary configuration initialization. A batch suppresses intermediate
owner callbacks; lifecycle reconciliation runs after owners are ready. Subsequent
loads/configuration changes never reimport. Hidden inputs are not forced or deleted;
removing that compatibility bridge requires a separate migration decision.

Local transaction frames exist only during synchronous callbacks and are never
saved. `on_load` does not read game state, rewrite settings or replay migration.

<a id="transactions"></a>
## Transactions and dispatch

An Apply validates all edited values and compares their original baseline with
fresh native values before writing anything. It checks finite numbers, exact
integer/range/choice constraints, strings and terrain pollution ordering. Untouched
imported values are preserved. Fields write in stable ID order with native readback.
Failure restores attempted writes in reverse order. Successful rollback discards
all deferred effects; an incomplete rollback reports failure and reconciles the
actual remaining values. The audit records successful native readbacks.

Factorio 2.1.24 raises setting-change events synchronously for script assignments,
including equal-value writes. Those native events are collected; callers never
manufacture a second event. The outer administration batch delays ESIR owner
reconciliation until audit/feedback complete. `control.lua` groups changes by owner,
updates scheduler globals first, and reconciles each affected owner once. The
administration gate runs last because it may destroy its own editor. External
native Map edits use the same owner dispatcher immediately. Other mods' event
receivers are outside this ESIR batching contract.

```mermaid
flowchart LR
  Draft[One administrator draft] --> Validate[Validate and compare baselines]
  Validate --> Native[Ordered native writes and readback]
  Native --> Events[Synchronous native setting events]
  Events --> Batch[Collect changed IDs]
  Native --> Receipt[Audit and feedback]
  Receipt --> Owners[Refresh affected owners once]
  Batch --> Owners
  Owners --> Gate[Administration availability last]
```

## Feature transitions

| Owner | Live-change contract |
| --- | --- |
| Administration | Restore modes/permissions, stop admitted admin work and close windows when disabled; native Map can re-enable without restart. |
| Technology curve | Refresh completed native research and the multiplier while preserving current research progress and scripted burst queues. |
| Rocket pollution | Newly admitted launches capture mode, cap and visual policy; pending launches and detached emissions retain their budgets/deadlines. |
| Ruptures | New jobs select current fidelity; paid rings and existing jobs retain their captured policy. |
| Fluid ignore names | Coalesce bounded removals and chunk/name-filtered rediscovery into normal fluid service; preserve unrelated segment queues/history. |
| Fulgora bounds | Update future-cycle bounds without RNG draws, day-length changes or cycle reset. |
| EM visuals | Change only scalar presentation mirrors; existing finite render objects expire naturally. |
| Scheduler | Refresh cadence/budgets without replacing queues, cursors or last-run timestamps. |
| Saucer/hover | Change presentation caches only. Saucer Off retains event-fed identities; resuming samples current positions without catch-up trails or a world scan. |
| Water targeting | New fire searches capture the new policy; active searches finish under their admitted policy. |
| Pressure grace | Refresh toggle/profile under the existing Impossible-difficulty veto without applying extra pollution reduction. |
| Tesla text/reminder | New messages use current choices; gameplay coefficients and arrival state remain unchanged. |
| Alert default | Affects later default-copy actions/new players; explicit personal choices remain authoritative. |
| Terrain/passage | Reuse existing setting hooks and preserve their owner-specific queues and effective-preset rules. |

## Editor lifecycle

One per-administrator draft spans categories. Native booleans, enum selections,
number/integer text and free strings use existing setting labels and descriptions.
Untouched fields rebase on explicit refresh; edited fields retain their baseline
and text so another administrator cannot be silently overwritten. Apply submits
all categories. Reload/Discard replace the entire draft. Visible controls are
retained across ordinary refresh and navigation; closed pages add no polling.
Apply rechecks administrator identity and toolkit availability. World target
selectors are hidden because all fields apply to the entire save.

Factory passage's former three Map Settings rows move to Options → Performance.
Old drafts transfer their values and original baselines; the map editor provides a
navigation link. Saved consoles lacking Options rebuild lazily while retaining
drafts. Administration cleanup may destroy the active page during Apply, so the
caller does not dereference its GUI elements afterward.

## Verification

test-suite: runtime-options

test-case: runtime-options/candidate

test-case: runtime-options/reload

test-case: runtime-options/configuration

See the [implementation receipt](../handoffs/runtime-options-implementation-2026-11-02.md)
for the passing six-case matrix, final-source continuation and genuine preserved
save migration. The ordinary reload case includes a pending native fluid-discovery
iterator and distinguishes reload from configuration repair.

Native setting events, owner cache refresh, rollback, GUI callbacks and persistence
require exact-version Factorio evidence. Mocked Lua tests establish only control
flow. A programmatic native GUI check is not rendered or mouse acceptance, and two
administrator sessions are not a multiplayer desync test. Controlled hidden-value
import fixtures are not authentic historical-save migration evidence. Preserve
those distinctions in the final receipt and implementation handoff.
