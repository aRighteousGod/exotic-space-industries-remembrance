---
name: esir-asset-pipeline
description: "Use when Codex should orchestrate a full ESIR asset pipeline from Meshy prompts or existing models through Blender static/procedural rendering, Factorio-style shadows, staged Factorio export, previews, QA, manifests, and reproducible asset dossiers."
---

# ESIR Asset Pipeline

Use this skill when an asset needs a reproducible end-to-end dossier instead of isolated commands. It coordinates `$meshy-api`, `$meshy-blender-spritesheet`, `$blender-procedural-animation`, and `$esir-factorio-asset-export`.

## Hard Rules

- Default generated artifacts to ignored `output/meshy/<asset>/`.
- Keep durable asset-specific generators, replay scripts, and generator notes under `.codex/esir/asset-generators/`; keep hand-written prompt notes under `.codex/esir/art-prompts/`. Do not make `output/` the only home for source material worth committing.
- Use `plan` or `--dry-run` before any credit-spending Meshy step.
- Never store, print, or request Meshy API keys. Meshy helpers read only `MESHY_API_KEY`.
- Do not copy assets into ESIR graphics folders or edit prototypes unless the user explicitly asks after staging.
- Keep Factorio preset assumptions intact by default: orthographic camera, upper-left baked light, lower-right staged shadows, separate base/shadow/glow/light/mask layers, and preset-compatible sheet layout.
- Use the local `factorioRenderingPreset_v4.blend`, `render_factorio_preset.py`, and `Render.zip` conventions for Factorio-bound spritesheets unless the user explicitly asks for a non-preset experiment.
- Classify every preset render output before promotion as base, shadow, glow/light, runtime color mask, water reflection, manual mask source, unused evidence, or baked color. Do not treat `object_mask_0.png` as wired just because it was staged.
- Runtime color masks default to owner-readability only: turrets, vehicles, rolling stock, train stops/remotes, force-facing logistics/control devices, and ownership-critical entities. Preserve baked ESIR color on neutral terrain, decoratives, resources, ruins, pure environmental/alien forms, and deliberately chromatic assets.
- Preserve every command and artifact path in the dossier so the pipeline can be replayed.

## Workflow

1. Create or update an asset spec.
2. Run `plan` to inspect commands and inferred paths.
3. Run individual steps until the output looks good. `render_preset` is the default final render path for Factorio-bound static or directional spritesheets. Auto ortho fitting is still required for static, procedural, and scripted preset renders; keep `min_alpha_margin`/`preflight_margin` enabled before export so the render expands only as much as needed to avoid clipping.
4. Run `qa` and inspect previews/bbox overlays. Enable `style` to compare staged PNGs against the local ESIR graphics baseline. Treat low frame occupancy, weak silhouette contrast, or black-material detail loss as a rerender cue rather than a promotion candidate.
5. Stage Factorio snippets and previews with the export step. Multi-sheet exports remain staged as Factorio `stripes`; runtime color-mask layers still require explicit classification and prototype wiring.
6. Enable `gallery` to write an HTML approval page with previews, warnings, snippets, and dossier links.
7. Enable `registry` to update the manifest-backed asset index with hashes, roles, QA status, and manual review fields; use the `registry` command to browse or mark queue status.
8. Use `batch` for sequential variant runs and `estimate` before expensive render batches.
9. Use the disabled-by-default `promotion` step only for dry-run copy/patch plans unless the user explicitly approves execution. `promotion` is excluded from `--steps all`; run it by name when needed.

## Commands

Create a full example spec:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py sample `
  --asset-name ei-threshold-array `
  --output output/meshy/ei-threshold-array/asset.pipeline.json
```

Plan the run:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py plan `
  --spec output/meshy/ei-threshold-array/asset.pipeline.json
```

Run selected stages:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py run `
  --spec output/meshy/ei-threshold-array/asset.pipeline.json `
  --steps render_procedural,export,qa
```

Dry-run any execution:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py run `
  --spec output/meshy/ei-threshold-array/asset.pipeline.json `
  --steps all `
  --dry-run
```

Estimate render weight:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py estimate `
  --spec output/meshy/ei-threshold-array/asset.pipeline.json
```

Run declared variants:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py batch `
  --spec output/meshy/ei-threshold-array/asset.pipeline.json `
  --steps render_preset,export,qa `
  --continue-on-error
```

Render a registry browser or mark a staged asset:

```powershell
python .codex/skills/esir-asset-pipeline/scripts/run_asset_pipeline.py registry `
  --path output/meshy/asset-index.json `
  --html output/meshy/asset-index.html
```

Stage the preset bundle through the orchestrator by setting `export.mode = "render-bundle"`. If `export.bundle` is omitted, it consumes `render_preset.output_dir`; pass `export.pack_raw_frames = true` to pack raw `Render/Object/*.png` folders.

Read `references/pipeline-spec.md` before authoring a complex spec or changing defaults.

## Dossier

Each run writes `asset.pipeline-dossier.json` beside the spec or under the asset output directory. The dossier includes:

- resolved spec
- commands planned or executed
- return codes and captured output tails
- discovered artifacts
- image dimensions and alpha bounds
- warnings and QA findings
- optional style reports, regression reports, approval gallery, render-cost estimate, and asset registry updates

Generated dossiers, manifests, galleries, and previews stay in ignored `output/` by default. Promote only deliberately curated provenance into `.codex/esir/asset-generators/` or another checked-in ESIR manifest path.
