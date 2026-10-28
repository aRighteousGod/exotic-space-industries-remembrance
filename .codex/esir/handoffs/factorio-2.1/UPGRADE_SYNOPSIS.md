# ESIR 1.4.0 — Factorio 2.1.23 upgrade synopsis

Status: local core release accepted for Factorio 2.1.23, 2026-10-28.
Publication is owned by the user. Optional migration exclusions and evidence
limits below remain explicit. Machine-readable reconciliation is in
[RELEASE_RECONCILIATION.json](RELEASE_RECONCILIATION.json).

## Release contract and preservation

The approved target is Factorio 2.1.23 and ESIR 1.4.0 under the existing identity.
ESIR 1.3.41 remains the final published 2.0 release. The pending steam-machine
working-light fixes are part of this upgrade. Authored balance is preserved except
for the approved crystal conservation correction and documented native 2.1 changes.
The user subsequently approved native 2.1 module-effect precision, native quality
scaling for every ESIR locomotive and wagon tier, native silo quality speedups with
phase-aligned pollution/plumes, native recipe buffers while Quality is enabled,
and native discovery-gated personal rocket travel.
These are intentional exceptions to numerical parity, with authored recipe costs,
yields and normal-quality vehicle values retained. The user owns publication;
no upload or credential work remains assigned to this implementation.
The user also accepted native truncation of fluid above a legacy pipe segment's
nominal capacity during 2.1 migration; no save-preparation step is required for it.

Protected run: `.factorio-qc/managed/0422e48554e14570806ee8e7c009f9a8`.
Its `baseline/` contains the original binary Git diff, HEAD, worktree status,
260 changed/untracked files with SHA-256 hashes, 77 selected 2.0 mod archives
(including ESIR 1.3.41), exact dependency lock, installed mod list and settings,
and four donor saves (`ass`, autosaves 6, 7 and 8). No enabled 2.0 dependency
was missing from the preservation selection. Baseline size: 2,799,005,154 bytes.
Those baseline packages and saves remain preserved. The user's subsequent request
authorized installing the accepted 2.1 packages into the real mod folder. That
separate deployment preserves the original configuration and replaced archives;
existing user saves remain untouched. See [LIVE_INSTALLATION.md](LIVE_INSTALLATION.md).

## Evidence rules

Each system below must acquire concrete before/after behavior, owners, migration
effects and evidence before acceptance. Static checks, engine loads, native
interaction, multiplayer, performance and audio listening are separate evidence
classes. A successful startup does not close the API ledger. Unsupported optional
content saves retain their preserved 2.0 installation.

## System ledger

| System | Approved change / preservation contract | Implementation and evidence |
|---|---|---|
| API tooling | Exact 2.1.23 default, explicit 2.0.77 historical access, no flat 2.1.15 fallback; read-only queries and explicit refresh | Versioned wrapper/cache and Lua assumptions updated. Full official executable build 87750 verified. Core and vanilla helper skills resurveyed. All 1,757 API rows structurally classified; semantic/native gates remain separate. Ordinary development context now selects the pinned engine, 23-archive core seed and clean live NSBC overlay. Historical 2.0 source staging remains explicitly selectable and mismatched current source is rejected. |
| Recipes and categories | Array categories, correct machine/handcraft membership, removal of obsolete union categories without yield changes | 11 ESIR category identities preserve 117 recipe routes. Final-data comparison records zero eligibility gains/losses across 2,834 shared recipes and 97 machines/character prototypes. Native tool/item/mixed research and 48,000 crystal crafts pass; a full progression playthrough remains outside that evidence. |
| Crystal conservation | 24 return recipes: 22 at 98/2, uranium 90/10, neodymium/morphium 92/8; complementary shared ranges and productivity-excluded returns | Source/final-data contract and 48,000 native crafts passed, including productivity stress, quality, blocked outputs, real mid-craft save/reload and a second reload. Science consumes two and returns one at 98/2; other 23 consume/return one. Full recipe enumeration and evidence below. |
| Other products and freshness | Independent unrelated byproducts; preserve metadata, freshness, catalyst and productivity intent; Gaia/relic crystal resource drops remain independent | Product and loot fields converted; both pentapod-egg outputs retain freshness reset. Paired engine probe confirms identical spoil lifetimes at every quality for all 18 shared spoiling items. |
| Vanilla recipes | Ore-melting recipe renames; molten-fluid identities retained | Recipe references renamed; molten-fluid identities retained. Piercing-shotgun output explicitly remains one and ESIR acid-neutralisation remains five seconds, preventing inherited native batch-size changes. |
| Science and progression | ESIR packs remain tools; vanilla science items participate in lab and technology logic; researched state retained; native 2.1 personal-travel gate approved | Discovery/lab helpers support both kinds; all 10 shared tool/science prototypes retain recorded values. Personal rocket travel unlocks with the first Vulcanus, Gleba or Fulgora discovery; Rocket silo alone grants platform creation. Migration adopts travel effects from already-researched discoveries. Native tool/item/mixed lab consumption and normal research completion pass. Core24 finds all 788 enabled technologies reachable through prerequisites and complete science sets accepted by a real lab. Manufacturing/bootstrap and full playthrough remain separate. |
| Quality and recycling | Explicit Quality and Recycler requirements; Recycler imports/assets; quality effects 0.03/0.045/0.06 | Quality effects use 0.03/0.045/0.06. All 1,326 shared recyclers retain economic outputs and duration, and populated research migration/reload passes. The user approved finer native precision: all 21 changed module values are enumerated in QUALITY_NATIVE_CHANGES.md; 22 modules and 110 native machine cases verified. |
| Fuels and ash | Array fuel categories, same membership, ash policy and bonuses | Array membership and Ash-fork bridge preserve the recorded burnt results of 1,177 shared items. Loaded solid/fluid power, flamethrower custody and vehicle/train suites exercise native admitted fuel paths. Fuel categories and authored acceleration/top-speed bonuses remain unchanged. |
| Fluid systems | Direct fluid APIs with segment/private-buffer distinctions, temperature/capacity/filter fidelity and rollback | Approved native Quality buffers: ordinary input floor grows from two batches to four and output floor from two to three; legacy sizing runs only without Quality. All 24 native capacity cases and reload pass. Locked railgun helper retains 30 cold/60 hot, with input amount 15. Native fluid-safety, auric, fusion, turbine, flamethrower rollback and railgun suites pass within the detailed scopes below. |
| Runtime controls | Disabled-by-script state, writable minable flag, inventory constants and helpers profiler | Qualified API ports plus focused native ownership, disable/mining state, circuits, replacement rollback, actual 2.0 migration and second-reload receipts are detailed below. Core ZIP smoke is supplemental; it is not the sole evidence. |
| Machinery and presentation | Generator pictures, robot doors, circuit graphics, steam working lights and simulations | Generator/container/turret definitions ported; seven retained 2.0 art sheets preserve authored animation shapes. All 28 native scene captures and 16 working dry/wet four-direction custom-drill rigs were inspected. Steam glow has separate 40-case native and 30-image evidence. Audible playback remains unverified. |
| Heat | Consumer temperatures and neighbour topology; preserve output and adjacency policy | Both heater topologies use four edge-midpoint neighbours and own matching category; 0.25 bonus and authored thermal values retained. Paired native 2.0/2.1 tests pass fuel use, bonus and steady heat rise for 16 layouts. Twelve solar boundary cases retain consumption and heat at/above 10 C over 6,000 ticks; colder fluid remains unconsumed, with a native storage distinction documented below. |
| Combustion power | Preserve the solid/fluid mode contract, fuel custody, protection flags, helper ownership and console access | Replacement creation now precedes source removal, preserving the original on failure. State flags transfer on success. Native mode/actor checks and populated migration/reload pass; a stale prior-window close is now ignored when another turbine owns the console. Native overflow truncation is an explicitly accepted migration limit. Fifty loaded generator cases pass 300 checks in 2.1; the rare solid burner's native 2.0 shortfall disappears without an authored balance change. Multiplayer remains separate. |
| Steam and large-turbine output | Retain native electrical delivery, temperatures, fluid consumption and quality scaling | Paired isolated networks retain 0.9/5.82/400 MW normal and 1.44/9.312/640 MW rare nominal output, including quarter/full/excess demand, idle and script-disabled states. Measured output and fluid use match 2.0 exactly, including fixed-point rounding. This verifies the turbine consumer, not the scripted fusion reactor or complete coolant-production loop. |
| Vehicles | Braking/friction fields with correct value semantics; preserve handling/state | Five native locomotive tiers and all cargo/fluid wagon tiers now inherit the user-approved 2.1 quality flags. All normal-quality rail traces match 2.0; higher-quality bonuses and all capacities are tabulated. Car/tank traces match; a small native hover displacement distinction is documented. Spider progression, migration/reload and bounded performance comparisons pass. |
| Asteroids and platforms | Damage per HP 0/3/5/12/50; preserve identities, health, resistance, loot and curves | Definitions and embedded generation ported. Eight inherited crushing/reprocessing/hidden uranium probability changes are explicitly restored to the 2.0 independent outcomes. Core22 comparison leaves exactly the 24 approved crystal-return changes among shared non-recycling recipe products/timings. |
| Planets and ecology | Soundtracks/surface properties; robot energy; external Terrain Evolution conflicts | Both conflicts pass native resolver rejection using identity-only stubs. Populated 2.0 donors preserve terrain, legacy noise overrides and ecology preferences, clear the stale external flag and retain selected ecology. Custom Gaia at pressure 800/gravity 12 retains robot cost 1.5 through migration/reload; canonical default remains 0.96875. Dedicated resource/nest, surface evacuation/reforge and connected admin suites pass within the documented bounds. |
| Enemy generation | Preserve existing surface seed expressions/overrides; version native generation per surface | 774 generation cases and dense legacy-noise/terrain parity reviewed; actual migration/reload preserves 97 nests and 32,768 tiles. Reforge and revision retention pass. The connected-client enemy/Administration suite passes 670 assertions, including evacuation, ecology preferences and stale GUI targets. Native future nest-placement differences remain documented. |
| Travel, GUI and persistent state | Physical travel/remote view, circuits, blueprint orientation, settings and GUI preferences | Physical gate transport/remote-view and save/reload pass. Fusion controls render and function at 100/125 percent scale; induction circuits, alert preferences, enemy/admin GUI and populated legacy progression checks pass. Orbital connected-client controls and reload pass; corrected bound launch call delivers 422 items through two real uplinks. |
| Rocket launch emissions and plumes | Native silo quality speedups; keep configured pollution totals and align effects to actual phases | All five qualities retain native modifiers 0.2/0.45/0.15. Emissions begin at ignition, plume begins 239 ticks after clamp release. 45 cases / 374,714 checks, 24 inspected native frames, in-flight reload, real 2.0 ignition/ascent migration and second reload pass. |
| Beacons | Adopt NSBC with preserved state/orientation/source UI/guarded rotation; two ESIR replacement families and overload behavior | NSBC core replacement, eight custody handoffs, overload 4 → 5 → 4, 128 blueprint transforms, guarded native/editor rotation, source panels, robot/platform construction, six ruined repairs and legacy migration/reload pass. Whole-world ownership finds 131 sources/262 helpers and zero orphans. Real peer disconnect/rejoin and the rebuilt NSBC ZIP also pass. |
| Working audio | Preserve ESIR's authored working-sound envelope while porting soundtrack bindings | A final data pass copies ESIR sound tables and makes omitted fades explicitly 0/0, retaining authored overrides and progress-matched audio. Native core23 audit covers 26,253 shared working sounds and reports zero ESIR fade differences. No audio-listening claim. |
| Cross-mod integration | Selected required forks, optional dispositions, overlap/daylight ownership and asset/remote/settings updates | 23 verified required/transitive ZIPs load with the core. Air Scrubber/Ash fixes and all 50 optional dispositions are recorded. Twelve optional roots pass a combined 48-archive final-ZIP smoke. K2 is deferred by user choice, with no ammonia-temperature exception; optional progression/save migration remains unaccepted unless separately stated. |
| Documentation and locale | Conceptual models, source comments and all eight locales | Conceptual owners and source comments are reconciled for implemented changes. Ecology incompatibility and new train quality guidance cover all eight locales while preserving existing prose. Current syntax, keys, duplicates, requires, headers and blueprint checks pass. Historical test-log encoding and independent native-language certification are explicitly separate. |
| Packaging and release | Own continuations, six graphics/two soundtracks, main; actual ZIP tests/publication | All 12 current candidate ZIPs passed a combined 35-archive exact-engine load, fresh save, 600 ticks and final-data crystal audit. Rebuilt main 1.4.0 includes the approved transport-quality policy and all eight locales; final ZIP data verifies every ESIR locomotive/cargo/fluid quality flag. Media are 1.1.0 and continuations 1.0.0. Nothing published. |

