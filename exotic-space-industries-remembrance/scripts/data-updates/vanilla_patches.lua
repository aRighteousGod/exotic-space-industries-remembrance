-- vanilla patches like changed entities/prototypes are made here

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

--====================================================================================================
--GENERIC CHANGES
--====================================================================================================

-- since there is no iron gear used in EI use iron-mechanical parts instead
for i,v in pairs(data.raw["recipe"]) do
    ei_lib.recipe_swap(i, "iron-gear-wheel", "ei-iron-mechanical-parts")
    ei_lib.recipe_swap(i, "iron-stick", "ei-copper-mechanical-parts")
end

--====================================================================================================
--CHANGES
--====================================================================================================

--MINING
------------------------------------------------------------------------------------------------------
local oreswaps = {
    ["uranium-ore"] = "ei-poor-uranium-chunk",
    ["iron-ore"] = "ei-poor-iron-chunk",
    ["copper-ore"] = "ei-poor-copper-chunk"
}
-- set output of copper and iron ore to ore chunks
for _,patch in pairs(data.raw.resource) do
    if patch and patch.minable then
        if patch.minable.result then
            if oreswaps[patch.minable.result] then
                log("ei oreswap: swapping: "..patch.minable.result.." for: "..oreswaps[patch.minable.result].." in patch: "..patch.name)
                patch.minable.result = oreswaps[patch.minable.result]
            end
        elseif patch.minable.results then
            for _,resource in pairs(patch.minable.results) do
                if oreswaps[resource] then
                    log("ei oreswap: swapping: "..resource.." for: "..oreswaps[resource].." in patch: "..patch)
                    resource = oreswaps[resource]
                end
            end
        end
    end
end

--ei_lib.raw["resource"]["iron-ore"].minable.result = "ei-poor-iron-chunk"
--ei_lib.raw["resource"]["copper-ore"].minable.result = "ei-poor-copper-chunk"


--Fulgora ruins, scrap recycling, previously below, can now be handled with merge_item
-----------------------------------------------------------------------------------------------------
--[[
replaced = {
    ["iron-gear-wheel"] = "ei-iron-mechanical-parts",
    ["iron-stick"] = "ei-iron-beam"
}

for ruin_name, ruin in pairs(data.raw["simple-entity"]) do
  if ruin.minable and ruin.minable.results then
    for i, result in ipairs(ruin.minable.results) do
      if result.type == "item" then
        local replacement = replaced[result.name]
        if replacement then
          log("ei: Replacing '"..result.name.."' with '"..replacement.."' in ruin: " .. ruin_name)
          result.name = replacement
        end
      end
    end
  end
end

for i, result in ipairs(ei_lib.raw.recipe["scrap-recycling"].results) do
    if result.type == "item" then
        local replacement = replaced[result.name]
        if replacement then
            log("ei: Replacing '"..result.name.."' with '"..replacement.."' in scrap: ")
            result.name = replacement
        end
    end
end
]]
--[[
table.insert(data.raw['simple-entity']['fulgurite'].minable.results, {
  amount_max = 1,
  amount_min = 0,
  name = "ei-alien-seed",
  type = "item"
})
]]

------------------------------------------------------------------------------------------------------

-- set furnace result inv to 2, when they have the smelting crafting category
for i,v in pairs(data.raw["furnace"]) do
    if v.crafting_categories[1] == "smelting" then
        ei_lib.raw["furnace"][i].result_inventory_size = 2
        if v.energy_source then
            if v.energy_source.fuel_categories then
                table.insert(v.energy_source.fuel_categories,"ei-rocket-fuel")
            end
        end
    end
end
for _,reactor in pairs(data.raw.reactor) do
    if reactor and reactor.energy_source then
        if reactor.energy_source.type == "burner" then
            if ei_lib.table_contains_value(reactor.energy_source.fuel_categories,"chemical") then
                table.insert(reactor.energy_source.fuel_categories,"ei-rocket-fuel")
            end
        end
    end
end

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
--TECHS
------------------------------------------------------------------------------------------------------
---
---make automation obey tech multiplier
local auto_tech = ei_lib.raw.technology["automation"]
if auto_tech then
    auto_tech.ignore_tech_cost_multiplier = false
end
--match with recipe changes
ei_lib.add_prerequisite("big-mining-drill","ei-advanced-motor")
ei_lib.add_prerequisite("big-mining-drill","ei-electronic-parts")
ei_lib.add_prerequisite("big-mining-drill","ei-carbon-manipulation")

ei_lib.raw.technology["radar"].age = "electricity-age"
local removerecipes = {
    "iron-stick",
    "iron-gear-wheel"
}
for _,technology in pairs(data.raw.technology) do
    if technology and technology.effects then
        for _,unlock in pairs(technology.effects) do
            if ei_lib.table_contains_value(removerecipes,unlock) then
                table.remove(technology.effects,unlock)
            end
        end
    end
end
ei_lib.remove_unlock_recipe("kovarex-enrichment-process", "kovarex-enrichment-process")
data.raw.recipe["kovarex-enrichment-process"].hidden = true
ei_lib.raw["technology"]["kovarex-enrichment-process"].localised_name = {"technology-name.ei-kovarex-fuel-enrichment"}
ei_lib.raw["technology"]["kovarex-enrichment-process"].localised_description = {"technology-description.ei-kovarex-fuel-enrichment"}

ei_lib.overwrite_entity_and_description("logistic-system","technology") -- overwrite to theory fluff because ei logistic containers is an post-grad tech
ei_lib.remove_unlock_recipe("logistic-system", "active-provider-chest")
ei_lib.remove_unlock_recipe("logistic-system", "buffer-chest")
ei_lib.remove_unlock_recipe("logistic-system", "requester-chest")
ei_lib.remove_unlock_recipe("logistic-robotics", "requester-chest")
ei_lib.remove_unlock_recipe("logistic-robotics", "passive-provider-chest")
ei_lib.remove_unlock_recipe("logistic-robotics", "storage-chest")
ei_lib.remove_unlock_recipe("construction-robotics", "passive-provider-chest")
ei_lib.remove_unlock_recipe("construction-robotics", "storage-chest")

--hide and disable vanilla logistic chests
local default_logi_chests = {
    "active-provider-chest",
    "buffer-chest",
    "requester-chest",
    "passive-provider-chest",
    "storage-chest"
}

for chest in pairs(default_logi_chests) do
    local hide_item = ei_lib.raw.item[chest]
    if hide_item then
        hide_item.hidden = true
        hide_item.enabled = false
    end
    local hide_recipe = ei_lib.raw.recipe[chest]
    if hide_recipe then
        hide_recipe.hidden = true
        hide_recipe.enabled = false
    end
end
--need investigate why the pre-req table doesn't always stick
ei_lib.raw["technology"]["flamethrower"].age = "steam-age"
ei_lib.raw["technology"]["concrete"].age = "steam-age"
ei_lib.set_prerequisites("concrete", {"advanced-material-processing"})
ei_lib.remove_unlock_recipe("concrete","iron-stick")
local new_prerequisites_table = {}

-- first index is tech second is prerequisite
-- changing things here can have inadvertent knock-on effects on science pack
-- requirements for technologies which use these as a prerequisite before
-- they're updated, double check things and make the changes in
-- final-updates/set_age_packs and set_prerequisites if it won't behave
new_prerequisites_table["steam-age"] = {
    {"flammables", "ei-steam-oil-processing"},
    {"automated-rail-transportation", "ei-steam-basic-train"},
    {"rail-signals", "ei-steam-basic-train"},
    {"braking-force-1", "ei-steam-basic-train"},
    {"steel-processing", "ei-steam-crusher"},
    {"engine", "ei-steam-oil-processing"},
    {"electronics", "ei-glass"},
    {"flamethrower","flammables"},
    {"concrete","advanced-material-processing"},
    {"automobilism","engine"}
}

