# Pressure-jet validation / 2026-10-09

Implemented and checked in Factorio 2.0.77. Artifact root:
`D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet`.
No machine model or machine image changed. No Meshy task, production runtime
handler, startup option, public interface, migration or release package was added.

## Native visual acceptance

All five profiles have 264 fresh captures each: four placement facings, nominal
ranges 9/24/38, centre and both firing-sector limits, daylight/night, muzzle
close-ups and firing/shutdown sequences. All 36 old/new trajectory pairs per
profile fired and landed. Targets use 9.02/37.98 and +/-47.9 degrees to stay inside
the unchanged exact 9–38/48-degree native boundaries after fixed-point rounding.
Reports retain actual positions and launch orientations.

The final Original profile has a median 2-pixel green core, including near the
nozzle; the 10th–90th percentile is 2–3 pixels. Detected green spans 97.8 percent of
the sampled central columns, with restrained bead breakup. Maximum visible bow
is 7.002 pixels / 0.21883 tile above the measured source-to-impact line, below 0.25.
The organic 16-frame ribbon uses unequal travelling ripples and rounded droplets.
All four nozzle close-ups show liquid beginning at the outlet; shortening the
intrinsic ribbon from 256 to 64 pixels removed the initial housing overdraw.
Night captures dim with ambient lighting; the stream adds no area light.

Centre-aim launch-to-first-impact timings across four facings:

| Nominal range | Old | New |
| --- | --- | --- |
| 9 tiles | 22–26 ticks | 9–11 ticks |
| 24 tiles | 67–70 ticks | 27–28 ticks |
| 38 tiles | 108–111 ticks | 43–45 ticks |

At 60 ticks/second, the measured maximum-range change is about 1.8–1.85 to
0.72–0.75 seconds. This excludes preparation time and measures from the actual
muzzle. Higher performance profiles deliberately retain sparse segments and
intermittent short-range emission rather than adding damaging particles.

## Damage, fluid and native behavior

432 old/new stationary pairs cover all four acid fluids, normal/legendary quality,
two research-modifier combinations, and separate direct/sticker/combined damage.
Each run warms up for 1,800 ticks and measures 7,200 ticks. Original/2x/4x combat
uses the initial approximately 24.5-tile snapped placement; their final visual
and trajectory matrices were rerun with corrected coordinates. 8x/16x combat
uses actual turret-centred 9.02/24/37.98 positions. Initial edge-rejection and
candidate-only reports are excluded from final visual acceptance.

| Profile | Largest damage-ratio error | Largest fluid-ratio error |
| --- | --- | --- |
| Original | 0.0278% | 0% |
| 2x | 0% | 0% |
| 4x | 0.0556% | 0% |
| 8x | 0.2223% | 0% |
| 16x | 0.4465% | 0.4465% |

Errors compare against unchanged damage, except the explicitly approved 16x
minimum-range correction below. Finite-window particle/refresh phase explains
the small discrepancies. The reference sulfuric-acid normal turret consumes
15 fluid/second. Radius probes at 2.9 are damaged and 3.1 remain untouched. No
ground-fire entities are created. The original 900-tick corrosion duration,
0.6 movement multiplier and profile-owned sticker damage remain intact.

Moving-target, replacement-target and shutdown probes pass in each profile.
In Original, the moving target's first hit advances from tick 109 to 70 in the
fixture; early damage is intentionally higher with faster arrival. This is
reported separately from stationary parity. The 24-tile shutdown probe's last
landing is 80 ticks after stop for old and 42 for new, including the retained
native emission timeout. Landing counts stop increasing; headless runs also
confirm corrosion expires naturally. There is no runtime timer keeping fire alive.

## Approved sparse-profile correction

Native short-flight streams can retire before their next sparse particle. With
the original refresh cooldown, the fast jet lost half its direct damage at 8x
near minimum range and 16x at medium range. Fade 64 and short-loop/default-fade
experiments did not preserve the stream. The user approved halving only the
8x/16x attack-refresh cooldown and fluid per refresh. This is applied after
the existing timeout calculation, preserving the intended particle density.

| Profile | Particle interval | Timeout | Attack refresh | Fluid per refresh |
| --- | --- | --- | --- | --- |
| Original | 2 | 16 | 4 | 1 |
| 2x | 4 | 16 | 8 | 2 |
| 4x | 8 | 24 | 16 | 4 |
| 8x | 16 | 48 | 16 | 4 |
| 16x | 32 | 96 | 32 | 8 |

The old 16x stream also underdelivered at minimum range. Restoring its intended
cadence approximately doubles direct damage there while preserving corrosion.
The normal unmodified sulfuric-acid combined result is 149.28 -> 199.00 DPS,
about 33.3 percent higher; medium/maximum-range combined DPS remains 199.00.
The checker treats that known baseline defect separately and verifies weighted
direct-plus-sticker expectations across fluids, qualities and research.
Final 8x/16x evidence has both candidate flags false and the production snapshot
contains the refresh values above. Other throwers retain their prior behavior.

## Machine and source regression

The separate 88-capture machine fixture passes all 12 muzzle cases with maximum
error 0.9222 native pixel, 21 distinct consecutive fine-rotation housing crops,
active-only head/tank glow shutdown and four-facing adjacent-pipe draw order.
All seven machine PNG SHA256 values remain identical. The five shipping effect
sheets match the lossless packing manifest; the unused spine shadow stays staged.

Fresh focused final-data snapshots record source, resolved and alias streams,
turret, sticker and unchanged handheld/vehicle definitions. The source and its
aliases use speed/leading 0.85, acceleration 0.00025, deviation 0.0015, target
deviation 0, width 0.1 and scale-per-part 1. Range, sector, rotation speed, ports,
collision/selection boxes, machine offsets and sound are unchanged.

Lua parse checks and the conceptual blueprint audit pass. Native captures use
medium graphics quality and isolated lab-tile fixtures; this is focused combat
and asset acceptance, not a populated-factory UPS benchmark. The aggregate
preflight suite was not rerun for unrelated worktree changes.

## Review and replay

`gallery/index.html` links all 1,320 stream captures, native-size comparisons,
6x texture detail and short old/new firing/shutdown GIFs. The machine gallery
adds fine rotation, glow shutdown and draw-order comparisons. See
`validation-summary.json`, per-profile `qc/*/acceptance.json`, fresh focused
`final-data.json`, and `machine-check/native-visual-qa.json` for numeric evidence.
`README.md` contains generation and native replay commands. All heavy write-data,
render caches, saves, dependency staging and screenshots were routed to D:.
