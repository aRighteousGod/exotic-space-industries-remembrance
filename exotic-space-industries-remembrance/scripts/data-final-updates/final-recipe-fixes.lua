-- fix recipes that are broken due to patches

local ei_data = require("lib/data")
local ei_lib = require("lib/lib")

--====================================================================================================
--FINAL RECIPE FIXES
--====================================================================================================
-- loop over all recipes and apply fix_recipe
for i,v in pairs(data.raw.recipe) do
    -- get mode of recipe

	ei_lib.fix_recipe(i)
end


-- hide all barrel rcipes that were added by autobarreling from player
-- check if recipe is in fill-barrel or empty-barrel subgroup

for i,v in pairs(data.raw.recipe) do
    if data.raw.recipe[i].subgroup == "fill-barrel" or data.raw.recipe[i].subgroup == "barrel" then
        data.raw.recipe[i].hide_from_player_crafting = true
    end
end

local rocket_part_recipe = data.raw["recipe"]["rocket-part"]
rocket_part_recipe.ingredients = {{type = "item", name = "ei-rocket-parts", amount = 1}}

-- error(serpent.block(data.raw.technology['planet-discovery-gleba']))

--====================================================================================================
--RECIPES THAT ALLOW PRODUCTIVITY
--====================================================================================================

local recipes = {
    "ei-bio-insulated-wire",
    "ei-bio-electronic-parts",
    "ei-bio-magnet",
    "ei-bio-hydrofluoric-acid",
    "ei-bio-nitric-acid",
    "ei-desulfurize-kerosene",
    "ei-kerosene-heavy-oil",
    "ei-hydrofluoric-acid",
    "ei-kerosene-cracking",
    "ei-nitric-acid",
    "ei-crystal-solution",
    "ei-drill-fluid",
    "ei-ammonia",
    "ei-dinitrogen-tetroxide",
    "ei-dinitrogen-tetroxide-water-solution",
    "ei-oxygen-difluoride",
--    "ei-lube-destilation",
    "ei-plastic-benzol",
    "ei-battery-lithium",
    "ei-carbon",
    "ei-lithium-crystal",
    "ei-molten-steel-mix",
    "ei-steam-engine",
    "ei_electron-tube",
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
    "ei-rocket-parts",
    "ei-dark-age-tech",
    "ei-steam-age-tech",
    "ei-electricity-age-tech",
    "ei-computer-age-tech",
    "ei-advanced-computer-age-tech",
    "ei-quantum-age-tech",
    "ei-ceramic",
    "ei-steel-blend",
    "ei-morphium-fluorite",
    "ei-neutron-container",
    "ei-odd-plating",
    "ei-advanced-rocket-fuel",
    "ei-plastic-crushed-coke",
    "ei-rocket-parts-odd-plating",
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
    "rocket",
    "explosive-rocket",
    "ei-molten-steel-oxygen",
    "ei-ceramic-water",
    "ei-solid-fuel-residual-oil",
    "ei-diesel-fuel-unit",
    "ei-benzol-petroleum"
}

local remove_prod = {

}

local crafting_categories = {
    "ei-waver-factory",
    "smelting",
    "rocket-building",
}

-- add them to limitation of productivity modules

for i,v in pairs(recipes) do
    local modify = ei_lib.raw["recipe"][v]
    if modify then
	    modify.allow_productivity = true
    else
        log("final-recipe-fixes: productivity module limitation got bad recipe "..v)
    end
end

-- remove productivity from given recipes

for i,v in pairs(remove_prod) do
    ei_lib.raw["recipe"][v].allow_productivity = false
end

-- get all recipes that have given crafting category and add them to limitation of productivity modules

for i,v in pairs(crafting_categories) do
    for i2,v2 in pairs(data.raw["recipe"]) do
        if v2.category == v then
            v2.allow_productivity = true
        end
    end
end


-- fix recipes that need vanilla iron-ore, copper-ore or iron-gear-wheel/iron-stick
-- loop over all recipes
for name,recipe in pairs(data.raw.recipe) do
    ei_lib.recipe_swap(name, "iron-gear-wheel", "ei-iron-mechanical-parts")
        ei_lib.recipe_swap(name, "steel-gear-wheel", "ei-steel-mechanical-parts")
    ei_lib.recipe_swap(name, "iron-stick", "ei-iron-beam")
    ei_lib.recipe_swap(name, "nuclear-fuel", "ei-uranium-235-fuel")
    ei_lib.recipe_swap(name, "ei-space-data", "space-science-pack")
    ei_lib.recipe_swap(name, "burner-assembling-machine", "ei-steam-assembler")
