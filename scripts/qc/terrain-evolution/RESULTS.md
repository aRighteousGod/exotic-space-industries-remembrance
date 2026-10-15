# Terrain Evolution implementation evidence

## Ecology V2, October 14, 2026

The worktree implements fair bounded service, persistent exposure observations,
transactional terrain ownership, the event-maintained drill registry, periodic
working-drill scars, non-expiring accepted mining requests, finite rebuild reports,
the public three-tab Ecology GUI and visibility-filtered vanilla custom alerts.
The launcher is now a saturated mechanical tree with spring, summer, autumn and
winter sprites. Its separate bounded refresh reads the viewed surface's analytical
calendar, including Fulgora's ecological phase, without writing daylight fields.
Offline retained viewers are removed before report refresh.

Current isolated **Factorio 2.0.77** evidence:

| Lane | Result | Evidence |
|---|---:|---|
| Ownership, planetary protections and surface lifecycle | 92/92 | `.factorio-qc/ev2n4/guards-final` |
| Drill registry, lifecycle, disablement and request retention | 35/35 | `.factorio-qc/ev2n4/v2` |
| Gleba species/habitats and direct fire contracts | 127/127 | `.factorio-qc/ev2n4/gleba-final` |
| Seven named presets and Custom | 136/136 | `.factorio-qc/ev2n4/presets-final`; 8,000 ticks |
| Connected GUI, native alerts and seasonal launcher | 66/66 | `.factorio-qc/ev2g4`; six reviewed screenshots |
| Elapsed autonomous wildfire | 35/35 | `.factorio-qc/ev2n4/wildfire-isolated`; 16,000 ticks |
| Native main/calendar and V2 lifecycle | 78/78 | `.factorio-qc/ev2n4/lifecycle-v2` |
| Extended mining coverage, planets, hazards and calendar | 265/265 | `.factorio-qc/ev2n5/extended-final`; 10,300 ticks |
| Named compatibility suspensions | 21/21 | `.factorio-qc/ev2n5/{TerrainEvolution,TerrainEvolution2,diurnal-dynamics}`; 1,200 ticks each |
| Native save/reload | 22/22 enabled, 24/24 startup-disabled | `.factorio-qc/ev2p2/on` and `off` |
| Older flat-index checkpoint adoption | 20/20 | `.factorio-qc/ev2p2/legacy` |

The wildfire fixture retains radius two and sustained pollution in two controlled
chunks. The diagnostic 32/35 run identified deferred authored-site insertion:
protected alien flowers appeared inside the planted forest after setup and caused
both dense Spreading candidates to be correctly rejected. The final fresh fixture
suppresses that unrelated site producer before generation, retaining production
protections, budgets, admission logic and positive native damage/spread assertions.
Fixture-local rate/probability overrides accelerate opportunities; this is not a
measurement of shipping ignition frequency.
Both modes now ignite dense and sparse forests; Contained remains nonspreading.
The earlier 29/35 and 32/35 runs and incomplete 5,000-tick presets run remain as
diagnostics, not accepted results. Gleba's action-only tree checks inject explicit
V2 observation records; they do not treat native spores as toxic pollution.

The extended fixture covers all four eligible drills, quality-dependent coverage,
overlaps, excluded ordinary drills, infinite and mismatched resources, native
depletion and mass events. Its V1 expectations were updated for bounded deferred
coverage admissions and Fulgora's independent analytical ecological phase; its
existing query cap and unchanged Fulgora daylight/rotation checks remain intact.
The earlier 262/265 result is retained as a superseded fixture diagnostic.
The compatibility lanes use presence-only stub mods to exercise ESIR's named
suspensions. They do not claim integration testing of upstream processing loops.
These last functional lanes ran in private profiles with the concurrent-process
guard explicitly bypassed; their engine timing is not used for performance gates.

The g4 connected run measures updater calls separately: GUI 133 calls, mean
0.036600 ms, p99 0.2409 ms, maximum 0.3848 ms; alerts 68 calls, mean 0.053365 ms,
p99/maximum 0.4210 ms; launcher nine calls, mean 0.024500 ms, maximum 0.0463 ms.
These exclude rendering, setup, gate checks and event callbacks. Nine launcher
samples do not establish a tail guarantee. Native alert target and vanilla-window
presence are checked; automated mouse-click navigation and network multiplayer
are not claimed. Lower Alerts controls require scrolling beyond the captured view.

