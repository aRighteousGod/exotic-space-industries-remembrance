# Exotic Space Industries: Remembrance Internal Reference

This document is the mod-local operator's map for ESIR. It is meant to answer three questions quickly:

1. What is this mod pack, structurally?
2. Where does a given system actually live?
3. What do we need to touch to change it without breaking the rest?

It is intentionally practical. The README carries the public-facing pitch and lineage. This file is for maintainers, contributors, and future-us.

## 1. Identity And Scope

- Canonical mod id: `exotic-space-industries-remembrance`
- Current packaged title: `Exotic Space Industries: Remembrance`
- Factorio target: `2.0`
- License: `GPL-3.0-or-later`
- Space travel required: `true`
- Primary author in `info.json`: `aRighteousGod`
- Lineage:
  - fork of Exotic Space Industries by Eliont
  - itself descended from Exotic Industries by PreLeyZero

ESIR is not a small feature mod. It is a broad overhaul with age-progression content, planet-specific logic, custom runtime systems, bundled compatibility behavior, and split asset packs.

## 2. Pack Topology

This repository is a multi-pack workspace. The main gameplay package is only one part of the shipped mod set.

### Main gameplay pack

- `exotic-space-industries-remembrance`

This contains:

- metadata
- prototypes
- runtime scripts
- locale
- balance settings
- control logic
- vendored Tesla's Legacy integration

### Companion asset packs

- `exotic-space-industries-remembrance-graphics-1`
- `exotic-space-industries-remembrance-graphics-2`
- `exotic-space-industries-remembrance-graphics-3`
- `exotic-space-industries-remembrance-soundtrack-1`
- `exotic-space-industries-remembrance-soundtrack-2`

Practical rule: gameplay references may depend on these sibling packs existing at run/package time, but the source of truth for behavior stays in the main pack.

Legacy root deploy scripts (`process.ps1` and the five sibling `*_process.ps1` scripts) still package and move ZIPs directly into `%APPDATA%\Factorio\mods`; prefer `scripts\invoke-esir-dev.ps1 -Task pack-dryrun` for non-destructive validation and reserve `-Task pack-deploy` for intentional local deployment.

## 3. Source Of Truth Rules

These matter because the repo has generated and cached run directories around it.

- Treat the live repo under `exotic-space-industries-remembrance/` as canonical.
- Treat cached run-mod copies under `output/` or other temporary QC directories as disposable test material.
- Do not edit stale mirrored mod copies and assume the change is real.
- If a headless Factorio run or packaging harness creates a synced mod directory, that directory is a runtime artifact, not an authoring surface.

### Codex Acceleration Surface

The fast maintainer surface now lives in the repo itself:

- wrapper command: `scripts/invoke-esir-dev.ps1`
- repo-local skill: `.codex/skills/esir-dev`
- checked-in manifests under `.codex/esir/`:
  - `runtime-modules.json`
  - `prototype-index.json`
  - `pack-manifest.json`
  - `save-catalog.json`
  - `tool-manifest.json`
  - `portal-shortlist.json`
  - `asset-import-plan.json`
  - `PROMPTS.md`

Operational rule:

- use the manifests to answer structure questions quickly
- refresh them from repo truth with `-Task manifest-refresh`
- treat them as a fast map, not the authority over source files

Save and art support now route through the same wrapper:

- `save-catalog.json` resolves named smoke saves such as `fueler-smoke`
- `art-start`, `art-collect`, `art-review`, and `art-validate` layer ESIR review/import planning over the Firefox companion without mutating shipped asset paths by default

## 4. High-Level Load Architecture

Factorio splits this mod into three broad concerns:

1. settings stage
2. data stage
3. runtime control stage

The main entrypoints are:

- `settings.lua`
- `data.lua`
- `control.lua`

### `settings.lua`

Purpose:

- define startup/runtime settings
- expose tuning knobs for progression, yields, pollution, reactor behavior, train visuals, and other system limits
- import Tesla legacy settings into the main mod's setting stage

Current file behavior:

- requires `lib/lib`
- requires `teslas_legacy.settings`
- defines settings for tech scaling, science yields by age, pipe length, reactor output/removal behavior, rocket launch pollution, Fulgora day variation, barrel capacity, beacon overload, EM train visuals, and related knobs

