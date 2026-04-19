# ESIR Revisit Notes

Use this file for short, durable follow-up notes when a patch intentionally leaves implementation debt, upgrade hooks, partial migrations, or known upgrade work behind.

Keep entries compact and practical:

- `YYYY-MM-DD | area | status | summary`
  - `Files:` absolute or repo-relative paths
  - `Next safe move:` the smallest sensible follow-up

Close or remove entries in the same patch that resolves them.

## Open

- `2026-04-18 | beacon-overload | open | steady-state enabled checks now ride the cached storage flag and internal recount paths reuse the same module state, so the next safe refinement is to benchmark whether `queued_units` and `queued_chunk_keys` are worth collapsing into the shared scheduler's unique-queue helpers.` 
  - `Files:` `exotic-space-industries-remembrance/scripts/control/beacon-overload.lua`, `exotic-space-industries-remembrance/scripts/control/global.lua`
  - `Next safe move:` profile one large rebuild, and only if queue bookkeeping still shows up, migrate the machine/chunk dedupe flow to `queue_push_unique`-style shared helpers without changing current rebuild order.

- `2026-04-18 | research-hitch-qc | open | the dedicated research-hitch benchmark stayed above its prior median after the latest hot-path trims, but the touched patch mostly affected normal tech-scaling cache reads and scripted-burst bookkeeping, not the helper's steady queued-research workload. The helper now records pre/post completion runtime snapshots through the QC remote bridge, and direct headless validation fixed stale helper assumptions around `table.deepcopy`, `write_file`, and `research_queue_enabled`, so the next pass can inspect actual Tesla and EM queue state around each 60-tick completion instead of inferring from medians alone.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/tech-scaling.lua`, `exotic-space-industries-remembrance/control.lua`, `exotic-space-industries-remembrance/scripts/control/teslas-legacy.lua`, `exotic-space-industries-remembrance/scripts/control/em-trains/charger.lua`, `.codex/skills/esir-dev/assets/zzz-research-hitch-qc_0.0.1/control.lua`
  - `Next safe move:` either teach the wrapper benchmark path to restage the helper mod for `research-hitch`, or keep using a direct staged helper pass, then inspect the helper's `pre-complete`, `post-immediate`, `post-plus-1`, and `post-plus-2` snapshot blocks before deciding whether the remaining regression is Tesla variant-sync work, EM rollout pressure, scenario drift, or helper overhead.

- `2026-04-18 | orbital-logistics | open | the cohort service path now skips stable signature rebuilds, reuses same-pass Need payload lookups, reuses the transponder registry across the same-pass retry, precomputes policy selector candidate order per build, keeps reconcile-time lease target counts local, stages a same-build ordered ready-job list, memoizes bound-silo lookups for each uplink across one service pass, threads that memo through launch, and derives ready-job counts from the staged ready list, so the next likely orbital UPS hotspot is the remaining repeated uplink passes and render-time binding reads around the dispatch lane surface.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/orbital-logistics.lua`
  - `Next safe move:` benchmark the remaining uplink loops plus `build_uplink_pages()` / GUI binding reads on the seeded orbital QC scenario, then decide whether the next safe win is a same-pass uplink-state staging shortcut or a narrow render-time binding cache that still preserves current lease and lane behavior.

- `2026-04-17 | orbital-logistics | open | selector lease cleanup, duplicate-target blocking, coordinator failover, demand-fairness rotation, and binding-loss recovery are covered, but the cohort helper still does not exercise a real launch-capable silo path.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/orbital-logistics.lua`, `.codex/skills/esir-dev/assets/zzz-orbital-logistics-qc_0.0.1/control.lua`
  - `Next safe move:` add one helper staging step or seeded save variant that brings a bound silo to `rocket_ready`, then assert `launch_count`, `last_launch_tick`, and post-launch lease behavior from the existing structured snapshots.

- `2026-04-17 | orbital-logistics-qc | open | the save-driven orbital cohort helper works during direct helper-aware runs, but the wrapper-driven runtime lanes still rebuild mods-live without replaying zzz-orbital-logistics-qc automatically.`
  - `Files:` `.codex/skills/esir-dev/assets/zzz-orbital-logistics-qc_0.0.1/control.lua`, `.codex/skills/esir-dev/references/orbital-logistics-qc-helper.md`, `scripts/esir-dev-lib.ps1`
  - `Next safe move:` trace the mod set returned by `Sync-FactorioRunMods` during `qc-runtime` and `runtime-benchmark`, then teach the QC sync path to include the staged orbital helper whenever the selected save catalog entry depends on it.

- `2026-04-15 | runtime-scheduler | open | fluid safety queues still use split head/tail scalar storage and are not yet on scheduler queue objects.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/fluid-safety.lua`
  - `Next safe move:` add an explicit storage-shape migration for `urgent_units` and `dirty_segments`, then move enqueue/dequeue helpers to `runtime-scheduler.lua`.

- `2026-04-18 | flammable-ruptures | open | rupture job assembly now reuses one shared center-area candidate scan, local pipeline fallback rejects out-of-radius candidates before paying for `sqrt`, and damage rings now skip the same distance math for victims that cannot possibly land inside the blast. The next likely rupture hotspot is still cap enforcement on dense pipe-network target lists plus any remaining runtime-only rupture regressions not covered by qc-fast.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/flammable-fluids.lua`
  - `Next safe move:` benchmark a dense pipe-network rupture and, if it still spikes, replace the full sort-and-trim path with a bounded nearest-N cap helper that preserves current ring ordering, then add one runtime smoke fixture or QC helper that actually exercises a rupture death path so cached-value regressions get caught before release.

- `2026-04-15 | runtime-scheduler | open | Vulcanus dormant ready queues still rely on false tombstones plus local active-surface bookkeeping.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/vulcanus-fumaroles.lua`
  - `Next safe move:` only migrate further after the shared scheduler can express the false-tombstone or equivalent live-set semantics without changing dormant-surface fairness behavior.

## Intentional Local

- `2026-04-15 | runtime-scheduler | intentional-local | matter stabilizer surface queues are dense swap-remove schedulers with positions and cursors, not FIFO queues.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/matter-stabilizer.lua`
  - `Next safe move:` leave local unless the shared helper surface grows a dense-set scheduler abstraction.

- `2026-04-15 | runtime-scheduler | intentional-local | steam train tracked and active unit sets are dense membership queues, not FIFO queues.`
  - `Files:` `exotic-space-industries-remembrance/scripts/control/steam-train.lua`
  - `Next safe move:` leave local unless there is a broader shared need for swap-remove queue helpers.
