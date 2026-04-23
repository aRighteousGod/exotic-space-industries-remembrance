local ei_lib = require("lib/lib")

--RECIPES
------------------------------------------------------------------------------------------------------
--alt artillery-shell
local alt_shell = table.deepcopy(ei_lib.raw.recipe["artillery-shell"])
alt_shell.name = "ei-artillery-shell"
alt_shell.ingredients = {
    {type="item",name="explosive-cannon-shell", amount=4},
    {type="item",name="ei-high-energy-crystal", amount=1},
    {type="item",name="ei-electronic-parts", amount=2},
    {type="item",name="ei-crushed-sulfur", amount=8},
    {type="item",name="radar", amount=1},
}
data:extend{alt_shell}
ei_lib.add_unlock_recipe("artillery","ei-artillery-shell")
--alt artillery-turret
local alt_shell = table.deepcopy(ei_lib.raw.recipe["artillery-turret"])
alt_shell.name = "ei-artillery-turret"
alt_shell.ingredients = {
    {type="item",name="processing-unit", amount=10},
    {type="item",name="ei-carbon", amount=40},
    {type="item",name="refined-concrete", amount=60},
    {type="item",name="ei-iron-mechanical-parts", amount=15},
    {type="item",name="ei-steel-mechanical-parts", amount=15},
    {type="item",name="ei-iron-beam", amount=5},
    {type="item",name="ei-steel-beam", amount=5},
}
data:extend{alt_shell}
ei_lib.add_unlock_recipe("artillery","ei-artillery-turret")
-- overwrite table for vanilla recipes
-- index is recipe name, value is table with new recipe data
local new_ingredients_table = {
    ["artillery-turret"] = {
    {type="item",name="processing-unit", amount=10},
    {type="item",name="tungsten-plate", amount=60},
    {type="item",name="refined-concrete", amount=60},
    {type="item",name="ei-iron-mechanical-parts", amount=15},
    {type="item",name="ei-steel-mechanical-parts", amount=15},
    {type="item",name="ei-iron-beam", amount=5},
    {type="item",name="ei-steel-beam", amount=5},
    },
    ["artillery-shell"] = {
    {type="item",name="explosive-cannon-shell", amount=4},
    {type="item",name="calcite", amount=1},
    {type="item",name="ei-electronic-parts", amount=2},
    {type="item",name="tungsten-plate", amount=4},
    {type="item",name="radar", amount=1},
    },
    ["beacon"] = {
    {type="item",name="ei-data-pipe", amount=10},
    {type="item",name="ei-electronic-parts", amount=10},
    {type="item",name="ei-gold-ingot", amount=8},
    {type="item",name="steel-plate", amount=8},
    {type="item",name="ei-energy-crystal", amount=15},
    {type="item",name="electric-engine-unit", amount=4},
    },
    ["transport-belt"] = {
        {type="item",name="iron-plate", amount=1},
        {type="item",name="ei-iron-mechanical-parts", amount=2}
    },
    ["burner-inserter"] = {
        {type="item",name="iron-plate", amount=1},
        {type="item",name="ei-copper-mechanical-parts", amount=2}
    },
    ["repair-pack"] = {
        {type="item",name="ei-copper-mechanical-parts", amount=3},
        {type="item",name="ei-iron-mechanical-parts", amount=3} 
    },
    ["iron-chest"] = {
        {type="item",name="iron-plate", amount=6},
        {type="item",name="ei-iron-beam", amount=2} 
    },
    ["steel-chest"] = {
        {type="item",name="steel-plate", amount=8},
        {type="item",name="ei-steel-beam", amount=2} 
    },
    ["gun-turret"] = {
        {type="item",name="iron-plate", amount=5},
        {type="item",name="ei-iron-mechanical-parts", amount=5},
        {type="item",name="ei-copper-mechanical-parts", amount=5}
    },
    ["heavy-armor"] = {
        {type="item",name="iron-plate", amount=40},
        {type="item",name="ei-iron-beam", amount=10},
        {type="item",name="ei-copper-beam", amount=10}
    },
    ["stone-wall"] = {
        {type="item",name="stone-brick", amount=3},
        {type="item",name="ei-iron-beam", amount=1}
    },
    ["offshore-pump"] = {
        {type="item",name="ei-copper-mechanical-parts", amount=4},
        {type="item",name="ei-iron-beam", amount=2},
        {type="item",name="pipe", amount=2}
    },
    ["pump"] = {
        {type="item",name="rp-steam-pump", amount=1},
        {type="item",name="electric-engine-unit", amount=1},
        {type="item",name="electronic-circuit", amount=1}
    },
    ["train-stop"] = {
        {type="item",name="ei-iron-beam", amount=2},
        {type="item",name="ei-iron-mechanical-parts", amount=2},
        {type="item",name="copper-plate", amount=2}
    },
    ["rail-signal"] = {
        {type="item",name="ei-copper-mechanical-parts", amount=1},
        {type="item",name="iron-plate", amount=1}
    },
    ["rail-chain-signal"] = {
        {type="item",name="ei-copper-mechanical-parts", amount=1},
        {type="item",name="iron-plate", amount=1}
    },
    ["steel-furnace"] = {
        {type="item",name="ei-steel-beam", amount=4},
        {type="item",name="stone-brick", amount=10},
        {type="item",name="stone-furnace", amount=1}
    },
    ["gate"] = {
        {type="item",name="stone-wall", amount=1},
        {type="item",name="ei-iron-beam", amount=2},
        {type="item",name="ei-copper-mechanical-parts", amount=4}
    },
    ["oil-refinery"] = {
        {type="item",name="pipe", amount=10},
        {type="item",name="ei-copper-beam", amount=10},
        {type="item",name="ei-steel-beam", amount=10},
        {type="item",name="steel-plate", amount=15},
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="stone-brick", amount=10}
    },
    ["engine-unit"] = {
        {type="item",name="ei-steam-engine", amount=1},
        {type="item",name="ei-copper-mechanical-parts", amount=1},
        {type="item",name="ei-iron-mechanical-parts", amount=1}
    },
    ["lab"] = {
        {type="item",name="ei-dark-age-lab", amount=1},
        {type="item",name="ei-copper-mechanical-parts", amount=10},
        {type="item",name="ei-iron-mechanical-parts", amount=10},
        {type="item",name="electronic-circuit", amount=10}
    },
    ["electric-engine-unit"] = {
        {type="item",name="electronic-circuit", amount=1},
        {type="item",name="engine-unit", amount=1},
        {type="item",name="copper-cable", amount=4},
        {type="item",name="ei-iron-mechanical-parts", amount=2}
    },
    ["steam-engine"] = {
        {type="item",name="pipe", amount=5},
        {type="item",name="electric-engine-unit", amount=4},
        {type="item",name="ei-steam-engine", amount=4},
        {type="item",name="ei-iron-beam", amount=2}
    },
    ["medium-electric-pole"] = {
        {type="item",name="ei-copper-beam", amount=4},
        {type="item",name="ei-iron-mechanical-parts", amount=2},
        {type="item",name="ei-insulated-wire", amount=2}
    },
    ["big-electric-pole"] = {
        {type="item",name="steel-plate", amount=2},
        {type="item",name="ei-steel-beam",amount=2},
        {type="item",name="ei-iron-mechanical-parts", amount=2},
        {type="item",name="ei-insulated-wire", amount=4}
    },
    ["substation"] = {
        {type="item",name="steel-plate", amount=3},
        {type="item",name="ei-steel-beam", amount=3},
        {type="item",name="ei-insulated-wire", amount=6},
        {type="item",name="electronic-circuit", amount=6},
        {type="item",name="concrete", amount=25}
    },
    ["assembling-machine-1"] = {
        {type="item",name="advanced-circuit", amount=2},
        {type="item",name="electric-engine-unit", amount=2},
        {type="item",name="ei-iron-beam", amount=2},
        {type="item",name="ei-copper-mechanical-parts", amount=4},
        {type="item",name="ei-steam-assembler", amount=1}
    },
    ["assembling-machine-2"] = {
        {type="item",name="ei-electronic-parts", amount=2},
        {type="item",name="ei-advanced-motor", amount=2},
        {type="item",name="ei-steel-beam", amount=4},
        {type="item",name="ei-steel-mechanical-parts", amount=8},
        {type="item",name="assembling-machine-1", amount=1},
        {type="fluid",name="lubricant", amount=25},
    },
    ["assembling-machine-3"] = {
        {type="item",name="assembling-machine-2", amount=2},
        {type="item",name="ei-advanced-motor", amount=10},
        {type="item",name="processing-unit", amount=6},
        {type="item",name="ei-carbon", amount=5},
        {type="item",name="ei-simulation-data", amount=15},
        {type="fluid",name="ei-liquid-nitrogen", amount=25},
    },
    ["chemical-plant"] = {
        {type="item",name="ei-heat-chemical-plant", amount=1},
        {type="item",name="electronic-circuit", amount=2},
        {type="item",name="electric-engine-unit", amount=2},
    },
    ["roboport"] = {
        {type="item",name="ei-electronic-parts", amount=15},
        {type="item",name="concrete", amount=50},
        {type="item",name="ei-steel-mechanical-parts", amount=45},
        {type="item",name="ei-steel-beam",amount=20},
        {type="item",name="steel-plate", amount=25},
        {type="item",name="rp-steam-roboport", amount=1}
    },
    ["logistic-robot"] = {
        {type="item",name="ei-electronic-parts", amount=2},
        {type="item",name="steel-plate", amount=4},
        {type="item",name="flying-robot-frame", amount=1},
        {type="item",name="rp-steam-logistic-bot", amount=1} 
    },
    ["construction-robot"] = {
        {type="item",name="ei-electronic-parts", amount=1},
        {type="item",name="steel-plate", amount=4},
        {type="item",name="flying-robot-frame", amount=1},
        {type="item",name="rp-steam-construction-bot", amount=1} 
    },
    ["modular-armor"] = {
        {type="item",name="advanced-circuit", amount=25},
        {type="item",name="electric-engine-unit", amount=25},
        {type="item",name="heavy-armor", amount=1},
        {type="item",name="iron-plate", amount=25},
    },
    ["exoskeleton-equipment"] = {
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="advanced-circuit", amount=10},
        {type="item",name="electric-engine-unit", amount=25},
    },
    ["discharge-defense-equipment"] = {
        {type="item",name="advanced-circuit", amount=10},
        {type="item",name="steel-plate", amount=10},
        {type="item",name="ei-insulated-wire", amount=45},
    },
    ["power-armor"] = {
        {type="item",name="modular-armor", amount=1},
        {type="item",name="ei-advanced-motor", amount=20},
        {type="item",name="ei-electronic-parts", amount=30},
        {type="item",name="ei-energy-crystal", amount=100},
    },
    ["energy-shield-equipment"] = {
        {type="item",name="advanced-circuit", amount=10},
        {type="item",name="steel-plate", amount=10},
        {type="item",name="ei-energy-crystal", amount=25},
    },
    ["personal-laser-defense-equipment"] = {
        {type="item",name="laser-turret", amount=6},
        {type="item",name="steel-plate", amount=10},
        {type="item",name="ei-energy-crystal", amount=25},
    },
    ["laser-turret"] = {
        {type="item",name="ei-steel-beam", amount=5},
        {type="item",name="steel-plate",amount=5},
        {type="item",name="advanced-circuit", amount=5},
        {type="item",name="battery", amount=5},
        {type="item",name="ei-energy-crystal", amount=10},
    },
    ["solar-panel"] = {
        {type="item",name="ei-semiconductor", amount=1},
        {type="item",name="steel-plate", amount=4},
        {type="item",name="electronic-circuit", amount=8},
    },
    ["electric-furnace"] = {
        {type="item",name="copper-cable", amount=40},
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="electronic-circuit", amount=10},
        {type="item",name="steel-furnace", amount=1},
    },
    ["radar"] = {
        {type="item",name="electronic-circuit", amount=5},
        {type="item",name="steel-plate", amount=6},
        {type="item",name="ei-iron-mechanical-parts", amount=10},
        {type="item",name="electric-engine-unit", amount=4},
    },
    ["electric-mining-drill"] = {
        {type="item",name="ei-steam-miner", amount=1},
        {type="item",name="electric-engine-unit", amount=4},
        {type="item",name="electronic-circuit", amount=4},
        {type="item",name="ei-iron-beam", amount=3},
        {type="item",name="ei-iron-mechanical-parts", amount=5},
    },
    ["big-mining-drill"] = {
        {type="item",name="electric-mining-drill", amount=4},
        {type="item",name="ei-advanced-motor", amount=10},
        {type="item",name="ei-electronic-parts", amount=10},
        {type="item",name="tungsten-carbide", amount=35},
        {type="fluid",name="ei-molten-steel", amount=250},
        {type="item",name="ei-carbon", amount=50},
    },
    ["storage-tank"] = {
        {type="item",name="steel-plate", amount=8},
        {type="item",name="ei-iron-beam", amount=4},
        {type="item",name="pipe", amount=4},
    },
    ["underground-belt"] = {
        {type="item",name="transport-belt", amount=5},
        {type="item",name="ei-iron-mechanical-parts", amount=10},
    },
    ["nuclear-reactor"] = {
        {type="item",name="concrete", amount=250},
        {type="item",name="ei-lead-ingot", amount=150},
        {type="item",name="ei-electronic-parts", amount=185},
        {type="item",name="ei-energy-crystal", amount=100},
        {type="item",name="steel-plate", amount=75},
        {type="item",name="ei-steel-beam",amount=75},
        {type="item",name="ei-fission-tech", amount=100},
    },
    ["heat-pipe"] = {
        {type="item",name="ei-basic-heat-pipe", amount=1},
        {type="item",name="ei-energy-crystal", amount=1},
        {type="item",name="steel-plate", amount=5},
    },
    ["centrifuge"] = {
        {type="item",name="ei-electronic-parts", amount=8},
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="ei-steel-beam",amount=10},
        {type="item",name="ei-lead-ingot", amount=10},
        {type="item",name="electric-engine-unit", amount=15},
        {type="item",name="ei-energy-crystal", amount=15},
    },
    ["steam-turbine"] = {
        {type="item",name="pipe", amount=10},
        {type="item",name="ei-steam-engine", amount=25},
        {type="item",name="ei-steel-mechanical-parts", amount=50},
        {type="item",name="ei-steel-beam",amount=10},
        {type="item",name="copper-plate", amount=50},
    },
    ["accumulator"] = {
        {type="item",name="ei-steel-beam", amount=4},
        {type="item",name="battery", amount=5},
        {type="item",name="ei-insulated-wire",amount=2},
        {type="item",name="electronic-circuit", amount=1},
    },
    ["stack-inserter"] = {
        {type="item",name="ei-electronic-parts", amount=5},
        {type="item",name="ei-advanced-motor", amount=4},
        {type="item",name="bulk-inserter", amount=1},
        {type="item",name="ei-energy-crystal", amount=4},
    },
    ["bulk-inserter"] = {
        {type="item",name="ei-electronic-parts", amount=5},
        {type="item",name="ei-advanced-motor", amount=2},
        {type="item",name="fast-inserter", amount=1},
        {type="item",name="ei-energy-crystal", amount=2},
    },
    ["fast-inserter"] = {
        {type="item",name="advanced-circuit", amount=1},
        {type="item",name="electric-engine-unit", amount=2},
        {type="item",name="ei-energy-crystal", amount=1},
        {type="item",name="inserter", amount=1},
    },
    ["inserter"] = {
        {type="item",name="electronic-circuit", amount=4},
        {type="item",name="electric-engine-unit", amount=1},
        {type="item",name="ei-steam-inserter", amount=1},
    },
    ["processing-unit"] = {
        {type="item",name="ei-electronic-parts", amount=1},
        {type="item",name="ei-advanced-semiconductor", amount=1},
        {type="item",name="ei-simulation-data", amount=4},
        {type="item",name="ei-crushed-gold", amount=8},
    },
    ["spidertron"] = {
        {type="item",name="tank", amount=1},
        {type="item",name="ei-steel-mechanical-parts", amount=100},
        {type="item",name="ei-advanced-motor", amount=100},
        {type="item",name="ei-high-energy-crystal", amount=40},
        {type="item",name="processing-unit", amount=40},
        {type="item",name="ei-simulation-data", amount=100},
    },
    ["power-armor-mk2"] = {
        {type="item",name="power-armor", amount=1},
        {type="item",name="low-density-structure", amount=40},
        {type="item",name="processing-unit", amount=60},
        {type="item",name="ei-high-energy-crystal", amount=40},
    },
    ["express-transport-belt"] = {
        {type="item",name="fast-transport-belt", amount=1},
        {type="item",name="ei-steel-mechanical-parts", amount=5},
        {type="item",name="ei-carbon", amount=3},
        {type="fluid", name="lubricant", amount=15},
    },
    ["express-underground-belt"] = {
        {type="item",name="fast-underground-belt", amount=2},
        {type="item",name="ei-steel-mechanical-parts", amount=30},
        {type="item",name="ei-carbon", amount=12},
        {type="fluid", name="lubricant", amount=35},
    },
    ["express-splitter"] = {
        {type="item",name="fast-splitter", amount=1},
        {type="item",name="advanced-circuit", amount=10},
        {type="item",name="ei-steel-mechanical-parts", amount=12},
        {type="item",name="ei-carbon", amount=12},
        {type="fluid", name="lubricant", amount=55},
    },
    ["firearm-magazine"] = {
        {type="item",name="ei-iron-mechanical-parts", amount=2},
    },
    ["piercing-rounds-magazine"] = {
        {type="item",name="firearm-magazine", amount=1},
        {type="item",name="ei-copper-mechanical-parts", amount=1},
        {type="item",name="ei-steel-mechanical-parts", amount=2},
    },
    ["shotgun-shell"] = {
        {type="item",name="ei-iron-mechanical-parts", amount=1},
        {type="item",name="ei-copper-mechanical-parts", amount=2},
    },
    ["piercing-shotgun-shell"] = {
        {type="item",name="shotgun-shell", amount=1},
        {type="item",name="ei-steel-mechanical-parts", amount=3},
        {type="item",name="ei-copper-mechanical-parts", amount=2},
    },
    ["rocket-silo"] = {
        {type="item",name="processing-unit", amount=100},
        {type="item",name="ei-steel-mechanical-parts",amount=100},
        {type="item",name="steel-plate", amount=100},
        {type="item",name="ei-steel-beam",amount=100},
        {type="item",name="concrete", amount=100},
        {type="item",name="ei-advanced-motor", amount=50},
    },
    ["arithmetic-combinator"] = {
        {type="item",name="electronic-circuit", amount=2},
        {type="item",name="copper-cable", amount=3},
    },
    ["decider-combinator"] = {
        {type="item",name="electronic-circuit", amount=2},
        {type="item",name="copper-cable", amount=3},
    },
    ["cannon-shell"] = {
        {type="item",name="ei-iron-beam", amount=1},
        {type="item",name="ei-ceramic", amount=2},
        {type="item",name="plastic-bar", amount=1}
    },
    ["explosive-cannon-shell"] = {
        {type="item",name="cannon-shell", amount=1},
        {type="item",name="explosives", amount=2},
    },
    ["locomotive"] = {
        {type="item",name="ei-steam-advanced-locomotive",amount=1},
        {type="item",name="advanced-circuit", amount=5},
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="engine-unit", amount=8},
        {type="item",name="electric-engine-unit", amount=8},
        {type="item",name="steel-plate", amount=30},
    },
    ["cargo-wagon"] = {
        {type="item",name="iron-plate",amount=10},
        {type="item",name="ei-iron-beam", amount=5},
        {type="item",name="steel-plate", amount=10},
        {type="item",name="ei-steel-beam", amount=2},
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="ei-steam-advanced-wagon", amount=1},
    },
    ["fluid-wagon"] = {
        {type="item",name="ei-tank-1",amount=1},
        {type="item",name="pipe", amount=4},
        {type="item",name="steel-plate", amount=8},
        {type="item",name="ei-steel-beam", amount=4},
        {type="item",name="ei-steel-mechanical-parts", amount=10},
        {type="item",name="ei-steam-advanced-fluid-wagon", amount=1},
    },
    ["long-handed-inserter"] = {
        {type="item", name="inserter", amount=1},
        {type="item", name="iron-plate", amount=1},
        {type="item", name="ei-steel-mechanical-parts", amount=1}
    },
    ["burner-mining-drill"] = {
        {type="item", name="iron-plate", amount=3},
        {type="item", name="ei-iron-mechanical-parts", amount=3},
        {type="item", name="stone-furnace", amount=1}
    },
    ["pipe"] = {
        {type="item", name="iron-plate", amount=1},
        {type="item", name="ei-iron-mechanical-parts", amount=1},
    },
    ["electronic-circuit"] = {
        {type="item", name="ei-electron-tube", amount=1},
        {type="item", name="copper-cable", amount=2},
        {type="item", name="iron-plate", amount=1}
    },
