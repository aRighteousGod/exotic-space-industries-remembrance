---
name: esir-dependency-intel
description: "Inspect ESIR declared dependencies and cross-mod touchpoints through a checked-in dependency catalog plus optional local installed-mod enrichment. Use when Codex needs to answer which mods ESIR depends on, where those mods are touched at runtime or data stage, which remote interfaces are involved, which planet/content integrations exist, or whether a locally installed external mod is present without treating machine-local state as checked-in truth."
---

# ESIR Dependency Intel

Use this before ad hoc repo-wide greps when the question is mainly about ESIR dependencies, compatibility surfaces, remote interfaces, planet integrations, or media companion packs.

Start with the wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-esir-dependency-intel.ps1 -Task query -Scope all -Category all
```

## Task Surface

- `refresh`: regenerate [`.codex/esir/dependency-catalog.json`](../../esir/dependency-catalog.json)
- `query`: filter declared dependencies and touchpoints by scope, category, mod, pack, or path
- `diff`: compare the checked-in dependency catalog against a fresh regeneration

Common options:

- `-Scope declared|touchpoints|all`
- `-Category runtime|prototype|planet|remote|media|all`
- `-ModName`
- `-Pack`
- `-Path`
- `-ResolveInstalled`
- `-Strict`
- `-AsJson`

## Working Rules

- Checked-in truth is exactly two stable layers: `declared_dependencies` from pack `info.json` files and ESIR `touchpoints` extracted from runtime/data-stage integration files.
- Local installed-mod inspection is query-time enrichment only. Never persist `%APPDATA%\Factorio\mods`, `output\tesla-run-mods`, or `.factorio-qc` presence into checked-in manifests.
- Reuse the existing ESIR manifests instead of rediscovering the repo shape from scratch: [`.codex/esir/runtime-modules.json`](../../esir/runtime-modules.json), [`.codex/esir/prototype-index.json`](../../esir/prototype-index.json), and [`.codex/esir/pack-manifest.json`](../../esir/pack-manifest.json).
- Treat touchpoint categories as a navigation aid, not a substitute for reading the owning file when a change is about to land.
- If you change dependency touchpoint logic or add a new compatibility surface, refresh the catalog and update the matching skill/reference wording in the same patch.

## Read Next When Needed

- Category meanings: [references/catalog-categories.md](./references/catalog-categories.md)
- Source hierarchy and truth order: [references/source-hierarchy.md](./references/source-hierarchy.md)
- Query flow and sidecar roles: [references/query-flow.md](./references/query-flow.md)
