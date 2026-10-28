# Approved native 2.1 quality changes

The user approved finer native module precision and native quality scaling
for all ESIR locomotives and wagons. Authored normal-quality base values,
module penalties and fuel bonuses remain unchanged. This table enumerates
every effective module value differing after probability-unit normalization.

| Module | Quality | Effect | 2.0.77 | 2.1.23 |
|---|---|---|---:|---:|
| `productivity-module` | uncommon | productivity | 3% | 3.9% |
| `productivity-module` | rare | productivity | 4% | 4.8% |
| `productivity-module` | epic | productivity | 5% | 5.7% |
| `productivity-module` | legendary | productivity | 7% | 7.5% |
| `productivity-module-2` | uncommon | productivity | 6% | 6.5% |
| `productivity-module-2` | epic | productivity | 9% | 9.5% |
| `productivity-module-2` | legendary | productivity | 12% | 12.5% |
| `productivity-module-3` | uncommon | productivity | 9% | 9.1% |
| `productivity-module-3` | rare | productivity | 11% | 11.2% |
| `productivity-module-3` | epic | productivity | 13% | 13.3% |
| `productivity-module-3` | legendary | productivity | 17% | 17.5% |
| `ei-productivity-module-5` | uncommon | productivity | 16% | 16.9% |
| `ei-productivity-module-5` | rare | productivity | 20% | 20.8% |
| `ei-productivity-module-5` | epic | productivity | 24% | 24.7% |
| `ei-productivity-module-5` | legendary | productivity | 32% | 32.5% |
| `ei-productivity-module-6` | uncommon | productivity | 20% | 20.8% |
| `ei-productivity-module-6` | rare | productivity | 25% | 25.6% |
| `ei-productivity-module-6` | epic | productivity | 30% | 30.4% |
| `quality-module-2` | uncommon | quality | 5.8% | 5.85% |
| `quality-module-2` | epic | quality | 8.5% | 8.55% |
| `quality-module-2` | legendary | quality | 11.2% | 11.25% |

Native verification covers all 22 shared modules at all five playable qualities
and 110 actual assembler/module combinations. Eighteen productivity changes
are also measured through native machine bonuses. The other three entries
are tier-2 quality-effect precision. All normal-quality values and every
speed/consumption/pollution bonus match after the documented probability-unit
conversion. The original 48,000-craft conservation suite remains a separate
probability/productivity/quality test, not evidence for every table row.

Locomotive power follows native factors 1 / 1.2 / 1.4 / 1.6 / 2.
Every ESIR locomotive, including its placement body, inherits the native
speed flag: ceilings scale by 1 / 1.03 / 1.06 / 1.09 / 1.15.
Five actual locomotives at normal/rare/legendary quality pass native
automatic travel and station-braking checks. All normal-quality sampled
speeds and positions match 2.0 exactly; stronger quality behavior is approved.

## Cargo slots

| Wagon | Normal | Uncommon | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|---:|
| `ei-steam-basic-wagon` | 20 | 25 | 30 | 35 | 50 |
| `ei-steam-advanced-wagon` | 30 | 37 | 45 | 52 | 75 |
| `cargo-wagon` | 40 | 50 | 60 | 70 | 100 |
| `ei-advanced-cargo-wagon` | 50 | 62 | 75 | 87 | 125 |
| `ei_em-cargo-wagon` | 60 | 75 | 90 | 105 | 150 |

## Fluid capacity

| Wagon | Normal | Uncommon | Rare | Epic | Legendary |
|---|---:|---:|---:|---:|---:|
| `ei-steam-advanced-fluid-wagon` | 25000 | 32500 | 40000 | 47500 | 62500 |
| `ei-advanced-fluid-wagon` | 75000 | 97500 | 120000 | 142500 | 187500 |
| `fluid-wagon` | 50000 | 65000 | 80000 | 95000 | 125000 |
| `ei_em-fluid-wagon` | 100000 | 130000 | 160000 | 190000 | 250000 |

## Evidence and boundaries

- Baseline report: `.factorio-qc\ql20\accepted-01.fixture.json`; SHA-256 `7fef731f64a4ee795d65cebf3debd587e1bfd45a2a4f3ec5c3a211c4d5e3aace`.
- Accepted report: `.factorio-qc\ql21\accepted-01.fixture.json`; SHA-256 `a3ea8ccd978ed9544f9d49155cc057a002c011c81e079aa952aea2d8347d46d5`.
- Full comparison: `.factorio-qc\managed\0422e48554e14570806ee8e7c009f9a8\audit\quality-native-accepted.json`.
- Native values and scripted automatic travel are checked; physical driving
  feel, rendered wheel alignment and a whole-factory throughput comparison
  are separate evidence classes.
- Prototype and item identities remain unchanged. Existing higher-quality
  wagons gain capacity; no item or fluid removal is required.
- No production polling, surrogate module identities or rounding emulation
  was added. Balancing these approved native bonuses is deferred.