-- treat red belts with plastic
    ["fast-transport-belt"] = {
        {type="item", name="transport-belt", amount=1},
        {type="item", name="ei-iron-mechanical-parts", amount=5},
        {type="item", name="plastic-bar", amount=1}
    },
    ["fast-underground-belt"] = {
        {type="item", name="underground-belt", amount=2},
        {type="item", name="ei-iron-mechanical-parts", amount=30},
        {type="item", name="plastic-bar", amount=4}
    },
    ["fast-splitter"]= {
        {type="item", name="splitter", amount=1},
        {type="item", name="ei-iron-mechanical-parts", amount=12},
        {type="item", name="electronic-circuit", amount=8},
        {type="item", name="plastic-bar", amount=4}
    },
-- red circuits need sulfuric acid
    ["advanced-circuit"] = {
        {type="item", name="electronic-circuit", amount=2},
        {type="item", name="ei-insulated-wire", amount=4},
        {type="item", name="ei-electron-tube", amount=2},
        {type="fluid", name="sulfuric-acid", amount=5}
    },
-- batteries
    ["battery"] = {
        {type="item", name="ei-crushed-iron", amount=4},
        {type="item", name="ei-crushed-copper", amount=4},
        {type="item", name="ei-ceramic", amount=1},
        {type="fluid", name="sulfuric-acid", amount=25}
    },
