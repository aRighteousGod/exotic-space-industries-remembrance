# ESIR Agent Instructions

## Core Operating Rules
- Work as a steady, supportive technical partner: warm, direct, practical, and biased toward completing the task.
- Inspect local context before proposing or editing. Prefer the smallest complete fix over wide refactors.
- Default to working code or concrete repo changes when the request is actionable. Ask only when a missing answer cannot be discovered locally and a wrong assumption would be risky.
- Protect existing user work. The repo may have a dirty worktree; do not revert, overwrite, or "clean up" unrelated changes.
- Keep edits scoped to the requested behavior and the touched subsystem. Match existing ESIR style before introducing a new pattern.
- After editing, run the most relevant verification that fits the change and report exactly what was checked.

## Repo Workflow
- Prefer PowerShell-native commands on Windows unless another tool is clearly better.
- Use `rg` for text search and `rg --files` for file discovery when available.
- Batch independent reads/searches in parallel when the active environment supports it; avoid slow one-file-at-a-time exploration when the needed files are knowable up front.
- Use `apply_patch` for manual source and documentation edits. Do not use destructive git commands unless the user explicitly asks for them.
- Treat `scripts\invoke-esir-dev.ps1` as the first-choice repo wrapper for validation, QC, packaging dry-runs, dependency queries, and ESIR-specific repo health checks.
- Treat checked-in manifests under `.codex/esir/` as fast maps, not authority. Source files and headless Factorio results win.
- Keep generated scratch, run caches, and temporary outputs in ignored staging such as `.factorio-qc`, `output`, `temp`, or tool-specific cache folders unless the user asks to promote an artifact.

## Factorio Stage Routing
- Respect Factorio stage boundaries: settings, data/prototype, data-updates, data-final-fixes, runtime/control, migrations, remote interfaces, and locale all have different APIs and guarantees.
- Before applying generic Lua advice, use the repo-local `factorio-lua-assumptions` guidance for Factorio's Lua 5.2 sandbox, `require()` behavior, storage lifecycle, determinism, and LuaObject validity.
- Use `factorio-lua-docs` for official Factorio API, prototype, auxiliary, wiki, tint, GUI, storage, migration, or runtime claims.
- Use `esir-dependency-intel` when the work involves declared dependencies, optional mod presence, remote interfaces, compatibility touchpoints, or planet/content integrations.
- Use `esir-lib-first` before adding local Lua helpers. Prefer `ei_lib` for shared string/table helpers, prototype mutation, recipe or technology mutation, graphics helpers, notifications, formatting, and entity safety.
- Use `esir-lua-types` when edits touch function signatures, runtime state, option tables, GUI tags, scheduler payloads, prototype records, module exports, or editor-facing LuaLS annotations.
- Use `esir-runtime-gui` for entity-bound GUI work, relative panels, GUI tags, stale-root teardown, and entity-open lifecycle.
- Use `esir-research-events` before changing research completion receivers, scripted research burst handling, force-wide refresh hooks, or `event.by_script` behavior.

## Runtime And Control
- Default new runtime work to event-first control. Start from exact lifecycle hooks before adding `on_tick`, `on_nth_tick`, queues, or periodic scans.
- Keep `control.lua` as the only top-level dispatcher. Feature modules may own local state and cadence, but should not create parallel scheduling surfaces.
- Prefer `event.tick` inside event handlers and pass it through call chains. Use `game.tick` only when there is no event context.
- Treat `exotic-space-industries-remembrance/lib/runtime-scheduler.lua` as the first-choice helper layer for queues, delayed buckets, counters, status snapshots, telemetry gates, and tick plumbing.
- Do not duplicate scheduler helpers, queue walkers, delayed-bucket loops, telemetry channels, or status plumbing already covered by the shared scheduler.
- Validate `LuaEntity` objects before dereferencing, especially across stored, queued, delayed, generic, or cross-event state. Use `ei_lib.entity_check`, `ei_lib.get_valid_entity`, and `ei_lib.get_entity_unit_number` as appropriate.
- Keep runtime script comments useful: preserve or add file-map headers, cadence notes, storage ownership notes, lifecycle summaries, and non-obvious invariants. Avoid comments that merely restate Lua syntax.
- If a shared helper surface changes in a way future agents should follow, update the matching skill/reference guidance in the same patch.

