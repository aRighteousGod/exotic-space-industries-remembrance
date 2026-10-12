# Prototype 2 minigun: 256-direction render handoff to 6.1 Sol

Selected by the user on 2026-10-09: **prototype 2, the exposed cradle**.
This measured plan has now been executed through the mechanical rig, all-pose
bounds, native timing experiment, 52-frame pilot and final-settings benchmark.
The Factorio 2.0.77 native spin/firing parity gate failed, so the 4096-image
production batch and in-game integration remain held. Read
[the execution report](EXECUTION-REPORT.md) before continuing; the remaining
sections describe the original target and gates, not a claim that production
sheets exist.

## Start here

Read this document, `prototype-2-rig-spec.json`, and the generated
`output/meshy/minigun-prototypes/prototype-2/handoff-256/planning-report.json`.
The JSON is an asset-specific planning contract, not an orchestrator pipeline spec.
Run from the repository root:

```powershell
python .codex/esir/asset-generators/minigun-turret/plan_prototype2.py
```

This verifies the exact paid model, exhaustively assigns its triangles, checks the
foundation against the 3x3 selection footprint, writes the 16-chunk render schedule,
and generates `rig-partition.png`. It does not create or modify a Blender rig.

Implementation order is **native timing probe -> mechanical rig -> pilot ->
all-pose framing and budget -> chunked production -> staged Factorio export**.
Do not begin the full render until the preceding gates pass. The current task
authorizes a handoff; it does not promote new sprites into the running mod.

## Source and appearance contract

- Paid source: `output/meshy/minigun-prototypes/prototype-2/source/model.glb`.
- SHA256: `453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59`.
- 853,014 vertices; 1,575,210 triangles; 8192x8192 base color; 4096x4096
  normal and packed metallic/roughness maps. Preserve all source files.
- Keep the exposed cradle, weathered olive armor, dark steel barrels, restrained
  brass fittings and rear ammunition drum. Preserve UVs and texture detail.
- Use the existing Factorio preset, fixed camera, upper-left lighting and
  lower-right shadow. The completed lighting comparison selected `preset-default`.
- No new glow, force-color mask, recoloring, firing flash, recoil or elevation
  animation is needed for this pass. Existing native ammunition effects remain.
- Retain the existing 3x3 placement and collision boxes. The foundation measures
  2.554x2.8 tiles; the complete barrel/drum assembly is about 4.91 tiles long.
  Barrel overhang is deliberate. Do not fit the entire model inside 3x3.

Existing eight-view images and `sample-scene.blend` are review evidence: they turn
the whole model, including the foundation, and start at 225 degrees. They are not
the production rig, north-first ordering, or muzzle calibration.

## Mechanical ownership and measured split

Use three mesh collections with an explicit parent hierarchy:

```text
ASSET_ROOT                    identity after canonical fitting
  BASE_FIXED                  never inherits aiming yaw or rotor phase
  YAW_PIVOT                   Z-axis, centered at the bearing
    UPPER_FIXED_TO_YAW         cradle, receiver sleeve, motor, rear drum
    ROTOR_PIVOT               tilted bore axis; inherits YAW_PIVOT
      BARREL_ROTOR            exposed barrel cluster + forward collars
```

The rear drum does not spin. The large receiver sleeve and elevation trunnions
remain fixed relative to the cradle. The barrels and their forward retaining
collars rotate together; spinning only individual tubes would tear the assembly.
No pitch channel is needed for Factorio's flat targeting plane in this pass.

Measurements use **Blender source-world coordinates before fitting**:
`(glTF.x, -glTF.z, glTF.y)`. The muzzle faces approximately source -X.

| Parameter | Measured/candidate value |
| --- | --- |
| Ground | `Z = -0.48354101181030273` |
| Yaw center | `X = 0.0085, Y = 0.0050` |
| Base/upper seam | `Z = -0.2600` |
| Rotor root P0 | `(-0.2950, 0.0260, 0.2065)` |
| Muzzle reference P1 | `(-0.9440, 0.0275, 0.1997)` |
| Rotor axis toward muzzle | `normalize(P1-P0)` |
| Rotor centroid gate | `X < -0.3000`, radial distance to axis `< 0.1550` |
| Uniform fit scale | `2.582866219043651` |

For each original triangle centroid C, assign BASE when `C.z < -0.260`;
otherwise assign ROTOR when the X and radial gates both pass; otherwise UPPER.
For the radial gate, set `D=C-P0`, `A=normalize(P1-P0)` and measure
`length(D-dot(D,A)*A)`. An X-only cut incorrectly captures the front cradle/base.

