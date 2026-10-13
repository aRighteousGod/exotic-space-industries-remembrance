> Current packages: main 1.3.43 + Graphics 6 1.0.1; optional `minigun-turret-HD` 1.0.0.
> Default artwork is now indexed HD64 with all unchanged HD shadows; `sd` is a
> legacy profile-slot name. See [the derivative contract](INDEXED-HD.md).
> The HD pack supplies standalone content without main, with base/Space Age progression.
> Standalone full bullet damage is retained; cooldown 1 / 0.9 produces 54 shots versus the original's 60 per second in the native steady test. The original .25 cooldown is capped at one shot per tick.
> The public reuse API is `lib/graphics.lua`; historical render/firing evidence is retained.
> Current scoped delivery and verification are recorded in `output/minigun-implementation/STATUS.md`.
> Native casing ejection has its own [receiver calibration contract](CASING-EJECTION.md).
> Casings use a private four-second vanilla particle; the launch map and rotor
> atlases remain the approved production data. Changing launch registration also
> requires recalibrating the receiver outlet.

# Minigun prototype 2: separated native graphics handoff

Status: original rendering and integration completed. The indexed-HD derivative
is implemented and validated separately; the rendering gates below are historical
source requirements, not a pending render queue or an indexed-pixel certificate.
Resume first from [the current operational status](../../../../output/minigun-implementation/STATUS.md)
and its [live render snapshot](../../../../output/minigun-implementation/render-status.json).
The full production render is retained; use the operational status for current
work. Do not restart rendering. [The 2026-10-11 progress record](PROGRESS-2026-10-11.md)
preserves the completed pilot evidence. Reuse its verified passes and existing
icons; do not restart the eight-direction pilot.
The old rig, pilot and timing reports remain historical evidence; their earlier
16-phase attack experiment
does not establish acceptance of this replacement.

## Source and mechanical ownership

Use `output/meshy/minigun-prototypes/prototype-2/source/model.glb` only.
SHA256: `453a8f5b75fd16630803d698293222cf9e07a3e1cecb1f7c3b40434d75008f59`.
Meshy task: `01a123b7-0507-7520-84dd-5fcce51bb408`, Meshy 7.1 reconstruction of
the selected prototype image 2. The source has 853,014 indexed vertices and
1,575,210 triangles. Preserve source UVs, material assignments and corner normals.
Five main bores and irregular smaller details prohibit assumed sixfold symmetry.

- Base: world-fixed pedestal, with no aiming rotation.
- Upper: receiver, cradle, rear drum and stationary receiver collars yaw together.
- Rotor: barrel cluster and its forward collars spin about the bore, under yaw.
- Hidden seam liners belong to their mechanical parent. Preserve the inspected
  rig's caps/clearance repairs; do not replace them with a broad forward-X cut
  that captures the cradle or rear drum.

Measured Blender source coordinates use `(glTF.x, -glTF.z, glTF.y)`:

| Parameter | Source value |
| --- | --- |
| Bounds minimum / maximum | `(-0.951002,-0.593895,-0.483541)` / `(0.951251,0.583375,0.492561)` |
| Bearing XY / base seam Z | `(0.0085,0.0050)` / `-0.260` |
| Bore root / muzzle | `(-0.295,0.026,0.2065)` / `(-0.944,0.0275,0.1997)` |
| Axis toward muzzle | `(-0.9999424434,0.0023111150,-0.0104770549)` |
| Ground / uniform scale | `-0.48354101181030273` / `2.582866219043651` |
| Canonical forward | Source `-X` becomes `+Y` by a `-90 degree` Z rotation |
| Original face partition | Base `239525`, upper `1167981`, rotor `167704` |

The partition totals all 1,575,210 original faces once. These measured values are
rig inputs, not proof of seam clearance or firing alignment. Retain the current
rig's preservation and clearance reports as evidence. Keep the existing 3x3
selection and 2.8x2.8 collision footprint. Add no pitch, recoil, deployment,
force-color mask, glow layer or runtime animation scheduler.

## Directions and the 28 physical rotor poses

