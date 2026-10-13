# Acidthrower revision 03 / pressure jet

## Approved short ribbon / 2026-10-13

The current production origin and 32-pixel ribbon crop follow the nine
user-selected grey-nozzle marks and canonical turning captures. All shipping
art stays in Graphics 6; this revision changes prototype registration and frame
selection, not PNGs. See [origin-calibration/README.md](origin-calibration/README.md)
for the fit, rejected half-length offsets, short-ribbon refinements and replay.
The older reports below do not establish continuous nozzle attachment.

Artifact root: `D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet`.
All heavy render, cache, fixture, screenshot and benchmark writes belong on D:.
No Meshy task, model change or machine-sprite regeneration is involved.

## Dispersion-03 / grey nozzle and softer onset / 2026-10-12

The current repair is in `pressure-jet.lua`: native animation registration puts
the visible liquid at the grey cylinder's opening ahead of the ivory housing.
Flecks begin at 12 percent flight, grow from 0.05 to 1 over their 12-tick lifetime,
fade in for eight ticks and out for four. Source frequency drops from 0.8 to
0.59 to compensate for the longer emitting path; late profiles still divide it.
No PNG, model, damaging cadence or runtime handler changes are needed.

Final evidence: `D:/CodexArtifacts/esir-acidthrower-20261012/dispersion-03-soft`.
The earlier `dispersion-03` sibling preserves a rejected, too-prominent onset.
See [DISPERSION-03-VALIDATION.md](DISPERSION-03-VALIDATION.md) for measured results.
The replay baseline must include the approved 35-percent wet flecks, not the
older no-dispersion jet or lobbed flame:

```powershell
$jetRoot='D:/CodexArtifacts/esir-acidthrower-20261012/dispersion-03-soft'
python -B scripts/qc/acid-jet/build_baseline.py --root $jetRoot `
  --source-data D:/CodexArtifacts/esir-acidthrower-20261012/delivery-3409af86/qc/original-visual/script-output/final-data.json `
  --source-art exotic-space-industries-remembrance-graphics-6/graphics/entities/acidthrower-turret/pressure-jet
& ./scripts/invoke-acid-jet-qc.ps1 -ArtifactRoot $jetRoot -Visual -Profiles original `
  -SeedMods D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02/qc/mods
& ./scripts/invoke-acid-jet-qc.ps1 -ArtifactRoot $jetRoot -ProbeOnly -Profiles 2x,4x,8x,16x `
  -SeedMods D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02/qc/mods
python -B scripts/qc/acid-jet/review_dispersion.py --root $jetRoot --profiles original
python -B scripts/qc/acid-jet/review_onset.py $jetRoot --out "$jetRoot/onset"
```

The sections below preserve historical settings and validation for dispersion-02.

## Dispersion-02 / 2026-10-12

Current artifact root is the `dispersion-02` child. The source sticker now
references vanilla wet acid beads, with normal blending and an olive-green tint.
Native probes did not establish suitable travel-age particle growth, so a short
cosmetic wet-fleck source starts at 35 percent flight. Its source frequency is
0.8 under Original and divided by the late profile factor. The smoke-quality
opt-out remains available; clipped/sparse spray is preferable to spending more
UPS to preserve presentation at higher factors. No damaging particles, scripted
runtime effects or cosmetic density compensation are added.

The local generator adds 16 fleck frames cropped to 96x96. Only the object sheet
is shipping; its unused shadow remains render evidence. All 15 revision-03
machine/effect/item/research files now belong to Graphics 6. The seven machine
sheet hashes remain unchanged. Existing shared flame sheets remain in Graphics 3.

The native source uses barrel length 0.835 and world muzzle height 0.87555.
Independent visible-outlet coordinates, native launch markers and startup frames
replace the previous self-referential model-anchor test. Back-facing cap centres
are inferred and have greater uncertainty than visible bores.

Replay the new revision with the preserved approved FINAL baseline:

```powershell
$jetRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02'
python -B scripts/qc/acid-jet/build_baseline.py --root $jetRoot
& ./scripts/invoke-acid-jet-qc.ps1 -ArtifactRoot $jetRoot -Visual -DispersionProbe -Profiles original
& .codex/esir/asset-generators/acidthrower-turret/revision-03/pressure-jet/render.ps1 -ArtifactRoot $jetRoot -Parts flecks
python -B .codex/esir/asset-generators/acidthrower-turret/revision-03/pressure-jet/pack_fx.py --root $jetRoot --parts flecks
& ./scripts/invoke-acid-jet-qc.ps1 -ArtifactRoot $jetRoot -Visual
& ./scripts/invoke-acid-jet-qc.ps1 -ArtifactRoot $jetRoot
python -B scripts/qc/acid-jet/review_dispersion.py --root $jetRoot
```

Final ownership inspection uses an isolated `final-inspection` child with a copy
of the frozen baseline and the same dependency seed. Run `-Profiles original
-ProbeOnly`, then aggregate with `scripts/qc/acid-jet/finish_dispersion.py`.
For parallel headless runs the `combat` child uses `-SeedMods` from the visual
staging; same-volume dependency archives are hard-linked, not duplicated.
See [DISPERSION-02-VALIDATION.md](DISPERSION-02-VALIDATION.md) for final results.

