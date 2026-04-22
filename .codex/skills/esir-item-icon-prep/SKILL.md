---
name: esir-item-icon-prep
description: Use when ESIR item art needs to be turned into a transparent Factorio item icon strip, especially when source art has a baked light checkerboard or white background and must end up as a `128/64/32` mipmapped item icon under `exotic-space-industries-remembrance/graphics/items/`.
---

# ESIR Item Icon Prep

Use this when a user drops source art for an ESIR item and wants it converted into a shippable Factorio icon.

The bundled helper:
- removes edge-connected light neutral backgrounds, including baked checkerboards
- preserves already-transparent sources
- fits the subject onto a `128x128` transparent canvas
- emits a horizontal `128/64/32` mip strip (`224x128`)

## Workflow

1. Confirm the source art path and the destination item icon path.
2. If the destination file will be overwritten, write a backup into `tmp/`.
3. Run `scripts/build_factorio_item_icon.py`.
4. Inspect the generated `128x128` preview or the final strip with `view_image`.
5. If the item prototype uses the strip directly, keep:
   - `icon_size = 128`
   - `icon_mipmaps = 3`
6. If the item is already wired into a prototype, run the ESIR fast QC pass.

## Command

Run from the repo root:

```powershell
python .codex/skills/esir-item-icon-prep/scripts/build_factorio_item_icon.py `
  --source exotic-space-industries-remembrance/graphics/items/calcite-bed.png `
  --output exotic-space-industries-remembrance/graphics/items/calcite-bed.png `
  --backup tmp/calcite-bed-source-original.png `
  --preview tmp/calcite-bed-preview-128.png
```

## Notes

- The helper is for source art, not an already-built `224x128` mip strip.
- Background removal keys off light, low-saturation pixels that are edge-connected to the canvas border, so bright highlights inside the subject are less likely to be eaten.
- The output strip is written into the main mod folder unless you point `--output` somewhere else.

