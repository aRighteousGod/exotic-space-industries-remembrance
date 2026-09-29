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
- `exotic-space-industries-remembrance-graphics-4`
- `exotic-space-industries-remembrance-graphics-5`
- `exotic-space-industries-remembrance-soundtrack-1`
- `exotic-space-industries-remembrance-soundtrack-2`

Graphics 4 carries the remaining main-pack graphics plus shared non-music sound effects that were split out of the gameplay pack. Graphics 5 carries the advanced and nuclear rolling-stock graphics, icons, and matching train sound payload split out of Graphics 4.

Practical rule: gameplay references may depend on these sibling packs existing at run/package time, but the source of truth for behavior stays in the main pack.

Legacy root deploy scripts (`process.ps1` and the seven sibling `*_process.ps1` scripts) still package and move ZIPs directly into `%APPDATA%\Factorio\mods`; prefer `scripts\invoke-esir-dev.ps1 -Task pack-dryrun` for non-destructive validation and reserve `-Task pack-deploy` for intentional local deployment.

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

Start with the [maintained conceptual blueprint index](../.codex/esir/blueprints/index.md), then read the owning source. The models cover runtime orchestration, shared libraries, subsystem state/lifecycle contracts, GUI and configuration helpers, migrations, and intentionally inactive boundaries.

The [orchestration model](../.codex/esir/blueprints/runtime-orchestration.md#tick-flow) describes the sixteen-slot dispatcher and its mandatory services. Each source has a primary blueprint backlink outside its generated file-map header; local blueprint-ref comments identify non-obvious invariants.

Generated runtime-modules.json remains an inventory aid, not the architecture authority. Preflight discovers current source dependencies and checks coverage plus reciprocal links. Source review and focused Factorio QC are still needed to verify behavioral agreement. Read the relevant model before substantive edits and update it with the code in the same patch.

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
- when editing non-English locale files, prefer bespoke idiomatic phrasing in the target language over literal English-mirror translation
- preserve gameplay meaning and tone, but let sentence structure and wording shift so the result reads like native game text instead of a calque

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
