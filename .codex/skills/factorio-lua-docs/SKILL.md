---
name: factorio-lua-docs
description: "Docs-first workflow for official Factorio Lua API questions. Use when Codex needs the authoritative runtime, prototype, auxiliary, or wiki scripting docs for Factorio modding, including classes, methods, attributes, events, concepts, defines, prototypes, types, migrations, storage, data lifecycle, script interfaces, localisation, console, command-line flags, or data.raw guidance."
---

# Factorio Lua Docs

Use this before freehand memory or broad web search when the task is mainly about official Factorio modding documentation.

Start with the wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task refresh
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query LuaGuiElement -Stage runtime -RefreshIfMissing
```

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
- The official docs are version-sensitive. Refresh when “latest” matters.
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

## Sidecar Roles

Use light read-only sidecars when it helps:

- `runtime-api explorer`
- `prototype-api explorer`
- `auxiliary-docs explorer`
- `wiki-guidance explorer`

Keep the main agent on synthesis and edits.

## Read Next When Needed

- Official source map and scope: [references/source-map.md](./references/source-map.md)
- Query workflow and answer shape: [references/query-flow.md](./references/query-flow.md)
- License and cache boundaries: [references/licensing.md](./references/licensing.md)