Use exactly 256 aiming directions. For direction index `d=0..255`, yaw is
`-360*d/256` degrees; canonical north is `+Y`. Use this convention in rendering,
sheet packing, native graphics and model-derived muzzle projections.

| Physical pose index | Meaning |
| --- | --- |
| `1` | P: sharp parked, zero phase |
| `2` | R: running, centered 90-degree angular blur, zero phase modulo 360 |
| `3..12` | Spin-up interior centers `1..10` |
| `13..28` | Spin-down interior centers `1..16` |

Logical spin-up has 12 frames: `{1,3,4,5,6,7,8,9,10,11,12,2}`.
Logical spin-down has 18 frames:
`{2,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,1}`.
Reuse P and R bytes for the logical endpoints, for both color and shadow.
Do not independently rerender endpoint lookalikes.

Each logical frame integrates a shutter centered on its time `t`, with support
`[t-0.5,t+0.5]`. Evaluate angular motion through that shutter; do not substitute a
fixed blur span for the interior acceleration and deceleration frames. Angles
below are degrees. Spin-up centers are `t=0..11`; spin-down centers are `t=0..17`.

```text
F(u) = u^4/4 + 3*u^5/5 - u^6/2
up(t) = 0                              when t <= 0.5
        900*F((t-0.5)/10)               when 0.5 < t < 10.5
        315 + 90*(t-10.5)               when t >= 10.5

G(u) = u - 23*u^3/16 + 43*u^4/32 - 9*u^5/16 + u^6/8
down(t) = 90*t                         when t <= 0.5
          45 + 1440*G((t-0.5)/16)       when 0.5 < t < 16.5
          720                          when t >= 16.5
```

The spin-up endpoint is a full turn at center time 11 with the R shutter;
spin-down reaches two full turns and the P shutter at center time 17. A physical
pose can be shared by logical states only through the declared map. The running
appearance must not depend on changing shot cadence or adding a runtime loop.

One pass contains `1 + 256 + 28*256 = 7425` separated color images before packing,
and the corresponding 7425 shadow images. Render a 64-pixel-per-tile master with
the established Factorio orthographic camera and lighting. Derive approved
32-pixel-per-tile color/shadow exports from that accepted master. Downsampling is
an approved resolution conversion; subsequent PNG optimization must be lossless.

## Layers, icons and native integration

Maintain independent base, upper and rotor color families. The selected shadow
representation is one complete all-caster ground mask per direction and physical
pose in each density. Base/upper shadow renders remain source evidence; failed
separated residual masks are not shipping layers. Recompose the color layers
against assembled reference renders to check depth, seams and occlusion. Compute
a stable crop and shift for every semantic family across all directions and
poses; no phase-specific crop wobble. Preserve the same world size and shifts:
SD32 uses sprite scale 1, HD64 uses scale 0.5. Every state has its real shadow;
running and transition shadows use the matching angular integration.

The size candidate stores the rotor correction as four vertical spatial strips.
These are additional native color leaves of the same mechanical rotor, each
retaining all 256 directions and all 28 poses; they do not add a moving part or
change source-over blending. Child leaves retain exact source pixels and receive
their own crop-derived shift. Their ordered composition must match the combined
reference at pixel centers and after native filtering. Source-array agreement
alone cannot prove seams between strips. Keep every atlas within 4096 pixels.

Item and research art use a front three-quarter view, slightly aside toward the
camera so the barrels remain visible, with the sharp parked rotor. Export both
default and HD icons; record the actual icon dimensions in generated metadata.
The turret item, entity and research icon consumers change together. The turret
recipe inherits its main product icon. The separate `ei-minigun` handheld weapon,
recipe and research are outside this change.

The data-stage ownership is:

- `prototypes/electricity-age/gatling-turret.lua`: turret/item/technology gameplay
  definitions and application of the graphics module.
- `prototypes/electricity-age/gatling-turret/graphics.lua`: native animation
  construction, profile selection, common shifts and muzzle mapping.
