---
name: factorio-lua-docs
description: "Docs-first workflow for official Factorio Lua API questions. Use when Codex needs the authoritative runtime, prototype, auxiliary, or wiki scripting docs for Factorio modding, including classes, methods, attributes, events, concepts, defines, prototypes, types, migrations, storage, data lifecycle, script interfaces, localisation, console, command-line flags, or data.raw guidance."
---

# Factorio Lua Docs

Follow [housekeeping](../esir-dev/references/housekeeping.md) for cache work: preserve the engine-matching docs cache and overwrite stable cache paths instead of copying a corpus per query. Historical caches are report-only until separately reviewed.

Use this before freehand memory or broad web search when the task is mainly about official Factorio modding documentation.

Start with the wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task status
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task query -Query LuaGuiElement -Stage runtime
powershell -ExecutionPolicy Bypass -File .\scripts\invoke-factorio-lua-docs.ps1 -Task refresh
```

These commands default to the exact `-Source hosted -Version 2.1.23` profile. Queries read the isolated `.factorio-lua-docs-cache/2.1.23` cache without network access or writes; populate it with an explicit `-Task refresh`. Use `-Task status` to confirm the source and cached runtime/prototype application versions before answering version-sensitive API questions. Verify the selected executable reports 2.1.23 as well.

For historical migration work, use `-Source installed -Version 2.0.77` with the preserved Steam installation at `C:\Program Files (x86)\Steam\steamapps\common\Factorio\doc-html`. Never substitute that executable for main 2.1 validation, or silently refresh either profile from another version.

For `-Task query`, provide either `-Query` or `-ExactName`. Blank queries fail instead of returning arbitrary first entries.
Cached queries are read-only by default. Installed refreshes never use the network. Use `-RefreshIfMissing` or `-Task refresh` only when a versioned cache write is acceptable.

## What This Skill Covers

- exact-version hosted runtime and prototype API JSON/HTML for Factorio 2.1.23 by default
- explicitly selected installed 2.0.77 documentation for migration and historical evidence
- auxiliary docs such as Data Lifecycle, Storage, Libraries, Migrations, Instrument Mode, and JSON doc formats
- official wiki scripting topics such as Tutorial:Scripting, Script interfaces, Localisation, data.raw, Console, Scenario System, and Command line parameters

## Working Rules

- Treat `lua-api.factorio.com` and official `wiki.factorio.com` pages as primary sources.
- Prefer the machine-readable runtime and prototype JSON docs for exact symbol lookup.
- Prefer the version-pinned cached index first, then open the exact versioned official page when the question needs more detail or examples.
- Do not copy the whole docs corpus into checked-in repo files. Keep indexed snapshots in the ignored, versioned cache at `.factorio-lua-docs-cache/<version>`.
- Treat 2.1.23 as the main ESIR authority. Never select, migrate, or reuse the legacy flat 2.1.15 cache implicitly. Keep 2.0.77 results explicitly labeled as historical.
- Refreshing hosted documentation is opt-in: pass `-Task refresh`. The version must be numeric; `latest` is rejected, and `-DocsRoot` is incompatible with hosted mode.
- Compare `-Task status` with `factorio.exe --version` before updating installed-file surveys such as core lualib or vanilla prototype helper maps.
- For command-line option questions, query the cached wiki topic first, then compare the official page with local `factorio.exe --help` when choosing flags for this workstation.
- For language/runtime assumptions, use `factorio-lua-assumptions` first, then verify exact API claims here.
- Return the exact official URL with your answer whenever practical.

## Native 2.1 fluid semantics

Do not equate an entity's local fluid storage with a connected segment.
`get_fluid(index)` and `set_fluid` operate on local storage; use
`has_fluid_segment` and the segment methods for connected-network transactions.
Private one-way machine buffers need local methods. Restore a replacement's
captured segment total after removing the overlapping source/candidate, because
native redistribution can otherwise duplicate fluid during commit or rollback.

The exact 2.0.77/2.1.23 paired capacity probes also found that fixed-recipe input
capacity is `amount * multiplier` in 2.0 and `amount * (multiplier + 1)` in 2.1.
An old input multiplier 2 therefore needs 1 to preserve capacity; 10 needs 9.
The native 2.1 input default is 3, so omitting the multiplier gives four input
batches rather than the old default of two; output default 3 gives three batches.
Fluid outputs need explicit multiplier 2 to retain the old default, instead of
the new default 3. The user subsequently approved native 2.1 buffer sizing with
Quality enabled. ESIR now uses `ei_lib.recipe_fluidbox_multiplier` to inherit
those defaults and retain authored explicit values; parity adjustments apply
only without Quality. Main ESIR requires Quality. Do not halve an ordinary
recipe's ingredients to fit a buffer.
The railgun helper's locked, normally uncraftable recipe has a separately verified
sizing exception. See `scripts/qc/factorio-2.1/prepare_fluid_buffers.py`, the paired
native probes and the upgrade synopsis; final merged data and generated recipes
still require verification. Nominal field preservation alone is insufficient.

## Query Examples

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
- Explicit hosted profile:
  - `-Source hosted -Version 2.0.77 -Task refresh`

## Verified 2.1 runtime details

Factorio LuaObject methods are bound. With `pcall`, pass the method followed by
its documented arguments, without an extra `self` (for example,
`pcall(silo.launch_rocket, destination)`). The exact 2.1.23 native orbital and
crystal-shell fixtures cover this distinction.

Pollution flow statistics can lag a successful `surface.pollute` call until the
next tick in 2.1.23. Do not assert an immediate statistics increment or issue a
second emission to compensate. The native rocket suite compares the graph to
completed prior-tick emissions; physical emission and recorded graph timing are
separate observations. Evidence: protected upgrade run `rocket-position-21` and
`rocket-quality-21/rendered-01.receipt.json`.

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
