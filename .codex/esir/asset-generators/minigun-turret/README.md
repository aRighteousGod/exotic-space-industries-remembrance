# Minigun prototype 2 asset dossier

## Selected production candidate

The user selected **prototype 2, the exposed cradle**, on 2026-10-09.
The current implementation contract is [the separated native graphics handoff](HANDOFF-SEPARATED.md):
256 aiming directions, 28 physical rotor poses, 12-frame native spin-up,
18-frame spin-down, and the selected 90-degree running exposure. Graphics 6
owns the indexed HD64 default family and all lossless HD shadows. The optional
`minigun-turret-HD` retains full-color HD artwork. The current derivative workflow
is [INDEXED-HD.md](INDEXED-HD.md); original render/firing evidence remains immutable.
Connector placement is user-owned.

Main lists the HD pack first among optional dependencies. Without main, HD adds
a standalone turret with base-game or Space Age progression. It also offers
GPL-3.0-or-later reuse documentation and an unloaded example turret.

Resume first from [the current operational status](../../../../output/minigun-implementation/STATUS.md)
and [live render snapshot](../../../../output/minigun-implementation/render-status.json).
The full render is complete; use the operational status instead of restarting it.
[The 2026-10-11 progress record](PROGRESS-2026-10-11.md) preserves the earlier evidence.
The production-quality eight-direction/28-pose pilot, icons, native layout/timing,
full pilot color reconstruction and image-reviewed firing calibration are complete.
Reuse those results. Serial-profile color/shadow reference selectors and strict
aggregates, compact firing controls and immutable capture retention, lossless
optimization application, and [finalization](FINALIZATION.md) are installed.
The original full-direction native color/shadow/firing evidence is retained.
The indexed derivative uses its own focused visual/native/archive checks.
Failed residual shadows stay historical; both current profiles use complete HD masks.

The installed [firing fixture](firing-fixture/README.md) now rechecks declared
projectile routes, moving-shot image approvals and retained heading measurements.
The [consumer fixture](consumer-fixture/README.md) binds separate approved combat
baselines for both doctrines and observes actual finalized main/example artwork.
`audit_shipping.py` verifies installed destinations and, after final exact ZIP
measurement, every archive entry against the installed pack. Follow the command
order in [FINALIZATION.md](FINALIZATION.md); these installed checks do not imply
that the pending final native evidence or shipping integration has passed.

The retained [earlier 256-direction handoff](HANDOFF-256-PROTOTYPE-2.md),
[`prototype-2-rig-spec.json`](prototype-2-rig-spec.json), and
[`plan_prototype2.py`](plan_prototype2.py) describe the historical fixed-base,
yawing upper and independent bore-axis rotor, with 256 directions and 16 spin
phases. The rig, original UV/normal verification, all-pose bounds, 52-frame pilot
and native timing experiment are complete. The native spin/firing parity gate
failed in Factorio 2.0.77. That result applies to the historical16-phase route,
not the replacement28-pose preparing/folding implementation. See
[the execution report](EXECUTION-REPORT.md) for measured results, commands and
the route decision. The original comparison
workflow below remains reproducible for both prototypes.

## Motion blur and activation follow-up

The 2026-10-10 [rotor exposure inspection](MOTION-BLUR-INSPECTION.md) adds sharp,
36-degree, 90-degree and 180-degree physical Cycles exposures. Eight sharp and
90-degree views, plus diagonal lighter/heavier alternatives, have matching
shadows, 32/64-density previews and a comparison slider. Open
`output/meshy/minigun-prototypes/prototype-2/handoff-256/motion-blur/index.html`.

The updated activation proposal uses native preparing/folding states: initial
12-tick spin-up, conditional user-approved ceiling of 45 ticks / 0.75 seconds,
and initial 18-tick spin-down. Prepared and attacking share the running appearance
to avoid between-shot flicker. Primary and secondary speeds must both be set.
The new 28-pose native layout and steady-fire timing fixture has passed in both
doctrine states. Those results do not establish final art/firing alignment or
shipping integration; the old independent continuous-spin experiment remains
failed historical evidence.

## Discord teaser

