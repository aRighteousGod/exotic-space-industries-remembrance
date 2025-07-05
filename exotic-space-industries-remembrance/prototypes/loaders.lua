ei_loaders_lib = require("lib/ei_loaders_lib")

--====================================================================================================
--BASE PROTOTYPES
--====================================================================================================

data:extend({
    {
    name = "ei-loader-base",
    type = "loader-1x1",
    icon = ei_loaders_item_path.."loader.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation"},
    minable = {
        mining_time = 0.2,
        result = "ei-loader"
    },
    max_health = 300,
    corpse = "small-remnants",
    collision_box = {{-0.4, -0.45}, {0.4, 0.45}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    drawing_box = {{-0.4, -0.4}, {0.4, 0.4}},
    animation_speed_coefficient = 32,
    belt_animation_set = data.raw["transport-belt"]["transport-belt"].belt_animation_set,
    container_distance = 0.75,
    belt_length = 0.5,
    fast_replaceable_group = "transport-belt",
    filter_count = 1,
    -- next_upgrade = "ei-fast-loader",
    speed = data.raw["transport-belt"]["transport-belt"].speed,
    structure = {
        direction_in = {
            sheet = {
                filename = ei_loaders_entity_path.."loader.png",
                priority = "extra-high",
                shift = {0.15625, 0.0703125},
                width = 106*2,
                height = 85*2,
                y = 85*2,
                scale = 0.25
            }
        },
        direction_out = {
            sheet = {
                filename = ei_loaders_entity_path.."loader.png",
                priority = "extra-high",
                shift = {0.15625, 0.0703125},
                width = 106*2,
                height = 85*2,
                scale = 0.25
            }
        }
    },
    circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 12, main_offset = util.by_pixel( 8.375, -2.5), shadow_offset = util.by_pixel( 8.375, -2.5), show_shadow = true },
            { variation = 26, main_offset = util.by_pixel(-3.625,  5.5), shadow_offset = util.by_pixel(-3.625,  5.5), show_shadow = true },
            { variation =  8, main_offset = util.by_pixel(-8.75, -9.625), shadow_offset = util.by_pixel(-8.75, -9.625), show_shadow = true }, 
            { variation = 22, main_offset = util.by_pixel( 4.5,  4.375), shadow_offset = util.by_pixel( 4.5,  4.375), show_shadow = true },
            { variation =  8, main_offset = util.by_pixel(-8.75, -9.625), shadow_offset = util.by_pixel(-8.75, -9.625), show_shadow = true }, 
            { variation = 22, main_offset = util.by_pixel( 4.5,  4.375), shadow_offset = util.by_pixel( 4.5,  4.375), show_shadow = true },
            { variation = 12, main_offset = util.by_pixel( 8.375, -2.5), shadow_offset = util.by_pixel( 8.375, -2.5), show_shadow = true },
            { variation = 26, main_offset = util.by_pixel(-3.625,  5.5), shadow_offset = util.by_pixel(-3.625,  5.5), show_shadow = true }
        }
        ),
    circuit_wire_max_distance = transport_belt_circuit_wire_max_distance
    }
})

--====================================================================================================
--1x1 LOADERS
--====================================================================================================

