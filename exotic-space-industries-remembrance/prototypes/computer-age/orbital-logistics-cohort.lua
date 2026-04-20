--==============================================================================
-- ESIR FILE MAP
-- owns: orbital logistics cohort prototypes, items, recipes, and helper signals
-- loaded_by: exotic-space-industries-remembrance\prototypes\computer-age\computer-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================
require("__base__.prototypes.entity.combinator-pictures")
require("util")

local sounds = require("__base__.prototypes.entity.sounds")

local BASE_TERMINAL_SPRITE_SCALE = 0.5
local BASE_TERMINAL_SPRITE_SHIFT_PIXELS = {0, 5}
local BASE_TERMINAL_SHADOW_SHIFT_PIXELS = {8.5, 5.5}
local BASE_TERMINAL_CONNECTION_PIXELS = {
    {
        shadow = {
            red = {7, -6},
            green = {23, -6},
        },
        wire = {
            red = {-8.5, -14.5},
            green = {7, -14.5},
        },
    },
    {
        shadow = {
            red = {32, -5},
            green = {32, 8},
        },
        wire = {
            red = {15, -13.5},
            green = {17.5, -0.5},
        },
    },
    {
        shadow = {
            red = {25, 20},
            green = {9, 20},
        },
        wire = {
            red = {9, 9.5},
            green = {-6, 9.5},
        },
    },
    {
        shadow = {
            red = {1, 11},
            green = {1, -2},
        },
        wire = {
            red = {-14, 3.5},
            green = {-16, -10.5},
        },
    },
}

local function make_orbital_icon(base_icon, tint)
    return {
        {
            icon = base_icon,
            icon_size = 64,
        },
        {
            icon = ei_graphics_other_path .. "overlay_1.png",
            icon_size = 64,
            tint = tint,
        },
    }
end

local function pixel_position(x, y)
    return {x / 32, y / 32}
end

local function scale_connection_position(base_position, scale_factor, shift_delta)
    return pixel_position(
        base_position[1] * scale_factor + shift_delta[1],
        base_position[2] * scale_factor + shift_delta[2]
    )
end

local function get_connection_scale_from_box(selection_box)
    if type(selection_box) ~= "table" then
        return 1
    end

    local left_top = selection_box[1]
    local right_bottom = selection_box[2]
    if type(left_top) ~= "table" or type(right_bottom) ~= "table" then
        return 1
    end

    local width = math.abs((right_bottom[1] or 0) - (left_top[1] or 0))
    local height = math.abs((right_bottom[2] or 0) - (left_top[2] or 0))
    return math.max(1, width, height)
end

local function make_scaled_connection_points(params)
    local sprite_shift_pixels = params.sprite_shift_pixels or BASE_TERMINAL_SPRITE_SHIFT_PIXELS
    local shadow_shift_pixels = params.shadow_shift_pixels or BASE_TERMINAL_SHADOW_SHIFT_PIXELS
    local footprint_scale = get_connection_scale_from_box(params.selection_box)
    local wire_connection_scale = params.wire_connection_scale or footprint_scale
    local shadow_connection_scale = params.shadow_connection_scale or wire_connection_scale

    local sprite_delta = {
        sprite_shift_pixels[1] - BASE_TERMINAL_SPRITE_SHIFT_PIXELS[1],
        sprite_shift_pixels[2] - BASE_TERMINAL_SPRITE_SHIFT_PIXELS[2],
    }
    local shadow_delta = {
        shadow_shift_pixels[1] - BASE_TERMINAL_SHADOW_SHIFT_PIXELS[1],
        shadow_shift_pixels[2] - BASE_TERMINAL_SHADOW_SHIFT_PIXELS[2],
    }

    local points = {}
    for index, base_point in ipairs(BASE_TERMINAL_CONNECTION_PIXELS) do
        points[index] = {
            shadow = {
                red = scale_connection_position(base_point.shadow.red, shadow_connection_scale, shadow_delta),
                green = scale_connection_position(base_point.shadow.green, shadow_connection_scale, shadow_delta),
            },
            wire = {
                red = scale_connection_position(base_point.wire.red, wire_connection_scale, sprite_delta),
                green = scale_connection_position(base_point.wire.green, wire_connection_scale, sprite_delta),
            },
        }
    end

    return points