new_prerequisites_table["electricity-age"] = {
    {"automation", "ei-electricity-power"},
    {"automation", "advanced-circuit"},
    {"fast-inserter", "automation"},
    {"fast-inserter", "ei-grower"},
    {"circuit-network", "ei-electricity-power"},
    {"lamp", "ei-electricity-power"},
    {"robotics", "ei-electronic-parts"},
--    {"lubricant", "ei-destill-tower"}, --moved to set_prerequisites
    {"sulfur-processing", "ei-destill-tower"},
    {"coal-liquefaction", "ei-benzol"},
--    {"advanced-oil-processing", "ei-electricity-age-tech"}, --moved to data
    {"laser", "ei-grower"},
    {"power-armor", "ei-grower"},
    {"solar-energy", "ei-waver-factory"},
    {"advanced-material-processing-2", "ei-electricity-power"},
    {"solar-panel-equipment", "solar-energy"},
    {"solar-panel-equipment", "advanced-circuit"},
    {"radar", "ei-electricity-power"},
    {"tank","advanced-circuit"},
    {"tank","explosives"},
    {"logistics-2","plastics"}
}

new_prerequisites_table["computer-age"] = {
    {"speed-module-2", "ei-computer-core"},
    {"productivity-module-2", "ei-computer-core"},
    {"efficiency-module-2", "ei-computer-core"},
    {"quality-module-2", "ei-computer-core"},
    {"rocket-silo", "ei-computer-age"},
    {"low-density-structure", "ei-advanced-steel"},
    {"ei-rocket-parts", "rocket-fuel"},
    {"rocket-silo", "ei-rocket-parts"},
    {"rocket-silo", "ei-advanced-motor"},
    {"rocket-silo", "processing-unit"},
    {"fission-reactor-equipment", "ei-high-temperature-reactor"},
    {"bulk-inserter","ei-advanced-motor"},
    {"inserter-capacity-bonus-1","ei-advanced-motor"}
}


new_prerequisites_table["advanced-computer-age"] = {
}

new_prerequisites_table["quantum-age"] = {

}

numbered_buffs = {
    "stronger-explosives-7",
    "mining-productivity-4",
    "research-speed-6",
    "worker-robots-speed-6",
    "worker-robots-storage-3",
    "laser-weapons-damage-7",
    "physical-projectile-damage-7",
    "refined-flammables-7",
    "inserter-capacity-bonus-7",
    "braking-force-7",
    "laser-shooting-speed-7",
    "weapon-shooting-speed-6",
    "follower-robot-count-5"
}

local prereqs_to_remove = {}

function make_numbered_buff_prerequisite(tech)

    -- get last char of tech name as number
    local tech_number = tonumber(string.sub(tech, -1))

    if tech_number == 1 then
        return 
    end

    -- get previous tech name by removing last char
    local pre = tonumber(tech_number - 1)
    local previous_tech = string.sub(tech, 1, -2)..tostring(pre)

    if not data.raw["technology"][previous_tech] then
        return
    end

    -- add previous tech to prerequisites, if it not already is there
    if data.raw["technology"][tech] then
      if data.raw["technology"][tech].prerequisites then
        if not ei_lib.table_contains_value(data.raw["technology"][tech].prerequisites, previous_tech) then
          table.insert(data.raw["technology"][tech].prerequisites, previous_tech)
        end
      end
    end

    -- remove the age tech prerequisite if the previous tech and this tech share the same age
    if data.raw["technology"][tech] then
      if data.raw["technology"][tech].age and data.raw["technology"][previous_tech].age then

          if data.raw["technology"][tech].age == data.raw["technology"][previous_tech].age then

              -- check if this tech has the age tech as prerequisite
              local age_tech = ei_data.tech_ages_with_sub_reverse[data.raw["technology"][tech].age]

              if ei_lib.table_contains_value(data.raw["technology"][tech].prerequisites, age_tech) then
                  table.insert(prereqs_to_remove, {tech, age_tech})
              end

              -- also check if the main age tech is in the previous techs prerequisites
              if ei_data.sub_age[data.raw["technology"][tech].age] then

                  local main_age_tech = ei_data.tech_ages_with_sub_reverse[ei_data.sub_age[data.raw["technology"][tech].age]]

                  if ei_lib.table_contains_value(data.raw["technology"][previous_tech].prerequisites, main_age_tech) then
                      table.insert(prereqs_to_remove, {previous_tech, main_age_tech})
                  end

              end

          end

      end
    end

    make_numbered_buff_prerequisite(previous_tech)

end
--Nerf the beacon to promote the EI specific varieties
ei_lib.raw.beacon["beacon"] = {
    localised_description = {"entity-description.ei-beacon"},
    distribution_effectivity = 0.375,
    distribution_effectivity_bonus_per_quality_level = 0.125,
    module_slots = 1,
    energy_usage = "900kW",
}
ei_lib.raw.item["beacon"] = {
    localised_description = {"item-description.ei-beacon"},
}
ei_lib.raw.technology["effect-transmission"] = {
    localised_description = {"technology-description.ei-effect-transmission"},
}
ei_lib.raw.technology["steel-processing"].icon = ei_graphics_tech_path.."steel-processing.png"
ei_lib.raw.technology["fluid-handling"] = {
    icon = ei_graphics_tech_path.."barreling.png",
    icon_size = 256,
}

ei_lib.add_unlock_recipe("automation-2", "ei-ceramic")

ei_lib.add_unlock_recipe("landfill", "ei-landfill-sand")

ei_lib.raw.technology.electronics.effects = {
    {
        type = "unlock-recipe",
        recipe = "ei-electron-tube"
    },
    {
        type = "unlock-recipe",
        recipe = "electronic-circuit"
    },
    {
        type = "unlock-recipe",
        recipe = "copper-cable"
    },
    {
        type = "unlock-recipe",
        recipe = "ei-ceramic-steam-assembler"
    },
}
--rename to Electric chemical plant
ei_lib.raw.technology["oil-processing"] = {
    localised_name = {"technology-name.ei-oil-processing"},
    localised_description = {"technology-description.ei-oil-processing"}
}
--remove doubled up unlocks
ei_lib.remove_unlock_recipe("oil-processing", "oil-refinery")
ei_lib.remove_unlock_recipe("oil-processing", "basic-oil-processing")
ei_lib.remove_unlock_recipe("oil-processing", "solid-fuel-from-petroleum-gas")
--remove advanced oil processing
ei_lib.remove_unlock_recipe("advanced-oil-processing", "advanced-oil-processing")
ei_lib.raw.technology["advanced-oil-processing"] = {
    localised_name = {"technology-name.ei-advanced-oil-processing"},
    localised_description = {"technology-description.ei-advanced-oil-processing"}
}
--delete it outright to prevent misunderstandings of whether removal is intentional
ei_lib.raw.recipe["advanced-oil-processing"].hidden = true


-- edit electric enigne tech to use only steam age science for progression
--ei_lib.set_age_packs("electric-engine","steam-age")

-- make inserter-capaity-bonus-1 buff normal inserters

table.insert(ei_lib.raw.technology["inserter-capacity-bonus-1"].effects,
{
        type = "inserter-stack-size-bonus",
        modifier = 1
    }
)

