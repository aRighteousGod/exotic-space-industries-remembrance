<a id="contract"></a>
# Unified ESIR native alerts

## Implementation sources

- [alerts.lua](../../../exotic-space-industries-remembrance/lib/alerts.lua)
- [alert-catalog.lua](../../../exotic-space-industries-remembrance/lib/alert-catalog.lua)
- [alert-icon-sets.lua](../../../exotic-space-industries-remembrance/lib/alert-icon-sets.lua)
- [alerts.lua prototypes](../../../exotic-space-industries-remembrance/prototypes/alerts.lua)

The stage-safe catalogue owns stable IDs, explicit defaults, icon signals, localized
settings and display order. Settings generation creates a visible personal boolean
for every type. Prototypes create hidden signals and a common invisible position
marker. Four built-in sets provide 108 PNGs in Graphics 6 under
`graphics/gui/alerts/`: Original at the root, SVG under `svg/`, Rendered under
`rendered/`, and Vanilla under `vanilla/`. Original files and signal identities remain compatible.

`storage.ei.alerts.channels` owns records, dense indexes, source indexes, recipients,
connection epochs, markers and delivery counters. Native calls exist only in the
shared handler. Registered callbacks remain module-local and are never serialized.
Feature owners decide whether gameplay warrants a condition or incident; the handler
enforces preferences, force/connection scope and exact native cleanup.

## Icon registration and personal selection

`alert-icon-sets.lua` owns `setting_definitions()`, `builtin_prototypes()`, and the
public `register_settings(manifest)` / `register_data(manifest)` interface. Provider
mods depend on ESIR and call both functions in their respective `settings.lua` and
`data.lua`, requiring the same pure-data API-version-1 manifest in each stage.
The stable set ID is `<provider>__<local-id>`. Settings registration extends the
startup and personal selectors; data registration creates the complete signal
family. A single sized PNG or explicitly sized `icons` layers can override existing
alert IDs; omitted/future IDs copy a built-in fallback (Rendered by default).
Duplicate IDs, unknown alerts, invalid fields and executable/cyclic manifests are
rejected before prototype mutation. Provider choice names and descriptions belong
to both selectors' standard locale keys; source/license provenance stays with art.

Runtime discovery intersects the personal selector's allowed values with complete
signal families. Built-ins keep Original/SVG/Rendered/Vanilla order; provider IDs sort.
There is no runtime remote registration, persisted callback registry, or cross-stage
Lua-global transport. The canonical development reference provides a full example.

`ei-alert-icon-set-default` is startup-only and defaults to Rendered. Personal
`ei-alert-icon-set` starts at `startup-default`; a game-available lifecycle boundary
normalizes it to a concrete available set. Existing explicit selections survive
later startup changes. Selecting the sentinel again copies the current default.
Only this setting's `settings.player_default` entry is reset to the sentinel for
future players; other map defaults and current players are preserved. A removed
choice resolves to the valid startup default, then Rendered. Ecology's dropdown
and native Mod settings use this same personal setting and shared change path.
Nil-player icon-setting events normalize map defaults without touching current
personal choices or audience epochs; player-entry hooks also maintain the sentinel.

The retained asset sources distinguish editable SVG from actual raster originals.
Named generation requires `--set svg|rendered|vanilla` and ignored staging. Hash-verified
promotion targets only that set; Original cannot be regenerated or overwritten
through this exporter. Exact imagegen prompts/corrections are provenance, not a
claim of deterministic regeneration or Blender/model-render authorship.

## Lifetime and dispatcher

`control.lua` forwards initialization/configuration, player/setting, force and surface
lifecycle and invokes bounded service only when a channel has due work. Operational
service has 32 work steps per tick, with a 120-tick renewal target. Persistent gate
conditions use the container as target. Destructive incidents capture force, surface,
position and message before deletion and last 3,600 ticks. Coalescing is force/surface/
chunk/type, retains the first map position, counts reports and refreshes expiry.
Late joins, reconnects and enabling types cannot replay incidents. Current conditions
can be delivered again. Source muting clears native recipients immediately; automatic
expiry and preference removal use the channel cleanup budget.

Ecology's adapter owns preference parsing, visibility/surface rules and terrain
receipt callbacks. It retains independent 64/32/4 caps and 32-tick 2-check/1-add/
1-create/1-cleanup limits. A receipt coalesces only within 600 ticks and a valid
owner/generation; its 3,600-tick deadline is an eligibility deadline. Completed
traversals do not reopen. Release occurs exactly once at final retirement.

## Presentation refresh and exact cleanup

Records retain `recipient_icons`, copied `recipient_messages`, and per-recipient
`presentation_checked` selections. Normal delivery records the signal actually
used. Cleanup selects the saved signal even after a player changes style. If a
provider signal is absent after configuration change, the handler inspects native
alerts for the owned target/surface, finds the saved localized message, and removes
that exact native message without passing an invalid icon or clearing unrelated
custom alerts.

The existing cleanup cursor discovers at most one cosmetic candidate per service.
Ordinary delivery/renewal consumes native additions first; only remaining channel
allowance can replace a still-visible native alert. Replacement preserves its
actual native message and does not renew logical incident deadlines or reset
audiences, delivery ticks, coalescing, or terrain references. A dismissed/expired
once-only ecology notification stays absent. Presentation counters are separate
from deliveries; operational and ecology caps/cadences remain independent and
unchanged. No second scanner, queue, or scheduler is added for style changes.

<a id="migration"></a>
## Save migration

Version 1 adopts the old `storage.ei.ecology_alerts` delivery arrays and objects
without cloning or retaining again. Preferences remain aliased to the adapter's
player records. IDs, epochs, deadlines, counters and anchors survive; migration
marks completion and is idempotent. Legacy boolean delivered entries select the
old icon for exact removal; the legacy ecology anchor prototype remains available.
The separate `presentation_version=1` records art migration without increasing the
delivery-adoption version or re-adopting aliased terrain state. Existing unified
recipients lacking presentation fields are interpreted as Original; they acquire
actual signal/message fields through bounded refresh or new delivery. Receipt
ownership, deadlines, counters, IDs and retained anchors survive unchanged.

## Verification

The [canonical development reference](../../skills/esir-dev/references/runtime-alerts.md)
defines extension rules and commands. Static catalogue/asset/localization checks,
mocked boundary fixtures, native runtime/save evidence, rendered icon/UI inspection
and multiplayer acceptance are separate claims. Dense cyclic record sets are local
because FIFO compaction does not provide their stable cursor/removal behavior;
general diagnostics use the shared scheduler and entity safety uses `ei_lib`.
The icon-set/presentation fixtures additionally cover personal isolation, sentinel
and future-map-default normalization, partial/future-type provider fallback,
provider removal/re-addition, message-scoped cleanup, dismissed once-only alerts,
and first-delivery priority under the existing channel budgets. The asset audit
checks all 108 built-in signals/PNGs and actual source/provenance hashes.