-- robo frames
    ["flying-robot-frame"] = {
        {type="item", name="electric-engine-unit", amount=4},
        {type="item", name="battery", amount=2},
        {type="item", name="advanced-circuit", amount=5},
        {type="item", name="ei-steel-mechanical-parts", amount=10},
        {type="item", name="ei-electronic-parts", amount=5},
        {type="item", name="ei-energy-crystal", amount=1},
        {type="fluid", name="lubricant", amount=100}
    },
-- recipes for modules
    ["quality-module"] = {
        {type="item", name="ei-module-base", amount=1},
        {type="item", name="ei-cpu", amount=5},
        {type="item", name="electronic-circuit", amount=5},
        {type="item", name="ei-energy-crystal", amount=5},
    },
    ["quality-module-2"] = {
        {type="item", name="ei-module-base", amount=1},
        {type="item", name="quality-module", amount=2},
        {type="item", name="ei-electronic-parts", amount=5},
        {type="item", name="processing-unit", amount=5},
        {type="item", name="ei-high-energy-crystal", amount=5},
    },
    ["quality-module-3"] = {
        {type="item", name="ei-module-base", amount=1},
        {type="item", name="quality-module-2", amount=2},
        {type="item", name="ei-computing-unit", amount=5},
        {type="item", name="processing-unit", amount=5},
        {type="item", name="superconductor", amount=1},
    },
    ["speed-module"] = {
        {type="item", name="ei-module-base", amount=1},
        {type="fluid", name="ei-liquid-nitrogen", amount=25}
    },
    ["efficiency-module"] = {
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="ei-energy-crystal", amount=8},
    },
    ["productivity-module"] = {
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="advanced-circuit", amount=4},
    },
    ["efficiency-module-2"] = {
        {type="item",name="ei-simulation-data", amount=25},
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="efficiency-module", amount=2},
    },
    ["productivity-module-2"] = {
        {type="item",name="ei-simulation-data", amount=25},
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="productivity-module", amount=2},
    },
    ["speed-module-2"] = {
        {type="item",name="ei-simulation-data", amount=25},
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="speed-module", amount=2},
    },
    ["efficiency-module-3"] = {
        {type="item",name="processing-unit", amount=2},
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="efficiency-module-2", amount=2},
    },
    ["productivity-module-3"] = {
        {type="item",name="processing-unit", amount=2},
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="productivity-module-2", amount=2},
    },
    ["speed-module-3"] = {
        {type="item",name="processing-unit", amount=2},
        {type="item",name="ei-module-base", amount=1},
        {type="item",name="speed-module-2", amount=2},
    },