| Assignment | Original triangles |
| --- | ---: |
| BASE | 239,525 |
| UPPER | 1,167,981 |
| ROTOR | 167,704 |
| Total, with no omitted or multiply assigned face | 1,575,210 |

The bearing waist circle fit gives center `(0.008455,0.004875)`, radius `0.400383`
and 95th-percentile radial residual `0.003109`. The bore axis is less certain:
approximately 0.003-0.006 source units. Treat it as a pilot candidate, not an
already proven wobble-free axis. The planner's orthographic ownership plot makes
the proposed split reviewable without falsely claiming a completed rig.

Preserve face-corner UV data, material indices and custom normals. The source has
65,545 coincident vertex duplicates; a diagnostic position-only remap finds a
closed manifold, but those duplicates must not be welded in production because
they carry texture seams. Avoid global normal recalculation and remeshing.

The centroid split is intentionally simple and exhaustive, but leaves cut edges:

- BASE: 415 boundary edges, one imperfect boundary network, spanning
  `Z=-0.268370..-0.252582`.
- ROTOR: 580 boundary edges forming eight loops, all at the root in
  `X=-0.308601..-0.294162`. There is no exposed forward cut.

Do not apply an indiscriminate fill-holes operation. Keep the whole-triangle
partition as the starting point; hide the base cut with a recessed dark circular
bearing liner covering at least `Z=-0.272..-0.248`. Fit its radius inside the
existing race after checking the rotating clearance. Hide the rotor root with
an internal shaft/socket liner spanning the complete root boundary envelope.
Use separate new liner material/geometry so original textured surfaces are not
duplicated or put into coplanar overlap. Both end cavities must remain concealed
at every yaw and phase; preserve the open muzzle bores. If the liner cannot hide
the stepped cut, make a documented BMesh plane cut that interpolates UVs and
preserves face normals, then recheck ownership/count changes explicitly.

Canonical fitting, applied once to all parts:

```text
X = scale * (sourceY - 0.0050)
Y = scale * -(sourceX - 0.0085)
Z = scale * (sourceZ + 0.48354101181030273)
```

This centers the yaw bearing, grounds the model and rotates source -X to Blender
+Y north. The bearing height becomes `0.577376528` tiles. The canonical bore root
is `(0.054240191,0.783899897,1.782283619)`; the muzzle reference is
`(0.058114490,2.460180074,1.764720129)`. These are geometric anchors, not ready-made
Factorio projectile offsets. The fixed base XY bounds are approximately
`[-1.38998,1.41002] x [-1.20309,1.35091]`, inside the unchanged selection box.

Set parent inverse/basis matrices deliberately so parenting does not apply this
fit twice. Rotate the rotor with an axis-angle/quaternion about the transformed
P0/A line, not object-origin Z or a bounding-box center. Save source-to-canonical
and per-part matrices, material names, counts and hidden-liner ownership in
`mechanical-split.json`. Record exact matrices at selected poses.

## Motion and occlusion decisions

Use **256 actual yaw poses x 16 barrel phases = 4096 color frames**. For zero-based
direction d and phase p:

```text
Blender frame f = 1 + 16*d + p
yaw(d) = -360*d/256 degrees
rotor(p) = +360*p/16 degrees about the forward bore axis
```

North is d=0; east/south/west are d=64/128/192. Direction 255 is followed by 0.
Phase 15 is followed by 0; do not export the duplicated 360-degree endpoint.
Positive rotor rotation follows the right-hand rule about root-to-muzzle.
The original mesh has **five principal open bores**, not proven sixfold symmetry.
Its geometry and textures are asymmetric. A full revolution is required; eight
45-degree samples would alias a five-barrel pattern. Sixteen 22.5-degree samples
are the conservative starting choice, provided native playback advances them in
order. A nominal 72-degree repeating sector is not valid for this source either.

**Mechanically separate, visually bake together.** Render BASE + UPPER + ROTOR in
one assembled Object beauty pass for each pose. BASE retains the same world
matrix across all 4096 frames and all placement facings. Only head and rotor move.
Using the same foundation orientation for all placement facings is deliberate;
this ammo turret has no directional pipe connector to preserve.

This avoids a rotor drawing through the exposed cradle, visible old barrel pixels
under an overlay, and missing yaw-dependent shadows of the gun on the base.
Do not wire a second `graphics_set.base_visualisation` underneath these baked
color images: that would duplicate the foundation. True separate base/rotor
shipping layers are a later optimization requiring depth/holdout and lighting
equivalence evidence, not the first implementation.

