<a id="contract"></a>
# Ordinary slag recovery

Six purifier recipes recover common chunks from ordinary waste slag, with rare
metal finds. Mining remains the primary supply. Native crafting and research
own all behavior and persistence; no runtime receiver or migration is added.

## Implementation sources

- [Purifier and raw-slag recipes](../../../exotic-space-industries-remembrance/prototypes/electricity-age/purifier.lua)

Related owners: [crushed recipes](../../../exotic-space-industries-remembrance/prototypes/planet-vulcanus/vulcanus-fumaroles.lua)
remain in the [fumarole model](vulcanus-fumaroles.md#slag-recovery), and
[productivity research](../../../exotic-space-industries-remembrance/prototypes/productivity.lua)
retains all six effects, five levels, prerequisites, science and cost scaling.

<a id="yields"></a>
## Recovery contract

Raw recipes consume 100 slag; crushed recipes consume 200 crushed slag.
Sulfuric uses 25 acid in 10 seconds, nitric uses 20 acid in 8 seconds, and
morphium uses 10 morphium plus one high-energy crystal in 6 seconds.

| Raw chunk output | Sulfuric | Nitric | Morphium |
| --- | ---: | ---: | ---: |
| Coal, guaranteed | 2 | 3 | 4 |
| Iron, guaranteed | 2 | 3 | 5 |
| Copper, guaranteed | 1 | 2 | 4 |
| Sulfur, guaranteed | 1 | 2 | 3 |
| One lead, probability | 0.1 | 0.25 | 0.5 |
| One gold, probability | 0.025 | 0.1 | 0.2 |
| One uranium, probability | 0.01 | 0.05 | 0.1 |
| One neodymium, probability | 0.005 | 0.02 | 0.05 |
| Expected total | 6.14 | 10.42 | 16.85 |

Crushing adds exactly 50% expected yield per chunk product. Guaranteed amounts
multiply by 1.5, using an always-successful floor/ceiling range for half-integers.
Rare probabilities multiply by 1.5 with amount one. Crushed totals are
9.21 / 15.63 / 25.275, with minimum common outputs of 8 / 14 / 23.
Original fluid ranges, statistics exclusions, independent 0.98 high-energy and
0.02 energy-crystal rolls, icons, sorting, names and unlocks remain intact.
The existing fluid_result helper retains the crushed recipes' waste quantities.

Before upstream productivity, basic production of 25 sulfuric acid averages
2.5 sulfur, 5/6 crushed iron and 125/6 water. Producing 20 nitric acid uses
0.5 crushed gold, 10 dinitrogen-tetroxide water solution and 5 oxygen gas.
These reagents are new costs; slag is donated waste. Nitric's initial gold
recovery does not fully replace the gold used to make its reagent.

<a id="crushing"></a>
## Crushing and research

Slag crushing converts 5 slag into 10 crushed slag in 0.5 seconds. One extraction
batch needs 20 crushing crafts: 10 seconds at speed one and 9 MJ in the 900 kW
electric crusher, down from 40 seconds and 36 MJ. All six extractions retain
default allow_productivity=false, disallowing modules while native research
supplies five +10% levels. At level five, crushed recipes average
13.815 / 23.445 / 37.9125 chunks. Waste and crystal products gain no bonus.

<a id="feedback"></a>
## Lead/gold feedback constraint

At the native +300% purification and plasma-smelting caps, one recovered chunk
becomes 160 crushed metal: 4 purified ore * (50 molten * 4 / 10 per ingot) * 2
crushed metal per ingot. Leaching consumes 10 crushed metal and averages 6 slag
for lead or 8 for gold; its slag is excluded from productivity. Casting and metal
crushing have no productivity in this chain.

Crushed morphium at five extraction levels yields 1.125 lead and 0.45 gold
chunks on average. Returning both through the chain yields
1.125 * 160 * 0.6 + 0.45 * 160 * 0.8 = 165.6 crushed slag per 200 consumed
(82.8%). Nitric returns 82.8; sulfuric returns 28.8. These are expected returns,
not limits on a lucky craft. Recheck the lossy loop after any upstream change.

<a id="verification"></a>
## Verification

scripts/qc/slag-recovery checks fresh final data, recipe values, unlocks,
research/module restrictions, byproducts, presentation and feedback-chain
prototypes. Native crafting covers levels 0, 1 and 5. A pre-change save retains
selected recipes and researched levels through upgrade and checkpoint reload.
Use scripts/invoke-slag-recovery-qc.ps1 with a registered managed run. Report
native/statistical evidence separately from manual gameplay acceptance.