Maintenance rule:

- if a feature needs player-visible tuning, wire it here first
- if a setting changes behavior in-game text, update locale too

### `data.lua`

Purpose:

- bootstrap prototype-stage helpers
- load prototype trees by progression band / subsystem
- perform a small amount of compatibility patching

Current bootstrap details:

- sets `ei_mod.stage = "data"`
- defines developer toggles such as `dev_mode`, `show_temp`, `show_dummy`, `show_exotic_gates`
- requires:
  - `lib/paths`
  - `lib/lib`
  - `lib/data`

It then loads the major prototype trees:

- infrastructure and support
  - `prototypes/pipe-covers`
  - `prototypes/other`
  - `prototypes/fluids`
  - `prototypes/styles`
  - `prototypes/informatron-sprites`
  - `prototypes/age-techs`
  - `prototypes/containers`
- progression bands
  - `prototypes/dark-age`
  - `prototypes/steam-age`
  - `prototypes/electricity-age`
  - `prototypes/computer-age`
  - `prototypes/quantum-age`
  - `prototypes/exotic-age`
- world and special systems
  - `prototypes/alien-system`
  - `prototypes/planet-gaia/gaia`
  - `prototypes/planet-gleba/gleba`
  - `prototypes/loaders`
  - `prototypes/more-asteroids`
  - `prototypes/productivity`
  - `teslas_legacy.data`

Compatibility note:

- `data.lua` also patches `alien_biomes_priority_tiles` when Alien Biomes is present, including Gaia and induction-matrix tiles.

Maintenance rule:

- new prototype sets should normally be added through a contained module under `prototypes/` and then required here
- avoid dumping large prototype bodies directly into `data.lua`

### `control.lua`

Purpose:

- central runtime orchestrator
- one-time event registration
- update scheduling
- init/config-change/load bootstrapping
- dispatch into subsystem modules

This file is the conductor, not the orchestra.

Current characteristics:

- loads shared runtime helpers:
  - `lib/lib`
  - `lib/data`
  - `lib/rng`
  - `lib/echo-codex`
  - `lib/runtime-scheduler`
- computes update pacing from config values such as:
  - `ticks_per_full_update`
  - `max_updates_per_tick`
- defines staggered update cadence across multiple subsystem buckets
- emits shared runtime telemetry heartbeats from `control.lua` while leaving queue ownership in the modules
- registers large sets of Factorio events once, then fans behavior out to module code

Maintenance rule:

- if you add a runtime feature, prefer a focused module in `scripts/control/`
- keep `control.lua` as orchestration glue, event registration, and shared bootstrap only
- do not let it turn into a second business-logic dump

## 5. Prototype Directory Map

The `prototypes/` tree is organized primarily by age bands plus several cross-cutting systems.

### Age bands

- `prototypes/dark-age`
- `prototypes/steam-age`
- `prototypes/electricity-age`
- `prototypes/computer-age`
- `prototypes/quantum-age`
- `prototypes/exotic-age`

These directories are where most progression-facing content lives:

- recipes
- technologies
- entities
- items
- balance updates tied to a given era

Working rule:

- if a new machine, weapon, or process clearly belongs to a progression band, start there
- if it spans several ages, consider a cross-cutting support file instead of forcing it into the wrong age directory

### Cross-cutting prototype systems

- `prototypes/alien-system`
- `prototypes/planet-gaia`
- `prototypes/planet-gleba`
- `prototypes/loaders`
- `prototypes/more-asteroids`
- `prototypes/productivity`
- `prototypes/containers`
- `prototypes/fluids`
- `prototypes/styles`
- `prototypes/informatron-sprites`
- `prototypes/pipe-covers`
- `prototypes/other`
- `prototypes/age-techs`

Use these when content is:

- planet-specific
- UI/style-oriented
- utility infrastructure
- shared across ages
- not naturally owned by one progression band

## 6. Runtime Subsystem Map

Most gameplay logic beyond pure prototype definition lives under `scripts/control/`, and `control.lua` is the one authoritative event router. What matters in practice is not just which files exist, but which ones are loaded directly by `control.lua`, what cadence they run on, and what state they own.