## Current engine evidence

### Vehicle module performance comparison

The retained `spider-native-21/performance-replay-matrix.json` records twelve
successful cases (six per engine), with five functional/budget assertions per
case. Each native benchmark runs alone and measures the existing spider module
for 220 ticks after setup. Every case retains its own selector/search profiler
text, source manifest, save hash and runtime report. The earlier matrix overwrote
shared profiler filenames; it remains functional evidence, while these separately
retained replay files supply the timing comparison.

| Population and mode | 2.0.77 module total, ms | 2.1.23 module total, ms |
| --- | ---: | ---: |
| 100 smart, idle | 53.3676 | 62.8375 |
| 100 smart, combat | 602.8873 | 637.6893 |
| 500 smart, idle | 365.4928 | 367.9805 |
| 500 smart, combat | 3224.4438 | 3275.6113 |
| 500 native, idle | 0.6857 | 0.7422 |
| 500 native, combat | 1.0061 | 0.8220 |

These are single-run module timings, including the established instrumented
dispatch/update/effect callbacks, not whole-map UPS or a statistically established
speed change. The 500-smart combat difference is +1.59%; the 100-smart idle
difference is +17.74% but only +9.47 ms over the entire 220-tick window. Native mode
performs zero selector searches on both engines. Smart mode retains its eight
searches-per-tick cap, and combat acquisition assertions pass. No vehicle balance
or scheduler settings were changed in response to these measurements.

### Retained core runs

All paths below are inside the protected run named above. Logs and compact
inventories are retained evidence, not portable claims about other configurations.

- `baseline-engine/compact`: exact 2.0.77, published ESIR 1.3.41 and preserved
  77-package selection. Native merged-data dump passed.
- `core/full-core-17.*`: first full 2.1.23 core data load passed, prototype
  checksum 3035121798. `core/create-01.*` and `core/fresh.zip`: fresh save passed.
- `core/runtime-smoke-01.*`: 600 ticks passed; 232.567 ms total, 0.388 ms average.
  This empty-map smoke is not representative performance acceptance.
- `core/full-core-20.*` and `core/compact-20`: recycling/ash source load passed;
  prototype checksum 1497307943, compact inventory SHA-256
  `07888846a73df3f4dc4ad8d345ef229fc53be30443b6c8bb8d690cfa004da6d5`.
- `core/full-core-21.*`: routing and buffer source load passed; prototype
  checksum 1713173879. The category comparison covers 2,834 shared recipes and
  97 shared machines, including the character; it does not prove native crafts.
- `core/full-core-22.*`, `core/compact-22`, `audit/core22-parity.json`: complete
  source load passed. Compact inventory SHA-256
  `c0ee38f0006b11cd6d7bc6c8f4eeabd902957ec74c0b85e6916ea8832de6092e`.
  Zero category eligibility, recycling economics/timing or ash-result changes;
  the 24 intended crystal recipe product differences are the only remaining
  normalized shared non-recycling recipe product/timing differences.
- `native-probe-20` / `native-probe-21`, `audit/spoil-parity.json`: real engine
  `get_spoil_ticks` values match for all 18 shared spoiling items at every quality.
- `core/full-core-23.*`, `core/compact-23`, `audit/core23-parity.json`: final
  sound-defaults source loads successfully; the compact recipe/economy inventory
  remains identical to core22. `audit/sound-defaults-23/comparison.json` compares
  effective 2.0/2.1 fades: 26,253 shared working sounds, zero ESIR differences.
  The preceding audit found 49,032 ESIR fade differences across 24,516 sounds,
  chiefly generated fleet bodies; those are now explicitly preserved. The 3,131
  remaining differences belong to native/dependency identities, not ESIR-owned
  sounds. This verifies prototype envelopes, not audible playback or listening.
- `core/full-core-24.*`, `core/compact-24`, `audit/core24-parity.json`: latest
  source loads with prototype checksum 1713173879 and compact SHA-256
  `e73aadb60789ea6815ccf4ccc1430ac2bedd88afb70b8e7f8c1acb65bd921641`.
  All 24 crystal contracts pass. The 2,834 shared recipes/97 crafting entities
  still have zero eligibility changes, zero recycling economy/timing changes
  and zero ash-result changes; only the 24 approved crystal product differences
  remain. `audit/core24-progression.json` passes all 788 enabled prerequisite
  routes, science item/tool identities and complete science-set lab coverage.
  This is merged-data evidence, not a science-production bootstrap playthrough.
- `beacon-native/create-01.*`, `runtime-01.*`, `script-output/beacons.json`:
  actual full-core beacon replacements pass without copied ESIR runtime owners
  or disabled overload logic. Eight upgrades/downgrades preserve exact source
  energy including reserve, fuel, burning remainder, fluid amount/temperature,
  orientation and mirroring. Slot counts remain 4/6/8/10; two excess modules are
  returned on each full downgrade. Weighted count 4 is safe, 5 disables the
  receiver with its overload indicator, and downgrade to 4 releases it.
- `audit/reviewed`: pinned-key API review manifests, source hashes and reviewed
  ledger. Source classification is distinct from engine/visual acceptance.

## Crystal conservation and the approved science exception

Before: the two crystal alternatives rolled independently, permitting zero or
two returns. After: adjacent shared ranges cover the full unit interval, each
alternative returns one crystal and has `ignored_by_productivity = 1`, with no
additional independent gate. Existing applicable product metadata is retained.

The user explicitly clarified during implementation that
`ei-alien-computer-age-tech` retains its input of **two** high-energy crystals:
**one is permanently consumed; the other returns at 98% high-energy / 2% ordinary**.
The other 23 recipes consume one and return one. This supersedes the initial
blanket one-return-per-consumed-input wording for that science recipe only.
Gaia excavation and relic-debris resource drops retain independent outcomes.
The final-data enumeration is:

| Recipe | High-energy input | Returned high-energy / ordinary |
|---|---:|---:|
| `ei-alien-computer-age-tech` | 2 | 98% / 2% |
| `ei-alien-resin-growing` | 1 | 98% / 2% |
| `ei-alien-seed-harvesting` | 1 | 98% / 2% |
| `ei-blooming-evolved-alien-seed` | 1 | 98% / 2% |
| `ei-clean-plating` | 1 | 98% / 2% |
| `ei-concentrated-morphium` | 1 | 98% / 2% |
| `ei-concentrated-morphium-heavy-oil` | 1 | 98% / 2% |
| `ei-concentrated-morphium-kerosene` | 1 | 98% / 2% |
| `ei-concentrated-morphium-light-oil` | 1 | 98% / 2% |
| `ei-concentrated-morphium-lubricant` | 1 | 98% / 2% |
| `ei-copper-extraction` | 1 | 98% / 2% |
| `ei-cryodust` | 1 | 98% / 2% |
| `ei-gold-extraction` | 1 | 98% / 2% |
| `ei-iron-extraction` | 1 | 98% / 2% |
| `ei-lead-extraction` | 1 | 98% / 2% |
| `ei-morphium-fluorite` | 1 | 98% / 2% |
| `ei-neodym-extraction-morphium` | 1 | 92% / 8% |
| `ei-slag-extraction-morphium` | 1 | 98% / 2% |
| `ei-slag-extraction-morphium-crushed` | 1 | 98% / 2% |
| `ei-stone-extraction` | 1 | 98% / 2% |
| `ei-sulfur-extraction` | 1 | 98% / 2% |
| `ei-undilute-morphium` | 1 | 98% / 2% |
| `ei-uranium-extraction` | 1 | 90% / 10% |
| `ei-water` | 1 | 98% / 2% |

`scripts/qc/factorio-2.1/crystal-conservation` tested each actual recipe for
1,000 crafts and an exact-product stress copy with productivity enabled for
another 1,000. Original productivity eligibility was left intact. All 48 cases
passed the per-craft one-return invariant and six-sigma aggregate tolerance:
46,749 high-energy and 1,251 ordinary returns, including 5,897 quality upgrades.
Each case included blocked outputs and a native in-progress checkpoint after
500 crafts. Reload preserved inventories, fluids, progress, bonus progress,
result quality and products finished before completing the remaining crafts.
The completed save then passed another load and 600 ticks.

Evidence: `crystal-native/quality-midpoint.checkpoint.json`,
`crystal-native/quality-completion.checkpoint.json`,
`crystal-native/script-output/crystal-conservation.json`, and
`crystal-native/script-output/crystal-second-reload.json`, with corresponding
server/benchmark logs. The original fixture lacked unlocked quality tiers;
that failed fixture run is retained, and the accepted run starts from a fresh
force with native quality tiers unlocked. This proves native server execution
and persistence, not multiplayer client/rejoin or visible UI acceptance.

## Dependency provenance findings

### Air Scrubber repair acceptance

Before: `air-scrubber` 0.2.9's quality build filter names the mod ID instead of the
`atan-air-scrubber` entity. Its destroy-first handler is unsuitable for repairing
populated existing machines. After: ESIR's central build/clone and configuration
paths normalize nonnormal base identities through guarded native replacement.
The integration also preserves ESIR's existing recipe routes and Ash policy.

Native fixture evidence in `air-native` covers normal-quality no-op, rare
replacement, prefixed-identity idempotence, recipe/result quality, health, progress,
bonus progress, products finished, script/user flags, a real mid-craft reload and
native mining refunds. Both immediate and post-reload cases preserve 11 queued
filters plus the consumed in-progress filter: mining returns 12 filters, five
existing used filters and one rare building, with no ground spill. Evidence:
`midpoint-14.checkpoint.json`, `completion-02.checkpoint.json` and
`script-output/air-scrubber.json`. These are script-built native engine cases;
actual player/robot/platform placement, nested unrelated notifications, changed
optional storage shapes and visible GUI remain separate gates.

Exact energy limit: the rare target keeps its authored smaller native buffer.
A full base buffer of 24,561.185185 J transfers 22,965.690596 J, clamping
1,595.494590 J. The fixture also accounts for 742.777778 J of ordinary passive
drain before the first post-load on-tick callback. This is native target capacity,
not a new ESIR power-cost or buffer-capacity change. The bridge has no tick work.
Owners: `scripts/control/air-scrubber-compat.lua`, central `control.lua`,
`scripts/data-updates/atan-air-scrubber.lua`, and the startup/integration model.
No new public interface, setting or locale key is introduced.

The requested author-facing message is saved in `AIR_SCRUBBER_PORTAL_MESSAGE.md`.
It has not been posted externally.

### Populated core migration evidence

`migration-native-20/donor-stage.json` pins the required original core: 35
preserved archives and four built-ins, actual Factorio 2.0.77 and ESIR 1.3.41.
The fixture uses a private main source copy solely to seed/inspect ESIR-owned
storage. Historical saves containing unsupported optional content are untouched.
`migration-native-21/target-stage.json` records the tested 2.1 source hashes.

The native engine applies Space Age's migrations and ESIR `1.4.0.lua`, saves the
adopted game, loads it again, writes a second save, then loads that save for
600 ticks. Receipts: `migration-native-20/donor-01.checkpoint.json`,
`migration-native-21/adoption-01.checkpoint.json`,
`migration-native-21/second-reload-01.checkpoint.json`, their script-output
snapshots, and `migration-native-21/final-reload.factorio.log`.

Preserved exact values include 123 normal iron plates, 17 rare energy crystals,
1,234 water at 87 degrees, three remaining iron plates in a paused rare assembler,
the selected recipe and normal recipe quality, craft progress 1/15, bonus progress
0.375, zero completed products, health 448, mining protection and disabled state,
researched recycling, the authored grass tile and ecology overrides. The stale
external flag clears; the selected enabled ecology state resumes. Gaia pressure
800/gravity 12 remains unchanged and maps to robot energy usage 1.5.

The second saved 2.1 checkpoint is SHA-256
`405e2094841393d8bc24e8b7cbe24faf43296ccf56f52c4640e15237f74a1f8a`.
This closes a focused real engine migration/persistence case. Player inventories,
circuits, blueprint data, GUI preferences, broader surfaces and optional
configurations still require their own populated cases. Beacon custody is covered
by the separate extended donor below.

