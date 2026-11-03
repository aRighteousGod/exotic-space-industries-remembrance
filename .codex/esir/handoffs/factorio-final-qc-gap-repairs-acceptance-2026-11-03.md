# Factorio 2.1.24 final QC gap repair acceptance

Completed on 2026-11-03. The fresh complete `qc-full -Strict` result is **ok**.
Fast/final-data, runtime smoke, preview, assets and packaging each report **ok**
with zero warnings and zero errors. All seven core native families passed every
required profile and phase. Required focused Gaia preview/native coverage passed.

Main-mod version remains **1.4.03**. The executable, adjacent base data and selected
profile are exact **2.1.24**. Concurrent orbital work was preserved and included in
the fresh run. This task did not commit, push or deploy changes.

- [Final strict aggregate](../../../.factorio-qc/fmqc/qc-full-a5137622f3d745228b7d144f70c38180.json)
- [Broad compact evidence](../../../.factorio-qc/managed/a5137622f3d745228b7d144f70c38180/evidence.zip)
- [Broad evidence index](../../../.factorio-qc/managed/a5137622f3d745228b7d144f70c38180/evidence-index.json)
- [Earlier native acceptance and failed broad aggregate](factorio-native-testing-acceptance-2026-11-02.md)

## Input identity and evidence validation

