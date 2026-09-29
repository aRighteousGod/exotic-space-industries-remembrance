---
name: esir-conceptual-blueprints
description: "Create and maintain repo-owned conceptual models with Lua commentary backlinks for substantive ESIR runtime or data-stage systems, lifecycle changes, persistent state, scheduling, and cross-file contracts. These are development reference models, not Factorio construction blueprint strings."
---

# ESIR Conceptual Blueprints

Read the relevant model in [the blueprint index](../../esir/blueprints/index.md) before changing a system contract. Inspect its current source owners as well: structural checks cannot prove that a model describes its implementation accurately.

## When a model is required

Create or update a model for a new subsystem or a substantive change to behavior, state ownership, lifecycle, scheduling, shared interfaces, or cross-file/stage contracts. This applies to runtime and data stages. Small wording, formatting, and cosmetic edits do not require a new model. Keep each subsystem's GUI, configuration, and migrations with its owner; give shared orchestration and helpers their own models.

## Workflow

1. Find the owner through the index or the source's `blueprint` comment. Follow relevant `blueprint-ref` comments before editing an invariant.
2. Trace current callers, storage, event routing, tick sources, cleanup, and validation fixtures. Use the existing Factorio and ESIR specialist skills for their contracts. A stale manifest or previous validation report is not current truth.
3. Write or revise `.codex/esir/blueprints/<system>.md` using [the model template](assets/model-template.md). Record observable behavior, owner symbols, authoritative versus derived state, lifecycle, timing, invariants, and verification scenarios. Use a small Mermaid diagram when flow or transitions benefit from it.
4. Distinguish implemented behavior, intended constraints, inferred rationale, and unresolved discrepancies. A code/model disagreement is a finding to resolve, not permission to bless a regression by rewriting its contract. Link deferred work to `REVISIT_NOTES.md`.
5. Update the model, source commentary, and index in the same patch. Preserve useful comments and explain non-obvious boundaries rather than narrating assignments.
6. Run the structural audit and relevant subsystem checks. Report structural, source-review, and engine evidence separately.

## Link contract

- Every modeled source has exactly one file-level primary marker in its leading comments: `-- blueprint: .codex/esir/blueprints/<system>.md#contract`.
- Place it immediately after the generated `ESIR FILE MAP` block, never inside that block. Header synchronization replaces the block. For files without a generated map, use a leading comment.
- Use `-- blueprint-ref: .codex/esir/blueprints/<system>.md#<anchor>` beside non-obvious logic, followed by useful explanation. These references do not establish ownership.
- Models use explicit `<a id="contract"></a>` and other stable, unique anchors. The `## Implementation sources` section is a Markdown list of relative links to owned Lua files. Other source links are citations, not ownership declarations. Avoid frozen line numbers.
- Keep classification exceptions in the index's `## Coverage exceptions` table (`Source | Classification | Reason`). Only `inactive` and `data-only` are supported; explain the actual owner or inactivity evidence. A `data-only` reason must link an existing non-runtime Lua importer outside `scripts/control` whose imports resolve the excluded file. An exception cannot conceal a source discovered through runtime imports.
- For a nonliteral runtime import, place `-- blueprint-requires: ["literal.module", "another/module"]` on the preceding line. This bounded dependency declaration does not authorize dynamic runtime imports. Remove it when no longer needed.

## Runtime timing

Follow the canonical [tick-source contract](../esir-dev/references/runtime-scheduler-guidelines.md#tick-source): propagate supplied callback ticks, resolve `game.tick` only at a game-available boundary without a supplied tick, and never read it during top-level loading or `on_load`. Distinguish origin, due, and execution timestamps for delayed work. Reuse existing `ei_lib` and scheduler interfaces.

## Validation

```powershell
python -B .codex/skills/esir-conceptual-blueprints/scripts/blueprint_audit.py --repo-root . --format markdown
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task preflight -AsJson
```

The audit uses current Lua source, not installed mod selection or generated manifests. It conservatively includes conditional local imports, migrations, and every control-directory Lua file. It checks coverage, ownership, links, and anchors; it does not execute Lua, validate gameplay, or prove semantic agreement. Future data-stage models are checked through declared owners and markers without imposing a full data-stage backfill.

See [the validation commands and evidence limits](../../../scripts/qc/blueprints/README.md) for audit regression fixtures, header preservation, preflight failure propagation, diagram parsing, and the bundled QC helpers' tick checks.
