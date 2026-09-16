# Weapon controls verification — 2026-09-15

Engine: installed **Factorio 2.0.77**. The isolated runner copied the input save and mod sources; the player's original save and installed mod directory were not modified. Commands and fixture boundaries are described in [README.md](README.md). Raw reports are retained in the ignored `.factorio-qc/spider-controls-results/` directory.

## Acceptance results

| Run | Runtime checks | Result |
| --- | ---: | --- |
| Required dependencies, scripted cycling enabled | 184 | Pass |
| Required dependencies, scripted cycling disabled | 164 | Pass |
| Enhancements 1.10.8 + Patrols 2.6.4, arachnophobia, scripted enabled | 197 | Pass |
| Enhancements 1.10.8 + Patrols 2.6.4, arachnophobia, scripted disabled | 177 | Pass |
| Initial saved control matrix | 33 | Pass |
| Saved enabled → disabled transition | 45 | Pass |
| Saved disabled → enabled transition | 45 | Pass |

The data-stage fixture verifies **24,388 gameplay configurations**, including native, Hold and compensated rocket bodies. With Enhancements it also checks every corresponding boarding proxy. The representative required and optional loads completed 124,769 and 149,166 data-stage checks respectively, including the existing research, chassis and recipe assertions.

Coverage includes both directions of native cycling stalls and scripted recovery, sustained turns, ordinary battery grouping, all ordinary rocket and Doeworks reload tiers, ammunition range modifiers, close/far target crossings, destroyed targets, empty ammunition, manual gunnery, requested/effective pending state, occupied driver and passenger windows, full cargo, moving vehicles, active logistic deliveries, quality and partially used magazines, cargo merging/restoration, cloning, force changes, research bursts, and native player/robot mining and rebuilding. Actual saved entities retain control preferences and full inventory/equipment/fuel/logistic fingerprints across startup changes; disabled mounts restore their remembered ammunition after loading.

The optional compatibility fixture exercises the Enhancements boarding replacement contract and Patrols waypoint retention. GUI checks construct actual relative widgets and invoke the production handlers through instrumentation confined to the staged copy. Native mouse/keyboard GUI delivery, rendered layout, and the third-party boarding shortcut were not manually exercised.

## Selector cost and acquisition

Each figure is a short headless sample over **220 measured ticks** after registration/setup. LuaProfiler times the ESIR spider updater, excluding native combat, other modules and the helper's acquisition measurements. It includes bounded searches and active ammunition/turn bookkeeping. Vehicles use the fully upgraded assault loadout. The dense combat layout starts them on artillery with both close and farther enemies.

| Vehicles | Situation | Spider updater ms/tick | Mean first-shot latency | Maximum first-shot latency |
| ---: | --- | ---: | ---: | ---: |
| 100 | Idle | 0.31 | — | — |
| 100 | Combat | 2.71 | 57.7 ticks | 92 ticks |
| 500 | Idle | 1.80 | — | — |
| 500 | Combat | 18.53 | 79.6 ticks | 139 ticks |

All scripted vehicles acquired targets. No tick exceeded eight localized searches. The 500-vehicle runs saturate that cap, so actual target-refresh intervals exceed the nominal 15-tick engagement interval. Searches do not truncate the candidate list.

The four matching startup-disabled runs recorded **zero selector searches, zero ammunition samples, and zero spider updater calls during the measured window**. The normal active-work predicate and event-driven replacement/smoke systems remain present. Native combat in this adversarial layout can stall, so these figures are not a comparison of equal native weapon throughput.

Fixed gun/ammunition metadata is cached, candidate properties are shared across slots, and target/diplomacy observations are reused only within a single updater call. These changes reduced the dense 500-vehicle sample from approximately 50 ms/tick during development to 18.53 ms/tick. The final dense case still exceeds a 60-UPS tick budget before other game work; it is a measured performance limit, not a 500-vehicle performance guarantee. Timings depend on hardware and encounter density.

## Native targeting boundary

Factorio exposes selected-gun control but no spider shooting-target setter. A long-range gun can continue aiming at a closer enemy inside its minimum range even when ESIR finds a valid farther enemy. The selector yields a gun that has not fired after the observed shared cooldown plus 30 ticks of acquisition allowance. This prevents that gun from blocking the other groups. Tests also confirm that the far target receives long-range fire after the close target is removed. ESIR does not force a particular native target or create scripted projectiles/damage.

## Static checks

- Preflight: Lua, Python and PowerShell syntax, encoding, requires, locale references/duplicates, assets and pack versions pass. The only warnings are pre-existing incomplete file-map headers in `auric-inoculation-vat.lua` and `emerald-apocalypse-hover-tank.lua`.
- Seven shipped spider locales have identical sets of 79 keys, no duplicate keys and no replacement characters.
- `git diff --check` passes. The working tree retains unrelated existing edits.