If you want the machine-readable version of this section, start with `.codex/esir/runtime-modules.json` and then read the owning module.

Two files under `scripts/control/` are support surfaces rather than direct top-level imports:

- `gaia-mapgen-data.lua`
- `event-handlers.lua`

The rest of this section follows the actual `control.lua` load surface.

### Control-Side Update Cadence

`control.lua` splits runtime work into a scheduled branch plus an every-tick branch. The scheduled branch is keyed from `event.tick`, not an inferred tick source, so the cadence stays explicit and deterministic in multiplayer.

- Step 1: `global.check_init`, `vulcanus-fumaroles.check_global`, `nauvis-pressure-grace.updater`, `camp-fire.updater`, `gaia.reforge_on_tick`
- Step 2: `fluid-safety.service_fluid_runtime`
- Step 3: `neutron-collector.update`
- Step 4: `matter-stabilizer.update`
- Step 5: `orbital-combinator.update`
- Step 6: `fueler.updater`
- Step 7: `gate.update`
- Step 8: `em-trains.train_updater`
- Step 9: `em-trains.charger_updater`
- Every tick outside the scheduler: `echo-codex.flush_pending_arrivals`, `em-trains/gui.updater`, `alien-spawner.update`, `gaia.update`, `induction-matrix.update`, `black-hole.update`, `steam-train.updater`, `echo-codex.arrival_waves`, `beacon-overload.updater`, `rocket-launch-pollution.updater`, `fulgora-day-length-variation.updater`, `vulcanus-fumaroles.updater`
- Every 600 ticks when runtime telemetry is enabled: `control.lua` collects shared module status and writes a `runtime-heartbeat` snapshot through `lib/runtime-scheduler`

### Runtime Helper Libraries Loaded First

- `lib/lib`: shared runtime utility layer for config reads, notifications, helper math, player messaging, and many small convenience wrappers.
- `lib/data`: shared data tables and constants used at runtime, especially where prototype-derived values need to stay centralized.
- `lib/rng`: shared RNG helper layer. Some newer modules still prefer local deterministic seeding, but this remains part of the runtime substrate.
- `lib/echo-codex`: ritual messaging layer. `control.lua` uses it for startup settings sync, arrival messaging, and ongoing arrival-wave effects.
- `lib/runtime-scheduler`: shared queue, delayed-bucket, counter, status-snapshot, and JSONL telemetry helper layer used by the newer queued-control runtimes. It does not own gameplay itself; it standardizes how modules expose and audit their schedulers, while the periodic JSONL heartbeat stays opt-in for release builds.

### Detailed Module Reference

- `scripts/control/tech-scaling.lua`: Owns the technology-price multiplier curve. It counts weighted researched tech, applies the configured formula, and refreshes the player force multiplier on init, configuration changes, and research completion.

- `scripts/control/global.lua`: Seeds and repairs `storage.ei`. This is the shared storage root for tech scaling, orbital combinators, rocket launch pollution, enemy difficulty, campfires, arrival waves, pending arrivals, fluid runtime state, beacon-overload runtime state, Vulcanus fumarole runtime state, steam train runtime state, and other cross-system tables. `control.lua` calls `init()` on new saves and `check_init()` both during migrations and on scheduled sanity passes.

- `scripts/control/register-util.lua`: Shared registry helper for runtime-owned tables. It handles fluid entity registration and the older master/slave bookkeeping pattern used by legacy beacon-style entities. In current `control.lua` flow it is mainly used for fluid entity add/remove tracking plus leftover beacon support scaffolding.

- `scripts/control/teslas-legacy.lua`: The owned runtime for the vendored Tesla's Legacy subsystem. It handles research-tier caching, helper entity spawning, script-trigger dispatch, chain lightning and vaporize behavior, and selective damage/death follow-up logic. `control.lua` forwards init, load, configuration-changed, research-finished, entity-built, entity-died, entity-damaged, and script-trigger events here.

- `scripts/control/flammable-fluids.lua`: Lightweight rupture/effect bridge for combustible fluid containers. It derives death behavior from final runtime fluid prototype data and is only in the `control.lua` surface for destruction-time routing.

