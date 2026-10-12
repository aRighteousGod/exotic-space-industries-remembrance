# Acidthrower revision 02 — recessed tanks and pressure head

Model and render comparison, 2026-10-08. Staged at `D:/CodexArtifacts/esir-acidthrower-20261008/revision-02`. No production sprite, prototype or gameplay changes. Revision 01 and both revision 02 source generations are preserved.

## Selected design

The user's final footprint clarification is **2 tiles across and 3 front-to-back**, appearing 3×2 in east/west placement. Use the refined upper-only reference and the separately approved second Meshy generation. Build a new elongated base, rather than reuse the original base.

The fixed base owns the two identical partly recessed upright canisters, clamps, tank plumbing, manifold, supply spine, rotary union and mirrored exterior pipe collars. Only `acid_yaw_*` objects turn around the low forward bearing. One collar is constructed, then its geometry is mirrored exactly. The pressure head retains the selected Meshy housing/cradle and PBR textures; its end cartridge is replaced with exact hollow steel/ceramic nozzle geometry.

The base targets a 1.8×2.8 body within the 2×3 contract. Including its exterior pipe mouths, measured base bounds are `[-1,-1.398,0]` to `[1,1.380,0.921]`. The Blender frame uses +Y forward/north, Z up, and one unit per tile. All exports share origin `(0,0,0)`. glTF applies its normal Y-up coordinate conversion on export.

Native fluid connection tiles stay at Factorio `(-0.5,+1)` and `(+0.5,+1)`; adjacent pipe centres are `(-1.5,+1)` and `(+1.5,+1)`. Physical mouth centres in Blender are `(-1,-1,0.29)` and `(+1,-1,0.29)`, facing outward. These model coordinates preserve the existing contract; engine attachment validation is deferred to sprite integration.

## Deliverables

| Path relative to artifact root | Role |
| --- | --- |
| `gallery/index.html` | Local interactive facing/aim/assembly comparison and review links |
| `gallery/four-facings.png` | Centred N/E/S/W views, identical scale |
| `gallery/native-size.png` | 64 px/tile render and 32 px/tile display previews |
| `gallery/connector-pair.png`, `gallery/nozzle.png` | Mechanical close-ups |
| `gallery/forward-arc.gif` | Five actual aim keyposes per facing, ping-pong within ±48° |
| `prepared/assembled.glb` | Complete model |
| `prepared/base.glb` | Fixed base including both canisters |
| `prepared/head-only.glb` | Base-free rotating head; no canisters |
| `prepared/acidthrower-revision02.blend` | Editable geometry, materials and source images |
| `model-anchors.json` | Shared origin, bearing, muzzle and object ownership |
| `renders/{base,assembled,head-only,details}` | Original preset object/shadow frames, manifests and actual pose records |
| `review-sheets/` | Losslessly packed review frames, separate object/shadow channels |
| `source/` | Both Meshy attempts, both references/prompts, ledger, source inspection and base material tiles |

Bearing is `(0,0.55,0.43)`. Forward muzzle anchor is approximately `(0.0572494,1.4230506,0.8687214)`, with axis `(0,1,0)`. The small inherited lateral offset is recorded rather than hidden; calibrate the engine attachment from actual renders during production integration.

## Generation and cost

Both revision 02 requests used Meshy 7.1, standard PBR, `geometry_resolution=4k`, `texture_resolution=8k`, `should_texture=true`, `should_remesh=false`, and no image enhancement. Construction does not rely on Meshy's deprecated symmetry setting.

| Generation | Task | Credits | Selection |
| --- | --- | --- | --- |
| Initial upper-only | `01a11d4e-da36-7533-8456-548c257d7675` | 40 | Superseded after revised reference |
| Refined pressure monitor | `01a11d54-914b-71d8-999c-62527661d785` | 40 | User explicitly approved the additional 40-credit generation |

Revision 02 spent **80 credits total**; balance changed from 1154 to 1074. This is separate from revision 01. No further generation is needed to replay these local construction/render steps.

Selected source SHA256: `11eed7c4933ebcc337041d470f8c36bfcc05891527680d9e550f7d82a8b2d444`.
Selected reference SHA256: `ee553b19fda792816fae17f1e2cddf3d123d625de3e7bc6f8489bdce93f58cd1`.
The source contains an 8192px base-color image and 4096px metal/roughness and normal images. Their embedded bytes survive unchanged in the assembled and head-only exports. Procedural base material tiles are 512px baked textures.