end

ei_lib.recipe_swap("concrete", "iron-ore", "ei-iron-beam")
ei_lib.recipe_swap("refined-concrete", "ei-copper-mechanical-parts", "ei-steel-beam")
ei_lib.add_unlock_recipe("ei-morphium-usage","ei-undilute-morphium")
ei_lib.add_unlock_recipe("ei-morphium-usage","ei-concentrated-morphium-light-oil")
ei_lib.add_unlock_recipe("ei-morphium-usage","ei-concentrated-morphium-kerosene")
ei_lib.add_unlock_recipe("ei-morphium-usage","ei-concentrated-morphium-heavy-oil")
ei_lib.add_unlock_recipe("ei-morphium-usage","ei-concentrated-morphium-lubricant")

--ei_lib.enable_from_start("iron-stick")
--ei_lib.enable_from_start("iron-gear-wheel")


ei_lib.add_unlock_recipe("steel-processing","ei-1x1-container-filter")
ei_lib.add_unlock_recipe("steel-processing","ei-2x2-container-filter")
ei_lib.add_unlock_recipe("steel-processing","ei-6x6-container-filter")

ei_lib.add_unlock_recipe("steel-processing","ei-1x1-container")
ei_lib.add_unlock_recipe("steel-processing","ei-2x2-container")
ei_lib.add_unlock_recipe("steel-processing","ei-6x6-container")

ei_lib.add_unlock_recipe("logistic-robotics","ei-1x1-container-red")
ei_lib.add_unlock_recipe("logistic-robotics","ei-2x2-container-red")
ei_lib.add_unlock_recipe("logistic-robotics","ei-6x6-container-red")

ei_lib.add_unlock_recipe("logistic-robotics","ei-1x1-container-yellow")
ei_lib.add_unlock_recipe("logistic-robotics","ei-2x2-container-yellow")
ei_lib.add_unlock_recipe("logistic-robotics","ei-6x6-container-yellow")

ei_lib.add_unlock_recipe("logistic-robotics","ei-1x1-container-blue")
ei_lib.add_unlock_recipe("logistic-robotics","ei-2x2-container-blue")
ei_lib.add_unlock_recipe("logistic-robotics","ei-6x6-container-blue")

ei_lib.add_unlock_recipe("logistic-system","ei-1x1-container-green")
ei_lib.add_unlock_recipe("logistic-system","ei-2x2-container-green")
ei_lib.add_unlock_recipe("logistic-system","ei-6x6-container-green")

ei_lib.add_unlock_recipe("logistic-system","ei-1x1-container-pink")
ei_lib.add_unlock_recipe("logistic-system","ei-2x2-container-pink")
ei_lib.add_unlock_recipe("logistic-system","ei-6x6-container-pink")

if mods and mods["aai-signal-transmission"] then
    ei_lib.add_unlock_recipe("aai-signal-transmission","aai-signal-sender")
    ei_lib.remove_unlock_recipe("space-platform","aai-signal-sender")
end
ei_lib.add_unlock_recipe("electronics","stone-tablet")
ei_lib.add_unlock_recipe("ei-steam-power","boiler")
--ei_lib.add_unlock_recipe("ei-glass","glass")
--ei_lib.add_unlock_recipe("steel-processing","steel-gear-wheel")

--ei_lib.add_unlock_recipe("ei-advanced-port","kr-small-roboport")
--ei_lib.add_unlock_recipe("ei-advanced-port","kr-big-roboport")
--ei_lib.add_unlock_recipe("ei-electricity-power","kr-wind-turbine")
ei_lib.add_unlock_recipe("atomic-bomb","nuclear-artillery-shell")
ei_lib.add_unlock_recipe("rocket-silo","ei-orbital-combinator")
--ei_lib.add_unlock_recipe("ei-electronic-parts","electronic-components") --add k2 electronic components to EI equivalent
ei_lib.add_unlock_recipe("lithium-processing","lithium-chloride")

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
      recipeItem.stack_size = 1
      recipeItem.amount = capacity
      recipeItem.ignored_by_stats = capacity
  end
end

