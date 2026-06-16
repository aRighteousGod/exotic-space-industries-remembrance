--==============================================================================
-- ESIR FILE MAP
-- owns: burner offshore pump item, recipe, technology, and entity prototype
-- loaded_by: exotic-space-industries-remembrance\prototypes\dark-age\dark-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================

local ei_data = require("lib/data")

local name = modprefix.."burner-offshore-pump"
local base_item = data.raw.item["offshore-pump"]
local base_pump = data.raw["offshore-pump"]["offshore-pump"]
local cap_mask_path = ei_graphics_entity_4_path.."offshore-pump/"

local cap_mask_layers = {
    north = {
        filename = cap_mask_path.."offshore-pump-cap-mask-North.png",
        width = 90,
        height = 162,
        shift = util.by_pixel(-1, -15),
    },
    east = {
        filename = cap_mask_path.."offshore-pump-cap-mask-East.png",
        width = 124,
        height = 102,
        shift = util.by_pixel(15, -2),
    },
    south = {
        filename = cap_mask_path.."offshore-pump-cap-mask-South.png",
        width = 92,
        height = 192,
        shift = util.by_pixel(-1, 0),
    },
    west = {
        filename = cap_mask_path.."offshore-pump-cap-mask-West.png",
        width = 124,
        height = 102,
        shift = util.by_pixel(-15, -2),
    },
}

local function make_cap_mask_layer(direction, tint)
    local layer = table.deepcopy(cap_mask_layers[direction])
    layer.priority = "high"
    layer.line_length = 1
    layer.frame_count = 1
    layer.repeat_count = 32
    layer.animation_speed = 0.25
    layer.scale = 0.5
    layer.tint = tint
    return layer
end

local function add_cap_mask_overlay(pump, tint)
    for direction, _ in pairs(cap_mask_layers) do
        local animation = pump.graphics_set and pump.graphics_set.animation and pump.graphics_set.animation[direction]
        local layers = animation and animation.layers
        if layers then
            table.insert(layers, 2, make_cap_mask_layer(direction, tint))
        end
    end
end

data:extend({
    {
        name = name,
        type = "item",
        icon = base_item.icon,
        icon_size = base_item.icon_size,
        icon_mipmaps = base_item.icon_mipmaps,
        subgroup = "extraction-machine",
        order = "b[fluids]-a[burner-offshore-pump]",
        place_result = name,
        stack_size = 20,
    },
    {
        name = name,
        type = "recipe",
        category = "crafting",
        energy_required = 3,
        ingredients = {
            {type = "item", name = "ei-iron-mechanical-parts", amount = 8},
            {type = "item", name = "ei-copper-mechanical-parts", amount = 4},
            {type = "item", name = "stone-brick", amount = 4},
            {type = "item", name = "burner-inserter", amount = 1},
        },
        results = {{type = "item", name = name, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = name,
    },
    {
        name = name,
        type = "technology",
        icon = base_item.icon,
        icon_size = base_item.icon_size,
        prerequisites = {"ei-dark-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = name,
            },
        },
        unit = {
            count = 75,
            ingredients = ei_data.science["dark-age"],
            time = 20,
        },
        age = "dark-age",
    },
})

local pump = table.deepcopy(base_pump)

pump.name = name
pump.localised_name = {"entity-name."..name}
pump.localised_description = {"entity-description."..name}
pump.icon = base_item.icon
pump.icon_size = base_item.icon_size
pump.icon_mipmaps = base_item.icon_mipmaps
pump.minable = {mining_time = 0.2, result = name}
pump.collision_box = {{-0.32, -1.05}, {0.32, 0.05}}
pump.fast_replaceable_group = "offshore-pump"
pump.next_upgrade = "ei-steam-offshore-pump"
pump.energy_usage = "60kW"
pump.pumping_speed = 20
add_cap_mask_overlay(pump, {r = 1.0, g = 0.08, b = 0.04, a = 1.0})
pump.energy_source = {
    type = "burner",
    fuel_categories = {"chemical"},
    fuel_inventory_size = 1,
    burnt_inventory_size = 1,
    effectivity = 1,
    emissions_per_minute = {pollution = 4},
    smoke = {
        {
            name = "smoke",
            frequency = 4,
            position = {0, -0.9},
            starting_frame_deviation = 60,
        },
    },
}

data:extend({pump})