Ground shadow is a separate **whole-assembly** pass at p=0 for all 256 yaw poses,
repeated across the 16 attack phases. This is an explicit approximation: rotor
phase affects ground-shadow silhouette but is omitted from this smaller layer.
The color beauty still includes phase-specific self/contact shadows. Compare p=0,
4,8,12 ground shadows at side/diagonal views; if the difference is conspicuous at
normal zoom, budget and render all 16 shadow phases. Do not alpha-stack separate
base and head ground shadows, which can darken their overlap twice.

## Native Factorio animation: resolve before rendering

Installed engine and API verified: **2.0.77, build 84539**. Current source is
`exotic-space-industries-remembrance/prototypes/electricity-age/gatling-turret.lua`.
Retained final-data evidence is the October 7 terrain-evolution/final-release dump;
it matches the inspected gatling fields, but is not a fresh dump of today's tree.

Preserve collision +/-1.4, selection +/-1.5, rotation speed 0.01, preparing/folding
speed 0.0625, cooldown 0.25, range 32, minimum range 4, rotate penalty 14, ammo,
inventory, damage, research, sounds and existing combat payloads. Preserve
`shoot_in_prepare_state=false` and `can_retarget_while_starting_attack=true`.

The present `attacking_speed=20` is hidden by a one-frame sprite. API docs define
the attack animation duration through `1/attacking_speed`; generic leaf
`animation_speed` is usage-dependent. Do not assume changing one field is harmless
to fire opportunities. Probe native behavior with inexpensive numbered 16-phase,
256-direction images in an isolated fixture before rendering the model.

Probe baseline 20 and candidate speeds `1/16`, `1/32`, `1/8`, with leaf
`animation_speed=1` and all weapon data unchanged. Start with 1/16; select the
fastest candidate that shows consecutive visible phases without aliasing and
preserves the baseline's first-shot tick, shot count, ammo consumption, retarget
behavior and prepare/fold durations. Capture each tick for at least two loops,
then a sustained-fire interval of at least 600 ticks, at cardinal and diagonal
targets. Supply enough ammunition and power and use a surviving stationary target;
cooldown 0.25 can demand roughly 2400 shots over 600 firing ticks. Record per-tick
and cumulative shot curves, not only the final total. Explicitly cover target loss,
stop/resume and retarget transitions, interrupting at several phases including
the 15->0 wrap. Test both Ballistic Divergence enabled and disabled, comparing
baseline versus candidate within each setting. Use an instrumented isolated
save; keep timing instrumentation out of
production control.lua. Do not claim a 16-tick deployment duration from the speed
constant alone; measure the existing and proposed transition durations.

Determine whether attacking animation loops while firing or restarts per attack,
and whether repeated one-frame shadow leaves follow the same logical duration.
If no candidate preserves gameplay, stop this gate and report the measured state
coupling before committing to expensive animation. Never alter cooldown/DPS to
make a sprite loop look right. The handoff intentionally leaves the selected
speed null until this experiment establishes it.

State contract:

| State | Visual |
| --- | --- |
| Folded / prepared / rotate-for-folding | Phase-zero assembled pose, 256 directions |
| Preparing / folding | Same pose, logical eight-frame repeated sequence; retain state speeds |
| Attacking | 16-phase loop, same housing position and bearing |
| Starting / ending attack | Retain existing absence initially; no new firing delay |

No new deployment or spin-up delay is planned. Rotor stop/idle phase is neutral
phase zero. Arbitrary phase carry-over between native states is not promised by
the documented API; inspect firing-to-idle transitions for a visible snap. Do not
solve it with a production on_tick rendering scheduler. Normal alignment and
gameplay parity take priority over an unproven spin-down effect.

## Resolution, framing and budget

Preserve the high-detail source. Render masters at **64 pixels per world tile**,
then export the default at **32 pixels per tile, scale=1** with correct alpha-aware
downsampling. Also stage the pilot at 64 pixels per tile, scale=0.5, for a fair
in-game comparison. Full 64-density shipping requires its own memory acceptance.

Use the preset with a starting orthographic scale 8.4375 and 540x540 master canvas.
These satisfy `resolution / ortho_scale = 64`. Auto-fit globally over all yaw and
spin poses. If a larger view is required, increase canvas and ortho together:
`resolution=ceil(required_ortho*64/2)*2`, `ortho=resolution/64`. Leave the camera,
light orientation and object scale fixed. Never let auto-fit silently shrink the
machine in Factorio. The review settings 1024/8.4 were about 121.9 pixels per tile,
not the metadata tile-size value of 128.

