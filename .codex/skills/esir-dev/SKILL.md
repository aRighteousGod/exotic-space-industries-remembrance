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
- `manifest-refresh`: regenerate checked-in manifests under `.codex/esir/`
- `preflight`: static syntax/reference/header/encoding sweeps without touching gameplay data
- `qc-fast|qc-runtime|qc-preview|qc-assets|qc-package|qc-full`: delegate to the Factorio QC harness
- `portal-scout`: build or refresh `.codex/esir/portal-shortlist.json`
- `diff`: compare live source, seeded caches, package outputs, and shortlist freshness
- `art-start|art-collect|art-review|art-validate`: stage and review supervised Firefox image sessions
- `pack-dryrun`: non-destructive packaging through the QC harness
- `pack-deploy`: intentional local deployment through the legacy root scripts
- `full`: run `doctor -> manifest-refresh -> preflight -> qc-full -> portal-scout -> diff -> pack-dryrun`

## Operating Rules

- Treat checked-in manifests under `.codex/esir/` as the fast map, not the authority. The repo source is still canonical.
- Treat headless Factorio runs as authoritative when they disagree with static sweeps.
- Treat cached run-mod directories as dependency seeds only. Live repo pack folders are the source of truth.
- Keep raw caches in `.factorio-qc` or `output`; stable manifests stay checked in.
- `pack-deploy` is intentionally mutating. Prefer `pack-dryrun` unless the user explicitly wants `%APPDATA%\Factorio\mods` updated.
- Encoding detection is part of `preflight` and the `qc-*` wrapper surface. Pass `-FixEncoding` when you want the harness to rewrite non-UTF-8 or repaired mojibake sources as UTF-8.
- When a shared helper surface changes in a way future Codex runs should follow, update the matching skill/reference guidance in the same patch.

## ESIR QC Helpers

- Keep reusable ESIR-only QC companion mods in this skill's `assets/` folder instead of leaving them only in `.factorio-qc`.
- The Vulcanus auric fumarole benchmark helper lives at [`assets/zzz-auric-fumarole-qc_0.0.1`](./assets/zzz-auric-fumarole-qc_0.0.1). Use [`references/auric-fumarole-qc-helper.md`](./references/auric-fumarole-qc-helper.md) when a run needs radial-band, off-center-placement, or non-Vulcanus-isolation telemetry.
- Stage skill-owned helper mods into `.factorio-qc/fmqc/mods-live/` only for the runs that need them, enable them in `mod-list.json`, and treat the checked-in skill copy as canonical.

## Shared Lua Helpers

When editing ESIR Lua modules, also follow the repo-local `esir-lib-first` rule set: inspect [`exotic-space-industries-remembrance/lib/lib.lua`](../../../exotic-space-industries-remembrance/lib/lib.lua) before adding new local helpers.

- Prefer `ei_lib` reuse for general string or table helpers, `data.raw` mutation, recipe or technology mutation, echo or notification formatting, tint helpers, and other cross-module utility behavior.
- If an existing `ei_lib` function is close but missing a guard, default, or narrow capability, extend it compatibly before adding a parallel local helper with overlapping behavior. For runtime queue, delayed-bucket, telemetry-gate, counter, cadence, or status-snapshot plumbing, the `Runtime Scheduler Rules` section below wins.

## Runtime Entity Safety

- Keep generic entity safety in `ei_lib`, not in `runtime-scheduler.lua`.
- Use `ei_lib.entity_check(entity)` when code is about to read LuaEntity fields or call LuaEntity methods.
- Use `ei_lib.get_valid_entity(entity)` when normalizing an uncertain optional or stale entity input into `entity-or-nil`.
- Use `ei_lib.get_entity_unit_number(entity)` only for a safe `.unit_number` read. It does not prove the entity is valid.
- Raw `entity.unit_number` is acceptable only when validity and unit-number expectations are established immediately in the same scope, especially in tight event-local code.
- For stored, queued, delayed, generic, or cross-event entity references, separate identity from validity: extract the unit number safely, and validate the entity again before dereferencing it later.

## Runtime Scheduler Rules

When touching queued runtime/control code, treat [`exotic-space-industries-remembrance/lib/runtime-scheduler.lua`](../../../exotic-space-industries-remembrance/lib/runtime-scheduler.lua) as the default shared helper layer instead of building one-off queue math in a feature module.

See [references/runtime-scheduler-guidelines.md](./references/runtime-scheduler-guidelines.md) for the repo-specific scheduler conventions Codex should check before adding new runtime queue logic.

- Prefer `event.tick` inside `on_tick` or other event callbacks. Only fall back to `game.tick` when there is no event context.
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

## Save Resolution

- Prefer `-SaveId` over `-SavePath`.
- The wrapper resolves `-SaveId` through `.codex/esir/save-catalog.json`.
- When neither is provided, `qc-runtime` and `qc-preview` fall back to the catalog default for that task.

## Sidecar Roles

When parallel read-only help is useful, use the playbook in [`references/agent-playbook.md`](./references/agent-playbook.md):

- `runtime-map explorer`
- `prototype-map explorer`
- `portal-scout explorer`
- `asset-pipeline explorer`
- `regression explorer`

Keep the main agent on orchestration and edits. Sidecars stay read-only.