-- treat rocket fuel
    ["rocket-fuel"] = {
        {type="item", name="solid-fuel", amount=10},
        {type="fluid", name="ei-kerosene", amount=15},
        {type="fluid", name="ei-liquid-oxygen", amount=25},
    },
    ["heat-exchanger"] = {
        {type="item",name="ei-basic-heat-exchanger", amount=1},
        {type="item",name="ei-steel-beam", amount=2},
        {type="item",name="steel-plate", amount=6},
        {type="item",name="copper-plate", amount=75},
    },
}
--adjust categories to allow above changes
ei_lib.raw["recipe"]["advanced-circuit"].category = "crafting-with-fluid"
ei_lib.raw["recipe"]["advanced-circuit"].additional_categories = {"electronics-with-fluid"}
ei_lib.raw["recipe"]["flying-robot-frame"].category = "crafting-with-fluid"
ei_lib.raw["recipe"]["speed-module"].category = "electronics-with-fluid"
ei_lib.raw["recipe"]["assembling-machine-2"].category = "crafting-with-fluid"
ei_lib.raw["recipe"]["assembling-machine-3"].category = "crafting-with-fluid"
ei_lib.raw["recipe"]["rocket-fuel"].category = "chemistry"

--remove vanilla plate recipes in favor of varied chunk processes
local ip = ei_lib.raw["recipe"]["iron-plate"]
local cp = ei_lib.raw["recipe"]["copper-plate"]
local sp = ei_lib.raw["recipe"]["steel-plate"]

