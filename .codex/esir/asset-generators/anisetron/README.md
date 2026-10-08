# ANISETRON asset dossier

The current reference 17 pipeline, source hashes, prepared anchors, 128-direction
packing and replay commands are in [reference17/README.md](reference17/README.md).
Its prepared crystal glow was approved October 5, 2026. The reference 16 pipeline
below remains historical provenance; it does not describe the new twin-beam art.

## Historical reference 16

The shipping candidate uses the completed Meshy model unchanged in proportion,
roof geometry, keel and PBR material identity. The user explicitly chose adapting
behavior to the artwork. The added-crown and procedural studies remain historical
staging evidence and are not shipping sources.

## Provenance

- Reference: `C:/Users/Theorun/Documents/1righteousgod/ANISETRON 16.png`.
  SHA256 `af8d9900d5145fc19ce74e9df9737bdbd71f3bb748ae75d9bf42ab9a65595f14`.
- Meshy image-to-3D task `01a10495-1e34-74b8-9610-11bd2c9bb3ea`, previously
  completed and downloaded; this integration performs no additional paid generation.
- Original GLB: `output/meshy/anisetron/meshy-max-detail/anisetron-max-detail.glb`,
  SHA256 `9dde547f67c993fffdd0772f332b3967df5935415049799259cdaa41666b60a5`.
- Source has 792,772 vertices and 1,485,670 triangles, one mesh/material, no animation.
  Preparation retains every source face/UV and external 8K base color plus 4K PBR maps.
- Prepared scene: `output/meshy/anisetron/mesh-faithful/anisetron.blend`.
  Original Meshy shape/materials; architecture, textured crystal region and small
  owner trim are named objects. Crystal extraction selects 10,058 source faces and
  the owner crest 236 faces; emission strength 0.65 uses original albedo.

## Locked transforms and native framing

Preparation converts the GLB through Blender's glTF importer, centers XY beneath
the model, and places the lowest keel tip at Z0. Uniform scale 4.74692964553833 fits
the model within 5.81 tiles projected width and 8 projected height over 64 yaw
headings. Physical bounds are approximately 5.04 wide, 3.53 deep, 8.79 tall.

Render uses `factorioRenderingPreset_v4.blend`, `preset-default`, orthographic
scale 20, 512 square pixels, 32 samples, 64 clockwise directions and one static frame
per direction. Angle 0 is native north; frame 16 east, 32 south, 48 west. Sprite scale
is 1.25, shift 0,0. Each pass packs 8×8 to 4096 square. All nonempty frames must have
at least 16 transparent pixels at each edge, including shadows.

The body is unlifted. A separate shadow-only copy is raised 1.8; native vehicle
height 1.8 is applied only by Factorio. Body/shadow/glow/neutral owner-mask layers
share framing and disable native angle reprojection. The mask is runtime-tinted
only on the small original facade trim; cyan and gold retain baked identity.

The existing lower facade aperture estimate in prepared coordinates is
`(0,1.6245346832275391,3.121613936424255)`. Its exact locked-camera projection
is recorded for every direction in the renderer manifest and exported to
`lib/anisetron-graphics.lua`; native source height/bob is calibrated in engine.

## Reproduction