`invoke-teaser.ps1` renders a presentation-only 960-pixel eased 360-degree yaw
turn, then the d096 front three-quarter spin-up, running barrel blur and spin-down.
It reuses the approved rig/exposure functions through proof-only initialization,
keeps the foundation fixed, and checks every rendered pass for clipping and
axis stability. `build_teaser.py` chooses lossless WebP if it fits; otherwise it
selects the highest integer quality that stays strictly below 10,000,000 bytes.
The retained report records actual duration, decoded frames, render provenance,
size and SHA256. Presentation timing is independent of native gameplay timing.
The teaser is outside shipping graphics and does not approve production sprites.

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-motion-blur.ps1
```

Requested 2026-10-09: generate both Development minigun prototype images at maximum
Meshy detail, then render samples for comparison. Shipping sprites are unchanged.

## Sources and generation

- `C:/Users/Theorun/Documents/Development/minigun proto image 1.png`
- `C:/Users/Theorun/Documents/Development/minigun proto image 2.png`
- Protected staging: `output/meshy/minigun-prototypes/`.
- Meshy 7.1, standard model, Ultra 4K geometry, 8K base-color, PBR enabled,
  `should_remesh=false`, `image_enhancement=false`, GLB, alpha/cardinal thumbnails.
- Prototype 1 task: `01a123b6-e548-74fd-a16c-5c4dd8e20d8a`.
- Prototype 2 task: `01a123b7-0507-7520-84dd-5fcce51bb408`.
- Price verified against official API pricing: 40 credits each, 80 total.
- Original images, paid downloads, task JSON and sample renders are retained evidence.

## Renderer

`render_samples.py` wraps the existing Factorio preset renderer. It preserves
downloaded geometry, UVs and textures, applies one uniform foundation fit, handles
Blender 5.1 output paths, and checks framing across every requested pose.

The bottom 15% of model height provides the draft foundation bounds. The longest
foundation side is fitted to 2.8 tiles inside the existing 3x3 selection footprint.
Inspect recorded geometry and rendered views before treating this fit as final.
Whole assemblies rotate for these sample views: these are not production turret
sprites, mechanical separation, calibrated muzzles, barrel spin or force masks.

Run background Blender from the repository root using the checked-in
`factorioRenderingPreset_v4.blend`; exact invocations are retained in staging.
Final sample layout: eight views, separate object/shadow passes, transparent
1024px frames, 256 Cycles samples, common orthographic scale 8.4. The standard
Factorio lighting profile was selected after baseline/rail-fill/gamma previews;
it preserves the original metallic/roughness maps and albedo without material lift.

Reproduce from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-samples.ps1 -Prototype 1 -Phase final
powershell -ExecutionPolicy Bypass -File .codex/esir/asset-generators/minigun-turret/invoke-samples.ps1 -Prototype 2 -Phase final
python .codex/esir/asset-generators/minigun-turret/build_review.py --phase final
```

## Verified downloaded detail

| Prototype | Vertices | Triangles | Base color | PBR maps |
| --- | ---: | ---: | --- | --- |
| 1 | 488,011 | 913,776 | 8192x8192 | 4096x4096 |
| 2 | 853,014 | 1,575,210 | 8192x8192 | 4096x4096 |

The GLBs embed normal and packed metallic/roughness maps. Separate downloaded
metallic, roughness and normal PNGs are also retained with the paid sources.

Object and Shadow outputs are base-art and shadow review layers respectively.
Composite frames are unused renderer evidence; no glow or runtime color mask was
requested. The common presentation crop changes only the contact-sheet display,
preserving equal scale between prototypes and all original 1024px frames.
Contact sheets apply 35% opacity to shadow masks for presentation only. Source
Object/Shadow PNGs remain untouched. Review generation repacks both sheets directly
from those raw PNGs with Pillow and asserts exact RGBA equality for all 32 cells;
this avoids the existing shared Blender packer's extra color conversion.

Independent lower-height measurements support the foundation estimate: prototype 1
remains 2.6609x2.8 through the bottom 35% of height; prototype 2 remains 2.5540x2.8
through the bottom 30%. This establishes a draft fit, not production collision or
mechanical-part validation. No in-game test was required for these staged samples.