data:extend({
    {
        name = "ei-loader",
        type = "item",
        icon = ei_loaders_item_path.."loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "loader",
        order = "h[ei-loader]-1",
        place_result = "ei-loader",
        stack_size = 50
    },
    {
        name = "ei-fast-loader",
        type = "item",
        icon = ei_loaders_item_path.."fast-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "loader",
        order = "h[ei-loader]-2",
        place_result = "ei-fast-loader",
        stack_size = 50
    },
    {
        name = "ei-express-loader",
        type = "item",
        icon = ei_loaders_item_path.."express-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "loader",
        order = "h[ei-loader]-3",
        place_result = "ei-express-loader",
        stack_size = 50
    },
    {
        name = "ei-turbo-loader",
        type = "item",
        icon = ei_loaders_item_path.."turbo-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "loader",
        order = "h[ei-loader]-4",
        place_result = "ei-turbo-loader",
        stack_size = 50
    },
    {
        name = "ei-neo-loader",
        type = "item",
        icon = ei_loaders_item_path.."neo-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "loader",
        order = "h[ei-loader]-5",
        place_result = "ei-neo-loader",
        stack_size = 50
    },
    {
        name = "ei-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 30,
        ingredients =
        {
        {type="item", name="transport-belt", amount=4},
        {type="item", name="engine-unit", amount=8},
        {type="item", name="burner-inserter", amount=4},
        {type="item", name="ei-iron-mechanical-parts", amount=20},
        },
        results = {{type="item", name="ei-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-loader",
    },
    {
        name = "ei-fast-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 60,
        ingredients =
        {
        {type="item", name="fast-transport-belt", amount=6},
        {type="item", name="ei-loader", amount=1},
        {type="item", name="ei-cpu", amount=20},
        {type="item", name="fast-inserter", amount=4},
        {type="item", name="electric-engine-unit", amount=10},
        },
        results = {{type="item", name="ei-fast-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-fast-loader",
    },
    {
        name = "ei-express-loader",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 90,
        ingredients =
        {
        {type="item", name="express-transport-belt", amount=8},
        {type="item", name="ei-fast-loader", amount=1},
        {type="item", name="bulk-inserter", amount=4},
        {type="item", name="ei-electronic-parts", amount=20},
        {type="fluid", name="lubricant", amount=50},
        },
        results = {{type="item", name="ei-express-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-express-loader",
    },
    {
        name = "ei-turbo-loader",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 120,
        ingredients =
        {
        {type="item", name="turbo-transport-belt", amount=8},
        {type="item", name="ei-express-loader", amount=1},
        {type="item", name="stack-inserter", amount=4},
        {type="item", name="ei-advanced-motor", amount=20},
        {type="item", name="tungsten-carbide", amount=40},
        {type="fluid", name="electrolyte", amount=100},
        },
        results = {{type="item", name="ei-turbo-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-turbo-loader",
    },
    {
        name = "ei-neo-loader",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 150,
        ingredients =
        {
        {type="item", name="ei-neo-belt", amount=12},
        {type="item", name="ei-turbo-loader", amount=1},
        {type="item", name="ei-magnet", amount=15},
        {type="item", name="ei-high-tech-parts", amount=20},
        {type="item", name="ei-high-energy-crystal", amount=20},
        {type="item", name="ei-neodym-ingot", amount=10},
        {type="fluid", name="ei-liquid-nitrogen", amount=150},
        },
        results = {{type="item", name="ei-neo-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-neo-loader",
    },
})

-- add entities

local belt = data.raw["transport-belt"]["transport-belt"]
local fast_belt = data.raw["transport-belt"]["fast-transport-belt"]
local express_belt = data.raw["transport-belt"]["express-transport-belt"]
local turbo_belt = data.raw["transport-belt"]["turbo-transport-belt"]
local neo_belt = data.raw["transport-belt"]["ei-neo-belt"]

-- add entities
ei_loaders_lib.make_loader(nil, "ei-fast-loader", belt.belt_animation_set, belt.speed)
ei_loaders_lib.make_loader("fast", "ei-express-loader", fast_belt.belt_animation_set, fast_belt.speed)
ei_loaders_lib.make_loader("express", "ei-turbo-loader", express_belt.belt_animation_set, express_belt.speed)
ei_loaders_lib.make_loader("turbo", "ei-neo-loader", turbo_belt.belt_animation_set, turbo_belt.speed)
ei_loaders_lib.make_loader("neo", nil, neo_belt.belt_animation_set, neo_belt.speed)

--Add energy use scaled by items/s
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-loader"],"6000","90000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-fast-loader"],"12000","180000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-express-loader"],"18000","270000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-turbo-loader"],"27000","405000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-neo-loader"],"40500","607500")

--Lane filtering / stacking
local loader = data.raw["loader-1x1"]["ei-express-loader"]
loader.max_belt_stack_size = 2
loader.adjustable_belt_stack_size = true
loader.filter_count = 1
loader.per_lane_filters = false
loader = data.raw["loader-1x1"]["ei-turbo-loader"]
loader.max_belt_stack_size = 2
loader.adjustable_belt_stack_size = true
loader.filter_count = 2
loader.per_lane_filters = true
loader = data.raw["loader-1x1"]["ei-neo-loader"]
loader.max_belt_stack_size = data.raw["utility-constants"]["default"].max_belt_stack_size
loader.adjustable_belt_stack_size = true
-- Default for loaders is 1; increase to inserter value
loader.filter_count = 2 -- Default is 5; set to 2 for lane filters to work
loader.per_lane_filters = true -- Enable lane-specific filtering


table.insert(data.raw["technology"]["logistics"].effects, {
    type = "unlock-recipe",
    recipe = "ei-loader"
})

table.insert(data.raw["technology"]["logistics-2"].effects, {
    type = "unlock-recipe",
    recipe = "ei-fast-loader"
})

table.insert(data.raw["technology"]["logistics-3"].effects, {
    type = "unlock-recipe",
    recipe = "ei-express-loader"
})

table.insert(data.raw["technology"]["turbo-transport-belt"].effects, {
    type = "unlock-recipe",
    recipe = "ei-turbo-loader"
})

table.insert(data.raw["technology"]["ei-neo-logistics"].effects, {
    type = "unlock-recipe",
    recipe = "ei-neo-loader"
})