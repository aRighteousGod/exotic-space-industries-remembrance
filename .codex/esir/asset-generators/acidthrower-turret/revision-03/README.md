# Acidthrower revision 03

Current 2.1.23 placement, diagonal render and pipe-overlay work is documented in
[EIGHT-WAY.md](EIGHT-WAY.md). Use `scripts/invoke-acid-eight-way-qc.ps1` for current
native acceptance; the old jet calibration runner requires explicit `-LegacyReplay`.

Source: the user's `Documents/Development/acidthrower prototype 2.glb`, selected on 2026-10-09. This revision uses its complete, consistently textured ivory/graphite machine. No additional Meshy generation or credits were required. Revisions 01 and 02 remain preserved.

Artifacts: `D:/CodexArtifacts/esir-acidthrower-20261009/revision-03`.

Shipping ownership (2026-10-12): the seven unchanged machine sheets and complete
pressure-jet effect family are in Graphics 6 under
`graphics/entities/acidthrower-turret/`. The item icon is in `graphics/items/`
and the technology icon in `graphics/techs/`. The main pack retains prototypes.
The native muzzle was subsequently fitted to visible outlet pixels using barrel
length 0.854090101414 and world height 0.886152416900; the source model anchors below are preserved
as historical geometry, not a claim of current visible launch alignment.

Source SHA256: `257f4beadb591807487fbfd1b70ff7f1b02c3e38c284068cbbee38c6ce3e4c17`.

## Model and ownership

The supplied GLB is one connected, textured mesh with 540154 imported indexed vertices and 1009648 triangles, with three embedded 2048px PBR textures. Split the upper front assembly at raw Z=-0.092 and X=-0.085; cap the cut with dark bearing material. Keep both upright vessels and the manifold fixed. Preserve the source texture and the pressure head geometry. Add a low bearing seal and a small neutral owner plate. The final production model excludes the rejected custom pipe collars.

The preset renders 64 pixels per Blender unit; +Y faces north and Z is up. Uniform source scale is 1.47. The shared entity origin is `(0,0,0)`. Bearing: `(0.0014700282,0.6423900127,0.4530966282)`. Muzzle: `(0.0014700640,1.4626500607,0.8426465988)`. The chassis lies inside X=±1 and Y=±1.5. The gameplay footprint remains 2×3 tiles.

Native comparison exposed a ground-grid fit error: the original chassis was only 1.696 tiles wide, and the preset compressed its 2.617-tile length to 1.851 screen tiles in the north/south views. Widen the low deck to two tiles. After placement rotation, compensate world Y by sqrt(2), leaving height unchanged, so the deck follows the native square ground grid. Translate the bearing and tank/manifold centres through that same correction while retaining their local geometry; the canisters stay round and the bearing matches the unchanged head sheet. Head placement and muzzle centre shifts use the corrected bearing XY. Cover and fluid-port coordinates remain native and unchanged. This is a base-art fit correction, not extra pipes.

Final refinement is **prototype offsets only**, per the user's explicit instruction to preserve the reviewed model and sprites. `graphics.lua` shifts the entire rendered assembly 0.18 tile (5.76 native pixels) rearward: north `(0,+0.18)`, east `(-0.18,0)`, south `(0,-0.18)`, west `(+0.18,0)`. Apply that same offset to all base/head/shadow/glow/mask layers and the native muzzle centre. Sprite scale remains 0.5; vanilla covers and fluid ports retain their original scale and positions. The interrupted rear-sidewall mesh trial was undone before it changed any sprite frames. Its artifacts are preserved under `prepared/rejected-port-seat-trial/` and are not used. The raw model gallery shows the centred source art; native captures show the final prototype offset.

Use vanilla `pipecoverspictures()` through the existing fluid box. Keep the mirrored west/east ports at `(-0.5,1)` and `(0.5,1)`. Factorio places and orients the cover sprites, includes their own shadows, and hides each cover when its port is connected. `lower-object-above-shadow`, secondary draw order 2 puts these independent overlays above the base at order 1. No extra pipe sleeves or closed caps are drawn over connected pipes. Exact anchors and object ownership are in `model-anchors.json`.

Exports in `prepared/`:

- `assembled.glb`: entire turret, shared origin.
- `base.glb`: fixed chassis, tanks, manifold and owner plaque.
- `head-only.glb`: only the rotating head and bearing underside, shared origin.
- `head-centred.glb`: identical head with bearing XY moved to zero for reusable directional rendering; absolute height retained.
- `chassis-with-tanks.glb`: fixed assembly, identical to the final base export.
- `acidthrower-revision03.blend`: editable mesh, source materials and named parts.

The rejected collar GLBs, render passes and `prepared/rejected-custom-collars/` preserve the comparison draft. They are not shipping assets. Vanilla graphics are referenced from `__base__` rather than copied into the mod.

`verify_model.py` compares the assembled and head-only exports numerically and tests mesh intersection at every whole degree from -48 through +48. The deliberate bearing contact within 0.025 tile of the seam is excluded from the clearance test.

## Render and sprite contract

