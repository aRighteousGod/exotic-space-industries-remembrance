<a id="contract"></a>
# Administration tools

## Implementation sources

- [admin-tools-config.lua](../../../exotic-space-industries-remembrance/lib/admin-tools-config.lua)
- [admin-tools.lua prototypes](../../../exotic-space-industries-remembrance/prototypes/admin-tools.lua)
- [admin-tools.lua coordinator](../../../exotic-space-industries-remembrance/scripts/control/admin-tools.lua)
- [common.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/common.lua)
- [gui.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/gui.lua)
- [players.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/players.lua)
- [world.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/world.lua)
- [targeting.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/targeting.lua)
- [restrictions.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/restrictions.lua)
- [ecology.lua](../../../exotic-space-industries-remembrance/scripts/control/admin/ecology.lua)

## Access and ownership

The Ecology page edits validated per-surface overrides through the terrain owner.
Global settings remain sufficient; surface selection never creates a surface.
Inheritance/reset affect configuration only. Calendar controls preserve Fulgora's
independent ownership. Effective values, compatibility and diagnostics are read
only for an open page; drafts survive navigation without authorizing mutations.

The startup switch `ei-admin-tools-enabled` defaults false. The coordinator gates the
console, new commands and mutation services; existing legacy commands retain their
own access rules. Commands and delayed jobs revalidate administrator identity and
target validity at execution. The server console may invoke registered repairs;
opening a GUI requires a connected player.

`storage.ei.admin_tools` owns sessions/drafts, selected locations, mode restoration,
jail sentences, permission overlays, per-force spawning, explicit native planet
policies, admitted world jobs, diagnostics and prior game speed. Gameplay owners
retain authority over their native entities, paid effects and repair invariants.
The separate runtime registry describes those owners without calling their
mutating status getters.

## Entry and presentation

`/ei-admin [page]` opens a movable native screen frame. Pages are created lazily
and hidden on navigation, preserving text edits, focus and scroll state. The
optional per-player mod-gui launcher is hidden by default. Target selectors do not
create planetary surfaces. Mutation confirms identify the actual resolved target.
Closed pages build no diagnostic snapshots and receive no periodic updates.
An optional per-viewer auto-refresh toggle defaults off. A native interval selector
offers 1/2/5/10/30/60 simulation seconds, default 5. Shared delayed buckets hold one
entry per visible enabled viewer, with a cached next due tick and at most eight
refreshes per service tick. Closing cancels the entry; reopening resumes an explicit
preference. Destruction/demotion/disabled cleanup turns the preference off. Timer
service revalidates access/connection and uses the same changed-value projection;
it never starts deeper inspections or drives gameplay owners.

Display-resolution and UI-scale events resize the existing page trees, target
controls, navigation and feedback panes. All four scroll regions have bounded
heights; resizing does not recreate focused inputs, draft controls or cameras.
Target summaries wrap, coordinate controls occupy a separate row, and matching
On/Off actions share a row. Window locations are clamped in screen pixels while
element dimensions use scale-independent GUI units. Initial opening centers once;
native auto-center is disabled before dimension changes so dragged positions survive
feedback, page changes, refreshes, reopening and root recreation. Display changes
clamp only where the current location no longer fits.
A valid saved preview root without the timer controls is an actual structural
change: its next explicit opening performs one rebuild, retaining its saved
location and drafts. A rebuilt root then returns to normal identity retention;
missing/revoked timer ownership is never silently enabled during that upgrade.

Enemy catalogs offer standard and advanced native entries with prototype-name
filtering. The optional fire dropdown includes hidden native fire prototypes;
resource selection filters native resource entities. Fluid storage index zero
omits the index to select compatible storage automatically. Native single-player
games disable kick/ban controls, and surfaces without a native pollutant disable
pollution actions; execution services retain their own checks.
The pollution presets submit exactly 100, 1,000 or 10,000 units independently of
the custom field. Resource selection/amount edits update a pure native amount
readout; infinite resources additionally show amount/normal nominal yield.

Chunks lists every active world job owned by its viewer, including jobs from
other pages. Its selected job ID is independent of the most recently submitted
job, so a completed short action cannot hide cancellation of an older job.
The list reads at most the bounded 64-job snapshot; captions, choices and button
availability change only when their values change. Visible progress remains on
the existing 30-tick cadence while that viewer has active world jobs.