### Extended legacy-beacon and progression migration

The second actual 2.0.77/ESIR 1.3.41 donor includes rare Copper and Alien beacons
with four rare speed modules each. It preserves the exact old runtime snapshot:
77 nitrogen at 43 degrees in Copper, ten queued rare bio-matter in Alien, zero
stored/burning energy, direction/mirroring, quality, disabled state and both valid
source/manager pairs. The original library is replaced by NSBC during native
configuration change. The original production, inventory, fluid and ecology
assertions above also pass in this donor. This is a dormant-fuel migration case;
live burning/replacement custody has separate native beacon evidence.

The user subsequently selected native 2.1 travel progression. Rocket silo retains
platform creation, while personal travel remains locked until a Vulcanus, Gleba
or Fulgora discovery is researched. `migrations/1.4.0.lua` adopts travel effects
from already-researched technologies, including compatible mods' grants; Rocket
silo alone has no such effect. This intentionally supersedes the earlier
unreleased preservation override and its positive Rocket-silo-only assertion.
No player save had loaded 1.4.0, so no migration for that interim build is added.
Research costs, recipes and science requirements are unchanged. Native built-in
effect localisation supplies all eight locales; there is no new setting or remote API.
Owners: `scripts/data-updates/vanilla-updates/techs.lua`, `migrations/1.4.0.lua`,
the research/progression conceptual model and changelog. The new logistic-network
flag is already migrated by the engine and passes the same assertions.

Evidence: `migration-beacon-20/donor-01.checkpoint.json`,
`migration-beacon-21/adoption-02.checkpoint.json`,
`migration-beacon-21/second-reload-01.checkpoint.json` and their script-output
snapshots. The first adoption failure is retained as evidence of the travel gap.
The accepted second save is SHA-256
`1792b80c9c9dcaea5a1830580504294b0e8eb49eae8295cf02aa4dfca3136f1f`.
The first adoption receipt's old generic limit string says no beacon claim;
its actual before/after beacon assertions and the corrected second-reload fixture
establish the narrow populated-beacon case described here.

### Native beacon interaction and construction actors

`beacon-client` uses a hidden native graphical client with an isolated profile,
private adapters and real engine interaction APIs. The combined player03/player04
run covers 128 exported/imported blueprint rotation/mirror combinations, ghost
revival and placement over existing beacons; four populated player replacement
round trips; incompatible replacement refusal; normal, remote-view and editor
rotation; permission, open-GUI and held-blueprint guards; and settings paste.
Source panels were opened without a hover selection, depleted/refuelled and
reopened, and followed replacement. Rendered Copper and Alien source panels were
inspected. This is native API interaction and rendered evidence, not physical
mouse-input or audio-listening evidence.

`beacon-client/player04.receipt.json` records acceptance. The accepted autosave
SHA-256 is `956f141109f5d979be4248db5a3578d603316551942f0a28e70678fa131f81c9`.
`reload01.receipt.json` and `script-output/beacon-client-reload.json` confirm stable
valid source/manager identities for all 131 fixture beacon records after reload.
This identity check does not substitute for a comprehensive orphan scan.

`beacon-actors/script-output/beacon-actors-complete.json` and its native runtime
log cover actual construction-robot and space-platform upgrades. Four rare modules,
rare quality, 77 nitrogen at 43 degrees, paused source state and orientation survive;
the replacement item is consumed and the old item refunded. Six ruin cases (three
ruin variants at normal and legendary quality) pass 115 repair assertions,
including one repair-kit consumption, force/position/quality preservation, one
build notification, attached helpers, fuel/module ownership and helper cleanup.

### Paired heat and native fluid safety

`audit/heat-parity-final.json` compares actual 2.0.77 and 2.1.23 at ticks 60 and
120 for both burner and fluid heaters: isolated, each cardinal neighbour,
diagonal, four neighbours and mixed families. All 16 layouts retain neighbour
bonuses (0, 0.25 or 1), source energy, remaining solid fuel and total physical
fluid consumption. The fixture normalizes old private buffers plus external
segments against 2.1 shared segments; comparing only the API's local-fluid view
would incorrectly report lost fuel. Input light-oil remains 1 MJ per unit.

Isolated heaters reach 33 and 46 degrees from 20 in both engines. Matching cardinal
neighbours have a fixed +0.0541667-degree offset in 2.1; the four-neighbour centre
has +0.0866667. The 60-to-120-tick rise matches within 0.000001 degree. This is
consistent with earlier native neighbour-bonus application at startup; it is not
evidence of a changed steady heat rate. Authored consumption 1,300 kW, effectivity
1.25, specific heat 100 kJ and bonus 0.25 remain. Loaded heat-to-electric networks
and multiplayer are separate gates.

The solar tower keeps its 10 C consumer floor. The removed fluid-box field moves
to `FluidEnergySource.minimum_input_temperature`; energy-conversion limits are
unchanged. `solar-boundary-20/native-02.*` and `solar-boundary-21/native-02.*`
pass 36 assertions each across twelve cases: 9/10/11 C solar fluid, initial tower
temperatures 20/900 C, isolated and heat-pipe-connected layouts, sampled at
60/600/6,000 ticks. `audit/solar-boundary-parity.json` records exactly equal tower
and pipe temperatures and energy in every sample. At/above 10 C, fluid consumption
also matches exactly. For an isolated 20 C tower after 6,000 ticks, 10 C fluid
reaches 419.9996185 C and 11 C fluid reaches 459.9995804 C, each consuming
99.9999046 units.

There is an observable native storage distinction below the threshold: 2.0 rejects
the injected 9 C fluid, while 2.1 retains all 100 units without consuming any.
No scripted deletion is introduced to mimic the old rejection. The fixture uses
the unchanged tower prototype and bypasses mirror supply only to control its
hidden fluid temperature. It does not prove mirror tracking, rendered beams,
electric network output, audio, migration or multiplayer behavior. No recipe,
setting, locale, public interface or authored power value changes for this test.

`fluid-native/native-01.receipt.json` and
`fluid-native/script-output/fluid-safety-native.json` pass 52 native assertions
against the actual fluid-safety owner: ordinary contents survive stale segment
membership; stale phase-shift contexts produce no incident or vent; genuine
nitrogen/oxygen boiloff converts once; destructive data-carrier breaches still
drain the converted fluid and report both actual incidents. The test injects
private exports only into its staged copy. No rendered-alert claim is made.

### Armoured Biters separate-nest modes

`armoured-on/script-output/armoured-native.json` and the corresponding
`armoured-off` report pass with ArmouredBiters21Compat 2.0.7. Both settings load
all five tiers with valid spawn/build routes and native AI group definitions.
Fifty real units per tier receive native expansion commands; all five groups
build successfully in each mode. Separate nests produce armoured nests; disabled
nests produce the supported ordinary spawner/worm targets. These focused native
AI results do not substitute for the multi-surface generation matrix.

### Development wrapper verification

The ordinary wrapper now defaults to exact 2.1.23 and a separate verified core
seed, stages clean live NSBC source, and selects `core-2.1-smoke`. The source-family
fixture passes main 2.1 selection, current-main/2.0 rejection and explicit compatible
2.0 staging. `doctor` passes. Ordinary fast and runtime engine runs complete with
no engine errors; their overall QC result remains failed because the historical
tracked `scripts/qc/singularity-lance/angular-results.json` contains captured
mojibake. That evidence file has not been rewritten. The initial wrapper also
walked generated long pycache paths; the local scanner now excludes those trees
before recursion. Python syntax checks compile in memory and pass without writing
source-tree pycache. Native log warnings and broad static findings remain visible.

Receipts: `wrapper-fast-22.json`, `wrapper-runtime-21.json`,
`wrapper-python-syntax-02.json` and `wrapper-staging-21/result.json` in the protected
run. Managed engine payloads are `6bba026d8c404c598376569ea9c417f8` and
`9b6b5fb63b6e4a02b094faa040d1d0d9`; both retain their failed overall status.

### Selected continuation provenance

Selected required replacements are ArmouredBiters21Compat 2.0.7, air-scrubber
0.2.9, atan-ash-fork 1.0.1, doeworks-deer-continued 1.0.0,
enhanced-walls-continued 1.0.0 and zzz-nonstandard-beacons-continued 1.0.0.
The latter uses published PEREL 1.2.2. Upstream Nonstandard Beacons remains an
assessed alternative, but its published release requires unpublished PEREL 1.2.3.

Package inspection corrects the proposed Deer GPL-only description: its original
`licence.txt` assigns remixed Factorio/Space Age graphics to Factorio terms, sounds
to GPLv3, and other content to CC BY-NC-SA 4.0. Preserve that file and component
attribution in the continuation. Walls' captured Portal license is MIT; retain
Ink_Dash/inkyboi attribution. Prototype and setting identities must survive both swaps.

### Native science and platform travel

`progression-native/native-01.receipt.json` and its
`script-output/upgrade-progression.json` pass native lab consumption for an ESIR
tool pack, a vanilla item science pack, and a mixed recipe. Each research consumes
three of four supplied packs and completes through the ordinary research event.
The earlier Rocket-silo travel assertion in that historical fixture is superseded
by the approved native 2.1 gate. The current fixture expects Rocket silo to leave
travel locked. Dedicated `platform-travel-native` evidence checks actual ordinary
completion of Rocket silo and each of the three discoveries, then executes the
exact shipping migration body against already-researched discovery forces with
the new flag absent. All four outcomes and an unrelated force bonus pass.
The discovered-force cases are native 2.1 migration-body checks; the preserved
2.0.77 Rocket-silo-only donor supplies the separate actual engine-migration case.
All four native outcomes survive a real save and reload. The populated 2.0 donor
also passes migration and a second load with personal travel locked, while its
production, fluids, ecology, beacon state and unrelated researched unlocks pass
the retained migration assertions. Evidence is
`platform-travel-native/native-03.receipt.json`, `reload-01.receipt.json`,
`platform-travel-migration/migration-01.checkpoint.json` and
`platform-travel-migration/reload-01.receipt.json`. This is an intentional gameplay
change: Rocket-silo-only forces must research one of the discoveries before
boarding a rocket. Cargo launches and remote platform construction are unchanged.

### Optional final-data acceptance and generated crystal returns

The first native smoke pass has now attempted all 45 selected optional roots:
42 pass and three remain unsupported. The user explicitly deferred K2 support for
1.4.0 after its ammonia temperature conflict; core recipes retain -35 degrees and
no K2 temperature/balance exception is applied. K2 saves stay on preserved 2.0.
Cubium still uses removed water-effect texture
fields; Woodoria's transitive Fruit dependency calls a removed assembler graphics
helper. Five original families remain in the separately documented port backlog.
Gore's successful load does not clear its license/provenance hold.

Integration fixes cover Muluna's replacement productivity technology, Cerys'
extra unlocks for deliberately removed recycling loops, Tenebris copies of ESIR
machine graphics, and Corrundum's steam-generator input temperature field.
These passes establish loading and focused invariants, not optional-save migration
or arbitrary mod combinations.

Muluna's Rigor dependency was found to select the ordinary return crystal as its
rare output, changing the approved shared split in generated recipes. ESIR now
excludes the two return alternatives from Rigor product selection. An unrelated
random product remains eligible; when none exists, that return recipe is excluded
from Rigor generation. Crystal resource drops are unaffected. The final native
Muluna/Rigor run validates all **600** return recipes: 24 originals and 576 variants
from 18 original groups. Each retains its original input count, one returned
crystal, the exact 98/2, 90/10 or 92/8 split, complete shared ranges, no independent
gate and productivity exclusion. The [complete variant list](CRYSTAL_VARIANT_MATRIX.md)
records every name and split. The 48,000-craft core suite remains the actual-craft
evidence; the additional variants have native final-data and smoke evidence.

### Enemy generation matrix and native placement differences

`audit/generation-matrix-02.json` compares 774 executed cases across 2.0.77 and
2.1.23: two seeds, six planets, legacy/native generation revisions, off/zero and
low/high slider settings, and mixed Nauvis enemy families. All 10,612 control and
map-exchange assertions pass. Gleba retains ordinary egg rafts when enemies are
off, as authored; its runtime birth gate is a separate owner.