- `prototypes/electricity-age/gatling-turret/graphics-data.lua`: generated atlas
  dimensions, physical/logical pose maps, crops and declared asset-family paths.

These paths are beneath the main ESIR mod root. Native Factorio owns aiming and
animation state. Preserve attack payload, cadence, ammo/energy consumption,
rotation, ranges, collision and selection behavior. New muzzle projections must
come from the accepted model and camera. The old 64-entry muzzle array is not a
valid substitute for the new 256-direction render.

Connector placement is user-owned and deferred from this implementation. It is
not a native acceptance blocker; preserve existing connector behavior here.

## Packages and profile selection

| Package | Candidate version and role |
| --- | --- |
| `exotic-space-industries-remembrance` | `1.3.41`; owns gameplay and metadata; requires Graphics 6 `>= 1.0.0`; new HD pack is first in its optional dependency list |
| `exotic-space-industries-remembrance-graphics-6` | `1.0.0`; complete SD32 colors, all shadows, item and research icons; requires base `>= 2.0.0` |
| `minigun-turret-HD` | `1.0.0`; optional HD64 colors/icons and complete eligible HD shadows; requires base `>= 2.0.77`, optional Space Age; standalone gameplay when main is absent |

Use `graphics/entities/gatling-turret/`,
`graphics/items/gatling-turret.png` and `graphics/techs/gatling-turret.png` beneath
the relevant graphics pack. The HD pack registers no prototypes, settings or
runtime scripts. Its README invites reuse under GPL-3.0-or-later, and its
`examples/` directory contains an explicitly unloaded standalone turret example
and generated HD metadata. It has no root data.lua that imports the example.
Main reads `mods["minigun-turret-HD"]`; its first optional entry is
`? minigun-turret-HD >= 1.0.0`. HD has no dependency back to main,
avoiding a cycle and allowing other mods to consume the graphics independently.
Do not invent a `graphics_only` info field.

Absent or disabled HD selects the complete SD family in required Graphics 6.
Every rotor child's ordered `filenames` array stays within that pack.
Each atlas holds contiguous whole direction groups and
all 28 physical poses. Read its direction capacity and file count from generated
metadata; do not assume 32 files or eight directions per file. A four-strip SD
child may, for example, hold sixteen directions per file.
No direction or state is omitted or duplicated. Enabled HD selects
all HD colors/icons. The current candidate includes the complete combined HD
shadow family; the preliminary size projection fits. Do not select a partial
base/upper/rotor fallback from the failed residual masks. Any later fallback
requires its own native and budget evidence and must preserve a complete shadow
representation across every state and direction. A complete SD fallback, if
selected, points directly at Graphics 6; copy no SD assets into the HD archive.
Freeze the chosen major-1 layout and shadow-tier contract in main metadata after
the size gate. Reject an unsupported HD major with a clear error, never silently
mix an unknown profile with current metadata.

Retain the old Graphics 3 minigun files unchanged: older ESIR releases still
consume them. Preserve unrelated files and prior incomplete output directories.
Register the HD source root in the existing package topology; any wrapper change
must be scoped to supporting this asset pack, not new deployment automation.

Each final whole archive, Graphics 6 and HD, must individually be strictly less
than `256000000` bytes. `240000000` bytes is a warning threshold only; it does not
justify removing an approved shadow family. Graphics 4 and 5 receive no new
minigun files and keep their existing version 1.0.0. Their earlier split and
candidate version bumps were superseded by the user's Graphics 6 decision.
The fresh budget report is
`output/minigun-implementation/graphics6-next/projection-g6-hd-with-reuse-docs/pilot-budget.json`.
It measures actual scaffold ZIPs and projects the existing four-strip pilot:

| Package | Projected new PNG bytes | Scaffold + 15% allowance on new PNG payload |
| --- | ---: | ---: |
| Graphics 6, complete SD | 64,095,928 | 73,724,174 |
| HD, including all complete combined HD shadows | 216,682,416 | 249,205,795 |

