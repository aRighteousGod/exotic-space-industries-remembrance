# Spider vehicle acceptance fixture

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-spider-vehicles-qc.ps1
```

This uses the normal ESIR `qc-fast` wrapper to stage the required dependency stack, adds the helper mod to the isolated QC directory, creates a disposable save, and benchmarks it. The helper is disabled afterwards. It does not install or deploy the mod to the player's mod directory.

For another iteration after a successful data check, use `-SkipDataCheck`. To include native player remote selections and the open vehicle window, supply `-SavePath` pointing to a Factorio 2.0 save with a player. The runner copies that save into its scratch directory; the original save is not modified. Existing saves may require dependencies beyond the standard QC seed.

Use `-Arachnophobia` to test the dependency's alternate graphics. `-WithPatrols` stages installed Spidertron Enhancements 1.10.8 and Spidertron Patrols 2.6.4, verifies patrol retention, and exercises their boarding-proxy replacement contract. The original mod-list state is restored after the run. The proxy test drives the documented replacement events; it does not simulate the keyboard shortcut or every third-party GUI interaction.

Results and logs are written under `.factorio-qc/spider-vehicles-runtime/`. The runner requires a fresh JSON report with every assertion passing. An old report cannot satisfy a failed run.

The fixture covers final prototype configurations, age gates, the original recipe, ordinary and scripted research completion, stable vehicle identities, quality, partially used ammunition, filtered cargo, trash, fuel, spent fuel, remaining burner energy, equipment charge and shields, equipment ghosts, logistic groups, health percentage, occupants, incoming follow links, expanded-grid mining/rebuilding, safe downgrade deferral, legacy assault ammunition remapping, force changes and merges on a second surface, scout locomotion, smoke targeting/expiry/cooldown, and native automatic weapon fire. Player remote and window checks run only when a player exists in the input save.

Combat samples use an unbonused force and stationary targets with large health pools. Firing intervals measure ammunition consumption, including the engine's weapon cycling and tick granularity; they are not projectile-hit or damage-per-second measurements. The benchmark also includes deliberately expensive fixture setup and research floods, so its average is not an idle-runtime performance claim.

Combat probes reproduce Factorio 2.0.77's native mixed-range stalls in both directions. Those raw native probes are marked `known_limitation=true`; separate managed-vehicle probes require recovery in scripted mode. Both test paths remain present. The near/far probes also check recovery from the engine prioritising an enemy inside a long-range gun's minimum range. See [the implemented controls contract](weapon-controls-plan.md) for the mode matrix, sustained turns and native targeting boundary.

Use `-NativeCycling` to disable the startup setting in the isolated fixture. Both modes load the same 24,388 gameplay configuration names. GUI tests build actual native relative widgets and invoke ESIR's production callbacks through an interface appended only to the staged ESIR copy: Factorio cannot raise GUI events from a helper mod. They cover both occupied mount toggles, selected-weapon Hold, pending state, reattachment to the replacement and closure. They do not simulate mouse input or provide a rendered visual review. The fixture uses native player and construction-robot mining/build actions to exercise item-number preference transport.

The normal fixture also covers full cargo deferral, compatible cargo merging, rare ammunition with a partial magazine, ammunition restoration, moving-vehicle deferral, target destruction and range changes, an emptied battery, cloning and preference preservation through a force change/research burst. Additional raw gun probes measure 30/24/18 smart rocket intervals, 60/48/36 Hold intervals and 30/24/18 native battery intervals. Doeworks' four reload tiers are checked independently.

Real save migration uses a separate eight-vehicle matrix because benchmark mode does not write saves. `-SaveFixture` starts a private local server on port 34198, saves into the isolated run directory, and stops only that process after the ZIP is readable. It checks all cycling/mount preference combinations across the two armed families, stable identities, Hold selection, quality, partial ammunition, cargo/trash, fuel/spent fuel, remaining fuel energy, equipment charge and logistic requests. Disabled mounts are re-enabled and disabled again after loading to verify remembered ammunition restoration. Run the initial save, switch off, then switch back on:

```powershell
./scripts/invoke-spider-vehicles-qc.ps1 -SkipDataCheck -SaveFixture -SavePath "$env:APPDATA/Factorio/saves/explode.zip"
./scripts/invoke-spider-vehicles-qc.ps1 -SkipDataCheck -SaveFixture -NativeCycling -SavePath .factorio-qc/spider-vehicles-runtime/saves/spider-controls-smart.zip
./scripts/invoke-spider-vehicles-qc.ps1 -SkipDataCheck -SaveFixture -SavePath .factorio-qc/spider-vehicles-runtime/saves/spider-controls-native.zip
```

For fleet measurements use `-PerformanceVehicles 100` or `500`, optionally `-PerformanceCombat` and `-NativeCycling`. The fixture measures ESIR's spider updater using LuaProfiler over 220 ticks after setup, records target-search and ammunition-sample counts, and measures acquisition latency after enemies appear. Profile time excludes native weapon simulation, the helper's measurements and other ESIR modules. The active-work predicate still runs when the updater has no work. The combat layout deliberately starts each vehicle on artillery with nearby and farther enemies, exercising mixed-range acquisition. Native and scripted runs can therefore perform different amounts of native combat work.

# Runtime integration contract

Production code lives in `exotic-space-industries-remembrance/scripts/control/spider-vehicles.lua`; `control.lua` remains the sole event dispatcher. The shared catalog is `lib/spider-vehicles.lua`, with declarations and final variant generation in `prototypes/spider-vehicles.lua`.

The remote interface `exotic-industries-spider-vehicles` exposes:

- `get_vehicle_id(entity)`: stable ESIR identity of a registered scout, assault, or rocket spidertron.
- `get_replacement_event()`: custom event ID. Subscribe from `on_init` and `on_load`, since generated event IDs are established when control scripts load.
- `refresh_vehicle(entity)`: register or refresh a vehicle after an integration changes its force directly. Factorio 2.0.77 has no general entity-force-changed event.
- `refresh_force(force)`: rebuild that force's researched configuration and queue its vehicles.
- `get_status()`: diagnostics including replacement count, unexpected failures, queued work, and deferred vehicles.
- `get_weapon_controls(entity)`: requested/effective controls, mount research availability and pending reasons.
- `set_weapon_controls(entity, changes)`: validated per-vehicle cycling, mount and Hold-slot preferences; see the controls contract for fields and errors.

The replacement event supplies `old_unit_number`, `entity` (the new live vehicle), and `vehicle_id`. Native remote selections, occupants, the open vehicle window, and incoming spider follow links are repaired by ESIR. Other mods holding their own LuaEntity references or unit-number indexes must consume the event and update those references. Native cloning creates a new stable identity; research replacements retain the old one.

When Spidertron Enhancements is installed, ESIR also raises its shared `on_spidertron_replaced` event before destroying the old entity, allowing Patrols to transfer its waypoints, dock links, and rendering state. Boarding proxies retain ESIR identity, control preferences and smoke cooldown, suspend ESIR replacements while boarded, and resolve current research on disembarkation. One matching proxy per configuration reuses the dependency's family graphics and dummy leg. These optional proxies add 24,388 entity prototypes without adding a leg prototype for each configuration.

Replacement is transactional: the original survives while a temporary clone supplies native item metadata and the candidate receives explicit runtime state. Contents that do not fit, equipment removal orders, motion, temporary stickers, construction orders, active personal robots, and targeted logistic deliveries defer replacement. Delayed retries and smoke pulses use the shared runtime scheduler. There are no idle surface scans; initial/configuration discovery and replacement-time incoming-follow-link discovery are the explicit scan boundaries.

Legacy assault cannon/MG/flamer slots are remapped. Rockets and artillery without an available mount are preserved in empty trunk slots; a full trunk defers conversion. Legacy grids are retained until runtime can check their contents. Expanded grids mine to hidden storage items with matching placement grids, preventing native item placement from discarding equipment. Selectable Gaian saucer recipe alternatives accept both expanded rocket storage items and name the required grid size.

All upgrades use ordinary ESIR research declarations and automatic cost scaling. Twelve cumulative chassis stages combine with independent weapon branches and cycling bodies, producing 13 scout, 23,400 assault, and 975 rocket configurations. Doeworks is a fifth slot; ordinary rocket slots remain in their original positions. Arachnophobia remains an upstream player choice.