end

local function make_constant_terminal(base, params)
    local entity = table.deepcopy(base)
    entity.name = params.name
    entity.localised_name = {"entity-name." .. params.name}
    entity.localised_description = {"item-description." .. params.name}
    entity.icon = params.icon
    entity.icons = make_orbital_icon(params.icon, params.tint)
    entity.minable = {mining_time = 0.1, result = params.name}
    entity.collision_box = params.collision_box
    entity.selection_box = params.selection_box
    entity.fast_replaceable_group = params.fast_replaceable_group or params.name
    entity.item_slot_count = params.item_slot_count or 256
    entity.order = params.order
    entity.corpse = nil
    entity.graphics_set = nil
    local sprite_shift_pixels = params.sprite_shift_pixels or BASE_TERMINAL_SPRITE_SHIFT_PIXELS
    local shadow_shift_pixels = params.shadow_shift_pixels or BASE_TERMINAL_SHADOW_SHIFT_PIXELS

    entity.sprites = make_4way_animation_from_spritesheet({
        layers = {
            {
                filename = params.sprite,
                width = params.sprite_width,
                height = params.sprite_height,
                frame_count = 1,
                shift = util.by_pixel(sprite_shift_pixels[1], sprite_shift_pixels[2]),
                scale = params.sprite_scale,
                tint = params.sprite_tint or params.tint,
            },
            params.shadow and {
                filename = params.shadow,
                width = params.shadow_width,
                height = params.shadow_height,
                frame_count = 1,
                shift = util.by_pixel(shadow_shift_pixels[1], shadow_shift_pixels[2]),
                scale = params.shadow_scale or params.sprite_scale,
                draw_as_shadow = true,
            } or nil,
        }
    })

    entity.activity_led_sprites = nil
    entity.activity_led_light = {
        intensity = 0,
        size = 0.5,
        color = {r = 1.0, g = 0.55, b = 0.15}
    }
    entity.activity_led_light_offsets = {
        {0.0, -0.25},
        {0.25, 0.0},
        {0.0, 0.25},
        {-0.25, 0.0},
    }
    entity.open_sound = sounds.machine_open
    entity.close_sound = sounds.machine_close
    entity.vehicle_impact_sound = sounds.generic_impact
    -- The shared 1x1 scanner sprite stays compact, but wire anchors should still
    -- land near each terminal's real footprint edge so large cohort terminals do
    -- not feel like they wire into the middle of empty space.
    entity.circuit_wire_connection_points = make_scaled_connection_points(params)
    entity.circuit_wire_max_distance = params.circuit_wire_max_distance or 18
    return entity
end

local base_combinator = data.raw["constant-combinator"]["constant-combinator"]
local shared_terminal_sprite = ei_graphics_3_path .. "graphics/entities/orbital-request-combinator/orbital-request-combinator.png"
local shared_terminal_shadow = ei_graphics_3_path .. "graphics/entities/orbital-request-combinator/orbital-request-combinator-shadow.png"

local transponder_icon = ei_graphics_3_path .. "graphics/icons/orbital-request-combinator.png"
local selector_icon = ei_graphics_item_path .. "alien-console.png"
local coordinator_icon = ei_graphics_item_path .. "computer-core.png"
local uplink_icon = ei_fueler_graphics_path .. "fueler_icon.png"

