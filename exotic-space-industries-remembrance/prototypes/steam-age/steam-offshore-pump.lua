--==============================================================================
-- ESIR FILE MAP
-- owns: steam offshore pump item, recipe, technology, entity prototype, and plume smoke
-- loaded_by: exotic-space-industries-remembrance\prototypes\steam-age\steam-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================

local ei_data = require("lib/data")

local name = modprefix.."steam-offshore-pump"
local smoke_name = modprefix.."offshore-pump-steam-smoke"
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

local steam_smoke = table.deepcopy(data.raw["trivial-smoke"]["train-smoke"])
steam_smoke.name = smoke_name
steam_smoke.color = {r = 0.82, g = 0.88, b = 0.92, a = 0.22}
steam_smoke.duration = 150
steam_smoke.spread_duration = 110
steam_smoke.fade_away_duration = 100
steam_smoke.start_scale = 0.18
steam_smoke.end_scale = 1.25

data:extend({
    steam_smoke,
    {
        name = name,
        type = "item",
        icon = base_item.icon,
        icon_size = base_item.icon_size,
        icon_mipmaps = base_item.icon_mipmaps,
        subgroup = "extraction-machine",
        order = "b[fluids]-b[steam-offshore-pump]",
        place_result = name,
        stack_size = 20,
    },
    {
        name = name,
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-burner-offshore-pump", amount = 1},
            {type = "item", name = "ei-steam-engine", amount = 1},
            {type = "item", name = "pipe", amount = 2},
            {type = "item", name = "ei-copper-mechanical-parts", amount = 4},
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
        prerequisites = {"ei-steam-power", "ei-burner-offshore-pump"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = name,
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20,
        },
        age = "steam-age",
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
-- Keep the steam fluid-box anchors inside the offshore pump bounds, but shave the body collision
-- so side-adjacent steam pipes can be placed without colliding with the pump itself.
pump.collision_box = {{-0.32, -1.05}, {0.32, 0.05}}
pump.fast_replaceable_group = "offshore-pump"
pump.next_upgrade = "offshore-pump"
pump.energy_usage = "60kW"
pump.pumping_speed = 20
add_cap_mask_overlay(pump, {r = 1.0, g = 1.0, b = 1.0, a = 0.9})
pump.energy_source = {
    type = "fluid",
    fluid_box = {
        filter = "steam",
        volume = 200,
        pipe_covers = pipecoverspictures(),
        pipe_connections = {
            {flow_direction = "input-output", direction = defines.direction.east, position = {0.25, 0}},
            {flow_direction = "input-output", direction = defines.direction.east, position = {0.25, -1}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {-0.25, 0}},
            {flow_direction = "input-output", direction = defines.direction.west, position = {-0.25, -1}},
        },
        production_type = "input-output",
    },
    effectivity = 0.7,
    scale_fluid_usage = true,
    smoke = {
        {
            name = smoke_name,
            frequency = 4,
            position = {0, -0.9},
            starting_vertical_speed = 0.06,
            starting_frame_deviation = 60,
        },
    },
}

data:extend({pump})
