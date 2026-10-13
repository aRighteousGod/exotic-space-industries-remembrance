---
name: esir-png-quantize
description: "Convert existing PNG sprites, animation atlases and icons to shared 256-entry indexed palettes, with reproducible receipts and static or animated comparisons. Use for requested palette reduction or indexed artwork; a request for PNG compression alone does not imply lossy conversion."
---

# ESIR PNG Quantize

Use existing PNGs directly; no Blender or Meshy session is needed. This skill creates
staged derivatives. It does not promote artwork, edit prototypes or rebuild mod packs.

## Choose the groups

- Confirm the request permits lossy RGB and intermediate-alpha changes. An explicit
  request for palette conversion already provides that direction; do not ask again.
- Read [the input format](references/input-format.md) before creating a spec.
- Group layers and animation states whose colors must match under one shared palette.
  Give unrelated icons their own groups. Do not train a universal palette for a mod.
- Declare shadows, tint masks, normal maps, glow and other special layers as `copy`
  by default. Their values may encode behavior rather than ordinary surface color.
- Retain the lossless source and its original validation evidence. Never claim that
  the derivative passed a lossless comparison against that source.

## Convert and inspect

Use task-local dependencies: Pillow, numpy and `imagequant==1.1.5` (bundled
libimagequant 2.15.1). The converter records versions; `--tool-path` accepts an
existing task-local `pip --target` directory. Installation and example commands
are in the input-format reference.

```powershell
python -B .codex/skills/esir-png-quantize/scripts/quantize_pngs.py --spec output/my-asset/palette.json --output output/my-asset/indexed --dry-run
python -B .codex/skills/esir-png-quantize/scripts/quantize_pngs.py --spec output/my-asset/palette.json --output output/my-asset/indexed --tool-path output/png-quantize-tools
python -B .codex/skills/esir-png-quantize/scripts/compare_pngs.py --spec output/my-asset/palette.json --conversion output/my-asset/indexed --output output/my-asset/comparison
```

- The tool uses up to 256 RGBA entries, no dithering and unchanged image dimensions.
  It preserves source alpha 0 and 255 exactly. RGB and intermediate alpha may change.
- Each declared cell contributes deterministic visible samples. Use `all` for icons
  or small groups when retaining every training pixel is useful.
- Review contact sheets and assembled animations on both backgrounds. Check shared
  layer boundaries, antialiased edges, thin details and changes between frames.
  Preview alpha-over is not evidence of native Factorio shadow blending.
- Report actual output bytes and visual limitations. Indexed PNG savings do not
  establish a reduction in Factorio texture memory.
- Use `--resume` only with the same spec, source, tools and frozen palettes. A mismatch
  requires a fresh output directory; do not edit receipts to bypass it.

Keep outputs in ignored staging. Follow [housekeeping](../esir-dev/references/housekeeping.md):
retain sources, specs and review evidence; register only disposable intermediates.
Route a requested shipping replacement through
[asset export](../esir-factorio-asset-export/SKILL.md) or
[the asset pipeline](../esir-asset-pipeline/SKILL.md), honoring existing authorization.

## Validation and precedent

`scripts/validate_skill.py` exercises alpha classes, shared mapping, metadata,
protected copies, dry-runs, path rejection and interrupted/resumed conversion.
Its optional minigun fixture crops one existing direction; it does not modify art.
See the reference for the reproducible command and retained local validation paths.

The original minigun converter remains under
`.codex/esir/asset-generators/minigun-turret/`; its direction counts, mechanical
families, registration and packaging contracts are deliberately outside this tool.