- `scripts/control/fluid-safety.lua`: Owns the V2 fluid safety runtime: exact urgent-entity wakeups, dirty-segment audits, and round-robin background scans that destroy or transform invalid pipe contents, enforce data-pipe rules, and catch uninsulated hot or cryogenic fluid misuse.

- `scripts/control/beacon-overload.lua`: Counts real beacons in range of eligible machines, disables machines over the configured threshold, renders overload effects/icons, and increments victory stats. The newer runtime is queue-driven rather than giant-scan driven: configuration changes, chunk discovery, suspect cleanup, and disable release all settle through bounded rebuild and audit work. `control.lua` routes build/destroy/configuration-change events here and also keeps its updater on the every-tick path.

- `scripts/control/spidertron-limiter.lua`: Narrow rule-enforcement module for spiderlings. It watches logistic slot edits and clears any request that is not valid fuel for the spider vehicle, then prints a rejection message.

- `scripts/control/victory-disabler.lua`: Disables vanilla rocket-launch victory and exposes ESIR victory bookkeeping instead. It also tracks cross-system counters such as machine overloads and other progress metrics that later systems can consult.

- `scripts/control/alien-spawner.lua`: Gaia-oriented worldgen and debug-spawn system. It owns the preset queue, tile/entity spawn batches, flower guardian behavior, selection-tool import helpers, chunk-generated spawning, and its own lightweight every-tick queue advancement.

- `scripts/control/informatron.lua`: Registers the main ESIR Informatron remote interface and renders the mod's in-game manual pages. It is documentation runtime, not simulation runtime, but it is still part of the `control.lua` surface because it owns the menu/page providers for progression, logistics, planets, Tesla legacy, gate behavior, and other mechanics.

- `scripts/control/milestone-preset.lua`: Load-time integration for the Milestones mod. It publishes a remote milestone preset for ESIR progression and does not participate in the event scheduler after its interface is registered.

- `scripts/control/matter-stabilizer.lua`: Tracks matter stabilizers and nearby volatile machines, computes stabilization coverage and risk, renders warning/connection effects, and reacts to player selection/cursor state for visualization. `control.lua` rebuilds its runtime on init/configuration changes, routes build/destroy and selection events into it, and services its machine queue on scheduled step 4.

- `scripts/control/neutron-collector.lua`: Owns neutron collector runtime state, dirty-collector queues, nearby neutron-source linking, collector efficiency math, and directional animation feedback. `control.lua` rebuilds it from world state on init/configuration changes, routes build/destroy events, and spends scheduled step 3 budget on its pending work.

- `scripts/control/fusion-reactor.lua`: GUI-heavy runtime for fusion reactors. It registers reactor entities, opens the fusion console, updates reactor recipes from GUI state, and owns click/value-change handlers for the reactor control panel.

- `scripts/control/induction-matrix.lua`: One of the larger multistructure runtimes. It flood-fills matrix footprints, assigns a canonical core, computes coil/solenoid/converter-derived stats, swaps core variants when IO changes, maintains a hidden wire proxy, and serves the matrix GUI. `control.lua` routes both entity and tile lifecycle events here and runs its update loop every tick.

- `scripts/control/black-hole.lua`: Owns black hole generator staging, mass absorption, pylon refresh, battery and power math, residue/output handling, and the player GUI for stage control. It is an every-tick runtime and also participates in build/destroy routing.

- `scripts/control/informatron-messager.lua`: Small notification bridge meant to push players toward relevant Informatron pages after research or major unlocks. At the moment it is intentionally light and mostly acts as a stub for future messaging expansion.

- `scripts/control/gaia.lua`: Owns Gaia as a surface and as a ruleset. It can create or migrate the surface, run a slower reforge workflow, maintain Gaia surface registry state, degrade or swap unsupported entities, and expose dev commands for Gaia operations. `control.lua` routes build events here and runs both `reforge_on_tick()` on step 1 and the main Gaia update every tick.