local function make_hidden_power_sensor(params)
    local sensor = table.deepcopy(data.raw["lamp"]["small-lamp"])
    sensor.name = params.name
    sensor.localised_name = {"entity-name." .. params.entity_name}
    sensor.localised_description = {"item-description." .. params.entity_name}
    sensor.icon = params.icon
    sensor.icons = make_orbital_icon(params.icon, params.tint)
    sensor.icon_size = 64
    sensor.flags = {
        "not-blueprintable",
        "not-deconstructable",
        "not-on-map",
        "not-flammable",
        "not-repairable",
        "not-upgradable",
        "not-selectable-in-game",
        "placeable-off-grid",
        "hide-alt-info",
    }
    sensor.hidden = true
    sensor.selectable_in_game = false
    sensor.minable = nil
    sensor.max_health = 1
    sensor.collision_box = {{0, 0}, {0, 0}}
    sensor.selection_box = {{0, 0}, {0, 0}}
    sensor.collision_mask = {layers = {}}
    sensor.always_on = true
    sensor.energy_source = {
        type = "electric",
        usage_priority = "lamp",
    }
    sensor.energy_usage_per_tick = params.energy_usage_per_tick
    sensor.energy_usage = nil
    sensor.light = {
        intensity = 0,
        size = 0,
        color = {r = 1, g = 1, b = 1},
    }
    sensor.picture_on = util.empty_sprite()
    sensor.picture_off = util.empty_sprite()
    sensor.circuit_wire_max_distance = 0
    return sensor
end

local orbital_power_sensors = {
    make_hidden_power_sensor{
        name = "ei-platform-transponder-power-sensor",
        entity_name = "ei-platform-transponder",
        icon = transponder_icon,
        tint = {r = 0.55, g = 0.95, b = 1.0, a = 0.95},
        energy_usage_per_tick = "100kW",
    },
    make_hidden_power_sensor{
        name = "ei-orbital-selector-power-sensor",
        entity_name = "ei-orbital-selector",
        icon = selector_icon,
        tint = {r = 0.95, g = 0.75, b = 0.20, a = 0.95},
        energy_usage_per_tick = "250kW",
    },
    make_hidden_power_sensor{
        name = "ei-orbital-coordinator-power-sensor",
        entity_name = "ei-orbital-coordinator",
        icon = coordinator_icon,
        tint = {r = 1.0, g = 0.40, b = 0.18, a = 0.95},
        energy_usage_per_tick = "500kW",
    },
    make_hidden_power_sensor{
        name = "ei-orbital-dispatch-uplink-power-sensor",
        entity_name = "ei-orbital-dispatch-uplink",
        icon = uplink_icon,
        tint = {r = 1.0, g = 0.62, b = 0.15, a = 0.95},
        energy_usage_per_tick = "350kW",
    },
}