Determine one common color crop and one common shadow crop over all poses, with
at least four transparent shipping pixels of padding. Do not crop each frame
independently. Keep the ground bearing's projected pixel anchor and derive shifts
from it. For crop `(left,top,width,height)` and ground anchor `(gx,gy)` measured in
the same exported pixels:

```text
shift_x_tiles = (width/2  - (gx-left)) * sprite_scale/32
shift_y_tiles = (height/2 - (gy-top))  * sprite_scale/32
```

Positive image Y is down. Compute color and shadow shifts independently; their
ground anchors must coincide in a composite. Verify with a tile-grid overlay.
Run geometry preflight over all 4096 poses, then check actual alpha bounds during
rendering, including soft shadows. Reject any clipped frame and update global
framing before continuing. Do not force illustrative crop sizes onto the art.

Illustrative sizes from existing sample coverage, **not final measurements**:

| Layer | Example cell | Frames | RGBA8 canvas estimate |
| --- | --- | ---: | ---: |
| Attack color | 176x152 | 4096 | 418 MiB |
| Prepared color | 176x152 | 256 | 26.125 MiB |
| Phase-zero shadow | 192x128 | 256 | 24 MiB |
| Total at 32 px/tile | | | 468.125 MiB |
| Same at 64 px/tile | doubled dimensions | | 1872.5 MiB |

Target <=512 MiB RGBA8 across referenced default art. This is a budget target,
not measured Factorio VRAM; atlas allocation, mip levels and engine handling must
be measured in the graphics-load pilot. PNG file size is not GPU memory. If actual
crops exceed the budget, report the numbers before the full batch. Keep 256 yaw
directions; do not silently reduce direction count, clip, or rescale the footprint.
The first optimization to investigate is safe static-pixel/depth decomposition,
with assembled-reference comparison, rather than sacrificing barrel occlusion.

Use 64 samples for the rig pilot and 256 final samples with the selected preset
profile. Benchmark actual final settings on the rig. Prior 1024px/256-sample whole
model review renders averaged about 26 seconds per warm frame on the GTX 1070;
4096 at that old setting would take about 29.6 hours. This is only an extrapolation.
The proposed 540px masters are cheaper, but there is no measured production ETA.

## Atlas and renderer implementation

Attack layout: **16 stripes**, each with 16 phase columns x 16 direction rows.
Stripe k contains directions `16*k..16*k+15`. Cell `(column=p,row=r)` corresponds
to direction `16*k+r`, phase p. Use `frame_count=16`, `direction_count=256`,
`line_length=16`, and each stripe's `width_in_frames=16,height_in_frames=16`.
At the illustrative crop this is 2816x2432 per stripe. Policy: keep both default
shipping image dimensions <=4096. Protected 64-density masters may use <=8192:
the same illustrative layout is 5632x4864. A height violation can be solved by
splitting direction rows into additional stripes. A width violation requires
fewer phase columns and a newly verified row/index layout in the engine; simply
splitting direction rows cannot solve it. Do not clip cells to satisfy a limit.

Prepared color and phase-zero shadow each use a 16x16 yaw grid, `frame_count=1`,
`direction_count=256,line_length=16`. Prepared frames are exact extractions of
attack phase zero, not fresh renders. During attack the shadow leaf uses
`repeat_count=16`. Preparing/folding use eight repeated phase-zero references.
Every leaf gets its own scale, shift, projection, direction count and timing:
properties on a `layers` container do not apply to its children.

For the assembled strategy, a staged Lua builder needs only these shapes:

```text
idle = layers { prepared-color(frame_count=1), yaw-shadow(frame_count=1) }
attack = layers { attack-color(frame_count=16, stripes),
                  yaw-shadow(frame_count=1, repeat_count=16, draw_as_shadow=true) }
transition = idle leaves with frame_sequence={1,1,1,1,1,1,1,1}, forward/backward
all leaves: direction_count=256, apply_projection=true, counterclockwise=false
graphics_set: do not add another base image; the color atlas contains it
```

Do not paste this as Lua. Generate actual snippets from measured paths/crops/
shifts and the successful timing probe. Use `RotatedAnimation8Way` correctly,
reusing the same assembled atlas for placement facings. Retain source gameplay
definitions in the isolated candidate. Confirm N/E/S/W and placement rotation in
the engine before trusting frame order or projection.

