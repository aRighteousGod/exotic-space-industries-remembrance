# Conservative plasma smelting verification

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
