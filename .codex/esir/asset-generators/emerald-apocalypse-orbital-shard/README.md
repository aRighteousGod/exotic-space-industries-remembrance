# Emerald Apocalypse Orbital Shard Asset Pipeline Slice

Replayable durable prep/isolation slice for the Emerald Apocalypse orbital shard. This directory intentionally contains only generator notes and scripts; generated GLBs and manifests are staged under `output/meshy/emerald-apocalypse-orbital-shard/`.

## Source

`C:\Users\Theorun\Documents\Development\Meshy_AI_Emerald_Crystal_Core_0510181142_texture.glb`

This is the corrected Emerald Crystal Core source model. Do not use any Nexus Prism source for this shard pipeline.

## Prep And Isolation

The Blender script imports the source GLB, joins multiple mesh objects if the import produces more than one, applies one shared center-origin normalization transform with target max size `1.35`, and exports:

- `output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-prepared.glb`
- `output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-crystal-faces.glb`
- matching `.manifest.json` files beside both GLBs

Run from the repository root:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background `
  --python .\.codex\esir\asset-generators\emerald-apocalypse-orbital-shard\prepare_emerald_apocalypse_orbital_shard.py -- `
  --source "C:\Users\Theorun\Documents\Development\Meshy_AI_Emerald_Crystal_Core_0510181142_texture.glb" `
  --out .\output\meshy\emerald-apocalypse-orbital-shard\prepared\emerald-apocalypse-orbital-shard-prepared.glb `
  --crystal-out .\output\meshy\emerald-apocalypse-orbital-shard\prepared\emerald-apocalypse-orbital-shard-crystal-faces.glb
```

The crystal-face isolation is adapted from the local Emerald Apocalypse hover tank crystal overlay precedent, but the object names, manifest `kind`, and scoring contract are shard-specific. It scores emerald/cyan material and texture samples on the normalized mesh, grows one-ring neighboring faces, and preserves source materials on the isolated crystal-face GLB.

## Render Status

Final 64-direction base art was rendered from the prepared Crystal Core model with the Emerald Apocalypse hover tank lighting profile:

- `output/meshy/emerald-apocalypse-orbital-shard/Render-final-64-v1/.Sheets/object_0.png`
- `output/meshy/emerald-apocalypse-orbital-shard/Render-final-64-v1/.Sheets/orbital_shard_pixel_glow_0.png`
- `output/meshy/emerald-apocalypse-orbital-shard/Render-final-64-v1/.Sheets/orbital_shard_shadow_soft_0.png`

The staged crystal-face-only render was rejected. Rendering isolated crystal geometry by itself exposes hidden/internal crystal surfaces and green casing leakage. Use the pixel-derived glow sheet from the full object render unless a later pass adds full-body occlusion/holdout rendering for geometry-only crystal surfaces.

Promoted sheets:

- `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-orbital-shard/emerald-apocalypse-orbital-shard.png`
- `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-orbital-shard/emerald-apocalypse-orbital-shard-glow.png`
- `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-orbital-shard/emerald-apocalypse-orbital-shard-shadow.png`
