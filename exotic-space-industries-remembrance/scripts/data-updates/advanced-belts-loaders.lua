-- return if advanced belts is not present
if not mods["AdvancedBeltsSA"] then return end

ei_loaders_lib = require("lib/loaders")
local item_path = ei_graphics_3_path.."graphics/items/"
local entity_path = ei_graphics_3_path.."graphics/entities/"

--====================================================================================================
--1x1 LOADERS
--====================================================================================================

data:extend({
    {
        name = "ei_extreme-loader",
        type = "item",
        icon = item_path.."extreme-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei_loader]_d-ab_1",
        place_result = "ei_extreme-loader",
        stack_size = 50
    },
    {
        name = "ei_extreme-loader",
        type = "recipe",
        category = "metallurgy",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei_turbo-loader", amount=2},
            {type="item", name="holmium-plate", amount=20},
			{type="fluid", name="lubricant", amount=25}
        },
        results = {{type="item", name="ei_extreme-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_extreme-loader",
    },
})

-- add entities

local extreme_belt = data.raw["transport-belt"]["extreme-belt"]
ei_loaders_lib.make_loader("extreme", nil, extreme_belt.belt_animation_set, extreme_belt.speed,item_path,entity_path)
data.raw["loader-1x1"]["ei_turbo-loader"].next_upgrade = "ei_extreme-loader"
table.insert(data.raw["technology"]["extreme-logistics"].effects, {
    type = "unlock-recipe",
    recipe = "ei_extreme-loader"
})


data:extend({
    {
        name = "ei_ultimate-loader",
        type = "item",
        icon = item_path.."ultimate-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei_loader]_d-ab_2",
        place_result = "ei_ultimate-loader",
        stack_size = 50
    },
    {
        name = "ei_ultimate-loader",
        type = "recipe",
        category = "metallurgy",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei_extreme-loader", amount=2},
            {type="item", name="carbon-fiber", amount=20},
            {type="item", name="superconductor", amount=10},
			{type="fluid", name="lubricant", amount=25}
        },
        results = {{type="item", name="ei_ultimate-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_ultimate-loader",
    },
})

-- add entities

local ultimate_belt = data.raw["transport-belt"]["ultimate-belt"]
ei_loaders_lib.make_loader("ultimate", nil, ultimate_belt.belt_animation_set, ultimate_belt.speed,item_path,entity_path)
data.raw["loader-1x1"]["ei_extreme-loader"].next_upgrade = "ei_ultimate-loader"
table.insert(data.raw["technology"]["ultimate-logistics"].effects, {
    type = "unlock-recipe",
    recipe = "ei_ultimate-loader"
})


data:extend({
    {
        name = "ei_high-speed-loader",
        type = "item",
        icon = item_path.."high-speed-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "belt",
        order = "h[ei_loader]_d-ab_3",
        place_result = "ei_high-speed-loader",
        stack_size = 50
    },
    {
        name = "ei_high-speed-loader",
        type = "recipe",
        category = "cryogenics",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei_ultimate-loader", amount=2},
            {type="item", name="lithium-plate", amount=20},
			{type="fluid", name="fluoroketone-cold", amount=50}
        },
        results = {
			{type="item", name="ei_high-speed-loader", amount=1},
			{type="fluid", name="fluoroketone-hot", amount=25}
			
		},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_high-speed-loader",
    },
})

-- add entities

local highspeed_belt = data.raw["transport-belt"]["high-speed-belt"]
ei_loaders_lib.make_loader("high-speed", nil, highspeed_belt.belt_animation_set, highspeed_belt.speed,item_path,entity_path)
data.raw["loader-1x1"]["ei_ultimate-loader"].next_upgrade = "ei_high-speed-loader"
table.insert(data.raw["technology"]["high-speed-logistics"].effects, {
    type = "unlock-recipe",
    recipe = "ei_high-speed-loader"
})

