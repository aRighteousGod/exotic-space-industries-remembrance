<a id="contract"></a>
# Planetary terrain evolution

## Implementation sources

- [terrain-policy.lua](../../../exotic-space-industries-remembrance/lib/terrain-policy.lua)
- [terrain-evolution-config.lua](../../../exotic-space-industries-remembrance/lib/terrain-evolution-config.lua)
- [terrain-evolution.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-evolution.lua)
- [terrain-calendar.lua](../../../exotic-space-industries-remembrance/scripts/control/terrain-calendar.lua)
- [terrain-evolution prototypes](../../../exotic-space-industries-remembrance/prototypes/terrain-evolution.lua)

## Ownership and reference flow

Native ESIR implementation informed by TerrainEvolution by Cheshirrski and
TerrainEvolution2 by MeteorSwarm/Nicholas Gower. No upstream runtime code is copied.
Mining scars transition data retains its original Mylon attribution.

Startup defaults on; restrained intensity, lean budget and seasonal daylight are
the shipping presets. Hazard switches remain independently off. Settings resolve
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
finite transition path. Permanent mining supersedes ecological history; optional
mining recovery rebases at the pre-mining tile. External writes invalidate history,
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
The prior measured Lean used 8 histories every 32 ticks; current timing is deferred.
No cap reduction discards committed history.
Ingress admits 16 descriptors/tick; mining separately permits one local query with
32 candidates/tick. Dense cursors avoid whole-queue compaction or all-due drains.
The hot path does not serialize telemetry. Lower budgets reduce coverage instead
of growing frame workload. Gleba spores do not drive toxic pollution damage.
Cold discovery samples only new entries so small maps cannot starve active work.
Cached samples remain eligible between refreshes. Query priority advances on
query grants, independent of service passes. Active tree/terrain cursors and
pending entity/tile cursors advance on their own eligible work opportunities;
intervening polling/validation cannot alias against a short query cadence.
Tile-history validation has its own cursor when queries are unavailable. Recovery
does not advance past the last available query; contested single-slot tile/tree
history turns alternate when both domains have actionable work. Fire-token cleanup
retains its bounded 32-tick cadence even at faster service presets.
The native preset lane and standalone mocked scheduling checks are described in
scripts/qc/terrain-evolution/README.md; the latter is not engine or timing evidence.

<a id="calendar"></a>
## Abstract orbital calendar

The reference year is 360 captured Nauvis days, scaled by final map distance ratio
to the power 1.5; orientation seeds phase. This is an ESIR abstraction.
Default tilt/latitude are 23.5/45 degrees. Period changes preserve phase.
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
Shorelines use approved Nauvis freshwater pairs only. Paving corrosion, ordinary
cliff erosion, aging and rot require explicit enablement.
Aging replaces native Nauvis trees with native deadwood only. Other planets have
no approved deadwood replacement; native death payloads are never invoked as a
fallback. Entity effects obey natural-tile, hidden-layer and infrastructure
protection just as terrain writes do.

<a id="verification"></a>
## Verification

scripts/invoke-terrain-evolution-qc.ps1 stages source/fixtures in ignored storage.
Source checks, engine mechanics, connected-player GUI, persistence and timing
are distinct evidence. Operation caps do not prove millisecond or UPS targets.
See scripts/qc/terrain-evolution/README.md for current commands and evidence.

Dense cursor sets deliberately remain local: shared FIFO helpers compact or drain
in ways that do not preserve the constant-time removal and cyclic-history contract.
No new scheduler, telemetry channel, or runtime timing controller is registered.