--Remove vanilla nuclear fuel reprocessing
ei_lib.remove_unlock_recipe("nuclear-fuel-reprocessing","nuclear-fuel-reprocessing")
--Remove vanilla uranium processing in favor of EI complex processing
ei_lib.remove_unlock_recipe("uranium-processing", "uranium-processing")
ei_lib.remove_unlock_recipe("uranium-processing", "uranium-fuel-cell")
ei_lib.raw.recipe["uranium-processing"].hidden = true
ei_lib.raw.technology["nuclear-fuel-reprocessing"].hidden = true
--Move the recipe to 235 recycling
ei_lib.add_unlock_recipe("ei-uranium-235-recycling","nuclear-fuel-reprocessing")

--Bring nuclear fuel aka Uranium-235 fuel cell recipe in line with fuel rods
ei_lib.recipe_add("nuclear-fuel","ei-lead-ingot",1)
ei_lib.recipe_add("nuclear-fuel","ei-ceramic",4)
ei_lib.recipe_add("nuclear-fuel","uranium-238",1)
--Move fuel cell and depleted cell into Nuclear category
ei_lib.raw.recipe["nuclear-fuel"] = {
    subgroup = "ei-nuclear-fission-fuel",
}
--Update names and descriptions, set spent result
ei_lib.raw.item["nuclear-fuel"] = {
    localised_name = {"item-name.ei-nuclear-fuel"},
    localised_description = {"item-description.ei-nuclear-fuel"},
    subgroup = "ei-nuclear-fission-fuel",
    burnt_result = "depleted-uranium-fuel-cell",
    icon = ei_graphics_3_path.."graphics/items/uranium-fuel-cell.png",
    icon_size = 256,
    icon_mipmaps = 4,
    stack_size=20,
    fuel_top_speed_multiplier=1.25,
}
ei_lib.raw.recipe["nuclear-fuel-reprocessing"] = {
    localised_name = {"recipe-name.ei-depleted-uranium-fuel-cell"},
    subgroup = "ei-nuclear-processing",
    category="chemistry"
    
}
ei_lib.raw.item["depleted-uranium-fuel-cell"] = {
    localised_name = {"item-name.ei-depleted-uranium-fuel-cell"},
    localised_description = {"item-description.ei-depleted-uranium-fuel-cell"},
    subgroup = "ei-nuclear-fission-fuel",
    icon = ei_graphics_3_path.."graphics/items/depleted-uranium-fuel-cell.png",
    icon_size = 256,
    icon_mipmaps = 4,
    stack_size=20,
}
--Remove vanilla uranium fuel cell
ei_lib.remove_unlock_recipe("nuclear-power","uranium-fuel-cell")
--Swap fission reactor recipe input
ei_lib.recipe_swap("fission-reactor-equipment","uranium-fuel-cell","ei-uranium-235-fuel",6)
--set fuel cell recycling to use fuel aka 235 fuel cell, etc
ei_lib.raw.recipe["nuclear-fuel-reprocessing"] = {
    ingredients = {
        {type="item",name="depleted-uranium-fuel-cell",amount=1},
        {type="fluid",name="ei-nitric-acid",amount=15}
    },
    results = {
        {type="item",name="ei-nuclear-waste",amount=1,probability=0.33},
        {type="fluid",name="ei-nitric-acid-uranium-235",amount=15}
    },
    main_product = "ei-nitric-acid-uranium-235",
}
--FUEL CATEGORIES
------------------------------------------------------------------------------------------------------

ei_lib.raw.item["rocket-fuel"].fuel_category = "ei-rocket-fuel"

ei_lib.raw.item["nuclear-fuel"].fuel_category = "ei-nuclear-fuel-cell"

--ITEM SUBGROUPS
------------------------------------------------------------------------------------------------------