Focused raw-value probes locate small native Voronoi differences in Aquilo
elevation and Vulcanus territory noise. The sampled differences do not cross zero,
and the tested Vulcanus territory chunks and segmented-unit identities match.
Gaia's actual future nest placements differ (48 versus 28 for seed 1000; 254 versus
137 for seed 421337). `audit/gaia-generation-probe.json` now checks 200,704 positions
per seed: both spawner probabilities and all sampled tiles match exactly, as do
the inspected spawner definition fields. Flat surfaces with other entities,
cliffs and initial units removed still differ (274 versus 178; 456 versus 287).
This isolates a native engine difference without claiming its internal cause.
A private prototype-order experiment also did not fix it and is not shipping.
No compensating density, probability or seed change is applied. Preserved legacy
expressions do not guarantee identical placement in newly generated 2.1 chunks.

`generation-migration-20/donor-01.checkpoint.json` records an actual populated
2.0.77 donor. `generation-migration-21/adopt-01.checkpoint.json` and
`reload-01.checkpoint.json` preserve all 97 existing nests (identity, position and
health), 32,768 checked tiles, seeds, control tuples and aliases across canonical
and custom-owned Gaia. The explicit walker probability override `0` survives.
Both saved surfaces acquire the legacy revision; a new surface uses native21.
Donor SHA-256: `e9b11b0170e27d5d6ca4a4f1e75be008956e93484ebb09d6dfb29ca31b48d976`;
second save: `64ab6fa714df69f488033a42493387bbc7e37f2e68ec784e36925ebb6d64f134`.

`gaia-reforge-21/reforge-01.checkpoint.json` exercises the real destructive reforge
only on a disposable copy of that donor. It completes evacuation/purge/staging,
old-surface release, rename/bind and verification in 125 ticks. Seed 421337,
custom 1.3/0.75 electric controls, the zero walker override and legacy revision
survive. The new surface replaces index 2 with 4 and leaves no staging surface.
`reload-01.receipt.json` passes another 600 ticks and rechecks the rebuilt state.
Reforged save SHA-256: `c9c52212ef7894d079dae0f05b4c24812b68156aa76fc007f8ea9f3d2764f357`.
No connected-player evacuation/remote-view claim is made by this fixture.

### Steam-machine native visual acceptance

`audit/steam-21-acceptance.json` passes 40 native states and captures: ten ordinary
steam consumers, working and starved, with Pyric Radiance both On and Off. Every
working machine performs activity; every starved machine has zero activity and
energy. Final consumer and excluded-family definitions match across the setting.
Their steam energy sources explicitly retain zero light-flicker intensity.

`audit/steam-21-visual-review.json` records inspection of all 20 On images and the
ten distinct Off images; the other ten Off images match decoded pixels exactly.
The unwanted light pools/glow are absent, while existing bodies, moving parts,
water and operating pump steam remain visible. Different donor seeds explain ore
variations and animation-phase differences; this is not a pixel-identical 2.0
render comparison. The fixture was ported to direct indexed fluid methods and
suppresses freeplay's introductory modal before native player creation. No audio
listening, physical mouse interaction or multiplayer acceptance is claimed.

### Muluna rocket productivity follow-up

The accepted default native run confirms `rocket-part-productivity-aquilo` grants
0.1 to each of `ei-rocket-parts`, `ei-rocket-parts-advanced`,
`ei-rocket-parts-odd-plating` and `ei-rocket-parts-odd-plating-advanced`, with no
additional productivity on the silo's `rocket-part` bridge recipe. The final
compatibility owner preserves each source effect's value/metadata and avoids
duplicate existing effects. Published Muluna 2.9.1 hides and forces its easy rocket
setting true; an attempted fixture default override did not change that effective
setting and is explicitly recorded as another default run. Expanded rocket
research is not claimed as an available supported setting. Its interstellar
science age classification still needs optional progression review.

## Additional native acceptance and release gates

<a id="railgun-migration"></a>
### Railgun coolant storage, helper ownership and migration

**Before:** configuration changes destructively rebuilt coolant helpers, discarding
stored fluid and heat-debt state. A mechanical 2.1 API port also let native cold/hot
capacities rise from 30/60 to 60/90 despite unchanged nominal recipe fields.

**After:** `control.lua` calls the existing state-preserving
`railgun-cooling.repair_runtime_state` for configuration changes. Explicit rebuild
and initialization retain their separate semantics. The data owner sets the
locked helper recipe's cold ingredient to 15 with multiplier 1 and retains hot
amount 30 with explicit multiplier 2. This produces the original native 30/60
capacities in exact 2.1.23. The hidden lock item has no ordinary production route;
this recipe sizes the buffers and does not perform gameplay coolant conversion.

**Exact effects and state:** a fully cooled shot still consumes ten cold
fluoroketone at -150 degrees C and produces ten hot at 180 degrees C. Shot timing,
damage, heat-debt cap 40, five-tick debounce, recovery interval 60 and passive delay
300 remain unchanged. Migration retains identities, connections, fluid amounts,
temperatures, health, debt and pending deadlines. No manual save action, new
setting, locale key, public remote interface or scheduling surface is introduced.
The [railgun model](../../blueprints/railgun-cooling.md) and dispatcher model now
distinguish preserving repair from destructive rebuild. Invisible coolant helpers
remain intentionally excluded from independent death/presentation scenes; the
visible railgun's presentation is inherited and unchanged by this fix.

**Native evidence:** `railgun-runtime-21/native-04.*` passes 288 real inserter
placements, eight orientations, both construction orders, helper rebuild and
destruction recovery, and eight coolant rigs at the correct capacities.
`railgun-runtime-20/donor-03.*` creates an actual 2.0.77 donor;
`railgun-migration-21/migration-05.*` verifies 2,091 state fields across 296 helper
records, including a pending overheated turret with debt 10, health 3600, shot
tick 299 and deadline 359. All eight populated coolant helpers and insulated
connections survive. `railgun-migration-21/reload-01.*` adds a second native
save/reload and 600 ticks. Reloaded save SHA-256:
`a66c5fbaa903d4da95a8bf1527ab7692948875e6e0102e7da8a6fb80bae3d690`.
Earlier failures and the capacity probe are retained. The old fixture's ordinary
fluoroketone pipes were corrected to insulated pipes so the test obeys ESIR's
existing fluid-safety policy.

**Limits:** live projectile combat, duplicate-shot boundary cases, blocked-output
recovery/passive bleed, physical GUI interaction, visual inspection, multiplayer
and representative performance remain separate from this acceptance.

### Recipe buffers: approved native behavior with Quality

**Before/after and exact effects:** the initial compatibility implementation below
retained 2.0 capacities. The user then explicitly approved the helpful native 2.1
buffer changes when Quality is enabled. Default input multiplier 3 permits
`amount * (3 + 1)`: four batches instead of two. The output floor becomes three
batches instead of two. Authored multiplier 10 stays 10 and permits eleven input
batches instead of ten. Native entity volume can impose a larger minimum.
Recipe consumption, production, temperatures, probability, productivity and
duration are unchanged. The railgun's locked internal sizing recipe remains
explicitly 30 cold / 60 hot; it does not perform coolant conversion.

**Implementation:** `ei_lib.recipe_fluidbox_multiplier` centralizes the policy.
With Quality, ordinary records omit compatibility overrides and explicit authored
values remain authored values. Without Quality, the helper subtracts one from
legacy input multipliers and retains output multiplier 2. The bounded inherited
recipe pass returns immediately when Quality is present. The final source patch
updates 766 literal records across 64 files, plus shared/generated paths.
`recipe-economy.md`, the API/helper skills and changelog document this choice.
No public interface, setting, recipe identity or locale key changes are needed.

**Migration and verification:** native capacity expansion requires no scripted
fluid conversion. `native-buffers-21/native-02.receipt.json` checks 24 actual
machine cases across two entity volumes, four policies and normal/rare/legendary
quality. A 60-unit recipe has native input/output floors 240/180 versus legacy
120/120, and explicit input multiplier 10 permits 660 versus old 600. The real
checkpoint and `reload-01.receipt.json` retain fluid amounts and temperatures.
The helper's no-Quality branch was exercised synchronously in a private fixture;
this is not acceptance of a complete no-Quality ESIR installation, because ESIR
requires Quality. The final ZIP comparison enumerates every changed buffer field
and rejects all other compact gameplay drift. These are engine/data observations,
not new multiplayer or graphical claims.

**Historical parity evidence, superseded only for ordinary buffer capacity:**

`audit/fluid-capacity-parity.json` compares 36 identical private crafting probes
in 2.0.77 and 2.1.23. Old input capacity is `amount * multiplier`; new input capacity
is `amount * (multiplier + 1)`. Explicit output multiplier 2 retains
`max(entity volume, 2 * output amount)`. All 24 cross-multiplier input comparisons
and all 36 explicit-output comparisons match. The isolated railgun probe separately
checks multipliers 1/2/3/4 and the hidden sizing exception.

