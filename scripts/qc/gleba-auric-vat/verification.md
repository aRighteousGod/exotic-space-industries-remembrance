# Gleba Auric vat verification

Engine: Factorio 2.0.77, build 84539. Main mod remains 1.3.40.
Managed run: `c4fc726065754962b8dde5c46280880e`.
Reproduction: [README](README.md).

## Production and native washing

Both global-tech-scaling configurations pass 74 final-data checks, 53 native
research/crafting checks and 132 field checks each. The baseline save contains
seven native vats with discovered basins, existing nodes, biological state and
enriched fermentation at 37.5%; candidate loading preserves those values.

| Band | Ordinary nodes | Enriched nodes | Standing capacity |
| --- | ---: | ---: | ---: |
| b1 | 2 | 4 | 6 |
| b2 | 2 | 4 | 8 |
| b3 | 4 | 6 | 12 |
| b4 | 4 | 6 | 16 |
| b5 | 6 | 8 | 20 |
| b6 | 8 | 10 | 24 |
| b7 | 10 | 12 | 28 |

Capacity saturation, one remaining slot, exhausted placement, both bloom-failure
thresholds, stale cached yield display and blocked/cleared runoff pass. A fully fed
native enriched cycle produces twelve nodes and returns through rest in 10,621 ticks
(177.02 seconds, including normal dispatcher sampling).

Each cost mode consumes 7,000 cysts through native purifier recipes. The default
configuration's observed output per 1,000 base washes is:

| Case | Gold | Spoilage | Dirty water (rounded) |
| --- | ---: | ---: | ---: |
| No bonus | 1,984 | 1,064 | 15,320 |
| Ten research levels | 3,972 | 977 | 15,070 |
| Thirty levels | 7,933 | 894 | 15,028 |
| Forty levels | 7,931 | 1,052 | 15,121 |
| Four tier-3 modules (+28%) | 2,552 | 1,042 | 15,184 |
| Ten levels and modules (+128%) | 4,543 | 989 | 14,690 |
| Twenty-nine levels and modules (capped) | 8,015 | 979 | 14,766 |

Gold scales additively and caps at four times base output; waste remains per input
batch. Statistical tolerances and fractional productivity rounding are documented
in the fixture. The native module bonus comes from final data, not a hard-coded
vanilla assumption.

Scaling enabled resolves to the configured `2^((L-1)*0.5)*10`; disabled preserves
`100 * (1 + 0.15 * L)`. Both retain six Gleba science packs and 20 seconds per unit.
The prerequisite checks and a normal queued research completion pass.

## Persistence and presentation

A real server checkpoint reload passes all 69 helper checks, including retained
research levels and modules, plus owner-side checks for all seven vats' identities,
phases, biological state, claims and cyst counts. No state-schema reset is added.

The full final-data dump completed successfully (2,070,125,526 bytes). Native English
technology/vat visual acceptance remains open: the hidden single-player client did
not advance after loading, and graphics benchmark mode did not create a local player
for GUI capture. The captured loading screen is not evidence of either panel. The
runner now requires explicit `-ShowVisualWindow` opt-in for interactive acceptance;
that path has not been exercised. Translations have not received native-speaker
acceptance, and two-client multiplayer has not been exercised.

## Static validation and boundaries

- Scoped reachable-Lua parsing passed for 416 files with no missing requires; the
  final modified runtime also passes syntax parsing and actual Factorio loading.
- New runner PowerShell syntax and scoped `git diff --check` pass.
- Both fixture Python files parse, and the independent asset staging helper passes
  an idempotent run against the staged immutable assets.
- Locale audit passes 56 checks across 16 files/eight languages, including the new
  keys, changed numerical guidance, rich-text reference and shared-cap description.
- Broad ESIR preflight was blocked by an unrelated long-path directory under
  `output/minigun-firing-offline-tests/long-paths` while enumerating Python files.
- Full blueprint audit reports unrelated minigun coverage and concurrent
  `terrain-field-report.lua` ownership findings. The Auric model and its three
  source owners have no findings.

Runtime testing exposed an existing fluidbox-index mismatch: drain recipes compact
their active boxes, so indexing the full prototype array missed runoff outputs.
The scoped correction uses each live box's native prototype, including merged
prototype lists. Blocked drainage and the complete real cycle pass with this fix.

Raw reports are under
[`../../../.factorio-qc/managed/c4fc726065754962b8dde5c46280880e`](../../../.factorio-qc/managed/c4fc726065754962b8dde5c46280880e).