The current owner-profile stress run without nested diagnostic timers
(`.factorio-qc/ev2s5`) passes all three
functional lanes and their mean <=0.10 ms/tick, service p99 <=0.50 ms and maximum
<=2 ms gates:

| Lane | Mean ms/tick | Service p99 ms | Maximum ms |
|---|---:|---:|---:|
| Default, 10,000 chunk records | 0.010124 | 0.3036 | 0.4660 |
| Default, 100,000 chunk records | 0.010403 | 0.3567 | 0.5192 |
| Full history and accelerated burst | 0.014809 | 0.4772 | 1.0099 |

Both default windows run 16,000 ticks; the burst window runs 40,000. All 1,024
accepted requests advance, 64 recovery records restore, and operation caps hold.
Six actual surfaces hold the seeded histories and drills; remote chunk populations
are metadata-only, not 100,000 fully generated inhabited chunks. Native Spreading
propagation is excluded from these default Contained measurements.
The two default windows record no tile writes. The saturated burst records 16
working-drill opportunities but no admitted working scars; the separate V2 native
fixture supplies positive working-drill admission evidence. This stress result
establishes bounded service and retained-work progress, not every effect firing.

The persistence lanes verify native registered metatables for all four lookup
facades, a saved mixed legacy/new lookup and its remaining conversion, exact tile
lineage, accepted mining requests, bootstrap report IDs, calendar ownership,
rotation and Fulgora exclusion. Startup-off restores only matching owned tuples;
an older flat-index checkpoint is adopted without reconstructing exposure.

The representative factory pair (`.factorio-qc/ev2f2/comparison.json`) passes:
disabled median **2.093283611 ms/tick**, enabled median **2.102400000 ms/tick**,
**+0.435506629%**, below the 2% gate. Each profile uses six 3,600-tick runs and
discards one warm-up. All six replay checksums agree within each profile
(`2635534384` disabled; `3761789959` enabled). This is deterministic native replay
evidence, not a claim of tested network multiplayer.

The copied source save is `ESIR 1.2.66.zip`, SHA-256
`f0ab715f13bd04cde2a6dd363f808cb2efbf0272e6b7d7d0581788f40381d7fa`.
The source identity is also recorded in `prepare-receipt.json`. Both private
profiles use identical code and matching post-run mod lists. `AspctTrainPatch`
is excluded from both because it cannot load this legacy fixture; Factorio removed
its disabled entry from both lists, so their preparation-time hashes differ from
the matching post-run hashes. Actual loaded mod names and versions also match.
Nauvis has 150,088 entities, Gaia
2,818 and Vulcanus 16,102; unsupported planets/platforms remain in the factory but
are excluded from ecology. The enabled profile confirms Lean, Restrained, periodic
scars and seasonal daylight; the disabled profile confirms zero enabled surfaces.
The original save was read/copied only.

Fresh complete loaded data (`.factorio-qc/ev2d2`) passes: the 2,069,903,297-byte
export has 60 valid transition edges, zero missing targets, all 38 approved tree
prototypes, all four eligible drills, the contained-fire contract, invisible alert
helper and four 128-pixel Graphics 6 seasonal sprites. The separate bounded-memory
JSON validator confirms the entire export is complete. All seven locale audits
report zero errors. The native prototype checksum is `2655202878`.
Earlier diagnostic `ev2s4` exceeded the burst maximum (4.8234 ms); factory pair
`ev2f1` exceeded its
2% gate (2.11185%). Both are retained separately from the current passing runs.
The current implementation reuses
finite report payloads and suppresses unchanged publications while preserving
60-tick ETA sampling and immediate actual progress. The passing stress run includes
that optimization, periodic drill scars and default-on seasonal daylight.

Standalone checks cover weighted liveness (20 plus six report checks), observation
and scheduling regressions (24), transactional history (25), alerts (85), index
facades (66,698 plus 37 actual-module migration checks), report lifecycle (23),
offline GUI lifecycle (three), and preset configuration (1,131). Population mocks
exercise six surfaces with 10,000/100,000 chunk records, full histories and drill
cache, due recovery, and the finite 100,000-visit bootstrap ceiling. These mocked
native boundaries supplement rather than replace engine evidence.
The four domain lookups use registered 256-bucket
facades; dense arrays remain authoritative and legacy maps convert within existing
budgets. All seven locale/schema checks pass. The focused blueprint audit has no
ecology findings; three unrelated minigun HD markers remain missing. Broad
preflight was blocked by an unrelated long-path artifact and is not claimed as
passing. Native Spreading is functionally tested separately; its engine propagation
cost is not included in the default Contained timing gates. No source has been
committed, pushed or packaged for this V2 closeout.