The 352 captures per profile contain the four-facing/range/sector day-night
matrix, twelve clean/marked outlet poses, startup, shutdown and small/large/moving
sticker samples through refresh and expiry. The comparison baseline retains the
approved fast jet and 8x/16x refresh fix, with frozen old FX textures and a
helper-only green-fire sticker. Flight parity permits one tick for the small
muzzle adjustment. Airborne envelope span and core occupancy are measured
separately; clipped high-profile cosmetics are not acceptance failures.

The remainder records the previous pressure-jet revision and its historical
replay/evidence. Its old QC dimensions and visual claims do not certify the new
outlet correction or dispersion.

## Art direction and roles

A compact industrial pressure nozzle ejects an acid-green liquid core with pale
wet reflections. Keep the line narrow, nearly direct and visibly uneven:
travelling thickness knots, unequal ripple wavelengths and small rounded beads.
Use normal blending and ambient lighting, no emitted light or flame puffs.
The landing effect has a dense centre and short translucent outward droplets
reaching the existing radius-three footprint, without a persistent puddle.

The Blender generator creates the liquid geometry locally, through the existing
Factorio preset at 64 source pixels per tile with separate Object/Shadow passes.
The 16-frame spine is 64x32; 16-frame particles are 32x32; the 24-frame splash is
512x512. Runtime scale 0.5 yields 32 native pixels per tile. The former 64-pixel intrinsic extent still overdraws the grey barrel in current
canonical captures; production now selects a central 32-pixel window. The
original 256-pixel draft and selected comparison captures
are retained under `iterations/initial-wire`.

| Shipping file | Role |
| --- | --- |
| acid-pressure-spine.png | Normal-blend liquid ribbon, irregular travelling core |
| acid-pressure-droplet.png | Small rounded liquid beads |
| acid-pressure-droplet-shadow.png | Particle shadow |
| acid-pressure-splash.png | Brief cosmetic impact droplets |
| acid-pressure-splash-shadow.png | Impact shadow |

`acid-pressure-spine-shadow.png` is retained in the render/export evidence only.
It is not shipped or referenced; native ribbon shadows are not layered twice.
Packing is lossless and rejects cropped alpha. `effect-qa.json` records dimensions,
roles and SHA256 values. `machine-hashes-before.json` anchors all seven unchanged
machine sheets. No owner-colour or glow mask is generated for these liquid FX.

## Replay

Run from the repository root with Blender 5.1.1, Python, Pillow and NumPy.
The generator imports the repo's shared Factorio renderer and preset scene.

```powershell
$jetRoot='D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet'
$jetScripts='.codex/esir/asset-generators/acidthrower-turret/revision-03/pressure-jet'
& "$jetScripts/render.ps1" -ArtifactRoot $jetRoot
python -B "$jetScripts/pack_fx.py" --root $jetRoot
& ./scripts/invoke-acid-jet-qc.ps1
& ./scripts/invoke-acid-jet-qc.ps1 -Visual
python -B "$jetScripts/review_native.py" --root $jetRoot
& ./scripts/invoke-acid-art-qc.ps1 -Visual -GraphicsQuality medium `
    -RunRoot "$jetRoot/machine-check" -SeedMods "$jetRoot/qc/mods"
python -B .codex/esir/asset-generators/acidthrower-turret/revision-03/review_native.py `
    --root "$jetRoot/machine-check" --captures "$jetRoot/machine-check/script-output"
python -B "$jetScripts/summarize.py" --root $jetRoot
```

Render `-Parts spine,droplet` for ribbon/particle-only iteration. Promote only
the five inspected shipping sheets, then verify fresh native data and captures.
Do not promote the unused spine shadow or regenerate the seven machine images.

The user approved a narrow 8x/16x compatibility exception: halve the native
attack-refresh cooldown and fluid per refresh after the late pass calculates
its existing timeout. Particle intervals and per-particle damage stay fixed.
This prevents short-flight streams losing sparse emissions and also corrects
the old 16x minimum-range underdelivery. See `refresh-proposal.md` and the measured
results in `VALIDATION.md`. Historical candidate folders are investigation
evidence; final acceptance uses production runs with candidate flags false.

## Native evidence

Each visual profile produces 264 screenshots: four facings, three nominal ranges,
three aim positions and day/night; eight nozzle comparisons; 112 sequence frames.
Nominal 9/38 targets are placed at 9.02/37.98 and sector limits at +/-47.9 degrees,
then actual fixed-point target and source positions and orientations are logged.
These tolerances avoid rejecting a target just outside the exact native boundary.

The native gallery includes direct PNG links, an actual-pixel-size toggle, a
6x nearest-pixel texture crop and old/new firing/shutdown animations. Width/bow
measurements use capture coordinates and detected green pixels, excluding the
machine and the target. Native source effects count stream creation/replacement,
not individual damaging particles; landing effects count individual impacts.

Stationary combat uses a 30-second warm-up and 120-second sample, four fluids,
two qualities and two modifier combinations. Direct damage, corrosion and their
combined payload are separated. Sparse profiles additionally compare minimum,
medium and maximum range. Moving-target differences are reported separately.
The dedicated machine fixture checks source-to-muzzle alignment, 21 fine-rotation
frames, active-only glow shutdown and nearby-pipe draw order.

The production contract and late-profile ownership are documented in
[the conceptual model](../../../../blueprints/acidthrower-pressure-jet.md#contract).
See `VALIDATION.md` for the final evidence and any acceptance limitations.
