<a id="contract"></a>
# Planetary terrain evolution

## Implementation sources

- [terrain-policy.lua](../../../exotic-space-industries-remembrance/lib/terrain-policy.lua)
- [terrain-evolution-config.lua](../../../exotic-space-industries-remembrance/lib/terrain-evolution-config.lua)
- [terrain-evolution.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-evolution.lua)
- [terrain-calendar.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-calendar.lua)
- [terrain-ecology-work.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-ecology-work.lua)
- [terrain-gui.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-gui.lua)
- [terrain-field-report.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-field-report.lua)
- [terrain-alerts.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-alerts.lua)
- [terrain-alert-config.lua](../../../exotic-space-industries-remembrance/lib/terrain-alert-config.lua)
- [terrain-index.lua](../../../exotic-space-industries-remembrance/lib/terrain-index.lua)
- [terrain-evolution prototypes](../../../exotic-space-industries-remembrance/prototypes/terrain-evolution.lua)

## Ownership and reference flow

Native ESIR implementation informed by TerrainEvolution by Cheshirrski and
TerrainEvolution2 by MeteorSwarm/Nicholas Gower. No upstream runtime code is copied.
Mining scars transition data retains its original Mylon attribution.

Startup defaults on; restrained intensity, lean budget and seasonal daylight are
the shipping presets. All ecology switches default on, including mining recovery;
wildfire defaults to Contained. Each feature remains independently configurable.
Saved settings and explicit surface overrides retain their selected values. Settings resolve
at lifecycle/configuration boundaries; validated surface overrides live here,
while administrator widgets own only drafts.

The immutable policy restricts named ground families to six explicit planets.
Unknown/platform surfaces, hidden/foundation tiles, infrastructure and ghosts,
active resources, cultivated flora, Auric claims and authored Gaia sites are
protected. The vat exposes a pure claim probe. Gaia placement registers bounds
before writing; artifact flags conservatively protect surviving legacy sites.
Tree families are explicit for Nauvis, Gaia, Vulcanus and Gleba; cultivated
fruit plants and their special soils are excluded. Gleba wild trees may use
approved wetland habitats without converting their liquids into generic water.
Approved wetland-to-wetland degradation retains native collision rules.

<a id="lifecycle"></a>
## Lifecycle and recovery

storage.ei.terrain_evolution owns bounded dense active/event/tile-history/tree-
history/ignition sets, per-surface settings, iterators and protection/deletion
provenance. Surface identity and reference-counted chunk tokens prevent stale restoration after
regeneration. History is reserved before reversible mutation and stores the exact
finite transition path. A staged write reserves capacity but changes the lineage
only after the native tile confirms success. Background checks skip that service's
reserved positions. Refused unchanged writes retain older committed paths;
external replacement still invalidates ownership. Mining recovery defaults on and rebases at the pre-mining
tile; permanent mining, when recovery is disabled, supersedes ecological history.
Earlier unrecorded scars cannot be reconstructed. External writes invalidate history,
including raised same-name writes. Self-raised tile notifications retain history.
At capacity, new reversible mutations are refused; existing records are retained.
Disablement retains history and releases owned daylight without catch-up bursts.
Surface clearing replaces terrain ownership but preserves the same orbital
record, phase and external-control suspension. Deleted surfaces use constant-time
schedule removal. Chunk deletion decrements retained protection-cache counts;
an earlier protection-capacity saturation remains fail-closed because some
authored bounds could not be recorded.

<a id="scheduling"></a>
## Timing and bounded work

