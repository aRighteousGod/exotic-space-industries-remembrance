--originally by @Samario for Exotic Industries: Loaders (2.0 Port) 
-- return if Factorio+ is not present
if not mods["factorioplus"] then return end

ei_loaders_lib = require("lib/loaders")
ei_lib = require("lib/lib")

local item_path = ei_graphics_3_path.."graphics/items/"
local entity_path = ei_graphics_3_path.."graphics/entities/"


data:extend({
    {
        name = "ei-fplus-turbo-loader",
        type = "item",
        icon = item_path.."turbo-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d",
        place_result = "ei-fplus-turbo-loader",
        stack_size = 50
    },
    {
        name = "ei-fplus-turbo-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-express-loader", amount=2},
            {type="item", name="processing-unit", amount=12},
            {type="item", name="speed-module", amount=4},
        },
        results = {{type="item", name="ei-fplus-turbo-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-fplus-turbo-loader",
    },
    {
        name = "ei-fplus-sonic-loader",
        type = "item",
        icon = item_path.."fplus-sonic-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei_loader]_d",
        place_result = "ei-fplus-sonic-loader",
        stack_size = 50
    },
    {
        name = "ei-fplus-sonic-loader",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-express-loader", amount=2},
            {type="item", name="processing-unit", amount=12},
            {type="item", name="speed-module-2", amount=4},
			{type="fluid",name="lubricant", amount=30},
        },
        results = {{type="item", name="ei-fplus-sonic-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-fplus-sonic-loader",
    },
})

-- add entities

local turbo_belt = data.raw["transport-belt"]["turbo-transport-belt"]
ei_loaders_lib.make_loader("fplus-turbo", nil, turbo_belt.belt_animation_set, turbo_belt.speed,item_path,entity_path)

-- set next replacable for express loader
data.raw["loader-1x1"]["ei-express-loader"].next_upgrade = "ei-fplus-turbo-loader"
ei_lib.add_unlock_recipe("logistics-4","ei-fplus-turbo-loader")


local sonic_belt = data.raw["transport-belt"]["supersonic-transport-belt"]
ei_loaders_lib.make_loader("fplus-sonic", nil, sonic_belt.belt_animation_set, sonic_belt.speed,item_path,entity_path)

-- set next replacable for express loader
data.raw["loader-1x1"]["ei-fplus-turbo-loader"].next_upgrade = "ei-fplus-sonic-loader"
ei_lib.add_unlock_recipe("logistics-5","ei-fplus-sonic-loader")