Both preliminary gates pass the strict cap. HD exceeds the early-warning
threshold only in the allowance case; this does not justify dropping shadows.
These are measured scaffold ZIPs plus eight-direction payload projections,
not actual complete replacement ZIPs. The baselines include the reuse README
and example source (HD baseline ZIP21,016bytes). Final generated example metadata
and new ZIP entry overhead must also be counted in the final archive. The final archive
builder must preserve unrelated content, measure each complete ZIP, and record
integrity and byte totals separately. If any individual archive exceeds the cap
after approved lossless optimization, stop and report
the constraint without reducing the approved directions, poses or visible color.

## Required gates and evidence

The four-strip pilot passed the uncompressed camera-v3 native color smoke gate:
128 comparisons plus the blank control, zero maximum/RMS RGB error, and 64
fraction groups with distinct captures. Coverage is SD/HD, directions
0/32/96/128, physical poses 0/1/7/20, native offsets 0/0.5 and zoom 1/1.5.
Evidence:
`output/meshy/minigun-prototypes/prototype-2/handoff-256/native-color-fixture/smoke-none-fold0-20261011-000137-2403df/summary.json`.
Its exact metadata SHA256 is
`129a7df70e0d9564e9018ebdf630bcffac44c5247b1029bee0c597597de9ee98`.
The full pilot matrix now passes all 7,168 comparisons plus its blank control,
with zero maximum/RMS RGB error. Camera-v3 requests all four fractions at every
zoom; exact translated native pixels prove that Factorio rounds some camera
phases to the same screen pixels. Every aliased group must retain that proof,
nonzero movement, actual camera coordinates and complete case coverage.
Evidence: `native-color-fixture/full-none-camera-phase-analysis-20261011/summary.json`
beneath the same retained handoff root. The original overly strict uniqueness
failure remains unchanged. This is eight-direction pilot evidence, not final256
production acceptance. The emitter independently rejects missing/stationary or
wrong-case alias evidence and any color error above one code value.

Default HQ GPU compression failed with maximum RGB error40. A per-sprite
`not-compressed` experiment passed all128 pairs with zero error. Explicitly
adding `linear-magnification` failed with maximum error80; the measured native
default atlas has no filtering flags. Preserve native default sampling.
The old cross-mode backdrop changed blue110 to108 through DXT, so the new
fixture holds its background uncompressed and audits every actual color leaf.
The clean HQ rerun passed all 128 pairs plus the blank control with zero RGB
error, and audited all 1,736 actual color leaves. Every one of its 258 screenshots
is also decoded-RGBA identical to the original global-none/default-sampling
smoke. Evidence is `native-color-fixture/smoke-high-quality-fold0-20261011-160801-8e8f56/`
and `output/minigun-implementation/native-color-compression-comparison.json`.
This verifies the selected sampling/compression policy on the smoke matrix;
complete pose/zoom coverage and final 256-direction acceptance remain required.
Automatic cropping stays enabled.

The corrected camera-v3 separated-shadow smoke run failed all density tiers:
equal-density HD reached 31 RGB codes and SD reached 22. Evidence is retained at
`output/meshy/minigun-prototypes/prototype-2/handoff-256/native-shadow-fixture/smoke-all-none-fold0-20261011-000129-17e8d7/summary.json`.
Do not promote these residual masks. The selected budget candidate is the
complete all-caster shadow family for SD and HD, avoiding decomposition and
mixed-density filtering. The complete-mask smoke passed128 SD/HD comparisons
plus three controls in `native-shadow-fixture/smoke-combined-none-fold0-20261011-151501-c67cc0/summary.json`.
Full pose/zoom coverage and final256 metadata remain separate gates.

The final color gate accepts complete 256-direction metadata and tests global
directions 0/7/8/15/16/32/64/96/127/128/160/192/224/255, all 28 physical poses,
four native fractional offsets and four zooms in both densities. It uses the
actual final files and metadata hash; pilot evidence cannot satisfy it. Offline
decoded reconstruction still covers all 7,168 logical color cells per density.
The final firing acceptance matrix independently covers every direction.

