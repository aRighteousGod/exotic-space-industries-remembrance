---
name: esir-dev
description: "ESIR-first repo-local development surface for Exotic Space Industries: Remembrance. Use when Codex should work faster inside this workspace by relying on checked-in manifests, the ESIR wrapper command, Factorio QC delegation, Mod Portal scouting, save catalog resolution, Lua/runtime/prototype helper routing, Meshy/Blender asset pipeline routing, Factorio asset export, item icon prep, recipe icon style audits, art/browser session handoff, cache diffing, packaging, or ESIR-specific runtime/prototype maps."
---

# ESIR Dev

Use the repo-local wrapper first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task doctor
```

This skill is the ESIR operator surface. It composes the existing engine-layer skills instead of replacing them:

- `factorio-mod-qc` for headless Factorio validation, package dry-runs, and Mod Portal metadata
- `chatgpt-firefox-companion` for supervised Firefox image sessions
- `esir-dependency-intel` for dependency declarations, compatibility touchpoints, remote interfaces, and local installed-mod enrichment
- `factorio-lua-assumptions`, `factorio-lua-docs`, `factorio-core-lualib`, and `factorio-vanilla-prototype-libs` for Factorio Lua lifecycle/API truth, bundled core helper routing, and vanilla prototype helper routing
- `esir-lib-first`, `esir-lua-types`, `esir-runtime-gui`, and `esir-research-events` for ESIR Lua helper reuse, LuaLS annotations, runtime GUI house style, and research-event burst dispatch
- `esir-asset-pipeline`, `meshy-api`, `meshy-blender-spritesheet`, `blender-procedural-animation`, `esir-factorio-asset-export`, and `esir-item-icon-prep` for the generated-art-to-Factorio asset path
- `esir-recipe-icon-style` for recipe icon readability, companion-baseline drift, visibility, sorting, and signal cleanup audits

## Task Map

- `doctor`: verify repo shape, engine paths, Factorio/Firefox discovery, and pack topology
- `manifest-refresh`: regenerate checked-in manifests under `.codex/esir/`, including the dependency catalog
- `dependency-refresh|dependency-query|dependency-diff`: operate on the ESIR dependency catalog and optional local installed-mod enrichment
- `preflight`: static syntax/reference/header/encoding sweeps without touching gameplay data
- `qc-fast|qc-runtime|qc-preview|qc-assets|qc-package|qc-full`: delegate to the Factorio QC harness
- `qc-gaia-resources`: run the checked-in multi-seed Gaia resource matrix described in [`references/gaia-resource-qc.md`](./references/gaia-resource-qc.md)
- `runtime-benchmark`: run save-catalog-backed runtime benchmarks, auto-staging helper mods declared for that save
- `portal-scout`: build or refresh `.codex/esir/portal-shortlist.json`
- `diff`: compare live source, seeded caches, package outputs, and shortlist freshness
- `art-start|art-collect|art-review|art-validate`: stage and review supervised Firefox image sessions
- `pack-dryrun`: non-destructive packaging through the QC harness
- `pack-deploy`: intentional local deployment through the legacy root scripts
- `full`: run `doctor -> manifest-refresh -> preflight -> qc-full -> portal-scout -> diff -> pack-dryrun`

## Operating Rules

- Treat checked-in manifests under `.codex/esir/` as the fast map, not the authority. The repo source is still canonical.
- For dependency-heavy questions, prefer the dedicated `esir-dependency-intel` skill and `scripts\invoke-esir-dependency-intel.ps1` before freehand repo scans.
- Treat headless Factorio runs as authoritative when they disagree with static sweeps.
- Treat cached run-mod directories as dependency seeds only. Live repo pack folders are the source of truth.
- Keep raw caches and generated staging in `.factorio-qc` or ignored `output/`; stable manifests stay checked in.
- Keep durable ESIR asset generator scripts and generator-specific notes in `.codex/esir/asset-generators/`, not in `output/`. Keep hand-written art prompts in `.codex/esir/art-prompts/` unless the user intentionally wants the older top-level `art-prompts/` tree.
- Treat `exotic-space-industries-remembrance*/graphics/` as the shipping surface for approved/promoted PNGs, not as scratch staging.
- Factorio-bound spritesheet work defaults to the local Factorio rendering preset conventions, including smoke/preflight checks: orthographic camera, upper-left lighting, lower-right shadows, separate base/shadow/light/mask passes, and preset-compatible sheet layout. Use non-preset rendering only when the user specifically asks for it or when debugging the renderer tooling itself.
- For force color, player color, runtime tint, color mask, or overlay mask work, route through official `factorio-lua-docs` first, then the asset path skills. Default to owner-readability masks only: turrets, vehicles, rolling stock, train stops/remotes, force-facing logistics/control devices, and ownership-critical entities. Do not add automatic runtime tint to neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, or assets whose baked ESIR chromatic identity should remain fixed.
- When entity, item, fuel, recipe, tech, or asset presentation changes could affect late visuals, check the matching data-final presentation touchpoints listed below instead of assuming the source prototype's first declaration survives untouched.
- The checked-in dependency catalog is intentionally limited to declared pack dependencies plus ESIR touchpoints. Local installed mod roots are query-time enrichment only.
- Before applying generic Lua advice to ESIR code, use the repo-local `factorio-lua-assumptions` skill to check Factorio's staged lifecycle, sandboxed libraries, storage rules, `require()` behavior, deterministic runtime changes, and LuaObject validity semantics.
- For official Factorio API or wiki questions, prefer the repo-local `factorio-lua-docs` skill and `scripts\invoke-factorio-lua-docs.ps1` before broad web search or memory.
- Before importing, replacing, or reimplementing Factorio bundled helpers such as `meld`, `util`, `mod-gui`, `resource-autoplace`, `collision-mask-util`, `math2d`, or `math3d`, use the repo-local [`factorio-core-lualib`](../factorio-core-lualib/SKILL.md) skill and verify exact semantics against the installed Factorio `data/core/lualib` files when needed.
- Before importing, replacing, or reimplementing vanilla prototype helper modules from `__base__`, `__space-age__`, `__quality__`, or `__elevated-rails__`, use the repo-local [`factorio-vanilla-prototype-libs`](../factorio-vanilla-prototype-libs/SKILL.md) skill and verify exact semantics against the installed Factorio `data/*/prototypes` files when needed.
- When editing ESIR Lua and the change touches function signatures, runtime state, option tables, GUI tags, scheduler payloads, prototype records, or module exports, use the repo-local [`esir-lua-types`](../esir-lua-types/SKILL.md) skill to add high-signal LuaLS annotations without forcing unrelated annotation churn.
- For weapon, turret, or vehicle tooltip/status readouts such as DPS, scripted payload, force-scaled damage, or custom entity status lines, use the repo-local [`esir-lib-first`](../esir-lib-first/SKILL.md) skill and its combat readout pattern before adding ad hoc tooltip or status wiring.
- For ESIR recipe icon readability, subgroup/order drift, Factoriopedia visibility, player-crafting visibility, recipe signal cleanup, or companion-style batch review, use the repo-local [`esir-recipe-icon-style`](../esir-recipe-icon-style/SKILL.md) skill before ad hoc prototype edits.
- `pack-deploy` is intentionally mutating. Prefer `pack-dryrun` unless the user explicitly wants `%APPDATA%\Factorio\mods` updated.
- Encoding detection is part of `preflight` and the `qc-*` wrapper surface. Pass `-FixEncoding` when you want the harness to rewrite non-UTF-8 or repaired mojibake sources as UTF-8.
- Keep commentary current during ESIR work. As context changes, say what you are inspecting, what you are changing next, and what you verified; do not go quiet through long repo-specific work.
- When a shared helper surface changes in a way future Codex runs should follow, update the matching skill/reference guidance in the same patch.
- When a patch leaves deferred implementation work, migration debt, upgrade hooks, or intentionally local behavior worth revisiting, add or update a short note in [`.codex/esir/REVISIT_NOTES.md`](../../esir/REVISIT_NOTES.md) in the same patch. Remove or close the note when the follow-up is done.
- Runtime script files should keep useful comments by default: preserve or add the ESIR file-map header, state-machine summaries, lifecycle/cadence notes, storage ownership notes, Factorio/Lua caveats, and non-obvious invariants. Do not add comments that merely restate simple assignments or control flow.
- Runtime scripts should strive to use `event.tick` over `game.tick` wherever an event context already provides the tick.
- When editing non-English locale files, write bespoke idiomatic translations for the target language instead of mechanically mirroring the English text.
- For entity-specific runtime GUI, prefer `player.gui.relative` first. Reach for `player.gui.screen` only when the panel is modal or intentionally detachable, and use `mod_gui` only for persistent global mod controls.
- Default new runtime work to event-first control. Before adding `on_tick`, `on_nth_tick`, or a persistent queue, check whether explicit lifecycle hooks, delayed one-shots, or `script.register_on_object_destroyed` can express the behavior cleanly.

## Repo-Local Skill Router

Use these specialist skills early instead of letting `esir-dev` absorb the whole task:

- [`esir-dependency-intel`](../esir-dependency-intel/SKILL.md): dependency declarations, remote interfaces, dependency touchpoints, planet/content integrations, and local installed-mod presence.
- [`factorio-lua-assumptions`](../factorio-lua-assumptions/SKILL.md): Lua sandbox, lifecycle, storage, `require()`, deterministic runtime behavior, `data.raw` versus runtime state, and LuaObject validity.
- [`factorio-lua-docs`](../factorio-lua-docs/SKILL.md): official Factorio runtime, prototype, auxiliary, and wiki scripting docs, including `apply_runtime_tint`, `tint_as_overlay`, `LuaEntity.color`, `LuaPlayer.color`, and rolling-stock color behavior.
- [`factorio-core-lualib`](../factorio-core-lualib/SKILL.md): bundled Factorio `data/core/lualib` helpers, including `meld`, `util`, `mod-gui`, `resource-autoplace`, `collision-mask-util`, `math2d`, `math3d`, require forms, stage routing, and when to prefer `ei_lib`.
- [`factorio-vanilla-prototype-libs`](../factorio-vanilla-prototype-libs/SKILL.md): vanilla prototype helper modules from Base, Space Age, Quality, and Elevated Rails, including canonical sounds/effects, asteroid and planet helpers, recycling generation, tile helpers, graphics precedent, require routing, and when to prefer `ei_lib`.
- [`esir-lib-first`](../esir-lib-first/SKILL.md): shared `ei_lib` helpers before adding local Lua helpers, including recipe/prototype mutation, table/string helpers, tint/config utilities, runtime entity safety, prototype tooltip rows, and runtime combat status readouts.
- [`esir-lua-types`](../esir-lua-types/SKILL.md): LuaLS/EmmyLua annotations for signatures, storage/state shapes, option tables, GUI tags, scheduler payloads, prototype records, and module exports.
- [`esir-runtime-gui`](../esir-runtime-gui/SKILL.md): runtime GUI surfaces, relative anchors, root names, style vocabulary, tag routing, stale-root teardown, and entity-bound lifecycle.
- [`esir-research-events`](../esir-research-events/SKILL.md): research completion receivers, scripted research burst compatibility, force-wide refresh hooks, and `event.by_script` QC planning.
- [`esir-asset-pipeline`](../esir-asset-pipeline/SKILL.md): replayable Meshy/Blender/Factorio preset-based asset dossiers with QA, output-role classification, previews, manifests, and promotion planning.
- [`meshy-api`](../meshy-api/SKILL.md): Meshy generation, balance checks, polling, downloads, manual asset handoff, and safe `MESHY_API_KEY` handling.
- [`meshy-blender-spritesheet`](../meshy-blender-spritesheet/SKILL.md): static or directional Factorio-preset spritesheet renders from Meshy GLBs or other Blender-compatible models, including named `team_color`/`force_trim`/`color_mask` regions when owner-readability requires runtime tint.
- [`blender-procedural-animation`](../blender-procedural-animation/SKILL.md): non-human procedural motion for ESIR machines, gates, crystals, orbitals, props, and preset-compatible transparent animation sheets.
- [`esir-factorio-asset-export`](../esir-factorio-asset-export/SKILL.md): staged Factorio-ready previews, manifests, Lua snippets, galleries, render-bundle export, runtime color-mask classification, and dry-run promotion plans.
- [`esir-item-icon-prep`](../esir-item-icon-prep/SKILL.md): source item art cleanup and transparent `128/64/32` mipmapped icon strips.
- [`esir-recipe-icon-style`](../esir-recipe-icon-style/SKILL.md): recipe icon readability, companion-mod baseline drift, sorting/order drift, hiding/visibility behavior, and recipe signal cleanup.

When a task spans several specialists, start with the broadest orchestrator (`esir-asset-pipeline` for assets, `esir-dev` wrapper tasks for QC/runtime, or `esir-dependency-intel` for dependency questions), then load narrower skills as the work crosses their boundary.

## Art And Asset Routing

- Use `esir-asset-pipeline` when a generated or imported asset needs an end-to-end, replayable dossier across Meshy, Blender, QA, Factorio export, previews, and manifests.
- Use `meshy-api` for Meshy generation, task polling, downloads, balance checks, or manual Meshy asset handoff. Run dry plans before credit-spending steps and read credentials only from `MESHY_API_KEY`.
- Use `meshy-blender-spritesheet` for static or directional renders from Meshy GLBs or other Blender-compatible models; default to `factorioRenderingPreset_v4.blend`/`render_factorio_preset.py` rather than ad hoc camera, lighting, or shadow setups.
- Use `blender-procedural-animation` when an ESIR machine, gate, crystal, orbital, prop, or Meshy model needs readable non-human procedural motion; keep preset-compatible lighting, orthographic framing, and separate lower-right shadow sheets unless explicitly asked otherwise.
- Use `esir-factorio-asset-export` after any art workflow produces source PNGs, sheets, or render bundles that should become staged Factorio/ESIR drafts. Prefer preset `render-bundle` exports for final review and keep promotion dry-run unless explicitly approved.
- For main-pack shipping graphics, use no-prefix filename and directory roots in `graphics/`; keep `ei-*` in prototype/internal names and pass explicit target prototype metadata when staging or promoting generated assets.
- For runtime-tinted force/player color overlays, keep the mask as a separate neutral/white sheet and wire it as a sprite/animation layer with `flags = {"mask"}` and `apply_runtime_tint = true` on that layer. When `layers` exists, never put tint fields only on the parent. Treat `FluidWagonColorMask` by yeahtoast as a read-only precedent for the pattern; do not copy third-party art or code.
- Use `esir-item-icon-prep` when source item art needs background cleanup and a transparent `128/64/32` mipmapped item icon strip.
- Use `esir-recipe-icon-style` when work touches recipe icon readability, companion-style overlays, subgroup/order drift, Factoriopedia visibility, player-crafting visibility, or recipe signal cleanup.

## Data Stage Routing

Use the current Factorio stage roots before creating or moving prototype code.

- [`data.lua`](../../../exotic-space-industries-remembrance/data.lua) and [`prototypes/`](../../../exotic-space-industries-remembrance/prototypes): ESIR-owned prototype declarations, age/planet aggregators, and first-pass content ownership.
- [`data-updates.lua`](../../../exotic-space-industries-remembrance/data-updates.lua) and [`scripts/data-updates/`](../../../exotic-space-industries-remembrance/scripts/data-updates): post-declaration normalization, vanilla/Space Age reshaping, icon/locale/music passes, and optional-mod bridges after regular prototype load.
- [`data-final-fixes.lua`](../../../exotic-space-industries-remembrance/data-final-fixes.lua) and [`scripts/data-final-updates/`](../../../exotic-space-industries-remembrance/scripts/data-final-updates): last-write reconciliation for recipes, techs, science packs, recycling, compatibility closures, balance, difficulty, and presentation.
- Do not create a generic `scripts/data-stage` root unless intentionally reorganizing the stage layout. Match the existing stage-specific roots and require order.
- For durable or non-obvious data-stage modules, prefer an `ESIR FILE MAP` header with `owns`, `loaded_by`, `cadence`, `forwarded_events`, and `rebuild_on` so future agents can route changes quickly.

## Data-Updates Prototype Touchpoints

Before editing recipes, technologies, fuels, resources, modules, vehicles, reactors, rockets, turrets, or Space Age content, inspect [`data-updates.lua`](../../../exotic-space-industries-remembrance/data-updates.lua) load order and the relevant post-declaration mutation pass.

- Treat [`tech-flattening.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/tech-flattening.lua), [`tech-structure.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/tech-structure.lua), [`lib/data.lua`](../../../exotic-space-industries-remembrance/lib/data.lua), [`set-age-packs.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/set-age-packs.lua), and [`set-prerequisites.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/set-prerequisites.lua) as one paired tech-tree surface.
- Treat [`vanilla-updates/generic.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/generic.lua), [`recipes.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/recipes.lua), [`techs.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/techs.lua), and [`other.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/other.lua) as global mutation passes, not isolated vanilla tweaks.
- For planet, asteroid, route, crusher, rail-in-space, or planet-science changes, check [`more-asteroids.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/more-asteroids.lua), [`vanilla-updates/space-science.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/space-science.lua), [`vanilla-updates/space-rails.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/space-rails.lua), [`vanilla-updates/space-age.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/space-age.lua), and [`vanilla-updates/planets/`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/planets).
- For icon, locale, soundtrack, Solar Matrix, or science-pack visual edits, check [`icon-updates.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/icon-updates.lua), [`locale-updates.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/locale-updates.lua), [`vanilla-updates/visuals.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/vanilla-updates/visuals.lua), [`music-patches.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/music-patches.lua), and [`solar-matrix.lua`](../../../exotic-space-industries-remembrance/scripts/data-updates/solar-matrix.lua) before the data-final presentation passes.
- For optional-mod bridges, use `esir-dependency-intel` and inspect the guarded patch module plus shared helpers such as [`lib/loaders.lua`](../../../exotic-space-industries-remembrance/lib/loaders.lua). Refresh the dependency catalog when declared dependencies or compatibility touchpoints change.
- When a data-updates prototype name is consumed at runtime, especially railgun cooling or flammable rupture effects, keep prototype, runtime, locale, and QC expectations paired in the same change.

## Data-Final Progression Touchpoints

Data-final is where many earlier prototype declarations are deliberately overwritten. Check these passes before assuming a source prototype's first shape is the final gameplay contract.

- For tech, science-pack, planet-discovery, research-trigger, tech-cost, tech-weight, or prerequisite edits, check [`final-tech-fixes.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/final-tech-fixes.lua), [`set-age-packs.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/set-age-packs.lua), [`set-prerequisites.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/set-prerequisites.lua), [`tech-weight-badges.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/tech-weight-badges.lua), and optional compatibility restores.
- For recipe, productivity, merged item, barrel capacity, science-yield, or Quality recycling edits, check [`final-recipe-fixes.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/final-recipe-fixes.lua) and [`recycling.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/recycling.lua). Late item merges can leave stale recycling aliases that need explicit cleanup.
- For fuels, burnables, labs, science packs, item weights, stack behavior, rocket-stack behavior, or synthetic burn recipes, check [`items.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/items.lua), [`labs.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/labs.lua), [`camp-fire.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/camp-fire.lua), and then [`fuel-glow.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/fuel-glow.lua).
- For optional mod integrations that intentionally win late, inspect [`compatibility.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/compatibility.lua), [`compatibility-lignumis.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/compatibility-lignumis.lua), [`compatibility-muluna.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/compatibility-muluna.lua), and guarded blocks such as [`krastorio-patches.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/krastorio-patches.lua). Say explicitly when a compatibility override is meant to beat generic ESIR passes.
- For damage types, enemies, hostile turrets, armor, vehicles, gate difficulty, collision masks, or special weapon scaling, check [`exotic-damage-resistances.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/exotic-damage-resistances.lua), [`enemy-difficulty.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/enemy-difficulty.lua), [`gate-difficulty.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/gate-difficulty.lua), [`singularity-lance-damage-category.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/singularity-lance-damage-category.lua), and [`emerald-apocalypse-hover-tank.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/emerald-apocalypse-hover-tank.lua).

## Data-Final Presentation Touchpoints

When a patch adds, renames, removes, or materially changes visible ESIR entities, items, fuels, reactor fuels, recipe visuals, technology weight markers, death effects, sound cues, hit effects, or render-bundle roles, treat the late presentation passes as update candidates instead of leaving them to drift.

- [`final-tint-pass.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/final-tint-pass.lua): curated recipe `crafting_machine_tint` for generic and cross-cutting recipe families.
- [`fuel-glow.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/fuel-glow.lua): `fuel_glow_color`, burner/reactor light flicker, reactor default glow colors, and high-temperature reactor recipe glow.
- [`item-glow-overlays.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/item-glow-overlays.lua): startup-controlled item picture glow/light flattening for ESIR items and modified vanilla science packs.
- [`death-explosions.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/death-explosions.lua): dynamic family assignments, bespoke `dying_explosion` prototypes, particles, shards, delayed effects, and audits for visible prototypes.
- [`entity-presentation.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation.lua), [`entity-presentation-machines.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-machines.lua), and [`entity-presentation-combat.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/entity-presentation-combat.lua): player-placeable entity presentation registry entries, hit effects, open/close sounds, Factoriopedia simulations, machine/logistics groups, combat, rolling stock, and vehicles.
- [`tech-weight-badges.lua`](../../../exotic-space-industries-remembrance/scripts/data-final-updates/tech-weight-badges.lua) and [`lib/tech-weighting.lua`](../../../exotic-space-industries-remembrance/lib/tech-weighting.lua): final technology icon marker overlays for weighted or repeated research chains.
- If one of these modules is intentionally not changed after a relevant source edit, make that choice explicit in the final report or a nearby code comment when it prevents future confusion.

## ESIR QC Helpers

- Keep reusable ESIR-only QC companion mods in this skill's `assets/` folder instead of leaving them only in `.factorio-qc`.
- The beacon overload geometry helper lives at [`assets/zzz-beacon-overload-geometry-qc_0.0.1`](./assets/zzz-beacon-overload-geometry-qc_0.0.1). Use [`references/beacon-overload-geometry-qc-helper.md`](./references/beacon-overload-geometry-qc-helper.md) when a run needs engine/fallback receiver geometry, weighted/excluded beacon, beacon remove/re-add, long-range, or `uses_beacon_effects=false` coverage.
- The Vulcanus auric fumarole benchmark helper lives at [`assets/zzz-auric-fumarole-qc_0.0.1`](./assets/zzz-auric-fumarole-qc_0.0.1). Use [`references/auric-fumarole-qc-helper.md`](./references/auric-fumarole-qc-helper.md) when a run needs radial-band, off-center-placement, or non-Vulcanus-isolation telemetry.
- The fluid rupture helper lives at [`assets/zzz-fluid-rupture-qc_0.0.1`](./assets/zzz-fluid-rupture-qc_0.0.1). Use [`references/fluid-rupture-qc-helper.md`](./references/fluid-rupture-qc-helper.md) when a run needs deterministic fluid-safety and flammable-rupture coverage with QC snapshots from the shared rupture runtime.
- The orbital logistics cohort helper lives at [`assets/zzz-orbital-logistics-qc_0.0.1`](./assets/zzz-orbital-logistics-qc_0.0.1). Use [`references/orbital-logistics-qc-helper.md`](./references/orbital-logistics-qc-helper.md) when a run needs a save-driven cohort with live platform IDs, selector setup, coordinator arbitration, uplink leases, and structured orbital QC snapshots.
- The research hitch helper lives at [`assets/zzz-research-hitch-qc_0.0.1`](./assets/zzz-research-hitch-qc_0.0.1). Use [`references/research-hitch-qc-helper.md`](./references/research-hitch-qc-helper.md) when a run needs late-game research-completion hitch coverage with Tesla, EM train, and tech-scaling snapshots.
- The Singularity Lance helper lives at [`assets/zzz-singularity-lance-qc_0.0.1`](./assets/zzz-singularity-lance-qc_0.0.1). Use [`references/singularity-lance-qc-helper.md`](./references/singularity-lance-qc-helper.md) when a run needs dense alien-age turret sweep coverage with scripted damage and visual-slice telemetry.
- Use [`esir-research-events`](../esir-research-events/SKILL.md) before changing research receivers or interpreting scripted-research results so normal `on_research_finished` behavior and burst-safe `on_scripted_research_burst` behavior stay paired.
- The scripted research burst helper lives at [`assets/zzz-scripted-research-qc_0.0.1`](./assets/zzz-scripted-research-qc_0.0.1). Use [`references/scripted-research-qc-helper.md`](./references/scripted-research-qc-helper.md) when a run needs a deterministic `event.by_script` `research_all_technologies()` flood.
- Stage skill-owned helper mods into `.factorio-qc/fmqc/mods-live/` only for the runs that need them, enable them in `mod-list.json`, and treat the checked-in skill copy as canonical.

## Dependency Intel

Use the repo-local `esir-dependency-intel` skill when the main question is:

- which mods ESIR declares in `info.json`
- where ESIR touches a dependency at runtime or data stage
- which remote interfaces or planet integrations exist
- whether a locally installed mod is present in `%APPDATA%\Factorio\mods`, `output\tesla-run-mods`, or `.factorio-qc`

Preferred commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dependency-intel.ps1 -Task query -Scope all -Category all
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task dependency-query -Scope all -Category all
```

Refresh the dependency catalog whenever dependency declarations or compatibility touchpoints change.

## Recipe Prototype Icon And Visibility Review

Use the repo-local [`esir-recipe-icon-style`](../esir-recipe-icon-style/SKILL.md) skill when the main question is about recipe icon layers, sorting/order drift, hiding or visibility behavior, recipe signal cleanup, or comparing ESIR prototypes against the local `recipe-icons-improvement-for-esir` companion baseline.

Start non-mutating with the companion probe and recipe audit before planning source edits.

## Runtime Script Comments

Default ESIR runtime/control edits should leave helpful comments in place and add them where the next maintainer or agent would otherwise have to reconstruct intent from event wiring.

- Keep or add the `ESIR FILE MAP` header for substantial runtime modules: `owns`, `loaded_by`, `cadence`, forwarded events, `storage_roots`, GUI IDs, remote interfaces, and rebuild triggers.
- Add short orientation comments before dense state machines, lifecycle repair paths, scheduler/backstop logic, proxy-entity ownership, telemetry mirrors, migration/rebuild behavior, and Factorio API caveats.
- Prefer comments that explain why a runtime invariant exists, what owns a piece of derived state, or which event boundary keeps the module cheap.
- Avoid decorative comments and comments that only translate obvious Lua syntax. If a helper name can carry the meaning cleanly, prefer the name.
- When adding LuaLS annotations through [`esir-lua-types`](../esir-lua-types/SKILL.md), keep prose comments for intent and annotations for editor-visible shape; do not make one substitute for the other.

## Factorio Lua Docs

Use the repo-local `factorio-lua-docs` skill when the main question is about official Factorio runtime, prototype, auxiliary, or wiki scripting documentation.
Use `-Task status` first when the answer depends on the current docs cache version, and compare it with the installed Factorio version before updating installed-file surveys.

Use the repo-local `factorio-lua-assumptions` skill first when the risk is a wrong generic-Lua assumption rather than a missing symbol lookup.

Use [`esir-lua-types`](../esir-lua-types/SKILL.md) when the work should improve LuaLS/EmmyLua editor fidelity for ESIR Lua. It defaults to touched-code annotations and supports explicit whole-module or whole-codebase typing passes.

Preferred commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task status
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task refresh
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query LuaEntity -Stage runtime -RefreshIfMissing
```

## Shared Lua Helpers

When editing ESIR Lua modules, also follow the repo-local `esir-lib-first` rule set: inspect [`exotic-space-industries-remembrance/lib/lib.lua`](../../../exotic-space-industries-remembrance/lib/lib.lua) before adding new local helpers.

- Prefer `ei_lib` reuse for general string or table helpers, `data.raw` mutation, recipe or technology mutation, echo or notification formatting, tint helpers, and other cross-module utility behavior.
- If an existing `ei_lib` function is close but missing a guard, default, or narrow capability, extend it compatibly before adding a parallel local helper with overlapping behavior. For runtime queue, delayed-bucket, telemetry-gate, counter, cadence, or status-snapshot plumbing, the `Runtime Scheduler Rules` section below wins.
- Prefer `ei_lib.copy_array` for dense sequence copies, `ei_lib.copy_preset` for visual-fidelity/config preset snapshots, and `ei_lib.clamp_number` or `ei_lib.clamp_integer` for setting/cap normalization. Use `ei_lib.clamp` only when the value is already numeric.
- Prefer `ei_lib.set_custom_tooltip_fields(prototype, fields, opts)` when writing Factorio `custom_tooltip_fields`; use `opts.append = true` for compatibility pass-throughs that add rows without owning the whole tooltip.
- For scripted combat readouts, pair prototype tooltip rows with runtime `LuaEntity.custom_status` only after entity validation; see [`esir-lib-first/references/combat-readout-pattern.md`](../esir-lib-first/references/combat-readout-pattern.md).
- For startup preset/config module style, including visual-fidelity settings and runtime snapshots, read [`esir-lib-first/references/preset-config-pattern.md`](../esir-lib-first/references/preset-config-pattern.md).

## Locale Rules

- English locale remains the anchor for keys and gameplay meaning, but non-English locale edits should read as native, idiomatic game text in the target language rather than literal English calques.
- Preserve gameplay meaning, tone, and Factorio-relevant terminology while allowing sentence structure, emphasis, and phrasing to change per language.
- Do not use English placeholder text in non-English locale files unless the user explicitly asks for a temporary fallback.
- If a locale update cannot be finished confidently in the target language, say so and leave a follow-up note in [`.codex/esir/REVISIT_NOTES.md`](../../esir/REVISIT_NOTES.md) instead of shipping an obviously awkward literal translation.

## Runtime Entity Safety

- Keep generic entity safety in `ei_lib`, not in `runtime-scheduler.lua`.
- Use `ei_lib.entity_check(entity)` when code is about to read LuaEntity fields or call LuaEntity methods. It rejects valid non-entity LuaObjects such as equipment grids.
- Use `ei_lib.get_valid_entity(entity)` when normalizing an uncertain optional or stale entity input into `entity-or-nil`.
- Use `ei_lib.get_entity_unit_number(entity)` only for a safe `.unit_number` read. It does not prove the entity is valid.
- Raw `entity.unit_number` is acceptable only when validity and unit-number expectations are established immediately in the same scope, especially in tight event-local code.
- For stored, queued, delayed, generic, or cross-event entity references, separate identity from validity: extract the unit number safely, and validate the entity again before dereferencing it later.

## Relative GUI Panels

When touching ESIR runtime GUI, prefer Factorio relative panels for entity-adjacent consoles and treat the existing modules as a pattern library instead of inventing a fresh surface each time.

See [references/relative-gui-panels.md](./references/relative-gui-panels.md) before adding or refactoring entity-specific GUI.
For deeper runtime GUI creation, style standardization, and read-only audits, use [`esir-runtime-gui`](../esir-runtime-gui/SKILL.md).

- Default to `player.gui.relative` for consoles that should live beside a vanilla entity window. Match the anchor to the entity GUI type and keep the panel on the right unless the local UX needs something different.
- Use `player.gui.screen` for confirm dialogs, detached panels, or explicit fallback behavior when a relative anchor is unavailable or the panel should survive as a movable window.
- Use `mod_gui` for persistent top-button or side-panel workflows that are not tied to one opened entity.
- Keep a stable GUI root name, destroy stale roots before rebuild, and use `tags` for button or field intent instead of parsing captions.
- Separate GUI rendering from entity mutation. Future modules should keep build or update helpers narrow and validate the entity again before reading or writing runtime state.
- Treat stale-entity close paths as mandatory for entity-bound panels. If the opened entity changes or becomes invalid, close or rebuild the panel instead of assuming the root is still meaningful.
- If a runtime GUI pattern changes in a way future Codex runs should reuse, update this section and [references/relative-gui-panels.md](./references/relative-gui-panels.md) in the same patch.

## Event-First Runtime Design

Use this when designing or refactoring low-UPS runtime control. The default question is not "what cadence should this run on?" but "what exact state transitions actually matter?"

See [references/event-first-runtime.md](./references/event-first-runtime.md) before adding new scheduler work or reviving old master/slave runtime patterns.

- Start from discrete lifecycle hooks: built, revived, mined, destroyed, GUI open or close, deconstruction toggles, teleport or rotation, configuration change, and `on_object_destroyed` where a one-shot internal callback is enough.
- If steady state does not change, do nothing. Treat background polling as a fallback, not the first draft.
- Key storage by the visible entity's unit number. Helper entities, proxy graphs, or extra bookkeeping tables should be derived state that can be rebuilt or destroyed symmetrically.
- Gate work on actual relevance. Empty prototype sets, disabled features, or zero tracked entities should early-return instead of keeping idle handlers warm.
- Keep broad world scans, repair sweeps, and migration reconciliation out of steady-state runtime. Reserve them for `on_configuration_changed`, explicit repair commands, or deliberate refresh paths.
- Use bounded scheduler work only when events alone cannot provide fairness, backlog draining, live-set scans, or eventual-consistency repair. When a scheduler is necessary, keep event hooks as the front door and the scheduler as the backstop.
- Treat legacy master/slave scaffolding as a specialized tool, not the default answer for every helper-entity problem.
- If future runtime work changes the house event-first guidance, update this section, [references/event-first-runtime.md](./references/event-first-runtime.md), and the relevant scheduler guidance in the same patch.

## Runtime Scheduler Rules

When touching queued runtime/control code, treat [`exotic-space-industries-remembrance/lib/runtime-scheduler.lua`](../../../exotic-space-industries-remembrance/lib/runtime-scheduler.lua) as the default shared helper layer instead of building one-off queue math in a feature module.

See [references/runtime-scheduler-guidelines.md](./references/runtime-scheduler-guidelines.md) for the repo-specific scheduler conventions Codex should check before adding new runtime queue logic.

- `on_tick` or scheduled service is a backstop, not the first instinct. Before adding a new cadence, check [references/event-first-runtime.md](./references/event-first-runtime.md) and be explicit about which invariant events alone cannot maintain.
- Runtime scripts should strive to use `event.tick` over `game.tick` wherever possible.
- In `on_tick` and other event callbacks, prefer `event.tick` and pass it through call chains instead of re-reading `game.tick`.
- Only fall back to `game.tick` when there is no event context, such as status helpers, load-time repair helpers, or utility functions called outside an event callback.
- Do not add duplicate local tick helpers, queue-length helpers, delayed-bucket walkers, telemetry gates, or status-snapshot plumbing if `runtime-scheduler.lua` already covers the need.
- Prefer `ensure_queue`, `queue_peek`, `queue_push`, `queue_push_unique`, `queue_pop`, `queue_pop_matching`, `queue_pop_queued`, `queue_remove_value`, `clear_queue`, `queue_length`, `queue_item_count`, `audit_queue`, and `compact_queue` over ad hoc `head/tail/items` logic.
- If a module intentionally leaves tombstoned values in `queue.items` and treats `queue.queued` as the live-set, do not swap in plain `queue_pop` blindly. Prefer `queue_pop_queued` or another compatible shared helper.
- If a module keeps queue liveness in module-owned state instead of `queue.queued`, prefer `queue_pop_matching` or another compatible shared helper over reviving a private dequeue loop.
- Prefer `ensure_delayed_buckets`, `delayed_schedule`, `delayed_take_due`, `delayed_bucket_count`, and `delayed_item_count` over bespoke delayed-tick tables.
- Keep `control.lua` as the only top-level dispatcher. Modules should own their local queues and cadence decisions, but should not grow parallel top-level scheduling surfaces.
- If a runtime module exports counters, status, or debug data, prefer `ensure_module_state`, `bump_counter`, `set_module_status`, `get_module_status`, `status_snapshot`, and the shared `/ei_runtime_status` flow instead of inventing a second telemetry channel.
- Heartbeat telemetry is default-off for release. Any periodic status polling must be gated so disabled telemetry is truly cheap.
- Use `write_telemetry` only behind a cheap gate, and keep `log_snapshot` for deliberate debug/QC paths rather than routine tick work.
- A new helper should only be added when `runtime-scheduler.lua` cannot express the behavior cleanly. Duplicating tick code or queue code is a design smell in this repo now.
- `runtime-scheduler.lua` stays entity-agnostic. If queued or delayed work carries `LuaEntity` payloads, modules must validate those payloads on dequeue, not just when they are enqueued.
- When adding or changing a shared scheduler helper, update this section and `references/runtime-scheduler-guidelines.md` in the same patch so future Codex runs inherit the new helper list and semantic caveats.
- If a scheduler migration intentionally stops short because module semantics stay local, record the reason and next safe move in [`.codex/esir/REVISIT_NOTES.md`](../../esir/REVISIT_NOTES.md).

## Save Resolution

- Prefer `-SaveId` over `-SavePath`.
- The wrapper resolves `-SaveId` through `.codex/esir/save-catalog.json`.
- Save-catalog entries may declare `helper_mods` with asset paths and auto-stage tasks. The repo-side `runtime-benchmark` path can restage those helper mods automatically, but wrapper-driven `qc-runtime`, `qc-preview`, and `qc-full` still require manual or pre-staged helper sync until the lower QC sync path grows save-aware helper staging.
- When neither is provided, `qc-runtime` and `qc-preview` fall back to the catalog default for that task.

## Sidecar Roles

When parallel read-only help is useful, use the playbook in [`references/agent-playbook.md`](./references/agent-playbook.md):

- `event-lifecycle explorer`
- `gui-pattern explorer`
- `runtime-map explorer`
- `prototype-map explorer`
- `combat-readout explorer`
- `portal-scout explorer`
- `asset-pipeline explorer`
- `vanilla-prototype-lib explorer`
- `space-age-planet explorer`
- `vanilla-graphics-precedent explorer`
- `quality-recycling explorer`
- `regression explorer`
- `dependency-touchpoint explorer`
- `dependency-runtime explorer`
- `dependency-prototype explorer`
- `dependency-presence explorer`
- `stage-boundary explorer`
- `sandbox-delta explorer`
- `storage-lifecycle explorer`
- `event-determinism explorer`
- `runtime-api explorer`
- `prototype-api explorer`
- `lualib-surface explorer`
- `meld-pattern explorer`
- `core-require explorer`
- `tint-api explorer`
- `asset-mask explorer`
- `third-party-art-precedent explorer`
- `auxiliary-docs explorer`
- `wiki-guidance explorer`

Keep the main agent on orchestration and edits. Sidecars stay read-only.
