# Orbital logistics native acceptance

This suite qualifies the native-first orbital logistics upgrade against **Factorio 2.1.24, build 87808**. It uses real platform hubs, inventories, requests, rockets, cargo pods, radar networks, native windows and saved worlds. Historical orbital helper receipts are not current acceptance.

## Reproduce functional checks

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 `
  -Task qc-test -Suite orbital-logistics `
  -TestProfile quality-enabled,quality-disabled `
  -Case candidate,reload,configuration -AsJson
```

The registered native driver stages private mutable source copies and the locked dependency profile. Run one Factorio process at a time. Keep shipping sources and harness inputs unchanged until managed validation/closeout finishes. A graphical checkpoint creates the save used for genuine reload and configuration-change checks.

Fixture ownership:

- `suite.lua`: scanner accounting, source filters, bulk parity, independent circuit outputs, persistence and native GUI lifecycle.
- `radar.lua`: actual dedicated/shared Universe channels, wire isolation, force isolation, presence, power and location changes.
- `cargo.lua`: actual cohort rockets, native automatic delivery, platform transfer, incoming accounting and launch guards.
- `lifecycle.lua`: adjacency, settings copies, native cloning/blueprints, ID conflicts, fairness and failover.
- `adapter.py`: stages these files into the registered native driver; no production remote interface is added.

## Accepted functional receipts

Final source qualification, completed 2026-11-03 local time:

| Profile | Managed run | Candidate | Rendered checkpoint | Reload | Configuration |
| --- | --- | ---: | ---: | ---: | ---: |
| Quality enabled | `d18f92011be449eca5394693b5a49503` | 127 | 152 | 57 | 57 |
| Quality disabled | `7726bb4ea32044199366a7b73edfa5a3` | 126 | 151 | 57 | 57 |

Every listed assertion passed. Counts include effective-mod/profile checks and repeated persistence checks; they are not counts of unique gameplay scenarios. The outer wrapper `all-profiles-navigation.log` reports `overall_status=ok`, with no source validation errors. Static preflight also passed in `preflight-navigation.log`.

Receipts and logs live in each run's `evidence.zip` under `reports/`. Screenshots remain outside the ZIP in `rendered/`. The protected task evidence root is [orbital-native-20261102](../../../.factorio-qc/orbital-native-20261102), registered as `80e261cd4fba45549860cd609e44a555`.

