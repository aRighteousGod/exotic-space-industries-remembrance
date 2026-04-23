---
name: esir-recipe-icon-style
description: "Ingest the local recipe-icons-improvement-for-esir companion mod, audit ESIR recipe icon and visibility drift, and generate non-mutating batch review reports plus patch-ready planning data for icon, sorting, hiding, and signal cleanup work."
---

# ESIR Recipe Icon Style

Use this skill when work touches ESIR recipe icon readability, subgroup or order drift, Factoriopedia visibility, player-crafting visibility, recipe signal cleanup, or batch review of companion-style changes outside the game.

This skill treats the locally installed `recipe-icons-improvement-for-esir` companion mod as the primary baseline and keeps the workflow non-mutating by default.

## Source Order

Read the sources in this order unless the user explicitly wants something else:

1. Latest local companion zip or unpacked folder accepted by the probe, typically under `%APPDATA%\Factorio\mods\recipe-icons-improvement-for-esir*.zip`
2. Local QC runtime evidence: `.factorio-qc/dump-run-data-2/script-output/data-raw-dump.json`
3. ESIR repo source under `exotic-space-industries-remembrance/`
4. Mod Portal screenshots or changelog only as secondary confirmation

Do not treat Mod Portal screenshots as the primary spec when the local companion mod is available.

## Default Workflow

### 1. Probe The Companion Baseline

Run the probe first so the skill starts from local truth instead of memory.

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/companion_mod_probe.py `
  --output .codex/skills/esir-recipe-icon-style/output/companion-baseline.json
```

When you need drift detection against an older snapshot:

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/companion_mod_probe.py `
  --compare .codex/skills/esir-recipe-icon-style/output/companion-baseline.json `
  --diff-output .codex/skills/esir-recipe-icon-style/output/baseline-diff.json
```

The probe is expected to summarize:

- startup settings
- config gates from `0-config.lua`
- loader order from `data-final-fixes.lua`
- icon helper semantics
- sorting and hiding helper semantics
- rule-family coverage from `esir-21*` through `esir-43*`
- overlay and background asset families
- feature candidates the skill may not model yet

### 2. Audit ESIR Prototypes

Use the audit script to build a best-effort static inventory before planning changes.

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/recipe_icon_audit.py `
  --repo-root . `
  --probe .codex/skills/esir-recipe-icon-style/output/companion-baseline.json `
  --output .codex/skills/esir-recipe-icon-style/output/recipe-audit.json
```

The audit should stay conservative. If a prototype cannot be classified confidently, prefer `manual-review-needed` over guessing.

For direct companion icon-helper hits, the audit now tries to synthesize concrete `proposed.icon_layers` from the local companion rule expressions. If a helper expression stays dynamic or ambiguous, keep it strategy-only instead of fabricating layers.

By default, the audit keeps the report limited to ESIR-owned recipes plus recipes that resolve back to ESIR's declared dependency and touchpoint universe from `.codex/esir/dependency-catalog.json`. Use the wider mode only when you explicitly want companion spillover from unrelated active mods.

Common variants:

- include non-ESIR recipes when you want a wider sanity pass:

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/recipe_icon_audit.py `
  --repo-root . `
  --probe .codex/skills/esir-recipe-icon-style/output/companion-baseline.json `
  --scope all-candidates `
  --output .codex/skills/esir-recipe-icon-style/output/recipe-audit.json
```

`--include-non-esir` still works as a compatibility alias, but prefer the explicit `--scope` modes:

- `esir-and-dependencies` (default)
- `esir-only`
- `all-candidates`

### 3. Normalize A Batch Manifest

Use the batch normalizer when you want one manifest that can drive both review and patch planning.

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/recipe_icon_batch.py `
  --audit .codex/skills/esir-recipe-icon-style/output/recipe-audit.json `
  --output .codex/skills/esir-recipe-icon-style/output/recipe-batch.json
