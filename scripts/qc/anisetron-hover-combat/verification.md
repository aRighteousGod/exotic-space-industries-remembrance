# ANISETRON hover, damage and chromatic-light verification

Fresh worktree verification on 2026-10-06 used installed Factorio **2.0.77,
build 84539**, its matching runtime/prototype documentation, and the current
dependency seed. No Git commit or push was made.

## Reproduced movement defect

The previous safeguard retired healthy vehicles and depended on a later damage
event to notice new stickers. Native sticker attachment has no event of its own
and does not necessarily deal damage. An eleven-type silent stack reproduced
**1,167 consecutive stopped ticks (19.45 seconds)**. The same stack with an
explicit damage event remained mobile, isolating the admission gap.

Keeping exact lifecycle registrations and checking native modifiers every four
ticks removed the reproduced stop: **zero stationary ticks** under both damaging
and silent stacks. The original clear-lane mean displacement was unchanged
at 0.175435267857 tiles/tick in this matched fixture. Damage admission can bring
service forward to the next tick. Sixty-four compensation tiers cover the
installed positive-multiplier combinations; no enemy sticker or damage effect
is removed. Four native hidden legs, their response, hover and bob remain intact.

The current powered-grid fixture also measured 0.5983903104 tiles/tick versus
0.1754142198 without equipment before attack. Its eight exoskeletons are supplied
throughout the test, not merely charged initially. Silent attack again produced
zero stopped ticks, followed by recovery. These are fixture measurements, not a
universal claim about arbitrary third-party zero-speed stuns or movement caps.

Before/after reports and the original mobility source are retained under:

- `.factorio-qc/anisetron/hover-before/`
- `.factorio-qc/anisetron/hover-after/`
- `.factorio-qc/anisetron/hover-combat-work/mobility-before.lua`

## Damage and research

New native-paid contacts are **320 crown + 160 facade every 12 ticks**. A normal
charge has at most 100 contacts per channel: **2,400 base DPS / 48,000 damage**.
Damage 6 and infinite 7 mirror the Lance's final +0.7 category effects. Research
is read once at native payment and multiplied with ammunition quality.

| Completed laser damage level | Normal combined DPS | Maximum normal charge damage |
| --- | ---: | ---: |
| 5 | 2,400 | 48,000 |
| 6 | 4,080 | 81,600 |
| 7 | 5,760 | 115,200 |
| 8 | 7,440 | 148,800 |

Real lab completion during a burst preserved the paid snapshot; the next native
charge acquired the new modifier. Scripted research states and infinite levels
also produced the expected native category effects. A deliberately staged old
category save restored its already-completed research on current prototypes,
without repricing its active contracts. Genuine historical v1 and rare-v2 saves
retained their original damage, payment, deadlines and native vehicle state.

An initial migration assertion expected an arbitrary script-set bullet bonus
to survive configuration loading. Factorio's native technology reconciliation
reset it, independently of ANISETRON. The corrected fixture observes that result
and tests the custom bonus across ANISETRON's own in-session rebuild instead;
that check passes. No production force-reset or generic modifier-restoration
code was added. See the installed 2.0.77 migration documentation for the engine
configuration boundary.

## Current engine results

All paths below are under `.factorio-qc/anisetron/`; each report is
`script-output/anisetron-qc.json` unless stated otherwise.

| Run | Result | Coverage |
| --- | --- | --- |
| `hover-native2` | 149/149 | Native payment, manual/automatic controls, logistics/real robots, lifecycle, movement, visuals and sound ownership |
| `hover-off` | 141/141 | Native behavior with decoration disabled |
| `hover-lean`, `hover-cinematic`, `hover-maximal`, `hover-unbounded` | 149/149 each | Remaining fidelity budgets and native behavior |
| `hover-powered` | 61/61 | Laser 5–8, quality, real lab research, exact packets, silent stacks, powered exoskeletons, recovery |
| `hover-attack` | 28/28 | Sustained real enemies, manual/autopilot/equipment/armed movement, original damage and expiry |
| `hover-tracking` | 47/47 | Target locks, smooth acquisition, continuous beams, diplomacy, removal and movement trails |
| `hover-timing` | 15/15 | Three native charges, 144,000 total base damage, uninterrupted cadence and paid FIFO rebuild |
| `hover-oldburst` | 11/11 | Genuine old rare-v2 save replay, old 38,400 damage contract and native metadata |
| `hover-v1` | 7/7 | Historical facade-only paid FIFO replay |
| `hover-upgrade2` | 79/79 | Old-category research migration, old snapshots, new researched charges and in-session rebuild ownership |
| `hover-glow2` | 38/38 + 12 decoded screenshots | Six daytime/nighttime twin-beam views, including frontal and rear enemies |

`hover-combat-work/fidelity-comparison.json` compares charge counts, per-channel
damage, quality, reserves and target sequences across all six presets. The
mechanical results match exactly.

The fresh `hover-finaldata/script-output/data-raw-dump.json` passes both selective
inspectors. Reports `hover-combat-work/final-data.json` and `final-assets.json`
confirm eight exact prerequisites including laser damage 5, matching +0.7 effects
only on tiers 6/7, no Quantum/Exotic ancestry, correct tooltips, void movement,
four hidden legs, all referenced assets, eight 128-direction sheets and 64 finite
damage-free compensation prototypes. All twelve palette variants retain native
glow/light flags, sustained visible cores and correctly scaled light-mask shifts.

Representative captures:

- `hover-glow2/script-output/anisetron-art/laser-six-night.png`
- `hover-glow2/script-output/anisetron-art/laser-base-day.png`
- `hover-glow2/script-output/anisetron-art/hover-captures.json`

The core retains the Lance's white seam and chromatic ribbons. Random variation
affects its native terrain light, halo and contact light. A saved channel choice
survives heading-driven recreation and paid handoff, avoiding color flicker.
The first contact shares that choice. Original cathedral sheets and icons are
unchanged; this pass produces engine evidence, not replacement model art.

## Repository checks and boundaries

Doctor and conceptual-link audit pass; the latter reports 46 models, 122 owned
sources and zero findings. Preflight's syntax, references, locale, asset paths
and pack-version checks pass. Overall preflight remains blocked by the same two
unrelated existing encoding findings:

- `scripts/qc/singularity-lance/angular-results.json`: suspected mojibake.
- `temp/anisetron-tracking-fix/blueprint-final.json`: UTF-16 encoding.

The initial graphics fixture completed rendering but the generic runner expected
the main fixture's pose filenames. The dedicated capture-validation branch and
the fresh `hover-glow2` run now validate and retain the twelve intended images.
The early rare-damage aggregate assertion was also tightened to the appropriate
native float32 tolerance: less than .01 over a full charge, with exact hit counts.
Earlier failed reports remain available alongside successful reruns.

Disk exhaustion required lossless gzip archival of three older ANISETRON
prototype dumps (`glide-finaldata`, `anisetron-final2`, `final17-data`). Each
decompressed SHA-256 was verified before removing its uncompressed copy. Reports,
saves, source art and the new authoritative dump remain. This pass does not claim
multiplayer or whole-factory performance validation.