Dependency lock SHA-256: `8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.

Shared-runner validation also passed: 22 host tests, 12 helper checks and the seven-phase base-only native conformance matrix (`a57859cb3c87431c81a5dc0cd9196633`). The matrix covers candidate/reload, explicit failure, Lua error, missing report, tick limit and host timeout. Its intentional failures must be rejected for the expected reason. A first sandboxed host-test invocation encountered temporary-directory permissions; the authorized rerun passed all 22 tests.

All seven core suite qualification controls also passed: build dispatch, scheduler event ticks, research events, research bootstrap, induction circuits, personal alert preferences and mirroring each detected its specifically injected defect. Their child runs intentionally report failure; qualification accepts only the named expected failure with intact source validation. [final-validation.json](../../../.factorio-qc/orbital-native-20261102/final-validation.json) records the aggregate `ok` verdict, native profile counts, all seven control run IDs and zero source errors.

The [artifact verification receipt](../../../.factorio-qc/orbital-native-20261102/artifact-verification.json) verifies the four final acceptance/conformance archives against their recorded archive hashes, all 325 indexed members, the four archive-covered reproduction manifests, both exact six-image inventories and all 72 unique performance trials. It also verifies the archived samples equal the analysis input, all eight phases passed in every trial, and retained source bytes normalize to the recorded benchmark digests. [The verifier](../../../.factorio-qc/orbital-native-20261102/verify-artifacts.py) is retained alongside the evidence.

### Functional coverage

- Per-platform Need, shared items, mixed qualities, Planet/Platforms/All eligibility, active sections, multipliers, import location, circuit requests, incoming deliveries and inventory mutations. Stock on a different platform cannot satisfy another platform's Need. Planet and Platforms are overlapping eligibility views because each includes All requests.
- Bulk inventory equality against a slot reader for empty/sparse hubs, spoilage, quality on/off and a 32-cargo-bay inventory. Same-tick mutations require fresh acquisition. Native-only uplinks make zero scanner bridge reads.
- Actual mixed cohort rocket, excess requested quantities, platform-only and unrequested-quality holds, destination power loss, ownership switches, loaded paste guards, incoming cargo, native target authority and confirmed-once launch accounting.
- Actual native automatic delivery with insufficient supply/minimum delivery, without a transponder; native platform-to-platform delivery and combined incoming accounting. The native engine may split eligible mixed requests across launches; the suite does not force a packing policy.
- Unambiguous adjacency, ambiguous binding rejection, settings paste, actual clone events, blueprint ghosts/revival/overwrite, explicit ID conflicts, fairness, coordinator failover, rebuild and saved-world persistence.
- Dedicated and shared native radar channels, red/green isolation from Set requests, multiple transmitters, force isolation, empty-stock presence, power loss/reconnection and direct platform-location changes. Native radio totals never become cohort per-platform demand.

### Independent output regression

Native logistics groups share their filters. The former named ESIR output sections accidentally linked otherwise independent devices. Negative-control run `b99ec28f69794d9aa319312e890eb5c2` reproduced:

- An All scanner bank's iron output changing from 185 to 35 when a Platforms-filtered bank wrote its output.
- Transponders configured as 101 and 102 both emitting 103 after the third transponder wrote.

The scanner and cohort now detach their own output sections from named groups before writing. Scanner schema 6 and cohort schema 9 migrate derived output state while preserving player configuration. The final suite verifies independent bank outputs, all three native circuit IDs, legacy grouped-output migration and persistence after reload/configuration. Player-created group definitions are not explicitly deleted.

### Bridge publication regression

The first actual-viewer benchmark stopped before collecting accepted measurements because the baseline circuit remained at 75 after Need returned to 100. Run `d6d88b50a86749e798b125fd307cdd6d` and `performance-host-publication-negative.log` preserve that failure. A bridge read had refreshed the shared cache without waking circuit banks; the next audit therefore saw unchanged data and could not rediscover the missed publication.

Changed bridge reads now use the existing deduplicated dirty-bank queue. Unchanged reads do not enqueue work, and no polling loop, service budget or cadence was added. The final native suite verifies both stock addition and removal reach actual circuit filters through normal scheduling, without forcing a bank update: 160 and 185 respectively. The performance baseline includes this correctness repair too.

### Rendered and interaction evidence

Six English 1280×720 panels were captured and reviewed: coordinator, selector, uplink, transponder, rocket silo and platform hub. The fixture uses a god observer near the opened entity and asserts native window admission; distant `player.opened` assignments can silently fail.

- [Coordinator overview](../../../.factorio-qc/managed/d18f92011be449eca5394693b5a49503/rendered/ei-orbital-coordinator.png)
- [Named selector](../../../.factorio-qc/managed/d18f92011be449eca5394693b5a49503/rendered/ei-orbital-selector.png)
- [Uplink ownership](../../../.factorio-qc/managed/d18f92011be449eca5394693b5a49503/rendered/ei-orbital-dispatch-uplink.png)
- [Transponder and independent ID](../../../.factorio-qc/managed/d18f92011be449eca5394693b5a49503/rendered/ei-platform-transponder.png)
- [Native silo panel](../../../.factorio-qc/managed/d18f92011be449eca5394693b5a49503/rendered/rocket-silo.png)
- [Native hub panel](../../../.factorio-qc/managed/d18f92011be449eca5394693b5a49503/rendered/space-platform-hub.png)

Programmatic native GUI callbacks cover search, tabs, selectors, compact anchors, target display, ownership guards and closing viewer interest. Overview links are clicked through the actual handler and must enter native remote view and open the destination hub on another surface. Physical mouse/keyboard interaction, two-client multiplayer, all-locale rendering and full thruster-driven journeys are **not** established by these receipts. Location mutation is narrower than a complete flight. All eight locale sidecars have 63 matching keys and matching placeholders; this is structural validation, not native-speaker or rendered acceptance in every language.

## Performance gate

**Passed; retain the bulk inventory reader and batched acquisition.** Managed run `63afab879fe849bf9b07dbe1a15ce8a4` completed all 72 trials and closed with status `success`. The protected task root contains `performance.py`, `performance.lua`, `analyze-performance.py`, the captured baseline source and a genuine 50-platform seed.

The workload uses 1, 10 and 50 platforms, four separately wired banks, one actual viewer, small and large inventories, idle and active stock, and open and closed viewers. Each trial executes all eight combinations. Large inventories have 32 cargo bays per platform. Active phases have four mutations. Phase length is 480 ticks at 1/10 platforms and 1920 ticks at 50, permitting the existing bounded audit to settle between mutations without changing production cadence.

Open-viewer phases additionally query the public Need bridge for every platform every 30 ticks, exercising the same acquisition API used by cohort and diagnostic consumers. These explicit fixture calls are additional to the actual scanner window; they do not mean one production coordinator panel samples every platform's inventory. Closed-viewer phases use the ordinary wired-bank workload. Active cargo alternates 25 normal iron plates and an empty inventory, with the stack placed in the last slot; this is a sparse-inventory workload, not a dense megabase benchmark.

For each platform count, six alternating baseline/candidate pairs run separately for uninstrumented whole-engine timing and instrumented script attribution. Pair zero is discarded as warm-up: 72 sequential processes, 60 retained samples. No competing Factorio process or CPU-heavy validation runs concurrently. API counts and response latency are recorded separately from uninstrumented engine totals.

Both private scanner schema markers normalize to 9001 so both variants rebuild the seed's derived cache. Both variants use independent output sections and notify dirty banks when bridge acquisition observes a change. This prevents the old shared-group and missed-publication bugs from distorting outputs or latency. Original and normalized source hashes, workload hash and seed hash are retained. Other production code is identical between variants. The baseline otherwise preserves the captured pre-upgrade scanner; the comparison therefore includes the candidate's additional source-accounting work.

The final workload asserts native scanner-window and relative-panel admission. Earlier one-platform samples with a distant viewer are qualification-only and excluded by workload hash. API instrumentation counts inventory calls, requester reads, Need rebuilds, slot reads or bulk result entries. Script attribution uses native `LuaProfiler` objects around the actual exported update/bridge calls; it does not substitute for whole-engine timing.

The pinned engine crashes while exporting `--benchmark-verbose wholeUpdate` CSV after simulation (qualification run `e214702bdc2c4b26bd88b6b86b1940d4`). Final trials use the standard benchmark total-update summary. Per-phase script attribution is available; per-phase whole-engine timings are not claimed.

### Measured result

All 72 trials passed every workload phase. After discarding the six warm-up pairs, 60 samples remain: five baseline/candidate pairs per platform count for each measurement family. All 15 retained whole-engine pairs improved. All retained attribution pairs have identical response-latency sequences, and API counters are deterministic within each variant/phase.

| Platforms | Engine ms/update, baseline → candidate | Median paired engine change | Active script ms, baseline → candidate | Median paired script change |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.635660 → 0.572647 | −10.20% | 182.582 → 101.420 | −44.45% |
| 10 | 0.780847 → 0.669431 | −14.16% | 341.574 → 199.424 | −41.29% |
| 50 | 1.226531 → 0.880370 | −28.27% | 4245.650 → 2169.474 | −48.90% |

Absolute times are medians of the individual retained runs; percentage changes are medians of paired changes. Active script time sums the four active phases; the 50-platform phases run four times as many ticks as the smaller cases. Whole-engine figures cover the complete eight-phase workload. Individual whole-engine reductions range from 9.38–10.43%, 13.82–16.90% and 27.65–28.85%, respectively.

API activity in the large-inventory, active, open-viewer phase:

| Platforms | Inventory acquisitions, both variants | Baseline Lua slot reads | Candidate bulk calls / returned item-quality totals | Requester reads, baseline → candidate | Need rebuilds, baseline → candidate |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 118 | 82,482 | 118 / 56 | 236 → 118 | 354 → 118 |
| 10 | 263 | 183,837 | 263 / 129 | 526 → 264 | 789 → 265 |
| 50 | 3,643 | 2,546,457 | 3,643 / 1,821 | 7,286 → 3,644 | 10,929 → 3,645 |

These counts measure the named acquisition functions and their slot/bulk operations, not every Lua API call in the mod or the native implementation's internal inventory work. Native bulk counting is not assumed constant-time.

Response latency remained identical:

| Platforms | Closed-viewer active phases | Open-viewer phases with explicit bridge reads |
| ---: | ---: | ---: |
| 1 | 20–44 ticks | 4–12 ticks |
| 10 | 44–92 ticks | 4–12 ticks |
| 50 | 220–316 ticks | 12 ticks |

The gate is satisfied for this matched sparse-inventory workload: exact outputs, unchanged observation latency, lower active scanner script time and improvement in every retained whole-engine pair. This does not measure dense inventories, arbitrary megabases or the whole-engine cost of replacing scanners with native radars.

Raw samples and per-phase statistics: [performance-measurements.json](../../../.factorio-qc/orbital-native-20261102/performance-measurements.json), [performance-summary.json](../../../.factorio-qc/orbital-native-20261102/performance-summary.json). The managed evidence archive retains all native logs, workload reports, the host/workload scripts and both source variants, including their instrumented forms. Source digests in the benchmark metadata use normalized UTF-8/LF text; retained-file byte hashes are recorded separately in the artifact verification report.