The common source fingerprint across broad QC, Gaia and all eleven core rows is
`25cd80b96c0e43d7fcdcf85d086f152824d008ec21787a2e4347fed71d9d2feb`.
The final independent source check still matched after execution and closeout.
The selected dependency lock remains
`8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.

All twelve current native archives, the final broad archive and fresh conformance
archive passed ZIP integrity, archive SHA-256 and indexed-entry size/hash checks.
Required cases completed with nonempty passing assertions, matching identity,
clean process verdicts and validated inputs. No row was omitted or substituted
with a receipt from an interrupted run.

The broad dump was parsed as complete JSON and its 39 required final-data
assertions passed before closeout. Its retained receipt records 2,076,028,929
bytes and SHA-256
`13036013b69a2aa58803db17ebe35b162c61048e917110d866755a125d6cf5a9`.
The raw dump and owned scratch were retired after their consumers finished.
Extracted checks remain in `reports/data-contracts.json` inside the broad archive.

## Warning disposition

| Previous warning family | Repair and verified behavior |
| --- | --- |
| Numeric item/recipe names `1`–`5` | Iterate logistic chest names. All five intended vanilla items and recipes are hidden, and all five recipes are disabled. |
| Missing `multiply-costs` setting | Use the selected dependency's `link-multiplier-to-cost`. The effective forced value is false and accumulator recipe costs are retained. |
| Missing `accumulator-v2` technology | Quiet conditional presence check preserves the SolarMatrix icon fallback and the technology-present behavior. |
| Missing shooting-speed tier 7 and mining-productivity tier 4 | Remove obsolete age entries while retaining current tier 6/tier 3 age, science and prerequisites. |
| Missing Tesla bridge categories | Quiet presence checks create the required categories once. Final weapons, ammunition and upgrade effects reference them. |
| Missing optional steel-gear recipes | Guard optional call sites. Controlled absent/present cases preserve merge, hiding and unlock behavior. |
| Parameter/NSBC helper recipes with absent arrays | Normalization and swapping treat absent or empty optional ingredient/result arrays as no-ops. Populated transformations and malformed/missing-recipe diagnostics remain tested. |
| Historical punctuation/C1 encoding findings | Preserve the exact registered receipt as informational. All other files retain ordinary encoding validation. |
| Incompatible Gaia companion | ESIR supplies the managed fixed-preview/native companion through the narrow generic preview hook. Generic fallback remains separately tested. |

The source repairs have 50 controlled host-Lua assertions plus the 39 current
final-data assertions. Effective dependency startup values are also asserted by
the native Gaia fixture. Controlled helper cases and native final-data evidence
retain their distinct scopes.

## Current native core

The eleven rows contain twenty completed phases and **16,767 passing native check
records**, plus **228 passing host postchecks**. Counts include repeated effective
profile assertions across phases and settings rows.

| Suite / profile | Candidate | Reload | Configuration | Receipt |
| --- | ---: | ---: | ---: | --- |
| Alert preferences / default | 190 | 47 | — | [effdd862](../../../.factorio-qc/managed/effdd86267dc426a8bf6b0aa94264d07/final-result.json) |
| Build dispatch / default | 930 | 56 | — | [77e8b448](../../../.factorio-qc/managed/77e8b4483cf44f5fb379665a9a35cda3/final-result.json) |
| Induction circuits / default | 137 | 48 | 48 | [e71915ac](../../../.factorio-qc/managed/e71915ac2e1646d3bf76649cc02f4bc5/final-result.json) |
| Mirroring / Quality enabled | 7,239 | 79 | — | [87cc7bf8](../../../.factorio-qc/managed/87cc7bf84ca24008b8eaa0bf686bbf48/final-result.json) |
| Mirroring / Quality disabled | 7,199 | 79 | — | [6557bbab](../../../.factorio-qc/managed/6557bbab78a143e28206c8eaff028495/final-result.json) |
| Bootstrap / no_triggers=false, flatten=false | 44 | — | — | [d92d34a0](../../../.factorio-qc/managed/d92d34a00b694648b6b95386f7093d49/final-result.json) |
| Bootstrap / no_triggers=false, flatten=true | 44 | — | — | [e47c54e6](../../../.factorio-qc/managed/e47c54e6a63c46cd805d413409d39bae/final-result.json) |
| Bootstrap / no_triggers=true, flatten=false | 65 | 46 | — | [8d666405](../../../.factorio-qc/managed/8d666405a47a4e939ea2398f0507601e/final-result.json) |
| Bootstrap / no_triggers=true, flatten=true | 44 | — | — | [9c7bf134](../../../.factorio-qc/managed/9c7bf1349ab1440f94ad1969f324d2c1/final-result.json) |
| Research events / default | 176 | 53 | — | [251da907](../../../.factorio-qc/managed/251da907638d4adab117ece11838b1f8/final-result.json) |
| Scheduler/event ticks / default | 118 | 125 | — | [79693868](../../../.factorio-qc/managed/7969386834fe4077ab4bea3c90771996/final-result.json) |

Ordinary reload preserves helper content and asserts that configuration repair did
not run accidentally. The laboratory row compares progress/inventory between the
independent candidate, saved checkpoint and reload. Induction's intended repair
is a separate phase. Historical mirroring differential counts remain provenance.

## Gaia acceptance and the observed window

The earlier window that prompted the user's question belonged to the alert
preferences graphical reload checkpoint. Player-dependent core checkpoints use
their declared ordinary fixture worlds. Gaia executes on the separate surface
`esir-qc-gaia-runtime`.

That review also found a real fixture error. Supplying a seed-only preserved-save
argument to the production settings factory selected historical generation. The
fixture now calls `get_map_gen_settings()` without that argument, then sets seed
1000. Required checks cover the native 2.1 revision, Gaia terrain expressions,
actual Gaia tiles and surface identity.

The current Gaia child passed **56 native assertions and nine host postchecks**.
It generated 16,384 chunks over bounds `[-2048,-2048]` through `[2048,2048]` and
measured **16,777,216 Gaia tiles**. The fixed preview also passed with no warnings.
[Native receipt](../../../.factorio-qc/managed/d3ad4b08d86449cda4ee8d37095e6e67/final-result.json),
[native compact evidence](../../../.factorio-qc/managed/d3ad4b08d86449cda4ee8d37095e6e67/evidence.zip)

| Resource | Runtime entities | Fixed preview entities |
| --- | ---: | ---: |
| Morphium | 4 | 41 |
| Phytogas | 6 | 70 |
| Cryoflux | 4 | 51 |
| Ammonia | 5 | 32 |
| Coal gas | 8 | 45 |
| Relic debris | 10 | 6 |

Runtime and planet-preview generation are distinct exercised paths. Both require
every resource within their measured bounds. The preview image was visually
inspected and is retained as `reports/gaia-required-seed-1000.png` in the broad
archive. This does not establish geographic-distribution, GUI layout, mouse-input
or multiplayer acceptance.

The extended qualification passed all eight policy seeds and all six isolated
resource-disable probes. Seeds are 1, 42, 1000, 424242, 8675309, 31415926,
1448790552 and 2330146955. Disable probes use seed 1000 and size 2048.
[Matrix evidence](../../../.factorio-qc/managed/3c424219ccf542508cc796a32aee5adb/evidence.zip)

Private defects were detected for a missing required relic resource and selection
of the legacy generation branch. Their child results intentionally remain failed.
[Missing-resource control](../../../.factorio-qc/managed/1b95e61357324ff68c767ca16297b7a9/final-result.json),
[legacy-generation control](../../../.factorio-qc/managed/c85a03f9309d415c9bc8a0afdc73d1a6/final-result.json)

The 2026-11-02 matrix and defect qualifications retain their original input
fingerprints. Their archives were reverified. Today's full run establishes the
focused acceptance on the current common fingerprint. Explicit custom preview
compatibility also passed with Nauvis seed 42 alongside the fixed Gaia row.
[Custom-preview evidence](../../../.factorio-qc/managed/bc4cc959dabe471ba36fdd6fea1d201f/evidence.zip)

## Encoding, runner and tooling qualification

The preserved 2.0.77 receipt remains byte-preserved with `complete=false`.
Its registered LF-normalized SHA-256 is
`2f3c5ed418b0559f74220ca2963c4bde2d4faf1156ac075afacb3a5e9bc0bc12`.
Exactly 32 punctuation-mojibake and 32 C1-control findings match the informational
preservation record. Altered content, missing evidence or differing findings fail.
`-FixEncoding` protects the registered receipt from rewriting.

Windows PowerShell 5.1.19041.7802 and PowerShell 7.6.5 each passed 15 preservation,
UTF-8, console/log deduplication, exit-code and fatal-diagnostic checks. The native
boundary restores caller encoding. Required-prototype diagnostics remain active.

Fresh conformance passed all seven cases on the updated shared runner. It covered
success, ordinary reload, explicit failure, Lua error, missing terminal report,
tick-limit exit zero and owned host timeout. Every expected adverse result was
detected and the run closed/compacted.
[Conformance receipt](../../../.factorio-qc/managed/6fc02a14f7a147fb9462614f7c5c2ac2/final-result.json)

Additional verification passed 26 Python host tests, twelve shared-helper checks,
eleven preview/matrix/failure-propagation checks, twelve strict preflight checks,
six affected skill validators and scoped whitespace checks. Blueprint validation
reported zero findings across 67 models and 214 owned sources. Dependency refresh
and a fresh diff agree on 108 declarations and 102 touchpoints.

The catalogue has 70 suites with explicit eligibility, comprising eleven active,
56 needs-port and three historical, plus 36 classified nested components. The
large shared-worktree change plan selected seventeen rows and exposed 99 uncovered
paths and ten supplementary requirements. These discovery gaps remain explicit.
Rendered, multiplayer, performance, historical migration, cryo and the full Quality
matrix retain their separately declared requirements and acceptance status.

## Closeout and provenance

The final broad run, all eleven core children, Gaia and fresh conformance are
closed and compacted. The three older successful broad/preview runs from this task
were also closed and compacted. Historical receipts and earlier failed aggregates
remain intact, including the original native integration qualification.

Task ownership is closed for the prior input-integrity failures
`aeb3eca8f8f44485a3532982911183d9`, `5b990b5d7d2245468223ab2420edf2c1` and
`5e470c6df2f24e47b8a7cca21fe12d77`. Their cleanup status remains
`protected-error`. Source-change diagnostics and protected payloads were preserved.
Other tasks' runs were left alone.

Reproduction commands and evidence boundaries are maintained in the
[native testing guide](../../skills/esir-dev/references/native-testing.md) and
[Gaia resource guide](../../skills/esir-dev/references/gaia-resource-qc.md).
