---
name: esir-factorio-asset-export
description: "Use when Codex should stage Meshy/Blender spritesheets, animated sheets, shadow sheets, or source icon art as Factorio/ESIR-ready asset drafts with previews, manifests, and Lua prototype snippets without wiring them into the mod."
---

# ESIR Factorio Asset Export

Use this skill after `$meshy-blender-spritesheet`, `$meshy-api`, or any other art workflow has produced source art that should become a Factorio/ESIR asset draft.

## Hard Rules

- Stage generated assets under `output/meshy/<asset>/factorio-export/` unless the user explicitly gives another staging path.
- Treat `output/` as ignored generated staging only. Do not leave the only copy of a reusable generator script, hand-written note, or prompt there; promote durable sources to `.codex/esir/asset-generators/` or `.codex/esir/art-prompts/`.
- Do not copy files into `exotic-space-industries-remembrance/graphics/` or edit prototypes unless the user explicitly asks for that follow-up. Promotion remains dry-run unless `--execute` is passed.
- Do not treat a generated sheet as shippable until the preview has been inspected.
- During preview inspection, reject or rerender drafts whose sprite occupies too little of each frame, loses its silhouette at Factorio scale, touches/cuts off at a frame edge, or has minimal contrast because the material is near-black. If a render manifest includes `alpha_bounds`, treat non-empty `warnings` or margins below the requested `min_alpha_margin` as a rerender cue.
- Keep Meshy credentials out of this workflow. This skill does not need API keys.
- For item icons, reuse the repo-local `$esir-item-icon-prep` behavior instead of hand-building mip strips.

## Modes

- `entity`: one-frame or directional entity sheets, with optional shadow sheet.
- `machine`: base machine sheet, optional base shadow, and optional `working_visualisations` animation sheet.
- `icon`: source art to a staged `128/64/32` Factorio item icon strip.
- `render-bundle`: staged output from the local Factorio rendering preset, such as `Render.zip`, an extracted `Render/.Sheets` folder, or raw `Render/Object/*.png` frame folders, preserving base, shadow, mask, light, glare, and water-reflection sheets. Large exports can emit Factorio `stripes`.
- `promote`: dry-run or explicitly execute narrow asset copies and marker-delimited prototype patching from a staged manifest, with optional asset-count and prototype-identity guards.
- `gallery`: static visual approval HTML over staged manifests and preview/source PNGs.

Read `references/factorio-asset-options.md` when choosing fields, scale, shifts, or snippet shape.

## Command

Run from the repo root:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py <entity|machine|icon|render-bundle|promote|gallery> --help
```

Entity example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py entity `
  --asset-name ei-threshold-array `
  --sheet output/meshy/threshold-array/threshold-array-sheet.png `
  --render-manifest output/meshy/threshold-array/threshold-array-sheet.manifest.json `
  --direction-count 8 `
  --scale 0.35 `
  --shift 0,-0.2
```

Machine example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py machine `
  --asset-name ei-threshold-array `
  --sheet output/meshy/threshold-array/base.png `
  --working-sheet output/meshy/threshold-array/working.png `
  --working-shadow-sheet output/meshy/threshold-array/working-shadow.png `
  --working-frame-count 16 `
  --working-line-length 4 `
  --snippet-template assembling-machine `
  --target-field graphics_set `
  --animation-speed 0.6 `
  --scale 0.35 `
  --shift 0,-0.2
```

Icon example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py icon `
  --asset-name ei-threshold-array `
  --source output/meshy/threshold-array/icon-source.png
```

Render bundle example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py render-bundle `
  --asset-name ei-threshold-array `
  --bundle Render.zip `
  --line-length 8 `
  --frame-count 64 `
  --scale 0.35 `
  --shift 0,-0.2
```

Raw preset frame pack example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py render-bundle `
  --asset-name ei-threshold-array `
  --bundle output/meshy/ei-threshold-array/Render `
  --preset-manifest output/meshy/ei-threshold-array/Render/factorio-preset-render-manifest.json `
  --pack-raw-frames `
  --grid 8x8 `
  --line-length 8 `
  --frame-count 64 `
  --emit-water-reflection
```

Promotion dry-run example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py promote `
  --manifest output/meshy/ei-threshold-array/factorio-export/ei-threshold-array.factorio-asset-manifest.json `
  --apply-prototype `
  --prototype-file exotic-space-industries-remembrance/prototypes/.../target.lua `
  --prototype-type assembling-machine `
  --prototype-name ei-threshold-array `
  --field graphics_set `
  --expected-asset-count 4 `
  --require-prototype-identity
```

Gallery example:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py gallery `
  --manifest-glob "output/meshy/*/factorio-export/*.factorio-asset-manifest.json" `
  --output output/meshy/visual-approval-gallery.html `
  --approval-json output/meshy/visual-approval-gallery.json `
  --include-snippet
```

## Output

Each run writes staged files only:

- staged PNG asset(s)
- preview PNG(s), including working-animation previews when present
- `<asset>.factorio-asset-manifest.json`
- `<asset>.prototype-snippet.lua`

These staged files remain generated review artifacts under ignored `output/`. Commit final approved PNGs only after promotion into the mod graphics packs, and commit reproducible procedural source scripts under `.codex/esir/asset-generators/` instead of under an output `source/` folder.

The Lua snippet assumes the staged PNGs will eventually be copied into the graphics folder matching the selected path variable, such as `ei_graphics_entity_path` or `ei_graphics_item_path`. Icon snippets are prototype-table field fragments and keep trailing commas for pasteability inside an item prototype. `--snippet-template`, `--target-prototype-type`, `--target-prototype-name`, and `--target-field` add prototype-aware comments and manifest metadata for safer promotion planning; they do not copy or patch anything.

`promote` prints the exact copy and patch plan by default. It only copies PNGs or edits Lua when `--execute` is present, and prototype patching requires explicit `-- ESIR_ASSET_PROMOTE_START <prototype-name> <field>` / `-- ESIR_ASSET_PROMOTE_END <prototype-name> <field>` markers. Use `--prototype-integration data-raw-assignment` when a marker block should become a guarded `data.raw["type"]["name"].field = ...` assignment instead of a raw snippet fragment.
