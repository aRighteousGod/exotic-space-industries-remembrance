# ESIR Prompt Shortcuts

Use these as repo-local prompt starters when you want Codex to grab the right surface quickly.

## Structure

- "Use `$esir-dev` and refresh the ESIR manifests before you touch runtime code."
- "Use `$esir-lib-first` before adding any helper to an ESIR Lua file; check whether `ei_lib` already covers it or should be hardened."
- "Map the `control.lua` runtime surface and show me which modules own storage."
- "Compare `data.lua` aggregators with `.codex/esir/prototype-index.json` and flag drift."

## QC

- "Run `$esir-dev` `qc-fast` and summarize only the real blockers."
- "Run `$esir-dev` `qc-runtime -SaveId fueler-smoke` and tell me what coverage that save actually gives us."
- "Run `$esir-dev` `qc-preview -SaveId fueler-smoke -Planet gaia` and call out Gaia/resource anomalies."
- "Run `$esir-dev` `preflight` first, then `qc-assets`, and separate advisory static warnings from authoritative Factorio failures."

## Portal

- "Run `$esir-dev` `portal-scout` and rank mods we can study or integrate, with license/source notes."
- "Diff the current portal shortlist against local feature gaps around recipe icons, Tesla, fusion, and orbital systems."

## Art

- "Use `$esir-dev` `art-start` with this prompt and keep the browser workflow manual."
- "Use `$esir-dev` `art-review` and bind the collected files to likely pack targets and in-game roles."
- "Use `$esir-dev` `art-validate` before proposing any import path."

## Packaging

- "Run `$esir-dev` `pack-dryrun` and confirm the zip layout without deploying."
- "Run `$esir-dev` `diff` and tell me whether live source, seeded run-mods, and package outputs have drifted."

## Full Sweep

- "Use `$esir-dev` `full` and give me the shortest useful triage report."