-- move iron and copper plates to plates subgroup
ei_lib.raw["item"]["iron-plate"] = {
    subgroup = "ei-refining-plate",
    order = "a1",
}
ei_lib.raw["item"]["copper-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["copper-plate"].order = "a2"

-- set train, cargo wagon, fluid wagon and artillery wagon to new ei_trains subgroup
ei_lib.raw["item-with-entity-data"]["locomotive"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["locomotive"].order = "c1"
ei_lib.raw["item-with-entity-data"]["cargo-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["cargo-wagon"].order = "c2"
ei_lib.raw["item-with-entity-data"]["fluid-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["fluid-wagon"].order = "c3"
ei_lib.raw["item-with-entity-data"]["artillery-wagon"].subgroup = "ei-trains"
ei_lib.raw["item-with-entity-data"]["artillery-wagon"].order = "c4"

ei_lib.raw["item"]["steel-plate"].subgroup = "ei-refining-plate"
ei_lib.raw["item"]["steel-plate"].order = "a3"

ei_lib.raw["item"]["lab"].subgroup = "ei-labs"
ei_lib.raw["item"]["lab"].order = "a2"

ei_lib.raw["fluid"]["lubricant"].order = "a[fluid]-d[lubricant]"

--OTHER
------------------------------------------------------------------------------------------------------

--increase assembling machine energy usage and pollution
local a1 = ei_lib.raw["assembling-machine"]["assembling-machine-1"]
local a2 = ei_lib.raw["assembling-machine"]["assembling-machine-2"]
local a3 = ei_lib.raw["assembling-machine"]["assembling-machine-3"]
if a1 then 
    a1.energy_usage = "232.5kW" --def 77.5
    a1.energy_source.emissions_per_minute.pollution = 5 --def 4
end
if a2 then
    a2.energy_usage = "465kW" --def 155
    a2.energy_source.emissions_per_minute.pollution = 4 --def 3
end
if a3 then
    a3.energy_usage = "1164kW" --def 388
    a3.energy_source.emissions_per_minute.pollution = 4 --def 2
end

-- set fluid burn values for crude, light, heavy - oil and petrol
ei_lib.raw["fluid"]["crude-oil"] = {
    fuel_value = "100kJ",
    fuel_emissions_multiplier = 1.25
}
ei_lib.raw["fluid"]["heavy-oil"] =  {
    fuel_value = "500kJ",
    fuel_emissions_multiplier = 1.1
}
ei_lib.raw["fluid"]["petroleum-gas"] = {
    fuel_value = "800kJ",
    fuel_emissions_multiplier = 0.7
}
ei_lib.raw["fluid"]["light-oil"] = {
    fuel_value = "1000kJ",
    fuel_emissions_multiplier = 0.8
}
local spider_smoke = table.deepcopy(ei_lib.raw["trivial-smoke"]["train-smoke"])
spider_smoke.name = "ei-spider-smoke"
spider_smoke.start_scale = 0.33
spider_smoke.end_scale = 4.2
spider_smoke.duration = 90
spider_smoke.fade_away_duration = 90
spider_smoke.color = {r = 0.24, g = 0.24, b = 0.24, a = 0.333}
data:extend({spider_smoke})
--Darker, longer duration, longer fadeout, smaller start_Scale, larger end_scale
--similar to actual diesel which makes a lingering plume
ei_lib.raw["trivial-smoke"]["train-smoke"] = {
    color = {r = 0.22, g = 0.22, b = 0.22, a = 0.42},
    duration = 300,
    spread_duration = 450,
    fade_away_duration = 300,
    start_scale = 0.33,
    end_scale = 2.5,
}

-- make locomotive use diesel
-- add burnt fuel slot
ei_lib.raw.locomotive.locomotive = {
    localised_name = {"entity-name.ei-locomotive"},

    max_power = "800kW", --default 600

    weight = 2500,

    energy_source = {
        emissions_per_minute = { pollution = 2.5 },
        fuel_categories = {"ei-diesel-fuel"},
        fuel_inventory_size = 3,
        burnt_inventory_size = 3,
        smoke = {
            {
                name = "train-smoke",
                deviation = {0.45, 0.45},
                frequency = 175,
                position = {0, 0},
                starting_frame = 0,
                starting_frame_deviation = 60,
                height = 2,
                height_deviation = 0.5,
                starting_vertical_speed = 0.08,
                starting_vertical_speed_deviation = 0.1
            }
      },
    }
}

-- let car and tank use alternative fuels
local t_extra_fuels = {
    "ei-rocket-fuel",
    "ei-nuclear-fuel",
    "ei-nuclear-fuel-cell",
    "ei-fusion-fuel",
    "ei-diesel-fuel"
}
local t = {
    "tank",
    "car"
}
for _,ent in pairs(t) do
    local target = data.raw.car[ent]
    if target and target.energy_source and target.energy_source.fuel_categories then
        for _,f in pairs(t_extra_fuels) do
            table.insert(target.energy_source.fuel_categories,f)
        end 
    end
end
-- make oil-refinery heat based
data.raw["assembling-machine"]["oil-refinery"].energy_usage = "1.5MW"
data.raw["assembling-machine"]["oil-refinery"].energy_source = {
    type = 'heat',
    max_temperature = 275,
    min_working_temperature = 185,
    specific_heat = ei_data.specific_heat,
    max_transfer = '10MW',
    emissions_per_minute = {pollution=15},
    connections = {
        {position = {-2.3, 0}, direction = defines.direction.west},
        {position = {-2.3, 1}, direction = defines.direction.west},
        {position = {-2.3, -1}, direction = defines.direction.west},
        -- {position = {0,1.4}, direction = defines.direction.south},
        {position = {2.3, 0}, direction = defines.direction.east},
        {position = {2.3, 1}, direction = defines.direction.east},
        {position = {2.3, -1}, direction = defines.direction.east},
        -- {position = {-1.5,0}, direction = defines.direction.west}
    }
}

-- make burner inserter be able to fuel leech
ei_lib.raw["inserter"]["burner-inserter"].allow_burner_leech = true
-- change upgrade from inserter to steam inserter
ei_lib.raw["inserter"]["burner-inserter"].next_upgrade = "ei-steam-inserter"
-- make electric engine unit craft category be crafting
data.raw["recipe"]["electric-engine-unit"].category = "crafting"

-- make underground pipes longer, read from setting
ei_lib.raw["pipe-to-ground"]["pipe-to-ground"].fluid_box.pipe_connections = {
    {
        direction=defines.direction.north,
        position = {
            0,
            0
        }
    },
    {
        connection_type = "underground",
        max_underground_distance = ei_lib.config("pipe-to-ground-length"),
        direction=defines.direction.south,
        position = {
            0,
            0
        }
    }
}

-- add handcrafting crafting category to player
--table.insert(data.raw["character"]["character"].crafting_categories, "ei-handcrafting")
ei_lib.raw["character"]["character"] = {
    force_insert = true,
    crafting_categories = {"ei-handcrafting"}
}
-- swap vanilla hr and normal reactor sprites with ei ones
-- also swap reactor lights
ei_lib.raw["reactor"]["nuclear-reactor"].picture.layers[1].filename = ei_graphics_entity_path.."hr-reactor.png"
ei_lib.raw["reactor"]["nuclear-reactor"].working_light_picture.filename = ei_graphics_entity_path.."hr-reactor-lights-color.png"

-- add fluidbox to centrifuge
ei_lib.raw["assembling-machine"]["centrifuge"].fluid_boxes_off_when_no_fluid_recipe = true
ei_lib.raw["assembling-machine"]["centrifuge"].fluid_boxes = {
    {
        production_type = "input",
        pipe_picture = ei_pipe_centrifuge,
        pipe_covers = pipecoverspictures(),
        volume = 200,
        pipe_connections = {
            {flow_direction = "input", direction = defines.direction.east, position = {1, 0}}
        },
        secondary_draw_orders = {north = -1}
    },
    {
        production_type = "output",
        pipe_picture = ei_pipe_centrifuge,
        pipe_covers = pipecoverspictures(),
        volume = 200,
        pipe_connections = {
            {flow_direction = "output", direction = defines.direction.west, position = {-1, 0}}
        },
        secondary_draw_orders = {north = -1}
    }
}
ei_lib.raw["assembling-machine"]["centrifuge"].fluid_boxes_off_when_no_fluid_recipe = true

-- remove neighbour bonus from nuclear reactor and set fuel category to ei_nuclear_fuel
-- also set energy output to 100MW (setting)

ei_lib.raw["reactor"]["nuclear-reactor"].energy_source.fuel_categories = {"ei-nuclear-fuel","ei-nuclear-fuel-cell",}
ei_lib.raw["reactor"]["nuclear-reactor"].energy_source.effectivity = 1
if ei_lib.config("nuclear-reactor-remove-bonus") then
    ei_lib.raw["reactor"]["nuclear-reactor"].neighbour_bonus = 0
end
ei_lib.raw["reactor"]["nuclear-reactor"].consumption = ei_lib.config("nuclear-reactor-energy-output")


-- buff solar panel power output and set fast_replaceable_group/next_upgrade
--update solar_matrix.lua default prod value at bottom if changing this
--1.778 is area difference multiplier between vanilla 3x3 solar and matrix 4x4
ei_lib.raw["solar-panel"]["solar-panel"].production = (80*1.778).."kW"
ei_lib.raw["solar-panel"]["solar-panel"].fast_replaceable_group = "solar-panel"
ei_lib.raw["solar-panel"]["solar-panel"].next_upgrade = "ei-solar-panel-2"

-- buff accumulator capacity, max in and output
ei_lib.raw.accumulator.accumulator = {
    energy_source = {
        buffer_capacity = "6MJ",
        input_flow_limit = "425kW",
        output_flow_limit = "425kW",
    }
}

-- sort fission reactor into nuclear tab
ei_lib.raw["item"]["nuclear-reactor"].subgroup = "ei-nuclear-buildings"
ei_lib.raw["item"]["nuclear-reactor"].order = "b-a"

ei_lib.raw["mining-drill"]["big-mining-drill"].energy_usage = "2MW"
--adjust furnaces energy usage
local stf = ei_lib.raw["furnace"]["stone-furnace"] or ei_lib.raw["assembling-machine"]["stone-furnace"]
if sf then
    sf.energy_usage = "135kW"
end
local sf = ei_lib.raw["furnace"]["steel-furnace"] or ei_lib.raw["assembling-machine"]["steel-furnace"]
if sf then
    sf.energy_usage = "260kW"
end
local ef = ei_lib.raw["furnace"]["electric-furnace"] or ei_lib.raw["assembling-machine"]["electric-furnace"]
if ef then
    ef.energy_usage = "558kW"
    ef.energy_source.emissions_per_minute.pollution = 2
end
ei_lib.raw["storage-tank"]["storage-tank"].fluid_box.volume = 5000

local vcp = ei_lib.raw["assembling-machine"]["chemical-plant"]
if vcp then
    --electric chem plant uses same energy but is slower than heat chem plant 1 vs 1.5
    vcp.energy_usage = "1MW"
    -- set fast replaceable group for chem plant
    vcp.fast_replaceable_group = "chemical-plant"
    -- allow burning fuels for ash
    if vcp.crafting_categories then
        table.insert(vcp.crafting_categories,"ei-burning")
    end
end

--set heat exchanger icon size so add_item_level can add the tier icon
local hea_exc = ei_lib.raw.item["heat-exchanger"]
if hea_exc then
    hea_exc.icon_size = 64
end

-- make mining radius of burner mining drill 
ei_lib.raw["mining-drill"]["burner-mining-drill"].radius_visualisation_picture = ei_lib.raw["mining-drill"]["electric-mining-drill"].radius_visualisation_picture
ei_lib.raw["mining-drill"]["burner-mining-drill"].resource_searching_radius = 2
ei_lib.raw["mining-drill"]["electric-mining-drill"] = {
    resource_searching_radius = 4,
    fast_replaceable_group = "electric-mining-drill",
    next_upgrade = "ei-advanced-electric-mining-drill",
    energy_usage = "150kW"
}

-- turn spidertron into a burner vehicle
for _, spider in pairs(data.raw["spider-vehicle"]) do
    if spider and spider.energy_source and spider.energy_source.type ~= "burner" then
        spider.energy_source =
    {
            type = "burner",
            fuel_categories = {"chemical", "ei-rocket-fuel","ei-nuclear-fuel","ei-nuclear-fuel-cell", "ei-fusion-fuel","ei-diesel-fuel"},
            effectivity = 1,
            fuel_inventory_size = 3,
            burnt_inventory_size = 3,
            emissions_per_minute = {
            pollution = 10
        },
        smoke = {
            {
            name = "ei-spider-smoke",
            deviation = {1.8, 1.8},
            frequency = 245,
            position = {0, 0},
            --position = {0, 0},
            starting_frame = 0,
            starting_frame_deviation = 60,
            height = 0.5,
            height_deviation = 1,
            starting_vertical_speed = 0.1,
            starting_vertical_speed_deviation = 0.5,
            }
        }
    }
        spider.movement_energy_consumption = "1.0MW"
    end
end

-- apply quality scaling bonuses to EI fuels
local buff_fuels = {
    "ei-rocket-fuel",
    "ei-nuclear-fuel",
    "ei-nuclear-fuel-cell",
    "ei-fusion-fuel"
}
for _,item in pairs(data.raw["item"]) do
    if item.fuel_category and ei_lib.table_contains_value(buff_fuels,item.fuel_category) then
        if not item.fuel_acceleration_multiplier_quality_bonus then
            item.fuel_acceleration_multiplier_quality_bonus = 0.495
        else
            item.fuel_acceleration_multiplier_quality_bonus = math.max(49.5,item.fuel_acceleration_multiplier_quality_bonus*1.1)
        end
        if not item.fuel_top_speed_multiplier_quality_bonus then 
            item.fuel_top_speed_multiplier_quality_bonus = 0.1
        else
            item.fuel_top_speed_multiplier_quality_bonus = math.max(0.1,item.fuel_top_speed_multiplier_quality_bonus*1.1)
        end
    end
end

-- improve movement speed bonus on stone-bricks, concrete and refined-concrete

data.raw["tile"]["stone-path"].walking_speed_modifier = 1.6
data.raw["tile"]["concrete"].walking_speed_modifier = 1.8
data.raw["tile"]["hazard-concrete-left"].walking_speed_modifier = 1.8
data.raw["tile"]["refined-concrete"].walking_speed_modifier = 2.2
data.raw["tile"]["refined-hazard-concrete-left"].walking_speed_modifier = 2.2

--prevent projectiles from colliding with friendly structures and allow collision with asteroids
local modify_collision_projectiles = {
    "cannon-projectile",
    "explosive-cannon-projectile",
    "explosive-uranium-cannon-projectile",
    "uranium-cannon-projectile",
    "shotgun-pellet",
    "piercing-shotgun-pellet",
    "ei-dragons-breath-shotgun-pellet",
}
local collision_mask = {
    layers = {
        object = true,
        player = true,
        trigger_target = true,
        train = true
    },
    not_colliding_with_itself = true
}
for _,projectile in ipairs(modify_collision_projectiles) do
    data.raw["projectile"][projectile].force_condition = "not-same"
    data.raw["projectile"][projectile].hit_collision_mask = collision_mask

    -- add the force condition to the action delivery
    if data.raw["projectile"][projectile].action then
        if data.raw["projectile"][projectile].action.action_delivery then
            
            -- loop over all trigger items and if contains damage set force
            for _,triggeritem in ipairs(data.raw["projectile"][projectile].action.action_delivery.target_effects) do
                if triggeritem.type == "damage" then
                    triggeritem.force = "not-same"
                end
            end

        end
    end

    -- do the same for final_action
    if data.raw["projectile"][projectile].final_action then
        if data.raw["projectile"][projectile].final_action.action_delivery then
            
            -- loop over all trigger items and if contains damage set force
            for _,triggeritem in ipairs(data.raw["projectile"][projectile].final_action.action_delivery.target_effects) do
                if triggeritem.type == "damage" then
                    triggeritem.force = "not-same"
                end

                if triggeritem.type == "nested-result" then
                    for _,nestedtriggeritem in ipairs(triggeritem.action.action_delivery.target_effects) do
                        if nestedtriggeritem.type == "damage" then
                            nestedtriggeritem.force = "not-same"
                        end
                    end
                end

            end

        end
    end
end

-- improve damage per bullet of firearm-magazine and piercing-rounds-magazine
ei_lib.raw["ammo"]["firearm-magazine"].ammo_type =     {
    action =
    {
    {
        type = "direct",
        action_delivery =
        {
        {
            type = "instant",
            source_effects =
            {
            {
                type = "create-explosion",
                entity_name = "explosion-gunshot",
                only_when_visible = true
            }
            },
            target_effects =
            {
            {
                type = "create-entity",
                entity_name = "explosion-hit",
                offsets = {{0, 1}},
                offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
                only_when_visible = true
            },
            {
                type = "damage",
                damage = {amount = 8, type = "physical"}
            },
            {
                type = "activate-impact",
                deliver_category = "bullet"
            }
            }
        }
        }
    }
    }
}

ei_lib.raw["ammo"]["piercing-rounds-magazine"].ammo_type =     {
    action =
    {
    type = "direct",
    action_delivery =
    {
        type = "instant",
        source_effects =
        {
        type = "create-explosion",
        entity_name = "explosion-gunshot",
        only_when_visible = true
        },
        target_effects =
        {
        {
            type = "create-entity",
            entity_name = "explosion-hit",
            offsets = {{0, 1}},
            offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
            only_when_visible = true
        },
        {
            type = "damage",
            damage = {amount = 13, type = "physical"}
        },
        {
            type = "activate-impact",
            deliver_category = "bullet"
        }
        }
    }
    }
}

-- increase radar energy usage
ei_lib.raw.radar.radar.energy_usage = "1.2MW" --default 300kW

-- increase power output of fission reactor equipment

ei_lib.raw["generator-equipment"]["fission-reactor-equipment"] = {
    power = "1MW",
    burner = {
        type = "burner",
        fuel_categories = {"ei-nuclear-fuel","ei-nuclear-fuel-cell",},
        effectivity = 1.0,
        fuel_inventory_size = 9,
        burnt_inventory_size = 9,
    }
}
ei_lib.raw["generator-equipment"]["fission-reactor-equipment"].energy_source.usage_priority = "secondary-output"
ei_lib.raw["item"]["fission-reactor-equipment"].order = "a[energy-source]-g[fission-reactor-equipment]"

-- sort uranium 235/238 in the nuclear tab
ei_lib.raw["item"]["uranium-235"].subgroup = "ei-nuclear-processing"
ei_lib.raw["item"]["uranium-235"].order = "a-a-a"

ei_lib.raw["item"]["uranium-238"].subgroup = "ei-nuclear-processing"
ei_lib.raw["item"]["uranium-238"].order = "a-a-b"

-- let vanilla modules use new textures (prod, speed and effectivity modules)
ei_lib.raw.module["productivity-module"].icon = ei_graphics_item_path .. "productivity-module.png"
ei_lib.raw.module["productivity-module-2"].icon = ei_graphics_item_path .. "productivity-module-2.png"
ei_lib.raw.module["productivity-module-3"].icon = ei_graphics_item_path .. "productivity-module-3.png"

ei_lib.raw.module["speed-module"].icon = ei_graphics_item_path .. "speed-module.png"
ei_lib.raw.module["speed-module-2"].icon = ei_graphics_item_path .. "speed-module-2.png"
ei_lib.raw.module["speed-module-3"].icon = ei_graphics_item_path .. "speed-module-3.png"

ei_lib.raw.module["efficiency-module"].icon = ei_graphics_item_path .. "effectivity-module.png"
ei_lib.raw.module["efficiency-module-2"].icon = ei_graphics_item_path .. "effectivity-module-2.png"
ei_lib.raw.module["efficiency-module-3"].icon = ei_graphics_item_path .. "effectivity-module-3.png"

-- modify quality modules
ei_lib.raw.module["quality-module"].effect = {
    productivity = -0.25,
    consumption = 1,
    speed = -0.3,
    quality=0.3
}
ei_lib.raw.module["quality-module-2"].effect = {
    productivity = -0.50,
    consumption = 2,
    speed = -0.6,
    quality=0.45
}
ei_lib.raw.module["quality-module-3"].effect = {
    productivity = -0.75,
    consumption = 3,
    speed = -0.9,
    quality=0.6
}

-- nerf vanilla modules a bit
ei_lib.raw.module["productivity-module"].effect = {
    productivity = 0.03,
    --consumption = 0.3,
    pollution = 0.05,
    speed = -0.05
}
ei_lib.raw.module["productivity-module-2"].effect = {
    productivity = 0.05,
    consumption = 0.2,
    pollution = 0.07,
    speed = -0.1
}
ei_lib.raw.module["productivity-module-3"].effect = {
    productivity = 0.07,
    consumption = 0.4,
    pollution = 0.15,
    speed = -0.2
}

ei_lib.raw.module["speed-module"].effect = {
    consumption = 0.1,
    speed = 0.3
}

ei_lib.raw.module["speed-module-2"].effect = {
    consumption = 0.2,
    speed = 0.4
}

ei_lib.raw.module["speed-module-3"].effect = {
    consumption = 0.3,
    speed = 0.5
}

-- clone vanilla prod module limitation to ei prod modules
data.raw.module["ei-productivity-module-4"].limitation = data.raw.module["productivity-module"].limitation
data.raw.module["ei-productivity-module-5"].limitation = data.raw.module["productivity-module"].limitation
data.raw.module["ei-productivity-module-6"].limitation = data.raw.module["productivity-module"].limitation
-- properly set logistics 3 age and prere 
ei_lib.raw.technology["logistics-3"].age = "advanced-computer-age"
ei_lib.set_prerequisites("logistics-3",{"ei-advanced-computer-age-tech","logistics-2","ei-carbon-manipulation"})
--plastic bar productivity
local pbp = ei_lib.raw.technology["plastic-bar-productivity"]
if pbp and pbp.effects then
    table.insert(pbp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-plastic-benzol",
        change = 0.1
    })
    table.insert(pbp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-plastic-crushed-coke",
        change = 0.1
    })
end

--processing unit productivity
local pup = ei_lib.raw.technology["processing-unit-productivity"]
if pup and pup.effects then
    table.insert(pup.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-processing-unit-circuit-board",
        change = 0.1
    })
end

--add t1 steel ingot casting to steel productivity

local spp = ei_lib.raw.technology["steel-plate-productivity"]
if spp and spp.effects then
    table.insert(spp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-steel-plate",
        change = 0.1
    })