control.lua remains sole dispatcher with its existing sixteen-slot rotation.
One global Lean service runs every 16 ticks: cold discovery 1, active samples 2,
candidate visits 32, tile/tree history visits 4, writes 4 (2 reserved for recovery),
and event inspections 4. Entity searches have a separate 32-tick allowance of one;
unused allowances never accumulate. Ultra Low, Low, Lean, Balanced, Detailed,
High Fidelity and Ultra High Fidelity provide progressively greater global work
and storage allowances; Custom exposes both intervals and finite limits. Intensity
and hazardous-module switches remain independent. Custom candidates have a floor
of 27 for Gaia's atomic biome/placement work; active samples have a floor of 2.
V2 timings require fresh attributed and whole-engine evidence; operation limits
alone do not establish a UPS claim.
No cap reduction discards committed history.
Ingress admits 16 descriptors/tick; mining separately permits one local query with
32 candidates/tick. Dense cursors avoid whole-queue compaction or all-due drains.
The hot path does not serialize telemetry. Lower budgets reduce coverage instead
of growing frame workload. Gleba spores do not drive toxic pollution damage.
Query grants follow R,T,R,E,R,S,R,T,R,G,R,H for recovery, pending tiles,
pending entities, soil, trees and hazards, with at most five other class checks.
The chosen class receives its companion inspection allowance; an operation that
cannot fit remaining work defers intact to the next service's first grant.
Gaia's indivisible placement needs 27 candidates. No work credit accumulates.
Cold discovery does not query pollution. One existing sample per service refreshes
a separate cohort of min(64, floor(1024 / interval)) observations, minimum one.
Half its capacity is reserved for recovery when lineage exists. A gap above 1,200
ticks breaks continuity. Leases begin at first observation; mature tickets have a
bounded execution window, and recovery gets at most eight attempts per lease.
Ready-cohort cursors keep maturity reachable independently of large discovery and
history populations. Their bounded 64-slot probes are reported separately.
Long soil/tree/hazard deadlines belong to bounded active schedules, not sample
leases. Under capacity pressure old schedules drain their admitted family
opportunities before retirement; they do not continually renew long deadlines.
This may delay new chunk coverage. Neutral/unsupported pollution cannot imply
clean exposure. Disabled surfaces can retire discovery cache while accepted
requests and recovery lineage remain paused and retained.
Fire-token cleanup retains its bounded cadence even at faster presets.
The native preset lane and standalone mocked scheduling checks are described in
scripts/qc/terrain-evolution/README.md; the latter is not engine or timing evidence.

<a id="calendar"></a>
## Abstract orbital calendar

The reference year is 360 captured Nauvis days, scaled by final map distance ratio
to the power 1.5; orientation seeds phase. This is an ESIR abstraction.
Default tilt/latitude are 23.5/45 degrees. Period changes preserve phase.
Ecological rate calculations read the cached analytical phase directly, without
building presentation snapshots. Cached drills evaluate that rate only when
their deadline is due or rearmed, rather than during every membership check.
At most one due surface is visited per service with a 600-tick target per surface.
Only atomic daytime_parameters is owned. Twilight widths are preserved with
2 percent minimum full-day/full-night clamps. Rotation, brightness, solar
multipliers and travel routes remain untouched. Fulgora is never acquired,
written or restored. Known diurnal-dynamics ownership yields automatically;
unexpected tuple changes suspend control. Disablement restores matching owned
tuples only. TerrainEvolution/TerrainEvolution2 suspend overlapping ecology.

<a id="hazards"></a>
## Optional hazards

Thermal deaths admit scars without ignition. The owned contained flame cannot
spread and lasts at most 600 ticks; tokens cap ignitions at 16 and one/600 ticks.
Native-spreading wildfire is separate; engine propagation exceeds Lua budgets.
Optional hazards receive H grants, alternating with finite drill/site discovery
while that work is pending. Wildfire, cliffs, flooding and drought have independent
deadlines. A late visit performs one current opportunity. Disabled hazards do not
advance their cooldown.
Per-surface hazard epochs rearm changed mode/rate settings lazily, without a
whole-active-set reset or catch-up work. Legacy saves missing the derived hazard
count/exclusion caches rebuild once at the first game-available tick.
Wildfire rolls require industrial pollution at the upper threshold and select
an approved nearby native tree with one capped search. Ignition revalidates the
tree's surface and position. Its capped protection query excludes approved natural
trees/corpses/fish by name before querying, retaining paving, cultivated/unsupported
flora, infrastructure, resources, Auric claims and Gaia authored-site protection.
One ground flame is explicitly seeded. Contained retains native ground-flame
damage, without native tree-fire propagation; only Spreading invokes native forest
burning. Contained expiry reserves worst-case service/cleanup cadence to remove
the owned entity within ten seconds, including Custom intervals. Cleanup walks
the at-most-16 records in reverse so swap removal cannot skip expired flames.
Same-cadence settings changes preserve earlier service deadlines; cadence changes
retire owned contained flames. Global and per-surface disablement remove owned
contained flames; native descendants are never adopted or destroyed.
Counters distinguish wildfire opportunities, fuel candidates, missing fuel,
protection rejection and creation failure. Defaults remain 1% per eligible
opportunity and 600 base seconds: a 20-minute baseline under Restrained, varied by
default-on seasonal ecology, before coverage delays or turns shared with other hazards.
Shorelines use approved Nauvis freshwater pairs only. Paving corrosion, ordinary
cliff erosion, aging and rot default on but remain individually toggleable.
Aging replaces native Nauvis trees with native deadwood only. Other planets have
no approved deadwood replacement; native death payloads are never invoked as a
fallback. Entity effects obey natural-tile, hidden-layer and infrastructure
protection just as terrain writes do.