Use `factorioRenderingPreset_v4.blend` and the repository preset renderer. Camera, lighting and object/shadow composition are unchanged. Render 448px square at 64px/tile, Cycles CUDA, 64 samples. Fix the rotator's parent inverse and use initial angle zero: frame 1 is north, increasing frames turn clockwise. Every actual frame angle is verified before rendering.

The stationary base uses four cardinal frames, centred crop 320px, horizontal sheet. The head uses 256 directions at 1.40625-degree intervals, centred crop 256px, 16×16 sheet. All leaves use Factorio scale 0.5, giving 32px/tile at native zoom. Packing is lossless, with an eight-pixel minimum alpha margin and transparent RGB cleanup.

The exterior covers are **separate native vanilla overlays**, as requested in the final refinement. The production base pass disables custom collar rendering entirely, including shadows. The custom collar atlas is not shipped or referenced.

| Sheet | Classification |
| --- | --- |
| `acidthrower-base.png` | Fixed chassis/tanks/manifold, diffuse |
| `acidthrower-base_shadow.png` | Fixed assembly shadow, excluding rejected collars |
| `__base__/graphics/entity/pipe-covers/*` | Engine-supplied cover and shadow overlays |
| `acidthrower-base_mask.png` | Neutral owner-colour plaque, runtime tint |
| `acidthrower-base_glow.png` | Isolated green windows/accents |
| `acidthrower-head.png` | Rotating head diffuse |
| `acidthrower-head_shadow.png` | Rotating head shadow |
| `acidthrower-head_glow.png` | Isolated green head accents |

The green AOV is selected from the source texture in linear colour space: G>1.035R, G>2B, G>0.025. It is separate from the ordinary PBR render. The source's small green details remain restrained; the full housing is never an emissive overlay. Owner colour is isolated by the neutral plaque material and never mixed with the glow.

The live graphics module installs the same diffuse/shadow head in all six native animation fields. Prepared, starting-attack, attacking, ending-attack and rotate-for-folding enable the separate glow; folded, preparing and folding do not. The reset states reuse the prepared head animation, so the base includes those same states to avoid a tank/head mismatch. The base uses native `enabled_states`; there is no production control script or polling. Preparing/folding preserve their .08 state speeds and use fifteen repeated logical frame indices without duplicating the sheet. Existing .015 rotation speed, collision/selection footprint, ports, firing arc and attack payload remain unchanged.

The legacy additive full-body overlays, vanilla gun masks/shadows, orange muzzle effect and old LED positions are replaced. The measured bearing offset and muzzle height/length drive the new native stream origin.

## Replay

Run from the repository root with Blender 5.1.1, Python, Pillow and NumPy. Preserve `source/acidthrower-prototype-2.glb` and copy these generators to the artifact root. `render_model.py` imports the shared renderer from the current repository checkout.

```powershell
$acidRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03'
$env:ESIR_ACID_REVISION_ROOT=$acidRoot
$acidBlender='C:/Program Files/Blender Foundation/Blender 5.1/blender.exe'
& $acidBlender --factory-startup --background --python-exit-code 1 --python "$acidRoot/prepare_model.py"
& $acidBlender --factory-startup --background --python-exit-code 1 --python "$acidRoot/finalize_model.py"
& $acidBlender --factory-startup --background --python-exit-code 1 --python "$acidRoot/verify_model.py"
& "$acidRoot/render.ps1"
python "$acidRoot/pack_sheets.py" --root $acidRoot
```

`render.ps1 -BaseOnly` rerenders only the four fixed chassis facings and their shadows/masks. It does not repeat the expensive 256-direction head run. `prepare_model.py` retains the original draft construction for provenance; run `finalize_model.py` before rendering to remove its rejected custom collars and fit the low deck to the native footprint.

After art promotion to `exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret`, validate with the repo `qc-assets` wrapper and the focused acid-jet fixture. The historical `scripts/invoke-acid-art-qc.ps1` helper checks native projection, fine aim increments and shutdown states; independent visible-outlet acceptance is recorded in `pressure-jet/DISPERSION-02-VALIDATION.md`. Its white state markers are helper-only; no runtime state API is invented.

`gallery/index.html` includes native-size and enlarged model renders and a four-facing ±48° animation. These model previews omit engine-supplied pipe covers and illustrate night lighting. The native acceptance screenshots show the actual covers and game shader.

Run `python "$acidRoot/review_native.py" --root $acidRoot` after native QC to preserve all 88 captures and build clean vanilla-cover contact sheets, a fine-rotation animation and a shutdown animation. The eight overlap captures compare the previous and corrected draw order with ordinary pipes immediately north and south of all four facings. See `VALIDATION.md` for acceptance evidence and known unrelated repository preflight findings.

The fixed chassis and tanks, native covers, base glow and head use the normal `object` render layer with secondary orders 1, 2, 3 and 4 respectively. This lets neighboring entities sort by their normal position instead of globally overpainting the tall tank artwork on a lower layer. The correction changes only prototype ordering; all model geometry, sprite pixels, scales and offsets are retained.
