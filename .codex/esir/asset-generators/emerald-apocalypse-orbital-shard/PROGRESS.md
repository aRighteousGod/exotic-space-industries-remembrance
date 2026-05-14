# Emerald Apocalypse Orbital Shard Progress

## Durable Prep Slice

- Added replayable prep/isolation script:
  `.codex/esir/asset-generators/emerald-apocalypse-orbital-shard/prepare_emerald_apocalypse_orbital_shard.py`
- Corrected source GLB:
  `C:\Users\Theorun\Documents\Development\Meshy_AI_Emerald_Crystal_Core_0510181142_texture.glb`
- Explicitly excluded Nexus Prism sources from this shard pipeline.
- Script contract:
  - Import source GLB.
  - Join imported mesh objects when needed.
  - Apply one shared center-origin normalization transform to target max size `1.35`.
  - Export prepared shard GLB and manifest.
  - Duplicate the same normalized mesh, isolate emerald/cyan crystal-face geometry, and export crystal-face GLB plus manifest.

## Output Targets

- Prepared full shard:
  `output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-prepared.glb`
- Prepared manifest:
  `output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-prepared.manifest.json`
- Crystal-face isolation:
  `output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-crystal-faces.glb`
- Crystal-face manifest:
  `output/meshy/emerald-apocalypse-orbital-shard/prepared/emerald-apocalypse-orbital-shard-crystal-faces.manifest.json`

## Current Status

- Prepared GLBs were generated from the corrected Crystal Core source.
- Final base render completed at `512px`, `64` directions, `8x8`, using the Emerald Apocalypse hover tank lighting profile.
- Pixel-derived glow was generated from the final object frames using the tank-style softened glow settings.
- Soft shadow sheet was generated from the final shadow frames with blur `1.2` and alpha scale `0.48`.
- Geometry/crystal-face-only glow was rejected: isolated crystal geometry exposed hidden/internal surfaces and non-crystal green casing leakage.
- Promoted pixel-only shipping sheets:
  - `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-orbital-shard/emerald-apocalypse-orbital-shard.png`
  - `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-orbital-shard/emerald-apocalypse-orbital-shard-glow.png`
  - `exotic-space-industries-remembrance/graphics/entities/emerald-apocalypse-orbital-shard/emerald-apocalypse-orbital-shard-shadow.png`
- Runtime/prototype Lua now wires the promoted sheets through `ei-emerald-apocalypse-hover-tank-orbital-shard`.
- Runtime visuals use `rendering.draw_animation` from the shard's autonomous position: skirmish/linger faces the last enemy target, moving idle faces the tank travel direction, and stationary idle faces outward from the tank center.

## Validation

- Object frames: `64/64` non-empty, minimum alpha margin `73px`.
- Pixel glow frames: `64/64` non-empty, minimum alpha margin `71px`.
- Soft shadow frames: `64/64` non-empty, minimum alpha margin `90px`.
- Final validation report:
  `output/meshy/emerald-apocalypse-orbital-shard/Render-final-64-v1/emerald-apocalypse-orbital-shard-final-validation.json`
- Final review strip:
  `output/meshy/emerald-apocalypse-orbital-shard/Render-final-64-v1/emerald-apocalypse-orbital-shard-final-review-strip.png`

## Sprite Reduction Pass

- Backed up current `512px` frame shard PNGs to:
  `temp/emerald-apocalypse-orbital-shard/sprite-reduction-backup/`
- Backup includes `RESTORE.md` and `backup-manifest.json`; `temp/` is repo-ignored and not part of the shipped mod package.
- Downsampled active shipping sheets in place:
  - `4096x4096` sheets / `512px` frames to `1024x1024` sheets / `128px` frames.
  - base, pixel glow, and soft shadow all keep the same filenames and `8x8` / `64` direction layout.
- Updated prototype scale compensation:
  - `ORBITAL_SHARD_FRAME_SIZE = 128`
  - `ORBITAL_SHARD_SCALE = 0.64`
- Validation after reduction:
  - base frames: `64/64` non-empty, minimum alpha margin `16px`.
  - pixel glow frames: `64/64` non-empty, minimum alpha margin `16px`.
  - soft shadow frames: `64/64` non-empty, minimum alpha margin `20px`.
  - no edge-touching frames.
- Comparison strip:
  `output/meshy/emerald-apocalypse-orbital-shard/downsample-128/orbital-shard-512-vs-128-comparison-strip.png`
- Validation report:
  `output/meshy/emerald-apocalypse-orbital-shard/downsample-128/downsample-128-validation.json`
