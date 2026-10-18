<a id="contract"></a>
# Auric inoculation vat basin lifecycle

## Implementation sources

The pure is_terrain_claimed(surface_index,x,y) probe exposes existing basin
claims to the ecology guard without creating state or changing vat lifecycle.

- [auric-inoculation-vat.lua](../../../exotic-space-industries-remembrance/scripts/control/auric-inoculation-vat.lua)
- [Auric vat prototypes](../../../exotic-space-industries-remembrance/prototypes/planet-gleba/auric-inoculation-vat.lua)
- [Auric cysts and washing](../../../exotic-space-industries-remembrance/prototypes/planet-gleba/auric-cysts.lua)

## Ownership and reference flow

`storage.ei.auric_inoculation_vat` owns vat records, per-surface indices, tile claims, telemetry proxies and destruction registrations, authoritative due times, ready work, GUI deadlines, and placement-guide caches. Basin eligibility and phase transitions share one record.

```mermaid
flowchart LR
  A["Vat or tile lifecycle"] --> B["Claim and basin reconciliation"]
  B --> C["Authoritative due time"]
  C --> D["Bounded ready-vat service"]
  D --> E["Phase, basin effects, and telemetry"]
  E --> F["Reschedule vat and dirty UI"]
```

<a id="tick-flow"></a>
## Tick flow and invariants

The top-level dispatcher supplies one event and budget to `updater`; the module chooses simulation/UI work. `now_tick` keeps event/numeric ticks authoritative with a utility fallback. Delayed bucket entries are hints: `due_tick_by_unit` determines whether a popped record is truly due. Attempted work, including stale entries, consumes the bounded loop allowance. Keep vat deadlines separate from per-player UI deadlines.

<a id="lifecycle"></a>
## Lifecycle and cleanup

Phases, including enriched fermentation, drainage, bloom, and rest, reconcile actual machine state before advancing. Tile changes refresh relevant claims and placement regions. Entity/object destruction removes claims, proxies, pending work, and sessions; surface deletion also tears down guides and surface ownership. Cursor, position, surface, alt-mode, and player-leave events maintain placement rendering without a broad player scan. Rebuild repairs world-derived ownership and orphan telemetry proxies.

Drain checks resolve each live fluidbox with `LuaFluidBox.get_prototype(index)`,
including merged prototype lists. Recipe-active indices do not necessarily match
the full entity prototype array; runoff must clear before advancing to bloom.

<a id="field-production"></a>
## Field production

Bands b1-b7 produce 2/2/4/4/6/8/10 nodes per successful ordinary bloom, with two
additional nodes for bioflux enrichment. Standing capacities are 6/8/12/16/20/24/28.
The shared per-bloom ceiling is 12; remaining capacity and valid placement can reduce
actual output. Each node still yields two cysts. Phase costs, durations and biological
failure thresholds are independent of this output increase.

Snapshot expected yield comes from current band definitions, not the historical
`record.expected_yield` cache. Existing records, claims, nodes and phase progress need
no reset or schema migration; subsequent blooms use the current definitions.

<a id="washing-productivity"></a>
## Washing productivity

`ei-productivity-auric-cyst-washing` follows Auric marsh inoculation and Agricultural
science pack, uses the six Gleba science packs, and grants native +0.1 recipe
productivity per level. Its infinite levels use the authored formula
`100 * (1 + 0.15 * L)` at 20 seconds per unit; global tech scaling overrides cost
normally. No scripted research receiver or persistent research cache is involved.

The wash accepts productivity modules and caps combined productivity at 3 (+300%).
Only gold receives bonus output: spoilage excludes 3 and dirty water excludes 25
units from bonus crafts. Base ingredients, output ranges, pressure and temperature
constraints remain authoritative. Levels beyond the shared cap remain researchable
but do not increase yield, and modules reach the cap sooner.

<a id="verification"></a>
## Verification contract

Exercise competing basin claims, tile replacement during phases, blocked drainage, enriched-cycle completion, stale delayed entries, bounded activation under load, independently destroyed proxies, reload, and surface/player cleanup. Check both state and rendering ownership; structural blueprint checks do not validate phase correctness.

The focused Gleba auric fixture checks all seven ordinary/enriched yields, saturation,
failed/blocked blooms, stale yield display, existing-save preservation, native washing
with research/modules at and beyond the cap, both cost-scaling modes and a real reload.
