# ANISETRON 17 asset dossier

The current shipping cathedral uses the approved reference17 Meshy geometry and
PBR materials, with 128 rendered headings, emission on the original crystals,
and a small force-colored owner crest. The shipping package contains all eleven PNGs
and the exact 128-direction anchor lookup. The promotion record is
[shipping-hashes.json](../../../../../output/meshy/anisetron/reference17/shipping-hashes.json). The reference16 pipeline remains
[historical provenance](../README.md#historical-reference-16).

## Original source and preservation

- Reference image: `C:/Users/Theorun/Documents/1righteousgod/ANISETRON 17.png`;
  SHA256 `b892560fb45538f3231624b3152a5967cab384f96daade0778f07a119a6e7d35`.
- Completed Meshy task: `01a109e4-32e3-76e7-b8b3-7188f94993a1`, 40 consumed
  credits. Recorded parameters: Meshy 7.1, standard model, 4K geometry, 8K texture,
  textured PBR, no remesh, no image enhancement, GLB output. This delivery uses
  the completed download and performs no further generation.
- Original model: [anisetron17-max-detail.glb](../../../../../output/meshy/anisetron/reference17/anisetron17-max-detail.glb);
  SHA256 `6e866e9d537e330fe2e20ddc89ccd071955562f0eca114db4dc2e4999a706bfc`.
  It has 546,599 source vertices and 1,031,452 triangles, embedded 8192-square
  albedo, and 4096-square PBR maps.
- Preparation retains every source triangle ID, triangle-corner coordinate and
  face-loop UV. The architecture PBR network and image identity are unchanged.
  Crystal materials add original-albedo emission at strength 0.65 and a glow AOV;
  owner coloring uses a separate neutral mask. No roof/crown mesh, aperture,
  altered keel, stretched architecture or beam extrusion was introduced.
- Original normal orientation survives flattening, uniform scale, yaw and role
  separation within Blender's packing precision: maximum angular difference
  0.208613 degrees, 99th-percentile component error 0.00005949. Geometry/UV checks
  are exact; normal encoding is not claimed bit-identical.

The recorded source request is [request-plan.json](../../../../../output/meshy/anisetron/reference17/request-plan.json).
Preparation and normal evidence are [anisetron17.json](../../../../../output/meshy/anisetron/reference17/prepared-v2/anisetron17.json)
and [normal-qc.json](../../../../../output/meshy/anisetron/reference17/prepared-v2/normal-qc.json).

## Framing and native wiring

One recorded 180-degree yaw makes the source facade face +Y. Render initial angle 0
gives native N rear, E, S facade, W in clockwise order. Uniform scale
4.939079761505127 fits a maximum projected width of 5.982356 tiles and height of
8 tiles over all 128 yaw views. The lowest original keel tip is Z=0. The body,
glow and mask stay unlifted; separate shadow-only copies rise 1.8 tiles. The engine
supplies body hover and bob.

The approved scene SHA256 is
`8f1e349716576d2049f090ed23e9d768db19d893db29fc1c63517ff7eb674651`;
prepared metadata SHA256 is
`51f21d9487f02cb30c2c69493b5cd290b71c1a9e4aa64c6d8c26c4cd35544c08`.
The full render used Blender 5.1.1/Cycles, 512-square frames, orthographic scale 20,
32 samples, preset-default lighting, no additional normalization, and the
`object,shadow,light-alpha-reduced,mask` passes. It took 28 minutes 19 seconds.

Each pass contains 128 real frames and packs into two 4096-square sheets, directions
0-63 and 64-127. Native wiring uses scale 1.25, `filenames`, `line_length=8`,
`lines_per_file=8`, `slice=8`, `direction_count=128`, `frame_count=1`, and
`apply_projection=false`. The eleven shipping PNGs comprise eight sheets, two
item 128/64/32 mipmap strips and one technology icon. The current LUT SHA256 is
`97114f5b5b169145c49464d345725ba18ff994814dc073671afc880414e151e6`.
All individual shipping PNG hashes are recorded in the promotion manifest.

The full render has 512 pass frames. Minimum transparent margins are body 82 px,
shadow 60 px, glow 82 px and owner mask 185 px. The owner crest is naturally occluded
in 36/128 headings; body, glow and shadow are nonempty throughout. All 512 packed
cells match their raw RGBA frames byte-for-byte; 640 named anchor rows are exact;
all eleven package PNG hashes match. See [full128-qc.json](../../../../../output/meshy/anisetron/reference17/prepared-v2/full128-qc.json),
[full128-run-qc.json](../../../../../output/meshy/anisetron/reference17/prepared-v2/full128-run-qc.json), and
[package-integrity-qc.json](../../../../../output/meshy/anisetron/reference17/prepared-v2/factorio-full128/package-integrity-qc.json).

## Original crystal and keel anchors

Five named anchors are projected through the same locked camera in all 128
directions. Their formula agrees with actual full-render rotation matrices within
0.00003052 px. The crown point is the exposed original apex; the facade point is
the color-weighted front crystal chamber; the keel points are original minimum-Z
vertices within left/center/right regions.

| Anchor | Prepared physical coordinate |
|---|---|
| Crown | `[0.023337072,-0.161754906,9.374269485]` |
| Facade | `[0.006949957,1.783496737,4.178755283]` |
| Left keel | `[-1.692291617,1.512129068,0.758608341]` |
| Center keel | `[-0.000953169,1.580579519,0]` |
| Right keel | `[1.696445704,1.513319016,0.762104988]` |

The exported Lua interfaces are `crown[index][2]`, `facade[index][2]` and
`keel_tips[tip][index][2]`; `muzzle` aliases the facade. Core beams attach to the
vehicle with these camera-derived offsets, inheriting native hover/bob.

[full128-twin-core-alignment.json](../../../../../output/meshy/anisetron/reference17/review-delivery/qc/full128-twin-core-alignment.json) certifies
624/624 isolated native samples: all 128 headings in day/night for both emitters,
eight-heading views, clockwise/counterclockwise turns, north wrapping and frozen
or static stops. Every runtime index matches the displayed raw body. Maximum
perpendicular white-core error is 1.804597 px for the crown and 1.240238 px for the
facade. Minimum body-registration correlation is 0.957524. Evidence hashes were
rechecked when the two emitter reports were combined.

The evaluator fits the luminous axis with PCA weighted by `min(R,G,B)^4`. The
Lance texture's deliberately asymmetric cyan/magenta shoulders have a different
area centroid, especially in the twice-wide crown. Those broad-halo distances are
retained as diagnostics. A separate bright-white threshold confirms every sample
also passes 2 px (crown maximum 1.808610 px, facade 0.629046 px). This proves perpendicular
axis alignment; taper and occlusion limit general longitudinal endpoint measurement.

## Movement decoration and native bob

The current runtime uses the stateless measured correction
`-.34 + .875*clamp(abs(source.speed)/.083,0,1)` for LuaRendering attachments.
Entity targets already inherit the base height of 1.8 tiles. Fixed world-position
motes account for native height separately. The exported LUT's
`render_attachment_lift=0.625` remains a historical cruise calibration value;
current runtime decoration reads the curve from `lib/anisetron-visual-config.lua`.

There is no exposed current native bob coordinate. `get_beam_source()` returns
the vehicle entity, not a rendered/bobbed source position. The curve improves
the observed approach-to-stop placement without adding state or helper probes.
The final shipping Standard captures register all 24 movement frames against actual
128-direction raw frames; every predicted/displayed index agrees. Inferred moving
tip placement error is at most 3.160 px, with vertical residual -3.158 to +3.053 px.
This remains an empirical one-route approximation, separate from the 2 px core-beam contract.
The last five stopped frames contain zero live strands. The visible filaments
use the narrow approved animation layer; rear roots can be hidden by architecture.
See [final17-standard-keel-diagnostic.json](../../../../../output/meshy/anisetron/reference17/review-delivery/final17-standard-keel-diagnostic.json).
The current runtime renews each admitted strand's time to live on every tick while
its attachment and root remain valid. The creation budget is unchanged. The final
`final17-*-art2` captures include this renewal correction and replace the first
visual review pass.
Teleport handling clears admitted strands, attachment ownership and cached pose
samples. The next motion sample follows normal native physics and does not retain
the old surface or direction. See
[anisetron-visuals.lua](../../../../../exotic-space-industries-remembrance/scripts/control/anisetron-visuals.lua).

## Continuous firing audio

The shipping `sounds/anisetron-lance-loop.ogg` derives from the existing
`singularity-lance-beam-2.ogg` and `singularity-lance-beam-3.ogg` samples. Their
repo attribution records "Pulsar.wav" by wcoltd, CC0, with the original
[source link](https://freesound.org/s/440783/). The source sample SHA256 values are
`9db0bc23e310fff1b50a4b3a898f5ccabb707151d2c83dd8243ef9191fd34dd8` and
`9195a45277f79a890b3cfc891bcc780dd46aed94f4a896c5f3f1c9bf657cef38`.

The deterministic 3.2-second, 44.1 kHz stereo loop uses 0.2-second grains from source
0.075-0.275 seconds with 0.1-second hops and 50% Hann circular overlap-add. It removes
original attack/tail retriggers, performs no offline pitch resampling, and
normalizes the PCM peak to 0.7. Vorbis encoding uses quality 7 and bitexact flags.
The OGG SHA256 is
`bffde3960e6cf25037054a0d3e1a0250901366afc2a4f7d9146972900fa9dc48`.

Two invisible native working-sound helpers follow the paid channels independently,
so changing beam sprite headings does not restart their loops. Crown playback is
speed 0.90/volume 0.32; facade speed 1.05/volume 0.18. Both use audible-distance
modifier 0.50, six-tick fade-in, twelve-tick fade-out, five concurrent sounds per
prototype, and no Doppler. Runtime owns their lifecycle alongside paid beams.
The action-free visual beam prototypes themselves have no duplicated working sound.

The durable audio generator is
[build_firing_loop.py](build_firing_loop.py).
[audio-dossier.json](../../../../../output/meshy/anisetron/reference17/audio/audio-dossier.json) records all source/output hashes
and a five-join decoded waveform proof. It proves offline waveform continuity,
not subjective in-engine listening or spatial mixing. The six-loop OGG preview is
[anisetron-firing-loop-six-loops.ogg](../../../../../output/meshy/anisetron/reference17/audio/anisetron-firing-loop-six-loops.ogg).

## Native reviews and simulated presentations

The final shipping visual runs are
`.factorio-qc/anisetron/final17-{lean,standard,maximal}-art2`; each passed 12/12
visual fixture checks and used the promoted art directly with the current strand
renewal correction. [engine-standard](../../../../../output/meshy/anisetron/reference17/review-delivery/engine-standard/)
contains 24-frame day/night ring and native movement/turn/coast/stop GIFs and
contact boards, including native-pixel movement detail crops. The four
[fidelity comparison boards](../../../../../output/meshy/anisetron/reference17/review-delivery/fidelity-comparison/) use matched native captures
for Lean, Standard and Maximal. Their manifest identifies each input run and
source image hash. Core beams and materials are shared; tier differences in
decoration density are subtle in these selected snapshots. These visual boards
do not substitute for the separate fidelity mechanics or timing checks.
The motion vehicle is unarmed in this visual fixture; these clips demonstrate
movement decoration. The ring vehicle demonstrates both firing channels.
A beam crossing the motion view can belong to another fixture vehicle.
[review-integrity.json](../../../../../output/meshy/anisetron/reference17/review-delivery/review-integrity.json) verifies 515 source hashes and
19 image/animation artifacts: six 24-frame, 4.8-second GIFs and the 128-frame,
6.4-second direction comparison WebP, plus their boards and poster.

[direction-resolution](../../../../../output/meshy/anisetron/reference17/review-delivery/direction-resolution/) compares 64/128-heading cadence at
normal scale 1.25/zoom 1 using the same completed 128 source frames. The 64 column
uses nearest even frames and the 128 column uses all frames. It is clearly labeled a
sprite simulation; it does not claim native motion, lighting, or performance.

The previously delivered [dusk teaser](../../../../../output/meshy/anisetron/reference17/anisetron17-dusk-teaser.webp) is also a
simulated sprite presentation. It has 128 headings, a 768-square canvas, a 6.4-second
loop and 819,822 bytes. Its durable generator is
[build_dusk_teaser.py](build_dusk_teaser.py);
[teaser manifest](../../../../../output/meshy/anisetron/reference17/anisetron17-dusk-teaser.json) records the composition and
source hashes, and the WebP SHA256 is
`ecbc9ea101fa93e6cc2126eaafd579b10ef09771c5fe13ea9228facc595325bc`.

## Asset replay

Run these commands at the repository root with Blender 5.1.1. They recreate
ignored prepared/render/package output from the completed local GLB; the source
request is recorded in [request.json](request.json). Repeating Meshy generation
is not required. The approved prepared scene and metadata hashes above identify
the exact inputs to the completed full render.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python .codex/esir/asset-generators/anisetron/reference17/prepare_reference17.py -- --input output/meshy/anisetron/reference17/anisetron17-max-detail.glb --output output/meshy/anisetron/reference17/prepared-v2/anisetron17.blend
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python .codex/esir/asset-generators/anisetron/reference17/render_reference17.py -- --preset-blend factorioRenderingPreset_v4.blend --input output/meshy/anisetron/reference17/prepared-v2/anisetron17.blend --asset-name anisetron17-full128 --output-dir output/meshy/anisetron/reference17/prepared-v2/full128 --no-normalize --frames 128 --directions 128 --animation-frames 1 --passes object,shadow,light-alpha-reduced,mask --resolution 512 --samples 32 --ortho-scale 20 --auto-ortho-max 32 --preflight-margin 0.04 --initial-angle 0 --lighting-profile preset-default --material-report
python -B .codex/esir/asset-generators/anisetron/reference17/qc_prepared17.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --output output/meshy/anisetron/reference17/prepared-v2/full128-qc.json
python -B .codex/esir/asset-generators/anisetron/reference17/package_reference17.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --output output/meshy/anisetron/reference17/prepared-v2/factorio-full128
python -B .codex/esir/asset-generators/anisetron/reference17/verify_package17.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --package output/meshy/anisetron/reference17/prepared-v2/factorio-full128
python -B .codex/esir/asset-generators/anisetron/reference17/review_prepared17.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --output output/meshy/anisetron/reference17/prepared-v2/full128-review
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python-exit-code 1 --python .codex/esir/asset-generators/anisetron/reference17/audit_normals.py -- --source output/meshy/anisetron/reference17/anisetron17-max-detail.glb --prepared output/meshy/anisetron/reference17/prepared-v2/anisetron17.blend --output output/meshy/anisetron/reference17/prepared-v2/normal-qc.json
```

The package replay stays in staging. Approval and promotion into the shipping
graphics and `lib/anisetron-graphics.lua` are recorded by
[shipping-hashes.json](../../../../../output/meshy/anisetron/reference17/shipping-hashes.json).

## Replay from completed captures

All commands run at the repository root and write only ignored review output.
They read the completed render/captures and do not invoke Meshy, Blender or a
new Factorio session. Copies of the evaluators and compositors remain beside the
reports in [review tools](../../../../../output/meshy/anisetron/reference17/review-delivery/tools/).
The durable generators in this folder are [build_engine_previews.py](build_engine_previews.py),
[build_fidelity_comparison.py](build_fidelity_comparison.py),
[build_direction_comparison.py](build_direction_comparison.py) and
[verify_review.py](verify_review.py); the native evaluators are
[measure_twin_emitters.py](measure_twin_emitters.py) and
[measure_keel_attachments.py](measure_keel_attachments.py).

```powershell
python -B .codex/esir/asset-generators/anisetron/reference17/build_engine_previews.py --art .factorio-qc/anisetron/final17-standard-art2/script-output/anisetron-art --output output/meshy/anisetron/reference17/review-delivery/engine-standard
python -B .codex/esir/asset-generators/anisetron/reference17/build_fidelity_comparison.py --tier lean=.factorio-qc/anisetron/final17-lean-art2/script-output/anisetron-art --tier standard=.factorio-qc/anisetron/final17-standard-art2/script-output/anisetron-art --tier maximal=.factorio-qc/anisetron/final17-maximal-art2/script-output/anisetron-art --output output/meshy/anisetron/reference17/review-delivery/fidelity-comparison
python -B .codex/esir/asset-generators/anisetron/reference17/build_direction_comparison.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --output output/meshy/anisetron/reference17/review-delivery/direction-resolution
python -B .codex/esir/asset-generators/anisetron/reference17/measure_keel_attachments.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --art .factorio-qc/anisetron/final17-standard-art2/script-output/anisetron-art --curve -.34 .875 .083 --output output/meshy/anisetron/reference17/review-delivery/final17-standard-keel-diagnostic.json
python -B .codex/esir/asset-generators/anisetron/reference17/measure_twin_emitters.py --bundle output/meshy/anisetron/reference17/prepared-v2/full128 --capture crown=.factorio-qc/anisetron/v2-full128-crown2/script-output/anisetron-art --capture facade=.factorio-qc/anisetron/v2-full128-facade/script-output/anisetron-art --output output/meshy/anisetron/reference17/review-delivery/qc/replayed-twin-core-alignment.json
python -B .codex/esir/asset-generators/anisetron/reference17/verify_review.py --root output/meshy/anisetron/reference17/review-delivery
```

## Eight original keel tips — attachment-only update

The additional side/rear roots come from source vertex IDs 526065, 20681, 527196,
274070 and 19123. The first three exported roots remain unchanged. No source
geometry, prepared materials, approved spritesheets or icons were regenerated.
The exporter reproduces all existing projected anchors within 0.000001640 tiles.

[export_keel_attachments.py](export_keel_attachments.py) projects all eight tips
for 128 headings and traces hull occlusion from each root toward the locked camera,
using a .08-tile self-hit tolerance. Each heading exposes three to five roots.
The export records source/scene/lookup hashes, original and prepared coordinates,
camera projection, root visibility and ray distances in
[attachments.json](../../../../../output/meshy/anisetron/reference17/eight-keel/attachments.json).

Replay **after the original package step**, which supplies the first three roots:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python .codex/esir/asset-generators/anisetron/reference17/export_keel_attachments.py -- --output output/meshy/anisetron/reference17/eight-keel
```

Review the generated lookup before copying it to
`exotic-space-industries-remembrance/lib/anisetron-graphics.lua`. This extension
does not render or promote images. Runtime capacity derives from the exported
eight-tip count; the root mask changes with heading while each strand retains a
finite 12-tick lifetime and per-tick attachment updates.

The engine review exposed a far-side filament crossing the wall during a turn.
Root visibility alone was insufficient. The export therefore adds 32 trail
directions for each root and heading, sampling up to 1.4 tiles in .1-tile steps
with .05-tile lateral clearance. Runtime hides a strand when its full extension
would cross the original hull. Neighboring bins are conservative; no replacement
root or shortened mesh is introduced. The corrected runtime uses the same
clockwise screen-plane angle for native animation and clearance lookup. The
original sheet-promotion manifest remains historical; `attachments.json` records
the current extended lookup hash.

Current native samples, exact replay results and evidence limits are recorded in
[the Lance inheritance verification](../../../../../scripts/qc/anisetron-inheritance/verification.md).
The final Lean/Standard/Maximal clips are under
`output/meshy/anisetron/reference17/eight-keel/review-{lean,standard,maximal}`.

## October 7 runtime attachment correction

The stability review corrected an earlier interpretation of script-animation
rotation and scale. The texture now has zero prototype shift and an explicitly
computed center half a scaled strand length beyond each tip. Trails fall
downward with an opposite-travel component; all eight headings, including north
and northeast rear roots, are visible in the reviewed native captures. Native
bob speed 1 bounds the body excursion to roughly 3-4 pixels; the old empirical
speed-lift curve is removed. The earlier replay commands and reports above are
historical and retain the settings used when captured.

ANISETRON beam prototypes retain the Lance source/impact artwork and aligned
additive glow, while omitting the separate ground ray and script source halo.
The original model, materials, eight body/shadow/glow/mask sheets, icons, and
exported attachment coordinates are unchanged. See
[stability verification](../../../../../scripts/qc/anisetron-stability/verification.md)
for the new captures, actual-pixel checks, remaining limits and replay commands.
