# ESIR conceptual blueprint index

These models describe current source ownership and system contracts. Read the
owner model and its implementation before making a substantive change, then
update code commentary and the model together. The
[conceptual blueprint skill](../../skills/esir-conceptual-blueprints/SKILL.md)
defines maintenance and link conventions. The
[scheduler tick-source guidance](../../skills/esir-dev/references/runtime-scheduler-guidelines.md#tick-source)
is the canonical timing policy; models separately record current deviations.

The initial published backfill was reviewed against committed source on 2026-09-28.
Pending feature models remain with their corresponding implementation changes. It accounts for
the live source dependency graph, migrations, nested control modules, shared
runtime-used helpers, and the deliberately inert vendored Tesla entry point.
Dependency discovery includes conditional imports conservatively; it is not
proof that every branch executes. The preflight audit derives current coverage
from source and does not trust generated manifests or installed mod selection.

## Models

| Model | Owned source files |
| --- | ---: |
| [Auric inoculation vat basin lifecycle](auric-inoculation-vat.md#contract) | 1 |
| [Balanced agricultural growth jitter](randomized-tree-growth.md#contract) | 1 |
| [Beacon overload topology and native diminishing-return profiles](beacon-overload.md#contract) | 2 |
| [Black hole containment and extraction](black-hole.md#contract) | 1 |
| [Camp-fire registration and periodic fire emission](camp-fire.md#contract) | 1 |
| [Combustion turbine shell switching](combustion-turbine.md#contract) | 1 |
| [Crystal accumulator resonance](crystal-accumulator.md#contract) | 1 |
| [EM train charging and research rollout](em-trains.md#contract) | 3 |
| [Emerald Apocalypse charge, doctrine, motion, and orbital shards](emerald-apocalypse.md#contract) | 4 |
| [Flamethrower fuel variants and replacement transactions](flamethrower-fuel-adaptation.md#contract) | 2 |
| [Fluid safety, flammable death, and staged rupture effects](fluid-safety-and-ruptures.md#contract) | 5 |
| [Fueler tower servicing](fueler.md#contract) | 2 |
| [Fulgora day-length variation](fulgora-day-length.md#contract) | 1 |
| [Fusion reactor control and telemetry](fusion-reactor.md#contract) | 1 |
| [Gaia surfaces, alien presets, and artifact progression](gaia-and-alien-systems.md#contract) | 8 |
| [Gaian saucer wake registration and bounded visual emission](gaian-saucer-wake.md#contract) | 2 |
| [Gate transport and receiver selection](gate.md#contract) | 1 |
| [Hemocrystal wall event-started regeneration](hemocrystal-wall.md#contract) | 1 |
| [Impact firefighting and powered water-turret service](firefighting-and-water-turret.md#contract) | 3 |
| [Induction matrix topology and power](induction-matrix.md#contract) | 1 |
| [Matter stabilizer containment](matter-stabilizer.md#contract) | 1 |
| [Mining scar event path](mining-scars.md#contract) | 1 |
| [Nauvis pressure grace and difficulty policy](nauvis-pressure-grace.md#contract) | 2 |
| [Neutron collector source binding](neutron-collector.md#contract) | 1 |
| [Orbital logistics cohorts and leases](orbital-logistics.md#contract) | 1 |
| [Orbital scanner banks and demand caches](orbital-combinator.md#contract) | 1 |
| [Railgun coolant proxies, heat debt, and recovery](railgun-cooling.md#contract) | 2 |
| [Research scaling, progression migrations, and victory](research-and-progression.md#contract) | 7 |
| [Rocket launch consequences and visual scheduling](rocket-launch-pollution.md#contract) | 1 |
| [Runtime orchestration and registry ownership](runtime-orchestration.md#contract) | 3 |
| [Sawblade event-owned animation and sound gates](sawblade-turret.md#contract) | 1 |
| [Shared runtime helper boundaries](shared-runtime-helpers.md#contract) | 6 |
| [Shared runtime scheduler](runtime-scheduler.md#contract) | 1 |
| [Singularity Lance paid contacts, Wound context, and delayed pulses](singularity-lance.md#contract) | 2 |
| [Spider progression, safe replacement, weapon controls, and reactive smoke](spider-vehicles.md#contract) | 3 |
| [Startup, compatibility, diagnostics, and information interfaces](startup-and-integration.md#contract) | 6 |
| [Steam train wheel helpers](steam-train.md#contract) | 1 |
| [Surveyor inventory scope and zoom restoration](surveyor-scope.md#contract) | 1 |
| [Tesla combat, research variants, and helper lifetime](tesla-runtime.md#contract) | 4 |
| [Vulcanus auric fumarole lifecycle](vulcanus-fumaroles.md#contract) | 1 |

## Coverage exceptions

These are classified control-directory files, not omitted runtime systems.
An exception becomes invalid if a runtime dependency imports it. The inert
vendored Tesla control file is model-owned because its inactivity is an
architectural invariant, not an empty placeholder.

| Source | Classification | Reason |
| --- | --- | --- |
| [event-handlers.lua](../../../exotic-space-industries-remembrance/scripts/control/event-handlers.lua) | inactive | Empty, unreferenced placeholder with no executable behavior. |
| [more-asteroids-spawners.lua](../../../exotic-space-industries-remembrance/scripts/control/more-asteroids-spawners.lua) | data-only | Data-stage helper imported by [more-asteroids.lua](../../../exotic-space-industries-remembrance/scripts/data-updates/more-asteroids.lua); its directory does not establish runtime ownership. |

## Maintenance and verification

Every owned source has one leading `blueprint` marker outside its generated
file-map block. Inline `blueprint-ref` comments point at particular invariant
sections. Each model's Implementation sources list links back to its owners;
other source links are contextual references. Explicit anchors remain stable
when headings change.

Run the audit directly or through repository preflight. Coverage and reciprocal
link checks are structural evidence only. Diagrams and behavioral descriptions
require source review, and prior QC reports prove only the runs they describe.
The models do not claim a new full-runtime, multiplayer, or interactive GUI test.

See [revisit notes](../REVISIT_NOTES.md) for deferred implementation issues,
including source discrepancies exposed by this backfill. Future substantive
data-stage changes also require models, but this rollout does not backfill all
prototype/data-stage files.