<a id="v2-reporting"></a>
## Ecology reports, personal alerts and finite maintenance

The current-view Ecology window uses mod_gui and a draggable screen frame.
Simple is an in-world field report; Advanced labels surface observations separately
from global allowances, queues and histories. Neither infers health from missing
observations. One viewer per 16 ticks receives at most eight native property writes,
including the seasonal title icon, visibility and strip geometry, targeting 60 ticks per viewer. A fair
binding cursor inspects at most 32 fixed widgets per opportunity. Initial population
uses ordinary 16-tick admissions and reserves two writes for reveal. Closed panels
perform no refresh or world reads. Surface generations invalidate hidden content;
Simple can populate without walking Advanced. Rapid A-B-A view changes retain
invalidation until a fresh generation is rendered.
A saved layout version is checked at first presentation or interaction without
requiring a gameplay migration or mod-version change. Layout version 3 added the
title icon and launcher toggle; version 4 added catalogue icons. Version 5 inserts
the personal icon-set selector into a compatible version-4 Alerts pane in place,
preserving the native scroll pane, active tab, location, preferences and launcher.
Older incompatible layouts use the existing per-viewer rebuild path. Initial
construction/adoption is not a second refresh service. Subsequent selector and
category-icon changes consume the existing eight-write viewer allowance; rapid
changes retain only the latest target and closed panels do no refresh work.

Simple uses six decorative Graphics 6 planetary banners, native planet icons and
the existing seasonal tree, with responsive paired/stacked activity cards. Artwork
is static place identity, never a visualization of measured terrain health.
`terrain-field-report` composes cached surface facts and a constant-count native
day-cycle observation only inside an admitted Simple refresh. The local strip uses
actual `daytime`, `ticks_per_day` and the four boundaries; the annual strip uses the
existing analytical calendar. No new simulation or daylight writer is added.
Frozen time suppresses forecasts; permanent daylight shows an all-light strip;
missing cycles hide the diagram. Fulgora's read-only `report_status` identifies the
specific surface managed by its independent rotation controller. The observer may
read Fulgora's native tuple; the seasonal controller still never reads/writes it.

Successful effects maintain one optional last-success tick per finite category.
Old totals remain, with no invented historical times or event logs. Pollution
capability is cached at surface preparation independently of observation age;
older entries without that field use a read-only native pollutant-type fallback.
Loaded approved tree-family availability is an O(1) snapshot fact. Counts mean
recorded changes, including repeated changes to one patch, not unique affected
areas or world health. All eight present locales cover the new report and its
Informatron explanation. The maximum window is 800x780 logical pixels, clamped
with 24-pixel margins; cards stack below 680 content pixels.
The top-left launcher is a saturated copper mechanical tree with four seasonal
enamel palettes: rising/spring lime, high/summer emerald, falling/autumn amber-red,
and low/winter cyan. It reads only the viewed surface's cached analytical phase,
including remote view and Fulgora, without acquiring daylight ownership. Missing
calendars use the steady summer sprite and an unavailable-season tooltip.
A separate event-maintained connected roster admits at most one launcher check
per 16 ticks, targeting 600 ticks per player. It changes native sprite/tooltip
fields only on season changes; closed report refresh remains entirely idle.
Existing text launchers are replaced in place during player/configuration lifecycle.
The per-player `launcher` preference defaults true only when absent. The toolbar
toggle below the title is available on every tab and displays its current state.
Hiding it destroys the button and removes its seasonal roster membership without
closing the report or creating mod-gui containers. Save/load, reconnect and
configuration changes preserve an explicit false. Feature disablement still
closes the window and removes the launcher without erasing the preference.
The title uses the same seasonal mapping at 48 GUI units. Its existing viewer
service checks the cached season even on Alerts and while the launcher is hidden,
charging only changed sprite writes to the eight-write allowance. No extra
scheduler or world observer is added.
The unbound `ei-toggle-ecology-menu` control opens/closes the report independently
of launcher visibility. `control.lua` forwards the original custom-input event
and tick. The control remains assignable with ecology disabled; runtime access
checks the startup gate before constructing any window or referencing gated art.
Closing releases the session's frame reference before clearing `player.opened`,
whose synchronous native close event may re-enter cleanup; the saved local handle
is then destroyed once. Rebuilding uses this same reentrant close path.
Administrator mutation remains in the existing gated console. Reading reports
does not instantiate planetary surfaces.