for _, recipe in pairs(data.raw.recipe) do

  recipe.always_show_made_in = false
  recipe.always_show_products = false
  recipe.hide_from_signal_gui = false
  recipe.result_is_always_fresh = true
  recipe.unlock_results = true

--  if ei_lib.contains(recipe.name,"recycler") then recipe.surface_conditions = nil end
--  if ei_lib.contains(recipe.name,"crusher") then recipe.surface_conditions = nil end

--This was failing silently, added sanity checks, but seems unnecessary at this time? 4-14-25
  if ei_lib.endswith(recipe.name,"-asteroid-crushing") and data.raw.technology and data.raw.technology[recipe.name] then
    ei_lib.add_unlock_recipe(recipe.name,"crusher")
  end

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


--====================================================================================================
-- FLUID TINTS
--====================================================================================================

data.raw.recipe["rocket-fuel"].crafting_machine_tint =
{
    primary = {r=0.88, g=0.53, b=0.16, a = 1.000},
    secondary = {r=0.49, g=0.48, b=0.46, a = 1.000},
    tertiary = {r=0.57, g=0.7, b=0.47, a = 1.000},
    quaternary = {r=0.83, g=0.11, b=0.05, a = 1.000}
}

data.raw.recipe["heavy-oil-cracking"].crafting_machine_tint =
{
    primary = {r=0.57, g=0.7, b=0.47,a = 1.000},
    secondary = {r=0.75, g=0.88, b=0.75, a = 1.000},
    tertiary = {r = 0.854, g = 0.659, b = 0.576, a = 1.000},
    quaternary = {r = 1.000, g = 0.494, b = 0.271, a = 1.000}
}

data.raw.recipe["ei-solid-fuel-residual-oil"].crafting_machine_tint =
{
    primary = {r=0.49, g=0.36, b=0.13, a = 1.000},
    secondary = {r=0.4, g=0.24, b=0.06, a = 1.000},
    tertiary = {r=0.49, g=0.36, b=0.13, a = 1.000},
    quaternary = {r=0.4, g=0.24, b=0.06, a = 1.000}
}

data.raw.recipe["ei-diesel-fuel-unit"].crafting_machine_tint =
{
	primary = {r=0.64, g=0.59, b=0.49, a = 1.000},
	secondary = {r=0.90, g=0.83, b=0.67, a = 1.000},
	tertiary = {r=0.64, g=0.59, b=0.49, a = 1.000},
	quaternary = {r=0.90, g=0.83, b=0.67, a = 1.000}
}

data.raw.recipe["ei-plastic-benzol"].crafting_machine_tint =
{
	primary = {r = 1.000, g = 1.000, b = 1.000, a = 1.000},
	secondary = {r = 0.771, g = 0.771, b = 0.771, a = 1.000},
	tertiary = {r = 0.768, g = 0.665, b = 0.762, a = 1.000},
	quaternary = {r=0.55, g=0.3, b=0.21, a = 1.000}
}

data.raw.recipe["ei-desulfurize-kerosene"].crafting_machine_tint =
{
	primary = {r=0.64, g=0.59, b=0.49, a = 1.000},
	secondary = {r=0.90, g=0.83, b=0.67, a = 1.000},
	tertiary = {r=0.75, g=0.88, b=0.75, a = 1.000},
	quaternary = {r=0.57, g=0.7, b=0.47,a = 1.000}
}

data.raw.recipe["ei-acidic-water-sulfur"].crafting_machine_tint =
{
	primary = {r = 0.876, g = 0.869, b = 0.597, a = 1.000},
	secondary = {r = 0.969, g = 1.000, b = 0.019, a = 1.000},
	tertiary = {r=0.51, g=0.69, b=0.62, a = 1.000},
	quaternary = {r=0.81, g=0.85, b=0.63, a = 1.000}
}

data.raw.recipe["ei-sulfur-acidic-water"].crafting_machine_tint =
{
	primary = {r=0.51, g=0.69, b=0.62, a = 1.000},
	secondary = {r=0.81, g=0.85, b=0.63, a = 1.000},
	tertiary = {r = 0.876, g = 0.869, b = 0.597, a = 1.000},
	quaternary = {r = 0.969, g = 1.000, b = 0.019, a = 1.000}
}

