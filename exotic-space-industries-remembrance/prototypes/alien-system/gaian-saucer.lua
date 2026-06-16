local ei_data = require("lib/data")

--====================================================================================================
--GAIAN SAUCER
--====================================================================================================

local saucer_name = "ei-gaian-saucer"
local leg_name = saucer_name.."-leg"
local grid_name = saucer_name.."-equipment-grid"
local main_graphics_entity_path = ei_graphics_entity_4_path
local main_graphics_item_path = ei_graphics_item_4_path
local main_graphics_tech_path = ei_graphics_tech_4_path
local icon_path = main_graphics_item_path.."gaian-saucer.png"
local tech_icon_path = main_graphics_tech_path.."gaian-saucer.png"
local wake_graphics_path = main_graphics_entity_path.."gaian-saucer/wake/"
local saucer_hum_sound_path = ei_sounds_4_path.."gaian-saucer-hum.ogg"
local SAUCER_FRAME_SIZE = 256
local SAUCER_SCALE = 0.69
local WAKE_FRAME_SIZE = 768
local WAKE_FRAME_COUNT = 64
local SAUCER_TARGET_SPEED_MULTIPLIER = 2.0
local SAUCER_HOVER_ANCHOR_RESPONSIVENESS = 1
local SAUCER_HOVER_STRIDE_MULTIPLIER = 1 + ((SAUCER_TARGET_SPEED_MULTIPLIER - 1) * 0.55)
local SAUCER_HOVER_BASE_SELECTION_DISTANCE = 2.4
local SAUCER_HOVER_MOVEMENT_SELECTION_DISTANCE = 2.8
local SAUCER_FRICTION_FORCE = 0.7 / SAUCER_TARGET_SPEED_MULTIPLIER
local SAUCER_BRAKING_FORCE = 1 + ((SAUCER_TARGET_SPEED_MULTIPLIER - 1) * 0.35)
local SAUCER_DIRECTION_COUNT = 64
local TAU = math.pi * 2
local CRYSTAL_HEADLIGHT_COLOR = {r = 0.12, g = 0.95, b = 0.88}
local CRYSTAL_HEADLIGHT_BEAM_FORWARD_OFFSET = 12
local CRYSTAL_HEADLIGHT_SOURCE_OFFSETS = {
    {x = 0, y = -50},
    {x = 70, y = -1},
    {x = 0, y = 45},
    {x = -70, y = -1},
    {x = 0, y = 0},
}

local base_spider = data.raw["spider-vehicle"] and data.raw["spider-vehicle"]["spidertron"]
local base_leg = data.raw["spider-leg"] and data.raw["spider-leg"]["spidertron-leg-1"]

if not (base_spider and base_leg) then
    return
end

local function saucer_sprite(path, options)
    options = options or {}

    return {
        filename = path,
        priority = "high",
        size = {SAUCER_FRAME_SIZE, SAUCER_FRAME_SIZE},
        width = SAUCER_FRAME_SIZE,
        height = SAUCER_FRAME_SIZE,
        line_length = 8,
        lines_per_file = 8,
        direction_count = SAUCER_DIRECTION_COUNT,
        frame_count = 1,
        scale = options.scale or SAUCER_SCALE,
        shift = options.shift or {0, 0},
        draw_as_shadow = options.draw_as_shadow,
        draw_as_glow = options.draw_as_glow,
    }
end

local function wake_animation_layer(filename, options)
    options = options or {}

    return {
        filename = wake_graphics_path..filename,
        priority = "high",
        width = WAKE_FRAME_SIZE,
        height = WAKE_FRAME_SIZE,
        line_length = 8,
        lines_per_file = 8,
        frame_count = WAKE_FRAME_COUNT,
        animation_speed = 0.45,
        draw_as_glow = options.draw_as_glow,
        blend_mode = options.blend_mode,
    }
end

local function map_icon()
    return {
        filename = icon_path,
        flags = {"icon"},
        size = {64, 64},
        scale = 0.5,
    }
end

local function crystal_headlight_beam_origin(offset)
    local distance = math.sqrt(offset.x * offset.x + offset.y * offset.y)
    if distance == 0 then
        return offset
    end

    return {
        x = offset.x + (offset.x / distance * CRYSTAL_HEADLIGHT_BEAM_FORWARD_OFFSET),
        y = offset.y + (offset.y / distance * CRYSTAL_HEADLIGHT_BEAM_FORWARD_OFFSET),
    }
end

local function rotate_crystal_offset(offset, direction_index)
    local angle = direction_index / SAUCER_DIRECTION_COUNT * TAU
    local cos_angle = math.cos(angle)
    local sin_angle = math.sin(angle)

    return util.by_pixel(
        (offset.x * cos_angle - offset.y * sin_angle) * SAUCER_SCALE,
        (offset.x * sin_angle + offset.y * cos_angle) * SAUCER_SCALE
    )
end

