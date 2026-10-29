# Shared ESIR native alerts

Use `exotic-space-industries-remembrance/lib/alerts.lua` for automatic operational
warnings and ecology notifications. It is the sole production owner of native
`add_alert`, `add_custom_alert`, and `remove_alert`. Destination confirmations,
instructions, research/Informatron notices, command replies, diagnostics and
floating text retain their chosen text presentation. `ei_lib.notify_connected_players`
is a text helper, not an alternative automatic-alert delivery path.

## Catalogue and settings

Add each stable ID to `lib/alert-catalog.lua` with its channel, unique setting name,
explicit boolean default, hidden virtual signal, localized name/description and
display order. The settings stage generates a **visible runtime-per-user bool-setting
for every entry**, including future additions. Never hand-maintain a second list of
type toggles. Reuse existing keys when migrating; saved false values are authoritative.
Missing settings, undeclared IDs and incomplete definitions must fail closed.

The 27 current entries have 108 transparent 128×128 PNGs across Original, SVG,
Rendered and Vanilla. They ship in **Graphics 6** under `graphics/gui/alerts/`: Original remains
at `<id>.png`, with the others at `svg/<id>.png`, `rendered/<id>.png` and `vanilla/<id>.png`, referenced
through `__exotic-space-industries-remembrance-graphics-6__/graphics/gui/alerts/`.
Original PNGs and flat SVG masters remain unchanged.
The [generator guide](../../../esir/asset-generators/alert-icons/README.md) requires
`--set svg|rendered|vanilla` and ignored `--staging-dir`; only explicit `--ship` promotes a
complete hash-verified named set. Original cannot be an export target. Preserve
actual SVG masters, rendered raster originals, exact prompts, corrections and
provenance separately; imagegen artwork is not a Blender render or an SVG master.

Delivery requires connection, owning force where applicable, the category-wide
switch, the alert-type switch, and the feature's source switch. A source switch
cannot override a player's Off preference. Ecology additionally owns visibility,
surface selection and administrator override rules. GUI controls write the native
per-player settings and invoke the same setting-change path; no shadow preference
can overrule native settings. Turning Off blocks admission/renewal immediately and
removes existing alerts through bounded cleanup. Turning On restores persistent
conditions; missed incidents are not replayed.

## Personal artwork and provider API

`lib/alert-icon-sets.lua` owns the stage-safe art interface. The startup selector
`ei-alert-icon-set-default` defaults to `rendered`. Personal `ei-alert-icon-set`
defaults to the sentinel `startup-default`. Initialization/join resolves that sentinel
to the current available startup choice and saves a concrete personal ID. Later
startup changes preserve existing personal choices. Choosing "Use startup default"
again copies the current default; it is not a continuing inheritance mode.
Initialization resets only `settings.player_default["ei-alert-icon-set"]` to the
sentinel so future players can resolve the current startup choice; unrelated map
defaults and existing players are preserved. An unavailable selection resolves to
the available startup choice, then Rendered. No icon choice changes permission.
Future-player default changes arrive as runtime-per-user setting events without
`player_index`; the shared handler restores its sentinel in that path too. Do not
return early solely because an icon-setting event has no current player.

Mod settings and the Ecology Alerts dropdown edit the same personal setting.
The dropdown affects all ESIR alerts, and category checkbox icons use the selected
set. GUI writes call `alerts.set_icon_set(player, id, tick)` and the shared setting
change path; callers retain explicit event ticks. Built-in IDs are `original`,
`svg`, `rendered`, `vanilla`; provider IDs are `provider .. "__" .. id`. Original signal names
remain `ei-alert-<alert-id>`; other sets use `ei-alert-set-<set-id>__<alert-id>`.

Companion mods declare a dependency on ESIR and pass one pure manifest to both
stage-specific registration functions. Register in `settings.lua` and `data.lua`
after ESIR's corresponding stage files; never attempt runtime registration or a
remote API. ESIR must not acquire a reverse dependency on its art providers.

```lua
-- alert-icons.lua in recipe-icons-improvement-for-esir
return {
    api_version=1,
    provider="recipe-icons-improvement-for-esir",
    id="industrial", -- local ID: lowercase letters, digits and hyphens
    fallback="rendered", -- optional; defaults to rendered; any built-in is valid
    icons={
        ["gate-low-power"]={
            icon="__recipe-icons-improvement-for-esir__/graphics/alerts/gate-low-power.png",
            icon_size=128,
        },
        ["ecology-wildfire"]={icons={
            {icon="__recipe-icons-improvement-for-esir__/graphics/alerts/tree.png",icon_size=128},
            {icon="__recipe-icons-improvement-for-esir__/graphics/alerts/fire.png",icon_size=128,scale=0.5},
        }},
    },
}
```

In the provider's `settings.lua`:

```lua
local api=require("__exotic-space-industries-remembrance__/lib/alert-icon-sets")
api.register_settings(require("alert-icons"))
```

In its `data.lua`, require the same data-only manifest in the new stage:

```lua
local api=require("__exotic-space-industries-remembrance__/lib/alert-icon-sets")
api.register_data(require("alert-icons"))
```

`register_settings` extends both selectors without changing their defaults. Built-ins
keep their order; provider IDs sort deterministically. `register_data` creates one
hidden signal for every catalogue entry, using the chosen built-in fallback for
omitted entries, including types added by later ESIR versions. It accepts a single
PNG with explicit `icon_size`, or an `icons` array with explicit sizes on every
layer; the forms cannot be mixed. Layer options are `scale`, `shift`, `tint`,
`draw_background` and `floating`. Reject unknown alert IDs, duplicate registrations,
invalid fields/values, unsupported API versions, callbacks, cycles and metatables.
The interface adds artwork, not new alert types or permission switches.

