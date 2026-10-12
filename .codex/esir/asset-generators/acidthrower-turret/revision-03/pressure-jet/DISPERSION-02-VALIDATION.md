# Acidthrower dispersion-02 / 2026-10-12

Implemented and checked with Factorio 2.0.77. Heavy artifacts:
`D:/CodexArtifacts/esir-acidthrower-20261009/revision-03/pressure-jet/dispersion-02`.
The implementation is delivered through a scoped Git commit; this task did not
package or deploy it to the live Factorio mod directory. The seven machine images remain byte-identical.

## Result and ownership

- `ei-acid-sticker` uses the vanilla 50-frame wet acid animation with normal
  blending and olive-green tint. Sticker identity, 900-tick lifetime, 0.6 slowing
  and profile-owned corrosion damage/refresh stay intact.
- A 12-tick native cosmetic wet-fleck effect starts at 35 percent flight. The
  existing connected core, trajectory, impact radius and damaging cadence stay
  intact. Native particle probes rejected growth based on burst emission order.
- The source is moved to the lip with barrel length 0.835 and world muzzle
  height 0.87555. Machine scale, placement and bearing shifts are unchanged.
- All 15 revision-03 shipping graphics are in Graphics 6: seven machine sheets,
  six liquid-effect sheets and two icons. Exact superseded copies were removed
  only after destination hashes matched. The wet sticker references the base
  game directly. Delivery cleanup retires three original gun sheets
  (3,146,172 bytes), four unused flame sheets (4,569,077 bytes), the disconnected
  four-fire/four-smoke/two-stream graph and its `acid-util.lua` builder. Current
  graphics are applied to the turret before registration. Shared `spark.png`
  and the optional poison fallback remain for current ordnance consumers.

## Native evidence

Every profile has 352 fresh screenshots: four placement facings, 9/24/38 ranges,
centre and both 47.9-degree sector limits, day/night, twelve clean/marked outlet
poses, startup, firing/shutdown and small/large/moving corrosion samples through
refresh and expiry. Total: 1,760 screenshots. All source/landing, retargeting,
shutdown and 2.9-inside/3.1-outside impact-radius checks passed. No ground fire
was created. The 432 sustained comparison pairs use the approved fast jet and
refresh fix as baseline, four fluids, normal/legendary quality and two modifier
combinations, after 1,800 warm-up ticks over a 7,200-tick measurement window.

| Profile | Stationary pairs | Largest damage difference | Fluid difference | Cosmetic source frequency |
| --- | ---: | ---: | ---: | ---: |
| Original | 48 | 0% | 0% | 0.8 |
| 2x | 48 | 0.0556% | 0% | 0.4 |
| 4x | 48 | 0.1112% | 0% | 0.2 |
| 8x | 144 | 0.2228% | 0% | 0.1 |
| 16x | 144 | 0% | 0% | 0.05 |

Small finite-window damage differences follow arrival/refresh phase after the
small source displacement. All 36 paired flight tests per profile differ by at
most one tick. The approved 8x/16x refresh correction is retained. No new damaging
particles or production runtime handlers were added. Sparse segments/clipping
are intentional at higher factors; cosmetic density is not increased to hide
them. The normal graphics smoke opt-out can disable outer flecks.

At Original maximum range, centre-aim late envelopes measure 24.00, 25.77,
24.00 and 26.17 native pixels for N/E/S/W: 0.75-0.82 tile. Near-core occupancy
is 2.38-2.63 pixels per sampled column. Outer droplets are separated and the
core remains coherent through the first third; neither effect emits light.

Visible outlet centres were marked independently on the shipping atlas. Native
launch-marker fit has a maximum error of 1.014 native pixel at a visible mouth,
with half a native pixel of marking uncertainty. Back-facing cap centres are
inferred, with a 1.463-pixel maximum error and larger uncertainty; these are not
claimed as visible-bore measurements. Clean/marked captures preserve the evidence
instead of treating the old model-anchor formula as proof of alignment.

Fresh final inspection resolves the machine/effect family and item/technology
icons from Graphics 6. The item retains 128/64/32 mipmaps; technology size remains
256. All seven relocated machine hashes match the originals. PNG structure and
Python syntax checks pass. The conceptual-model audit passes with zero findings.
Broad preflight did not finish: traversal failed in an unrelated minigun firing
artifact directory. This is not a clean aggregate-repository preflight verdict.

## Scoped GitHub delivery / 2026-10-12

The unused-effect reachability audit is recorded in
`LEGACY-EFFECT-RETIREMENT.md`. A separate exact Git-tree export on D: passes
fresh native Original/2x/4x/8x/16x fixtures: all ten retired definitions are
absent, all 180 paired flight poses pass, and radius, tracking, target-switching,
shutdown and corrosion expiry probes pass. Resolved active stream, alias,
corrosion and cosmetic-fleck tables match the approved dispersion data after
normalizing the already approved pack relocation and ignored legacy fields.
All 15 shipping PNGs are verified; seven machine images remain unchanged.

Candidate preflight completes with passing missing-require, asset-reference,
Python/PowerShell syntax, locale, pack-version and conceptual-model checks.
The aggregate verdict still fails on the existing out-of-scope encoding finding
in `scripts/qc/singularity-lance/angular-results.json`; existing unrelated runtime
header warnings remain. Factorio 2.0.77 supplies the native Lua/data validation.
Current source, historical art, compact review reports and baseline provenance
are retained under `D:/CodexArtifacts/esir-acidthrower-20261012/delivery-*`.

## Evidence and replay

- `gallery/index.html`: all native comparisons, enlarged outlet markers,
  corrosion comparison and firing/shutdown animations.
- `validation-summary.json`: five-profile cadence, damage/fluid and ownership.
- `dispersion-visual-qa.json`: 720 day/night old/new width records and outlet fits.
- `graphics-6-relocation.json`: fifteen source/destination hashes.
- `final-inspection/qc/original-probes/script-output/final-data.json`: fresh final
  machine, stream, aliases, sticker and icon prototypes.
- `baseline/`: preserved approved final pressure-jet art/contract and diagnostic
  playback artwork. The initial stale 256px snapshot was rejected and corrected
  before final acceptance; no failed loading run counts as visual evidence.

See README.md for generation and native replay. No PBR/mechanical model checks
were reintroduced; the model and machine images were not regenerated.
