# Emerald Apocalypse Hover Tank Asset Pipeline Slice

Replayable staging for the v1 Emerald Apocalypse Hover Tank model. This slice is intentionally limited to generator/provenance files under this directory and generated staging under `output/meshy/emerald-apocalypse-hover-tank/`.

## Source

`C:\Users\Theorun\Documents\Development\Meshy_AI_Emerald_Crystal_Canno_0509011313_texture.glb`

The source GLB is treated as read-only. The preparation script imports it into Blender, detects the thin extremely bright green cylinder protruding from the forward barrel, preserves its endpoint metadata, removes it from the renderable model, and exports a hidden evidence GLB for the removed artifact.

## Replay Commands

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .\.codex\esir\asset-generators\emerald-apocalypse-hover-tank\prepare_emerald_apocalypse_hover_tank.py -- `
  --source "C:\Users\Theorun\Documents\Development\Meshy_AI_Emerald_Crystal_Canno_0509011313_texture.glb" `
  --out .\output\meshy\emerald-apocalypse-hover-tank\prepared\emerald-apocalypse-hover-tank-prepared.glb `
  --artifact-out .\output\meshy\emerald-apocalypse-hover-tank\prepared\emerald-apocalypse-hover-tank-removed-forward-cylinder.glb
```

Preset preflight, cheap and non-rendering:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .\.codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py -- `
  --preset-blend .\factorioRenderingPreset_v4.blend `
  --input .\output\meshy\emerald-apocalypse-hover-tank\prepared\emerald-apocalypse-hover-tank-prepared.glb `
  --asset-name emerald-apocalypse-hover-tank `
  --output-dir .\output\meshy\emerald-apocalypse-hover-tank\Render `
  --passes object,shadow,light-alpha-reduced,light-alpha,mask `
  --quality smoke `
  --frames 64 `
  --directions 64 `
  --animation-frames 1 `
  --ortho-scale 7 `
  --tile-size 64 `
  --resolution 448 `
  --grid 8x8 `
  --pack-sheets `
  --preflight-only `
  --auto-prep `
  --prep-origin-mode ground `
  --prep-target-size 4.4 `
  --prep-alpha-mode report `
  --material-report `
  --warn-alpha-materials `
  --footprint-tiles 4x4
```

Final render, intentionally not run unless the slice is approved:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .\.codex\skills\meshy-blender-spritesheet\scripts\render_factorio_preset.py -- `
  --preset-blend .\factorioRenderingPreset_v4.blend `
  --input .\output\meshy\emerald-apocalypse-hover-tank\prepared\emerald-apocalypse-hover-tank-prepared.glb `
  --asset-name emerald-apocalypse-hover-tank `
  --output-dir .\output\meshy\emerald-apocalypse-hover-tank\Render `
  --passes object,shadow,light-alpha-reduced,light-alpha,mask `
  --quality final `
  --samples 128 `
  --frames 64 `
  --directions 64 `
  --animation-frames 1 `
  --ortho-scale 7 `
  --tile-size 64 `
  --resolution 448 `
  --grid 8x8 `
  --pack-sheets `
  --auto-prep `
  --prep-origin-mode ground `
  --prep-target-size 4.4 `
  --prep-alpha-mode report `
  --material-report `
  --warn-alpha-materials `
  --footprint-tiles 4x4
```

Effect provenance and optional procedural sheets:

```powershell
python .\.codex\esir\asset-generators\emerald-apocalypse-hover-tank\generate_emerald_apocalypse_effects.py `
  --out-dir .\output\meshy\emerald-apocalypse-hover-tank\effects
```

## Role Classification

- `Object/*.png` or `.Sheets/object_0.png`: base sprite candidate.
- `Shadow/*.png` or `.Sheets/object_shadow_0.png`: lower-right shadow candidate.
- `Light A Reduced/*.png` and `Light A/*.png`: emerald glow/light candidates. Keep additive companion sheets separate.
- `ColorMask/*.png` or `.Sheets/object_mask_0.png`: runtime color-mask evidence only. The hover tank is vehicle-like, so an owner-readability mask may be appropriate for narrow trim, but it must be reviewed before Lua wiring.
- Removed forward cylinder: evidence artifact only; do not render as part of the base model. Use the recorded muzzle endpoint for muzzle/beam alignment.

## Effect Direction

The companion effect specs are original Emerald Apocalypse prompts and procedural parameters. They use caged glass, acid-saint emerald, blackened industrial plating, null sap, and hover-tank pressure-wave motifs. They are deliberately not derived from the Singularity Lance prismatic beam or Gaian saucer wake sheets.
