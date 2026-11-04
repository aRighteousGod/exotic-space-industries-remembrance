# Fast iteration and targeted QC acceptance — 2026-11-03

Implementation and focused qualification are complete. The new quick and targeted
workflows passed their selected checks. No `qc-full` run was performed for this
implementation. Exact Factorio **2.1.24**, the selected dependency lock, main-mod
version **1.4.03**, concurrent gameplay work and historical receipts are preserved.
Nothing was committed, pushed or deployed.

## Operator contract

Use the [shared native-testing guide](../../skills/esir-dev/references/native-testing.md)
and repository wrapper. Specialist skills and the global QC/shim guidance now route
routine development through explicit scope:

```powershell
& ./scripts/invoke-esir-dev.ps1 -Task qc-quick -Suite induction-circuit -PlanOnly
& ./scripts/invoke-esir-dev.ps1 -Task qc-quick -Suite induction-circuit -Strict
& ./scripts/invoke-esir-dev.ps1 -Task qc-targeted -Suite induction-circuit -Strict
& ./scripts/invoke-esir-dev.ps1 -Task qc-quick -ChangedPath @('exotic-space-industries-remembrance/lib/alerts.lua','exotic-space-industries-remembrance/lib/alert-catalog.lua') -PlanOnly
& ./scripts/invoke-esir-dev.ps1 -Task qc-preview -Planet nauvis -Seed 42 -Strict
```

- Exactly one of `ChangedPath`, `ChangedSince` or `Suite` is required for the two
  scoped tasks. Plans are read-only; unknown/empty selectors fail before staging.
- Quick runs use declared candidate/profile presets and list omitted acceptance
  requirements. They do not run reload/configuration, previews, packaging or full
  data dumps. Candidate-only native rows create no unused seed/checkpoint.
- Targeted runs retain required selected cases/profile matrices and relevant data,
  asset or preview checks. Runtime-only scope avoids the full data dump. Explicit
  subsets remain labelled as subsets, with omitted requirements visible.
- Changed-path routing does not absorb unrelated dirty work. Unmapped gameplay
  receives initialization smoke and an explicit gap; strict mode fails that gap.
  Only equivalent selected candidates replace routed fallback smoke. Explicit
  smoke and extended inventory selections retain it.
- Explicit preview planet/seed requests default to requested-only coverage. Bare
  preview and full retain fixed Gaia acceptance; targeted Gaia invokes its fixed
  preview/native companion exactly once.
- Full QC remains an explicit request or authorized release gate. There is no
  automatic full escalation and no result cache. Bare `qc-test` and `qc-fast`
  preserve their existing core/full-data meanings.

## Qualification receipts

| Qualification | Result and evidence |
| --- | --- |
| Scoped guidance | Strict static-only [receipt](../../../.factorio-qc/managed/9dfb737732b64926a9bc463eb6f6e6fe/result.json); no engine work |
| Quick smoke | **ok**, 47 assertions, one scenario, no seed/checkpoint: [aggregate](../../../.factorio-qc/managed/a1d497ef00f948bf9673c68d35e4f8ae/result.json), [native receipt](../../../.factorio-qc/managed/971ddd2ebc444477a8b5f85af3f2373a/final-result.json) |
| Targeted lifecycle/settings/Quality | **ok**, eight rows, 16,250 native assertions and 39 final-data checks: [aggregate](../../../.factorio-qc/managed/ade6b9c7390741a7b1921006cf2c311c/result.json) |
| Final adverse conformance | **ok**, all seven cases: [aggregate](../../../.factorio-qc/managed/f250e1a4636b457d9ce427be4e927b02/result.json), [native receipt](../../../.factorio-qc/managed/0dd268331361497f94d383bbaf58df4a/final-result.json) |
| Targeted Gaia | **ok**, 39 final-data checks, fixed preview and one native candidate with 56 assertions: [aggregate](../../../.factorio-qc/managed/6890545c27fc4d8b9484e8d267460d2c/result.json), [native receipt](../../../.factorio-qc/managed/79952638177f4bc8abdb3943a4c39db0/final-result.json) |
| Explicit Nauvis request | **ok**, seed 42, size 1024, automatic requested-only scope, zero warnings/errors, no Gaia preview/native artifact: [compact evidence](../../../.factorio-qc/managed/f80a04afb4bf4f9cb0604f7f3ec73e92/evidence.zip), [index](../../../.factorio-qc/managed/f80a04afb4bf4f9cb0604f7f3ec73e92/evidence-index.json) |