- `scripts/control/gate.lua`: Another major runtime pillar. It handles receiver registration, distance quoting, energy burden, stress/cooldown/residue penalties, wire-proxy telemetry, gate GUI, remote targeting, position selection tools, and scripted transport. `control.lua` forwards init, configuration-changed, build/destroy, GUI open/close/click/selection, selection-tool, cursor cleanup, player disconnect, and script-trigger-remote events here, while scheduled step 7 advances active gates.

- `scripts/control/alien-system.lua`: Owns alien artifact scanning and unlock progression. It tracks unlocked states, artifact repair/selection interactions, alien-tier GUI flow, and the player-facing unlock confirmation screens driven by the alien selection tool.

- `scripts/control/debug.lua`: Admin and debugging command surface. It handles `/tp` via the console-command event and also self-registers admin commands for victory reset, beacon overload refresh, Gaia reforge, fast travel to planetary surfaces, beacon-overload stall/status inspection, and `/ei_runtime_status` for shared scheduler snapshots plus telemetry control.

- `scripts/control/compat.lua`: Runtime compatibility glue. It performs remote-interface setup for mods such as K2 and DiscoScience and exposes an ESIR remote interface for Gaia-surface registration. It is mostly migration and integration setup, not a tick-heavy gameplay system.

- `lib/loaders.lua`: Runtime helper for loader snapping and adjacency repair. Even though it lives under `lib/`, `control.lua` treats it as a runtime subsystem and forwards build events into its loader rebinding logic.

- `scripts/control/rocket-launch-pollution.lua`: Computes rocket-launch pollution based on difficulty/evolution settings, queues retaliation or wrath behavior, and drives the lingering launch smoke visuals. `control.lua` forwards rocket-order events and runs the smoke/retaliation upkeep every tick.

- `scripts/control/fulgora-day-length-variation.lua`: Periodically perturbs Fulgora's cycle length while guarding against abrupt transitions in unstable-light conditions. It is a small every-tick timer-driven module.

- `scripts/control/mining-scars.lua`: Responds to depleted resources by degrading terrain and cleaning decoratives around supported drill classes. Its only `control.lua` hook is `on_resource_depleted`.

- `scripts/control/vulcanus-fumaroles.lua`: Owns auric precipitation fumarole seeding, delayed dormant wakeups, active/dormant chunk bookkeeping, depletion cleanup, and volcanic scar aftermath on Vulcanus. `control.lua` runs its global sanity check on init/configuration changes and step 1, routes chunk-generated and resource-depleted events into it, and keeps its active/dormant scheduler on the every-tick path.

- `scripts/control/nauvis-pressure-grace.lua`: Owns the pre-steam / pre-electricity Nauvis pressure grace system. It lowers or caps enemy evolution until progression milestones are reached, unless settings or difficulty mode disable that behavior. `control.lua` runs it on configuration changes, research completion, and scheduled step 1.

- `scripts/control/fueler/fueler.lua`: Service-tower logistics runtime for refueling and rearming supported targets, including vehicles, spidertrons, and connected players. It owns tower/target registries, chunked lookup, ready queues, transfer logic, and the fueler GUI. `control.lua` rebuilds it from live world state on init/configuration changes, routes build/destroy and GUI events, and advances its ready queue on scheduled step 6.

- `scripts/control/fueler/informatron.lua`: Dedicated Informatron page provider for the fueler feature. It exists to register docs content rather than simulation logic.

- `scripts/control/em-trains/charger.lua`: Main EM train runtime. It tracks chargers and EM locomotives, computes rail coverage and power draw, applies research-driven buffs, manages charge transfer, renders train/charger feedback, and owns the separate train and charger schedulers used on steps 8 and 9.

- `scripts/control/em-trains/gui.lua`: Mod-GUI layer for EM train controls and status. It creates the top-level button, rebuilds the panel when marked dirty, and owns the click handling for that UI. `control.lua` keeps it on the every-tick path because it is lightweight and player-facing.

- `scripts/control/em-trains/informatron.lua`: Currently an empty placeholder file. It is required by `control.lua`, but as of this snapshot it does not register any interface or own any runtime behavior yet.

- `scripts/control/steam-train.lua`: Maintains the steam locomotive runtime shape, helper wheel entities, active/audit queues, and fast wake-up behavior when train state changes. `control.lua` rebuilds it on init/configuration changes, routes build/destroy and train-state events, and runs its visual/runtime updater every tick.

