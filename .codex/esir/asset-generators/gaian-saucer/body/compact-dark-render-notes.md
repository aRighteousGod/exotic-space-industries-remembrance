# Slipwake Saucer Compact Dark Body Render

Replay note for the compact saucer body rerender shipped as:

- `graphics/entities/gaian-saucer/gaian-saucer_dark_compact.png`
- `graphics/entities/gaian-saucer/gaian-saucer_dark_compact_glow.png`
- `graphics/entities/gaian-saucer/gaian-saucer_dark_compact_shadow.png`

Source model:

`C:\Users\Theorun\Documents\Development\Meshy_AI_Prismatic_Aegis_0505030805_texture.glb`

The accepted dark pass uses the baseline Factorio preset lighting. It intentionally does not use the Emerald v8 brightening flags (`--preset-sun-energy-scale 1.5`, `--preset-view-gamma 1.5`), because that version washed out the saucer shell.

Preview command:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --python ".\.codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py" -- --preset-blend ".\factorioRenderingPreset_v4.blend" --input "C:\Users\Theorun\Documents\Development\Meshy_AI_Prismatic_Aegis_0505030805_texture.glb" --asset-name ei-gaian-saucer-dark-compact-preview --output-dir ".\output\meshy\ei-gaian-saucer\Render-dark-compact-preview-8dir" --passes object,shadow,light-alpha-reduced,mask --quality smoke --samples 256 --cycles-compute-device optix --denoise --frames 8 --directions 8 --animation-frames 1 --initial-angle 90 --ortho-scale 6.959680622816086 --no-auto-ortho-scale --tile-size 64 --resolution 256 --grid 8x1 --pack-sheets --auto-prep --prep-origin-mode ground --prep-target-size 4.75 --prep-alpha-mode force-opaque --material-report --warn-alpha-materials --footprint-tiles 4x4
```

Final command:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --python ".\.codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py" -- --preset-blend ".\factorioRenderingPreset_v4.blend" --input "C:\Users\Theorun\Documents\Development\Meshy_AI_Prismatic_Aegis_0505030805_texture.glb" --asset-name ei-gaian-saucer-dark-compact --output-dir ".\output\meshy\ei-gaian-saucer\Render-dark-compact-64" --passes object,shadow,light-alpha-reduced,mask --quality final --samples 4096 --cycles-compute-device optix --persistent-data --denoise --frames 64 --directions 64 --animation-frames 1 --initial-angle 90 --ortho-scale 6.959680622816086 --no-auto-ortho-scale --tile-size 64 --resolution 256 --grid 8x8 --pack-sheets --auto-prep --prep-origin-mode ground --prep-target-size 4.75 --prep-alpha-mode force-opaque --material-report --warn-alpha-materials --footprint-tiles 4x4
```

Final staged export:

```powershell
python .\.codex\skills\esir-factorio-asset-export\scripts\export_factorio_asset.py render-bundle --asset-name ei-gaian-saucer --filename-root ei-gaian-saucer_dark_compact --output-dir ".\output\meshy\ei-gaian-saucer\factorio-export-dark-compact" --factorio-var main_graphics_entity_path --prototype-kind spider-vehicle --snippet-template entity --target-prototype-type spider-vehicle --target-prototype-name ei-gaian-saucer --target-field graphics_set --scale 0.69 --shadow-scale 0.69 --bundle ".\output\meshy\ei-gaian-saucer\Render-dark-compact-64\.Sheets-final" --preset-manifest ".\output\meshy\ei-gaian-saucer\Render-dark-compact-64\factorio-preset-render-manifest.json" --prototype-mode entity --frame-width 256 --frame-height 256 --line-length 8 --direction-count 64 --light-layer glow --light-source light_reduced
```

QC summary:

- Sheet size: `2048x2048`
- Layout: `64` directions, `8x8`, `256x256` frames
- Prototype scale: `0.69`
- Non-empty frames: `64/64`
- Minimum alpha margin: `40px`
- Edge touches: `0`
- Mean active luma: `38.212`
- RGB clipping after tiny object-layer cap: `0.0%`

The raw baseline render is preserved under `output/meshy/ei-gaian-saucer/Render-dark-compact-64/.Sheets`. The shipped candidate under `.Sheets-final` caps object-layer RGB at `249` only to remove fully clipped prismatic pixels; it does not alter the preset lighting.

## Derived Glow Overlay

The preset `light-alpha-reduced` pass produced an effectively empty black glow sheet for this asset. The shipped glow overlay is therefore derived from the approved compact dark body sheet instead of reusing the preset light pass.

Generator command:

```powershell
python .\.codex\esir\asset-generators\gaian-saucer\body\derive_dark_compact_glow_overlay.py --promote
```

Generator source:

`exotic-space-industries-remembrance/graphics/entities/gaian-saucer/gaian-saucer_dark_compact.png`

Promoted output:

`exotic-space-industries-remembrance/graphics/entities/gaian-saucer/gaian-saucer_dark_compact_glow.png`

Glow style:

- Strong cyan/teal on hard energy edges, prow/wing tips, rim accents, and the central crystal.
- Restrained gold/orange on circuitry and annular ring lines.
- Medium-low magenta on drive scars, underside cuts, and fin accents.
- Sparse hot slivers for the brightest cyan-white ridges.
- Broad hull regions rejected so the black shell remains dominant.

Glow QC summary:

- Sheet size: `2048x2048`
- Layout: `64` directions, `8x8`, `256x256` frames
- Non-empty frames: `64/64`
- Minimum alpha margin: `40px`
- Edge touches: `0`
- Black-alpha pixels: `0`
- Glow coverage: `2.3123%`
- Max per-frame coverage: `2.713%`

Staged previews and metrics:

`output/meshy/ei-gaian-saucer/derived-dark-compact-glow/`