Run from the repo root with installed Blender 5.1.1. Keep intermediates ignored.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python .codex/esir/asset-generators/anisetron/prepare_meshy.py -- --input output/meshy/anisetron/meshy-max-detail/anisetron-max-detail.glb --output output/meshy/anisetron/mesh-faithful/anisetron.blend
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python .codex/esir/asset-generators/anisetron/render_meshy.py -- --preset-blend factorioRenderingPreset_v4.blend --input output/meshy/anisetron/mesh-faithful/anisetron.blend --asset-name anisetron --output-dir output/meshy/anisetron/mesh-final --no-normalize --frames 64 --directions 64 --animation-frames 1 --passes object,shadow,light-alpha-reduced,mask --resolution 512 --samples 32 --ortho-scale 20 --auto-ortho-max 32 --preflight-margin 0.04 --initial-angle 0 --lighting-profile preset-default --material-report
python .codex/esir/asset-generators/anisetron/package_meshy.py --bundle output/meshy/anisetron/mesh-final --output output/meshy/anisetron/factorio-final
```

`package_meshy.py` checks all alpha bounds, packs four passes, derives the vehicle
and crystal-charge icons from the same source render, delegates 128/64/32 mipmaps
to the shared icon helper, creates a 256 technology icon, and writes source hashes
and the native projected muzzle table. `--preview` is an eight-view draft for
behavior work during the full render; it is not a shipping asset bundle.

## Current evidence — October 4, 2026

The export contains four 4096-square sheets, two 128/64/32 item icon
strips and a 256 technology icon. `output/meshy/anisetron/factorio-final/asset-qc.json`
records the seven shipping PNG hashes and all 256 direction/pass bounds.
Minimum margins are body 72px, glow 118px, mask 167px and shadow 40px, exceeding 16px.
The final shipping PNGs match this fresh package byte-for-byte.

The lower original facade aperture is the emitter. The baseline Singularity
Lance's saturated chromatic textures are reused at 60 percent scale; their
`light-effect` draw layer exposes the origin above the floating hull and keel.
No independently animated crown, altered roof or new architectural geometry is
introduced. Native source attachment follows height and bob automatically.

Sixteen native engine views in `aligned-art` cover eight headings by day/night.
Golden-architecture registration and beam-line fitting give a maximum 1.229752px
perpendicular muzzle error, below the 2px criterion. Thirty-six additional moving
frames cover clockwise, counterclockwise and north-wrap turns; four frozen/static
poses isolate native frame selection. Their maximum error is 1.526088px.
Night crystals and beam are
clear; architecture and the tiny force crest remain dark/subtle. The crest is
approximately 15–31 screen pixels squared in sampled facade-facing views and is
naturally occluded from some rear/side views. These are eight sampled headings,
not 64 runtime-angle measurements. The crest mask is empty in 26 raw directions
where the architecture occludes it; the other body/glow/shadow passes are nonempty
in all 64 directions.

The controller's visual-only lookup predicts one observed native torso step
because physics advances after on_tick. Prediction is bounded by the native
rotation speed and requires consecutive full steps. It leaves native movement
and the actual gameplay arc untouched. An abrupt unseen goal change can produce
a one-tick ambiguity; the measured clockwise/counterclockwise/wrap/frozen views
are the evidence, not a universal future-heading guarantee.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -Visual -RunName aligned-art
python .codex/esir/asset-generators/anisetron/measure_muzzle.py --bundle output/meshy/anisetron/mesh-final --shots .factorio-qc/anisetron/aligned-art/script-output/anisetron-art --output output/meshy/anisetron/muzzle-static-final.json
foreach($motion in 'turn','counterclockwise','north-wrap'){python .codex/esir/asset-generators/anisetron/measure_turn.py --bundle output/meshy/anisetron/mesh-final --shots ".factorio-qc/anisetron/aligned-art/script-output/anisetron-art/$motion" --output "output/meshy/anisetron/muzzle-$motion-final.json"}
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -RunName final-native
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -Save -RunName bursts1
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 -Resume -SaveInput .factorio-qc/anisetron/bursts1/saves/anisetron-transition.zip -RunName final-replay
python .codex/esir/asset-generators/anisetron/preview_engine.py
```

`final-native` passes 65 current runtime cases, including 100 contacts/24000 normal damage
per upfront charge, quality attribution, target cycling, arc/diplomacy safety,
movement, actual robot resupply, native mining/rebuilding and equipment ghosts.
`bursts1` saves after 25 contacts; `final-replay` passes 4 checks and completes the original
burst at 100 total contacts with one paid opener. `aligned-art` retains sixteen views,
24 real-engine sweep frames, 36 moving turn frames and four frozen/static views.
The entire 100-contact sequence is checked for both frontal and collinear targets.
The earlier native 54-case run tests superseded
per-contact payment and is historical evidence only.

Fresh `anisetron-final2` data inspection checks the single-round trigger, native
tooltip readouts, final recipes/research and shipping references. The conceptual
audit passes 46 models/118 owned sources with zero findings. Repo-wide preflight and
asset-wrapper status remains affected by the preexisting mojibake finding in
`scripts/qc/singularity-lance/angular-results.json`; focused ANISETRON checks pass.
No multiplayer/full-factory performance pass or Git commit/push is included.

Native targeting can start a paid burst against an enemy outside the frontal
arc. The controller damages only eligible targets within the current frontal
120 degrees; absent targets spend the remaining paid time. Removal cancels without
refund. Duration/contact/sweep timing and a zero-default quality-duration hook
live in `lib/anisetron-config.lua`; quality currently improves contact damage.
