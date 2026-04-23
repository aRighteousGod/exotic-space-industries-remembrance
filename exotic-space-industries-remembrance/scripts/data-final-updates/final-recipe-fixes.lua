-- fix recipes that are broken due to patches

local ei_data = require("lib/data")
local ei_lib = require("lib/lib")

--====================================================================================================
--FINAL RECIPE FIXES
--====================================================================================================
-- loop over all recipes and apply fix_recipe
for i, v in pairs(data.raw.recipe) do
	-- get mode of recipe

	ei_lib.fix_recipe(i)
end

-- hide all barrel rcipes that were added by autobarreling from player
-- check if recipe is in fill-barrel or empty-barrel subgroup

for i, v in pairs(data.raw.recipe) do
	if data.raw.recipe[i].subgroup == "fill-barrel" or data.raw.recipe[i].subgroup == "barrel" then
		data.raw.recipe[i].hide_from_player_crafting = true
	end
end

-- error(serpent.block(data.raw.technology['planet-discovery-gleba']))
local p_unit = ei_lib.raw.recipe["processing-unit"]
if p_unit then
	p_unit.category = "crafting"
	p_unit.additional_categories = {"electronics"}
end
--====================================================================================================
--RECIPES THAT ALLOW PRODUCTIVITY
--====================================================================================================
--Burning chemical fuel for ash recipes module effects set in data-final-updates/camp_fire.lua

local recipes = {
	"ei-bio-insulated-wire",
	"ei-bio-electronic-parts",
	"ei-bio-magnet",
	"ei-bio-hydrofluoric-acid",
	"ei-bio-nitric-acid",
	"ei-hydrofluoric-acid",
	"ei-hydrofluoric-acid-steam",
	"ei-hydrofluoric-acid-steam-ash",
	"ei-desulfurize-kerosene",
	"ei-kerosene-heavy-oil",
	"ei-kerosene-cracking",
	"ei-nitric-acid",
	"ei-crystal-solution",
	"ei-drill-fluid",
	"ei-ammonia",
	"ei-oxygen-sulfuric-acid",
	"ei-dinitrogen-tetroxide",
	"ei-dinitrogen-tetroxide-water-solution",
	"ei-oxygen-difluoride",
	"ei-oxygen-difluoride-alien",
	--    "ei-lube-destilation",
	"ei-plastic-benzol",
	"ei-battery-lithium",
	"ei-carbon",
	"ei-lithium-crystal",
	"ei-molten-steel-mix",
	"ei-steam-engine",
	"ei-electron-tube",
	"ei-cpu",
	"ei-electronic-parts",
	"ei-module-part",
	"ei-module-base",
	"ei-magnet",
	"ei-emtpy-cryo-container",
	"ei-green-circuit-waver",
	"ei-red-circuit-waver",
	"ei-electric-engine-lube",
	"ei-advanced-motor",
	"ei-advanced-motor-cryo",
	"ei-rocket-parts",
	"ei-rocket-parts-advanced",
	"ei-dark-age-tech",
	"ei-steam-age-tech",
	"ei-electricity-age-tech",
	"ei-computer-age-tech",
	"ei-advanced-computer-age-tech",
	"ei-quantum-age-tech",
	"ei-ceramic",
	"ei-steel-blend",
	"ei-dirty-water-fluorite",
	"ei-dirty-water-fluorite-nitric",
	"ei-acidic-water-fluorite-bed",
	"ei-morphium-fluorite",
	"ei-neutron-container",
	"ei-odd-plating",
	"ei-advanced-rocket-fuel",
	"ei-plastic-crushed-coke",
	"ei-rocket-parts-odd-plating",
	"ei-rocket-parts-odd-plating-advanced",
	"ei-insulated-wire",
	"firearm-magazine",
	"piercing-rounds-magazine",
	"uranium-rounds-magazine",
	"ei-compound-ammo",
	"shotgun-shell",
	"piercing-shotgun-shell",
	"cannon-shell",
	"explosive-cannon-shell",
	"uranium-cannon-shell",
	"explosive-uranium-cannon-shell",
	"artillery-shell",
	"ei-artillery-shell",
	"rocket",
	"explosive-rocket",
	"ei-molten-steel-oxygen",
	"ei-ceramic-water",
	"ei-solid-fuel-residual-oil",
	"ei-diesel-fuel-unit",
	"ei-benzol-petroleum",
	"ei-molten-carbon-symbiote-casting",
	"ei-cast-carbon",
	"ei-molten-carbon-fusion",
	"ei-molten-carbon-fusion-high-energy",
	"ei-basic-steam-oil-processing",
	"ei-basic-water-oil-processing",
	"ei-explosives-solid-sulfuric-nitric",
	"ei-explosives-light-crushed",
	"ei-liquid-nitrogen-oil-processing",
	"ei-liquid-oxygen-heavy-oil-cracking",
	"ei-nitric-acid-medium-destilate-cracking",
	"ei-bio-oil-refining",
	"ei-water-bio-oil-refining",
	"ei-steam-bio-oil-refining"
}

