---
name: factorio-lua-docs
description: "Docs-first workflow for official Factorio Lua API questions. Use when Codex needs the authoritative runtime, prototype, auxiliary, or wiki scripting docs for Factorio modding, including classes, methods, attributes, events, concepts, defines, prototypes, types, migrations, storage, data lifecycle, script interfaces, localisation, console, command-line flags, or data.raw guidance."
---

# Factorio Lua Docs

Use this before freehand memory or broad web search when the task is mainly about official Factorio modding documentation.

Start with the wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task status
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query LuaGuiElement -Stage runtime
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task refresh
```

Use `-Task status` to confirm the cached runtime/prototype application versions before answering version-sensitive API questions.

For `-Task query`, provide either `-Query` or `-ExactName`. Blank queries fail instead of returning arbitrary first entries.
Cached queries are read-only by default. Use `-RefreshIfMissing` or `-Task refresh` only when network/cache writes are acceptable.

## What This Skill Covers

- runtime API docs from `lua-api.factorio.com`
- prototype API docs from `lua-api.factorio.com`
- auxiliary docs such as Data Lifecycle, Storage, Libraries, Migrations, Instrument Mode, and JSON doc formats
- official wiki scripting topics such as Tutorial:Scripting, Script interfaces, Localisation, data.raw, Console, Scenario System, and Command line parameters

## Working Rules

- Treat `lua-api.factorio.com` and official `wiki.factorio.com` pages as primary sources.
- Prefer the machine-readable runtime and prototype JSON docs for exact symbol lookup.
- Prefer local cached index results first, then open the official page when the question needs more detail, examples, or release-specific nuance.
- Do not copy the whole docs corpus into checked-in repo files. Keep downloaded snapshots in the ignored cache at `.factorio-lua-docs-cache`.
- The official docs are version-sensitive. Refresh when "latest" matters.
- The `latest` docs can track experimental Factorio while the installed local game remains on stable. Compare `-Task status` with `factorio.exe --version` before updating installed-file surveys such as core lualib or vanilla prototype helper maps.
- For command-line option questions, query the cached wiki topic first, then compare the official page with local `factorio.exe --help` when choosing flags for this workstation.
- For language/runtime assumptions, use `factorio-lua-assumptions` first, then verify exact API claims here.
- Return the exact official URL with your answer whenever practical.

## Query Hints

- Runtime symbol lookup:
  - `-Stage runtime -ExactName LuaEntity`
  - `-Stage runtime -Kind method -Query teleport`
- Prototype lookup:
  - `-Stage prototype -ExactName RecipePrototype`
  - `-Stage prototype -Kind prototype-property -Query results`
- Guidance topic lookup:
  - `-Stage auxiliary -Query migrations`
  - `-Stage wiki -Query script interfaces`
  - `-Stage wiki -Query "Command line parameters"`

## Sidecar Roles

Use light read-only sidecars when it helps:

- `runtime-api explorer`
- `prototype-api explorer`
- `auxiliary-docs explorer`
- `wiki-guidance explorer`
- `cli-options explorer`

Keep the main agent on synthesis and edits.

## Read Next When Needed

- Factorio-vs-general-Lua guardrails: [../factorio-lua-assumptions/SKILL.md](../factorio-lua-assumptions/SKILL.md)
- Official source map and scope: [references/source-map.md](./references/source-map.md)
- Query workflow and answer shape: [references/query-flow.md](./references/query-flow.md)
- License and cache boundaries: [references/licensing.md](./references/licensing.md)
