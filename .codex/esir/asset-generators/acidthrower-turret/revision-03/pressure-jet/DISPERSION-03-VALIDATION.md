# Acidthrower dispersion-03 / grey nozzle and softer onset

Implemented locally and checked with Factorio 2.0.77 on 2026-10-12.
Final evidence: `D:/CodexArtifacts/esir-acidthrower-20261012/dispersion-03-soft`.
This follow-up changes prototype presentation settings, with no new shipping
images, machine re-render, Meshy generation, runtime handler or deployment.

## Visible grey-nozzle attachment

The reference is the dark outlet of the grey cylinder ahead of the ivory head
housing. The existing native source marker was close to that opening, but the
rendered spine's baked elevation displaced its visible centre by roughly 2.2
native pixels sideways. Marker-only acceptance therefore missed the defect.

`spine_animation.shift={0,2.25/32}` and `particle.shift={0,1.35/32}` correct the
liquid registration. Native screenshots establish that the spine shift rotates
with the jet. Barrel length 0.835, muzzle height 0.87555, bearing, placements and
all seven machine images remain unchanged. A comment in `graphics.lua` identifies
the grey outlet explicitly and keeps liquid registration owned by pressure-jet.

The final twelve-pose Original comparison measures maximum mean transverse
displacement of 0.46 native pixel. All seven visible/side bores have actual
liquid within one native pixel of the independently marked outlet. Away-facing
apertures are inferred through their cap/rim and have approximately one pixel
of marking uncertainty; their largest nearest-liquid distance is 1.75 pixels.
Those are not claimed as directly visible bore measurements.

Clean and marked screenshots are consecutive emission phases. The clean phase
already contains native particle gaps in the approved control; the marked phase
connects all twelve poses. The repair preserves those cadence gaps instead of
spending more particles to conceal them. Neither gap phases nor cyan markers
alone certify the visible attachment. `review_dispersion.py` now measures both.

## Earlier and softer breakup

Flecks begin at 12 percent flight rather than 35 percent. Their scale grows from
0.05 to 1 over the existing 12 ticks, with eight ticks fading in and four fading
out. There is no fully opaque plateau. Frequency is 0.59 under Original, divided
by 2/4/8/16 by the existing late pass. The normalized expected source budget is
0.5192 versus the previous 0.52, with unchanged lifetime. This is a particle-budget
calculation, not a measured UPS benchmark; no damaging emission is added.

The rejected first trial (`dispersion-03` sibling) reached full-sized clusters
too early and recreated the hard boundary. Final sustained 38-tile east-facing
captures measure an initial 12-16 percent travel envelope of 7.92 native pixels,
then 14 pixels in the following bin. At 24 tiles those bins measure 7.63 and
15.26 pixels. The initial trial measured 28.73 and 31.23 pixels in the first bin.
Final 9/24/38 comparisons and all four centre facings at maximum range, by day
and night, show subordinate earlier flecks without the abrupt full-width wall.
The airborne field is intentionally fainter and somewhat narrower. Stationary
cosmetic smoke does not implement deterministic per-projectile distance growth.

## Verification and limits

- Original: 352 fresh native screenshots, including four facings, 9/24/38 tiles,
  centre and both 47.9-degree limits, day/night, startup, firing and shutdown.
- Original, 2x, 4x, 8x and 16x: all five native fixtures pass; 180 paired flight
  cases differ by at most one tick. Moving targets, switching, shutdown, inside/
  outside radius-three tests and corrosion refresh/expiry probes pass.
- Fresh source/resolved/alias stream snapshots match delivered baseline
  `delivery-e0a8144e` after excluding precisely the changed cosmetic fields.
  Attack parameters and stickers match exactly in every profile, retaining the
  approved 8x/16x refresh fix. Long sustained damage/fluid benchmarks were not
  rerun for this presentation-only repair.
- All seven Graphics-6 machine hashes match the approved originals. No PNGs
  changed. Four touched Python scripts parse and scoped `git diff --check` passes.
- The aggregate conceptual-model audit reports three unrelated missing primary
  markers under `minigun-turret-HD`. It reports no acidthrower findings. This is
  not a clean aggregate repository audit, and no broad preflight is claimed.

## Retained evidence

- `gallery/index.html`: native/enlarged comparisons and firing/shutdown GIF.
- `dispersion-visual-qa.json`: all 144 old/new day/night matrix width records,
  source markers, actual visible-ribbon measurements and seven machine hashes.
- `onset/`: reproducible comparison strips and four-percent travel-bin metrics.
- `attachment/`: annotated twelve-pose contact sheet and detailed pixel metrics.
- `validation-summary.json`: five-profile native and resolved-data comparisons.
- `baseline/`: immutable approved jet and flecks, including their original PNGs.

README.md records replay commands. Compact sources and review evidence accompany
the D: results; the earlier rejected trial remains separate investigation evidence.