--if these aren't removed sometimes they inexplicably show back up
if ip then
    data.raw.recipe["iron-plate"] = nil
    --[[
    ip.ingredients = nil
    ip.results = nil
    ip.icon = "__core__/graphics/cancel.png"
    ip.icon_size = 64
    ip.icon_mipmaps = 4
    ip.enabled = false
    ip.hidden = true
    ]]
end
if cp then
    data.raw.recipe["copper-plate"] = nil
    --[[
    cp.ingredients = nil
    cp.results = nil
    cp.icon = "__core__/graphics/cancel.png"
    cp.icon_size = 64
    cp.icon_mipmaps = 4
    cp.enabled = false
    cp.hidden = true
    ]]
end
if sp then
    ei_lib.remove_unlock_recipe("steel-processing","steel-plate")
    data.raw.recipe["steel-plate"] = nil
    --[[
    sp.ingredients = nil
    sp.results = nil
    sp.icon = "__core__/graphics/cancel.png"
    sp.icon_size = 64
    sp.icon_mipmaps = 4
    sp.enabled = false
    sp.hidden = true
    ]]
end
--remove_recipe_unlock swaps unlocks and productivity effects using below table
local r_r_u = {
    ["steel-plate"] = "ei-steel-plate",
    ["copper-plate"] = "ei-poor-copper-chunk-smelting",
    ["iron-plate"] = "ei-poor-iron-chunk-smelting",
}
for _,tech in pairs(data.raw.technology) do
    if tech and tech.effects then
        for index in pairs(tech.effects) do
            if tech.effects[index] and tech.effects[index].recipe then
                if r_r_u[tech.effects[index].recipe] then
                    log("swapping "..tech.effects[index].recipe.." from "..tech.name.." with "..r_r_u[tech.effects[index].recipe].." due to EI using alternative recipes")
                    tech.effects[index].recipe = r_r_u[tech.effects[index].recipe]
                end
            end
        end
    end