The earlier AST-scoped source patch adjusted 462 literal inputs and 302 literal outputs
across 62 files. Shared helpers, auric marker/fumarole generators and barrel
rewrites are reconciled separately. Legacy input default 2 becomes 1; authored
casting multiplier 10 becomes 9. A bounded final pass covers 75 inherited core
recipe identities, including eight native casting/holmium overrides (10 becomes
9, cable's 5 becomes 4) and the two ore-melting renames. Explicit unrelated optional
buffer policies are not globally overwritten. The recipe-economy model and API
skill now document native sizing rather than nominal-field equality.

Core26 verifies all 24 crystal contracts, zero machine-eligibility changes
among 2,834 shared recipes/97 crafting identities, zero recycling economic/timing
changes and zero ash changes. The bounded final pass resolves all 105 inherited
field differences found in Core25. `audit/fluid-final-data-26.json` now has zero
differences across 992 fluid inputs and 591 output sizing floors, including the
two renamed ore-melting recipes. `audit/economy-parity-26.json` retains exactly
the 24 approved crystal-return differences among shared non-recycling products.
`core/full-core-26.*` passes exact 2.1.23 loading; compact inventory SHA-256 is
`65e06406b28b9866931d1232c890c7a98000c42467b62f02a15f255eb81f30f8`.
The only changed fluid input amount is the normally uncraftable railgun lock
recipe described above. Ordinary recipe consumption, yields, temperatures,
probabilities, productivity, quality and duration remain unchanged.

After the authored buffer patch, `auric-runtime-21-buffer-parity/migration-01.*`
passes the real fed enriched cycle and 154 checks from a 2.0 donor. Its eight
phases still take exactly 10,651 ticks, matching 2.0. The second reload passes 175
checks (`reload-01.*`), save SHA-256
`94fb4a3f18ab958291e9dbcf2dec35e1ee6568b44a2cf14b2c10141af32119f0`.

<a id="flamethrower-transactions"></a>
### Flamethrower fuel replacement and fluid custody

**Before:** a mechanical replacement of old fluidbox access with 2.1 local
`get_fluid`/`set_fluid` calls could duplicate connected supply during rollback.
A native failure injected after candidate fluid copy increased seven units of
diesel to 7.875 after retries. Entity-local shares redistribute during the
temporary overlapping-entity operation.

**After:** `scripts/control/flamethrower-fuels.lua` captures the complete connected
segment and the separate private firing buffer. It restores segment totals with
the native segment API after removing the source on success or the candidate on
rollback; the private buffer retains indexed local APIs. Existing connection,
temperature, filter and settings verification remains in the transaction.

**Gameplay and migration:** no fuel eligibility, damage, damage modifier,
consumption rate, research value or recipe changes. Seven units of diesel at
60 degrees C remain seven across connected peers, alongside five units of heavy
oil in the private firing buffer. Stable records, health, kills, damage statistics,
quality, circuit wires/conditions and target priorities survive replacement.
Two epic populated turrets also retain health 321, 17 kills and five units of
their respective fuel through saved On/Off/On startup-setting transitions.
The disabled mode restores ordinary turret identities and returns to idle.
No new public interface, setting, locale key or scheduling surface is introduced.
The [flamethrower model](../../blueprints/flamethrower-fuel-adaptation.md) describes
the connected/private distinction and transaction ordering.

**Evidence:** `flamethrower-native-21/native-03.receipt.json` and its
`script-output/flamethrower-qc.json` pass 51 assertions, including 12 injected
post-copy failures and 15 successful replacements. `flamethrower-native-off-21/`
`native-02.receipt.json` passes 53 assertions, including ten failed rollback
attempts and ten successful restorations. `flamethrower-matrix-21/native-02.*`
passes all 110 native turret/fuel firing combinations. Transition checkpoints are
`flamethrower-transition-on-21/on-01.checkpoint.json`,
`flamethrower-transition-off-21/off-01.checkpoint.json` and
`flamethrower-transition-on-21/on-02.checkpoint.json`; final save SHA-256 is
`142c185cc87673d915f8df7e67e4ed349e7a71b593ad1c35558be8dab7154cc8`.
Earlier failed attempts remain retained. The matrix fixture was corrected to
create its deliberately unregistered fixed identities after configuration
rebuild; no gameplay bypass ships.

**Limits:** native engine calls exercise player/robot construction, mining,
rotation, teleport, cloning, blueprint normalization and cleanup, but do not
establish rendered appearance, physical mouse interaction, fire-overlap
combinations, multiplayer or representative performance.

### Resource Off settings and native save admission

**Before:** the native 2.1.23 resource helper divides by resource frequency twice.
Saved frequency zero/size zero controls can fail map loading with
`NoiseExpression cannot be NaN`; zero frequency with positive size also reproduced
an engine crash during sampling. The failure occurs before Lua migrations.

**After:** `scripts/data-final-updates/resource-generation.lua` guards only the
recognized native formulas and returns zero for zero frequency. Positive values
use their original denominators and original expression. The saved native controls
remain unchanged; no runtime conversion or pre-upgrade console step is required.
`scripts/control/map-settings.lua` now retains known positive dimensions and exact
richness from an imported Off control when no remembered tuple exists, before
falling back to planet defaults. An existing remembered tuple still wins.

**Gameplay and migration:** disabled resources remain disabled, including zero
richness. No recipe, progression, entity amount, seed, tile or enemy-control value
changes. The native Off/On check restores frequency 3/size 2/richness 0 for iron,
and frequency 1/size 2/richness 1.25 for imported copper. Explicitly switching
copper back Off writes the established zero/zero representation. No new setting,
locale key, remote interface or scheduled work is introduced. The owning model is
[map settings](../../blueprints/map-settings.md#resource-off).

**Evidence:** `audit/resource-zero-comparison.json` records six zero cases with no
generated iron and 16,900 exactly equal positive probability/richness samples.
Positive generated ore counts are unchanged at 767 and 1,266. The shipping guard
then passes actual 2.0 donor admission in `resource-off-migration-21/adopt-03.*`
and a second save/reload in `reload-01.*`, retaining 1,949 existing ore entities,
1,024 sampled tiles, seed 231337, control values and remembered preferences.
Second save SHA-256: `bb9dc9fd87d073c5730fbc5346a6c047bad5ed71c6a6754aad7323aab35fe473`.

**Limits:** this protects the native resource helper. A mod replacing its formulas
is logged for compatibility review. Positive sample equality is focused evidence,
not a proof for every optional custom noise function. Enemy-generation placement
differences described above are a separate native-engine finding.

### Auric vat indexed fluids, cycle and migration

The vat keeps its existing identity, seven basin bands, claim ownership, hidden
recipes, scheduler and biological thresholds. The 2.1 implementation uses indexed
entity fluid access, live fluid-storage prototype resolution and
`disabled_by_script`. The [auric model](../../blueprints/auric-inoculation-vat.md)
now names those APIs. No recipe quantities, durations, quality or productivity
eligibility are changed by this port.

The focused native fixture passes all seven ordinary yields `2/2/4/4/6/8/10`,
enriched yields `4/4/6/6/8/10/12`, and standing capacities
`6/8/12/16/20/24/28`. It verifies saturated/partially filled basins, exhausted
placement, failure thresholds, and a 35-unit dirty-water drain that must empty
before bloom. Seven existing vats preserve identity, claims, nodes, 37.5% native
crafting progress, vigor 76, contamination 11 and seven completed cycles during
the actual 2.0-to-2.1 donor load.

`auric-runtime-20/cycle-01.*`, `auric-runtime-21/cycle-04.*` and
`auric-runtime-21/migration-01.*` complete the real fed enriched cycle through the
production dispatcher. `audit/auric-cycle-parity.json` records identical eight
phase-transition samples and 10,651 ticks (177.5167 seconds) on both engines.
The migrated 2.1 run passes 154 assertions. Its completed save SHA-256 is
`5ca3b87585e852915b8b00347f118cddef93a91d9127b817134268d69e08c2dd`.
The actual second save/reload passes 175 cumulative assertions in
`auric-runtime-21/reload-01.*`; the reloaded save SHA-256 is
`e5b84381bdc801072c5fe47c34be2d995a0672c63cb8da8541a7262290bd7928`.

An earlier timing failure belonged to the fixture: forced `crafting_progress=1`
probes left a native product count when changing recipes in 2.1. The timed cycle
now starts from the actual counter and asserts that no completion marker remains.
No gameplay timing change was made to accommodate that artifact. Native GUI,
circuit telemetry, washing-productivity acceptance and multiplayer remain separate.

<a id="turbine-transactions"></a>
### Combustion turbine transactions, GUI and migration

**Before/after and reason:** the old shell-switch path destroyed the source before
attempting replacement. Injected creation failure spilled 13 queued rare coal,
lost 123,456 J of burning-fuel state and reduced a connected 230-unit diesel supply
to 100. Successful switching reset mining/destruction/operation/rotation and script
disable flags. The owner now creates the requested shell while retaining the old
one, then commits refunds/removal only after creation succeeds. Failure returns
the original entity, preserving its unit number, fuel, fluids, proxy and viewers.
Successful switches transfer the tested flags, quality, health and energy.

A separate GUI trace found that opening a fluid console can synchronously close
another turbine's previously open native window. Its close event formerly destroyed
the newly opened console. The handler now compares the closed entity's owner with
the current GUI owner. A stale close from another turbine is ignored; native close
of the current console still works. Clone/proxy grid alignment was investigated
and already matched; the proposed grid change was removed rather than retained as
an unproven fix.

**Gameplay and implementation:** no recipe, fuel category, efficiency, power limit,
setting, locale key or public interface changes. Authored nominal output remains
12 MW, with solid efficiency 3 and fluid efficiency 2.25. Switching successfully
to fluid mode still refunds queued solid fuel; switching successfully to solid
mode still removes the discarded fluid-only storage. The latter is existing
behavior, distinct from failed-switch conservation. Both native turbine bodies
expose no red circuit connector. The source owner is
`scripts/control/combustion-turbine.lua`; its [conceptual model](../../blueprints/combustion-turbine.md)
and changelog describe the transaction and native GUI handoff. Dispatcher, storage
root, event-only cadence, existing locales and entity presentation identities stay
in place. No new death, hit, sound or simulation asset is introduced.

**Native verification:** `turbine-runtime-21/native-02.*` passes the 50 transaction,
flag and helper assertions. `native-04.*` extends this to build tags, native cloning
and settings paste. `client-02.*` passes 63 assertions with an actual connected
player, including failed/successful GUI switching and departure cleanup. Its save
SHA-256 is `464678697ea1353b38fa0a514cfa2fdc1199ab633cb33884e53e2a255f6bcef3`.
`headless-reload-03.*` then passes 71 cumulative assertions on that populated player
save, including stale-window transfer, native close/reopen and four retained
turbine owners. `client-reload-03.*` passes the same 71 assertions in the graphical
client with a connected player and saves again. Its checkpoint SHA-256 is
`aea90f2dd336358dbda91905d9f933282d4bdb6bdd5cfd61baec7d77db5dc66b`;
source-manifest SHA-256 is
`6a513ba9f3b972b75de5fd9029bfb0304dfdf650f84e013b8d76b2ee44ac8128`.
The 1600x1000 `client/script-output/turbine-fluid-reload.png` and
`turbine-solid-reload.png` were visually inspected: the fluid screen, solid native
window/relative console, selected-mode buttons and script-disabled state are
readable. Earlier cropped/incorrect-panel captures and failed fixtures are retained
as historical evidence, not render acceptance.

**Migration:** `turbine-migration-20/donor-04.*` creates two populated rare turbines
in real 2.0.77. `turbine-migration-21/migration-03.*` and `reload-01.*` compare 41
fields after admission and another 600 ticks each. They preserve body identities,
mode, health 123, energy 12,345 J, protection flags, 13 rare coal, a rare burning
coal reserve of 123,456 J, 60 C diesel and reconstructed proxy ownership. The
accepted native overflow adjustment below is recorded separately and becomes the
strict baseline for the second reload; there is no further loss. Migrated save:
`ce4ec819e7779df2c96df53f2d4e3184fe8c47e3182ff89e2a2be8611da282e3`;
second save: `fdc79729371ad01262f56fe622eb4366380f7d711c55b6ff1aca906386bacd22`.

**Accepted native migration limit:** a minimal Base-only reproduction with no ESIR
control code preserves bounded 100- and 200-unit networks, but a 230-unit network
becomes 215.0000083. In 2.0 the turbine's 400-unit private store and a connected
100-unit pipe settle at roughly 115 each; the pipe segment is over its nominal
capacity despite spare capacity in the installation overall. Native 2.1 clips
that segment before combining the stores. Adding a second pipe in the private 2.0
reproducer preserves all 230 units, confirming the capacity boundary. The actual
core donor was saved earlier in the equalisation cycle and therefore loses
9.6345603 units, retaining 220.3654397. Evidence: `native-generator-20/donor-01.*`,
`native-generator-21/unprepared-migration.json`, `prepared-migration-01.*`, and
`turbine-migration-21/script-output/turbine-reload.json`. The user explicitly chose
not to address this native edge case; no automatic preparation or mandatory manual
draining/storage step is added. This acceptance applies only to this identified
overflow behavior, not arbitrary fluid loss.

**Limits:** isolated electrical-load results are recorded below. This does not prove
working animation or audio playback, physical mouse interaction, simultaneous
viewers, multiplayer or performance parity. Visual/GUI receipts do not close those
gates.

<a id="loaded-power"></a>
### Loaded power and native burner behavior

**Before/after and reason:** ported generator definitions retain their authored
power, efficiency, fluid and quality values. The native load comparison covers
solid/fluid combustion, steam engine, steam turbine and big turbine bodies. Each
has normal/rare versions at idle, quarter demand, full demand, double demand and
script-disabled demand: 50 isolated networks, measured in two ten-second windows
after a ten-second warm-up. The fixture adds only a private load prototype; core
generators are unchanged.

**Exact gameplay effects:** the following normal-quality outputs and full-load
consumption remain the same in both engines. Rare fluid generators retain 1.6
times the output and consumption, subject to identical native fixed-point rounding.

| Generator | Nominal normal output | Full-load input per 10 seconds |
|---|---:|---:|
| Solid combustion | 12 MW | 40 MJ raw coal energy, efficiency 3 |
| Fluid combustion | 12 MW | 266.6666508 diesel at 60 C, efficiency 2.25 |
| Steam engine | 0.9 MW | 300 steam at 165 C |
| Steam turbine | 5.82 MW | 600 steam at 500 C |
| Big turbine | 400 MW | 99.9999762 critical steam at 1,500 C |

The big turbine's measured normal output is 399.9999 MW and rare output 639.99984 MW
in **both** engines; the small rounding difference from the nominal limit is not a
new upgrade effect. Idle and script-disabled bodies consume no additional fuel in
the measured windows. Quarter-load bodies follow demand; excess demand does not
raise generation above the native limit.

One measured difference belongs to the native solid burner. With normal coal in a
rare turbine, full/overloaded output rises from 18.943999725 MW in 2.0 to 19.2 MW in
2.1. Raw fuel use over each ten-second window rises from 63.146666654 MJ to
64.000000954 MJ, retaining efficiency 3 within native precision. This approximately
1.35135% delivered-output increase reaches the existing rare-quality limit; ESIR's
12 MW base limit and efficiency are unchanged. A minimal Base/Quality reproduction
with a private burner and no ESIR code/assets produces the identical numbers.
The shipped 2.1 changelog also records a high-effectivity burner fuel-request fix
in 2.1.7; the independent reproduction is the evidence for this observed behavior.

**Implementation/migration:** no additional shipping change, setting, locale,
prototype identity, public interface or save conversion is required for this
native output difference. Source owners remain
`prototypes/electricity-age/combustion-turbine.lua`,
`prototypes/computer-age/big-turbine.lua` and the inherited vanilla generators.
Existing turbine migration/GUI evidence remains separate above. The retained
authoring values are not reduced to imitate the old native shortfall.

**Verification:** `power-output-21/native-06.*` passes all 300 assertions. The paired
2.0 run intentionally retains four failed power-limit assertions for the two rare
solid demand cases across two windows; its receipt is **not** relabeled as a clean
pass. `native-burner-20/native-01.*` reproduces the same four negative assertions;
`native-burner-21/native-01.*` passes 60 checks. The strict comparison in
`audit/power-output-parity.json` validates all 100 windows, with 488 of 500 compared
values exactly equal and the remaining 12 electricity/fuel measurements exactly
matching the isolated native reproduction. There are no unexplained differences.
Comparison SHA-256:
`3a66e625c1b716d280a4b9463d292dccd6609e12849c96e1d5c06b77ef62c804`.
Core 2.0/2.1 report hashes:
`6e455ab73fb3e2c9637f762273a3516ac7eb48ee00f870d4e2568b38537fad36` /
`9f6d1182100e09290ba6e82f0ac68eca2d4aef5aeadf3d4e71e93d35991ae30e`.
`stage.json` and `power-fixture-source.json` retain source/fixture hashes. Reproduction
commands and statistics semantics are in `scripts/qc/factorio-2.1/POWER_ACCEPTANCE.md`.

**Limits:** supplies are controlled directly by the private fixture. These checks
do not prove upstream fuel production, pipe-network throughput, the scripted
fusion reactor/control/coolant loop, solar mirror supply, migrated active power
networks, graphics/audio, multiplayer or representative performance.

### Fusion recipe and control-state acceptance

The recipe-driven fusion reactor retains all 135 recipe identities, fuel and
coolant amounts, products, output capacities, output-blocking behavior and native
craft completion timing. Paired 2.0.77/2.1.23 runs each pass 1,053 assertions.
`audit/fusion-recipes-parity.json` normalizes 405 deterministic product-probability
representation fields and finds zero remaining differences. The original and
target report hashes are respectively
`c72d3ef93e5de863b064d8f98dc8ad5bcad9d67e54d27750e1ff02a50c43b95d` and
`9f52defe858dc60994124c21e5667cea1727ba5c6528d666d1e19a1a2bed645c`.
This uses supplied fuel/coolant and does not establish a complete upstream supply
loop or total-system power performance.

Actual migration exposed a control-state bug: configuration rebuild reconstructed
manual settings from the circuit-selected recipe and replaced valid telemetry
proxies. Configuration now uses the existing state-preserving repair path.
Three populated rare reactors retain 121 compared fields, including distinct
manual fallback and effective selections, control modes, native proxy identities
and wiring, recipe/progress, fluids, health and protection flags. Migration and
the second save/reload each advance another 600 ticks. The donor SHA-256 is
`82f1c0c89b6919642eaeec15846b5686590b92f349a67d92105a3fba1be5f06c`,
the migrated save is
`eef56e4c39a16f76f04ed4f28181627842689601d704be01062f00bd2dc4ca53`,
and the second saved reload is
`08ffcda6d8486216e4e5e447cbe9813fadde5567217cb3b6b085da94501a72da`.
Negative evidence remains in `fusion-migration-21/migration-01-first-state.json`;
accepted receipts are `migration-02.checkpoint.json` and `reload-01.checkpoint.json`.
No manual migration step or recipe/balance change is introduced.

The native actor suite passes 20 assertions for construction, full/partial circuit
commands, manual fallback, telemetry, neutron-collector disable/recovery, settings
paste, missing-helper recreation/reconnection and orphan removal. It also exposed
stale dense-index entries after reactor destruction. Removal now swaps the final
entry into the removed slot, repairs reverse indexes and bounds the service cursor;
destroying the last reactor leaves zero pending work and zero helpers. The negative
`fusion-actors-21/native-01-fixture.json` and accepted `native-02.receipt.json`
distinguish the defect from its fix.

Implementation owners are `scripts/control/fusion-reactor.lua` and its conceptual
blueprint; the existing dispatcher, remote interfaces, settings and localized
console labels remain unchanged. `scripts/qc/factorio-2.1/POWER_ACCEPTANCE.md`
documents reproducible fixtures. The connected console passes 17 checks across
native sliders/buttons, presets, manual/circuit selection, configuration repair,
actual saving, reloading, closing and reopening. The final tested save has SHA-256
`03f0f07b3f14f2681e911c00e4a3861c11c5647ddc8e974e6a78abf630537eec`
(`fusion-gui-21/client-reload-02.receipt.json`). The source manifest is
`e85b20067808e2497d4c1bd20e9c7c2c1b4f02e1184239f787e05091aa67977f`.
Native capture now records the actual display resolution (1600x1000, scale 1),
instead of assuming screenshot dimensions change the client window. The source
description wraps at 360 UI pixels, retaining every locale's original text.
Subsequent settled renders exposed two distinct layout faults: lower descendants
were clipped by the relative frame, and at 125% scale the expanded native machine
and circuit panels pushed the right-hand console outside the physical viewport.
The 100% scroll-body candidate passed 18 checks and rendered all five agent values
and Options buttons (`fusion-gui-21/scroll-fix-01.receipt.json`). The 125% candidate
also passed widget-state checks but failed rendered horizontal-fit review; it is
explicitly **not accepted** (`scroll-scale-125-01.images/`). Windows client bounds
were independently measured as 1600x1000, matching the engine's display report.
The revised source retains the bounded body and uses a movable screen frame below
1,600 UI-scaled pixels of width, retaining the opened native entity and all control
values. One deferred raise on the existing viewer refresh prevents the native
entity window covering the fallback; later updates do not continually steal focus.
The final 125% run passes 24 checks, including all five Options actions through the
central dispatcher, sliders, manual/circuit settings, configuration repair, saved
state, explicit fallback close and reopening. Its settled render visibly contains
all five buttons, five agent readouts and the complete wrapped interface text.
Evidence: `fusion-gui-21/responsive-125-03.receipt.json` and its immutable images;
source manifest `120f3bba2860147e88b18bf0da09867ebb3536e1363b78ca972f79cf6abb9a48`,
checkpoint `f526920bef9fbed6790c189e46d88e670866fa0fef19f3029eab6f461899851d`.
The interface text now wraps at 340 UI pixels to reserve scroll-bar space.
The same final source passes 22 checks at 100% scale with the relative console,
and its settled render also shows all five buttons and agent values:
`responsive-100-01.receipt.json`, checkpoint
`45aef4dea1f8d75bae90d848fd41696054e82e29cf2004f1e2a2dd5fba038063`.
Agent values remain read-only diagnostics; Options are buttons.
Other display scales/locales and physical mouse/keyboard input remain separate.

### Induction matrix and orbital logistics

The established induction suite passes 94 connected native checks on 2.1.23,
including all four default-Off outputs with C/T/M/A retained, signal types and
quality, aggregation, native red/green propagation, dormant work suppression,
floor split/rejoin, converter upgrades/downgrades, blueprint data, native robot
placement, both clone orders, helper ownership, paste isolation and stale GUI
cleanup. The actual initial save has SHA-256
`db6f765bf23f89b2a95c9e8011262a556071b340b818668c29a6a433ed9a237a`;
`induction-native-21/reload-01.receipt.json` verifies ordinary native reload.
The removed-signal configuration transition passes all 98 checks, including
dormant-state preservation and sanitizing the removed prototype. The accepted
configuration save has SHA-256
`df7bbf9df2801188761f23f64b07eb00559eeed9c06744108a75bc345ddadcf9`
(`induction-native-21/configuration-02.receipt.json`; source manifest
`f3457542af2e3e7bee08479eccba6bd17dcfff854a8e976802d0d8f829a8ec4b`).
The native capture after dismissing the save dialog and reopening the console
visibly contains all four labeled checkboxes, C/T/M/A pickers, current values,
network IDs and reanalyze button. All eight locales pass the dedicated key,
description, help and default-Off checks. No new production matrix change,
recipe, output default, interface or locale edit was required by this run.

The orbital cohort passes all 12 checkpoint validations and 16 mutation actions:
duplicate/manual policy claims, coordinator failover, invalid target recovery,
retargeting, silo destruction/rebuild/rebinding, contested-lane fairness rotation,
and transponder conflict/recovery. Evidence is
`orbital-native-21/native-02.records.jsonl` and its native logs/source manifest
(`96aa7ad3f553485299541154a3d5b8b4d6776514bd0ac8dd3b33f351637de613`).
The accepted cohort retains three platform identities and source/circuit ownership.
The initial fixture needed two bound-method call corrections (`apply_starter_pack`
and `add_section`); its 28 missing-player GUI samples remain explicit skips.
Subsequent `orbital-client-21/client-05` and reload receipts close connected-client
coverage: four rendered consoles and 16 mutations through the central dispatcher.
These cover the supported controls and preferences, not physical mouse input.

Real delivery then exposed a shipping bound-method error: `pcall` passed the silo
as an extra first argument to `launch_rocket`. `orbital-logistics.lua` now passes
only the destination. `orbital-delivery-21/native-02.receipt.json` verifies both
uplinks launch at tick 1410 and deliver all 422 items: Gamma receives 60 bricks and
12 low-density structures; Alpha receives 200 iron and 150 copper plates. No
recipe, destination policy, circuit schema, setting, locale or remote interface
changes. Existing silo/platform identities and inventories remain native-owned.
This dedicated delivery fixture is single-version 2.1 evidence; the separate
general migration and multiplayer cohorts retain their narrower documented scope.

### Rocket quality, pollution and exhaust timing

**Before:** the old launch scheduler assumed normal-quality absolute delays.
Temporarily preserving 2.0 timing would have suppressed the native silo quality
bonuses. The user instead approved native 2.1 launch speedups and required
pollution/plumes to follow them.

**After and exact gameplay effects:** the native silo arm, engine-start and rising
modifiers remain 0.2, 0.45 and 0.15 per quality level; lift weight remains 1,000,000.
Recipe costs, rocket cargo, fuel, production and configured launch pollution do
not change. Combustion begins at the first observed `engine_starting` tick. The
engine phase consumes 330/812 of the captured pollution budget over its native
quality-aware duration; clamp release starts the remaining 482/812 share at the
authored reference rate. Updates every ten ticks emit only the unpaid cumulative
difference; confirmation settles the remainder. Cancellation and duplicate/late
confirmation retain their existing safeguards. No fixed pollution refund occurs.

The plume now starts exactly 239 ticks after native `arms_retract`, instead of
always 690 ticks after ordering. Pad smoke begins at ignition and fades toward
that same handoff. Authored cosmetic acceleration, density, particle budgets and
96-tick pad fade remain unchanged; the plume curve is not a physical trajectory
simulation. Normal quality keeps its old timing.

| Quality | Engine-start duration, ticks | Emission reference duration, ticks | Plume offset after ordering, ticks |
|---|---:|---:|---:|
| Normal | 330 | 812 | 690 |
| Uncommon | 228 | 710 | 588 |
| Rare | 174 | 656 | 534 |
| Epic | 141 | 623 | 501 |
| Legendary | 102 | 584 | 462 |

These are the ordinary silo fixture's native timings. A custom fractional engine
speed can cross its native threshold one tick later than arithmetic rounding;
observed clamp release always controls the ascent and plume phases.

**Migration:** schema 2 preserves captured budgets, paid balances, ignition,
silo/rocket identity and detached-launch custody. Old airborne schema-1 records
reconstruct elapsed engine time with the original unscaled 2.0 duration so their
plume is not moved early during migration. New launches capture quality-aware
duration. No user preparation, new setting or remote-interface conversion.

**Implementation:** `scripts/control/rocket-launch-pollution.lua`, its conceptual
model and changelog; explanatory Informatron text updated in all eight locales.
The established dispatcher and gated owner remain unchanged. `stage_rocket_quality.py`
adapts the historical 29-case suite and adds sixteen higher-quality/style cases.

**Verification:** `rocket-quality-21/rendered-01.receipt.json` passes 374,714 checks
across 45 cases against the latest rocket owner. Each ordinary 10,000-pollution
hybrid case emits exactly 10,000, with 76 pad particles and 1,419 plume particles.
All five qualities start plume emission at clamp+239 and stop at confirmation.
Actual server checkpoints and `reload-during-01.receipt.json` repeat the full
374,714 checks after in-flight save/reload. The native rendered run produced 24
hashed frames: ignition and plume start/+150/+300 for five qualities plus normal
cinematic. All were inspected; `audit/rocket-quality-render-review.json` records
the review and contact sheets.

The genuine 2.0.77 donor includes normal, rare and legendary launches. Both the
ignition donor and the already airborne donor migrate successfully in
`rocket-migration-21/migration-ignition-01.receipt.json` and
`migration-ascent-01.checkpoint.json`. Total pollution stays 30,000 across the
three launches, with paid balances and identities preserved. The completed 2.1
save reloads successfully again (`second-load-01.receipt.json`).

**API observation and limits:** 2.1 pollution statistics update after the emission
tick; immediate reads can still show zero. The fixture compares statistics with
completed prior-tick physical emissions, rather than emitting twice. This is
documented in the API skill. Native graphical execution is verified, but no
physical mouse input, continuous-video review, listening test or dedicated rocket
multiplayer/performance benchmark is claimed.

### Crystal accumulator shell custody

`crystal-accumulator.lua` now calls bound `get_wire_connectors` through `pcall`
without an extra entity argument. Core crystal bodies are electric-energy
interfaces with **no native circuit connectors**; this corrects a defensive path,
not a demonstrated loss of core circuit wires or an added wiring capability.
No recipe, energy capacity, quality rule, setting, locale or remote interface
changes. The ordinary/Gaia shell identities and existing owner storage remain.

`crystal-wire-21/native-05.receipt.json` verifies four actual swaps across ordinary
and Gaia surfaces at normal/rare quality, retaining 12,345,678 J, 70% health and
quality. The engine returns an empty connector set for every core body. A real
checkpoint preserves those replacements; reload evidence is recorded alongside
the fixture. This is native shell custody evidence, not proof for an optional mod
that adds circuit connectors or a rendered/multiplayer crystal-specific test.

### Approved native module precision and rolling-stock quality

Paired native testing found that 2.1 retains fractional module bonuses which 2.0
rounded down. The user explicitly approved this native precision. All 22 module
identities retain their normal-quality authored values and penalties; the three
quality modules retain the approved 0.03/0.045/0.06 effect-unit conversion.
There are 21 changed higher-quality values: 18 productivity values and three
tier-2 quality values. The complete before/after enumeration is maintained in
[QUALITY_NATIVE_CHANGES.md](QUALITY_NATIVE_CHANGES.md), together with every wagon
capacity at every playable quality. No hidden module identities or runtime
rounding emulation were introduced.

The user also explicitly approved native quality scaling for **all locomotives
and wagons**, deferring balance adjustments. Native locomotive power factors
remain 1/1.2/1.4/1.6/2, and speed ceilings use 1/1.03/1.06/1.09/1.15. A bounded
final-data owner now copies the native locomotive speed, cargo inventory and
fluid-wagon capacity flags to ESIR's early-copied train bodies. This fixes a stage
ordering gap: Quality's data-updates pass enabled the flags on native bodies after
the steam and EM copies already existed. The steam placement body inherits the
same flag. Quality definitions, authored base power, fuels, bonuses, weight,
braking, friction and normal-quality capacities remain unchanged.

Cargo slots now scale by 1/1.25/1.5/1.75/2.5 with native integer truncation; fluid
capacity scales by 1/1.3/1.6/1.9/2.5. For example, the EM cargo wagon remains 60
slots at normal quality and gains 150 at legendary; its fluid wagon remains
100,000 units at normal and gains 250,000 at legendary. Existing prototype/item
identities, cargo, fluids, schedules and circuit configurations need no new state
conversion. Native larger capacity is gained on load. The preservation-only
intermediate candidate is retained as diagnostic evidence and superseded by the
user's explicit decisions.

Implementation: `scripts/data-final-updates/transport-quality-policy.lua`, its
final-data import, the [transport quality model](../../blueprints/transport-quality.md),
the 1.4.0 changelog and a short appended rail-progression paragraph in all eight
locales. Existing translated prose remains intact. No new setting, remote API,
dispatcher or periodic runtime work is added. Future optional modifications to
native flags are inherited; unrelated optional rolling stock is outside the bounded
ESIR list and still needs its own acceptance.

Verification: `quality-trains-{20,21}/accepted-01.receipt.json` passes paired
2.0.77/2.1.23 runs. All 110 native assembler/module combinations were inspected;
the 18 productivity differences also appear in effective machine bonuses. Five
canonical locomotives at normal/rare/legendary quality execute real automatic rail
travel and station braking. All normal-quality sampled speeds and positions match
2.0 exactly. Native prototype queries verify every locomotive speed ceiling, five
cargo tiers and four fluid tiers at all five playable qualities. The comparison
receipt is `audit/quality-native-accepted.json`; source-manifest SHA-256 values are
`484252f38870bab4d702d18087e6cf862710ed2e0ee4032fb09129e3ebfe64f6` (2.0) and
`c5d254a80a89ffbac7ac072df112c2fbf3d71ff2befda4c245a01887362cd54e` (2.1).
This verifies native values and automatic travel, not physical driving input,
rendered train wheels, complete EM charger service or whole-factory throughput.

### Car and hover handling

Paired native lanes cover car, tank and Emerald Apocalypse at normal/rare quality,
with acceleration, coasting and braking: 18 cases and 108 sampled states per engine.
The twelve ordinary car/tank cases match speed, position and orientation exactly.
For the six registered hover cases, all authored drift-speed calculations match;
the native motion between scheduled controller services has a maximum sampled
position difference of 0.0703125 tiles. At the final sample only one accelerating
normal hover tank differs in position, by 0.03515625 tiles. Its controller's drift
value still matches. No hover thrust, drag, brake, speed cap or equipment coefficient
was changed to compensate for this transient native motion.

A separate Base-only reproducer establishes the engine distinction with identical
car and fuel values on dry concrete, and unchanged health. Coal acceleration,
braking and coasting match exactly. With top-speed fuel modifiers 1.15 and 1.25,
2.1's native accelerating speed traces are respectively 1.15 and 1.25 times their
2.0 traces; native braking also differs, while coasting remains identical. The
authored fuel acceleration/top-speed bonuses are unchanged. Thus the W/60 braking
field conversion is validated with unit fuel modifiers; stronger-fuel movement
has a native 2.1 semantic difference, separate from ESIR's script-controlled drift.
This is an observed engine effect, not a newly authored vehicle buff or complete
manual driving-feel certification.

Evidence: `vehicle-handling-20/registered-01.receipt.json`,
`vehicle-handling-21/registered-01.receipt.json`,
`audit/vehicle-handling-registered-parity.json`, and both
`native-car-{20,21}/native-02.receipt.json` reports. Earlier unregistered-body
measurements, the inactive `ei-drone` fixture error and the incorrect fuel-candidate
attempt remain retained negative/diagnostic evidence. The final fixture uses the
native build lifecycle, actual drivers and admitted coal/nuclear fuel.

### Spider vehicle progression and combat details

`spider-native-21/native-02.receipt.json` passes 156,034 data assertions over all
24,388 gameplay configurations and 169 native runtime checks with 33 firing cases.
The run performs 34 state-preserving replacements with zero owner failures;
quality, partial ammunition, cargo/trash, equipment, burner reserve, logistic
settings, stable identities, research/force transitions, smoke and bounded target
selection pass. It is headless with no player; player mining, occupied GUI and
manual gunnery are separate acceptance work.

The preserved authored rocket-spider recipe remains four rocket turrets, 50 steel
mechanical parts, 50 carbon fiber, 100 advanced motors, 40 high-energy crystals,
40 processing units and 100 simulation data. An old fixture incorrectly expected
four handheld launchers; the preserved 2.0 source and Git baseline confirm the
turret recipe, and only the oracle was corrected. No ingredient or progression
change was introduced by that correction.

The first overkill run passed 131 of 133 assertions because two rebuilding checks
required a player absent from its seed. The player-backed replay
`spider-native-21/overkill-02.receipt.json` passes all 135 assertions over 29 cases,
including actual player mining/rebuilding while fire is held, remembered targeting
and preferences, manual gunnery, native impacts, resistance/quality prediction,
ammunition savings, lost-impact expiry, clone behavior and native-targeting edits.
The negative first receipt is retained and is not counted as acceptance.

The actual eight-vehicle 2.0.77 donor passes 41 checks and has SHA-256
`c56af0d1d4ccb9acd43d1c65d9d4cd18ef021baeddc078bb82740b0c3990f531`.
Migration and the second native saved reload each pass 53 checks covering stable
identities, cycling/special/Hold/overkill choices, complete inventory/equipment/fuel
fingerprints, logistic filters and restoration of stored rare partial ammunition.
The migrated and second-reload saves are respectively
`06421a26cd38ae76e57d80352c1fc87f9937f974d3303f4fad6b3453ad5180eb` and
`2e96b9c06c9d9e54f91de9c02f3998b8c451ec4e5a67b560a515ecde0019b4b2`.
Receipts live in `spider-migration-20/donor-01.checkpoint.json` and
`spider-migration-21/{migration-01,reload-01}.checkpoint.json`. No new production
vehicle change was needed for these passes. A further player-backed matrix passes
16 dispatch checks and 146 canonical-item checks in each startup cycling mode,
plus 173 checks in the full native-cycling suite. These cover all nine family/grid
combinations, quality equipment at outer positions, nested fuel/spent fuel, stored
preferences, old item adoption, oversized-grid deferral, actual construction-robot
mining/rebuilding, and bounded damage/effect routing. Evidence is
`spider-native-21/functional-matrix.json` with per-case source manifests and fresh
JSON assertion reports. Broader native car/train handling and the separate paired
fleet-performance matrix remain separate gates.

### Research completion and unified alerts

The exact 2.1.23 research dispatcher passes 114 assertions in
`research-native-21/native-01.receipt.json`. A native 758-technology scripted flood
coalesces into one ordered force-wide fan-out, drains its pending queue and retains
the Tesla, EM train/charger and Emerald tank caches. Ordinary queued Tesla and EM
research completions each follow their original event path. The focused unchanged
EM-buff replay still performs the required access check. Tick, force, relevance,
argument order and return contracts are checked separately from the broad flood.
The source manifest is
`2a1cc310fe3fd4f411e4de5d93676bd93bd1bbc32cd82fde7efaf714a69b8ec8`.
No new shipping research behavior, recipe or progression value changed in this pass.

The actual graphical alert client passes 170 checks for all 27 native setting/icon
pairs, personal Off/On, gate source mute and the existing 100 GJ recovery boundary,
nine destructive operational incidents and all 17 ecology receipt categories.
Destroyed-source navigation, no replay on re-enable, independent service budgets,
marker retirement and terrain-reference release pass. The actual save is
`3f3702fc9e5b610558adb0029718f83593e5c759fb1afc0bcb82433a896091ef`.
Reloading that save verifies pending, delivered and expiring legacy ecology records,
identity/deadline/reference preservation, saved false preferences, idempotent
initialization, no duplicate delivery and exactly one release per retired receipt.
Evidence: `alerts-native-21/{client-01,client-reload-01}.receipt.json`; source manifest
`86e9196a49c902ac8ffdda81d8c7f6cdcc2e977a13ca250cbfa9da07927f02a0`.
This is a real native save/reload with reconstructed legacy alert storage; it is
not itself an engine-2.0 donor migration or physical mouse-input check. No new
shipping alert setting, default, icon, message or locale change was required.

### Global beacon ownership and physical gate transport

The saved full-core beacon client cohort reconciles all 131 live beacon records
and all 262 source/controller helpers across every surface. There are no orphan
helpers, unregistered bodies or multiply owned helpers. Every record is attached,
with valid body/source/controller and matching surface/force ownership. Evidence:
`beacon-ownership-21/native-01.fixture.json`, source manifest
`8af922b9b6b50dc0da75330f81054e44a58f2261a4eae047296a46784a119458`.
This closes the global orphan scan for that populated acceptance world; deliberately
protected recovery cases remain covered by NSBC's separate recovery fixture.

The native gate cohort passes 18 checks for same-surface and cross-surface rare-item
transfer, one-stack conservation, exact quoted payment, cooldown/stress/saturation,
zero-power and full/saturated-receiver rejection, native red-wire enable/disable,
and physical player travel out of remote view. Each successful sample moves exactly
37 rare iron plates; failed transfers retain the 11 rare copper plates at the sender.
The shared physical-teleport helper exits remote view before moving the character,
so both the player's physical surface and the character reach the receiver surface.
No gate burden, cost, threshold or cooldown formula changed. Evidence:
`gate-native-21/native-01.fixture.json`, source manifest
`7973005ccac8308c1b6cc9ac07615449172d9b404d9c0d73a90b987bc1d30b8e`.
The actual gate checkpoint and second save/reload also pass, preserving gate,
container, wire-proxy and receiver identities, manual/alert settings and inventories,
then checking the same state after 600 additional native ticks. Evidence:
`gate-native-21/donor-01.checkpoint.json` and `reload-01.checkpoint.json`; saved hashes
`f1cff43f4160daf28c47550bf168c095d199874ffc5f5bafe72a17d911d9a659` and
`8e424d70bdafb68395551d852a9deb635676b8ba902a00f3fa648ebbcf2de42e`.
This gate-specific fixture is a populated 2.1 save/reload; the actual 2.0-to-2.1
donor migrations are recorded separately above.

### Multiplayer disconnect and rejoin

The actual loopback server and graphical peer pass initial admission and a real
disconnect/rejoin on exact 2.1.23. Both sides independently emit identical reports
after 600 connected ticks in each phase: nine initial checks and 22 rejoin checks.
The server observes the leave event before readmission. Player identity and the
personal restoration-alert Off preference survive, as do the populated rare chest,
two rare beacon sources, their modules, orientation/mirroring and owned helpers,
and the rare fusion reactor's manual/circuit selections and telemetry proxy.
The fixture also scans its beacon surface for unowned helpers. No desync or runtime
error occurs in the accepted run.

Evidence is `multiplayer-native-21/multiplayer-03.receipt.json`, the server and two
peer logs, and the source manifest with SHA-256
`5f6f13c30d9980bbce17b16ec737d24f67681f101c7fbcc688a4b8d0986f07e4`.
The actual saved checkpoint has SHA-256
`78ea4d68a679d9a547727ac9e9ee1968163a27910a2de64a5ec422fdeca1708d`.
This is one simultaneous graphical peer with a dedicated server, not a two-player
concurrency or every-system multiplayer claim. The earlier two negative attempts
are retained: an incomplete private server configuration and a fixture trying to
change another mod's setting directly. The accepted fixture invokes that change
inside ESIR's private test bridge, respecting native setting ownership. No shipping
remote API or gameplay behavior was added for the test.

### Native presentation and custom drill connectors

The unified connector port now assigns the superior drill's authored connector
array directly, matching the advanced drill. The stale final assignments to the
removed `.points` and `.sprites` subfields had silently retained its inherited
vanilla connector. Both drills preserve four authored offsets, `object` render
layer and secondary order 14 north / 48 east-south-west. There is no mining speed,
recipe, fuel, productivity, quality or placement-identity change.

The isolated presentation fixture executes the exact final shipping initialization
and update strings for 28 scenes through 1,200 ticks, with one valid canonical body
per scene and applicable radar/robot helper assertions. Native rendered captures
were inspected for all 28 scenes. Additional native rigs cover both custom drills,
four directions and dry/wet resources: all 16 report `working`, admit their required
fluid where applicable, deliver to native output targets and visibly retain their
connected circuit sprites and wire positions. The images retain the authored wet
pipe art and working lights. The fixture's first output-chest calculation was
replaced with the engine's actual `drop_position`; no shipping output vector changed.

Evidence: `presentation-native-21/native-01.receipt.json` and
`rendered-01.receipt.json` (44 original image hashes), with final rendered source
manifest `200e2c74cd416af5f17e91641be581f8d9c030968499b7e3745371abe9c0bc90`.
The three review sheets are `audit/presentation-21-{presentation,advanced,superior}.png`.
This verifies native scene content and connector rendering, not the encyclopedia's
own window layout, audible playback or a frame-by-frame death-animation review.
Existing death/hit/sound assignments and generated variants pass the fixture's
final-data inheritance checks; those owners required no additional presentation
change for this connector correction.

### Source and static reconciliation

The final graphical-client enemy/Administration run
`enemy-runtime-21-accepted/native-03.*` passes all 670 assertions with one connected
player. Coverage includes enemy-family birth suppression, administrator summons,
infected replacements, owned-raft restoration and its 64-entity budget, resources
Off/On, global validation, stale edit conflicts, retained GUI drafts, access loss,
pending-planet creation and stale replaced-surface targets. The accepted save has
SHA-256 `9971968c46f7e35e2770538bf05f4f7ef5d7ee79a75336def2118f655c5dd185`.
The source-manifest SHA-256 is
`dc1d7e81b3864f2afb5723d60d2f7e107c4d181d4fc8c4e4a96f7c4034b086f1`.
This is native entity/GUI automation in a graphical client; physical mouse/focus,
screenshot review, multiplayer and cross-session GUI-preference acceptance remain
separate evidence classes.

`audit/blueprints-resource-off-fixed.json` records zero blueprint audit findings.
The pass repairs primary contract anchors, gives legacy electric noise an explicit
owner and removes duplicate ownership of the 1.4.0 migration. The focused live
header audit also has no findings. These are structural/source checks, not broad
engine or full-preflight acceptance.

The later final-fusion preflight (`fusion-gui-21/responsive-preflight.json`) passes
Lua/Python/PowerShell syntax, requires, asset references, module headers, package
versions, locale missing/duplicate checks and blueprint coverage (zero findings).
Its sole failing check is suspected mojibake in the pre-existing, Git-clean
`scripts/qc/singularity-lance/angular-results.json`: historical engine-log text
contains a misdecoded cross symbol. That retained result was not rewritten to make
the check green. It is test evidence, not shipping Lua or player locale. The broad
preflight result remains explicitly failed for that historical artifact.

### Final reconciliation and remaining limits

The complete working [50-entry dependency matrix](DEPENDENCY_MATRIX.md) and its
[machine-readable package/provenance/evidence detail](DEPENDENCY_MATRIX.json)
are maintained alongside this report. The selected optional roots resolve to 96
verified packages including transitive requirements. Gore is held because the
original Portal's CC BY-SA 4.0 label disagrees with the fork's MIT label. Smoke
passes are recorded separately from progression, migration and combination acceptance.

The core release's implemented systems and focused evidence are complete within
the scopes reported above. The final twelve ZIPs pass actual archive-only loading,
fresh save, 600 ticks and merged-data verification with 35 selected archives.
Main 1.4.0 SHA-256 is
`a8fb077a851004e409a74c0450872bddfdee16a4b121dd2f3f2be90509f94822`
(7,846,171 bytes). Its compact inventory is
`d7290f480a3f4ef44e5bad1a24c6fb15c8b70d5d4cbd442146b327e188ff99ed`.
Compared with the accepted core26 baseline, precisely 1,581 buffer fields change
across 775 recipes: 991 inputs and 590 outputs. The exhaustive field list is
`package-core-26/compact/approved-native-buffer-changes.json`. The only additional
compact change is removal of the travel grant from Rocket silo, adopting the
approved native discovery gate; no other recipe, item, technology, fuel or
recycling values drift. All 24 crystal pairs,
five locomotive/four cargo/three fluid-wagon native quality flags and the native
0.2/0.45/0.15 silo modifiers pass final ZIP assertions.

Final package versions are ESIR **1.4.0**, graphics packs 1–6 **1.1.0** each,
soundtracks 1–2 **1.1.0** each, and deer/walls/NSBC continuations **1.0.0** each.
[RELEASE_PACKAGES.md](RELEASE_PACKAGES.md) records every version, size and hash;
its JSON companion includes all exact required/transitive versions and archive
paths. The 1.3.41/2.0 packages, dependency lock, settings and donor saves remain
preserved. Nothing was uploaded, committed or pushed. The user subsequently
authorized the real-folder 2.1 installation, recorded in LIVE_INSTALLATION.md.
Publication order remains continuations, media, then ESIR.

The pinned 1,757-row API ledger is fully dispositioned, including 1,330 additions,
205 non-class structural changes and the 179-row runtime class cohort. No pending
or open disposition remains. The 143 new default controls were re-inventoried
against the final ZIP dump. `audit/reviewed/` retains source hashes, exact reviewed
keys and evidence hashes; `audit/default-controls-final.json` records affected
final prototypes. Bound-method corrections and the native statistics delay are
additional semantic observations documented above, rather than fabricated API
signature differences. Every shipping Lua owner matches the reviewed manifest.

`RELEASE_RECONCILIATION.json` verifies all twelve ZIP manifests, current packaged
source bytes, the ledger's evidence hashes, focused latest owner hashes, all fifty
optional entries and the 211 preserved Minigun HD baseline files. It records this
synopsis and companion report hashes plus the exact final working diff/status.
No unrelated dirty work was staged or reverted. The protected run remains pinned
for handoff, including failed diagnostic attempts and historical evidence.
The task registry is closed. Its retention snapshot is marked failed because it
correctly refuses the protected overflow junctions (first reported:
`crystal-wire-21`). This is a housekeeping protection result, separate from the
passing release reconciliation; no evidence or package was pruned.

The final wrapper preflight passes Lua/Python/PowerShell syntax, requires, assets,
module headers, pack versions, eight-locale keys/duplicates, runtime alerts and all
65 conceptual models / 208 owned sources. Its one retained failure is the old
`scripts/qc/singularity-lance/angular-results.json` encoding finding; this is
nonshipping historical evidence, preserved rather than rewritten. See
`audit/preflight-final.json`.

Remaining limits are deliberate and visible: optional content migration is not
accepted merely by a smoke pass; unsupported saves stay on their preserved 2.0
installation. K2 and original-behavior port backlogs are deferred; Gore remains
on provenance hold. Audio evidence covers bindings/envelopes, not listening.
Connected native GUI tests use real clients and the central dispatcher but do
not claim physical mouse-input certification. Multiplayer covers the documented
dedicated-server peer disconnect/rejoin, not every optional combination or two
simultaneous peers. Performance comparisons cover representative focused loads,
not an arbitrary full megabase. Neither a complete progression playthrough nor
independent native-speaker certification is claimed. The developer's launch-
pollution and recipe-buffer decisions are implemented and verified, not deferred.

### Follow-up: Construction Drones and the live installation

The user selected a compatibility fix instead of disabling Construction Drones
Forked 1.1.18. Before the fix, that fork excluded the vanilla electric drill from
its `construction_drone` collision layer but added it to ESIR's advanced and
superior drills. ESIR's later hover-layer pass also made their explicit masks
different from the vanilla drill's inherited policy. Factorio rejected the
upgrade chain during prototype loading.

The final data pass now copies the vanilla electric drill's complete collision
policy to `ei-advanced-electric-mining-drill` and
`ei-superior-electric-mining-drill`, preserving nil/default inheritance, only
when `Construction_Drones_Forked` is present. The hidden optional dependency
orders the fork before this final reconciliation. The two upgrades follow the
same collision policy as the original drill; their mining speed, productivity,
quality behavior, recipes, circuit connectors, assets and identities are
unchanged. No runtime storage, remote interface, setting or locale key is added.
Existing entities inherit the corrected prototype policy without a state rewrite.

Owners are `scripts/data-final-updates/construction-drone-compatibility.lua`,
the final require in `data-final-fixes.lua`, `info.json`, the 1.4.0 changelog and
the startup/integration blueprint's `construction-drones` contract. Death effects,
sounds and rendered bodies are inherited without modification; this compatibility
check adds no new graphical or audio claim.

Evidence under `.factorio-qc/lv21`: `selection-02.receipt.json` passes the actual
95-enabled-mod configuration with the user's settings, and
`drill-compatibility-03.receipt.json` passes final-data mask equality plus four
actual fast replacements: vanilla to advanced to superior at normal and rare
quality. Every preview admits the replacement, every old body is invalidated,
and the replacement retains the requested identity and quality. This is native
entity replacement evidence, not physical upgrade-planner mouse-input evidence.
The rebuilt main archive remains ESIR 1.4.0; the earlier candidate stays preserved.
The core package gates are repeated against `package-core-26` after this fix and
the subsequent native platform-travel decision.

The live installation separately includes the compatible Pipe Visualizer and
Even Distribution forks. Recipe Icons Improvement is disabled by user choice;
unused Data Utils and the obsolete separate Prismatic Belts Space Age asset pack
are disabled. The exact 90 external packages, five native mods, disabled entries,
settings conversion, preservation paths and real-engine verification are recorded
in LIVE_INSTALLATION.md and its JSON receipt. These convenience-mod load checks
do not change the optional content migration limits reported above.