```

You can also merge explicit entries for prototypes that need manual notes, missing art, or stronger review tags.

Common variants:

- merge guided overrides or missing-art notes:

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/recipe_icon_batch.py `
  --audit .codex/skills/esir-recipe-icon-style/output/recipe-audit.json `
  --extra-manifest .codex/skills/esir-recipe-icon-style/assets/examples/recipe-icon-manifest.example.json `
  --output .codex/skills/esir-recipe-icon-style/output/recipe-batch.json
```

- narrow review output to one status, family, or prototype slice:

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/recipe_icon_batch.py `
  --audit .codex/skills/esir-recipe-icon-style/output/recipe-audit.json `
  --status manual-review-needed `
  --family isotope-overlay `
  --prototype ei-bio-oil-synthesis `
  --output .codex/skills/esir-recipe-icon-style/output/recipe-batch.json
```

### 4. Render The Out-Of-Game Review Surface

Generate the HTML report, machine-readable JSON, and PNG contact sheet from the batch manifest.

```powershell
python .codex/skills/esir-recipe-icon-style/scripts/render_recipe_icon_report.py `
  --manifest .codex/skills/esir-recipe-icon-style/output/recipe-batch.json `
  --output-dir .codex/skills/esir-recipe-icon-style/output/report
```

The report is meant for sanity checking outside Factorio. It should always show before and after behavior data, not icon previews alone.

The renderer can resolve icon assets from:

- repo-local ESIR mod folders
- sibling ESIR graphics-pack folders in the repo
- local Factorio data roots such as `base`, `core`, and `space-age`
- installed mod folders or zips under `%APPDATA%\Factorio\mods`

If an icon still cannot be resolved after those sources are checked, keep the placeholder and call it out in notes instead of fabricating a preview.

Use `preview.resolved_sources` in `report.json` as the provenance trail when you need to confirm whether a preview came from repo-local art, Factorio data, or installed mod archives.

## Working Rules

- Keep the skill non-mutating by default. Analyze, diff, preview, and emit patch-ready snippets or manifests before touching gameplay files.
- Treat helper semantics from the local companion mod as the baseline, but map them into ESIR-first presets from [references/esir-preset-map.md](./references/esir-preset-map.md).
- Prefer the overlay-driven readability language first. Background plates, purging, hiding, and sorting are part of the broader behavior surface, not a reason to skip icon analysis.
- If local companion logic and QC dump evidence disagree, read the relevant rule file before deciding which side is stale.
- If a batch cannot be flattened exactly, render a clearly labeled placeholder slot instead of inventing a fake icon.
- Keep newly discovered companion features visible through baseline diffs. Do not silently collapse them into existing buckets.

## Monitoring Modes

Use milestone monitoring by default:

- after the first baseline probe
- after the report schema is stable
- after the first implementation pass of the probe script
- before final validation

Session-sidecar monitoring is also acceptable during long implementation sessions, but do not present it as an always-on watcher. This skill is meant to support bounded re-checks, not background daemon behavior.

## References

- Local companion baseline: [references/local-companion-baseline.md](./references/local-companion-baseline.md) when you need the observed helper surface, loader order, or companion feature map
- ESIR-first preset mapping: [references/esir-preset-map.md](./references/esir-preset-map.md) when translating companion behavior into ESIR-facing review tags
- Icon composition rules: [references/composition-rules.md](./references/composition-rules.md) when reviewing layered icon proposals or family consistency
- Behavior rules: [references/behavior-rules.md](./references/behavior-rules.md) when evaluating hide, show, redirect, purge, or signal-cleanup semantics
- Batch review checklist: [references/review-checklist.md](./references/review-checklist.md) when deciding whether a manifest entry is ready to move from planning into a patch

## Resources

- `scripts/companion_mod_probe.py`: summarize the companion mod and emit baseline diffs
- `scripts/recipe_icon_audit.py`: statically inspect ESIR prototypes and classify drift
- `scripts/recipe_icon_batch.py`: normalize audit data plus manual entries into one manifest
- `scripts/render_recipe_icon_report.py`: build `report.html`, `report.json`, and `report-sheet.png`
- `assets/examples/recipe-icon-manifest.example.json`: starter manifest for guided or batch review