for i, v in pairs(recipes) do
	local modify = ei_lib.raw["recipe"][v]
	if modify then
		modify.allow_productivity = true
		log("final-recipe-fixes: allowed productivity for recipe: " .. v)
		if modify.allowed_effects then
			local found = false
			for index, effect in pairs(modify.allowed_effects) do
				if effect == "productivity" then
					found = true
					log("final-recipe-fixes: found productivity was already allowed for recipe: " .. v .. ", skipping")
					break
				elseif index == #modify.allowed_effects and not found then
					table.insert(modify.allowed_effects, "productivity")
					log("final-recipe-fixes: allowed productivity effect for recipe: " .. v)
				end
			end
		end
		--[[
		else
			--could probably use recipes table to set individual allowed effects
			modify.allowed_effects = {
			"speed",
			"consumption",
			"pollution",
			"quality",
			"productivity"
			}
			log("final-recipe-fixes: allowed module effects including productivity for recipe: "..v)
		end
		]]
	else
		log("final-recipe-fixes: adding productivity module effects got invalid recipe:  " .. v)
	end
end
local remove_prod = {
	"lubricant",
	"ei-lube-destilation",
	"ei-lube-destilate-steam-finishing",
	"ei-vaporize-liquid-ammonia",
	"ei-vaporize-liquid-nitrogen",
	"ei-vaporize-liquid-oxygen",
	"ei-liquid-ammonia",
	"ei-liquid-nitrogen",
	"ei-liquid-oxygen",
}
--this segment commented out pending mindful consideration of removing productivity
--in this bloated 2.0 era of insane productivity
--[[
-- remove productivity from given recipes
local crafting_categories = {
    "ei-waver-factory",
    "smelting",
    "rocket-building",
}
-- get all recipes that have given crafting category and add them to limitation of productivity modules

for i,v in pairs(crafting_categories) do
    for i2,v2 in pairs(ei_lib.raw["recipe"]) do
        if v2.category == v then
            if not ei_lib.table_contains_value(remove_prod,v2.name) then
				table.insert(remove_prod,v2.name)
				log("final-recipe-fixes: crafting category: "..v.." found in recipe: "..v2.name.." adding to productivity limitation table")
			end
        end
    end
end
]]
for i, v in pairs(remove_prod) do
	local modify = ei_lib.raw["recipe"][v]
	if modify then
		modify.allow_productivity = false
		log("final-recipe-fixes: forbid productivity for recipe: " .. v)
		if modify.allowed_effects then
			local found = false
			for index, effect in pairs(modify.allowed_effects) do
				if effect == "productivity" then
					table.remove(modify.allowed_effects, index)
					log("final-recipe-fixes: forbid productivity effect for recipe: " .. v)
					break
				end
			end
		end
		--[[
		else
			--could probably use recipes table to set individual allowed effects
			modify.allowed_effects = {
			"speed",
			"consumption",
			"pollution",
			"quality",
			}
			log("final-recipe-fixes: allowed module effects OTHER than productivity for recipe: "..v)
		]]
	else
		log("final-recipe-fixes: forbidding productivity module effects got invalid recipe: " .. v)
	end