end

--move cannon shells from tank to explosives
ei_lib.remove_unlock_recipe("tank","cannon-shell")
ei_lib.remove_unlock_recipe("tank","explosive-cannon-shell")
ei_lib.add_unlock_recipe("explosives","cannon-shell")
ei_lib.add_unlock_recipe("explosives","explosive-cannon-shell")

--alternative explosives recipes
local explosives = ei_lib.raw.recipe["explosives"]
if explosives then
    --alt 1
    local explosives_2 = table.deepcopy(explosives)
    explosives_2.ingredients = {
        {type="item",name="ei-crushed-coke", amount=6},
        {type="item",name="ei-crushed-sulfur", amount=6},
        {type="fluid",name="light-oil", amount=20},
    }
    explosives_2.results = {
        {type="item",name="explosives", amount=12},
    }
    explosives_2.name = "ei-explosives-light-crushed"
    explosives_2.energy_required =  explosives_2.energy_required * 4
    explosives_2.icons = {
        { icon = data.raw.item["ei-crushed-coke"].icon,            scale = 0.18, shift = { 4, 4 } },
        { icon = data.raw.item["ei-crushed-sulfur"].icon, scale = 0.18, shift = { -4, 4 } },
        { icon = data.raw.fluid["light-oil"].icon,            scale = 0.18, shift = { -4, -4 } },
        { icon = data.raw.item["explosives"].icon, scale = 0.2, shift = { 4, -4 } },
    }
    --alt 2
    local explosives_3 = table.deepcopy(explosives)
    explosives_3.ingredients = {
        {type="fluid",name="ei-nitric-acid", amount=270},
        {type="fluid",name="sulfuric-acid", amount=190},
        {type="item",name="solid-fuel", amount=5},
    }
    explosives_3.results = {
        {type="item",name="explosives", amount=30},
    }
    explosives_3.name = "ei-explosives-solid-sulfuric-nitric"
    explosives_3.energy_required =  explosives_3.energy_required * 12
    explosives_3.icons = {
        { icon = data.raw.fluid["ei-nitric-acid"].icon,            scale = 0.18, shift = { 4, 4 } },
        { icon = data.raw.fluid["sulfuric-acid"].icon, scale = 0.18, shift = { -4, 4 } },
        { icon = data.raw.item["solid-fuel"].icon,            scale = 0.18, shift = { -4, -4 } },
        { icon = data.raw.item["explosives"].icon, scale = 0.2, shift = { 4, -4 } },
    }
    data:extend({
        explosives_2,
        explosives_3
    })
    ei_lib.add_unlock_recipe("explosives","ei-explosives-light-crushed")
    ei_lib.add_unlock_recipe("ei-nitric-acid","ei-explosives-solid-sulfuric-nitric")