Diagnostics keeps distinct overview/detail scroll panes alive. The overview
shows each owner's stored state, schema and available cached count/queue scalars;
unknown counters remain explicitly unsampled. Selecting an owner reads only its
pure snapshot, then shows role, stored metrics, scheduler cache, repair history
and the last bounded inspection. Back restores the existing overview pane.
Captions change only when their signatures change. Inspect/cancel/completion
refresh through explicit actions and coordinator invalidation, not UI polling.
Long localized metric lists are grouped below Factorio's parameter limit.
The shared planet/entity target controls are hidden, with their state retained,
while Diagnostics is selected because owner snapshots do not use world targets.

The optional launcher retains its own element reference. Disabled/default-hidden
launcher maintenance does not call mod-gui's container-creating helper; cleanup
reads existing native containers only when recovering an enabled saved launcher.

<a id="targeting"></a>
## Native targeting

One hidden selection-tool serves point, rectangle, entity and secondary attack
selection. Clear the native cursor before giving the tool; retain its ghost and
the prior view. Selecting or cancelling removes the session before restoring the
view. Execution ends targeting before teleporting anyone, preventing view
restoration from undoing self travel. Neither a location picker nor a camera
creates a planetary surface.
Native remote-view exit alone does not return a god controller to its prior
physical location. Cancellation explicitly restores that saved surface/position
while the controller is still god; failed native teleport is recorded without
moving a replacement character or recreating a deleted surface.

## Player state and restoration

Travel creates surfaces only upon an explicit destination request. Gaia creation
uses its existing owner. Spawn overrides run only for newly created or respawned
characters once ready; reconnects keep their position. Native cheat mode,
character destructibility and god controller are independent owned overrides.
Opening the console or promotion to administrator does not enable any mode or
create mode ownership. Native sandbox modes require an explicit selected-player
action; status readouts are separate from Enable/Disable button captions.
The travel destination rows reconcile on visible explicit/dirty refresh only
when the planet-ID signature changes. Other page controls, drafts and the root
remain intact; closed menus never build or reconcile destination rows.

Native god mode parks the original protected character. Returning moves exact
god-inventory stacks through escrow, transfers them to the body, spills what can
be recovered and keeps failed remainders. No inventory cloning occurs. A destroyed
parked body requires a replacement without duplicating recoverable corpse items.
Native controller attachment requires a shared surface. Before reattaching a valid
parked body, move the owned god controller to that body's exact surface/position
when necessary and revalidate the body after teleport callbacks. The same guarded
return handles explicit God Off and disabled cleanup after a saved remote view;
failed return retains its original body and exact escrow for bounded recovery.

Jail uses a finite internal surface and owned permission group, saving origin,
group and modes. Online and elapsed simulation clocks both follow game speed;
online clocks pause while disconnected. Relevant player lifecycle events retain
confinement. Release restores the original safe location or force spawn. Offline
restoration remains pending instead of discarding inventory or state.

Sentences accept 1–1440 minutes and persist their reason. The prisoner sees a
persistent read-only left status panel with reason, clock basis and remaining
minutes/seconds. One shared delayed job per connected prisoner services the next
displayed second; only a changed displayed second assigns the countdown caption.
There is no all-player tick scan. Offline online sentences have no scheduled HUD
work; offline elapsed sentences retain one expiry job. Release/removal/disable
destroys the owned status panel, including when body return remains pending.

Jail permits native walking and chat on its isolated finite surface. It owns a
separate saved character-destructibility override, restoring an old body before
protecting a replacement and restoring the current body before resuming suspended
toolkit modes. Existing group edits/deletion and surface-deletion callbacks queue
repair through the player service; player surface changes defer confinement until
native teardown finishes. The visible countdown also bounds recovery. A missing
return surface uses the configured force spawn surface when already available,
then Nauvis, and its native force spawn position. Native group deletion moves its
members to Default (group id 0). A recorded owned-group deletion makes that native
fallback eligible for saved-group restoration; a distinct external group survives
release. Independent mode restoration and exact god-inventory escrow are unchanged.

<a id="interaction-restrictions"></a>
## Player-built entity restrictions

A per-player permission overlay guards direct selected/native-GUI interactions
when a player-built entity's last user differs from the player. Natural entities
and unattributed map/script entities remain usable. Native last_user is the last
settings editor, not immutable builder identity; placeability alone is no proof.
Real builds preserve provenance when a previous user disappears.