end

ei_lib.recipe_swap("concrete", "iron-ore", "ei-iron-beam")
ei_lib.recipe_swap("refined-concrete", "ei-copper-mechanical-parts", "ei-steel-beam")

-- fix recipes that need vanilla iron-ore, copper-ore or iron-gear-wheel/iron-stick
-- loop over all recipes

for name, recipe in pairs(data.raw.recipe) do
	--ei_lib.recipe_swap(name, "iron-ore", "ei-poor-iron-chunk")
	--ei_lib.recipe_swap(name, "copper-ore", "ei-poor-copper-chunk")
	--ei_lib.recipe_swap(name, "iron-gear-wheel", "ei-iron-mechanical-parts")

	--ei_lib.recipe_swap(name, "iron-stick", "ei-iron-beam")
	--ei_lib.recipe_swap(name, "nuclear-fuel", "ei-uranium-235-fuel")
	ei_lib.recipe_swap(name, "uranium-fuel-cell", "ei-uranium-235-fuel")
	ei_lib.recipe_swap(name, "burner-assembling-machine", "ei-burner-assembler")
end

--recipes and placeables + simple entities ie vulcanus rocks bacteria

ei_lib.merge_item("ei-iron-chunk", "iron-ore", false, true)
ei_lib.merge_item("ei-copper-chunk", "copper-ore", false, true)
ei_lib.merge_item("ei-steel-mechanical-parts", "steel-gear-wheel", false)
ei_lib.merge_item("ei-iron-mechanical-parts", "iron-gear-wheel", false, true)
ei_lib.merge_item("ei-iron-beam", "iron-stick", false, true)
--ei_lib.merge_item("ei-uranium-235-fuel","nuclear-fuel",false,true)
--ei_lib.merge_item("ei-burner-assembler","burner-assembling-machine",false,true)

local igw = ei_lib.raw.recipe["iron-gear-wheel"]
if igw then
	igw.enabled = false
	igw.hidden = true
end
local is = ei_lib.raw.recipe["iron-stick"]
if is then
	is.enabled = false
	is.hidden = true
end
local sg = ei_lib.raw.recipe["steel-gear-wheel"] or ei_lib.raw.recipe["kr-steel-gear-wheel"]
if sg then
	sg.enabled = false
	sg.hidden = true
end
if mods and mods["aai-signal-transmission"] then
	ei_lib.add_unlock_recipe("aai-signal-transmission", "aai-signal-sender")
	ei_lib.remove_unlock_recipe("space-platform", "aai-signal-sender")
end
ei_lib.add_unlock_recipe("electronics", "stone-tablet")
ei_lib.add_unlock_recipe("ei-steam-power", "boiler")
ei_lib.add_unlock_recipe("ei-glass", "kr-glass")
ei_lib.add_unlock_recipe("steel-processing", "kr-steel-gear-wheel")

--ei_lib.add_unlock_recipe("ei-advanced-port","kr-small-roboport")
--ei_lib.add_unlock_recipe("ei-advanced-port","kr-big-roboport")
ei_lib.add_unlock_recipe("ei-electricity-power", "kr-wind-turbine")
ei_lib.add_unlock_recipe("atomic-bomb", "nuclear-artillery-shell")
ei_lib.add_unlock_recipe("rocket-silo", "ei-orbital-combinator")
ei_lib.add_unlock_recipe("ei-electronic-parts", "kr-electronic-components") --add k2 electronic components to EI equivalent
ei_lib.add_unlock_recipe("lithium-processing", "lithium-chloride")

--====================================================================================================
-- SPECIAL CASES
--====================================================================================================

