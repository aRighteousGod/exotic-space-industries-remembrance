# Conceptual blueprint validation

The [skill](../../../.codex/skills/esir-conceptual-blueprints/SKILL.md) defines the
maintenance contract; the [index](../../../.codex/esir/blueprints/index.md) maps
systems to their current implementation owners. Run these commands from the
repository root.

## Required structural checks

```powershell
python -B .codex/skills/esir-conceptual-blueprints/scripts/blueprint_audit.py --repo-root . --format markdown
python -B .codex/skills/esir-conceptual-blueprints/scripts/test_blueprint_audit.py
powershell -ExecutionPolicy Bypass -File scripts/qc/blueprints/check-support.ps1
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task preflight -AsJson
```

The audit discovers the current runtime graph and control-directory inventory.
It does not use a frozen file count, generated manifests, or installed mod
selection. Fixtures exercise shared subsystem ownership, new modules,
exceptions, stale/missing sources, reciprocal links, anchors, conditional and
cyclic imports, quoting, comment/string decoys, dynamic imports, and CLI exit
status. `check-support.ps1` tests the real header synchronizer's functions and
preflight result aggregation without rewriting repository headers. Missing
Python or a missing audit script must fail the required preflight check.

The audit is read-only and uses only Python's standard library. Test fixtures
are created under ignored `output/`. The existing full preflight's separate
Python syntax check uses `py_compile`; in a sandbox protecting `.codex`, give
it a writable cache location for the command, restoring the prior environment
afterward:

```powershell
$previousCachePrefix = $env:PYTHONPYCACHEPREFIX
try {
    $env:PYTHONPYCACHEPREFIX = Join-Path ([IO.Path]::GetTempPath()) 'esir-bp-pyc'
    powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task preflight -AsJson
} finally {
    $env:PYTHONPYCACHEPREFIX = $previousCachePrefix
}
```

## QC helper timing checks

```powershell
& .tools/lua-5.4.8/luac54.exe -p .codex/skills/esir-dev/assets/zzz-emerald-doctrine-qc_0.0.1/control.lua
& .tools/lua-5.4.8/luac54.exe -p .codex/skills/esir-dev/assets/zzz-auric-fumarole-qc_0.0.1/control.lua
& .tools/lua-5.4.8/lua54.exe scripts/qc/blueprints/check-tick-helpers.lua
```

The mock harness loads the actual helper files. It makes `game.tick` throw
during event callbacks, checks tick zero and shifted origins, exercises every
configured report/checkpoint deadline, and verifies one clock capture at
unticked lifecycle/remote boundaries. Emerald's remote spy verifies the
helper's forwarded arguments; the main mod's existing remote implementation
still resolves its own time. These are standalone Lua 5.4 checks with mocked
APIs, not Factorio engine, gameplay, rendering, multiplayer, or LuaObject tests.

## Optional diagram parsing

This dependency install stays in ignored staging and is not required by
preflight. Use an available Node/npm executable, or its full local path:

```powershell
npm install --prefix output/blueprint-rollout/mermaid-check --ignore-scripts --no-audit --no-fund mermaid@11.12.1 jsdom@26.1.0
node scripts/qc/blueprints/check-diagrams.mjs
```

The parser accepts optional repository-root and dependency-root arguments.
It checks Mermaid syntax only; read diagrams against their source owners to
assess behavior and inspect a rendered document to assess layout.

## Rollout evidence and limits

The 2026-09-28 backfill accounts for 41 models, 94 owned sources, and two
classified exceptions in a 96-file inventory. The conservative runtime graph
contains 93 files, including migrations. These are observed rollout counts,
not audit constants. The Lance feature commit updates its model to schema 14,
including paid contacts and angular acquisition.

All 30 audit regression tests and five header/preflight
support checks passed. All 41 Mermaid diagrams parsed successfully with Mermaid
11.12.1. Metadata validation passed for the new skill and six updated development
skills; 338 local links across 59 relevant documents resolved. The QC helper
mock harness passed 629 assertions, and both helper files passed Lua syntax
checks. Whitespace checks passed.

Final repository preflight completed with no errors after redirecting Python's
cache to the temporary directory. Blueprint coverage, Lua/Python/PowerShell
syntax, encoding, requires, locale, assets, and pack versions passed. The result
remained `warning` for two pre-existing header findings: `forwarded_events` in
`auric-inoculation-vat.lua`, and `storage_roots`, `gui_ids`, `remote_interfaces`,
and `rebuild_on` in `emerald-apocalypse-hover-tank.lua`. The initial run's
protected `.codex` cache-write failures were environmental; a separate read-only
compile also passed for 89 Python files.

Each model was reviewed against its current source owners, including dispatcher
ordering, lifecycle ownership, and timing. Existing implementation deviations
are recorded in the models and
[revisit notes](../../../.codex/esir/REVISIT_NOTES.md); the documentation rollout
does not repair shipping gameplay behavior.

Our shipping Lua edits add commentary only. A comparison against the starting
415-file Lua snapshot found concurrent executable edits in sweeping radar and
a Singularity Lance prototype, confirmed by the user as other Codex instances'
work. Those edits were preserved and are excluded from any claim that this
patch changed gameplay. The models reflect the inspected snapshot and must
continue to be reconciled by the owners of subsequent substantive edits.

No fresh Factorio run is claimed for this rollout: other instances' engine
runs occupied the serialized QC slot. Existing reports linked by the models
remain historical references, not evidence of a fresh engine pass.