Runtime-per-user alert settings are canonical. The Alerts tab uses the same cache
and validation path as the native settings menu. Surface selection is all or a
JSON array of exact names (empty means none), capped at 128 names and 4,096 bytes.
Missing names match nothing; retained native surface identity supports bounded
rename reconciliation. The current-view filter is independent. Only administrators
may bypass visibility, and status is checked again at delivery and cleanup.
An open picker compares the cached canonical selection as well as the surface
catalog generation, so delayed rename reconciliation cannot leave stale rows.
Demotion resets the canonical override and the visible checkbox together.

Committed effects emit EffectReceipt records. Incidents coalesce per surface,
chunk and category for ten seconds. Each delivered incident owns one immutable,
invisible native helper shared across recipients, with reference-counted chunk
provenance. add_custom_alert supplies vanilla display and map targeting.
Current force visibility is required, rather than historical charting. Caps are
64 incidents, 32 helpers, four alerts per player. Each 32-tick opportunity permits
two recipient checks, one addition, one helper creation attempt and one cleanup action.
Incomplete recipient traversal restarts on connected-roster changes, with prior
deliveries deduplicated. Admission and connection epochs exclude later joins or
reconnects from old incidents; completed traversals never reopen.
Notification eligibility lasts 60 seconds; bounded cleanup may retire its helper
later. This deadline never expires terrain or mining work.
Cleanup targets only owned entities/custom alerts. Wildfire receipts establish
successful ignition creation, not subsequent forest loss.

terrain-ecology-work publishes at most four aggregate shared-scheduler reports:
migration, bootstrap, revalidation and maintenance. Generations retain their IDs,
cursors, fixed membership and scalar progress. Waiting-only generations stay out
of the public monitor; mixed paused/running membership suppresses ETA. Retired
publishers cannot reopen a generation. Ordinary recovery, drill polling and
background discovery do not keep the rebuild monitor open.
Each generation reuses one scalar report payload. Identical publications are
deduplicated between 60-tick heartbeats; changed progress, phase, state or limits
publish immediately. A live registry/ID is required before skipping, preserving
missing-registry adoption and stale-publisher rejection. This avoids repeated
allocation and revision changes when discovery and cleanup report the same batch.

V1 conversion inspects at most four records inside the existing history allowance;
one inspection every fourth service is reserved before query consumers so query
phase cannot starve conversion. Converted pending records enter the same E/T
class counters as new admissions; new records never join the migration denominator.
The four domain indexes use 256 deterministic hash buckets, with dense arrays
remaining authoritative. A registered metatable preserves direct ID lookup
across saves. Adoption replaces a flat index pointer in constant time and keeps
its old lookup table as a fallback; no new keys enter that large table. Existing
migration inspections convert at most one old lookup each. Normal updates or
removals can also retire a lookup, reconciled through four scalar remaining
counts. Reports count schema conversion and index conversion as separate finite
steps when both apply. Fire records are outside this denominator. Fixed bucket
count reduces measured churn costs without promising a worst-case bucket size.
Ready selection inspects at most eight observation slots per class and resumes
its saved cursor. Full-cohort ticket windows absorb the additional selection
latency; no ready search scans the entire cohort on every empty fallback.
Primary classes defer missing companion allowances, while borrowed fallback
classes cannot capture the rotation. A selected T/S operation retains a writable
opportunity even under a one-write preset. Final report progress is published
before retirement, including unknown-total and synchronous operations.
Bootstrap freezes surface membership and
ends traversal at exhaustion or 100,000 yielded visits per surface, then drains
already admitted drill/site work. The limit is not a map-size estimate. The same
iterator continues ordinary discovery after the finite generation closes.
Legacy Gaia saturation locks remain conservative. New protection uses up to 4,096
exact protected chunks globally and 16 overflow rectangles per Gaia surface,
merged by least additional area. Surviving artifact anchors are classified through
the shared query allowance; absent historical anchors cannot be reconstructed.

