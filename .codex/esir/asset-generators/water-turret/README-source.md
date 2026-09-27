# Water turret art source and replay

The user selected concept 9, PIPEWORK BASTION, revision 2, then palette 4: the
last shown lighter blue/teal version. Latest user correction supersedes the
earlier fixed-backpack plan: the backpack and exposed pipe rotate with the
head and circular platform. The pipe still terminates in that platform rather
than directly in the upper head housing.

Mechanical split: the circular turntable, entire head/nozzle, backpack and its
supply pipe rotate together about the bearing axis. Only the structure below
that platform, the ground plinth and external grid couplings remain fixed.
Use an actual separate mesh boundary at the bearing seam; do not rotate just
the nozzle or leave part of the upper turntable behind. Inspect a full sweep
for backpack clearance, gaps, duplicated surfaces and floating pieces.

Selected source: `output/meshy/water-turret/colors/04-patina-teal.png`.
SHA-256: `de83c6266570a714d83bf0c11f0f786b8d2f51cd7af93bb69f5f0effe715a647`.
Six independently generated color PNGs, their exact prompts and the selected
palette record are retained in that folder. All are RGBA, 1254 by 1254.
They were made with built-in image_gen; Meshy image generation was not used.

## Completed model request

`output/meshy/water-turret/meshy-request.json` contains the concrete MCP payload.
The user explicitly approved 40 credits per attempt for Meshy 7.1 with 4k
geometry, 8k textures and PBR, including regeneration when inspection finds a
defective result. The final request disables remeshing and exports GLB only.
Preserve each attempt and its actual consumed credits in the dossier.

Attempt 1 succeeded: task `01a0dbbe-601e-7336-8d16-33d112e20d1a`, 40 credits.
The source GLB is 79,464,904 bytes, 386,779 vertices / 711,780 faces, with an
8192-square base-color map and embedded 4096-square auxiliary PBR maps.
Its SHA-256 is `f9b54cc4a846b840491bed74b77aff1fc8f99534685aca114c26b439e8819c7a`.
The service's 8K texture option does not make every auxiliary PBR map 8K.
The request's original fixed-backpack wording predates the user's final
rotation correction; the deterministic Blender split implements that correction.

The global MCP was updated permanently to `0.5.2-esir.20260925.1` at
`C:/Users/Theorun/.codex/tools/meshy-mcp-server-esir` and is selected by the
existing global launcher. A fresh connection advertises the new schemas. The
original conversation tool list can remain stale; use a reconnected/fresh MCP
client for generation. Preserve the resulting task ID, paid request, task JSON,
consumed credits and downloaded GLB under `output/meshy/water-turret/source/`.

The earlier T2/15000 proposal was superseded by the approved highest-detail
7.1 request. Auto Split is not in this pipeline because it discards textures.

## Blender and rendering

1. Inspect the downloaded mesh and materials. Separate the stationary lower
   base from the rotating platform, backpack, pipe, head and nozzle. Native Meshy
   parts do not establish the correct mechanical joint automatically.
2. Normalize the complete model once: ground origin, centered bearing yaw axis,
   candidate 2x2 or 3x3 footprint (user allows either based on final pipe/art
   alignment). Preserve shared coordinates in base/head exports. Record the
   nozzle muzzle in those coordinates for stream alignment.
3. Preserve the light blue/teal armor as baked color. Keep a small neutral owner
   trim material separate for the runtime force-color mask. Never tint the
   entire turret or merge the mask into its base texture.
4. Export aligned `prepared-3x3/base.glb` and `prepared-3x3/head.glb`; keep the source
   GLB intact. Use the installed Blender 5.1 and local Factorio preset.
5. `base.pipeline.json` and `head.pipeline.json` record final render parameters: four
   base placement directions and 64 head directions, independent shadow and mask
   passes, 64 pixels per tile. Both skip independent normalization.
   Use `invoke-art.ps1` for replay because the asset-specific `render_model.py`
   wrapper routes owner trim into the preset's Colored collection. Running the
   generic pipeline plan directly would omit that routing.
6. Evaluate the union of the fixed base, every head direction and shadows.
   Resolve one common ortho scale/canvas/shift for both roles. Draft automatic
   framing must not become independently scaled shipping layers. The preset
   resolution must track ortho scale times tile size.
   External fluid collars must match the prototype's pipe-connection coordinates
   in all four placement directions. Derive them from engine-backed grid tests;
   keep the backpack's internal supply pipe separate from the external ports.
7. Inspect pose alignment, pipe clearance, footprint, alpha margins, mask
   neutrality and readability before final sampling/export. Produce the item
   and technology icons from the approved assembled model.
8. Replace temporary gun-turret graphics and the water icon in
   `prototypes/electricity-age/water-turret.lua`, align stream muzzle settings,
   run `qc-assets` plus the isolated water-turret engine fixture, and close the
   unfinished-art note. Gameplay integration is already user-authorized.

## Selected geometry and replay

The selected footprint is 3x3. Its fixed plinth is approximately 2.8 tiles wide;
the nozzle/backpack overhang above it. Both 2x2 and 3x3 prepared models remain
available. The 3x3 choice permits centered west/east ports at prototype offsets
`{-1,0}` and `{1,0}`; adjacent ordinary pipe centers are at `{-2,0}` and `{2,0}`.
Use native `assembler2pipepictures()` plus `pipecoverspictures()`, with their
original shifts, to keep external connectors independent of the rendered head.

Source coordinates: pivot `(0.055,-0.012)`, ground `z=-0.5461480021`.
Separate the fixed body at `z=-0.255` and rotating body at `z=-0.235`; the narrow
transition is rebuilt as a fixed dark bearing race and a rotating machined rim
and platform. The original textures/UVs outside this joint remain intact.
Prepared north is +Y; all sprites use initial angle 0 and clockwise order.
The common body/shadow/mask canvas is 576x576, ortho scale 9, 64px per Blender
unit, Factorio sprite scale 0.5 and shift `{0,0}`. No independent role fitting.
Final renders use the original preset's lighting and Cycles, 64 samples, CUDA.
Ship the exporter-packed raw frames, not Blender's `.Sheets`: pixel comparisons
found a second color transform in Blender's sheet writer. `--pack-raw-frames`
preserves the reviewed frame colors. The technology icon uses the exporter's
256-square preview; the item uses the 224x128 strip containing 128/64/32 mips.

The neutral backpack identification strip is a separate mesh. The preset's
Color Mask layer keeps Normal as a holdout for proper occlusion; Colored is
indirect-only in body/shadow passes. The icon render keeps the neutral strip.

The measured nozzle reach is 2.5962124 and projected pivot height 1.3620957621
Factorio tiles. Native launch-event probes show that aiming includes the pivot
height before applying the 45-degree projection. The scripted fire stream uses
that same formula; it does not clamp the tip inward for close targets.

Run from the repository root after retaining the original source GLB:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/water-turret/invoke-art.ps1 -Stage All
```

Gameplay validation before final art: all 41 player/runtime cases passed on
Factorio 2.0.77. Legacy migration, normal reload and forced configuration reload
also passed. The tests include native zero-damage slowing, priorities, fluid
use, power/circuit gates, helper lifecycle, surface cleanup, GUI handlers and
blueprints. These do not replace visual in-game sprite inspection.
After the footprint change, all 59 non-player runtime cases passed, including
25 grid/rotation assertions. The muzzle probe additionally calibrates explicit
stream origins and native launch effects across eight aiming directions.