## Replay

Run from the repository root. Requires the repo's `factorioRenderingPreset_v4.blend`, the shared `render_factorio_preset.py`, Blender 5.1.1, Python with Pillow, and the already downloaded `source/upper-refined.glb`. Copy the durable generators in `.codex/esir/asset-generators/acidthrower-turret/revision-02/` to the artifact root before running. Exact reference prompts are under `.codex/esir/art-prompts/acidthrower-turret-revision-02-*.md` and `source/` in the artifact folder.

```powershell
$acidRoot = 'D:/CodexArtifacts/esir-acidthrower-20261008/revision-02'
$env:ESIR_ACID_REVISION_ROOT = $acidRoot
$acidBlender = 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
& $acidBlender --factory-startup --background --python-exit-code 1 --python "$acidRoot/prepare_revision.py"
if ($LASTEXITCODE -ne 0) { throw 'Model preparation failed' }
python "$acidRoot/check_models.py" --root $acidRoot
if ($LASTEXITCODE -ne 0) { throw 'Export identity check failed' }
& $acidBlender --factory-startup --background --python-exit-code 1 --python "$acidRoot/check_continuous_clearance.py"
if ($LASTEXITCODE -ne 0) { throw 'Continuous clearance check failed' }
& "$acidRoot/invoke-renders.ps1"
& "$acidRoot/invoke-details.ps1"
python "$acidRoot/build_gallery.py"
if ($LASTEXITCODE -ne 0) { throw 'Gallery QA failed' }
```

`prepare_revision.py` calls `base_geometry.py`, preserves the selected source hash, cuts only the final source nozzle cartridge, constructs the precise replacement nozzle and exports every role from the same object set. Meshy is not called by any replay script. The same output paths are replaced on replay; select another artifact root and copy source inputs there if preserving this render run is desired.

The preset renders 448×448 frames at 64 px/tile, orthographic scale 7, 32 samples, CUDA; details are 1792×1792 at 256 px/tile. Camera and default preset lighting are retained. This comparison deliberately fixes camera scale rather than auto-fitting roles independently; all frames pass measured bounds checks with at least 93px margin. Object and shadow channels are separate. Gallery compositing displays shadow masks at 50% opacity; raw masks and packed sheets remain unchanged. No color correction is applied to object pixels.

Base frames 1–4 are N/E/S/W. Assembled/head frames have 5 columns of relative aims `[-48,-24,0,24,48]` and 4 facing rows. Centred frames are `3,8,13,18`. These 20-frame review sheets are **not** production 64-direction sheets. High-resolution detail frames 1–4 are centred N/E/S/W.

## Validation and review notes

- `geometry-qa.json`: matching connector vertices within `5.9604645e-8` tile; full fixed assembly inside footprint; 33 head poses over ±48°; minimum rear-hardware AABB separation about 0.459 tile; bearing contact at Z=0.43.
- `continuous-clearance-qa.json`: between-sample proof expands each sampled head bound in XY by 0.0229924 tile, the maximum possible vertex motion to its nearest sample. The expanded envelopes clear all 72 fixed non-bearing components and remain in the footprint throughout the arc. Intentional bearing engagement is explicitly excluded.
- `model-integrity.json`: full/separate component geometry and transforms match; original source texture bytes preserved; base and head object sets are disjoint and their union is the complete model.
- `render-qa.json`: 96 object/shadow pass frames and 48 actual poses checked, correct dimensions and angle mapping, nonempty/unclipped bounds, lossless raw-frame packing.
- Visual review of all four centred detail views confirms seated bearing, recessed matching tanks, symmetric collars and visible hollow ceramic outlet. Broad base/tank surfaces are cleaner than the Meshy head; consider matching wear and material contrast after selecting the model.

The neutral `acid_trim_fixed_rear_panel` is separated for eventual owner tint. It has no runtime mask export yet. Deployment motion, production directional sheets, owner masks, sprite integration, muzzle attachment calibration in Factorio and the original firing flash/alignment repair remain outside this model-comparison iteration. No headless Factorio run is claimed for these staged files.

Benign Blender log messages include an old preset driver evaluating before its frame parameters are replaced, an unavailable HIP backend while CUDA is selected, and an 8-byte shutdown allocation warning. Actual angle assertions and completed object/shadow files are the render evidence.
