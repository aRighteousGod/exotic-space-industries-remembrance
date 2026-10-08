# Ten-leg hover qualification — 2026-10-05

Current Factorio **2.0.77** engine evidence identifies a smoother ten-leg candidate,
two groups of five, overlap **0**, response **.02/.02** and stretch force **.2**.
**It is not promoted.** The retained native hover causes decorative effects to
separate from the lower crystals. Shipping remains the original four-leg gait;
the durable `-TenLegTrial` helper can reproduce the calibrated ten-leg candidate.
Mount and ground anchors fit the preceding four-anchor bounds. Height **1.8**,
bob **.08**, torso turning **.005**, selection distances, friction and the native
20% slowing safeguard retain their preceding values. The original model and
128-direction sheets are unchanged.

## Measured selection

`glide-qualify` records 3600 per-tick samples for 128 native actors: eight
headings, naked/one normal exoskeleton, four-anchor control, saucer and six
ten-anchor calibration candidates. The same normal reactor/exoskeleton placement
is used on each equipped comparator. Warmed cruise is ticks 300–899.

| Candidate | Mean saucer speed ratio | Range across 16 cases | Mean cruise CV | Result |
|---|---:|---:|---:|---|
| Original four anchors | 51.372% | 50.781–52.337% | .6320% | Control |
| Ten, overlap 0, original force | 47.504% | 46.372–48.386% | 1.2755% | More variation |
| Ten, overlap .5, original force | 66.223% | 61.174–84.475% | 28.1172% | Surging; outside band |
| Ten, overlap .75, original force | 53.845% | 24.385–104.447% | 60.7616% | Surging; outside band |
| Ten, overlap 0, force .2 | **52.855%** | **52.183–53.587%** | **.4562%** | Best gait; rejected visual gate |
| Ten, overlap .05, force .2 | 52.856% | 52.183–53.587% | .4564% | Similar cruise; more reversal hesitation |

The first three ten-anchor comparisons come from `glide-initial`; the final
calibrated comparisons come from `glide-qualify`. Controls are reproduced in
both runs. Responsiveness/force/selection/friction sweeps precede qualification.
The force change was measured rather than derived from a leg-count formula.

The best gait candidate reduces average normalized cruise variation **27.8%**,
with an improvement in all sixteen cases (16.7–58.2% relative). Naked cruise is
53.339–53.587% of saucer speed; one-exoskeleton cruise is 52.183–52.315%.
Peak-to-peak cruise ripple is at most 1.494%. Native speed and quantized world
displacement are retained separately in the traces.

Transient tradeoffs are explicit:

- Mean braking travel rises **4.422 → 4.779 tiles**, maximum paired increase
  **.711 tile**. Full stop occurs after 98–108 ticks versus 91–105; mean delay
  5.69 ticks and maximum 11 ticks. Both configurations settle completely.
- Restart reaches 90% of its own warmed speed **2–5 ticks later**. Mean restart
  distance is 2.6% greater, which is not itself a smoothness measure.
- A 30-tile approach settles 3.44 ticks later on average, at most 14 later.
  Mean along-path overshoot is **2.293 → 2.647 tiles**, maximum paired increase
  .586 tile. No persistent motion remains after native settlement.
- Turn speed CV falls approximately **34% / 23% / 64%** for 45° / 90° / 180°.
  The 90° maximum quantized velocity step rises approximately 5.4%; the 45°
  maximum step falls. The 180° phase has one stopped displacement sample instead
  of three or four and makes substantially more progress along the new heading.
- The .05-overlap candidate has equivalent cruise but 201 stopped turn samples
  across qualification, versus 16 selected and 52 control samples. Higher
  overlap does not qualify merely because it allows concurrent steps.

These bounded braking/arrival changes are a modest handling tradeoff for smoother
cruise and reversals. This is not a claim that every movement metric improves.
The phase named `final-stop` includes a restart at tick 3200 and is not used as a
stopping measurement.

## Public ten-leg trial evidence

All paths below are under `.factorio-qc/anisetron/<run>/script-output`.
The clean physics clone qualification does not substitute for these checks.
These runs temporarily exercised the public prototype with ten legs before
attachment review rejected promotion. Subsequent shipping checks use four legs.

