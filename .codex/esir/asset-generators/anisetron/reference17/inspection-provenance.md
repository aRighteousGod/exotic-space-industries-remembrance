# ANISETRON 17 — regenerated Meshy model

Generated and inspected October 4, 2026 from the user's replacement reference.
This is a historical original-model review. At inspection time, the in-game
sheets still used the previous ANISETRON 16 source. See the [current asset
dossier](README.md) for the subsequently integrated 128-direction ANISETRON 17.

## Provenance and request

- Source image: `C:/Users/Theorun/Documents/1righteousgod/ANISETRON 17.png`.
- Image SHA256: `b892560fb45538f3231624b3152a5967cab384f96daade0778f07a119a6e7d35`.
- Meshy image-to-3D task: `01a109e4-32e3-76e7-b8b3-7188f94993a1`.
- User explicitly authorized the 40-credit generation. The completed task reports
  40 credits consumed.
- Request: Meshy 7.1, standard model, 4K geometry, 8K texture, PBR enabled,
  texturing enabled, remeshing disabled, image enhancement disabled, GLB output,
  alpha and cardinal thumbnails requested. The original reference was sent directly.
- Local model: `output/meshy/anisetron/reference17/anisetron17-max-detail.glb`.
- Model SHA256: `6e866e9d537e330fe2e20ddc89ccd071955562f0eca114db4dc2e4999a706bfc`.
- Length: 101,800,988 bytes; one mesh/material/node; no animation, skin or camera.
- 546,599 vertices and 1,031,452 triangles, with UV0 and normals.
- Embedded textures: 8192-square albedo and 4096-square metallic/roughness and
  normal maps. The external original maps were also downloaded beside the GLB.

## Art review

The model captures the exposed upper teal crystal, compact chapel mass, split
gold-ribbed roof, side finials and shorter pointed keel. The depicted facade
crystal is present. No large modeled laser extrusion is visible in the eight
views. The upper crystal remains an architectural component of the source;
the reference depicts the front crystal as the beam origin.

The eight inspection directions retain every original face/vertex, UV and PBR
material. There is no added crown, geometry edit, crystal segmentation, neutral
crest, material lift, gamma correction or added emission. Imported world
transforms are flattened, then one uniform scale centers XY and places the lowest
keel tip at Z0. Scale 4.939079761505127 fits the actual vertices to approximately
5.982 tiles projected width and 8 projected height across 64 measured headings.

Rendering uses the local `factorioRenderingPreset_v4.blend`, `preset-default`,
512-square frames, 16 Cycles samples, eight static directions and ortho scale 20.
The body is unlifted; separate shadow-only copies are raised 1.8. Camera framing
checks all eight directions, and all 16 raw body/shadow frames have at least 60px
transparent margin. A common crop and uniform review enlargement preserve the
relative scale of directions in the board and turntable.

Artifacts:

- `output/meshy/anisetron/reference17/eight-directions.png`
- `output/meshy/anisetron/reference17/turntable.gif`
- `output/meshy/anisetron/reference17/inspection.blend`
- `output/meshy/anisetron/reference17/model-qc.json`
- `output/meshy/anisetron/reference17/inspection/factorio-preset-render-manifest.json`
- `output/meshy/anisetron/reference17/inspection-render.log`
- `output/meshy/anisetron/reference17/{request-plan,creation,task-status}.json`

These yaw labels are source inspection headings, not a calibrated native sprite
direction contract. At inspection time, the new muzzle, force crest, emission
regions, native beam alignment and final sheets awaited preparation after art
review. That work is recorded in the current dossier; old reference16 coordinates
and color-region thresholds must not be reused blindly.

## Replay without additional Meshy credits

From the repo root with Blender 5.1.1 and the downloaded source GLB:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python .codex/esir/asset-generators/anisetron/reference17/inspect_reference.py -- --preset-blend factorioRenderingPreset_v4.blend --input output/meshy/anisetron/reference17/anisetron17-max-detail.glb --asset-name anisetron17-inspection --output-dir output/meshy/anisetron/reference17/inspection --no-normalize --frames 8 --directions 8 --animation-frames 1 --passes object,shadow --resolution 512 --samples 16 --ortho-scale 20 --auto-ortho-max 32 --preflight-margin 0.04 --initial-angle 0 --lighting-profile preset-default --material-report --save-blend output/meshy/anisetron/reference17/inspection.blend
python .codex/esir/asset-generators/anisetron/reference17/qc_reference.py
python .codex/esir/asset-generators/anisetron/reference17/review_reference.py --bundle output/meshy/anisetron/reference17/inspection --output output/meshy/anisetron/reference17/eight-directions.png --turntable-output output/meshy/anisetron/reference17/turntable.gif
```

Model/header validation, embedded-map dimensions, triangle/vertex count
preservation, alpha bounds, Python syntax and the actual eight-view Blender render
pass. This is model inspection, not fresh Factorio runtime/asset integration QC.
No Git commit or push is included.
