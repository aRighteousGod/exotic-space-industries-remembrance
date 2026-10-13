# Grey outlet calibration and approved short ribbon

User approval: 2026-10-13, after the half-length comparison and short-ribbon
iteration. The 32-pixel central crop is implemented in the canonical production
stream. All machine, effect and item/research artwork belongs to Graphics 6.
No shipping PNG, model, damaging particle count or runtime controller changed.

## Source of truth

`user-points.json` preserves the nine supplied clicks and the atlas SHA256.
`origin-fit.json` records the single rotating fit and residuals. Use full
`head_pixel` values, not the rounded tile coordinates. The grey nozzle opening
ahead of the ivory housing is the reference. The head atlas hash is
`a9d05dd5c9fce9e70b465dc933fd9a7783634ceeb83353ca1440714a45217105`.

With `phi = head_frame * 2*pi/256`, offsets relative to the bearing are
`x=L*sin(phi)` and `y=-sqrt(0.5)*(L*cos(phi)+H)`. The final fit uses
`L=0.854090101414`, `H=0.886152416900`; RMS error is 0.648 native pixels and the
worst of the nine marks is 0.937 pixels. Native creation markers independently
agree with the projected rotating source within one native pixel. That does
not establish the visible ribbon's full extent.

## Native evidence and decision

Heavy outputs: `D:/CodexArtifacts/esir-acidthrower-20261013`.
Tests use Factorio 2.0.77, high graphics, the active Original performance
profile, and the exact 99-mod live selection/settings staged privately.
Production packs are repository junctions; installed mods are not overwritten.

| Run | Purpose |
| --- | --- |
| origin-calibration | Actual canonical turret reproduces old 64-pixel backward overdraw |
| origin-calibrated | Rejected state-specific muzzle vectors |
| origin-diagnostic | Particle-only/spine-only isolation; particle birth is at the grey tip |
| origin-ribbon-fit | Canonical 32-pixel crop and 24/40-pixel controls |
| origin-half-ribbon | 32 versus full 64, half-length artwork shift and physical launch shift |
| origin-short-tuning | 30/34/36 widths, 32-pixel small shifts, and no-crop controls |

The last run produced 3,596 captures, including 551 of the actual canonical
turret: all four facings through +/-47.9 degrees, static ESE, retargeting and
shutdown. Sixteen consecutive frames expose emission-phase differences that
the earlier static helper checks missed. Atlas matching is within one head
frame of next-tick orientation across the full run.

The original full ribbon extends roughly 15-22 native pixels behind the ESE
opening. Moving its artwork by half its nominal length creates phase-dependent
gaps approaching 19 pixels; moving the physical source leaves a gap and moves
the particle birth away from the calibrated opening. Neither is retained.

The short 32-pixel ribbon is the approved compromise. The 30-pixel/forward-shift
variants reduce overlap slightly but worsen detached phases; 34/36 pixels or a
rearward shift cover more of the grey sleeve. Disabling automatic cropping is
effectively unchanged. Production uses the centre 32 pixels of each 64x32 cell,
scale 0.5, the existing 2.25/32 vertical shift, and no longitudinal shift.

Some native phases still have a brief gap, particularly near cardinal poses.
This is an accepted visual tradeoff, not a claim of one-pixel ribbon contact in
every frame. Keep profile clipping and particle cadence; no extra damaging or
cosmetic particles are added to conceal it. No UPS improvement was measured.

`review/origin-contract-check.json` verifies all seven machine hashes,
Graphics-6 references, the resolved crop and alias inheritance, and exact
unchanged payload/cadence outside the ribbon animation. Machine prototypes
differ only in the calibrated native origin. Sustained damage/fluid benchmarks
were not rerun for this cosmetic frame selection. Earlier 8x/16x refresh fixes
remain untouched; this iteration's native visual acceptance uses active Original.

The first short-tuning fixture attempt failed because a new QC-only require
was inside setup. It is now loaded during control parsing. The failed log is
retained as `origin-short-tuning/fixture-require-failure.log`; final evidence
comes from the successful fresh rerun, not that attempt.

## Replay

Run from the repository root. Stage the exact live ZIP versions/settings with
`scripts/qc/acid-jet/stage_origin_live.py` (see its command-line help), or reuse
the preserved `origin-calibration/qc/mods` seed. Copy its `mod-settings.dat` into
the new artifact root's `qc/mods` before invoking the native fixture.

```powershell
$root='D:/CodexArtifacts/esir-acidthrower-20261013/origin-short-tuning'
$fit='output/acidthrower-origin-calibration-20261013/final-fit/origin-fit.json'
python -B scripts/qc/acid-jet/fit_origin.py `
  .codex/esir/asset-generators/acidthrower-turret/revision-03/pressure-jet/origin-calibration/user-points.json `
  output/acidthrower-origin-calibration-20261013/final-fit
& ./scripts/invoke-acid-jet-qc.ps1 -OriginProbe -OriginVariants `
  -OriginVariantSet short -Visual -Profiles original -GraphicsQuality high `
  -ArtifactRoot $root -SeedMods D:/CodexArtifacts/esir-acidthrower-20261013/origin-calibration/qc/mods
python -B scripts/qc/acid-jet/review_origin.py $root $fit
python -B scripts/qc/acid-jet/check_origin.py $root $fit
python -B scripts/qc/acid-jet/compare_origin.py $root `
  output/acidthrower-origin-calibration-20261013/short-comparison --short
```

Use `-OriginVariantSet half` without `--short` on the comparison builder to
replay the half-length options. Omit `-OriginVariants` for canonical-only work.
Source effects observe creation/replacement, not every particle or refresh.
Do not reinterpret an old creation marker as the current rotating muzzle.