All sections below are historical evidence for their stated revisions. They do
not establish current V2 performance, defaults, GUI or migration acceptance.

## Historical defaults change, October 13, 2026

All ecology feature switches now default on. Wildfire defaults to Contained;
native spreading remains a selectable alternative. Restrained intensity, Lean
processing, planetary protections and Fulgora's independent daylight controller
remain unchanged. Future mining scars reserve recovery history by default;
earlier unrecorded scars cannot be reconstructed. Saved runtime settings and
surface overrides retain their selected values.

The fresh isolated Factorio **2.0.77** fixture passes **50/50** checks, including
native loaded settings, explicit feature disablement, scar/recovery mechanics,
protections, seasonal boundaries and Lean operation caps. Loaded defaults are
checked before unrelated modules are disabled for the fixed-deadline scar phase.
The initial run confirmed the defaults but missed that phase's old deadline under
additional query contention; the fixture now explicitly isolates those mechanics
instead of increasing shipping budgets. It does not measure coverage or UPS with
every module active.

The standalone preset suite passes **19,665** assertions, including retained
explicit disabled selections across all intensity/performance presets. All seven
locale surfaces pass the 182 schema-derived requirements and syntax screening
passes. The structural audit has no terrain/mining findings; three unrelated
missing primary markers remain in the new minigun HD pack. Historical results
below retain their original settings and revision limits.

The full `--dump-data` export failed after native acceptance because the engine
could not allocate approximately 1.7 GB with the user's game open. The fixture
therefore captures a compact native settings/transition snapshot before overrides.
The final snapshot validates **23/23 runtime boolean settings enabled**, Contained
wildfire, Lean/Restrained and **60** loaded transition edges. This is selective
loaded-state evidence, not a complete fresh prototype dump.

## Historical wildfire repair, October 12, 2026

Fresh isolated **Factorio 2.0.77** fixtures reproduce and repair autonomous
wildfire admission on the current 16-tick Lean preset. Soil degradation previously
consumed the only query allowance before optional hazards could run; a separate
deterministic seam recorded **zero** ignition admissions with degradation enabled
and **2,251** when disabled over the same 72,000 simulated ticks. Native baseline
fixtures also failed autonomous ignition in dense forests. Dense natural trees
could saturate the capped infrastructure query and falsely protect the candidate.

Optional hazards now receive their existing query lane before soil/recovery,
using an independent bounded cursor. Enabled hazard families take turns. Wildfire
selects approved native trees; its capped occupancy query excludes natural trees
before searching, while retaining protected flora, resources and infrastructure.
Changed hazard settings lazily rearm existing chunks without catch-up. Legacy
derived caches repair at the first game-available tick after loading.

| Fresh native lane | Result | Coverage |
|---|---:|---|
| Elapsed wildfire and ownership | 33/33 | Autonomous Contained/Spreading, soil on/off, dense/sparse forests, native forest damage/descendants, query caps, gates, protection, hazard fairness, legacy caches, cleanup and live settings |
| Ownership/protection guards | 91/91 | Existing terrain protections and recovery ownership |
| Gleba/fire regression | 127/127 | Native Gleba species/habitats and fire token/ownership contracts |

Contained retains finite ground flames without native tree-fire propagation.
Spreading invokes native tree fires; dense-forest assertions require actual tree
damage and descendant fire identities. Pollution greying alone does not prove
fire damage. Contained cleanup visits all owned records, preserves earlier
deadlines on same-cadence settings changes, retires flames when cadence changes
or their surface is disabled, and leaves unrelated combat fires intact.

The fresh final-data audit passes all **60** loaded applicable transitions, all
**38** approved tree prototypes and the contained-fire prototype contract.
Seven-language locale/schema audits, focused syntax checks and the blueprint
structural audit pass. The standalone preset suite passes **19,413** assertions
with mocked native boundaries; it is not an engine test.

