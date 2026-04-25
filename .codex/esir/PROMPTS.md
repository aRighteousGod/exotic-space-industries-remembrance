# ESIR Prompt Shortcuts

Use these as repo-local prompt starters when you want Codex to grab the right surface quickly.

## Structure

- "Use `$esir-dev` and refresh the ESIR manifests before you touch runtime code."
- "Use `$esir-lib-first` before adding any helper to an ESIR Lua file; check whether `ei_lib` already covers it or should be hardened."
- "Use `$factorio-lua-assumptions` before applying normal Lua advice to Factorio control/data code."
- "Use `$factorio-lua-docs` to verify the exact Factorio API or lifecycle rule before changing this script."
- "Use `$esir-dependency-intel` to show declared dependencies and ESIR touchpoints for this mod."
- "Map the `control.lua` runtime surface and show me which modules own storage."
- "Compare `data.lua` aggregators with `.codex/esir/prototype-index.json` and flag drift."

## QC

- "Run `$esir-dev` `qc-fast` and summarize only the real blockers."
- "Run `$esir-dev` `qc-runtime -SaveId fueler-smoke` and tell me what coverage that save actually gives us."
- "Run `$esir-dev` `runtime-benchmark -SaveId research-hitch` and compare the runtime artifact against the previous benchmark notes."
- "Run `$esir-dev` `qc-preview -SaveId fueler-smoke -Planet gaia` and call out Gaia/resource anomalies."
- "Run `$esir-dev` `preflight -AsJson` as a read-only sweep and separate advisory static warnings from authoritative Factorio failures."
- "Run `$esir-dev` `preflight -FixEncoding` only when we intentionally want the harness to repair encoding."
- "Run `$esir-dev` `dependency-diff -Strict -AsJson` when manifest drift should fail the pass."

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
- "For a read-only status pass, use `$esir-dev` `doctor -AsJson`, `$esir-dev` `dependency-diff -Strict -AsJson`, and `$factorio-lua-docs` cached queries without `-RefreshIfMissing`."