The targeted matrix preserved ordinary reload and intended configuration repair
as distinct cases. All four bootstrap startup combinations and both Quality
profiles completed; no required row was omitted.

| Suite / profile | Candidate | Reload | Configuration | Receipt |
| --- | ---: | ---: | ---: | --- |
| Build dispatch / default | 930 | 56 | — | [899efc1c](../../../.factorio-qc/managed/899efc1c856f439789169f493141e91a/final-result.json) |
| Induction / default | 137 | 48 | 48 | [b726b477](../../../.factorio-qc/managed/b726b47716a74dd7b47d3b0b38c7b3f5/final-result.json) |
| Mirroring / Quality enabled | 7,335 | 79 | — | [ee66ece8](../../../.factorio-qc/managed/ee66ece856584576a8a29d579b1c7002/final-result.json) |
| Mirroring / Quality disabled | 7,295 | 79 | — | [d18709e6](../../../.factorio-qc/managed/d18709e65aa44dcd8782c11389d0bcca/final-result.json) |
| Bootstrap / triggers-0-flatten-0 | 44 | — | — | [77d849ae](../../../.factorio-qc/managed/77d849ae187f4c158d95449d1629de6f/final-result.json) |
| Bootstrap / triggers-0-flatten-1 | 44 | — | — | [84dd48f0](../../../.factorio-qc/managed/84dd48f09aa64952819724d78a2f8c30/final-result.json) |
| Bootstrap / triggers-1-flatten-0 | 65 | 46 | — | [4b838000](../../../.factorio-qc/managed/4b838000e342415fbb3a1e2fc2bf96c4/final-result.json) |
| Bootstrap / triggers-1-flatten-1 | 44 | — | — | [5698a512](../../../.factorio-qc/managed/5698a512c86a44c398a57335d569232a/final-result.json) |

The first bootstrap digit means effective `no_triggers`. Counts describe these
receipts; they do not replace the catalogue's behavioral contract.

## Gaia versus requested preview evidence

The fixed preview is planet `gaia`, seed 1000, size 4096. The native case separately
uses the production runtime settings factory on `esir-qc-gaia-runtime`, generating
16,384 chunks over `[-2048,-2048]` through `[2048,2048]` and asserting all
16,777,216 tiles are Gaia terrain. These are separate generation paths, so their
measured resource counts are recorded independently.

| Resource | Fixed preview | Runtime native |
| --- | ---: | ---: |
| Morphium | 41 | 4 |
| Phytogas | 70 | 6 |
| Cryoflux | 51 | 4 |
| Ammonia | 32 | 5 |
| Coal gas | 45 | 8 |
| Relic debris | 6 | 10 |

[Fixed-preview evidence](../../../.factorio-qc/managed/a427b4945d5e4dcda3c0592c35e79e16/evidence.zip)
contains the required preview and its one native child aggregate. The explicit
Nauvis request was run without `PreviewScope`; the final receipt proves automatic
selection of `requested`, with neither `gaia_required_preview` nor `gaia_native`.
Preview generation is not a claim of human visual review or rendered GUI quality.

## Host and guidance checks

- **42 Python host tests** passed: exact scope/selectors, dirty-worktree isolation,
  both rename paths/deletions, presets, complete matrices, omissions, narrow helper
  routing, explicit/fallback smoke, Gaia deduplication and child-failure propagation.
- Windows PowerShell 5.1: encoding **15**, managed helpers **12**, preview acceptance
  **20** checks passed. PowerShell 7: encoding **15** and preview acceptance **20**
  checks passed. These include requested/fixed scope and failed child/report paths.
