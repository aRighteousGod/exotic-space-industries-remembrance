# Runtime development contract verification

Target: installed Factorio 2.0.77. These fixtures check the shared scheduler and
the focused dispatcher adoption of the runtime development standard. Bridges
are appended only to isolated staged `control.lua` copies. They are not shipping
event registrations. Reports, frozen sources and caches belong in ignored QC
staging. No fixture establishes a UPS improvement.

## Static and advisory checks

```powershell
python -B scripts/qc/runtime-contracts/test_runtime_contract_audit.py
powershell -ExecutionPolicy Bypass -File scripts/qc/runtime-contracts/check-preflight.ps1
python -B .codex/skills/esir-dev/scripts/runtime_contract_audit.py --repo-root . --format json
powershell -ExecutionPolicy Bypass -File scripts/invoke-esir-dev.ps1 -Task preflight -AsJson
```

The Python suite uses temporary Lua sources and the real blueprint lexer. It
checks executable tokens, multiline exports, import uncertainty, caller/provider
replacement, explicit self, engine receivers, capability probes, duplicates,
exceptions, deterministic output and CLI failures. It does not evaluate Lua.

The PowerShell suite imports the actual preflight/advisory functions by AST and
stubs unrelated checks. It exercises ordinary/Strict aggregation with findings,
unavailable Python/script, nonzero exit, malformed/invalid reports, existing
failures and warnings. Its generated fixture may require normal filesystem
access to a staging `.codex` directory. The live wrapper remains the separate
repository check.

## Engine checks and differential comparison

Freeze the current main pack before editing, including pending work; use a copy,
not mutable hard links. The examples use this task's frozen path and the existing
saved connected-player fixture. Substitute a fresh baseline/run name for future
changes. Use unique run names; the staging harness does not remove old results.

```powershell
$frozen = '.factorio-qc/runtime-standards-20261005/baseline-source'
powershell -ExecutionPolicy Bypass -File scripts/invoke-runtime-contracts-qc.ps1 -RunName contract-scheduler -Mode scheduler -BaselineSource $frozen
powershell -ExecutionPolicy Bypass -File scripts/invoke-runtime-contracts-qc.ps1 -RunName contract-dispatch-before -Mode dispatch -BaselineSource $frozen -SourceRoot $frozen
powershell -ExecutionPolicy Bypass -File scripts/invoke-runtime-contracts-qc.ps1 -RunName contract-dispatch-after -Mode dispatch -BaselineSource $frozen
python -B scripts/qc/runtime-contracts/compare.py dispatch .factorio-qc/cu/g/contract-dispatch-before/script-output/runtime-contracts-dispatch.json .factorio-qc/cu/g/contract-dispatch-after/script-output/runtime-contracts-dispatch.json
powershell -ExecutionPolicy Bypass -File scripts/invoke-runtime-contracts-qc.ps1 -RunName contract-research-before -Mode research -BaselineSource $frozen -SourceRoot $frozen
powershell -ExecutionPolicy Bypass -File scripts/invoke-runtime-contracts-qc.ps1 -RunName contract-research-after -Mode research -BaselineSource $frozen
python -B scripts/qc/runtime-contracts/compare.py research .factorio-qc/cu/g/contract-research-before/script-output/runtime-contracts-research.json .factorio-qc/cu/g/contract-research-after/script-output/runtime-contracts-research.json
```

`-BaselineSource` records staging provenance; it does not select the source or
compare reports. `-SourceRoot` selects the frozen main pack. Omission stages the
current main pack. Default `-SaveInput` is `.factorio-qc/wtr/player/fixture.zip`;
dispatch requires its real connected player. Research requires at least 181
ticks and uses the existing scripted-research helper (default is 240 ticks).
The launcher may coexist with a user client for correctness checks. It never
stops that client. Concurrent-client runs are unsuitable for performance claims.

- Scheduler: actual exports, isolated scheduler storage and poisoned/counting
  clock stubs. Checks zero/nonzero timestamps, omitted fallback, one timestamp
  per nested log, returns/identity, disabled encoding/I/O and gate initialization.
  Temporary globals and storage are restored before continuing the staged run.
- Dispatch: actual registered handlers, original event/player argument identity,
  relative panels, Auric session/pending cleanup, matter watchers, root/entity
  closes and relevance admission. The unrelated-open case suppresses property
  notifications briefly to retain a stale session, restores handlers and then
  delivers that case. Placement admission is overridden without fabricating
  runtime guides; the original receivers still observe real absent-guide state.
- Research: native `research_all_technologies` flood, one coalesced fan-out,
  native queued Tesla/EM completions with `by_script == false`, original force
  and event identity, argument counts, returns, ticks and snapshots. A separate
  focused queue/flush replay after caches settle exercises the unchanged EM
  buffs/access branch; this replay is not counted as a native research event.

Comparison requires passing reports and equality of all declared trace/snapshot
fields. It does not prove equality of the entire saved world, multiplayer or
manual GUI presentation. Keep performance measurement in a separately controlled
lane.

Run the existing radar acceptance lane against the same baseline/current source:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName contract-radar-before -Fixture acceptance -Ticks 3550 -SaveInput .factorio-qc/wtr/player/fixture.zip -SourceRoot $frozen
powershell -ExecutionPolicy Bypass -File scripts/invoke-sweeping-radar-qc.ps1 -RunName contract-radar-after -Fixture acceptance -Ticks 3550 -SaveInput .factorio-qc/wtr/player/fixture.zip
```

Review each `radar-qc.json` and its stage maxima, rather than claiming that a
successful process exit alone establishes acceptance.

## Verified 2026-10-05

| Check | Result |
| --- | --- |
| Adversarial advisory suite | 26 tests passed |
| Preflight isolation suite | 18 ordinary/Strict scenarios passed |
| Installed-engine scheduler observations (`rs-s1`) | 32 assertions passed |
| GUI dispatch (`rs-db3`, `rs-dc1`) | 107 assertions each; all 20 ordered routes and checks equal |
| Research (`rs-rb2`, `rs-rc2`) | 114 assertions each; traces, arguments, returns, ticks and snapshots equal |
| Radar acceptance (`rs-radar-b1`, `rs-radar-c1`) | 62 checks each; checks and stage maxima equal |
| Conceptual blueprint structure | No findings |

Research observed 780 native scripted completions coalesced into one refresh,
then native normal Tesla and EM completion and the separate unchanged-buffs
access replay. The advisory inventoried 111 files and 1,636 exports, applied all
12 narrow contracts without stale entries, and reported 167 `game.tick` review
entries. Clock entries are review inventory, not confirmed violations.

Ordinary and Strict live preflight completed Lua/Python/PowerShell syntax, requires, locale, assets,
versions and blueprint checks. Its existing blocking encoding finding in
`scripts/qc/singularity-lance/angular-results.json` remained byte-identical to
the frozen manifest; the existing Auric/Emerald file-map warnings remained.
Python cache permission failures on the first sandboxed runs were resolved by
running with normal cache access. These findings are independent of advisory
pass/fail isolation.

Detailed reports and source fingerprints are beneath
`.factorio-qc/runtime-standards-20261005`, `.factorio-qc/cu/g` and
`.factorio-qc/radar`. The frozen source includes pending Anisetron work; separate
Anisetron file updates and a later `on_entity_damaged` hook observed during this
task were retained. Source comparison confirmed the tested dispatcher differs
from the final dispatcher only by that unrelated hook. The comparison
establishes the affected routes/records above, not entire-world equivalence.
No manual GUI, multiplayer, or controlled whole-engine UPS benchmark was run.
