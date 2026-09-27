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

Coverage includes both directions of native cycling stalls and scripted recovery, sustained turns, ordinary battery grouping, all ordinary rocket and artillery rocket reload tiers, ammunition range modifiers, close/far target crossings, destroyed targets, empty ammunition, manual gunnery, requested/effective pending state, occupied driver and passenger windows, full cargo, moving vehicles, active logistic deliveries, quality and partially used magazines, cargo merging/restoration, cloning, force changes, research bursts, and native player/robot mining and rebuilding. Actual saved entities retain control preferences and full inventory/equipment/fuel/logistic fingerprints across startup changes; disabled mounts restore their remembered ammunition after loading.

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

## Overkill prevention — 2026-09-23

The default-off prevention implementation was exercised in installed Factorio **2.0.77**, using the isolated helper and copied saves. Manual in-game verification was intentionally skipped. The original prototype/configuration count remains **24,388**; no prevention-specific vehicle bodies were added.

| Automated run | Checks | Result |
| --- | ---: | --- |
| Prevention combat and lifecycle suite, scripted cycling | 135 | Pass |
| Same suite, startup setting disabled | 91 | Pass |
| Full acceptance with Enhancements/Patrols and arachnophobia, scripted | 208 | Pass |
| Same compatibility stack, native cycling | 188 | Pass |
| Saved preference matrix, initial | 41 | Pass |
| Saved preference matrix, enabled → disabled | 53 | Pass |
| Saved preference matrix, disabled → enabled | 53 | Pass |
| Save made during an effective hold | 1 | Pass |
| Reload that hold and its original expiry bucket | 7 | Pass |

The isolated artillery-rocket pair fired **1 rocket with prevention On versus 10 with it Off**. Both killed the 500-health target. The conservative reservation credited 640 guaranteed explosion damage; the observed hit also included physical damage and dealt 850. This is a reproducible fixture result, not an ammunition-saving percentage promised for arbitrary combat.