Provide English choice names and descriptions for **both** selector keys in the
provider's locale; other accepted translations use those same stable keys:

```ini
[string-mod-setting]
ei-alert-icon-set-recipe-icons-improvement-for-esir__industrial=Industrial icons
ei-alert-icon-set-default-recipe-icons-improvement-for-esir__industrial=Industrial icons
[string-mod-setting-description]
ei-alert-icon-set-recipe-icons-improvement-for-esir__industrial=Industrial alert artwork. Unchanged types use Rendered objects.
ei-alert-icon-set-default-recipe-icons-improvement-for-esir__industrial=Initial artwork for players without a saved choice. Unchanged types use Rendered objects.
```

Providers retain source/license attribution and asset provenance with their art.
Runtime `refresh_runtime()` admits only choices present in the setting prototype
with a complete signal family; `available_sets()` and `choice_caption()` serve
the GUI, while `player_set()`, `normalize_player()` and `normalize_map_default()`
resolve native settings. Stage globals are not runtime registration storage.

## Feature examples

```lua
local alerts = require("lib/alerts")
-- Stable condition identity; the feature owns effective power/circuit policy.
alerts.set_condition("operational", gate.unit_number, "gate-low-power",
    enabled and alerts_enabled and gate.energy < 100e9,
    {entity=container, source_id=gate.unit_number, message={"ei-alerts.gate-low-power",
        gate.surface.name, gate.position.x, gate.position.y}}, event.tick)

-- Capture before destruction; the handler owns the surviving position marker.
alerts.record_incident("operational", "matter-cascade",
    {entity=machine, message={"existing-localized-warning"}}, event.tick)
machine.destroy()

-- Ecology calls its adapter, which keeps interested-player admission cheap.
terrain_alerts.record_effect{category="wildfire", surface=surface, position=position,
    owner=surface_record, generation=generation, count=1, tick=event.tick}
```

Channels register policies and hooks during module loading, never in persistent
state. Hooks retain feature-owned semantics: eligibility, receipt validity,
retain/release and message composition. `control.lua` remains the only event/tick
dispatcher. Pass explicit ticks through callbacks, including valid tick zero;
do not read `game.tick` inside ordinary helpers or `on_load`. Add no remote API.

## Lifetime, budgets and migration

Operational service spends at most 32 record/recipient steps per tick and targets
120-tick renewal. Conditions persist until their owner clears them; finite incidents
last 3,600 ticks and coalesce by force/surface/chunk/type, retaining the first location,
incrementing the count and extending expiry. A new report refreshes its eligible
audience; reconnecting or enabling a preference alone never replays incident history.
Reconnects get current conditions. Clear removed/muted sources with `clear_source`; gate muting
removes its visible alert immediately. Normal expiry, setting and lifecycle cleanup
remains bounded. Each recipient stores the actual delivered signal and a copied
localized message. Exact removal uses the owned entity and saved icon, never the
player's newly selected style. If a provider disappears and that signal prototype
no longer exists, inspect native alerts scoped to the owned entity/surface and
match the saved message; remove the actual native message without passing an
invalid signal or broadly clearing unrelated custom alerts.

Ecology has independent budgets: 64 records, 32 markers, four per player; every
32 ticks, two recipient checks, one native addition, one creation attempt and one
cleanup action. It coalesces for 600 ticks with owner/generation validity, delivers
once, and has a 3,600-tick eligibility deadline. Receipt references survive until
retirement, not merely until delivery. Shared scheduler diagnostics and existing
entity-safety helpers are reused; dense cyclic indexes are specific alert state,
not a duplicate FIFO/telemetry system.

Changing artwork is bounded presentation maintenance, not a new incident. The
existing cleanup traversal discovers a candidate; ordinary delivery/renewal gets
the channel's native-add allowance first. A remaining allowance may replace only
an alert still present in native state, preserving its native message. An already
dismissed or expired once-only ecology alert stays absent. Do not reset delivery
epochs, receipt ownership, deadlines, coalescing or historical audiences for style
changes. Presentation updates have their own counter and remain inside the same
operational/ecology budgets; no additional scanner or scheduler is introduced.

Migration is versioned and idempotent. Move existing records, counters, preferences,
epochs, anchors and indexes by identity; never re-retain a migrated receipt.
Preserve deadlines and delivered audiences. The old ecology anchor prototype stays
for save compatibility. `presentation_version` is independent of completed legacy
ecology adoption (`VERSION=1`); do not bump delivery adoption or re-adopt its aliased
records to migrate art. Old recipients without presentation fields resolve to
Original, or their pre-unification legacy icon, until bounded refresh/cleanup.
New deliveries capture the selected per-recipient signal/message. New positional
incidents use the common invisible marker.

## Verification

Run `python -B scripts/qc/alerts/audit.py`, the Lua fixtures in
`scripts/qc/alerts/runtime.lua`, `scripts/qc/alerts/icon-sets.lua`,
`scripts/qc/alerts/icon-presentation.lua` and `scripts/qc/terrain-evolution/v2-alerts.lua`,
then the native fixture documented in `scripts/qc/alerts/README.md`.
The audit enforces catalogue/settings/icon/locale completeness, unique settings,
declared emitter IDs and sole native-call ownership. Fixtures must cover all toggles,
false/missing values, masters, pending/visible changes, player/force isolation,
reconnects, budgets, expiry, invalidation, migration and future catalogue additions.
Also cover two different personal sets, startup/sentinel normalization and future
map defaults, partial providers, future-type fallback, provider removal/re-addition,
actual-icon cleanup, dismissal without replay and ordinary-delivery priority.
Run relevant wrapper preflight, qc-runtime, qc-assets and blueprint/skill validation.
Report mocked Lua, native engine/save, rendered UI and multiplayer evidence separately.
