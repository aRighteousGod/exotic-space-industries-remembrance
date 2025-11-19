--originally by @Samario for Exotic Industries: Loaders (2.0 Port) 
-- return if castra is not present
if not mods["castra"] then return end

ei_loaders_lib = require("lib/loaders")
ei_lib = require("lib/lib")

local item_path = ei_graphics_3_path.."graphics/items/"
local entity_path = ei_graphics_3_path.."graphics/entities/"

data:extend({
    {
        name = "ei-military-loader",
        type = "item",
        icon = item_path.."military-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d",
        place_result = "ei-military-loader",
        stack_size = 50
    },
    {
        name = "ei-military-loader",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-fast-loader", amount=2},
            {type="item", name="nickel-plate", amount=15},
            {type="item", name="engine-unit", amount=5},
			{type="fluid", name="lubricant", amount=10}
        },
        results = {{type="item", name="ei-military-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-military-loader",
    },
})

-- add entities

local military_belt = data.raw["transport-belt"]["military-transport-belt"]
ei_loaders_lib.make_loader("military", nil, military_belt.belt_animation_set, military_belt.speed,item_path,entity_path)
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-military-loader"],"18000","270000")
ei_lib.raw['loader-1x1']['ei-military-loader'].resistances = ei_lib.raw["transport-belt"]["military-transport-belt"].resistances
ei_lib.raw['loader-1x1']['ei-military-loader'].max_health = ei_lib.raw["transport-belt"]["military-transport-belt"].max_health

ei_lib.add_unlock_recipe("military-transport-belt","ei-military-loader")
