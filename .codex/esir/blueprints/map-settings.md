<a id="contract"></a>
# Native map settings and future-planet overrides

## Implementation sources

- [map-settings-config.lua](../../../exotic-space-industries-remembrance/lib/map-settings-config.lua)
- [map-settings.lua owner](../../../exotic-space-industries-remembrance/scripts/control/map-settings.lua)
- [map-settings.lua editor](../../../exotic-space-industries-remembrance/scripts/control/admin/map-settings.lua)

The owner writes native settings through a typed allowlist. The administration
adapter owns drafts and delegates authorized Apply through the existing coordinator,
feedback and audit path. Opening or navigating the page never creates surfaces or
changes world settings. The administration startup gate defaults On;
saved world configuration and enemy policy operate independently of that gate.

<a id="settings"></a>
## Settings and writes

Selected surface/planet covers visible applicable autoplace controls, starting
area, seed, native peaceful/no-enemies flags, the ESIR new-base policy and current
enemy evolution. Global rules cover evolution, expansion, pollution, asteroid
spawning and native spoil/research multipliers. Advanced hides seed/research price
until requested. Bound cliff controls use native frequency/size; unbound configured
cliffs expose elevation interval and continuity. Aquilo gains no artificial cliffs.
Terrain frequency is displayed as inverse scale; evolution uses percent and
expansion cooldowns game minutes. Resource/terrain checkbox availability is native.

Draft validation requires finite typed values, supported bounds, integer fields,
ordered expansion minimum/maximum pairs, and native generation values zero or
1/6 through 6. Untouched imported values are never clamped. Apply checks only
edited fields against their baseline, then merges into freshly read native records,
preserving unrelated expressions, allowlists and settings. Evolution uses an owner
revision because natural evolution is not another administrator's edit. Native
writes are guarded; rejected writes restore previously written fields. Feedback
and the audit log include read-back values. Existing world shortcuts use this owner.

Population zero/Off remembers positive frequency and size independently; On
restores them, including across recreation. Unknown values use planet defaults,
including Gaia size 5. No setting action clears entities, pollution or chunks.
Explicit clearing and regeneration remain separate existing administration actions.

<a id="lifecycle"></a>
## State, creation and persistence

`storage.ei.map_settings.overrides` holds sparse typed fields and revisions keyed
by `planet:<identity>` or a custom surface index. `enabled` remembers positive
autoplace tuples. Surface evolution revisions are transient per-surface ownership;
planet overrides survive deletion. Legacy administration policies migrate once
without overwriting explicit new settings. A missing override inherits native data.

An uncreated planet presents prototype values as references, never as the
unreadable player-selected native creation settings. Explicit Override controls
allow choosing even a value equal to that reference. Creation merges only saved
fields into the actual native settings in `on_surface_created`, before chunk
generation. Gaia fallback/reforge also call `prepare_creation` before staging;
the surface-ready callback reapplies the latest revision after association.
Configuration changes replay saved policies independently of the editor gate.

The central dispatcher owns surface events and new-base events. The owner has no
tick service or world scan. Policy changes notify the enemy owner to service its
bounded owned-raft restoration queue. See [enemy lifecycle](planet-enemies.md#births).

<a id="editor"></a>
## Draft and target lifecycle

Per-administrator drafts live in the existing administration session, keyed by
stable target identity. Apply revalidates access and target identity. Refresh,
navigation and other administrators' changes preserve drafts. Reload and Discard
explicitly replace the selected draft with current values. Same-field conflicts
retain unsubmitted work; unrelated concurrent changes survive Apply.

Pending-to-created transitions rebuild the applicable fields while retaining
unapplied intent and conflict checks. A draft for a deleted live surface cannot
silently target its replacement; it requires explicit Reload. Page controls retain
their identity during ordinary refresh. Slider/text and Override state agree.
Space platforms, raw expressions, territory internals, map dimensions, starting
points, planet properties and pathfinder tuning are intentionally absent.

<a id="verification"></a>
## Verification boundaries

The v2 fixtures under `scripts/qc/planet-enemies` exercise production owners and
native GUI elements in Factorio 2.0.77. Data, generation, callback, persistence,
native rendered UI and multiplayer evidence must be reported separately. Simulated
GUI dispatcher events do not establish mouse/focus behavior or two-client safety.
The EditMapSettings 0.1.6 `ems` branch informed field coverage; its clearing behavior
and source implementation are not imported.