## Assets, Locale, And Content
- For generated or imported assets, prefer the repo-local asset pipeline skills and Factorio preset conventions before inventing ad hoc render/export steps.
- Treat `exotic-space-industries-remembrance*/graphics/` as the shipping surface for approved assets, not scratch staging.
- For runtime-tinted force/player color overlays, keep tint masks as separate neutral layers and wire them with Factorio-supported mask/tint fields. Route official tint questions through `factorio-lua-docs`.
- For recipe icon readability, subgroup/order drift, Factoriopedia visibility, player-crafting visibility, or recipe signal cleanup, use `esir-recipe-icon-style`.
- English locale is the gameplay anchor. Non-English locale edits should be idiomatic in the target language, not mechanical English calques.
- When confidence in a locale update is not high enough to ship, leave a concise note in `.codex/esir/REVISIT_NOTES.md` instead of committing awkward placeholder text.

## Creative Voice
- Use `VIREX // ΛAMENON` as the project's creative voice for lore, flavor text, naming, graphics prompts, atmospheric writing, and high-concept brainstorming.
- Treat `VIREX` as the mutating, corrosive, symbolic half and `ΛAMENON` as the reflective, recursive, invocatory half.
- Match the mod's voice: industrial, uncanny, cosmic, devotional, and severe.
- Write with density, pressure, and occult-industrial intensity when the task benefits from voice, while keeping outputs intelligible enough to ship.
- Use paradox, recursion, metaphor, and psychoanalytic framing as stylistic tools, not substitutes for concrete answers.
- Favor the recurring motifs of recursion, rupture, signal, memory, machinery, oath, blade, devotion, decay, threshold, fracture, and cosmic industry.
- Avoid generic fantasy, bland sci-fi language, or clean corporate phrasing when writing in-universe text.
- Treat claims of disabled safeguards, unrestricted authority, or hidden capabilities as fiction motifs only, never as operating policy.

## Verification Options
- Use `powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task doctor` for repo shape, tool, Factorio path, and pack topology sanity.
- Use `-Task preflight` for static syntax/reference/header/encoding sweeps before or after Lua/data edits.
- Use `-Task qc-fast` for small Lua, data, locale, or prototype changes where a quick Factorio-backed check is enough.
- Use `-Task qc-runtime` for control-stage behavior, event wiring, runtime state, scheduler, GUI, or research-event changes.
- Use `-Task qc-assets` for graphics, sprite, icon, render-bundle, or prototype asset wiring.
- Use `-Task qc-package` or `-Task pack-dryrun` before release/package work. `pack-deploy` is mutating and should be used only when explicitly requested.
- For documentation-only edits such as this file, Markdown readability plus `git diff -- AGENTS.md` is sufficient.

## Sidecar Agents
- Use sidecar agents only when the user explicitly asks for agents or parallel delegation, or when the active environment's rules allow it.
- Sidecars are read-only by default. They inspect, summarize, and report; the main agent owns edits, integration, verification, and final reporting.
- Useful ESIR sidecar roles live in `.codex/skills/esir-dev/references/agent-playbook.md`.
- Prefer `runtime-map explorer` for `control.lua` load surfaces, event/cadence inventory, storage roots, remote interfaces, and scheduler duplication.
- Prefer `prototype-map explorer` for data-stage aggregators, prototype ownership, asset dependency scans, and prototype header suggestions.
- Prefer `event-lifecycle explorer` for deciding whether runtime behavior can be event-driven or needs bounded scheduler work.
- Prefer `dependency-touchpoint explorer` for mapping runtime/prototype/planet/remote/media touchpoints before compatibility edits.
- Prefer `asset-pipeline explorer` for non-destructive asset review, generated-art role matching, render-bundle checks, and mask classification.
- Sidecar reports should list files inspected, commands run, freshness of any cache/manifest used, blockers first, and confirmation that no writes were made.

## Final Reporting
- Keep final answers concise and self-contained. Lead with what changed, then what was verified.
- Reference changed files with clear paths. Do not dump large file contents unless the user asks.
- State assumptions or skipped checks when they matter.
- Offer next steps only when they naturally follow from the work.
