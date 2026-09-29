# Sweeping radar models and retained spritesheet masters

Approved selection: **#1 / E1 Split-Trough Watcher** for `ei-sweeping-radar`, and **#8 / S4 Fourfold Interrogator** for `ei-phased-array-radar`. The earlier #3 generation is preserved as superseded. Entity names and gameplay remain unchanged.

## Current deliverable

Maximum-detail Meshy originals, UV-preserving animated Blender models, 256-facing final-quality master renders and staged spritesheets. The chosen export is **256 facings**; 128 and 64 are exact repacks retained for comparison. The shipping prototypes still use placeholder radar art. Live runtime-render lifecycle integration is separate from this asset export.

## Final renders and repacking

The user selected 256 facings and explicitly requested retention of the renders. Preserve all original numbered PNGs under each asset's `master-256/Render/`, including `Object`, `Shadow`, and the Phased-Array's `Light A` pass. The manifest records every file hash, source/model hashes, render settings, frame angles, and camera anchor. Do not delete these when replacing spritesheets or cleaning temporary work. Each frame is checkpointed; matching completed frames are verified and skipped on resume.

```powershell
# Render missing master headings; never reduces or replaces retained masters.
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/sweeping-radar/invoke-spritesheets.ps1 -Stage Render

# Pack and verify the selected 256-facing spritesheets.
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/sweeping-radar/invoke-spritesheets.ps1 -Stage Pack -Facings 256
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/sweeping-radar/invoke-spritesheets.ps1 -Stage Check -Facings 256

# Repack lower counts directly from the same masters, without Blender or Meshy.
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/sweeping-radar/invoke-spritesheets.ps1 -Stage Pack -Facings 128
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/sweeping-radar/invoke-spritesheets.ps1 -Stage Check -Facings 128
```

Use `-Facings 64` the same way. Exact evenly spaced subsets must divide 256: 256, 128, 64, 32, 16, 8, 4, 2 or 1. More than 256 unique directions, or an exactly uniform count that does not divide 256, needs additional renders. Each variant has its own directory under `factorio-export/<count>/`; packing a lower count leaves the 256 set and master frames untouched.

Master rendering uses the original 384×384 canvas, 256 Cycles samples, denoising, fixed preset lighting, eight CPU threads, and no motion blur. `-StartFrame` and `-EndFrame` can limit a resumed range. The 256 poses cover `[0°,360°)` with no duplicate closing image. Source model yaw is `-90° - heading_index*360/256`; this is an art reference, not an in-game north calibration. Keep the original 0.5 sprite scale and 3×3 physical footprint.

The final images retain their original **16-bit RGBA** PNG channels. The shared exporter decodes them to **RGBA8** for shipping, then packs losslessly. Verification compares every exported alpha value and every visible RGB value against this RGBA8 decode; it does not claim lossless 16-to-8-bit conversion. The high-precision originals remain available for other export decisions.

Crop unions use all 256 headings, with at least 12 pixels of padding rounded outward to 8-pixel boundaries. Body and glow share a crop; shadow has its own. Crops never resize or recenter individual frames. Shifts are calculated from the saved projected world origin, preserving body/shadow/glow alignment. Every count uses the same crop derived from the full master.

Each page contains at most 128 row-major frames, eight columns, and at most 16 rows. The 256 set has two pages per pass. The generated `.animation-segments.lua` returns body/shadow layers and optional independent additive glow for each <=128-frame segment. It intentionally does not use a 256-entry `frame_sequence` or infer `RotatedAnimation` semantics from the Blender direction count. The exact global-to-source frame map is in `spritesheet-manifest.json`.

`test_packing.py` checks isolated 256/128/64 repacks, partial alpha, page ordering, unchanged master hashes and corruption detection. `spritesheets.py check` performs the equivalent checks on every real exported frame and binds its result to the current sheet manifest hash. After packing and checking all three counts for both assets, run `python -B .codex/esir/asset-generators/sweeping-radar/finish_spritesheets.py` to build the self-contained manifest-driven preview and verified master ZIP. The finalizer rechecks current page hashes, verifies every archive entry against its source hash, and only then replaces the previous archive. `review_spritesheets.py` produces the full-rotation and page-boundary contact sheets from the packed images.

Open `output/meshy/radar-production/spritesheets-review.html` for the finished comparison gallery. It embeds its manifests and works directly as a local file. It has a 256/128/64 selector, forward/reverse playback, speed control, phase slider, and #8 glow toggle. Measured sizes are recorded in `spritesheet-completion.json`; raw RGBA memory and compressed PNG file size are separate figures.

The additional `radar-master-renders-256.zip` is a verified source archive, **not a shipped-mod asset**. Extract it into `output/meshy/` to restore the default `<asset>/master-256/Render/` paths. Raw renders and that archive remain local under ignored `output/`. Exact copies of both selected source GLBs and prepared animated Blender models are versioned under [`models/`](../../../../models/radar-models.md) using four narrowly scoped Git LFS paths; the model manifest records hashes and self-contained rotation checks. The original working copies remain in `output/`. Durable generators and provenance are repo-owned. Only the selected packed graphics belong in a later shipping integration.

Open `output/meshy/radar-production/index.html` locally for the heading slider and playback controls. Each asset also has an animated `prepared/<asset>.blend`; its continuous 360-degree rotor cycle runs over frames 1–64, closing at frame 65. The preview uses eight discrete headings.

## Replay

