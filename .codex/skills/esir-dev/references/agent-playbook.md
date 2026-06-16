# ESIR Sidecar Playbook

Use these as light read-only sidecars when the main agent can keep moving without waiting.

Each sidecar should report:

- files inspected
- commands run
- freshness status of any manifest, cache, save, or generated artifact it relied on
- blockers first, then warnings, then optional suggestions
- confirmation that it made no writes

## `event-lifecycle explorer`

Use for:

- deciding whether a runtime system can be pure event-driven or needs bounded scheduler work
- mapping the relevant lifecycle hooks for a feature: build, destroy, deconstruct, GUI, teleport, rotation, configuration change, and `on_object_destroyed`
- comparing a target module against `zzz-nonstandard-beacons`, `beacon-overload.lua`, `matter-stabilizer.lua`, `fluid-safety.lua`, or `orbital-combinator.lua`
- spotting steady-state scans that should move into repair, migration, or explicit refresh paths
- recommending when helper entities should be a derived proxy graph versus when plain storage and event hooks are enough

## `gui-pattern explorer`

Use for:

- deciding whether a runtime panel should use `player.gui.relative`, `player.gui.screen`, or `mod_gui`
- matching a new entity console to the right `defines.relative_gui_type.*` anchor
- comparing a target module against `black-hole.lua`, `fusion-reactor.lua`, `orbital-combinator.lua`, `orbital-logistics.lua`, `alien-system.lua`, or `em-trains/gui.lua`
- spotting stale-root, stale-entity, rebuild, or close-path gaps in runtime GUI code
- drafting concise guidance for titlebar, body, tags, fallback, and lifecycle conventions

## `runtime-map explorer`

Use for:

- direct `control.lua` load-surface mapping
- event/cadence inventory
- storage/gui/remote-interface scans
- header-metadata suggestions for runtime modules
- checking whether queued-control edits should use `lib/runtime-scheduler.lua` instead of custom tick/queue helpers
- spotting duplicated `event.tick` / `game.tick` plumbing or legacy fallback schedulers that should be consolidated

## `prototype-map explorer`

Use for:

- `data.lua`, `data-updates.lua`, and `data-final-fixes.lua` aggregator and require-order mapping
- prototype subtree ownership questions
- pack-to-pack asset dependency scans
- prototype header-metadata suggestions
- checking whether data-updates global mutation passes or data-final progression passes overwrite the prototype surface being edited
- checking whether relevant entity, item, fuel, recipe, tech, asset, or effect changes should also update `scripts/data-final-updates/final-tint-pass.lua`, `fuel-glow.lua`, `item-glow-overlays.lua`, `death-explosions.lua`, `tech-weight-badges.lua`, or the `entity-presentation*` registry modules

## `combat-readout explorer`

Use for:

- mapping scripted weapon, turret, vehicle, or support-system damage readouts across prototype, runtime, locale, and research-refresh files
- comparing a target module against Singularity Lance for turret DPS `custom_status` and Emerald Apocalypse orbital shards for vehicle/support DPS readouts
- checking whether base tooltip rows belong in `custom_tooltip_fields` and live force-tuned numbers belong in `LuaEntity.custom_status`
- spotting missing build/rebuild/research/scripted-research refresh hooks for force-scaled DPS caches
- recommending where `esir-lib-first/references/combat-readout-pattern.md` should be followed before the main agent edits code

## `portal-scout explorer`

Use for:

- Mod Portal metadata triage
- license/source-url sanity checks
- shortlist note drafting
- comparing candidate mods against current repo coverage

## `asset-pipeline explorer`

Use for:

- Firefox session artifact review
- prompt-to-asset role matching
- import-plan suggestions
- non-destructive image-format checks
- checking whether an asset should reserve `team_color`, `force_trim`, or `color_mask` regions for owner-readability

## `regression explorer`

Use for:

- reading QC summaries or logs after a run
- grouping failures into runtime/data/assets/package buckets
- comparing a new run against prior artifacts under `.factorio-qc`