The first Factorio 2.0.77 uncompressed color smoke run recorded zero maximum
and RMS RGB error for 128 cases plus the blank-background control. It covered
SD/HD, four directions, four physical poses and two zooms, but native turret
placement snapped the two requested fractional positions to the same position.
Those duplicated cases do not establish fractional filtering acceptance. The
original result is preserved as center-position evidence:
`output/meshy/minigun-prototypes/prototype-2/handoff-256/native-color-fixture/smoke-none-fold0-20261010-232857-0eb59e/summary.json`.
This result is bound to compiled metadata SHA256
`57d62c635e30cfc94151641d317fd3e90f4e648aa9b9ae15985d2c20fefbdcb6`.
Full native acceptance requires `entity-relative-camera-v3`: actual entity
positions, camera-relative offsets in engine-native pixels (32 per tile),
distinct fractional captures or exact pixel-proven screen-grid aliases, and
uniform unclipped borders. Its full matrix
uses 0/0.25/0.5/0.75 native pixels for both SD and HD, with source offsets twice
as large for HD and screen offsets multiplied by zoom. Historical v2 tests use
source-pixel fractions: a requested 0.5 represents 0.5 native pixels in SD but
0.25 in HD. Retain that limited coverage without claiming the full HD period.
The original shadow run also sampled the control's
edge and clipped its frame; its retained failure is not rewritten. True shadow
pair differences of 13-31 RGB codes remain unresolved by that instrumentation
finding. Final256 color, compressed-texture policy, full shadow coverage,
remaining native behavior and actual complete package sizes remain pending. Earlier staged
comparison payloads without the corrected geometry must not run.

The installed color fixture supports `-Profile sd|hd|all` and
`-ReferenceSelection auto|full|cells`. Final256 defaults to exact original atlas
filename/x/y reference-cell selectors, with one-direction/one-frame leaves and
recorded decoded-cell hashes. Actual candidate leaves keep their complete
256-direction layout; references are neither repacked nor made into an irregular
14-direction animation. Run SD and HD serially to limit simultaneous texture
allocation. Each full profile has 6,272 comparisons and one control; the installed
strict aggregate reopens both retained components and requires identical input
and validator hashes and the complete 12,544-comparison union plus two controls.
This tooling is installed and checked offline; final native acceptance is pending.

The installed final shadow fixture uses the same 14 canaries and exact reference
selectors, with only `combined_sd` and `combined_hd` eligible for final256. Before
capture it checks all 7,168 source cells per density against the retained renderer
journal, compiled source hashes and actual atlas pixels, requiring exact combined
alpha reconstruction. Each serial full profile has 6,272 comparisons plus three
alpha controls; the aggregate requires 12,544 comparisons plus six controls.
Observed global HQ and the actual native shadow atlas policy qualify through
`final_policy_qualified`; the older `native_eligible` field remains full/global-none
only. No lossless-color or sampling flag is added to shadows. The emitter requires
the exact retained final HQ aggregate for the selected combined-shadow route.
Installed implementation and offline tests do not satisfy either native gate.

Retained full-mod logs report 21,860.82 MiB of texture allocation under global
`none`, and 8,469.55 MiB under global HQ, against a 7,299 MiB local budget. These are
engine allocation figures, not resident VRAM. Keep global HQ with independently
verified `not-compressed` color flags; do not add mipmaps or change sampling.
Measure final loading behavior. A lightweight hash-bound composition fixture can
remove unrelated mod graphics if necessary, with separate full-mod integration
and native firing acceptance still required.