Run from the repository root with Blender 5.1 installed at the path in the wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/sweeping-radar/invoke-model-review.ps1 -Asset both -Stage All
python -B .codex/esir/asset-generators/sweeping-radar/check_review.py
```

`-Stage Prepare`, `Render`, or `Check` reruns only that step. Original GLBs must already exist at the paths below; replay does not spend credits or contact Meshy. The shared `factorioRenderingPreset_v4.blend` and `.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py` are required. This older model-review wrapper uses CPU by default (`-ComputeDevice cuda` is optional), 16 samples, transparent 384×384 frames and separate preset passes. The final model verification switched to CPU after a GPU job made no output progress. This is the eight-heading review render; use `invoke-spritesheets.ps1` above for the retained 256-facing masters.

| Asset | Original source | SHA-256 | Original triangles |
| --- | --- | --- | ---: |
| Sweeping Radar | `output/meshy/sweeping-radar/source/attempt-01.glb` | `7bcf55b384b853e7c760dbe8e3c7e39ee62095ce19c8f9daeb0106dcff1cf366` | 2,820,202 |
| Phased-Array Radar | `output/meshy/phased-array-radar/source/attempt-01.glb` | `8239316631930f34d462d8a0e3d561ff7e78c32ebd71925c8945a16a09a2fd99` | 2,961,706 |

Source task metadata and downloaded PBR textures are beside the GLBs. Both contain 8192-pixel base color and 4096-pixel PBR maps. Generation requested Meshy 7.1 standard, 4K geometry, 8K texture, PBR, no remesh. Three 40-credit tasks cost 120 credits total: two selected assets and the already-started superseded #3. Approved prompts, references and task IDs are under `.codex/esir/art-prompts/sweeping-radar/`.

## Mechanical contract

`prepare_radar.py` verifies the source hash, partitions original triangles without remeshing, preserves UVs, grounds the model and adds a bearing seam. The original sources remain untouched.

- **#1:** trough, receiver spine, cradle and upper turntable move together; transformer, insulators, drive housing, lower plinth and feet stay fixed. Source-space separation is at Z=-0.10, with a 0.010 rotor lift.
- **#8:** four panels, support arms and upper hub move together; lower hub, base cables and foundation stay fixed. The fixed region is `Z < -0.32 OR (radius < 0.43 AND Z < -0.005)`, with a 0.045 rotor lift.
- Both rotate around the vertical center. The largest rotor radius is normalized to 1.4 tiles. One prepared world unit represents one tile at the intended 64 pixels/world-unit render and Factorio sprite scale 0.5. The generic preset's canvas-based footprint estimate is not the model's physical footprint.
- #8's panel emission combines an outer-panel region attribute with bright neutral albedo, retaining the dark tile divisions. The red lamp is a separate rotor object/material on the exposed lower face of the upper hub. Emission uses the preset `Lights` group and a separate `Light A` pass. That pass has black non-emitting pixels and should be composited additively; it is not a normal opaque body overlay.
- `render_radar.py` appends the saved rig, evaluates its controller before detaching meshes, lets the shared preset turn the rotor, and restores fixed object transforms. Updating the dependency graph before copying transforms is essential to preserve the red lamp's small scale.

`check_rig.py` checks fixed transforms, changing rotor transforms, loop closure, retained triangle counts, UV presence and the recorded swept radius. It does not prove collision-free geometry at every intermediate angle. Review all rendered headings for the seam and attachment behavior.

The preset convenience sheets apply a further color transform and do not preserve raw-frame pixels. `pack_review.py` therefore delegates to ESIR's shared raw-frame exporter and writes `review/raw-packed/`. `check_review.py` requires every packed frame to preserve visible RGB and every alpha value exactly, and checks alpha margins, emission presence and gallery links. The shared packer zeros otherwise invisible RGB where alpha is zero; this is the only permitted pixel difference. The gallery itself always reads raw frames.

## Factorio 2.0.77 feasibility evidence

The isolated fixture in `output/meshy/radar-production/orientation-qc/` tested a void-powered disabled radar with zero native scan radii, zero rotation speed and wireless coupling disabled. Writing `LuaEntity.orientation` to 0, .25, .5 and .75 left its orientation at zero. Do not build production rotation around that setter.

The second fixture used an invisible shell and `rendering.draw_animation` with `animation_speed=0`. Selected offsets 0, 16, 32 and 48 stayed selected after five ticks, while the radar remained disabled. Engine screenshots show different headings. Results are preserved with this generator as `feasibility/native-orientation-result.json` and `feasibility/rendered-orientation-result.json`.

Production integration should therefore select pre-rendered frames through the existing bounded radar service, updating only changed headings and power visibility. The chosen motion policy is to trail completed work. Keep native scans disabled. Live interpolation, segment transitions, north calibration, lifecycle teardown/repair, pause/reversal/fixed-bearing behavior, save/reload, powered glow behavior, and whole-engine overhead checks remain integration work. The earlier fixture proves frozen-frame rendering, not those production behaviors.

## Known review limits

The older eight-angle gallery is a geometry and material review. The 256-facing production set adds per-frame packing validation, full-rotation composite contact sheets, page-boundary comparisons, and glow-on/off images. These do not replace in-game zoom review or a benchmark. The current CUA session had no browser available, so interactive playback was not exercised; artifact/link and script checks are recorded separately. Preset `Composite` frames are unused; inspect `Object`, `Shadow`, and `Light A` directly. Shared preset startup emits a transient driver division-by-zero before the render configuration replaces its zero defaults; verify the successful render manifest and outputs rather than treating that message alone as a failed render.