data.raw.recipe["ei-kerosene-heavy-oil"].crafting_machine_tint =
{
	primary = {r=0.57, g=0.7, b=0.47, a = 1.000},
	secondary = {r=0.75, g=0.88, b=0.75, a = 1.000},
	tertiary = {r = 0.854, g = 0.659, b = 0.576, a = 1.000},
	quaternary = {r = 1.000, g = 0.395, b = 0.127, a = 1.000}
}

data.raw.recipe["ei-benzol-petroleum"].crafting_machine_tint =
{
	primary = {r = 0.764, g = 0.596, b = 0.780, a = 1.000},
	secondary = {r = 0.762, g = 0.551, b = 0.844, a = 1.000},
	tertiary = {r=0.33, g=0.16, b=0.13, a = 1.000},
	quaternary = {r=0.55, g=0.3, b=0.21, a = 1.000}
}

data.raw.recipe["ei-kerosene-cracking"].crafting_machine_tint =
{
	primary = {r = 1.000, g = 0.642, b = 0.261, a = 1.000},
	secondary = {r = 1.000, g = 0.722, b = 0.376, a = 1.000},
	tertiary = {r=0.75, g=0.88, b=0.75, a = 1.000},
	quaternary = {r=0.57, g=0.7, b=0.47,a = 1.000}
}

data.raw.recipe["ei-acidic-water-crushed-sulfur"].crafting_machine_tint =
{
	primary = {r=0.51, g=0.69, b=0.62, a = 1.000},
	secondary = {r=0.81, g=0.85, b=0.63, a = 1.000},
	tertiary = {r = 0.876, g = 0.869, b = 0.597, a = 1.000},
	quaternary = {r = 0.969, g = 1.000, b = 0.019, a = 1.000}
}

data.raw.recipe["ei-drill-fluid"].crafting_machine_tint =
{
	primary = {r=0.49, g=0.48, b=0.44, a = 1.000},
	secondary = {r=0.69, g=0.63, b = 0.771, a = 1.000},
	tertiary = {r = 0.268, g = 0.723, b = 0.223, a = 1.000},
	quaternary = {r = 1.000, g = 0.852, b = 0.172, a = 1.000}
}

data.raw.recipe["ei-lube-destilation"].crafting_machine_tint =
{
	primary = {r = 0.647, g = 0.471, b = 0.396, a = 1.000},
	secondary = {r = 1.000, g = 0.395, b = 0.127, a = 1.000},
	tertiary = {r = 0.268, g = 0.723, b = 0.223, a = 1.000},
	quaternary = {r = 0.432, g = 0.793, b = 0.386, a = 1.000}
}

data.raw.recipe["ei-sus-plating"].crafting_machine_tint =
{
	primary = {r = 0.728, g = 0.818, b = 0.443, a = 1.000},
	secondary = {r = 0.939, g = 0.763, b = 0.191, a = 1.000},
	tertiary = {r = 0.268, g = 0.723, b = 0.223, a = 1.000},
	quaternary = {r = 0.432, g = 0.793, b = 0.386, a = 1.000}
}

data.raw.recipe["ei-bio-hydrofluoric-acid"].crafting_machine_tint =
{
	primary = {r=0.36, g=0.56, b=0.37, a = 1.000},
	secondary = {r=0.57, g=0.68, b=0.39, a = 1.000},
	tertiary = {r = 0.728, g = 0.818, b = 0.443, a = 1.000},
	quaternary = {r = 0.939, g = 0.763, b = 0.191, a = 1.000}
}

data.raw.recipe["ei-bio-nitric-acid"].crafting_machine_tint =
{
	primary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	secondary = {r=0.24, g=0.42, b=0.55, a = 1.000},
	tertiary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	quaternary = {r=0.53, g=0.58, b=0.75, a = 1.000}
}

data.raw.recipe["ei-undilute-morphium"].crafting_machine_tint =
{
	primary   = {r = 0.38, g = 0.52, b = 0.56, a = 1.000},  -- Muted teal-grey
	secondary = {r = 0.48, g = 0.46, b = 0.32, a = 1.000},  -- Dusty olive
	tertiary  = {r = 0.22, g = 0.60, b = 0.66, a = 1.000},  -- Cool cyan
	quaternary= {r = 0.64, g = 0.54, b = 0.58, a = 1.000}   -- Dull mauve
}