end
--increase silo energy draw, enforce modules
ei_lib.raw["rocket-silo"]["rocket-silo"] = {
    module_slots = 6,
    rocket_parts_required = 100,
    energy_usage = "1MW",
    active_energy_usage = "7980kW",
    allowed_effects = {"speed", "consumption", "pollution"}
}

--adjust vanilla rocket part recipe
local rocket_part_recipe = ei_lib.raw["recipe"]["rocket-part"]
rocket_part_recipe.ingredients = {
	{type = "item", name = "ei-rocket-parts", amount = 1}
}
rocket_part_recipe.localised_name = {"recipe-name.ei-rocket-assembly"}
--adjust Rocket part name display
local rocket_part = ei_lib.raw["item"]["rocket-part"]
rocket_part.localised_name = {"item-name.ei-rocket-assembled"}

local rfp = ei_lib.raw.technology["rocket-fuel-productivity"]
if rfp and rfp.effects then
    table.insert(rfp.effects,
    {
        type = "change-recipe-productivity",
        recipe = "ei-bio-rocket-fuel",
        change = 0.1
    })
end

data.raw.technology["rocket-part-productivity"].effects = {
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts",
        change = 0.1
    },
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts-advanced",
        change = 0.1
    },
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts-odd-plating",
        change = 0.1
    },
    {
        type = "change-recipe-productivity",
        recipe = "ei-rocket-parts-odd-plating-advanced",
        change = 0.1
    },
}

