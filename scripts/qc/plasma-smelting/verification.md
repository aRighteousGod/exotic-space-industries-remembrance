# Conservative plasma smelting verification

## Neodymium extension, 2026-10-26

Verified with Factorio 2.0.77 and the live ESIR 1.3.41 working tree. Managed run
`6af56cbb38124a0aa4852e8e104ad733` (`plasma-smelting/conservative-seven-recipes`)
uses a source snapshot taken before this extension, with the original six plasma
recipes already present. The main mod version and unrelated edits are preserved.

- 130 final-data assertions passed for all seven plasma recipes, including exact
  inputs, outputs, categories, times, inherited temperatures, unlocks, icon layers,
  the +300% cap and all 35 productivity research effects.
- All 42 native furnace cases passed: seven feedstocks in both machines at zero,
  inherited +5%/+10%, and capped +300% productivity. The neodymium cases consumed
  100 inputs each: arc/plasma outputs were 2,000/2,500 without research,
  2,200/2,750 at +10%, and 8,000/10,000 at the cap. Every plasma case produced no
  slag. Native selection chose the correct exclusive recipe in each machine.
- Fourteen pre-change furnaces operated and were saved at craft boundaries.
  Loading with the extension retained identities, input inventories, stored slag,
  molten buffers and research; previously researched heater technology unlocked
  the new neodymium route. All 42 candidate machines, unlocks, production counters
  and recipe productivity bonuses survived a further save/reload.
- All 35 prior shared/arc/plasma/gas recipes matched their baseline definitions
  apart from the intended original neodymium category change. The previous six
  plasma routes, six technology definitions (excluding only new effects), and
  protected machine power, speed, module and presentation fields matched exactly.
  Death effects, hit effects, interaction sounds and Factoriopedia scenes remain
  inherited and verified at the prototype level.
- Neodymium retains the original fluid default of 15 C; the six earlier plasma
  routes retain 900 C. The fixture checks actual fluid output temperatures before
  collecting them, including existing buffered fluid after the upgrade.
- Eight locale folders passed UTF-8, 56 unique recipe-name and feedstock-token
  checks; each original arc explanation remains intact. The new labels reuse
  each locale's existing plasma-smelting prefix and accepted neodymium item name.
  The Informatron explanation now covers seven recipes and the 25-unit yield.
- Inspected the new three-layer icon at 32 and 64 pixels using final data and
  resolved live assets. The molten product, feedstock and heater badge are clear.
  Probed the installed recipe-icons companion 1.1.28 and inspected its neodymium
  rules; the existing six accepted plasma icons provided the composition pattern.
  The companion was not enabled for the furnace fixture.
- The live blueprint audit passed with zero findings across 60 models and 185
  owned sources; the live module-header audit also passed.

Repository preflight passed Lua/PowerShell syntax, requires, locale duplicates
and missing keys, asset references, pack versions, blueprints and module headers.
Its overall result remains failed for Python bytecode-cache permissions/path
lengths and three existing encoding findings: `scripts/qc/singularity-lance/angular-results.json`,
`temp/anisetron-tracking-fix/blueprint-final.json`, and
`temp/storage-audit-c/evidence-link-update.json`. Redirecting Python caches into
the managed run avoided protected cache writes but still hit Windows path limits;
the touched Python runner passed an independent AST parse.

Both `qc-fast` attempts failed while resolving the existing
`kirazy-semi-classic-mining-drill/advanced-electric-mining-drill` module. Its staged
file has a 260-character path and is byte-identical to source when read through
the Windows extended-path prefix. The focused runner uses a short mod-directory
junction and successfully loaded the full staged selection for every phase.
These repository-wide failures are separate from the focused acceptance results.

Reports are retained under
`.factorio-qc/managed/6af56cbb38124a0aa4852e8e104ad733/`: `Baseline-report.json`
(444 assertions), `Candidate-report.json` and `Save-report.json` (130,563 each,
including repeated runtime checks), `Reload-report.json` (130,691),
`script-output/plasma-final-data.json`, `locale-checks.json`, `icon-checks.json`,
`neodymium-icons.png`, `blueprint-checks.json`, logs and native checkpoint saves.
Use the current [fixture instructions](README.md) to reproduce the extension.