local orbital_entities = {
    make_constant_terminal(base_combinator, {
        name = "ei-platform-transponder",
        icon = transponder_icon,
        tint = {r = 0.55, g = 0.95, b = 1.0, a = 0.95},
        collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        fast_replaceable_group = "ei-orbital-cohort-terminal",
        item_slot_count = 32,
        order = "c[combinators]-d[platform-transponder]",
        sprite = shared_terminal_sprite,
        sprite_width = 114,
        sprite_height = 102,
        sprite_shift_pixels = {0, 5},
        sprite_scale = 0.5,
        shadow = shared_terminal_shadow,
        shadow_width = 98,
        shadow_height = 66,
        shadow_shift_pixels = {8.5, 5.5},
        shadow_scale = 0.5,
        circuit_wire_max_distance = 18,
    }),
    make_constant_terminal(base_combinator, {
        name = "ei-orbital-selector",
        icon = selector_icon,
        tint = {r = 0.95, g = 0.75, b = 0.20, a = 0.95},
        collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
        selection_box = {{-1.0, -1.0}, {1.0, 1.0}},
        fast_replaceable_group = "ei-orbital-cohort-terminal",
        item_slot_count = 512,
        order = "c[combinators]-e[orbital-selector]",
        sprite = shared_terminal_sprite,
        sprite_width = 114,
        sprite_height = 102,
        sprite_shift_pixels = {0, 7},
        sprite_scale = 0.85,
        shadow = shared_terminal_shadow,
        shadow_width = 98,
        shadow_height = 66,
        shadow_shift_pixels = {14.5, 9.5},
        shadow_scale = 0.85,
        circuit_wire_max_distance = 18,
    }),
    make_constant_terminal(base_combinator, {
        name = "ei-orbital-coordinator",
        icon = coordinator_icon,
        tint = {r = 1.0, g = 0.40, b = 0.18, a = 0.95},
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        fast_replaceable_group = "ei-orbital-cohort-terminal",
        item_slot_count = 128,
        order = "c[combinators]-f[orbital-coordinator]",
        sprite = shared_terminal_sprite,
        sprite_width = 114,
        sprite_height = 102,
        sprite_shift_pixels = {0, 14},
        sprite_scale = 1.95,
        shadow = shared_terminal_shadow,
        shadow_width = 98,
        shadow_height = 66,
        shadow_shift_pixels = {31.5, 23.5},
        shadow_scale = 1.95,
        circuit_wire_max_distance = 24,
    }),
    make_constant_terminal(base_combinator, {
        name = "ei-orbital-dispatch-uplink",
        icon = uplink_icon,
        tint = {r = 1.0, g = 0.62, b = 0.15, a = 0.95},
        collision_box = {{-0.8, -0.8}, {0.8, 0.8}},
        selection_box = {{-1.0, -1.0}, {1.0, 1.0}},
        fast_replaceable_group = "ei-orbital-cohort-terminal",
        item_slot_count = 512,
        order = "c[combinators]-g[orbital-dispatch-uplink]",
        sprite = shared_terminal_sprite,
        sprite_width = 114,
        sprite_height = 102,
        sprite_shift_pixels = {0, 7},
        sprite_scale = 0.85,
        shadow = shared_terminal_shadow,
        shadow_width = 98,
        shadow_height = 66,
        shadow_shift_pixels = {14.5, 9.5},
        shadow_scale = 0.85,
        circuit_wire_max_distance = 18,
    }),
}

local orbital_items = {
    {
        type = "item",
        se_allow_in_space = true,
        name = "ei-platform-transponder",
        icon = transponder_icon,
        icons = make_orbital_icon(transponder_icon, {r = 0.55, g = 0.95, b = 1.0, a = 0.95}),
        icon_size = 64,
        subgroup = "circuit-network",
        order = "c[combinators]-d[platform-transponder]",
        place_result = "ei-platform-transponder",
        stack_size = 50,
    },
    {
        type = "item",
        se_allow_in_space = true,
        name = "ei-orbital-selector",
        icon = selector_icon,
        icons = make_orbital_icon(selector_icon, {r = 0.95, g = 0.75, b = 0.20, a = 0.95}),
        icon_size = 64,
        subgroup = "circuit-network",
        order = "c[combinators]-e[orbital-selector]",
        place_result = "ei-orbital-selector",
        stack_size = 20,
    },
    {
        type = "item",
        se_allow_in_space = true,
        name = "ei-orbital-coordinator",
        icon = coordinator_icon,
        icons = make_orbital_icon(coordinator_icon, {r = 1.0, g = 0.40, b = 0.18, a = 0.95}),
        icon_size = 64,
        subgroup = "circuit-network",
        order = "c[combinators]-f[orbital-coordinator]",
        place_result = "ei-orbital-coordinator",
        stack_size = 10,
    },
    {
        type = "item",
        se_allow_in_space = true,
        name = "ei-orbital-dispatch-uplink",
        icon = uplink_icon,
        icons = make_orbital_icon(uplink_icon, {r = 1.0, g = 0.62, b = 0.15, a = 0.95}),
        icon_size = 64,
        subgroup = "circuit-network",
        order = "c[combinators]-g[orbital-dispatch-uplink]",
        place_result = "ei-orbital-dispatch-uplink",
        stack_size = 20,
    },
}