local function crystal_headlight_positions()
    local positions = {}

    for crystal_index, offset in ipairs(CRYSTAL_HEADLIGHT_SOURCE_OFFSETS) do
        local crystal_positions = {}
        for direction_index = 0, SAUCER_DIRECTION_COUNT - 1 do
            crystal_positions[direction_index + 1] = rotate_crystal_offset(offset, direction_index)
        end
        positions[crystal_index] = crystal_positions
    end

    return positions
end

local function crystal_headlight_beam_shift(offset)
    offset = crystal_headlight_beam_origin(offset)
    return util.by_pixel(offset.x * SAUCER_SCALE, offset.y * SAUCER_SCALE)
end

local function crystal_headlight_beam(source_orientation_offset, source_offset)
    return {
        type = "oriented",
        minimum_darkness = 0.25,
        picture = {
            filename = "__core__/graphics/light-cone.png",
            priority = "extra-high",
            flags = {"light"},
            scale = 0.85,
            width = 200,
            height = 200,
        },
        source_orientation_offset = source_orientation_offset,
        shift = crystal_headlight_beam_shift(source_offset),
        size = 0.95,
        intensity = 0.26,
        color = table.deepcopy(CRYSTAL_HEADLIGHT_COLOR),
    }
end

local saucer_leg = table.deepcopy(base_leg)
saucer_leg.name = leg_name
saucer_leg.localised_name = {"entity-name."..leg_name}
saucer_leg.icon = icon_path
saucer_leg.icon_size = 64
saucer_leg.hidden = true
saucer_leg.flags = {"not-on-map", "placeable-off-grid"}
saucer_leg.collision_mask = {layers = {}}
saucer_leg.collision_box = nil
saucer_leg.selection_box = {{0, 0}, {0, 0}}
saucer_leg.selectable_in_game = false
saucer_leg.alert_when_damaged = false
saucer_leg.graphics_set = nil
saucer_leg.working_sound = nil
saucer_leg.walking_sound_volume_modifier = 0
saucer_leg.walking_sound_speed_modifier = 0
saucer_leg.target_position_randomisation_distance = 0
saucer_leg.minimal_step_size = 0
saucer_leg.initial_movement_speed = SAUCER_HOVER_ANCHOR_RESPONSIVENESS
saucer_leg.movement_acceleration = SAUCER_HOVER_ANCHOR_RESPONSIVENESS
saucer_leg.base_position_selection_distance = SAUCER_HOVER_BASE_SELECTION_DISTANCE
saucer_leg.movement_based_position_selection_distance = SAUCER_HOVER_MOVEMENT_SELECTION_DISTANCE
saucer_leg.knee_height = 2.5
saucer_leg.knee_distance_factor = 0.4

local saucer = table.deepcopy(base_spider)
saucer.name = saucer_name
saucer.localised_name = {"entity-name."..saucer_name}
saucer.localised_description = {"entity-description."..saucer_name}
saucer.icon = icon_path
saucer.icon_size = 64
saucer.minable = {
    mining_time = 1,
    result = saucer_name,
}
saucer.flags = {"placeable-neutral", "player-creation", "placeable-off-grid", "no-automated-item-removal", "no-automated-item-insertion"}
saucer.max_health = 1800
saucer.map_color = ei_data.colors.alien
saucer.corpse = "big-remnants"
saucer.dying_explosion = "medium-explosion"
saucer.collision_mask = {layers = {}}
saucer.collision_box = {{-1.45, -1.45}, {1.45, 1.45}}
saucer.selection_box = {{-1.8, -1.8}, {1.8, 1.8}}
saucer.selection_priority = 60
saucer.terrain_friction_modifier = 0
saucer.friction_force = SAUCER_FRICTION_FORCE
saucer.braking_force = SAUCER_BRAKING_FORCE
saucer.create_ghost_on_death = false
saucer.hide_resistances = false
saucer.resistances = {
    {type = "acid", percent = 80, decrease=10},
    {type = "electric", percent = 80, decrease=10},
    {type = "explosion", percent = 85, decrease=40},
    {type = "fire", percent = 70, decrease=30},
    {type = "cold", percent = 70, decrease=30},
    {type = "impact", percent = 90, decrease=100},
    {type = "laser", percent = 80, decrease=10},
    {type = "physical", percent = 70, decrease=30},
}
saucer.guns = {}
saucer.automatic_weapon_cycling = false
saucer.inventory_size = 80
saucer.trash_inventory_size = 20
saucer.equipment_grid = grid_name
saucer.height = 1.8
saucer.alert_icon_shift = {0, -0.6}
saucer.torso_rotation_speed = 0.01
saucer.torso_bob_speed = 0.2
saucer.energy_source = {
    type = "void",
}
saucer.movement_energy_consumption = "750kW"
saucer.working_sound = {
    sound = {
        filename = saucer_hum_sound_path,
        volume = 0.40,
        audible_distance_modifier = 0.58,
    },
    idle_sound = {
        filename = saucer_hum_sound_path,
        volume = 0.18,
        audible_distance_modifier = 0.42,
    },
    match_speed_to_activity = true,
    activity_to_speed_modifiers = {
        multiplier = 0.85,
        minimum = 0.85,
        maximum = 1.65,
        offset = 0.85,
    },
    match_volume_to_activity = true,
    activity_to_volume_modifiers = {
        multiplier = 1.15,
        minimum = 0.28,
        maximum = 1.18,
        offset = 0.08,
    },
    use_doppler_shift = false,
    fade_in_ticks = 10,
    fade_out_ticks = 36,
    max_sounds_per_prototype = 5,
}
saucer.minimap_representation = map_icon()
saucer.selected_minimap_representation = map_icon()
saucer.graphics_set = {
    render_layer = "air-object",
    base_render_layer = "air-object",
    animation = {
        layers = {
            saucer_sprite(main_graphics_entity_path.."gaian-saucer/gaian-saucer_dark_compact.png"),
            saucer_sprite(main_graphics_entity_path.."gaian-saucer/gaian-saucer_dark_compact_glow.png", {
                draw_as_glow = true,
            }),
        },
    },
    shadow_animation = saucer_sprite(main_graphics_entity_path.."gaian-saucer/gaian-saucer_dark_compact_shadow.png", {
        draw_as_shadow = true,
    }),
    light = {
        crystal_headlight_beam(0.00, CRYSTAL_HEADLIGHT_SOURCE_OFFSETS[1]),
        {
            type = "basic",
            minimum_darkness = 0.25,
            intensity = 0.5,
            size = 18,
            color = {r = 0.25, g = 0.95, b = 0.55},
        },
    },
    eye_light = {
        type = "basic",
        minimum_darkness = 0.18,
        intensity = 0.82,
        size = 2.2,
        color = table.deepcopy(CRYSTAL_HEADLIGHT_COLOR),
    },
    light_positions = crystal_headlight_positions(),
}

