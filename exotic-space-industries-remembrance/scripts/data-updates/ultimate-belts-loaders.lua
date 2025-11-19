--originally by @Samario for Exotic Industries: Loaders (2.0 Port) 
-- return if any of the ultimate belts is not present
if not (mods["UltimateBeltsSpaceAge"] or mods["UltimateBeltsSpaceAgeFork"] or mods["NovasUltimateBelts"]) then return end

ei_loaders_lib = require("lib/loaders")
ei_lib = require("lib/lib")

local item_path = ei_graphics_3_path.."graphics/items/"
local entity_path = ei_graphics_3_path.."graphics/entities/"

--====================================================================================================
--1x1 LOADERS
--====================================================================================================

data:extend({
    {
        name = "ei-ultra-fast-loader",
        type = "item",
        icon = item_path.."ultra-fast-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d-ub-1",
        place_result = "ei-ultra-fast-loader",
        stack_size = 50
    },
    {
        name = "ei-ultra-fast-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-turbo-loader", amount=2},
            {type="item", name="ei-iron-mechanical-parts", amount=50}
        },
        results = {{type="item", name="ei-ultra-fast-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-ultra-fast-loader",
    },
})

-- add entities

local ultrafast_belt = data.raw["transport-belt"]["ultra-fast-belt"]
ei_loaders_lib.make_loader("ultra-fast", nil, ultrafast_belt.belt_animation_set, ultrafast_belt.speed,item_path,entity_path)
ei_lib.add_unlock_recipe("ultra-fast-logistics","ei-ultra-fast-loader")

data:extend({
    {
        name = "ei-extreme-fast-loader",
        type = "item",
        icon = item_path.."extreme-fast-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d-ub-2",
        place_result = "ei-extreme-fast-loader",
        stack_size = 50
    },
    {
        name = "ei-extreme-fast-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-turbo-loader", amount=1},
            {type="item", name="ei-ultra-fast-loader", amount=2},
            {type="item", name="ei-iron-mechanical-parts", amount=100}
        },
        results = {{type="item", name="ei-extreme-fast-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-extreme-fast-loader",
    },
})

-- add entities

local extremefast_belt = data.raw["transport-belt"]["extreme-fast-belt"]
ei_loaders_lib.make_loader("extreme-fast", nil, extremefast_belt.belt_animation_set, extremefast_belt.speed,item_path,entity_path)
ei_lib.add_unlock_recipe("extreme-fast-logistics","ei-extreme-fast-loader")

data:extend({
    {
        name = "ei-ultra-express-loader",
        type = "item",
        icon = ei_loaders_item_path.."ultra-express-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d-ub-3",
        place_result = "ei-ultra-express-loader",
        stack_size = 50
    },
    {
        name = "ei-ultra-express-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-turbo-loader", amount=1},
            {type="item", name="ei-extreme-fast-loader", amount=2},
            {type="item", name="speed-module", amount=10}
        },
        results = {{type="item", name="ei-ultra-express-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-ultra-express-loader",
    },
})

-- add entities

local ultraexpress_belt = data.raw["transport-belt"]["ultra-express-belt"]
ei_loaders_lib.make_loader("ultra-express", nil, ultraexpress_belt.belt_animation_set, ultraexpress_belt.speed,item_path,entity_path)
ei_lib.add_unlock_recipe("ultra-express-logistics","ei-ultra-express-loader")

data:extend({
    {
        name = "ei-extreme-express-loader",
        type = "item",
        icon = item_path.."extreme-express-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d-ub-4",
        place_result = "ei-extreme-express-loader",
        stack_size = 50
    },
    {
        name = "ei-extreme-express-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-turbo-loader", amount=1},
            {type="item", name="ei-ultra-express-loader", amount=2},
            {type="item", name="speed-module-2", amount=7}
        },
        results = {{type="item", name="ei-extreme-express-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-extreme-express-loader",
    },
})

-- add entities

local extremeexpress_belt = data.raw["transport-belt"]["extreme-express-belt"]
ei_loaders_lib.make_loader("extreme-express", nil, extremeexpress_belt.belt_animation_set, extremeexpress_belt.speed,item_path,entity_path)

ei_lib.add_unlock_recipe("extreme-express-logistics","ei-extreme-express-loader")

data:extend({
    {
        name = "ei-ultimate-nova-loader",
        type = "item",
        icon = item_path.."ultimate-nova-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei-loader]-d-ub-5",
        place_result = "ei-ultimate-nova-loader",
        stack_size = 50
    },
    {
        name = "ei-ultimate-nova-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-turbo-loader", amount=1},
            {type="item", name="ei-extreme-express-loader", amount=2},
            {type="item", name="speed-module-3", amount=5}
        },
        results = {{type="item", name="ei-ultimate-nova-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-ultimate-nova-loader",
    },
})

-- add entities

local ultimatenova_belt = data.raw["transport-belt"]["ultimate-belt"]
ei_loaders_lib.make_loader("ultimate-nova", nil, ultimatenova_belt.belt_animation_set, ultimatenova_belt.speed,item_path,entity_path)
ei_lib.add_unlock_recipe("ultimate-logistics","ei-ultimate-nova-loader")