local orbital_recipes = {
    {
        type = "recipe",
        name = "ei-platform-transponder",
        enabled = false,
        energy_required = 10,
        ingredients = {
            {type = "item", name = "constant-combinator", amount = 1},
            {type = "item", name = "copper-cable", amount = 10},
            {type = "item", name = "radar", amount = 1},
        },
        results = {{type = "item", name = "ei-platform-transponder", amount = 1}},
    },
    {
        type = "recipe",
        name = "ei-orbital-selector",
        enabled = false,
        energy_required = 20,
        ingredients = {
            {type = "item", name = "arithmetic-combinator", amount = 1},
            {type = "item", name = "constant-combinator", amount = 2},
            {type = "item", name = "advanced-circuit", amount = 10},
            {type = "item", name = "radar", amount = 1},
        },
        results = {{type = "item", name = "ei-orbital-selector", amount = 1}},
    },
    {
        type = "recipe",
        name = "ei-orbital-coordinator",
        enabled = false,
        energy_required = 40,
        ingredients = {
            {type = "item", name = "ei-computer-core", amount = 1},
            {type = "item", name = "processing-unit", amount = 20},
            {type = "item", name = "low-density-structure", amount = 10},
            {type = "item", name = "ei-orbital-selector", amount = 2},
        },
        results = {{type = "item", name = "ei-orbital-coordinator", amount = 1}},
    },
    {
        type = "recipe",
        name = "ei-orbital-dispatch-uplink",
        enabled = false,
        energy_required = 30,
        ingredients = {
            {type = "item", name = "ei-orbital-selector", amount = 1},
            {type = "item", name = "processing-unit", amount = 8},
            {type = "item", name = "ei-advanced-motor", amount = 4},
            {type = "item", name = "radar", amount = 2},
        },
        results = {{type = "item", name = "ei-orbital-dispatch-uplink", amount = 1}},
    },
}

local orbital_signals = {
    {
        type = "virtual-signal",
        name = "ei-platform-id",
        icon = transponder_icon,
        icon_size = 64,
        icons = make_orbital_icon(transponder_icon, {r = 0.55, g = 0.95, b = 1.0, a = 0.95}),
        order = "ei-orbital-b",
    },
    {
        type = "virtual-signal",
        name = "ei-orbital-ready",
        icon = selector_icon,
        icon_size = 64,
        icons = make_orbital_icon(selector_icon, {r = 0.45, g = 0.95, b = 0.45, a = 0.95}),
        order = "ei-orbital-c",
    },
    {
        type = "virtual-signal",
        name = "ei-orbital-blocked",
        icon = coordinator_icon,
        icon_size = 64,
        icons = make_orbital_icon(coordinator_icon, {r = 1.0, g = 0.62, b = 0.15, a = 0.95}),
        order = "ei-orbital-d",
    },
    {
        type = "virtual-signal",
        name = "ei-orbital-invalid",
        icon = selector_icon,
        icon_size = 64,
        icons = make_orbital_icon(selector_icon, {r = 0.95, g = 0.25, b = 0.20, a = 0.95}),
        order = "ei-orbital-e",
    },
    {
        type = "virtual-signal",
        name = "ei-orbital-lease",
        icon = coordinator_icon,
        icon_size = 64,
        icons = make_orbital_icon(coordinator_icon, {r = 1.0, g = 0.85, b = 0.20, a = 0.95}),
        order = "ei-orbital-f",
    },
}

data:extend(orbital_power_sensors)
data:extend(orbital_entities)
data:extend(orbital_items)
data:extend(orbital_recipes)
data:extend(orbital_signals)

if data.raw.technology["rocket-silo"] then
    local effects = data.raw.technology["rocket-silo"].effects or {}
    effects[#effects + 1] = {type = "unlock-recipe", recipe = "ei-platform-transponder"}
    effects[#effects + 1] = {type = "unlock-recipe", recipe = "ei-orbital-selector"}
    effects[#effects + 1] = {type = "unlock-recipe", recipe = "ei-orbital-coordinator"}
    effects[#effects + 1] = {type = "unlock-recipe", recipe = "ei-orbital-dispatch-uplink"}
    data.raw.technology["rocket-silo"].effects = effects
end