data.raw.recipe["transport-belt"].category = "crafting"
data.raw.recipe["underground-belt"].category = "crafting"
data.raw.recipe["splitter"].category = "crafting"

-- error(serpent.block(data.raw.technology["uranium-mining"]))
-- error(serpent.block(data.raw.recipe["centrifuge"]))

--====================================================================================================
-- BARRELS AND MISC
--====================================================================================================

local function overwrite_barrel_capacity(recipeItem, capacity)
	if recipeItem and recipeItem.type == "fluid" then
		recipeItem.amount = capacity
		recipeItem.ignored_by_stats = capacity
	end
end

local barrel = ei_lib.raw.item.barrel
if barrel then
	barrel.stack_size = 1
	if barrel.weight then
		barrel.weight = barrel.weight * 10
	end
	--[[
	if barrel.flags then
		if not ei_lib.table_contains_value(barrel.flags, "not-stackable") then
			table.insert(barrel.flags, "not-stackable")
		end
	else
		barrel.flags = {"not-stackable"}
	end
	]]
end
for _, item in pairs(data.raw.item) do
	if item and item.name and string.sub(item.name, -7) == "-barrel" then
		item.stack_size = 1
		if item.weight then
			item.weight = item.weight * 10
		end
		--[[
		if item.flags then
			if not ei_lib.table_contains_value(item.flags, "not-stackable") then
				table.insert(item.flags, "not-stackable")
			end
		else
			item.flags = {"not-stackable"}
		end
		]]
	end
end
for _, recipe in pairs(data.raw.recipe) do
	if recipe.name and string.sub(recipe.name, 1, 3) == "ei-" then
		--recipe.always_show_made_in = false
		--recipe.always_show_products = false
		recipe.hide_from_signal_gui = false
		recipe.allow_decomposition = true
		--recipe.result_is_always_fresh = true
		recipe.unlock_results = true
	end
	--  if ei_lib.contains(recipe.name,"recycler") then recipe.surface_conditions = nil end
	--  if ei_lib.contains(recipe.name,"crusher") then recipe.surface_conditions = nil end

	--This was failing silently, added sanity checks, but seems unnecessary at this time? 4-14-25
	--  if ei_lib.endswith(recipe.name,"-asteroid-crushing") and data.raw.technology and data.raw.technology[recipe.name] then
	--    ei_lib.add_unlock_recipe(recipe.name,"crusher")
	--  end

	if recipe.subgroup == "fill-barrel" and recipe.ingredients then
		for _, ingredient in pairs(recipe.ingredients) do
			overwrite_barrel_capacity(ingredient, ei_lib.config("barrel-capacity"))
		end
	end

	if recipe.subgroup == "empty-barrel" and recipe.results then
		for _, result in pairs(recipe.results) do
			overwrite_barrel_capacity(result, ei_lib.config("barrel-capacity"))
		end
	end
end

--Science pack yield adjustment settings
--dark
local dark_yield = ei_lib.config("science-pack-yield-dark")
local dark_pack_amount = ei_lib.raw.recipe["ei-dark-age-tech"].results[1]["amount"]
if dark_yield and dark_yield ~= dark_pack_amount then
	ei_lib.raw.recipe["ei-dark-age-tech"].results[1]["amount"] = dark_yield
	log("EI science pack yield adjusted to: " .. dark_pack_amount .. " for Dark age science pack")
end
--steam
local steam_yield = ei_lib.config("science-pack-yield-steam")
local steam_pack_amount = ei_lib.raw.recipe["ei-steam-age-tech"].results[1]["amount"]
if steam_yield and steam_yield ~= steam_pack_amount then
	ei_lib.raw.recipe["ei-steam-age-tech"].results[1]["amount"] = steam_yield
	log("EI science pack yield adjusted to: " .. steam_pack_amount .. " for Steam age science pack")
