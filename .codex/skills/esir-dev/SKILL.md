---
name: esir-dev
description: "ESIR-first repo-local development surface for Exotic Space Industries: Remembrance. Use when Codex should work faster inside this workspace by relying on checked-in manifests, the ESIR wrapper command, Factorio QC delegation, Mod Portal scouting, save catalog resolution, art/browser session handoff, cache diffing, packaging, or ESIR-specific runtime/prototype maps."
---

# ESIR Dev

Use the repo-local wrapper first:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dev.ps1 -Task doctor
```

This skill is the ESIR operator surface. It composes the existing engine-layer skills instead of replacing them:

- `factorio-mod-qc` for headless Factorio validation, package dry-runs, and Mod Portal metadata
- `chatgpt-firefox-companion` for supervised Firefox image sessions

## Task Map

- `doctor`: verify repo shape, engine paths, Factorio/Firefox discovery, and pack topology
- `manifest-refresh`: regenerate checked-in manifests under `.codex/esir/`, including the dependency catalog
- `dependency-refresh|dependency-query|dependency-diff`: operate on the ESIR dependency catalog and optional local installed-mod enrichment
- `preflight`: static syntax/reference/header/encoding sweeps without touching gameplay data
- `qc-fast|qc-runtime|qc-preview|qc-assets|qc-package|qc-full`: delegate to the Factorio QC harness
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
- Keep raw caches in `.factorio-qc` or `output`; stable manifests stay checked in.
- The checked-in dependency catalog is intentionally limited to declared pack dependencies plus ESIR touchpoints. Local installed mod roots are query-time enrichment only.
- Before applying generic Lua advice to ESIR code, use the repo-local `factorio-lua-assumptions` skill to check Factorio's staged lifecycle, sandboxed libraries, storage rules, `require()` behavior, deterministic runtime changes, and LuaObject validity semantics.
- For official Factorio API or wiki questions, prefer the repo-local `factorio-lua-docs` skill and `scripts\invoke-factorio-lua-docs.ps1` before broad web search or memory.
- `pack-deploy` is intentionally mutating. Prefer `pack-dryrun` unless the user explicitly wants `%APPDATA%\Factorio\mods` updated.
- Encoding detection is part of `preflight` and the `qc-*` wrapper surface. Pass `-FixEncoding` when you want the harness to rewrite non-UTF-8 or repaired mojibake sources as UTF-8.
- Keep commentary current during ESIR work. As context changes, say what you are inspecting, what you are changing next, and what you verified; do not go quiet through long repo-specific work.
- When a shared helper surface changes in a way future Codex runs should follow, update the matching skill/reference guidance in the same patch.
- When a patch leaves deferred implementation work, migration debt, upgrade hooks, or intentionally local behavior worth revisiting, add or update a short note in [`.codex/esir/REVISIT_NOTES.md`](../../esir/REVISIT_NOTES.md) in the same patch. Remove or close the note when the follow-up is done.
- Runtime scripts should strive to use `event.tick` over `game.tick` wherever an event context already provides the tick.
- When editing non-English locale files, write bespoke idiomatic translations for the target language instead of mechanically mirroring the English text.
- For entity-specific runtime GUI, prefer `player.gui.relative` first. Reach for `player.gui.screen` only when the panel is modal or intentionally detachable, and use `mod_gui` only for persistent global mod controls.
- Default new runtime work to event-first control. Before adding `on_tick`, `on_nth_tick`, or a persistent queue, check whether explicit lifecycle hooks, delayed one-shots, or `script.register_on_object_destroyed` can express the behavior cleanly.

## ESIR QC Helpers

- Keep reusable ESIR-only QC companion mods in this skill's `assets/` folder instead of leaving them only in `.factorio-qc`.
- The Vulcanus auric fumarole benchmark helper lives at [`assets/zzz-auric-fumarole-qc_0.0.1`](./assets/zzz-auric-fumarole-qc_0.0.1). Use [`references/auric-fumarole-qc-helper.md`](./references/auric-fumarole-qc-helper.md) when a run needs radial-band, off-center-placement, or non-Vulcanus-isolation telemetry.
- The fluid rupture helper lives at [`assets/zzz-fluid-rupture-qc_0.0.1`](./assets/zzz-fluid-rupture-qc_0.0.1). Use [`references/fluid-rupture-qc-helper.md`](./references/fluid-rupture-qc-helper.md) when a run needs deterministic fluid-safety and flammable-rupture coverage with QC snapshots from the shared rupture runtime.
- The orbital logistics cohort helper lives at [`assets/zzz-orbital-logistics-qc_0.0.1`](./assets/zzz-orbital-logistics-qc_0.0.1). Use [`references/orbital-logistics-qc-helper.md`](./references/orbital-logistics-qc-helper.md) when a run needs a save-driven cohort with live platform IDs, selector setup, coordinator arbitration, uplink leases, and structured orbital QC snapshots.
- The research hitch helper lives at [`assets/zzz-research-hitch-qc_0.0.1`](./assets/zzz-research-hitch-qc_0.0.1). Use [`references/research-hitch-qc-helper.md`](./references/research-hitch-qc-helper.md) when a run needs late-game research-completion hitch coverage with Tesla, EM train, and tech-scaling snapshots.
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

## Factorio Lua Docs

Use the repo-local `factorio-lua-docs` skill when the main question is about official Factorio runtime, prototype, auxiliary, or wiki scripting documentation.

Use the repo-local `factorio-lua-assumptions` skill first when the risk is a wrong generic-Lua assumption rather than a missing symbol lookup.

Preferred commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task refresh
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query LuaEntity -Stage runtime -RefreshIfMissing
```

## Shared Lua Helpers

When editing ESIR Lua modules, also follow the repo-local `esir-lib-first` rule set: inspect [`exotic-space-industries-remembrance/lib/lib.lua`](../../../exotic-space-industries-remembrance/lib/lib.lua) before adding new local helpers.

- Prefer `ei_lib` reuse for general string or table helpers, `data.raw` mutation, recipe or technology mutation, echo or notification formatting, tint helpers, and other cross-module utility behavior.
- If an existing `ei_lib` function is close but missing a guard, default, or narrow capability, extend it compatibly before adding a parallel local helper with overlapping behavior. For runtime queue, delayed-bucket, telemetry-gate, counter, cadence, or status-snapshot plumbing, the `Runtime Scheduler Rules` section below wins.

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
- `portal-scout explorer`
- `asset-pipeline explorer`
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
- `auxiliary-docs explorer`
- `wiki-guidance explorer`

Keep the main agent on orchestration and edits. Sidecars stay read-only.