These mechanics fixtures ran sequentially in isolated profiles while the user's
game remained open, by explicit authorization. **No current-preset UPS or
whole-engine timing claim follows from these runs.** The historical performance,
calendar, GUI and persistence evidence below retains its stated revision limits.
Wildfire defaulted off in this revision. Its configured 1% was per eligible polluted-chunk
opportunity, with a 600-second base interval: **20 simulation minutes** under
Restrained intensity with seasonal ecology disabled, before coverage delays or
turns shared with other enabled hazards.

Implementation evidence recorded with Factorio **2.0.77**, October 7, 2026.
Reproduction commands and fixture limitations are in [README.md](README.md).
The October 8 Git delivery includes the scoped terrain implementation and preset
retune; release packaging and the deferred engine reruns are outside that delivery.

**Preset retune, October 7:** that worktree introduced seven named processing
tiers plus Custom, with Lean at 16-tick services, 4 history visits, 4 writes and
one independently paced entity-query allowance every 32 ticks. Static configuration,
mocked scheduler and locale checks cover this revision. Native fixture reruns,
fresh final data and timing are explicitly deferred at the user's request while
Factorio is in use. **All native and timing results below describe the preceding
32-tick Lean revision, not the October 7 retune.** The new native preset lane was
prepared but had not run. See README for the current allowance table and commands.

October 7 retune checks: **19,413 standalone assertions passed** using Lua 5.4.8
with mocked native boundaries; Lua and PowerShell syntax screening passed. The
focused locale audit passes all seven languages and all 182 schema-derived
setting/enum locale requirements. The broader blueprint audit reports only two
unrelated missing `anisetron.md#dispatch` anchors (control.lua and anisetron.lua);
no terrain ownership/link findings. These results do not replace Factorio 2.0.77
runtime, save/reload, final-data or performance validation.

The October 8 isolated commit export reran those standalone, locale and syntax
checks successfully. Its blueprint audit passes with **zero findings** across
46 models and 118 owned sources; the unrelated ANISETRON changes are excluded.
The terrain locale auditor is self-contained, and fixture staging treats absent
optional sounds as optional instead of depending on uncommitted vehicle assets.

## Previously measured behavior

Integration, restrained ecology and seasonal daylight default on. Lean is the
default processing preset. Fulgora retains its independent day controller and is
excluded from seasonal acquisition, writes and restoration. Hazard options stay
independently off; changing intensity never enables them.

The previously measured Lean history allowance was **8 inspections per 32-tick service**, reduced
from the proposed 32 after timing checks. The other proposed Lean allowances stay
unchanged. No committed histories are discarded. A full 32,768-record tile-history
sweep takes at least **36.4 simulation minutes**, with additional contention from
tree histories and protection checks. This is a coverage limit, not accumulated
work that will later run in a burst.

Native trees use explicit Nauvis, Gaia, Vulcanus and Gleba families. Gleba spores
are not toxic industrial pollution. Cultivated plants and fruit-growing soils are
excluded. Optional destructive aging has an approved deadwood adapter only on
Nauvis. Other planetary tree families are not replaced with foreign dead trees.

## Historical native acceptance (before preset retune)

| Lane | Result | Main coverage |
|---|---:|---|
| Runtime and lifecycle | 67/67 | Calendar geometry/ownership, exact recovery, caps, live settings, real surface clear, Fulgora exclusion |
| Extended native mechanics | 265/265 | Six planets, all four drills, quality coverage, finite/infinite deposits, overlap, mass depletion, real fueled quarry, protections and hazards |
| Ownership and protection guards | 91/91 | Auric claims, cultivation, path depth, mining takeover, live recovery switches, external replacement, mixed shoreline paths, deferred deletion/regeneration, bounded surface schedules |
| Gleba and fire | 127/127 | All ten Gleba wild species, native habitats, three wetland paths, contained/spreading distinction, throttle/token limits, unrelated fire ownership |
| Compatibility presence | 21/21 | TerrainEvolution, TerrainEvolution2 and Diurnal Dynamics, seven checks each |
| Genuine save/reload | 30/30 | Five committed histories and calendar phase; normal reload 14, startup-off reload 16 |
| Connected administrator GUI | 37/37 | Actual player/native callbacks, non-admin/demotion checks, inheritance, overrides, Informatron, 180 idle ticks with zero refresh/snapshot calls |

The compatibility fixtures use inert named adapters to validate presence-based
suspension. They are not full upstream-mod behavioral integrations. Save/reload
uses a real server checkpoint, not an in-memory imitation. Multiplayer
determinism is checked with repeated native replay checksums in the factory
benchmark; a two-client network/desync session has not been run.