ei_lib.raw["recipe"]["heavy-oil-cracking"].localised_name = {"recipe-name.ei-heavy-oil-cracking"}


-- use mk2 armor sprite for bio armor
for _, animation in ipairs(data.raw["character"]["character"]["animations"]) do
    if animation.armors then
        for _, armor in ipairs(animation.armors) do
            if armor == "power-armor-mk2" then
                animation.armors[#animation.armors + 1] = "ei-bio-armor"
                break
            end
        end
    end
end
--Double roboport charge energy
ei_lib.raw.roboport.roboport.charging_energy = "1MW"
--x10 the constant roboport drain
ei_lib.raw.roboport.roboport.energy_usage = "500kW"

--bring in line with ei-containers
ei_lib.raw["container"]["wooden-chest"].inventory_size = 8
ei_lib.raw["container"]["iron-chest"].inventory_size = 12
ei_lib.raw["container"]["steel-chest"].inventory_size = 16

ei_lib.patch_nested_value(
  data.raw["electric-turret"]["laser-turret"],
  "attack_parameters.ammo_type.action.action_delivery[1].max_length",
  30
)

--Modify laser turrets for extended range and lowered damage
ei_lib.raw["electric-turret"]["laser-turret"] = {
    attack_parameters = {
        range = 30,
        damage_modifier = 1.2,
    }
}

--Note: Add individual stream types to provide visual differentiation for different fluids
ei_lib.raw["fluid-turret"]["flamethrower-turret"] = {
    attack_parameters = {
        prepare_range = 40,
        fluid_consumption = 1, --default 0.2
        lead_target_for_projectile_speed = 0.45,
        range = 38, --default 0.225
        min_range = 9, --default 6
        turn_range = ei_lib.raw["fluid-turret"]["flamethrower-turret"].attack_parameters.turn_range * 0.8,
        fluids = {
            {type = "ei-heavy-destilate", damage_modifier = 0.4, damage_override_animation_modifier = 0.4},
            {type = "ei-medium-destilate", damage_modifier = 0.5, damage_override_animation_modifier = 0.5},
            {type = "ei-residual-oil", damage_modifier = 0.65, damage_override_animation_modifier = 0.65},
            {type = "crude-oil"},
            {type = "heavy-oil", damage_modifier = 1.15, damage_override_animation_modifier = 1.15},
            {type = "light-oil", damage_modifier = 1.25, damage_override_animation_modifier = 1.25},
            {type = "petroleum-gas", damage_modifier = 1.35, damage_override_animation_modifier = 1.35},
            {type = "ei-kerosene", damage_modifier = 1.45, damage_override_animation_modifier = 1.45}
        },
    }
    
}
local flame_stream = ei_lib.raw["stream"]["flamethrower-fire-stream"]
ei_lib.raw.stream["flamethrower-fire-stream"] = {
    particle_verticle_acceleration = flame_stream.particle_vertical_acceleration * 1.5,
    particle_horizontal_speed = flame_stream.particle_horizontal_speed * 1.5,
    particle_horizontal_speed_deviation = flame_stream.particle_horizontal_speed_deviation * 1.5
}
--allow space crusher to do ground based crusher recipes
local space_crusher = ei_lib.raw["assembling-machine"]["crusher"]
if space_crusher and space_crusher.crafting_categories then
    table.insert(space_crusher.crafting_categories,"ei-crushing")
end

--====================================================================================================
--Space science -> Cosmic criticality pack
--====================================================================================================
ei_lib.raw.technology["space-science-pack"] = {
    localised_name = {"technology-name.ei-space-science-pack"},
    localised_description = {"technology-description.ei-space-science-pack"},
    icon = ei_graphics_3_path.."graphics/items/cosmic-criticality-pack.png",
    icon_size = 512,
    icon_mipmaps = 5,
}

--Increase space science pack difficulty, make alt recipes with different fuels
ei_lib.raw.tool["space-science-pack"] = {
    icon = ei_graphics_3_path.."graphics/items/cosmic-criticality-pack.png",
    icon_size = 512,
    icon_mipmaps = 5,
    localised_name = {"item-name.ei-space-science-pack"},
    localised_description = {"item-description.ei-space-science-pack"}
}
ei_lib.raw.recipe["space-science-pack"] = {
    category = "centrifuging",
    icon = ei_graphics_3_path.."graphics/items/cosmic-criticality-pack.png",
    icon_size = 512,
    icon_mipmaps = 5,
}
ei_lib.recipe_swap("space-science-pack","iron-plate","ei-steel-beam")
ei_lib.recipe_add("space-science-pack","ei-liquid-nitrogen",50,true)
ei_lib.recipe_add("space-science-pack","ei-liquid-oxygen",50,true)
local ssp = table.deepcopy(ei_lib.raw.recipe["space-science-pack"])

local two_three_nine = table.deepcopy(ssp)
--239
table.insert(two_three_nine.ingredients,{type="item",name="ei-plutonium-239-fuel",amount=1})
two_three_nine.name = "ei-space-science-pack-239"

--original science pack is 235
ei_lib.recipe_add("space-science-pack","ei-uranium-235-fuel",2)
ei_lib.raw.recipe["space-science-pack"].localised_name = {"recipe-name.ei-space-science-pack-235"}

--233
local two_three_three = table.deepcopy(ssp)
two_three_three.name = "ei-space-science-pack-233"
table.insert(two_three_three.ingredients,{type="item",name="ei-uranium-233-fuel",amount=3})

--232
local two_three_two = table.deepcopy(ssp)
two_three_two.name = "ei-space-science-pack-232"
table.insert(two_three_two.ingredients,{type="item",name="ei-thorium-232-fuel",amount=4})
--test fuel
local test_fuel = table.deepcopy(ssp)
test_fuel.name = "ei-space-science-pack-testfuel"
test_fuel.results[1].amount = 1
table.insert(test_fuel.ingredients,{type="item",name="ei-uranium-test-fuel",amount=16})

data:extend({
    two_three_nine,
    two_three_three,
    two_three_two,
    test_fuel
})
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-239")
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-233")
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-232")
ei_lib.add_unlock_recipe("space-science-pack","ei-space-science-pack-testfuel")

--double centrifuge fluidboxes
local cent = ei_lib.raw["assembling-machine"].centrifuge
if cent then
    local i2 = table.deepcopy(cent.fluid_boxes[1])
    local o2 = table.deepcopy(cent.fluid_boxes[2])
    if i2 then
        i2.pipe_connections = {{ flow_direction="input", direction = defines.direction.north, position = {0, -1} }}
        table.insert(cent.fluid_boxes,i2)
    end
    if o2 then
        o2.pipe_connections = {{ flow_direction="output", direction = defines.direction.south, position = {0, 1} }}
        table.insert(cent.fluid_boxes,o2)
    end
end

--====================================================================================================
--Vulcanus
--====================================================================================================

ei_lib.recipe_swap("turbo-transport-belt", "lubricant","electrolyte", 20)
ei_lib.recipe_swap("turbo-underground-belt", "lubricant","electrolyte", 40)
ei_lib.recipe_swap("turbo-splitter", "lubricant","electrolyte", 80)
ei_lib.recipe_add("turbo-transport-belt", "ei-steel-mechanical-parts", 8, false)
ei_lib.recipe_add("turbo-underground-belt", "ei-steel-mechanical-parts", 30, false)
ei_lib.recipe_add("turbo-splitter", "ei-steel-mechanical-parts", 15, false)

-- set next upgrade of turbo belt, splitter and underground to ei_neo-belt
ei_lib.raw["transport-belt"]["turbo-transport-belt"].next_upgrade = "ei-neo-belt"
ei_lib.raw["splitter"]["turbo-splitter"].next_upgrade = "ei-neo-splitter"
ei_lib.raw["underground-belt"]["turbo-underground-belt"].next_upgrade = "ei-neo-underground-belt"

-- set localised descriptions
ei_lib.raw["item"]["burner-inserter"].localised_description = {"item-description.ei_burner-inserter"}
ei_lib.raw["item"]["oil-refinery"].localised_description = {"item-description.ei_oil-refinery"}

-- set localised name of ores to ei ones
data.raw["resource"]["iron-ore"].localised_name = {"item-name.ei-poor-iron-chunk"}
data.raw["resource"]["copper-ore"].localised_name = {"item-name.ei-poor-copper-chunk"}
data.raw["resource"]["uranium-ore"].localised_name = {"item-name.ei-poor-uranium-chunk"}

local p_d_v = ei_lib.raw.technology["planet-discovery-vulcanus"]
if p_d_v then
    p_d_v.age = "computer-age"
end
--cliff explosives
ei_lib.set_prerequisites("cliff-explosives",{"military-2","planet-discovery-vulcanus","explosives"})

-- foundry
local foundry = ei_lib.raw["assembling-machine"].foundry
if foundry then
    foundry.crafting_speed = 1.5
    foundry.energy_usage = "58MW"
    foundry.module_slots = 2
    foundry.energy_source.emissions_per_minute.pollution=18
    table.insert(foundry.crafting_categories,"ei-casting")
end

ei_lib.recipe_swap("casting-low-density-structure","molten-iron","ei-molten-steel",50)

ei_lib.raw.recipe["casting-steel"].ingredients = {
    {type="fluid",name="ei-molten-steel",amount=20}
}
ei_lib.raw.recipe["casting-steel"].results = {
    {type="item",name="steel-plate",amount=2}
}
ei_lib.raw.recipe["casting-iron-gear-wheel"].results = {
    {type="item",name="ei-iron-mechanical-parts",amount=1}
}
ei_lib.raw.recipe["casting-iron-stick"].results = {
    {type="item",name="ei-iron-beam",amount=1}
}
ei_lib.raw.recipe["molten-copper"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,allow_productivity=false
}
ei_lib.raw.recipe["molten-iron"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,probability=0.33,allow_productivity=false
}
ei_lib.raw.recipe["molten-copper-from-lava"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,allow_productivity=false
}
ei_lib.raw.recipe["molten-iron-from-lava"].results[2] = {
    type="item",name="ei-slag",amount_min=8,amount_max=12,allow_productivity=false
}

ei_lib.merge_fluid("ei-molten-iron", "molten-iron", false)
ei_lib.merge_fluid("ei-molten-copper", "molten-copper", false)
--allow caster to produce space-age plates
local addToCaster = {
    "holmium-plate",
    "tungsten-plate"
}
for _,toCast in pairs(addToCaster) do
    local recipe = ei_lib.raw.recipe[toCast]
    if recipe then
        if recipe.additional_categories then
            table.insert(recipe.additional_categories,"ei-casting")
        else
            recipe.additional_categories = {"ei-casting"}
        end
    end
end

--acid neutralisation
local a_n = ei_lib.raw.recipe["acid-neutralisation"]
if a_n then
    --acid neutralisation t2
    local a_n_t2 = table.deepcopy(a_n)
    a_n_t2.name = "ei-acid-neutralisation-t2"
    a_n_t2.icon = ei_graphics_3_path.."graphics/fluid/acid-neutralisation-t2.png"
    a_n_t2.icon_size = 64
    a_n_t2.ingredients = {
        {type= "item", name= "calcite", amount=15},
        {type= "fluid", name= "sulfuric-acid", amount=750},
        {type= "fluid", name= "ei-nitric-acid", amount=250},
    }
    a_n_t2.results = {
        {type= "fluid", name= "steam", amount_min= 9000, amount_max=12500, temperature=500},
        {type = "fluid", name= "ei-acidic-water", amount_min=25,amount_max=125}
    }
    data:extend({
        a_n_t2,
    {
        name = "ei-acid-neutralisation-t2",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/fluid/acid-neutralisation-t2.png",
        icon_size = 64,
        prerequisites = {"ei-nitric-acid","metallurgic-science-pack"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-acid-neutralisation-t2"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
        })
    local a_n_t2_tech = ei_lib.raw.technology["ei-acid-neutralisation-t2"]
    table.insert(a_n_t2_tech.unit.ingredients,{"metallurgic-science-pack",1})
    a_n.ingredients = {
        {type= "item", name= "calcite", amount=15},
        {type= "fluid", name= "sulfuric-acid", amount=1000},
    }
    --modify acid neutralization
    a_n.results = {
        {type= "fluid", name= "steam", amount_min= 7500, amount_max=9500, temperature= 280},
        {type = "fluid", name= "ei-acidic-water", amount_min=50,amount_max=250}
    }
end
--====================================================================================================
--Aquilo
--====================================================================================================
--swap solid fuel for light oil in fluoroketone
ei_lib.recipe_remove("fluoroketone","solid-fuel")
ei_lib.recipe_add("fluoroketone","light-oil",30,true)
local cryo = ei_lib.raw["assembling-machine"]["cryogenic-plant"]
if cryo then
    cryo.energy_usage = "31MW"
    cryo.energy_source.emissions_per_minute.pollution = 18 --def 6
    cryo.crafting_speed = 1.5
    cryo.module_slots = 4
    table.insert(cryo.crafting_categories,"ei-cooler")
end
data:extend({
    {
    name = "ei-fluorite-fluorine-calcite",
    type = "recipe",
    category = "chemistry",
    energy_required = 6,
    ingredients = {
        {type = "fluid", name = "fluorine", amount = 15},
        {type = "item", name = "calcite", amount = 1},
    },
    results = {
        {type = "item", name = "ei-fluorite", amount = 2},
        {type = "fluid", name = "ei-oxygen-gas", amount = 15},
        --co2?
    },
    always_show_made_in = true,
    enabled = false,
    main_product = "ei-fluorite",
    },
    {
        name = "ei-fluorine-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "fluorine", amount = 50},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = data.raw.fluid["fluorine"].icon,
        icon_size = data.raw.fluid["fluorine"].icon_size,
        icons = {
            { icon = data.raw.fluid["fluorine"].icon, scale = 1 },
            { icon = "__base__/graphics/icons/signal/signal-no-entry.png", scale = 1.5}
        },
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-i[ei-fluorine-vent]"
    },
})
table.insert(data.raw["technology"]["planet-discovery-aquilo"].effects, {type = "unlock-recipe", recipe = "ei-fluorite-fluorine-calcite"})
table.insert(data.raw["technology"]["planet-discovery-aquilo"].effects, {type = "unlock-recipe", recipe = "ei-fluorine-vent"})
--====================================================================================================
--Fulgora
--====================================================================================================
local p_d_f = ei_lib.raw.technology["planet-discovery-fulgora"]
if p_d_f then
    p_d_f.age = "computer-age"
end
local li_co = ei_lib.raw.technology["lightning-collector"]
if li_co then
    li_co.age = "computer-age"
end
local electro = ei_lib.raw["assembling-machine"]["electromagnetic-plant"]
if electro then
    electro.energy_usage = "41.4MW"
    electro.energy_source.emissions_per_minute.pollution = 12 --def 4
    electro.crafting_speed = 1.5
    electro.module_slots = 3
    table.insert(electro.crafting_categories,"ei-waver-factory")
end
--====================================================================================================
--Gleba
--====================================================================================================
--Add nutrients to science pack
local p_d_g = ei_lib.raw.technology["planet-discovery-gleba"]
if p_d_g then
    p_d_g.age = "computer-age"
end
local ag_sci_pack = ei_lib.raw.recipe["agricultural-science-pack"]
if ag_sci_pack then
	table.insert(ag_sci_pack.ingredients,{type = "item", name = "nutrients", amount = 40})
end
-- Biolab uses nutrients, @StephenB
local originalEnergySource = ei_lib.raw.lab.biolab.energy_source
ei_lib.raw.lab.biolab.energy_source = table.deepcopy(data.raw["assembling-machine"].biochamber.energy_source)
-- Leaving power at 300kW. Biochambers use 500kW.
-- Biochambers have -1/m pollution emission (ie they reduce pollution). Biolabs had 8/m pollution emission, but this changes it to -1/m. Captive biter spawners are also -1/m. Looking at a simple Nauvis base importing most sciences, biolabs are actually the majority of the pollution, so I'm changing it back to 8/m.
ei_lib.raw.lab.biolab.energy_source.emissions_per_minute = originalEnergySource.emissions_per_minute

--====================================================================================================
--FUNCTION STUFF
--====================================================================================================

-- loop over new_ingredients_table and set new ingredients for indexed recipes
for i,v in pairs(new_ingredients_table) do
    ei_lib.recipe_new(i, v)
end
-- loop over new_prerequisites_table and add new prerequisites for indexed technologies
-- if so remove the age tech as prerequisiter
for age,table_in in pairs(new_prerequisites_table) do
    for i,v in pairs(table_in) do
        ei_lib.add_prerequisite(v[1], v[2])
        ei_lib.remove_prerequisite(v[1], "ei-"..age)
    end
end

for _, tech in ipairs(numbered_buffs) do
    make_numbered_buff_prerequisite(tech)
end

for i,v in ipairs(prereqs_to_remove) do
    ei_lib.remove_prerequisite(v[1], v[2])
end