-- Exotic skimmer profile: the hidden hover anchors are already much more
-- responsive than vanilla Spidertron legs, so traversal speed comes from longer
-- anchor reach plus lower vehicle friction instead of runtime movement logic.
saucer.spider_engine = {
    legs = {
        {
            leg = leg_name,
            mount_position = {0.65, -0.55},
            ground_position = {1.75 * SAUCER_HOVER_STRIDE_MULTIPLIER, -1.55 * SAUCER_HOVER_STRIDE_MULTIPLIER},
            walking_group = 1,
        },
        {
            leg = leg_name,
            mount_position = {0.65, 0.45},
            ground_position = {1.75 * SAUCER_HOVER_STRIDE_MULTIPLIER, 1.45 * SAUCER_HOVER_STRIDE_MULTIPLIER},
            walking_group = 2,
        },
        {
            leg = leg_name,
            mount_position = {-0.65, -0.55},
            ground_position = {-1.75 * SAUCER_HOVER_STRIDE_MULTIPLIER, -1.55 * SAUCER_HOVER_STRIDE_MULTIPLIER},
            walking_group = 2,
        },
        {
            leg = leg_name,
            mount_position = {-0.65, 0.45},
            ground_position = {-1.75 * SAUCER_HOVER_STRIDE_MULTIPLIER, 1.45 * SAUCER_HOVER_STRIDE_MULTIPLIER},
            walking_group = 1,
        },
    },
}

data:extend({
    {
        name = saucer_name,
        type = "item-with-entity-data",
        icon = icon_path,
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-d[ei-gaian-saucer]",
        place_result = saucer_name,
        stack_size = 1,
        weight = 200 * kg,
    },
    {
        name = saucer_name,
        type = "recipe",
        category = "crafting",
        energy_required = 60,
        surface_conditions =
        {
           {
              property = "gravity",
              min = 15.5,
              max = 15.5
            }
        },
        ingredients = {
            {type = "item", name = "spidertron", amount = 1},
            {type = "item", name = "low-density-structure", amount = 50},
            {type = "item", name = "ei-computing-unit", amount = 40},
            {type = "item", name = "ei-high-energy-crystal", amount = 80},
            {type = "item", name = "ei-alien-resin", amount = 100},
            {type = "item", name = "ei-sus-plating", amount = 100},
            {type = "item", name = "ei-magnet", amount = 150},
        },
        results = {{type = "item", name = saucer_name, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = saucer_name,
    },
    {
        name = saucer_name,
        type = "technology",
        icon = tech_icon_path,
        icon_size = 256,
        prerequisites = {"ei-neodymium-magnet", "spidertron", "ei-computing-unit"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = saucer_name,
            },
        },
        unit = {
            count = 300,
            ingredients = ei_data.science["alien-computer-age"],
            time = 30,
        },
        age = "alien-computer-age",
    },
    {
        name = grid_name,
        type = "equipment-grid",
        equipment_categories = {"armor"},
        width = 12,
        height = 8,
    },
    saucer_leg,
    saucer,
    {
        name = "ei-gaian-saucer-wake",
        type = "animation",
        layers = {
            wake_animation_layer("gaian-saucer_wake.png"),
            wake_animation_layer("gaian-saucer_wake_glow.png", {
                draw_as_glow = true,
                blend_mode = "additive-soft",
            }),
        },
    },
})