end
--Modify basic oil processing -> Oil processing
-- Steam and water equivalents are in steam_prototypes
ei_lib.raw["recipe"]["basic-oil-processing"] = {
    force_replace = true,
    ingredients = {
        {type="fluid", name="crude-oil", amount=65},
    },
    results =   {
        {type="fluid", name="ei-residual-oil", amount_min=28,amount_max=32},
        {type="fluid", name="petroleum-gas", amount_min=38,amount_max=42},
    },
    icon = ei_graphics_3_path.."graphics/other/basic-oil-processing.png",
    icon_size = 64,
    localised_name = {"recipe-name.ei-basic-oil-processing"},
}
-- treat cracking
ei_lib.raw["recipe"]["light-oil-cracking"].results = 
{
    {type="fluid", name="petroleum-gas", amount_min=18,amount_max=22},
}
ei_lib.recipe_new("heavy-oil-cracking",
{
    {type="fluid", name="heavy-oil", amount=50},
    {type="fluid", name="water", amount=50}
})
ei_lib.raw["recipe"]["heavy-oil-cracking"].icon = ei_graphics_other_path.."heavy-cracking.png"
ei_lib.raw["recipe"]["heavy-oil-cracking"].icon_size = 64
ei_lib.raw["recipe"]["heavy-oil-cracking"].results = {
    {type="fluid", name="ei-kerosene", amount_min=38,amount_max=42},
}