- `scripts/control/camp-fire.lua`: Small lifetime-tracking runtime for campfire entities. It registers and cleans them on build/destroy and advances its maintenance pass on scheduled step 1.

- `scripts/control/orbital-combinator.lua`: Mirrors logistic and space-platform state into orbital combinator banks. It owns bank registration, platform cache reconciliation, page splitting, signal filter reconciliation, and dirty-platform tracking. `control.lua` runs `check_init()` on init/configuration changes, routes relevant logistics/platform events, and services bank updates on scheduled step 5.

Practical reading order for runtime debugging:

1. `control.lua`
2. the specific module above that owns the affected behavior
3. `global.lua` or the module's runtime storage initializer if state is involved
4. any linked GUI or Informatron page provider if the issue is player-facing
5. shared helpers in `lib/` only after the owning module boundary is clear

## 7. Embedded Tesla's Legacy Surface

ESIR vendors Tesla's Legacy content directly under:

- `teslas_legacy/`

This is not just a loose reference folder. It is actively integrated into the main mod:

- `settings.lua` requires `teslas_legacy.settings`
- `data.lua` requires `teslas_legacy.data`
- `control.lua` loads `scripts/control/teslas-legacy`

What it brings in:

- Tesla coil systems
- advanced Tesla coil behavior
- Tesla tank content
- its own config, prototype, graphics, sound, and helper files

Maintenance rule:

- treat Tesla legacy as a vendored subsystem with explicit integration points
- preserve attribution and structure where possible
- avoid casual rewrites unless a shared ESIR concern genuinely needs them

## 8. Shared Libraries And Helpers

The mod relies on helper code under `lib/`.

Observed common runtime/data touchpoints:

- `lib/lib`
- `lib/data`
- `lib/paths`
- `lib/rng`
- `lib/echo-codex`

Even when a feature seems self-contained, check whether a helper already exists before adding another utility layer. ESIR already has a lot of moving parts, so duplicate helper logic becomes expensive fast.

## 9. Locale Surface

Current locale coverage includes:

- `locale/en`
- `locale/fr`
- `locale/ja`
- `locale/pl`
- `locale/ru`
- `locale/zh-CN`
- `locale/zh-TW`

Minimum rule for content work:

- new settings, item names, recipe names, technology names, entity names, and player-facing messages should land in English locale at the same time as the feature
- if the change touches an already-translated key, preserve key stability unless a rename is unavoidable
- broad translation updates can follow, but breaking keys casually creates hidden regressions

## 10. Dependency And Compatibility Profile

`info.json` makes it clear ESIR is operating in a dense mod ecosystem.

### Hard dependencies and major expected companions

Examples currently listed include:

- `base`
- `informatron`
- `space-age`
- `elevated-pipes`
- `zeus-wrath`
- several enemy and utility mods

### Explicit incompatibilities

Examples currently blocked include:

- `tesla_legacy_sa`
- `ExoticDiscoIndustries`
- `factorioplus`
- `no-triggers`
- specific More Asteroids variants

### Soft/optional integrations

`info.json` also lists a long optional surface for expansion or ecosystem compatibility, including several planet overhauls and utility mods.

Maintenance rule:

- when adding compatibility support, encode it deliberately in one place
- if the support is prototype-stage only, keep it near `data.lua` or the owning prototype module
- if it affects runtime behavior, make the runtime module own it and document any assumptions

## 11. Settings And Balancing Conventions

From the current `settings.lua`, ESIR already exposes balancing levers for:

- technology scaling
- science reward/yield pacing across ages
- pipe logistics reach
- reactor output behavior
- pollution side effects
- barrel capacities
- beacon overload behavior
- train visual toggles

Guideline:

- put player/admin-facing tuning behind settings
- put internal constants in code only when exposing them would create more confusion than value
- if a setting materially changes simulation cost, note it in comments or docs so performance regressions are easier to interpret

## 12. Documentation Surface

Current major mod-local docs include:

- `README.md`
- `CONTRIBUTORS.md`
- `CREDITS.md`
- `LICENSE.md`
- `changelog.txt`
- this file
- `.codex/esir/PROMPTS.md`

