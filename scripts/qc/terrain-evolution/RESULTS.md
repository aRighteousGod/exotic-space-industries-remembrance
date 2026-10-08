# Terrain Evolution implementation evidence

Implementation evidence recorded with Factorio **2.0.77**, October 7, 2026.
Reproduction commands and fixture limitations are in [README.md](README.md).
The October 8 Git delivery includes the scoped terrain implementation and preset
retune; release packaging and the deferred engine reruns are outside that delivery.

**Preset retune, October 7:** the current worktree now uses seven named processing
tiers plus Custom, with Lean at 16-tick services, 4 history visits, 4 writes and
one independently paced entity-query allowance every 32 ticks. Static configuration,
mocked scheduler and locale checks cover this revision. Native fixture reruns,
fresh final data and timing are explicitly deferred at the user's request while
Factorio is in use. **All native and timing results below describe the preceding
32-tick Lean revision, not the current retune.** The new native preset lane is
prepared but has not run. See README for the current allowance table and commands.

Current retune checks: **19,413 standalone assertions passed** using Lua 5.4.8
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

## Bounded-service stress

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

## Final data and source checks

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

## Representative factory comparison

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