data.raw.recipe["ei-concentrated-morphium"].crafting_machine_tint =
{
	primary = {r=0.56, g=0.36, b=0.38, a = 1.000},
	secondary = {r=0.66, g=0.63, b=0.45, a = 1.000},
	tertiary = {r=0, g=0.57, b=0.63, a = 1.000},
	quaternary = {r=0.78, g=0.55, b=0.68, a = 1.000}
}

data.raw.recipe["ei-evolved-alien-seed"].crafting_machine_tint =
{
	primary = {r = 0.728, g = 0.818, b = 0.443, a = 1.000},
	secondary = {r = 0.939, g = 0.763, b = 0.191, a = 1.000},
	tertiary = {r=0.1, g=0.78, b=0.03, a = 1.000},
	quaternary = {r=0.36, g=0.6, b=0.6, a = 1.000}
}

data.raw.recipe["ei-bio-matter"].crafting_machine_tint =
{
	primary = {r = 0.728, g = 0.818, b = 0.443, a = 1.000},
	secondary = {r = 0.939, g = 0.763, b = 0.191, a = 1.000},
	tertiary = {r=0.22, g=0.36, b=0.25, a = 1.000},
	quaternary = {r=0.6, g=0.31, b=0.32, a = 1.000}
}

data.raw.recipe["ei-cryodust"].crafting_machine_tint =
{
	primary = {r=0.1, g=0.78, b=0.83, a = 1.000},
	secondary = {r=0.78, g=0.55, b=0.68, a = 1.000},
	tertiary = {r=0, g=0.57, b=0.63, a = 1.000},
	quaternary = {r=0.1, g=0.78, b=0.83, a = 1.000}
}

data.raw.recipe["ei-molten-steel-mix"].crafting_machine_tint =
{
	primary = {r=0.88, g=0.53, b=0.16, a = 1.000},
	secondary = {r=0.50, g=0.61, b=0.67, a = 1.000},
	tertiary = {r=0.88, g=0.53, b=0.16, a = 1.000},
	quaternary = {r=0.49, g=0.48, b=0.46, a = 1.000}
}

data.raw.recipe["ei-molten-steel-oxygen"].crafting_machine_tint =
{
	primary = {r=0.88, g=0.53, b=0.16, a = 1.000},
	secondary = {r=0.50, g=0.61, b=0.67, a = 1.000},
	tertiary = {r=0.88, g=0.53, b=0.16, a = 1.000},
	quaternary = {r=0.83, g=0.11, b=0.05, a = 1.000}
}

data.raw.recipe["ei-crystal-solution"].crafting_machine_tint =
{
	primary = {r=0.55, g=0.75, b=0.57, a = 1.000},
	secondary = {r=0.48, g=0.3, b=0.36, a = 1.000},
	tertiary = {r=0.36, g=0.56, b=0.37, a = 1.000},
	quaternary = {r=0.57, g=0.68, b=0.39, a = 1.000}
}

data.raw.recipe["ei-hydrogen"].crafting_machine_tint =
{
	primary = {r = 1.0, g = 1.0, b = 1.0, a = 1.000},
	secondary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	tertiary = {r = 1.0, g = 1.0, b = 1.0, a = 1.000},
	quaternary = {r = 1.0, g = 1.0, b = 1.0, a = 1.000}
}

data.raw.recipe["ei-ammonia"].crafting_machine_tint =
{
	primary = {r=0.36, g=0.6, b=0.6, a = 1.000},
	secondary = {r=0.36, g=0.6, b=0.6, a = 1.000},
	tertiary = {r=0.0, g=0.82, b=1, a = 1.000},
	quaternary = {r = 1.0, g = 1.0, b = 1.0, a = 1.000}
}

data.raw.recipe["ei-dinitrogen-tetroxide"].crafting_machine_tint =
{
	primary = {r=0.53, g=0.58, b=0.75, a = 1.000},
	secondary = {r=0.67, g=0.36, b=0.45, a = 1.000},
	tertiary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	quaternary = {r=0.36, g=0.6, b=0.6, a = 1.000}
}

data.raw.recipe["ei-dinitrogen-tetroxide-water-solution"].crafting_machine_tint =
{
	primary = {r=0.53, g=0.58, b=0.75, a = 1.000},
	secondary = {r=0.67, g=0.36, b=0.45, a = 1.000},
	tertiary = {r=0.53, g=0.58, b=0.75, a = 1.000},
	quaternary = {r=0.67, g=0.36, b=0.45, a = 1.000}
}

