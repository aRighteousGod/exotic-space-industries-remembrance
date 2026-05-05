# Factorio Asset Options

## Default Staging Flow

1. Start from a transparent PNG sheet or source icon art.
2. Stage outputs under `output/meshy/<asset>/factorio-export/`.
3. Inspect the preview PNG.
4. Only after explicit follow-up, copy assets into the mod graphics tree and wire the generated snippet into a prototype.

`output/` is ignored staging. If an asset needs a reusable generator, replay script, hand-written prompt, or promotion note, keep that source under `.codex/esir/asset-generators/` or `.codex/esir/art-prompts/`; generated manifests, snippets, galleries, and previews stay under `output/` unless deliberately promoted as provenance.

## Entity Mode

Use `entity` for static entity pictures, simple `animation` tables, directional sheets, or draft rotated-animation snippets.

Recommended inputs:

- `--sheet`: transparent sheet from Blender or another renderer.
- `--render-manifest`: `.manifest.json` from `$meshy-blender-spritesheet` when available.
- `--scale` and `--shift`: match nearby ESIR entities. Common ESIR generated-entity values are around `0.35` or `0.44/2`, with shifts tuned per prototype.
- `--shadow-sheet`: optional separate shadow layer.

If the render manifest came from `render_spritesheet.py`, the exporter uses `directions`, `columns`, and `frame_size` to infer `direction_count`, `line_length`, and frame dimensions.

## Machine Mode

Use `machine` for assembling-machine-style `graphics_set` drafts:

- base sheet becomes `graphics_set.animation`
- optional `--shadow-sheet` becomes a `draw_as_shadow` layer
- optional `--working-sheet` becomes one `working_visualisations` animation
- optional `--working-shadow-sheet` becomes a `draw_as_shadow` layer inside that working animation

Pass `--working-frame-count`, `--working-line-length`, and `--animation-speed` for actual animated sheets. If a working manifest is available, it can infer frame size and line length, but animation timing is still a design choice.

## Icon Mode

Use `icon` for item/source art. It reuses the existing ESIR item icon prep behavior:

- removes edge-connected light neutral backgrounds
- fits the subject onto a transparent `128x128` canvas
- emits a horizontal `128/64/32` mip strip
- generates a snippet with `icon_size = 128` and `icon_mipmaps = 3`

The generated icon snippet is a set of item prototype fields, not a standalone Lua chunk. Its trailing commas are intentional so the fields can be pasted into an existing prototype table.

## Render Bundle Mode

Use `render-bundle` when starting from the local Factorio rendering preset output rather than a single scripted sheet. It accepts `Render.zip`, an extracted `Render` folder containing `.Sheets`, or raw preset frame folders such as `Render/Object/0001.png`.

Expected preset sheet mapping:

- `object_0.png`: base animation sheet.
- `object_shadow_0.png`: `draw_as_shadow` layer.
- `object_lightAR_0.png`: preferred reduced/alpha-safe light layer.
- `object_lightA_0.png`: alternate additive light layer.
- `object_lightGlaredA_0.png`: alternate glared additive light layer.
- `object_light_0.png` and `object_lightGlared_0.png`: staged but not used in snippets unless `--allow-opaque-light-layer` is passed, because they may be full-alpha sheets.
- `object_mask_0.png`: staged color mask or manual post-processing source.
- `WaterReflection.png`: staged water reflection source.

Default assumptions match the sample bundle: `line_length = 8`, `frame_count = 64`, `direction_count = 1`, and `384x384` cells. Override frame dimensions or counts if a different preset export was used.

When staging output produced by `render_factorio_preset.py`, pass `--preset-manifest output/meshy/<asset>/Render/factorio-preset-render-manifest.json` or let the orchestrator supply it. The exporter uses that manifest to infer direction-major layouts such as `frame_count = 16`, `direction_count = 4`.

Raw frame packing:

- Pass `--pack-raw-frames` to ignore `.Sheets` and pack raw folders with PIL.
- `--grid` accepts `2x2`, `4x4`, `8x8`, or another explicit columns-by-rows grid.
- The packer natural-sorts frame names, infers tile size from the first frame, validates every frame dimension, and never renames or mutates source folders.
- Output sheet names follow the preset bundle: `object_0.png`, `object_shadow_0.png`, `object_lightAR_0.png`, `object_lightA_0.png`, `object_mask_0.png`, and `WaterReflection.png`.
- Use `--black-to-transparent rgb-zero` only for legacy helper outputs that intentionally encode transparency as pure black.
- Large raw-frame exports are split automatically when they exceed the selected grid. `object_0.png`, `object_0_1.png`, `object_0_2.png`, and matching shadow/light sheets are staged as Factorio `stripes` with explicit `width_in_frames` and `height_in_frames`.
- If a preset already contains `object_0_1.png` style sheets, the exporter validates numbering continuity and emits the same `stripes` layout without renaming source folders.

Use `--light-layer glow` for a draft `draw_as_glow` layer, `--light-layer light` for `draw_as_light`, or `--light-layer none` to stage light sheets without snippet wiring. For Factorio, only one of `draw_as_shadow`, `draw_as_glow`, and `draw_as_light` belongs on any single layer.

Use `--emit-water-reflection` when the staged `WaterReflection.png` should appear in the snippet. Use `--water-reflection-placement auto|top-level|graphics-set`; `auto` is the default, using `graphics_set.water_reflection` for machine snippets and top-level `water_reflection` for entity snippets.

The generated snippet is intentionally a draft. The preset can produce richer layers than the standard Meshy scripts; inspect the previews and decide whether glow, light, mask, or water reflection belongs in the final prototype.

## Promotion Mode

Use `promote` only after the staged preview and snippet have been inspected. Default behavior is a dry-run plan:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py promote `
  --manifest output/meshy/ei-example/factorio-export/ei-example.factorio-asset-manifest.json `
  --copy-assets `
  --graphics-destination exotic-space-industries-remembrance/graphics/entity/ei-example
```

Promotion safeguards:

- Without `--execute`, no files are copied and no Lua is edited.
- `--copy-assets` requires an explicit `--graphics-destination`.
- `--apply-prototype` requires `--prototype-file`, `--prototype-type`, `--prototype-name`, and `--field`.
- `--expected-asset-count` fails the plan if the manifest exposes more or fewer promotable PNGs than expected.
- `--require-prototype-identity` requires the target Lua file to mention the requested prototype type and name before patching.
- `--prototype-integration data-raw-assignment` wraps the generated snippet in a guarded `data.raw["type"]["name"]` assignment for explicit data-stage integration.
- Prototype patching replaces only a marker block:

```lua
-- ESIR_ASSET_PROMOTE_START ei-example graphics_set
-- staged snippet goes here
-- ESIR_ASSET_PROMOTE_END ei-example graphics_set
```

No broad Lua rewriting is attempted. If the marker block is missing, dry-run reports the requirement and execute mode stops.

## Gallery Mode

Use `gallery` when several staged manifests need a fast visual approval pass:

```powershell
python .codex/skills/esir-factorio-asset-export/scripts/export_factorio_asset.py gallery `
  --manifest-glob "output/meshy/*/factorio-export/*.factorio-asset-manifest.json" `
  --output output/meshy/visual-approval-gallery.html `
  --approval-json output/meshy/visual-approval-gallery.json `
  --include-snippet
```

The gallery reads existing staged manifests and preview PNGs. It does not approve, reject, promote, copy, or patch assets by itself. For icon manifests, the gallery prefers the generated `*.preview.png`, reusing the `$esir-item-icon-prep` preview path rather than showing only the full mip strip.

## Prototype-Aware Snippet Hints

All staging modes accept:

- `--snippet-template auto|entity|machine|assembling-machine|furnace|lab|beacon|turret|car|unit|simple-entity|container|corpse|item|recipe|technology`
- `--target-prototype-type`
- `--target-prototype-name`
- `--target-field`

These options add comments to the snippet and `prototype_template` metadata to the manifest. They are deliberately hints, not a Lua parser and not a promotion mechanism. Use them to align generated snippets with a later `promote --apply-prototype` dry-run.

## ESIR Notes

- Prefer readable silhouettes over maximum texture detail.
- Treat generated assets as drafts until checked in-game.
- Keep staged filenames close to the final prototype name, usually `ei-...`.
- Generated snippets are fragments, not automatic prototype edits.
- Existing ESIR snippets commonly use `size`, `width`, `height`, `shift`, `scale`, `line_length`, and `frame_count`; this skill keeps those fields visible so hand-tuning stays straightforward.