Positive Gaia tests select an unprotected location without clearing production
ownership. Separate tests retain authored-marker protection. Historical sites
whose distinguishing anchors disappeared cannot be reconstructed exactly.

## Historical bounded-service stress

Both windows include default-on seasonal daylight and six planetary surfaces.
Each measures **500 actual services** with a full 2,048-entry active cache,
32,768 retained tile histories, an initial 4,096-tree forest/history set, and
bounded event bursts. The second window maintains event pressure. Chunk metadata
is synthetic native generated-chunk state; map/forest construction is outside the
attributed service window.

| Generated chunk records | Mean attributed ms/tick | Service p99 ms | Maximum service ms | Operation limits |
|---:|---:|---:|---:|---|
| 10,000 | 0.004186 | 0.2328 | 0.3021 | Pass |
| 100,000 | 0.005954 | 0.3227 | 0.5471 | Pass |

All pass the 0.10 ms/tick mean, 0.50 ms service-p99 and 2 ms maximum gates.
Using service-p99 is stricter than including idle ticks in the p99 distribution.
Native-spreading fire is verified functionally but its engine propagation is
outside this attributed Lua-service measurement and is not covered by these
timing claims.

Earlier measurements are retained in ignored QC storage: the 32-history allowance
missed service p99; a fuller 16-history test had a 0.7505 ms short-window outlier.
The final 8-history preset uses longer windows and retains every committed record.
The final fixed-seed fixture paints its history region inside a fully generated,
padded area. An earlier boundary fixture correctly released three records after
native tile replacement; the padding isolates retention pressure from those
external changes without weakening production ownership checks.

## Historical final data and source checks

The refreshed final dump is **2,047,673,162 bytes**, prototype checksum
`2163322843`. Its selective audit found 186 declared transition edges, 60 loaded
applicable edges, 126 absent optional Alien Biomes sources, no missing loaded
targets, no cycles, and a longest route of 13 steps. All **38** approved tree
prototypes and four drill prototypes exist. The contained flame has no spawned
entity, zero spread, 600-tick initial/maximum life and zero lifetime extension.

All seven locale surfaces pass key, placeholder, duplicate and UTF-8 checks.
The extra translated administrator on/off labels have existing English anchors
in the administrator locale. Lua/Python/PowerShell syntax and the conceptual
blueprint audit pass for this feature.

Full repository preflight still fails on protected `.codex` Python-cache writes
and two pre-existing unrelated artifacts: `scripts/qc/singularity-lance/angular-results.json`
has suspected mojibake; `temp/anisetron-tracking-fix/blueprint-final.json` is UTF-16.
Lua syntax, missing requires, locale keys/duplicates, asset references and pack
version consistency pass. Module-header findings remain advisory.

## Historical representative factory comparison

Final measurement is recorded in `.factorio-qc/terrain-evolution/factory-comparison.json`.
Source and input provenance is in `factory-provenance.json` beside it. Both
profiles use the identical 97,525,176-byte save, the same original settings seed
and enabled dependency names. The source baseline was captured before these
terrain changes, preserving the pre-existing worktree changes. Staged main-pack
versions are `1.3.40000` on both sides to force equivalent configuration hooks;
the shipping version is unchanged.

The optional **AspctTrainPatch** add-on is disabled in both isolated profiles:
its legacy-locomotive migration fails on this save. This does not change shipping
dependencies. The save SHA-256 is
`02A517D4FAD391352FEA946D320C2F96B2C276F0B20C93C44A2D0B2D3186AC9F`.

Each repetition loads the same save and measures 3,600 updates. One warm-up is
discarded, then five samples form the median. This measures the representative
factory during initial ecology discovery; it does not claim a full year of
seasonal factory operation or mature whole-world ecological coverage.

| Profile | Median update time | Native replay checksum (all six runs) |
|---|---:|---:|
| Frozen baseline | 20.513880 ms | 2079900218 |
| Final Terrain Evolution, default-on daylight | 19.523957 ms | 3953665763 |

The observed median change is **-4.8256%**, passing the maximum **+2%** regression
gate. The negative difference is not a general speedup claim. All six source
fingerprints in the candidate provenance match the final worktree. Each profile
produced its own identical replay checksum across all six repetitions; the
profiles are expected to differ because their runtime behavior differs.