Create a new `prepare_prototype2.py` and `render_prototype2.py`; leave the original
review generator reproducible. Reuse existing shared-renderer/preset helpers and
the water/acidthrower split patterns, with these corrections:

- Production indexing is `d=(frame-1)//16`, `p=(frame-1)%16`; the review wrapper's
  one-phase yaw assertion is wrong for this animation.
- Fixed base must bypass `Rotation by Frames & Directions`. Parent only the upper;
  rotor follows upper yaw plus its local axis. Assert matrices before render.
- Blender 5.1 output nodes use `directory` and `file_name`; retain the existing fix.
- Reconcile imported material warnings against GLB `alphaMode=OPAQUE`. Base color
  uses color management; PBR/normal maps stay Non-Color with tangent-normal wiring.
- Pack PNGs using Pillow `paste(frame,(x,y))` **without a mask**. The shared Blender
  packer's extra color conversion previously changed both RGB and alpha.
- Validate exact RGBA equality for every cell. Do not apply opacity reductions to
  shipping shadows because the review gallery used 35% shadow opacity.
- Disable unused compositor outputs. Render full ground-shadow output only for
  phase zero unless the shadow gate selects all phases.

## Pilot, checkpoints and reproducible delivery

The rig pilot contains a full 16-phase loop at d=32 (diagonal), plus phase-zero
views at d=0,64,96,128,160,192,224. Retain ground shadows for all phases at d=32
and add shadow-only p=4,8,12 at d=64 and d=192, so the shadow gate has both diagonal
and side-view evidence. Add an isolated rotor inspection from the muzzle and
side. Include phase 15->0 and a slow yaw turntable, with the base visibly fixed.
Inspect cradle occlusion, drum/receiver stability, socket gaps, open bores, normal
continuity, side-facing shadows and native 32/64-density readability. Full frame
0..15 color differences must be real rotor motion, not only lighting noise.

Automated geometry invariants: BASE world matrix identical for every pose; UPPER
matrix identical across phases of one yaw; rotor axis endpoints invariant across
phases; distances to the rotor axis preserved; all original faces assigned once;
no second scale/translation on parenting. Recheck selected source hash before any
cut and preserve source SHA in every derived manifest.

After approval of the technical gates, render sequentially in 16-direction chunks
(256 beauty images). Persist `render-job-plan.json`, command arguments, source/
spec/rig/camera/material hashes, device, samples, bounds and elapsed time. A resume
skips a frame only when the complete configuration hash and decoded PNG checks
match. Keep per-frame completion records and atomic completed-stripe writes.
One changed rig/camera/material parameter invalidates the old frame cache.

Protect paid source, final review, rig, master sheets, manifests and QA. Register
only new disposable intermediate runs through ESIR housekeeping, with retained
paths outside those runs. Before each chunk, require predicted remaining retained
storage plus one scratch chunk plus 5 GiB free headroom. Keep heavy Blender and
Factorio jobs serial on this workstation. Retire exact raw intermediates only
after retained master sheets and byte-exact packing/QA succeed; never enroll the
whole minigun dossier or source model in automatic cleanup.

Required staged deliverables under `prototype-2/handoff-256/`:

- `prepared/minigun-prototype-2.blend`, source-preserving mesh partitions,
  `mechanical-split.json`, pose invariant report.
- `timing-probe/` numbered atlas, fixture/reproduction commands, shot-count and
  first-shot parity, tick captures, selected timing record.
- `pilot/index.html`, spin and yaw previews, 32/64-density comparison, bounds,
  shadow approximation review and measured runtime/memory estimate.
- `masters/` 64-density sheets; `draft-factorio/` default color/shadow sheets,
  generated Lua snippet, manifest and exact packing QA.
- `muzzle-anchors.json`, regenerated 256-sample creation-map proposal, directional
  overlay review and Ballistic Divergence on/off checks.
- `qa-summary.json` that distinguishes successful checks from skipped/blocked ones.

## Muzzle mapping and eventual integration

The existing 256-element projectile map describes the old 64-direction art. It
cannot be reused just because the new atlas has 256 yaw directions. Start from
the new bore/muzzle reference, project its center at every yaw through the actual
camera, apply crop/scale/shift once, and use the existing native projected-heading
mapping as the calibration precedent. A shared central muzzle origin is deliberate:
the native creation-position map is orientation-based, not rotor-phase-based.
Do not invent per-barrel shot synchronization or move gameplay origins each tick.

