# Research Hitch QC Helper

Use this helper when ESIR work needs a dedicated late-game save that exercises research-finished hitch paths instead of relying on `fueler-smoke`.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-research-hitch-qc_0.0.1`](../assets/zzz-research-hitch-qc_0.0.1)
- Main helper file: [`../assets/zzz-research-hitch-qc_0.0.1/control.lua`](../assets/zzz-research-hitch-qc_0.0.1/control.lua)

## What It Builds

- Three generated test surfaces: `research-hitch-a`, `research-hitch-b`, `research-hitch-c`
- Dense Tesla turret grids on each surface
- A main EM train surface with rails, chargers, and locomotives
- A mostly researched late-game force state
- A queued terminal research chain that completes one tech every `60` ticks:
  - Tesla progression
  - EM charger efficiency
  - EM locomotive acceleration
  - EM locomotive speed

The helper also calls the QC-only remote hook `exotic-industries-qc.rebuild_research_hitch_runtime` so the save's serialized runtime state matches the world and force research it just built.
It also appends focused runtime snapshots to `research-hitch-qc.txt` around each queued completion by calling the QC-only remote hook `exotic-industries-qc.get_research_hitch_qc_snapshot`.

## Important Behavior

- This helper is meant to be staged only for `research-hitch` save generation and the QC runs that consume that save.
- Do not leave it enabled for normal `qc-fast`, `fueler-smoke`, or preview runs; on a fresh save it will intentionally build the hitch scenario.
- During `research-hitch` runtime and benchmark runs, the helper advances the queued research by setting `force.research_progress = 1` every `60` ticks until the queue is empty.
- The helper writes `research-hitch-qc.txt` into script output during generation/config-change refresh so you can confirm surface counts and queued techs.
- During the active hitch scenario, the same file also records `pre-complete`, `post-immediate`, `post-plus-1`, `post-plus-2`, and final `queue-finished` snapshot blocks with tech-scaling, scripted-burst, Tesla variant-sync, and EM rollout status.

## Staging Steps

1. Copy `assets/zzz-research-hitch-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-research-hitch-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\research-hitch.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Keep the helper staged and enabled while running:
   - `qc-runtime -SaveId research-hitch`
   - `runtime-benchmark -SaveId research-hitch`
5. Disable or remove the helper again before unrelated QC runs.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