| Run | Result | Scope |
|---|---|---|
| `glide-qualify` | 256/256 topology/validity assertions; all 16 selected speed cases in band | Per-tick native physics comparison |
| `glide-native` | 149/149 | Public ten-leg vehicle: manual/automatic fire, moving fire, native remote/autopilot, water/cliff/factory/elevated fixtures, quality, equipment/charge/position, player/robot mining and rebuilding, logistics, native blueprint equipment ghosts and real robot ammunition delivery |
| `glide-mobility` | 28/28 | 12000 ticks; actual manual/remote/armed movement, stacked enemy slows, original poison damage, attack persistence and recovery; zero stopped ticks in the protected attack cases |
| `glide-old-slow` | 29/29 | Existing four-leg attack save loads ten legs with original unit numbers, observes configuration change and preserves slowing damage/lifetimes/recovery |
| `glide-upgrade2` | 12/12 | Four-leg rare vehicle save upgrades to ten legs, keeps both body IDs, equipment/logistics fingerprint and genuine paid rare burst; no orphaned legs |
| `glide-upgrade3` | 12/12 | Repeats the upgrade with the stronger fresh configuration-receipt assertion |
| `glide-save` / `glide-reload` | 3/3 and 10/10 | Ten-leg same-configuration save/reload preserves native state, IDs, equipment/logistics and a real paid burst |
| `glide-timing` | 15/15 | Three native payments, 300 contacts per channel, 72000 combined normal damage; paid FIFO survives visual rebuild |
| `glide-clip` | 6/6 | Normal-zoom four/ten comparison captured at actual frozen dusk, original engine pixels, hover bob retained |
| `glide-track3` | 47/47 behavioral assertions | Standard cores, target locks, real attack movement and three live strand handles; pixel attachment gate fails separately |

`glide-upgrade2` recorded a fresh configuration receipt at tick 1917 for helper
version .0.2 → .0.4, startup setting change and first replay tick 1918. The later
fixture assertion explicitly rejects stale seed receipts; `glide-upgrade3`
passes that assertion. `glide-reload` covers ordinary same-configuration replay.

The fresh ten-leg `glide-data` prototype dump and `final-data.json` inspector verify
ten legs, groups 5/5, overlap 0, hidden/unselectable/collision-free leg prototype,
.02 response, force .2, void movement power, progression, recipes, research
science, weapon category and shipped paths. `final-art-data.json` additionally
checks all eight 4096-square sheets, 128 directions, glow/owner/shadow wiring,
icons, hover sound and both firing-loop voices. These inspect current final data,
not the historical September dump. Its 2 GB dump is retained as a 185 MB gzip;
`final-dump-archive.json` records the verified decompressed SHA-256. Final shipping
inspection is separate because the trial was not promoted.

## Failed attachment gate

`motion-alignment.json` evaluates 70 current native frames against the original
128-direction body sources. Unarmed eastbound daytime captures have effectively
equal speed (.17821 / .17781 tiles per tick) and strong body correlations
(.9897 / .9869), yet their inferred extra body lift is +.5093 / -.3579 tiles.
That is **27.75 pixels of vertical change at normal zoom**. The existing correction
is a function of speed only; it leaves later crystal strands **28–38 pixels above
their intended roots**. Night samples agree. Visual review confirms the drift.
Stopped samples correctly remove the strands, but live handles alone cannot
establish attachment. Decorative beam halos use the same correction.

Native core sources largely inherit the body lift correctly: 85/86 measured
centerline distances are at most two pixels. The largest is 2.138 pixels in a
low-confidence nighttime frame. Of 75 strict measurement failures, every one
misses the .95 body-correlation threshold; these are not 75 demonstrated muzzle
defects. One predicted-direction boundary uses index 33 while the displayed body
is 32, with .857-pixel centerline distance. Composite measurements do not certify
all headings or the longitudinal start of the beam.

Per the approved promotion gate, the four-leg prototype and inherited leg force
are restored. No unapproved change to the hover bob or visual carrier is shipped.
The ten-leg fixture remains ready for a future attachment implementation which
inherits native heave; changing one offset constant is insufficient.

## Retained shipping and repository checks

- `glide-retained`: **149/149**, fresh public four-leg native acceptance after
  restoring the promotion gate.
- `glide-restore`: **11/11**, a saved ten-leg rare craft loads the retained four-leg
  prototype with both body identities, native inventories/equipment/logistics and
  its genuine paid burst intact. Configuration change is observed; no native legs
  are orphaned and the burst finishes with one payment and 38400 rare damage.
- `glide-fixture10`: **12/12**, replaying the original four-leg save with the new
  staged-only `-TenLegTrial` flag restores ten native legs and passes the same
  identity, native state and paid-burst assertions. This validates the reproducible
  trial rather than shipping ten legs after rejection.
- `shipping-final-data.json` and `shipping-final-art-data.json`: fresh
  `glide-finaldata` final-data inspection passes. Shipping has **four legs, groups
  2/2**, .02/.02 response, inherited stretch force **.7142857143**, overlap 0,
  height 1.8 and bob .08. Research/recipes/weapon balance, void power, all 128
  directions, eight sheets, icons and audio wiring pass their inspectors.
- `blueprint-retained.md`: **46 models, 122 owned sources, zero findings**.
- `preflight-retained.json`: Lua, Python and PowerShell syntax, conceptual links,
  requires, locale, asset references and version checks pass. The overall result
  remains failed on two preceding encoding findings:
  `scripts/qc/singularity-lance/angular-results.json` suspected mojibake and
  `temp/anisetron-tracking-fix/blueprint-final.json` UTF-16. Existing module-header
  warnings are separate. A short temporary Python cache fixes the initial cache
  permission/path problem without changing unrelated files.
- `preservation.json`: 4930 pre-task file hashes checked, no missing files, all
  eleven approved ANISETRON image assets unchanged. The shipping prototype differs
  from the task baseline only in its trial-result comment and conceptual backlink.