## `dependency-touchpoint explorer`

Use for:

- mapping which ESIR files touch a named dependency
- grouping runtime, prototype, planet, remote, and media touchpoints before the main agent edits anything
- spotting when one compatibility surface should move from one-off grep work into the checked-in dependency catalog

## `dependency-runtime explorer`

Use for:

- runtime/control dependency scans rooted in `control.lua` and `scripts/control`
- remote-call, remote-interface, and `script.active_mods` inventory work
- checking whether a dependency question is really runtime-facing or should be handed off to prototype analysis

## `dependency-prototype explorer`

Use for:

- data-stage dependency scans rooted in `data.lua`, `prototypes`, `scripts/data-updates`, and `scripts/data-final-updates`
- cataloging guarded mod patches, `mods[...]` gates, and external prototype/library references
- separating general prototype integration from planet/content-specific compatibility

## `dependency-presence explorer`

Use for:

- optional local installed-mod presence checks under `%APPDATA%\Factorio\mods`, `output\tesla-run-mods`, and `.factorio-qc`
- confirming whether a named external mod is present locally and which key files it exposes
- validating that local presence stays query-time enrichment instead of leaking into checked-in manifests

## `stage-boundary explorer`

Use for:

- deciding whether a Lua question belongs to settings, prototype/data, runtime/control, migration, console, or remote interface context
- pinning the active stage from `ei_mod.stage`, the top-level aggregator, and the loaded subtree before making API or helper assumptions
- checking whether data-stage assumptions are being imported into runtime code or runtime assumptions are being imported into prototype code
- routing exact API lookups through `factorio-lua-docs` after the stage is clear

## `sandbox-delta explorer`

Use for:

- checking whether generic Lua advice relies on libraries or behaviors Factorio changes or removes
- reviewing `require()`, `package`, `debug`, `load`, `pairs()`, `next()`, `math.random()`, or `math.randomseed()` assumptions
- comparing a proposed Lua pattern against `factorio-lua-assumptions` before the main agent edits code

## `storage-lifecycle explorer`

Use for:

- checking whether runtime state belongs in `storage`, locals, module upvalues, migrations, `on_init`, `on_load`, or `on_configuration_changed`
- spotting unsafe stored functions, stale `LuaObject` dereferences, missing `.valid` checks, and metatable-registration gaps
- separating durable identity keys such as `unit_number` from live object validity

## `event-determinism explorer`

Use for:

- checking event-registration, event-order, and deterministic-runtime assumptions before control-stage changes
- reviewing whether `event.tick` can be passed through instead of rereading `game.tick`
- spotting RNG or iteration-order assumptions that need Factorio-specific handling

## `runtime-api explorer`

Use for:

- exact runtime symbol lookup through `factorio-lua-docs`
- class, method, attribute, event, define, GUI, remote-interface, migration, and storage documentation checks
- returning official URLs for any API claim the main agent will rely on
- reporting the docs cache version used for runtime API claims

## `prototype-api explorer`

Use for:

- exact prototype symbol lookup through `factorio-lua-docs`
- prototype inheritance, property, concept, and data.raw documentation checks
- separating prototype declaration rules from runtime prototype-read APIs
- reporting the docs cache version used for prototype API claims

## `lualib-surface explorer`

Use for:

- mapping the installed Factorio `data/core/lualib` modules and Factorio version
- finding vanilla and ESIR usage examples for a core lualib helper
- reporting whether the result came from live Factorio files, cached docs, or repo source

## `meld-pattern explorer`

Use for:

- deciding whether a prototype patch should use `meld`, `util.merge`, direct mutation, or ESIR `ei_lib`
- checking `meld.delete`, `meld.overwrite`, `meld.invoke`, and `meld.append` semantics against the installed core file
- warning when a proposed `meld` patch would mutate shared tables, rely on append order, or store functions/control markers

## `core-require explorer`

Use for:

- verifying core lualib require forms such as short names, `__core__.lualib.*`, and `__core__/lualib/*`
- finding nearby vanilla or ESIR precedent before changing an import
- separating data/prototype helpers from runtime/scenario helpers before the main agent edits code

## `vanilla-prototype-lib explorer`

Use for:

- mapping installed Base, Space Age, Quality, or Elevated Rails prototype helper modules and Factorio version
- finding ESIR and vanilla usage examples for `__base__`, `__space-age__`, `__quality__`, or `__elevated-rails__` imports
- separating vanilla prototype helper modules from true `data/core/lualib` helpers before the main agent edits code
- reporting whether the result came from live Factorio files, cached docs, or repo source

## `space-age-planet explorer`

Use for:

- inspecting Space Age asteroid spawn definitions, route constants, probability interpolation, and `spawn_definitions`
- checking planet map-gen helper usage before adding or changing ESIR planet generation
- mapping procession, cargo-pod, platform-to-planet, and planet-to-platform helper modules
- warning when Space Age dependency assumptions are not established for the target pack or data stage

## `vanilla-graphics-precedent explorer`

Use for:

- reading vanilla picture modules as precedent for graphics_set, layer ordering, shadows, lights, masks, working visualisations, status lamps, and frozen variants
- summarizing `util.sprite_load` option shape and table layout without copying large vanilla source blocks or art paths into ESIR
- checking whether a target graphics question should route to asset pipeline skills or official prototype docs instead

## `quality-recycling explorer`

Use for:

- verifying `__quality__/prototypes/recycling` exports and current Quality recycling eligibility behavior
- checking ESIR recycling regeneration precedents before data-final-fixes edits
- deciding whether a change belongs in ESIR recipe policy before calling the vanilla recycling generator

## `tint-api explorer`

Use for:

- exact official lookup of runtime tint, player color, force color, rolling-stock color, and sprite/animation tint behavior
- confirming whether a target prototype supports `LuaEntity.color`, player color inheritance, rolling-stock color copying, or explicit script-render `tint`
- checking `apply_runtime_tint`, `tint_as_overlay`, `tint`, `LuaRendering::draw_sprite`, `LuaRendering::draw_animation`, and `LuaRenderObject::color` before the main agent writes guidance or code
- warning when `LuaForce.color` exists but is not an official universal source for entity-mask tinting

## `asset-mask explorer`

Use for:

- reviewing preset render bundles and staged exports for base, shadow, glow/light, runtime color mask, water reflection, and baked-color roles
- checking whether `object_mask_0.png` is a runtime-tint mask, manual post-processing source, or unused evidence
- verifying that proposed mask layers match base frame dimensions, frame count, direction count, shift, scale, and Factorio layer placement
- spotting accidental tinting of neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, or baked ESIR chromatic assets

## `third-party-art-precedent explorer`

Use for:

- read-only precedent inspection of installed or public mods that demonstrate prototype graphics patterns
- summarizing implementation shape without copying third-party art, code, filenames, or license-sensitive content into ESIR
- checking `FluidWagonColorMask` by yeahtoast as a color-mask precedent: `flags = {"mask"}`, `apply_runtime_tint = true`, rotated/sloped fluid-wagon mask layers, `additional_pastable_entities`, and `on_entity_settings_pasted`
- reporting source, license, version, and whether the files came from local installed mods or public Mod Portal metadata

## `auxiliary-docs explorer`

Use for:

- official auxiliary docs such as Data Lifecycle, Storage, Libraries and functions, Mod Structure, Migrations, Instrument Mode, and JSON docs
- resolving broad "how should Factorio Lua behave here?" questions after `factorio-lua-assumptions` identifies the risk

## `wiki-guidance explorer`

Use for:

- official wiki scripting guidance such as script interfaces, localisation, console, command-line parameters, and data.raw
- checking tutorial-level behavior when the API JSON does not answer the workflow question directly

Main-agent rule: sidecars analyze and summarize. The main agent still owns edits, wrapper invocations, and final integration.