Keep projectile height/flash compensation separate from camera projection. The
old function compensates a one-tile rendering height; re-verify it for the actual
effects rather than baking the old '+32' into raw geometry anchors. Review all
256 overlay points, then test native shots/flashes at eight cardinal/diagonal
headings and enough intermediate headings to expose indexing drift, with both
Ballistic Divergence settings. Target <=2 native pixels at ordinary zoom; any
larger mismatch must be explained and corrected before promotion.

Production integration is a later explicit task. Candidate destination remains
the existing graphics-3 `graphics/entities/gatling-turret/` family unless that task
changes ownership. Preserve the dirty worktree's current muzzle correction and
all unrelated edits. Leave the item/technology icon and sounds alone in this pass.
When replacement is actually authorized, search consumers, preserve unique
uncommitted originals in protected staging, and retire only proven-superseded
`gatling-sheet.png`/`gatling-place.png` files after the new family is wired.

Run focused `qc-assets`, a graphics-enabled load, native animation/firing checks
and a fresh 2.0.77 final-data comparison for the candidate. Assert gameplay fields
unchanged except a demonstrated-safe presentation speed. Do not label a headless
load as visual validation, or planned render time as a measured performance gain.
This plan does not introduce a runtime system or modify the combat blueprint;
future substantive cross-file behavior changes must reconcile the relevant
conceptual model in the same patch.

## Evidence and reference map

- Current source: `prototypes/electricity-age/gatling-turret.lua` in the main pack.
- Current conceptual boundary: `.codex/esir/blueprints/combat-doctrines.md`.
- Retained baseline: `.factorio-qc/terrain-evolution/final-release/script-output/data-raw-dump.json`
  (Oct 7, 2.0.77; use a fresh candidate dump at integration).
- Existing muzzle QC: `.factorio-qc/minigun-offsets/muzzle-comparison.png` and
  `verification.json`; do not mutate those historical fixture results.
- Previous model review: `output/meshy/minigun-prototypes/review/index.html`.
- Split precedent: `.codex/esir/asset-generators/water-turret/prepare_model.py`.
- Preset wrapper: `.codex/skills/meshy-blender-spritesheet/scripts/render_factorio_preset.py`.
- Installed API authority: `C:/Program Files (x86)/Steam/steamapps/common/Factorio/doc-html/prototype-api.json`.

Canonical official references (the installed 2.0.77 JSON was read; hosted versioned
pages were unavailable through the web tool during this planning session):

- [RotatedAnimation](https://lua-api.factorio.com/2.0.77/types/RotatedAnimation.html):
  direction count is uint32; projection/order/stripes and per-leaf fields.
- [AnimationParameters](https://lua-api.factorio.com/2.0.77/types/AnimationParameters.html):
  repetition and animation speed; 8192px input-width limit in line_length docs.
- [AnimationFrameSequence](https://lua-api.factorio.com/2.0.77/types/AnimationFrameSequence.html):
  255 maximum logical temporal length; not a 255-direction limit.
- [TurretPrototype](https://lua-api.factorio.com/2.0.77/prototypes/TurretPrototype.html):
  native state speeds and animation fields.
- [BaseAttackParameters](https://lua-api.factorio.com/2.0.77/types/BaseAttackParameters.html):
  cooldown below one tick is supported; keep fire-rate semantics unchanged.
- [TurretGraphicsSet](https://lua-api.factorio.com/2.0.77/types/TurretGraphicsSet.html):
  separate stationary art would use base_visualisation, if a future decomposition
  is proven. No extra base layer is used by the assembled plan.

## Copyable assignment to 6.1 Sol

> Implement the staged prototype-2 minigun render pipeline from
> `.codex/esir/asset-generators/minigun-turret/HANDOFF-256-PROTOTYPE-2.md` and its
> measured JSON spec. The user selected the exposed cradle. Preserve the paid
> source and existing 3x3 gameplay footprint. Build fixed-base, yaw-upper and
> bore-axis rotor parts, preserve materials/UVs, and follow the native timing and
> rig pilot gates before the 256x16 render. Bake assembled color for correct
> occlusion; use the documented shadow approximation only if it passes review.
> Produce the staged sprite sheets, rig, previews, measured manifests, Lua draft,
> and new muzzle proposal. Do not add a runtime animation controller, change
> combat balance, spend Meshy credits, or promote into shipping folders as part
> of staging. Treat null timing/crop values as explicit measurement tasks, not
> permission to guess. Report evidence and remaining blockers accurately.
