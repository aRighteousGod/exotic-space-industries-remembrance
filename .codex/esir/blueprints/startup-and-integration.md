<a id="contract"></a>
# Startup, compatibility, diagnostics, and information interfaces

<a id="admin-repair"></a>
## Admin repair

Arrival repair normalizes pending players and the saved wave due minimum without replaying arrival rewards/effects. Informatron notification repair prunes only nonexistent force ownership, retaining delivered-page history. Admin registry diagnostics remain separate from mutating legacy status getters.

## Implementation sources

- [echo-codex.lua](../../../exotic-space-industries-remembrance/lib/echo-codex.lua)
- [compat.lua](../../../exotic-space-industries-remembrance/scripts/control/compat.lua)
- [air-scrubber-compat.lua](../../../exotic-space-industries-remembrance/scripts/control/air-scrubber-compat.lua)
- [debug.lua](../../../exotic-space-industries-remembrance/scripts/control/debug.lua)
- [informatron.lua](../../../exotic-space-industries-remembrance/scripts/control/informatron.lua)
- [informatron-messager.lua](../../../exotic-space-industries-remembrance/scripts/control/informatron-messager.lua)
- [milestone-preset.lua](../../../exotic-space-industries-remembrance/scripts/control/milestone-preset.lua)
- [construction-drone-compatibility.lua](../../../exotic-space-industries-remembrance/scripts/data-final-updates/construction-drone-compatibility.lua)

## Behavior and ownership

<a id="construction-drones"></a>
### Construction Drones drill upgrade compatibility

Construction Drones Forked 1.1.18 deliberately excludes the vanilla electric drill
from its construction-drone collision layer, while adding that layer to ESIR's
Advanced and Superior drills. The latter explicit masks also acquire ESIR's hover
layer. Factorio consequently rejects the vanilla → Advanced → Superior upgrade
chain. A hidden optional dependency orders the fork before ESIR. At the end of
ESIR final data, the two same-footprint tiers inherit the vanilla drill's complete
collision-mask policy, including an omitted mask and native fallback when present.
This preserves the fork's vanilla-drill pass-through policy throughout the chain.

Only these two masks change, and only when the fork is enabled. Collision boxes,
mining speed, energy, recipes, resources, next-upgrade identities, native graphics,
death effects, circuit connectors and existing entity state are unchanged. There
is no runtime work, setting, locale key or migration script. Verify native startup
with the fork, effective mask equality and actual fast replacement through both
tiers; the ordinary core configuration must retain its previous final data.

<a id="scrubber"></a>
Data-stage quality-variant patches require the companion's supported Quality
integration and actual generated prototypes. Runtime rebuild returns immediately
when these variants are absent, avoiding a no-Quality world scan. Ordinary scrubber
changes and operation remain active.

### Air Scrubber 0.2.9 quality repair

The published fork's build filter names a nonexistent entity, so ESIR normalizes
the unprefixed nonnormal furnace at its central build/clone boundary. A dedicated
replacement group allows native inventory transfer without destroying the source
first. The accepted shape is one input/output slot with no modules or fluid
storage; changed optional shapes fail closed. Explicit progress, energy, damage
and script/user flags are restored before the script-built notification. A
shared replacement family is required. The runtime `can_fast_replace` query
rejects these hidden identity variants even when actual native replacement
succeeds, so the repair verifies the actual transaction instead. A protected
source temporarily permits mining within the synchronous transaction; its
original flag is restored on the replacement or on the source after failure.
Energy transfers up to the quality variant's native buffer capacity; its authored
lower power usage and corresponding smaller buffer remain unchanged. A full base
buffer can therefore lose the excess charge during identity correction.
If creation leaves the source alive,
only the new unnotified candidate is removed and the populated source is kept. A
synchronous notification guard prevents duplicate ESIR handling. Configuration
changes repair already-placed unprefixed furnaces once; there is no tick scanner.
Quality-prefixed identities and normal quality are unchanged. Acceptance requires
populated replacement, every build/clone path, failure and save/reload fixtures.