The first restriction starts a generated-chunk attribution census: at most one
native chunk query and 64 processed entity records per tick, with bounded finite
map void traversal. Area/undo/redo input pauses while this explicit scan is pending.
A dense native query can allocate more than 64 handles; Lua processing is bounded.
Original permissions return for own/natural area actions when the scan completes.
The four native mark/cancel events have already overwritten last_user, so the
prior cache restores rejected foreign orders and their previous targets/qualities.
Existing exact interaction events and a bounded 30-tick active-handle watch keep
attribution current. No restrictions means no census/watch work. Jail temporarily
owns its stricter permission group; removal restores the prior group.

Deleting an owned permission overlay moves its members to native Default (id 0).
That deletion fallback does not replace the saved inherited policy when the
overlay is recreated or disabled. A distinct external group assignment becomes
the inherited policy and survives later restriction removal.
Owned membership assignments guard their synchronous native remove/add callbacks;
the temporary no-group state cannot replace the inherited permission policy.

Indirect/AoE damage, another mod's mutations, historical undo/redo and edits
without an immediate native event are explicit limits. Factorio 2.0.77 exposes
post-undo events and optional target surface data, not a complete pre-action
guard. This feature is not a complete multiplayer anti-grief boundary. The native
fixture and API limits are recorded in scripts/qc/admin-tools/RESTRICTIONS.md.

## World jobs and budgets

World jobs persist their actor, exact surface object, force, cursor and native
pending-work ownership. Shared scheduler queues service admitted work round-robin.
Ordinary creation is limited to 25 attempts per tick, segmented enemies to one per
tick, iterator/candidate work to 64 visits, chart submissions to four, and generation
submissions to one per 30 ticks with at most 16 owned requests. Native chart work
has at most 32 owned pending requests. Generation times
out after 3,600 ticks. Reveal-only does not generate terrain. Native submitted work
can finish after cancellation; unrelated chart jobs are not cancelled.

Resource patches skip existing deposits and never remove trees/cliffs.
Scripted entity placement respects collision/surface/rail rules and raises build
events, revalidating returned handles after owner replacements. Every subsequent
creation rechecks job membership, administrator access and exact native targets
after synchronous build callbacks. Rolling stock never searches for a different
nearby track when placement at the selected position fails. Fluid additions
preserve compatible native storage/temperature and notify the fluid-safety owner.
Enemy policies distinguish native surface suppression, per-surface settlement
suppression and the global planner. Demolishers are destroyed as segmented units.
A wave's ordinary units and commandable spider-units share a native unit group.
An explicit destination supplies one group attack-area order; otherwise the group
uses native autonomous behavior. The queued job retains the native group handle.
Completing or cancelling creation starts already-created members and leaves them
to native AI; cancellation does not delete the group or its members. Stationary
structures and demolishers retain their separate native behavior.
Enemy clearing rechecks force eligibility at each slice and each destruction in a
batch. A player joining the target force or an additional force becoming friendly
cancels future removals. Raised destroy callbacks may transfer or remove other
entities, so every returned target must still belong to the exact surface/force.

Positional ruptures use the existing real effect builder and scheduler without a
dummy machine or pipe traversal. One admin rupture is admitted at a time; committed
effects drain normally on toolkit shutdown.

## Lifecycle and shutdown

New planetary surfaces receive the peaceful default only when newly created;
explicit planet-keyed policies win. Gaia notifies the optional coordinator after
planet association, including staged reforge completion, so temporary unassociated
surfaces cannot lose their policy. Rebinding an existing legacy surface does not
apply the new-surface default.

Instant research persists the enabling administrator and revalidates that actor
when due. Infinite technologies use the native max_level sentinel and stop after
one level until explicit reselection or Finish current. Ordinary/scripted research
completion still enters the existing coalesced research-burst dispatcher.

Configuration changes reconcile caches and startup enablement. Disabled cleanup
removes the toolkit UI/cursor, stops automation, cancels future job submissions,
releases jail sentences and restores owned player modes and previous speed.
Completed world edits, native policies, research, entities, bans and promotions
remain. No work runs during on_load; persistent queues resume through the dispatcher.

## Verification

Use Factorio 2.0.77 engine fixtures for controller inventory transfers, jail clocks,
permissions, surface policies, native effects, chunk ownership and save/reload.
The repository preflight checks syntax, locales, source ownership and backlinks.
GUI checks require connected viewers and multiple scales. Mocked budget assertions
are supporting evidence, not engine or whole-UPS measurements.