data.raw.recipe["ei-nitric-acid"].crafting_machine_tint =
{
	primary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	secondary = {r=0.24, g=0.42, b=0.55, a = 1.000},
	tertiary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	quaternary = {r=0.53, g=0.58, b=0.75, a = 1.000}
}

data.raw.recipe["ei-battery-lithium"].crafting_machine_tint =
{
	primary = {r = 0.65, g = 0.81, b = 0.87, a = 1.000},
	secondary = {r = 0.80, g = 0.84, b = 0.73, a = 1.000},
	tertiary = {r = 0.728, g = 0.818, b = 0.443, a = 1.000},
	quaternary = {r = 0.939, g = 0.763, b = 0.191, a = 1.000}
}

data.raw.recipe["ei-silicon"].crafting_machine_tint =
{
	primary = {r = 0.24, g = 0.28, b = 0.40, a = 1.000},
	secondary = {r = 0.55, g = 0.48, b = 0.67, a = 1.000},
	tertiary = {r = 1.0, g = 1.0, b = 1.0, a = 1.000},
	quaternary = {r=0.88, g=0.53, b=0.16, a = 1.000}
}

data.raw.recipe["ei-monosilicon"].crafting_machine_tint =
{
	primary = {r = 0.44, g = 0.31, b = 0.62, a = 1.000},
	secondary = {r = 1.0, g = 1.0, b = 1.0, a = 1.000},
	tertiary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	quaternary = {r = 0.55, g = 0.48, b = 0.67, a = 1.000}
}

data.raw.recipe["ei-neodym-ingot"].crafting_machine_tint =
{
	primary = {r=0.1, g=0.78, b=0.83, a = 1.000},
	secondary = {r=0.64, g=0.56, b=0.63, a = 1.000},
	tertiary = {r=0.0, g=0.82, b=1, a = 1.000},
	quaternary = {r=0.54, g=0.53, b=0.85, a = 1.000}
}

data.raw.recipe["ei-dt-mix"].crafting_machine_tint =
{
	primary = {r=0.0, g=0.51, b=0.58, a = 1.000},
	secondary = {r=0.59, g=0.22, b=0.21, a = 1.000},
	tertiary = {r=0.0, g=0.72, b=0.8, a = 1.000},
	quaternary = {r=0.96, g=0.35, b=0.34, a = 1.000}
}

data.raw.recipe["ei-oxygen-difluoride"].crafting_machine_tint =
{
	primary = {r=0.56, g=0.82, b=0.1, a = 1.000},
	secondary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	tertiary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	quaternary = {r=0.44, g=0.31, b=0.62, a = 1.000}
}

data.raw.recipe["ei-lithium-crystal"].crafting_machine_tint =
{
	primary = {r = 0.65, g = 0.81, b = 0.87, a = 1.000},
	secondary = {r = 0.80, g = 0.84, b = 0.73, a = 1.000},
	tertiary = {r=0.83, g=0.11, b=0.05, a = 1.000},
	quaternary = {r=0.29, g=0.41, b=0.45, a = 1.000}
}

data.raw.recipe["ei-uranium-hexafluorite"].crafting_machine_tint =
{
	primary = {r=0.28, g=1, b=0.6, a = 1.000},
	secondary = {r = 0.210, g = 0.170, b = 0.013, a = 1.000},
	tertiary = {r=0.36, g=0.56, b=0.37, a = 1.000},
	quaternary = {r=0.57, g=0.68, b=0.39, a = 1.000}
}

data.raw.recipe["ei-energy-crystal-washing"].crafting_machine_tint =
{
	primary = {r = 0.51, g = 0.84, b = 0.61, a = 1.000},
	secondary = {r = 0.210, g = 0.170, b = 0.013, a = 1.000},
	tertiary = {r = 1.000, g = 0.978, b = 0.513, a = 1.000},
	quaternary = {r = 0.210, g = 0.170, b = 0.013, a = 1.000}
}

data.raw.recipe["ei-hydrofluoric-acid"].crafting_machine_tint =
{
	primary = {r=0.36, g=0.56, b=0.37, a = 1.000},
	secondary = {r=0.57, g=0.68, b=0.39, a = 1.000},
	tertiary = {r=0.4, g=0.3, b=0.54, a = 1.000},
	quaternary = {r = 0.969, g = 1.000, b = 0.019, a = 1.000}
}