The native firing fixture now disables target-grid snapping so its requested
angles are actually exercised. Explosion orientation readback remains zero
for rotated images and is not an alignment authority. Native constructor
controls with twice-projected target rays resolve the earlier approximately
20-degree diagonal template mismatch. Paired native-height/zero-height images
measure a constant64-screen-pixel displacement at zoom2 for height1.
The retained unsnapped piercing pilot is
`firing-fixture/sd-on-pilot-calibration-heading-templates-20261011-155135-97e4f3`.
First-flash and next-frame fitted positions are stable within0.707 native pixels
of the proposed anchor across all8 views, but background-dependent flash
compositing still weakens several correlation scores. The new leading-cap
projectile fitter measures full-native t0 within1.118 native pixels; its exact
inputs, angular alternatives and annotated pre-shot/native/control panels are
retained. A paired-background native-control refinement now recovers flash
opacity/foreground before fitting the actual shot. It reproduces all 32 visible
flash attachments within 0.707 native pixels, while 16 held-out control cells
recover their independent registrations exactly. Source hashes, native cell
registrations and measured height translations are checked. The helper and
reproduction command are documented in `firing-fixture/README.md`; the latest
diagnostic is `output/minigun-implementation/firing-composited-flash-measurements-v2/`.
The diagnostics remain unapproved measurements. A separate image-bound manual
review now accepts all eight SD/BD-on piercing pilot views, including native
appearance/decay and first projectile. Its retained report is
`firing-fixture/pilot-visual-calibration-accepted-20261011/summary.json`.
It sets `pilot_calibration_gate_passed=true`, while final alignment and production
approval remain false. Maximum reviewed flash error is0.707nativepixels and
first-projectile error1.118. The d000late residual is a particle below an exactly
unchanged muzzle region. All256directions, allfour profile/doctrine combinations,
other ammo routes and moving shots remain final promotion gates. Do not require
a new four-configuration pilot as an extra prerequisite to continuing production rendering.

The installed firing fixture adds compact nine-cell heading controls using the
actual observed flash variation, fixed paired backgrounds and an independent
held-out native-height cell for each of three ray hypotheses. Native compact
smoke is still required; these controls do not inherit acceptance from the larger
historical template atlases. Candidate PNG manifests bind the complete referenced
SD/HD image union by path, dimensions, bytes and hash. Same-tick moving shots share
one actual screenshot per variant while retaining every shot/effect observation.
Default same-volume hardlink retention preserves all evidence paths and bytes;
it does not thin capture coverage or manufacture visual approval. See
[the firing fixture](firing-fixture/README.md) for commands and strict review scope.

`apply_lossless_optimization.py` is installed. Apply complete independently
verified lossless reports into a fresh compiled sibling before native capture;
freeze that metadata hash and preserve the raw compile/reference provenance.
`finalize_graphics_data.py` is also installed and documented in
[FINALIZATION.md](FINALIZATION.md). It requires the unchanged tested lookup,
four-configuration firing matrix and bound lifecycle/visual reviews, then emits
staged calibrated metadata and the exact tested launch contract. It does not
promote assets or turn a pilot into full acceptance. Native lifecycle, icons,
real consumers, standalone HD reuse and final whole archives remain separate gates.

The required acceptance scope remains:

1. Verify source hash, all-face ownership, UV/corner-normal preservation, hidden
   seam repairs, rotor clearances and separated-layer recomposition.
2. Run the focused Factorio 2.0.77 native timing gate before production promotion:
   verify spin-up/down progression and endpoints, unchanged sustained shot/ammo/
   energy behavior, retargeting, idle/start/stop, ammo/power loss and save/load.
3. Gate firing alignment with actual native flashes and projectiles at cardinal,
   diagonal and fine intermediate aim angles, with Ballistic Divergence both on
   and off. Compare model-derived muzzle projection and visible barrel exits.
   A mismatch blocks production/promotion; static render alignment alone cannot
   pass this gate.
4. Check all 256 directions and 28 poses, matching shadows, stable crops, blur
   integration, P/R byte reuse and equal SD/HD world size. Check item/recipe/
   research icons in the native UI and confirm the handheld weapon is unchanged.
5. Run isolated HD-absent, HD-disabled and HD-enabled final-data checks; normalize
   graphics fields and require gameplay parity. Validate every declared path and
   the explicit major-version failure behavior.
6. Refresh manifests only after the owners and files exist. Run focused static
   asset/blueprint checks, wrapper package dry-run, actual archive byte and ZIP
   integrity checks. Record compression settings and whole archive totals.

Do not claim the old timing test passed this new contract. Record each pending
or failed gate plainly. No publication, live deployment or remote delivery is
implied by this handoff or candidate version metadata.
