<a id="contract"></a>
# Arc and plasma ore smelting

Six ore routes have distinct native furnace categories. Plasma heaters recover
more molten metal without slag; arc furnaces retain their original yields.
This data-stage contract owns no runtime state, events or cadence.

## Implementation sources

- [arc-furnace.lua](../../../exotic-space-industries-remembrance/prototypes/electricity-age/arc-furnace.lua)
- [plasma-heater.lua](../../../exotic-space-industries-remembrance/prototypes/quantum-age/plasma-heater.lua)
- [productivity.lua](../../../exotic-space-industries-remembrance/prototypes/productivity.lua)

<a id="routing"></a>
## Recipe routing and recovery

The six original recipes move into `ei-arc-smelting`, accepted by arc furnaces.
Their `ei-plasma-molten-*` counterparts use `ei-plasma-smelting`, accepted only by
plasma heaters. Both machines retain `ei-arc-furnace` for other shared recipes.
Krastorio's existing arc-to-assembler conversion retains the category list.

| Input | Arc output | Plasma output | Recipe seconds |
| --- | ---: | ---: | ---: |
| 3 poor iron/copper chunks | 15 | 20 | 0.33 |
| 1 purified iron/copper/gold/lead | 40 | 50 | 0.25 |

Outputs preserve fluid identity and 900 C temperature. Only the new plasma ore
routes omit slag. Remelting, carbon and gas recipes, purification, machine speed,
power and modules remain unchanged. Finished-metal remelting must not gain the
recovery bonus, avoiding casting/remelting multiplication loops.

The existing heater technology unlocks all six variants. Names and layered
product/input/heater icons distinguish them. Death and presentation fields remain
inherited from the existing final-data owners.

<a id="research"></a>
## Research and existing saves

All five `ei-productivity-pure-ore-smelting*` tiers mirror the six ore effects:
+5% per level for poor chunks, +10% for purified ores, with the native +300% cap.
Research costs and levels are unchanged; furnace productivity modules remain
unsupported. Original recipe IDs and research definitions remain stable.

Factorio's native prototype/technology refresh supplies new unlocks and effects
on existing saves. No global reset, entity replacement, inventory cleanup or
periodic runtime service is introduced. Existing buffered slag is retained.

## Verification

`scripts/qc/plasma-smelting` compares final data with a pre-change snapshot,
checks native recipe selection and measured output at zero, inherited and capped
productivity, and reloads a real checkpoint. It verifies existing machine identity,
items, fluids, research, shared recipes and inherited presentation. Preflight and
`qc-fast` cover structure and full data loading. Headless evidence does not prove
visual GUI, native-language or optional-mod gameplay acceptance.