Informatron presents [Pyric Radiance and Ballistic Divergence](combat-doctrines.md#contract)
using shared stage-neutral configurations; these pages own no combat effects.
`compat.warn_combat_overlap` prints independent optional-counterpart warnings
through the [combat overlap contract](combat-doctrines.md#overlap) on native
singleplayer initialization and multiplayer join. Other player-entry hooks do
not repeat those warnings; disabled integrated features produce no warning.

This group owns presentation/integration boundaries, not feature mechanics. `echo-codex.handle_global_settings` synchronizes startup-derived runtime settings. Player entry queues the arrival ritual until a character exists. Informatron and Milestones expose stable remote interfaces; `informatron-messager` announces newly relevant pages. `compat` bridges optional mods and accepts Gaia-surface/beacon-overload overrides. `debug` exposes explicit diagnostic and repair commands.

```mermaid
flowchart TD
  J[Player creation, join, respawn, or SP init] --> Q[pending_arrivals keyed by player]
  T[Coordinator event.tick] --> F[flush_pending_arrivals]
  Q --> F
  F --> C{Valid player with character?}
  C -->|ready| A[youHaveArrived and timed waves]
  C -->|not ready| Q
  C -->|stale player| X[Remove pending entry]
  A --> W[Due wave service and removal]
  R[Research or burst refresh] --> N[Per-force page deduplication]
  N --> I[Informatron announcement]
```

## Interfaces and invariants

<a id="hierophant-page"></a>
The Gaian Hierophant page (`gaian_hierophant`) is always available under New
logistics beside the Gaian saucer. Informatron owns its GUI lifecycle; ESIR builds
static wrapped sections and item cards only when opened. The page reads crown and
facade damage, range, arc, contact cadence, charge duration and Testament interval
from the shared ANISETRON/Lance configurations. Its selected visual preset comes
from the startup setting. Imports remain at control parsing time. All seven
locales supply menu/title keys, body text, crystal-charge labels and preset labels;
the page owns no weapon, movement, payment, notification or periodic work.

`storage.ei.pending_arrivals` deduplicates players; `arrival_waves` and `arrival_waves_next_due_tick` hold scheduled beam records and their derived minimum. `flush_pending_arrivals` drops nonexistent players, waits for character readiness, then calls `youHaveArrived` with the flush callback's current tick. The pending entry stores no original enqueue timestamp. Wave service removes completed beams and empty waves.

`storage.ei.informatron_messager.notified_by_force` stores announced pages by force index. Both `on_research_finished` and `on_scripted_research_burst` use the same deduplication path; the burst path inspects completed technologies instead of inventing one representative research event.

Remote names are `exotic-industries-informatron`, `exotic-industries-milestones`, and `exotic-industries`. The latter adds/clears `storage.gaia_surfaces` and modifies `storage.ei.beacon_overload.compat` exclusions/weights, then requests the owning beacon runtime to refresh. It does not directly own beacon topology. Optional startup integrations check mod/interface availability before calling K2 or DiscoScience. `compat.nth_tick` is an empty legacy function, not an active scheduler registration.

Diagnostic entrypoints include `ei_runtime_status`, `ei_orbital_scanner_probe`, `refresh_beacon_overload`, `rescan_orbital_logistics`, and `reforge_gaia`. Commands differ in authorization and side effects; do not assume every status-looking helper is pure or every command is read-only. Informatron pages should describe the owning config/runtime contract rather than create another set of gameplay constants.

<a id="tick-flow"></a>
## Tick flow

Arrival scheduling and waves use the coordinator's event tick. Pending readiness is checked by the coordinator's arrival flush; due wave service uses the stored minimum. Keep both event-supplied tick paths intact. Explicit command/remote diagnostics may have no gameplay event tick and use existing observational APIs; this does not justify replacing available callback ticks elsewhere.

<a id="lifecycle"></a>
## Lifecycle and cleanup

Settings synchronization occurs through init/configuration orchestration. Player-created/joined/cutscene/respawn hooks and singleplayer init enqueue work. No arrival gameplay should move into `on_load`. Invalid pending players are removed, and consumed wave records are deleted. Existing beam records contain surface references; changing surface lifecycle behavior requires checking that delayed presentation cannot dereference a removed surface.

Remote callbacks and command registration remain available after script reload through module loading, while persistent counters/queues live in storage. Newly added optional integration must preserve an absent-mod path. Page notification flags intentionally survive reload to avoid repeated announcements.

<a id="verification"></a>
## Verification and limits

Use the [GUI lifecycle fixture](../../../scripts/qc/control-ups/gui-lifecycle.lua) and [control lifecycle driver](../../../scripts/invoke-control-lifecycle-qc.ps1) for entry/GUI transitions, and the [scripted research helper](../../skills/esir-dev/references/scripted-research-qc-helper.md) for notification fan-out. Inspect the real command callback before invoking it; Gaia reforge is destructive gameplay behavior.

Cover new-save entry, characterless player waiting, reconnect, SP reload, stale player removal, disabled optional dependencies, force page deduplication, compatibility override refresh, and delayed waves during surface changes. The current source review is not a fresh visual or multiplayer validation, and the cited fixtures do not prove every optional integration.