Recommended ownership:

- `README.md`: public-facing mod overview, tone, install/use context
- `changelog.txt`: release-facing delta log
- `CONTRIBUTORS.md`: people and contribution surface
- this file: maintainer-facing architecture and operational reference
- `.codex/esir/*.json`: checked-in machine-readable repo maps for Codex and maintainers
- `.codex/esir/PROMPTS.md`: repo-local “ask Codex” prompt shortcuts

## 13. QC And Testing Workflow

The authoritative judge for many failures is still Factorio itself.

### Testing hierarchy

1. static checks are advisory
2. headless Factorio data/runtime runs are authoritative
3. smoke-save loading and targeted preview generation catch cross-system breakage that static scans miss

### Practical workflow

Start with the wrapper unless you are deliberately doing a one-off manual check:

1. `powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task doctor`
2. `... -Task manifest-refresh`
3. `... -Task preflight`
4. `... -Task qc-fast` or the narrower QC mode you actually need
5. `... -Task diff` when cache or package drift is part of the question

The wrapper composes the existing Factorio QC and Firefox companion engine layers; it does not replace Factorio as the authoritative runtime judge.

For ESIR work, the usual safe sequence is:

1. verify file and locale wiring
2. run a fast headless preflight
3. run runtime smoke on a known save when behavior changed
4. run preview or asset checks when touching mapgen, Gaia resources, icons, media, or pack structure
5. dry-run packaging before release work

### Important repo-specific rule

- never trust a stale copied run directory over the live repo folder
- any QC harness should sync live source into a temporary run-mod directory before invoking Factorio

### Artifact discipline

- generated logs, previews, temp mods, and zips should live in ignored artifact directories
- generated material is for inspection, not hand-editing

## 14. Release And Packaging Notes

Before cutting a release:

1. confirm `info.json` version bump is intentional
2. update `changelog.txt`
3. verify pack alignment across gameplay, graphics, and soundtrack siblings if the release depends on them
4. run dry-run packaging instead of manually copying straight into live user mod directories
5. check that canonical metadata in the live repo matches what will ship

## 15. How To Add New Content Safely

### New prototype content

Touch at least the relevant combination of:

- owning file under `prototypes/`
- `data.lua` require list if a new module is introduced
- locale keys
- settings if user tuning is needed
- assets in the correct sibling pack or local path

### New runtime behavior

Touch at least the relevant combination of:

- a focused file under `scripts/control/`
- `control.lua` module load path
- init/load/config-change handling if stateful
- event registration or update scheduling if needed
- `lib/runtime-scheduler.lua` plus debug/status surfaces if the feature introduces shared queues, delayed buckets, counters, or telemetry
- migration/repair logic if existing saves can be affected

### New compatibility path

Touch at least the relevant combination of:

- `info.json` dependency metadata if load order or exclusivity matters
- prototype or runtime conditional logic
- QC coverage for the affected ecosystem surface

## 16. Known Structural Truths

These are easy to forget and expensive to relearn.

- `control.lua` is already large because it owns orchestration; resist moving feature business logic into it.
- `control.lua` remains the single top-level dispatcher even when modules share queue primitives through `lib/runtime-scheduler`.
- The age-band prototype split is a core organizing principle. Use it unless you have a stronger ownership boundary.
- Tesla legacy is already integrated. Treat it as active code, not archive material.
- Locale coverage is broad enough that key churn carries real maintenance cost.
- This repo is a pack workspace, not a single isolated zip folder.

## 17. Suggested Reading Order For New Maintainers

If you need to get oriented fast:

1. `info.json`
2. `README.md`
3. `data.lua`
4. `settings.lua`
5. `control.lua`
6. the relevant `prototypes/<area>` directory
7. the relevant `scripts/control/<system>.lua` file
8. this document again, once the names mean something

## 18. Style Note For Internal Writing

ESIR's public and in-universe voice can be severe, devotional, uncanny, and signal-haunted. Internal docs should still stay concrete. Use the project's tone when it sharpens meaning, not when it obscures procedure.

The machine may speak in omens. The maintainer docs should still tell you which file to open.
