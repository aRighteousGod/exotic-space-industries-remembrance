# Scripted Research QC Helper

Use this helper when ESIR work needs a deterministic `event.by_script` research flood instead of relying on manual console work or normal queued research.

## Canonical Asset

- Helper mod folder: [`../assets/zzz-scripted-research-qc_0.0.1`](../assets/zzz-scripted-research-qc_0.0.1)
- Main helper file: [`../assets/zzz-scripted-research-qc_0.0.1/control.lua`](../assets/zzz-scripted-research-qc_0.0.1/control.lua)

## What It Builds

- Two generated test surfaces:
  - `scripted-research-main`
  - `scripted-research-aux`
- Dense Tesla turret grids on both surfaces
- A main EM train surface with rails, chargers, and locomotives
- One Emerald Apocalypse hover tank so orbital shard force-cache/status refreshes are visible
- One delayed scripted research burst that calls `force.research_all_technologies()` after `10` ticks

The helper also calls the QC-only remote hook `exotic-industries-qc.rebuild_scripted_research_runtime` before the burst so ESIR runtime state matches the world it just created.
After the burst fires, it waits a few ticks before writing its post-burst report so ESIR's coalesced `on_scripted_research_burst` handler has time to flush.

## Important Behavior

- This helper is meant to be staged only for direct scripted-research QC runs.
- Do not leave it enabled for normal `qc-fast`, `fueler-smoke`, preview, or package runs.
- The helper writes `scripted-research-qc.txt` into script output during world preparation and after the scripted burst fires.
- The save is intended for explicit `-SavePath` usage; it does not need a checked-in save-catalog entry.

## Staging Steps

1. Copy `assets/zzz-scripted-research-qc_0.0.1` into `.factorio-qc/fmqc/mods-live/`.
2. Add or enable the `zzz-scripted-research-qc` entry in `.factorio-qc/fmqc/mods-live/mod-list.json`.
3. Create the save with the normal Factorio executable, for example:
   - `factorio.exe --create .factorio-qc\\scripted-research-burst.zip --mod-directory .factorio-qc\\fmqc\\mods-live`
4. Keep the helper staged and enabled while running:
   - `qc-runtime -SavePath .factorio-qc\\scripted-research-burst.zip`
5. Disable or remove the helper again before unrelated QC runs.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