<a id="informatron-guide"></a>
## Detailed player guide

The existing [Informatron](../../../exotic-space-industries-remembrance/scripts/control/informatron.lua)
`terrain_evolution` page remains a clickable overview
under World related. Five nested pages (`ecology_ground`, `ecology_woodland`,
`ecology_hazards`, `ecology_seasons`, `ecology_controls`) explain each feature's
trigger, timing, planetary scope, protections, recovery limits and common reasons
for inactivity. All seven locales own matching `ecology-informatron.cfg` entries.
The section order is declared in Informatron; paragraphs and headings stay localized.
All 36 sections use a practical engineer-ecologist voice: observable effects and
plain explanations first, then bold default-setting and practical-limit labels
where relevant. The seven locales retain 82 keys each and established setting
names. Exact timings describe processing opportunities, not per-tile promises;
software limits are explained honestly rather than disguised as natural laws.

Informatron owns scrolling and navigation. Sections build only when explicitly
opened, using wrapped labels. Child pages do not query the world. The overview
ends with the existing effective-status line, read from `public_snapshot` for the
viewed surface and explicitly reports startup disablement. Opening documentation
does not mutate ecology state, create planetary surfaces, or schedule refreshes.
The guide distinguishes shipped defaults from preserved save settings and base
intervals from guaranteed effect timing. Gameplay remains with the terrain owner.

<a id="verification"></a>
## Verification

scripts/invoke-terrain-evolution-qc.ps1 stages source/fixtures in ignored storage.
The elapsed wildfire fixture exercises public autonomous scheduling with soil
enabled, dense/sparse forests, native propagation identities, contained expiry,
query caps, disabled/probability/pollution gates, protections and legacy cache repair.
Source checks, engine mechanics, connected-player GUI, persistence and timing
are distinct evidence. Operation caps do not prove millisecond or UPS targets.
See scripts/qc/terrain-evolution/README.md for current commands and evidence.

Dense cursor sets deliberately remain local: shared FIFO helpers compact or drain
in ways that do not preserve the constant-time removal and cyclic-history contract.
No new scheduler, telemetry channel, or runtime timing controller is registered.

## Shared alert ownership

`terrain-alerts.lua` owns ecology preferences, interested-player admission,
visibility policy and terrain receipt callbacks. The
[shared native alert owner](runtime-alerts.md#contract) owns records, recipients,
markers, deadlines, deduplication and native calls. Versioned adoption preserves
old records and retained receipts by identity. The caps and cadence above remain
independent of operational service.

Native per-player settings are authoritative. The Alerts tab's icon-set selector
edits `ei-alert-icon-set`, the same choice exposed in Mod settings, through the
shared setting-change path. It applies to all ESIR alerts. Category captions use
that player's Original, SVG, Rendered, or registered provider set; the startup
default initializes a personal choice without overriding a later explicit choice.
The shared art module owns available-set validation and provider fallback, not the
ecology policy adapter. GUI selection tags validate player/frame identity and
selection bounds before writing the personal setting.

Changing art neither re-admits incidents nor re-retains terrain receipts. Shared
records remember each recipient's actual signal/message for exact cleanup and
provider-removal recovery. A cosmetic refresh replaces only a native alert still
visible; dismissed once-only ecology incidents remain absent. Ordinary deliveries
have priority over replacement within the same one-addition allowance, and style
changes do not alter the 60-second eligibility deadline or completed audience.
Presentation migration has its own version and does not repeat terrain delivery
adoption. Layout version 5 and its bounded caption projection are described above.