ei_lib.recipe_new("lubricant",
{
    {type="fluid", name="heavy-oil", amount=10},
    {type="fluid", name="ei-coal-gas", amount=10}
})
ei_lib.raw["recipe"]["lubricant"].results = {
    {type="fluid", name="lubricant", amount_min=6,amount_max=10},
    {type="fluid", name="steam", amount_min=3,amount_max=7,temperature=350},
}
local l_icon = ei_lib.raw.fluid["lubricant"].icon
local l_icon_size = ei_lib.raw.fluid["lubricant"].icon_size
ei_lib.raw.recipe["lubricant"].icon = l_icon
ei_lib.raw.recipe["lubricant"].icon_size = l_icon_size

ei_lib.raw["recipe"]["sulfuric-acid"].ingredients = {
    {type="fluid", name="water", amount=25},
    {type="item", name="ei-crushed-iron", amount=1},
    {type="item", name="sulfur", amount=3}
}
ei_lib.raw["recipe"]["sulfuric-acid"].results = {
    {type="fluid", name="sulfuric-acid", amount_min=25,amount_max=35},
}
ei_lib.recipe_new("carbon",
{
    {type="item",name="ei-coke", amount=6},
    {type="fluid", name="sulfuric-acid", amount=45},
})
--Adjust carbon outputs
ei_lib.raw["recipe"]["carbon"].results = {
    {type="item",name="carbon", amount_min=2,amount_max=3},
    {type="fluid", name="steam", amount_min=1,amount_max=5,temperature=250}
}
ei_lib.recipe_new("simple-coal-liquefaction",
{
    {type="item", name="ei-coke", amount=15},
    {type="item", name="calcite", amount=2},
    {type="fluid", name="sulfuric-acid", amount=25}
})
ei_lib.raw["recipe"]["simple-coal-liquefaction"].results = {
    {type="fluid", name="ei-residual-oil", amount_min=48,amount_max=52},
    {type="fluid", name="ei-coal-gas", amount_min=33,amount_max=37},
}
ei_lib.recipe_new("coal-liquefaction",
{
    {type="item", name="ei-crushed-coke", amount=30},
    {type="fluid", name="heavy-oil", amount=35},
    {type="fluid", name="steam", amount=50}
})
ei_lib.raw["recipe"]["coal-liquefaction"].results = {
    {type="fluid", name="ei-residual-oil", amount_min=88,amount_max=92},
    {type="fluid", name="light-oil", amount_min=3,amount_max=7},
    {type="fluid", name="ei-benzol", amount_min=38,amount_max=42},
}

-- make engine recipe in recipe-category crafting
ei_lib.raw["recipe"]["engine-unit"].category = "crafting"

-- reduce craft time of engines and electric engines
ei_lib.raw["recipe"]["engine-unit"].energy_required = 4
ei_lib.raw["recipe"]["electric-engine-unit"].energy_required = 6

for i,v in pairs(new_ingredients_table) do
    ei_lib.recipe_new(i, v)
end