No movement startup setting, scripted propulsion, model generation, additional
spritesheet rendering, Git commit or push is part of this result.

## Native previews and evidence limits

`output/meshy/anisetron/reference17/ten-leg-trial/previews` contains six
before/after WebPs: start, cruise, stop/restart and 45°/90°/180° turns. The four-leg
control is left; public ten-leg vehicle is right. Captures are zoom 1 at actual
frozen dusk, paired at real-time 20 fps without altering native RGB. Each is
under 10 MB and decoded after packaging. Fidelity Off keeps the gait comparison
free of decorative differences; Standard is reviewed separately for beams/trails.

Attachment measurement uses actual native body registration and the existing
128 raw source directions. `measure_motion.py` adapts regression metadata to the
reference17 evaluator. Composite coincident rays remain unmeasurable rather than
counting as alignment successes. Keel heave estimates are diagnostic because
native torso bob is not exposed; pixel visibility and live handle ownership are
separate checks. No new sprite render is necessary for the topology change.

Focused fixtures are single-player/headless or graphics-benchmark engine runs.
They do not establish multiplayer behavior, whole-factory UPS or unrestricted
flight. Traversal claims cover only the constructed native route fixtures.
Historical paid-contract/asset runs remain separate supporting evidence.

## Replay commands

Use short run names for Windows asset-path limits. The runner copies a player
seed and stages a helper; it does not edit the player's save or installed mod.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -FixtureSource scripts/qc/anisetron-glide `
  -FixtureOptions scripts/qc/anisetron-glide/qualification-options.lua `
  -RuntimeTicks 3600 -RunName glide-qualify -Fidelity off
python -B scripts/qc/anisetron-glide/analyze.py `
  --report .factorio-qc/anisetron/glide-qualify/script-output/anisetron-qc.json `
  --output output/meshy/anisetron/reference17/ten-leg-trial/qualification.json
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -RunName glide-native -Fidelity standard -TenLegTrial
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -FixtureSource scripts/qc/anisetron-mobility -RuntimeTicks 12000 `
  -RunName glide-mobility -Fidelity standard -TenLegTrial
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -Resume -SaveInput .factorio-qc/anisetron/glide-before-four-save/saves/anisetron-transition.zip `
  -RunName glide-upgrade3 -Fidelity off -TenLegTrial
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -Save -RunName glide-save -Fidelity standard -TenLegTrial
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -Resume -SaveInput .factorio-qc/anisetron/glide-save/saves/anisetron-transition.zip `
  -RunName glide-reload -Fidelity standard -TenLegTrial
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -Regression -Visual -RunName glide-track3 -Fidelity standard -TenLegTrial
python -B scripts/qc/anisetron-glide/measure_motion.py `
  --source .factorio-qc/anisetron/glide-track3/script-output `
  --bundle output/meshy/anisetron/reference17/prepared-v2/full128 `
  --output output/meshy/anisetron/reference17/ten-leg-trial/motion-alignment.json
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -DumpOnly -RunName glide-data -TenLegTrial
python -B scripts/qc/anisetron/inspect_data.py `
  --dump .factorio-qc/anisetron/glide-data/script-output/data-raw-dump.json --expected-legs 10 `
  --output output/meshy/anisetron/reference17/ten-leg-trial/final-data.json
python -B scripts/qc/anisetron/inspect_final_extras.py `
  --dump .factorio-qc/anisetron/glide-data/script-output/data-raw-dump.json `
  --output output/meshy/anisetron/reference17/ten-leg-trial/final-art-data.json
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -RunName glide-retained -Fidelity standard
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -Resume -SaveInput .factorio-qc/anisetron/glide-save/saves/anisetron-transition.zip `
  -RunName glide-restore -Fidelity standard
powershell -ExecutionPolicy Bypass -File scripts/invoke-anisetron-qc.ps1 `
  -DumpOnly -RunName glide-finaldata
python -B scripts/qc/anisetron/inspect_data.py `
  --dump .factorio-qc/anisetron/glide-finaldata/script-output/data-raw-dump.json `
  --output output/meshy/anisetron/reference17/ten-leg-trial/shipping-final-data.json
python -B scripts/qc/anisetron/inspect_final_extras.py `
  --dump .factorio-qc/anisetron/glide-finaldata/script-output/data-raw-dump.json `
  --output output/meshy/anisetron/reference17/ten-leg-trial/shipping-final-art-data.json
python -B .codex/skills/esir-conceptual-blueprints/scripts/blueprint_audit.py --repo-root . --format markdown
$env:PYTHONPYCACHEPREFIX=Join-Path $env:TEMP 'epc'
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task preflight -AsJson
```

Intermediates and validation reports stay ignored. Redundant copied mod folders
from this trial were removed after path/link verification; reports, trace chunks,
captures and transition saves are retained. `redundant-staging-cleanup.json`
records that scope. Failed long-path/disk-pressure capture attempts are not
accepted visual evidence. Git commit and push remain outside this pass.