Coverage includes both sides of the 120% threshold, all four reserved weapon groups, ordinary rocket quality and force bonuses, resistant targets, repeated small hits, overlapping targets, movement, regeneration, destruction, an empty/last ammunition stack, unsupported late-cloned ammo, switching between near and far targets, manual gunnery, equipment lasers during a hold, cloning and native player mining/rebuilding during a hold. Repeated-hit prediction matched engine damage to within 0.0001; flat resistance is applied per hit using [Factorio's damage formula](https://wiki.factorio.com/Damage), before aggregation. MG and flamethrower alternatives each spent one unsuccessful probe before holding, without reserving their own damage. Deliberately destroyed projectiles recovered through the 300-tick expiry.

The live-save fixture retained a suppressed vehicle, its target reservation and the original expiry deadline. After reloading, it stayed held before that deadline, resumed after expiry and restored the original mixed native targeting flags when disabled. An additional mixed-quality volley verified that ambiguous impacts retain their reservations until the safety expiry, without guessing which damage estimate to remove. Configuration changes instead restore targeting and discard outstanding predictions while preserving the player's preference.

Full acceptance retains the existing cadence, shared-cooldown, inventory, fuel, equipment, logistics, smoke and research checks. It additionally verifies the overkill preference through both occupied mount GUIs, force changes/research bursts, native player and robot mining/building, and the Enhancements/Patrols boarding protocol. Headless GUI tests exercise real widgets and production handlers; they do not provide a rendered visual review or simulate the third-party boarding shortcut.

### Incremental fleet cost

These paired rocket-fleet samples include the spider updater **and launch/impact handler**, over 220 ticks after setup. Native combat, other modules and fixture measurements are excluded. The fleet is indestructible to keep friendly splash from changing the tested population. Durable enemies sustain native fire and reservations; this measures bookkeeping under fire, not the maximum possible benefit from holding lethal volleys.

| Vehicles | Situation | Prevention Off, ms/tick | Prevention On, ms/tick |
| ---: | --- | ---: | ---: |
| 100 | Idle | 0.248 | 0.274 |
| 100 | Combat | 2.350 | 4.520 |
| 500 | Idle | 1.621 | 1.561 |
| 500 | Combat | 13.565 | 22.581 |

Idle differences are sample noise: both idle modes recorded zero reservation monitoring and zero launch observations. Every Off run recorded zero prediction reservations and monitoring. Script events still incur a small dispatch/early-return cost when loaded ammunition fires while the startup setting is enabled. Startup-disabled combat recorded zero selector searches, ammunition samples and prediction work.

All 100 and 500 scripted vehicles acquired targets. Mean/max first-shot latency was **9.52/74 ticks** at 100 vehicles; at 500 it was **13.58/133 Off** and **13.37/132 On**. No tick exceeded the existing eight-search budget. Dense 500-vehicle combat with prevention enabled exceeds the 16.67 ms budget for 60 UPS before native simulation and other mods. These short, hardware-dependent samples are a performance limit, not a fleet-size guarantee.

The seven shipped spider locales now contain **88 matching keys** without duplicate keys or replacement characters. Runtime controls, remote fields, default-off behavior, prediction limits and save semantics are documented in [the controls contract](weapon-controls-plan.md).

Final `qc-fast` completed with exit 0 and no engine errors. Its 69 nonfatal mod-stack warning lines match the prior baseline after timestamp/console-glyph normalization. Final preflight passed syntax, encoding, requires, locale, asset-reference and pack-version checks; only the same two unrelated incomplete module-header warnings remain. `git diff --check` passed.

## Disabled-mode UPS pass — 2026-09-25

Verified in installed Factorio **2.0.77**, without manual in-game inspection. The data-stage observation pass now publishes its exact effect IDs. The shared dispatcher registers those IDs only with range-aware cycling enabled; unrelated effects require no spider prefix searches or spider callback. The damage event uses engine filters for electric damage, spider vehicles, the Emerald Apocalypse hover tank and Hemocrystal Wall, then forwards to the appropriate owners. Reactive smoke remains available with scripted cycling disabled, using cached vehicle/research state and rejecting cooldowns before diplomacy/inventory work.

Future smoke pulses, refit retries and idle selector refreshes no longer wake the spider updater between their deadlines. The existing shared scheduler still owns the queues and due buckets. Disabled mode also skips calls to the selector and overkill update functions when another spider job wakes the updater.

| Automated run | Checks | Result |
| --- | ---: | --- |
| Dispatch and delayed-work fixture, native | 16 | Pass |
| Same fixture, scripted | 16 | Pass |
| Full acceptance with Enhancements/Patrols and arachnophobia, native | 188 | Pass |
| Same compatibility stack, scripted | 208 | Pass |
| Scripted overkill combat/lifecycle suite | 135 | Pass |
| Native combat fleet, 100 vehicles | 5 | Pass |
| Native combat fleet, 500 vehicles | 5 | Pass |

In each dispatch fixture, **1,000 unrelated physical hits produced zero entries into ESIR's damage dispatcher**, and 1,000 electric hits reached only Tesla's damage handler. Two thousand unrelated script effects, including unregistered IDs sharing the spider prefix, produced zero spider callbacks. Wall/tank routing, smoke charge consumption, hostile-only slowing and expiry all passed. A full-cargo refit and future smoke pulse produced no native updater calls during the 54-tick observation gap; the scheduled pulse ran on its exact tick, and the scheduled refit later retained the removed mount's ammunition.

Both native fleet samples recorded **220 scheduler checks, zero updater calls, zero spider damage/effect callbacks, zero searches, zero ammunition samples, and zero prediction work** over the 220-tick measurement window. The profiler now includes the work predicate as well as the updater and observation handler; earlier tables excluded the predicate. The 100-vehicle sample spent 0.984300 ms total in the instrumented predicate (approximately **0.0045 ms/tick**); the 500-vehicle sample spent 1.890300 ms total (approximately **0.009 ms/tick**). Timings are hardware-dependent and include measurement overhead. Native combat and other modules are excluded; native mixed-range stalls remain, so this is not an equal-throughput comparison against scripted mode.

Every fixture loaded the final data-stage stack and retained the **24,388** gameplay configurations. Preflight passed syntax, encoding, requires, locale, asset references and pack versions, with only the same two existing module-header warnings. All seven spider locales retain 88 matching keys. Whitespace checks passed. Raw reports are staged as `.factorio-qc/spider-ups-*.txt`; reproduce dispatch checks with `-Dispatch` and fleet checks with `-NativeCycling -PerformanceVehicles 100` or `500`, plus `-PerformanceCombat -RocketPerformance`.