data.raw.recipe["ei-alien-seed-harvesting"].crafting_machine_tint =
{
	primary = {r=0.0, g=0.82, b=1, a = 1.000},
	secondary = {r=0.54, g=0.53, b=0.85, a = 1.000},
	tertiary = {r=0.0, g=0.82, b=1, a = 1.000},
	quaternary = {r=0.54, g=0.53, b=0.85, a = 1.000}
}

data.raw.recipe["ei-nitric-acid-uranium-235"].crafting_machine_tint =
{
	primary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	secondary = {r=0.37, g=0.84, b=0.16, a = 1.000},
	tertiary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	quaternary = {r=0.24, g=0.42, b=0.55, a = 1.000}
}

data.raw.recipe["ei-nitric-acid-plutonium-239"].crafting_machine_tint =
{
	primary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	secondary = {r=0.23, g=0.69, b=0.67, a = 1.000},
	tertiary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	quaternary = {r=0.24, g=0.42, b=0.55, a = 1.000}
}

data.raw.recipe["ei-nitric-acid-thorium-232"].crafting_machine_tint =
{
	primary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	secondary = {r=0.24, g=0.37, b=0.38, a = 1.000},
	tertiary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	quaternary = {r=0.24, g=0.42, b=0.55, a = 1.000}
}

data.raw.recipe["ei-nitric-acid-uranium-233"].crafting_machine_tint =
{
	primary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	secondary = {r=0.24, g=0.37, b=0.38, a = 1.000},
	tertiary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	quaternary = {r=0.35, g=0.65, b=0.36, a = 1.000}
}

data.raw.recipe["ei-cold-coolant"].crafting_machine_tint =
{
	primary = {r=0.88, g=0.65, b=0.42, a = 1.000},
	secondary = {r=0.32, g=0.84, b=0.95, a = 1.000},
	tertiary = {r=0.76, g=0.45, b=0.3, a = 1.000},
	quaternary = {r=0.3, g=0.3, b=0.3, a = 1.000}
}

data.raw.recipe["ei-carbon"].crafting_machine_tint =
{
	primary = {r=0.3, g=0.3, b=0.3, a = 1.000},
	secondary = {r=0.1, g=0.1, b=0.1, a = 1.000},
	tertiary = {r = 1.000, g = 0.978, b = 0.513, a = 1.000},
	quaternary = {r = 0.210, g = 0.170, b = 0.013, a = 1.000}
}
--[[
data:extend({
  {
    name = "ei-gear-to-plates",
    type = "recipe",
    category = "crafting",
    energy_required = 1,
    ingredients = {
        {type="item", name="iron-gear-wheel", amount = 2},
    },
    results = {
        {type = "item", name = "iron-plate", amount = 1},
    },
    enabled = true,
    main_product = "iron-plate",
},
{
    name = "ei-iron-stick-to-iron-parts",
    type = "recipe",
    category = "crafting",
    energy_required = 0.5,
    ingredients = {
        {type="item", name="iron-stick", amount = 2},
    },
    results = {
        {type = "item", name = "ei-iron-mechanical-parts", amount = 1},
    },
    enabled = true,
    main_product = "ei-iron-mechanical-parts",
},
{
    name = "ei-cable-to-plates",
    type = "recipe",
    category = "crafting",
    energy_required = 0.5,
    ingredients = {
        {type="item", name="copper-cable", amount = 2},
    },
    results = {
        {type = "item", name = "copper-plate", amount = 1},
    },
    enabled = true,
    main_product = "copper-plate",
},
{
    name = "ei-cable-to-copper-parts",
    type = "recipe",
    category = "crafting",
    energy_required = 0.5,
    ingredients = {
        {type="item", name="copper-cable", amount = 2},
    },
    results = {
        {type = "item", name = "ei-copper-mechanical-parts", amount = 1},
    },
    enabled = true,
    main_product = "ei-copper-mechanical-parts",
},]]
data:extend({
{
  name = "ei-space-data",
  type = "recipe",
  category = "crafting",
  energy_required = 10,
  ingredients = {
      {type = "item", name = "ei-space-data", amount = 1},
  },
  results = {
      {type = "item", name = "space-science-pack", amount = 1},
  },
  always_show_made_in = false,
  enabled = false,
  main_product = "space-science-pack",
},

})

ei_lib.add_unlock_recipe("space-science-pack","ei-space-data")