Native graphical UI/Factoriopedia interaction, native-speaker wording review,
optional Krastorio gameplay and two-client multiplayer were not performed.
Electricity is calculated from unchanged power/drain and throughput: arc
42 MW / 10 units per second versus plasma 94 MW / 15.625 units per second,
approximately 43% more electricity per unit without modules. The fixture supplies
electrical buffers directly, so it does not measure power consumption.

## Original six-route verification, 2026-10-19

Verified on 2026-10-19 with Factorio 2.0.77 and the live ESIR 1.3.41 working tree.
The version and pre-existing changelog edits were preserved. Managed run:
`826ac25ea8a84b828cd9eb9d33ba70d6` (`plasma-smelting/conservative-six-recipes`).

## Focused results

- 106 final-data assertions passed: six recipe IDs, categories, exact inputs,
  outputs, 900 C temperature, times, cap, unlocks, icon layers and thirty research
  effects, plus both machines' inherited presentation fields.
- 36 native furnace cases processed 100 batches each: all six feedstocks in arc
  furnaces and plasma heaters, at zero productivity, one inherited research level,
  and research above the +300% cap. Native automatic recipe selection and measured
  yields passed. Every plasma case produced zero slag.
- At zero research, 100 batches yielded 2,000 molten metal from each poor-chunk
  route and 5,000 from each purified-ore route. The capped cases yielded four times
  those amounts, retaining the intended 33.3%/25% advantage over arc smelting.
- Twelve pre-change furnaces operated before saving. After the prototype change,
  they retained their unit numbers, input items, molten buffers at 900 C, stored
  slag and research. Previously researched heater technology unlocked all six new
  recipes without a custom migration or research reset.
- Compared all 29 original arc/ore/gas recipe definitions with the baseline;
  only the six intended category changes differed. Machine power, speed, modules,
  death effects, hit effects, sounds and Factoriopedia scenes matched the baseline.
  All six relevant technology definitions matched after filtering new effects.
- Saved and reloaded a native candidate checkpoint; all 36 machines, unlocks,
  production counters and capped recipe-productivity bonuses were retained.
- All eight locale folders passed checks for 48 unique recipe labels, eight
  descriptions, valid UTF-8 and resolvable item tokens. French and Simplified
  Chinese received the two missing poor-chunk item names used by the new labels.
- Inspected a six-icon contact sheet at 32 and 64 pixels, rendered from final-data
  layers and resolved live assets. Molten metal, feedstock and heater badges are
  distinct. This is an out-of-game asset review, not native UI acceptance.
- Focused Lua/Python syntax, PowerShell parsing, whitespace and new-blueprint
  ownership/link checks passed. The engine loaded the full staged mod selection.

## Repository-wide checks and limits

Both requested wrapper commands, `preflight` and `qc-fast`, were attempted.
Their recursive scan stops at the pre-existing long-path fixture under
`output/minigun-firing-offline-tests/long-paths`. The `qc-fast` encoding scan also
flags existing files `scripts/qc/singularity-lance/angular-results.json` and
`temp/anisetron-tracking-fix/blueprint-final.json`. No unrelated files were changed.

The full blueprint audit reports three missing primary markers in the existing
untracked `minigun-turret-HD` pack; the new smelting model and its three source
owners have zero findings. These are separate from the focused engine success.

Krastorio's furnace-to-assembler conversion was reviewed for category-list
preservation, but its optional mod configuration was not run. Native-language
review, graphical GUI/Factoriopedia interaction and two-client multiplayer were
not performed. Electricity comparisons are calculated from unchanged prototype
power/drain and throughput, not measured by this electrically supplied fixture.

## Evidence and reproduction

Follow [README.md](README.md) for all phase commands. Reports, saves, logs and the
icon contact sheet are retained beneath
`.factorio-qc/managed/826ac25ea8a84b828cd9eb9d33ba70d6/`:
`Baseline-report.json`, `Candidate-report.json`, `Save-report.json`,
`Reload-report.json`, `script-output/plasma-final-data.json`, `locale-checks.json`,
`blueprint-checks.json`, `icon-checks.json`, and `plasma-icons.png`.