end
--electricity
local electricity_yield = ei_lib.config("science-pack-yield-electricity")
local electricity_pack_amount = ei_lib.raw.recipe["ei-electricity-age-tech"].results[1]["amount"]
if electricity_yield and electricity_yield ~= electricity_pack_amount then
	ei_lib.raw.recipe["ei-electricity-age-tech"].results[1]["amount"] = electricity_yield
	log("EI science pack yield adjusted to: " .. electricity_pack_amount .. " for Electricity age science pack")
end
--computer
local computer_yield = ei_lib.config("science-pack-yield-computer")
local computer_pack_amount = ei_lib.raw.recipe["ei-computer-age-tech"].results[1]["amount"]
if computer_yield ~= computer_pack_amount then
	ei_lib.raw.recipe["ei-computer-age-tech"].results[1]["amount"] = computer_yield
	log("EI science pack yield adjusted to: " .. computer_pack_amount .. " for Computer age science pack")
end
--simulation
local simulation_yield = ei_lib.config("science-pack-yield-simulation")
local simulation_pack_amount = ei_lib.raw.recipe["ei-advanced-computer-age-tech"].results[1]["amount"]
if simulation_yield and simulation_yield ~= simulation_pack_amount then
	ei_lib.raw.recipe["ei-advanced-computer-age-tech"].results[1]["amount"] = simulation_yield
	log("EI science pack yield adjusted to: " .. simulation_pack_amount .. " for Simulation age science pack")
end
--alien
local alien_yield = ei_lib.config("science-pack-yield-alien")
local alien_pack_amount = ei_lib.raw.recipe["ei-alien-computer-age-tech"].results[1]["amount"]
if alien_yield and alien_yield ~= alien_pack_amount then
	ei_lib.raw.recipe["ei-alien-computer-age-tech"].results[1]["amount"] = alien_yield
	log("EI science pack yield adjusted to: " .. alien_pack_amount .. " for Alien age science pack")
end
--quantum
local quantum_yield = ei_lib.config("science-pack-yield-quantum")
local quantum_pack_amount = ei_lib.raw.recipe["ei-quantum-age-tech"].results[1]["amount"]
if quantum_yield and quantum_yield ~= quantum_pack_amount then
	ei_lib.raw.recipe["ei-quantum-age-tech"].results[1]["amount"] = quantum_yield
	log("EI science pack yield adjusted to: " .. quantum_pack_amount .. " for Quantum age science pack")
end
--fusion-quantum
local fusion_quantum_yield = ei_lib.config("science-pack-yield-fusion-quantum")
local fusion_quantum_pack_amount = ei_lib.raw.recipe["ei-fusion-quantum-age-tech"].results[1]["amount"]
if fusion_quantum_yield and fusion_quantum_yield ~= fusion_quantum_pack_amount then
	ei_lib.raw.recipe["ei-fusion-quantum-age-tech"].results[1]["amount"] = fusion_quantum_yield
	log("EI science pack yield adjusted to: " .. fusion_quantum_pack_amount .. " for Fusion-Quantum age science pack")
end
--exotic
local exotic_yield = ei_lib.config("science-pack-yield-exotic")
local exotic_pack_amount = ei_lib.raw.recipe["ei-exotic-age-tech"].results[1]["amount"]
if exotic_yield and exotic_yield ~= exotic_pack_amount then
	ei_lib.raw.recipe["ei-exotic-age-tech"].results[1]["amount"] = exotic_yield
	log("EI science pack yield adjusted to: " .. exotic_pack_amount .. " for Exotic age science pack")
end
--black-hole
local black_hole_yield = ei_lib.config("science-pack-yield-black-hole")
local black_hole_pack_amount = ei_lib.raw.recipe["ei-black-hole-exotic-age-tech"].results[1]["amount"]
if black_hole_yield and black_hole_yield ~= black_hole_pack_amount then
	ei_lib.raw.recipe["ei-black-hole-exotic-age-tech"].results[1]["amount"] = black_hole_yield
	log("EI science pack yield adjusted to: " .. black_hole_pack_amount .. " for Black-hole Exotic age science pack")
end
