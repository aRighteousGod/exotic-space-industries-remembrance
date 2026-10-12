# Acidthrower revision03 icons

2026-10-10: replace the item/entity and technology icons with a full-model
Factorio-preset render of the reviewed revision03 machine. No Meshy generation,
model change, machine-sprite replacement or gameplay change is involved.

Source: `D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/prepared/assembled.glb`.
Model SHA256: `4dcaaa053de76f109ae31ff202eba0178c932d36f03e63bdcdc11622356908d0`.
Artifacts: `D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/icons`.

Render the complete fixed and rotating assemblies together with the ordinary PBR
materials and unchanged Factorio preset lighting. Four comparison views use 45,
135, 225 and 315 degrees of clockwise placement yaw. Select frame 2, which shows
the nozzle opening, pressure housing and both rear vessels. Use the transparent
object pass for icons; retain the separate shadow pass as render evidence.

## Shipping ownership

- Replace `exotic-space-industries-remembrance-graphics-6/graphics/items/acid-turret.png`
  in place with a transparent 224x128 strip: 128/64/32 square levels. Item and
  fluid-turret declarations use `icon_size=128`, matching the item-icon convention.
- Replace `exotic-space-industries-remembrance-graphics-6/graphics/techs/acid-turret.png`
  in place with a transparent 256x256 icon. Technology uses `icon_size=256`.
- The family moved to Graphics 6 on 2026-10-12 without changing its pixels.
  Historical QA records below retain their original Graphics 3 paths.
  Git preserves committed originals; no backups,
  alternate icons or previews belong in shipping folders.
- The recipe has a single result and inherits its item icon. Informatron uses that
  same item identity. The late technology weight badge stays on top of the new icon.
- Remaining PBR, head rotation, clearance and glow checks were skipped at the user's
  request. Icon validation does not claim to rerun those model checks.

## Replay

Run from the repository root. Copy these two generators into the artifact directory.

```powershell
$acidIconRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/icons'
$env:TEMP="$acidIconRoot/cache"
$env:TMP=$env:TEMP
$env:CUDA_CACHE_PATH="$acidIconRoot/cache/cuda"
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
$ErrorActionPreference='Continue'
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' `
  --factory-startup --background --python-exit-code 1 `
  --python "$acidIconRoot/render_icons.py" -- `
  --preset-blend factorioRenderingPreset_v4.blend `
  --input D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/prepared/assembled.glb `
  --asset-name acidthrower-icon-revision03 --output-dir "$acidIconRoot/renders" `
  --frames 4 --directions 4 --animation-frames 1 --grid 4x1 --initial-angle 45 `
  --ortho-scale 5 --tile-size 128 --no-normalize --passes object,shadow `
  --quality final --samples 64 --cycles-compute-device cuda `
  --material-report --fail-framing-risk *> "$acidIconRoot/render.log"
$acidIconExit=$LASTEXITCODE
$ErrorActionPreference='Stop'
if($acidIconExit -ne 0){throw "Icon render failed: $acidIconExit"}
python -B "$acidIconRoot/build_icons.py" --root $acidIconRoot --frame 2
```

`build_icons.py` uses the shared item-icon helper's transparent subject isolation.
The fitting and mip placement retain straight alpha without masking it a second
time. Item maximum extent is 118px; technology maximum extent is 236px. The script
cleans hidden RGB and records sizes, transparency, bounds and output hashes in
`icon-qa.json`. `icon-review.png` shows the 256/128/64/32 images at native sizes.

Inspect the engine's final item and fluid-turret icon fields and the technology's
first `icons` layer, since `tech-weight-badges.lua` converts the latter to a layered
icon. Confirm the recipe still resolves to the same item. Heavy engine output stays
on D: and is external, report-only storage under the housekeeping policy.