- Native runner Python parsing, affected PowerShell parsing, fourteen affected
  skill validators, catalogue/inventory/model links and scoped Markdown checks
  passed. Forward plans for GUI, research, scheduler helpers, recipes, locale and
  shipping assets retained their intended evidence boundaries. Diff whitespace
  validation passed; normal checkout LF/CRLF notices were informational.
- Final native conformance covered success, reload, explicit failure, Lua error,
  missing terminal report, tick-limit exit zero and owned host timeout. Adverse
  cases passed by observing their required failure signatures.

## Input identity, first-launch normalization and closeout

The gameplay source fingerprint shared by the quick smoke, targeted matrix and
Gaia qualification remained unchanged through final closeout:
`b6f47a9ef230735286617d4419e62c876f8efd8aead2e1987db4052e4257ead1`.
The dependency lock remains
`8f509c61cfebdcca625577ad4ed14f2b491e1c4cf1a63260d8ca78f09130161a`.

The quick smoke/matrix harness identity was
`4be84ef2afc066a8ea19a8eb8fe56570f2cf7bfccd6175ee35d6cfed86c7dbf8`.
Final selector repair changed only `catalogue.py`, `workflows.py` and
`test_workflows.py`, producing
`ab0751f6fd7349546eb4988885913f9c6f788a861818e7d8f8e7567fe3e7f135`.
The eight-row selection and check plan were compared and remained identical.
Final host tests, adverse conformance and Gaia ran after that repair; gameplay
helpers and execution semantics did not change, so the eight gameplay rows were
not repeated solely for the selector repair.

The first quick smoke correctly failed when Factorio canonicalized mod selection
and created its initial settings file. Its [failed aggregate](../../../.factorio-qc/managed/818566ae34b346a59cc67aca10a3c3cd/result.json)
and [failed native receipt](../../../.factorio-qc/managed/08366f46d3464faf894fb235c1ee9308/final-result.json)
remain unchanged. The repair compares the exact enabled mod set and permits a
new settings file only against fresh identity-bound native prototype defaults.
Existing settings bytes, nondefault/missing/extra values, stale/wrong identities
and altered enabled selections remain strict failures.

All **25 task-owned runs** are closed. Successful runs have no closeout errors;
the two failed smoke records retain their failure status. Native/broad payloads
are compacted, while small scoped aggregate receipts remain directly readable.
Sixteen selected archives, including failed-smoke provenance, passed ZIP/hash
validation and **412 indexed entry** size/hash checks. Both final-data dumps were
retired only after all consumers finished. No Factorio process remained at the
final process check. Other tasks' runs and source edits were left alone.

## Observed costs and acceptance boundary

| Run | Observed cost |
| --- | --- |
| Quick smoke | 1 native game session, 26.7 seconds engine time; 171.4 seconds workflow before parent closeout |
| Eight-row targeted qualification | 24 native game sessions plus one data dump; 2,288.1 seconds before parent closeout |
| Final conformance | All seven cases; 126.6 seconds before parent closeout |
| Targeted Gaia | 1 native scenario (70.4 seconds), 1 fixed preview (29.0 seconds), 1 data dump; 785.8 seconds before parent closeout |
| Requested Nauvis preview | 1 preview process (25.2 seconds); 140.8 seconds including closeout |

These are observations on this workstation, not benchmarks or timing guarantees.
Exact-source hashing, dependency staging, dump consumers and compact closeout
remain real costs. The improvement is explicit scope and avoiding unnecessary
sessions/checks, without reusing stale results or weakening assertions.

This qualifies the changed orchestration and representative lifecycle/matrix
paths. It is not a new all-core/full-QC, packaging, eight-seed Gaia matrix,
performance, multiplayer or rendered-layout acceptance. Those commands and gates
retain their separate requirements. The
[earlier full strict acceptance](factorio-final-qc-gap-repairs-acceptance-2026-11-03.md)
and historical qualifications remain version/source-specific provenance.
