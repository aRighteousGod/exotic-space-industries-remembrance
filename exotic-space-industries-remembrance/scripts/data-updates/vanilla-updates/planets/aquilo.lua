local ei_lib = require("lib/lib")

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
        {type = "fluid", name = "ei-carbon-dioxide", amount = 10, ignored_by_stats = 10},
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
ei_lib.add_unlock_recipe("ei-nitric-acid", "ei-dirty-water-fluorite-nitric")
ei_lib.add_unlock_recipe("ei-carbon-manipulation", "ei-coal-gas-carbon-dioxide")
table.insert(data.raw["technology"]["planet-discovery-aquilo"].effects, {type = "unlock-recipe", recipe = "ei-fluorite-fluorine-calcite"})
table.insert(data.raw["technology"]["planet-discovery-aquilo"].effects, {type = "unlock-recipe", recipe = "ei-fluorine-vent"})
ei_lib.add_unlock_recipe("planet-discovery-aquilo", "ei-carbon-dioxide-vent")

local lithium_plate = ei_lib.raw.recipe["lithium-plate"]
if lithium_plate then
    lithium_plate.results[2] =
    {type = "item", name = "ei-slag", amount_min = 1,amount_max=2, probability = 0.11,ignored_by_stats=2}
    lithium_plate.icon = data.raw.item["lithium-plate"].icon
    lithium_plate.icon_size = data.raw.item["lithium-plate"].icon_size
    lithium_plate.localised_name = {"item-name.lithium-plate"}
    end

local fluoro_cooling = ei_lib.raw.recipe["fluoroketone-cooling"]
if fluoro_cooling then
	fluoro_cooling.ingredients = {
		{ type = "fluid", name = "ei-liquid-nitrogen", amount = 50, ignored_by_stats = 50 },
		{ type = "fluid", name = "fluoroketone-hot", amount = 10, ignored_by_stats = 10 },
	}
	fluoro_cooling.results = {
        { type = "fluid", name = "ei-nitrogen-gas", amount = 125, ignored_by_stats = 125 },
		{ type = "fluid", name = "fluoroketone-cold", amount = 10, temperature = -150, ignored_by_stats = 10 },
	}
end
