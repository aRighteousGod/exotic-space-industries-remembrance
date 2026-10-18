# Rebuild monitor implementation verification

Verified on 2026-10-12 with installed Factorio **2.0.77**. Changes remain in the
working tree; this report does not describe a commit or remote delivery. The
working tree also contains unrelated changes, which were preserved.

## Passing checks

| Lane | Result | Evidence |
| --- | --- | --- |
| Full ESIR owner fixture | 80 checks, engine exit 0 | Managed run `5336844b0b3f4c25bf6c4e00562ada7c` |
| Native 1280x720, 100% scale | 73 checks, engine exit 0; screenshot inspected | Managed run `a2353cc7e65740feb19c4c9612ef51f9` |
| Native 1280x720, 150% scale | 71 checks, engine exit 0; screenshot inspected | Managed run `208f5e32a21b40c69b37c52ca6ccdff5` |
| Native open/closed save and reload, 100% scale | 78 checks; both autosaves reloaded successfully | Managed run `34d2909cf26b41b2b2e0eeb6396ccbe8` |
| Admin responsive GUI, 100% and 150% scale | 69 checks at each scale | `.factorio-qc/rebuild-admin100-final.json`, `.factorio-qc/rebuild-admin150-final.json` |
| Scripted research regression | 114 checks | `.factorio-qc/cu/g/rebuild-research/script-output/runtime-contracts-research.json` |
| Focused Lua syntax | 27 files, no errors | `luaparser` over touched runtime files and fixture Lua |
| Runner syntax and patch whitespace | Passed | PowerShell parser; scoped `git diff --check` |
| Runtime contract audit | No blocking findings | `.factorio-qc/rebuild-contracts-final.json` |

Managed reports are under `.factorio-qc/managed/<id>/script-output/rebuild-qc.json`.
Screenshots are under `script-output/rebuild-monitor/active.png`. The later 100%
fixture includes additional cursor and stale convenience-report assertions; the
earlier 150% fixture predates those assertions. All current producer code passed
the final full-pack lane. Final full-pack artifact registration also completed
successfully; temporary companion junctions are unlinked after the engine exits.

Coverage includes all ten requested owners plus deferred synchronous orbital
rescan history, removed cohort members, water ingestion after discovery, EM rail
rescan requests, radar mixed and fully blocked cohorts, restriction census
completion/cancellation, stale generation rejection, and the 32-result ring.
The native GUI retained its machine window and held cursor. Four rows fit before
scrolling at 100%; the smaller effective viewport shows fewer at 150%.

## Performance evidence

Native profiler microbenchmarks from the final 100% GUI run:

| Work | Iterations | Total time | Approximate time per call |
| --- | ---: | ---: | ---: |
| Empty callback | 100,000 | 2.197 ms | 0.000022 ms |
| Idle monitor admission predicate | 100,000 | 25.139 ms | 0.000251 ms |
| Scalar report updates | 100,000 | 166.792 ms | 0.001668 ms |
| Detached snapshots of ten jobs | 10,000 | 385.249 ms | 0.038525 ms |

These compare isolated idle/reporting costs, not whole-save UPS. They include
loop/callback overhead and are single-machine observations, not performance
guarantees. Production ETA uses only work counters and simulation ticks.

## Limits and unrelated findings

- Sixteen fake viewers exercise bounded scheduling, joining and independent
  dismissal. Genuine two-client multiplayer has **not** been run. The native
  one-player reload lane is separate evidence.
- No keyboard-focus input injection was performed. The installed API has a focus
  setter but no focus reader; the monitor never calls it or assigns `player.opened`.
- Blueprint audit found three unrelated missing primary markers in
  `minigun-turret-HD/data-final-fixes.lua`, `lib/graphics.lua` and
  `prototypes/minigun-turret.lua`. No touched monitor model had a finding.
- Broad preflight stopped while enumerating an unrelated long path under
  `output/meshy/minigun-prototypes/prototype-2/handoff-256/firing-fixture/`.
  Therefore there is no clean aggregate preflight result.
- Wrapper `qc-runtime` staging lacked the imported helper
  `kirazy-semi-classic-mining-drill/advanced-electric-mining-drill` and failed
  before runtime. The full-pack owner lane uses the installed dependency seed
  and passed independently. The wrapper also reported existing encoding findings
  in `scripts/qc/singularity-lance/angular-results.json` and the unrelated scratch
  report `temp/anisetron-tracking-fix/blueprint-final.json`.
- Existing EM first-registration invariant repair can supersede a subsequently
  requested research generation. The fixture settles that pre-existing repair
  before research admission. This monitoring patch does not change its ordering.
- Upgrade reporting adopts owner work without adding repair/restart requests.
  Owners' existing configuration-change reconstruction behavior is unchanged.

See [README.md](README.md) for reproduction commands and fixture boundaries.
