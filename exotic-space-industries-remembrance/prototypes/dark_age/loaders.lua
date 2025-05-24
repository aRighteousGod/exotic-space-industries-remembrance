ei_loaders_lib = require("lib/ei_loaders_lib")

--====================================================================================================
--BASE PROTOTYPES
--====================================================================================================

local loader = {
    name = "ei-loader",
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
}

--====================================================================================================
--UTIL FUNCTIONS
--====================================================================================================

function ei_loaders_lib.make_loader(tier, next_upgrade, belt_animation_set, speed)
    local loader = table.deepcopy(loader)

    if tier then
        tier = tier .. "-"
    else
        tier = ""
    end

    if next_upgrade then
        loader.next_upgrade = next_upgrade
    end
    
    loader.name = "ei-"..tier.."loader"
    loader.icon = ei_loaders_item_path..tier.."loader.png"
    loader.minable.result = "ei-"..tier.."loader"
    loader.speed = speed
    loader.belt_animation_set = belt_animation_set
    loader.circuit_connector =  circuit_connector_definitions.create_vector(
      universal_connector_template,
      {
        { variation = 4, main_offset = util.by_pixel(3, 2), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
        { variation = 2, main_offset = util.by_pixel(-11, -5), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
        { variation = 0, main_offset = util.by_pixel(-3, -23), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
        { variation = 6, main_offset = util.by_pixel(10, -17), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },

        { variation = 0, main_offset = util.by_pixel(-3, -23), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
        { variation = 6, main_offset = util.by_pixel(10, -17), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
        { variation = 4, main_offset = util.by_pixel(3, 2), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
        { variation = 2, main_offset = util.by_pixel(-11, -5), shadow_offset = util.by_pixel(7.5, 7.5), show_shadow = false },
      }
    )
    loader.circuit_wire_max_distance = transport_belt_circuit_wire_max_distance
    loader.structure.direction_in.sheet.filename = ei_loaders_entity_path..tier.."loader.png"
    loader.structure.direction_out.sheet.filename = ei_loaders_entity_path..tier.."loader.png"

    data:extend({loader})
end

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
        name = "ei-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="transport-belt", amount=4},
            {type="item", name="ei-iron-mechanical-parts", amount=6}, --circuit
            {type="item", name="iron-plate", amount=6},
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
        energy_required = 3,
        ingredients =
        {
            {type="item", name="ei-loader", amount=1},
            {type="item", name="electronic-circuit", amount=20},
            {type="item", name="iron-gear-wheel", amount=20},
        },
        results = {{type="item", name="ei-fast-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-fast-loader",
    },
    {
        name = "ei-express-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-fast-loader", amount=1},
            {type="item", name="advanced-circuit", amount=20},
            {type="item", name="iron-gear-wheel", amount=40},
        },
        results = {{type="item", name="ei-express-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-express-loader",
    },
})

-- add entities

local belt = data.raw["transport-belt"]["transport-belt"]
local fast_belt = data.raw["transport-belt"]["fast-transport-belt"]
local express_belt = data.raw["transport-belt"]["express-transport-belt"]

ei_loaders_lib.make_loader(nil, "ei-fast-loader", belt.belt_animation_set, belt.speed)
ei_loaders_lib.make_loader("fast", "ei-express-loader", fast_belt.belt_animation_set, fast_belt.speed)
ei_loaders_lib.make_loader("express", nil, express_belt.belt_animation_set, express_belt.speed)


data:extend({
    {
        name = "ei-neo-loader",
        type = "item",
        icon = ei_loaders_item_path.."neo-loader.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "loader",
        order = "h[ei-loader]-4",
        place_result = "ei-neo-loader",
        stack_size = 50
    },
    {
        name = "ei-neo-loader",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-express-loader", amount=2},
            {type="item", name="processing-unit", amount=12},
            {type="item", name="ei-high-energy-crystal", amount=4},
        },
        results = {{type="item", name="ei-neo-loader", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-neo-loader",
    },
})

-- add entities

local neo_belt = data.raw["transport-belt"]["ei-neo-belt"]
ei_loaders_lib.make_loader("neo", nil, neo_belt.belt_animation_set, neo_belt.speed)

-- set next replacable for express loader
data.raw["loader-1x1"]["ei-express-loader"].next_upgrade = "ei-neo-loader"

--Add electricity use scaled by items/s
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-loader"],"1000","60000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-fast-loader"],"2000","120000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-express-loader"],"3000","180000")
ei_loaders_lib.addEnergyDraw(data.raw["loader-1x1"]["ei-neo-loader"],"4000","240000")

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

table.insert(data.raw["technology"]["ei-neo-logistics"].effects, {
    type = "unlock-recipe",
    recipe = "ei-neo-loader"
})