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
- Historical standalone saves used explicit `-SavePath`. Current `research-events` cases own their checkpoints through the suite catalogue; `qc-test` uses suite/profile/case selectors.

## Staging Steps

1. Run `scripts/invoke-esir-dev.ps1 -Task test-plan -Suite research-events`.
2. Run `scripts/invoke-esir-dev.ps1 -Task qc-test -Suite research-events`.
3. Review fresh `candidate` and `reload` reports under the managed run identity.

The repository-owned adapter reuses this helper's world setup in a private current-engine helper. Required snapshots, completion, derived state and ordering are assertions; a missing snapshot fails. Historical receipts retain their engine and counts. See [native testing](native-testing.md). Do not stage shared `fmqc/mods-live` copies.

## Scope

This helper is QC-only. Do not ship it inside the released mod packs.
