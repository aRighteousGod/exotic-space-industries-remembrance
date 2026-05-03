local ei_data = require("lib/data")
local ei_lib = require("lib/lib")
local severance_array_config = require("lib/severance-array-config")
local util = require("__core__/lualib/util")

--====================================================================================================
--SEVERANCE ARRAY
--====================================================================================================

local NAME = "ei-severance-array"
local BEAM_NAME = NAME.."-beam"
local IMPACT_BEAM_NAME = NAME.."-impact-beam"
local TRIGGER_BEAM_NAME = NAME.."-trigger-beam"
local FIRE_STICKER_NAME = NAME.."-fire-sticker"
local HIT_FIRE_NAME = NAME.."-hit-fire"
local SCORCHMARK_NAME = NAME.."-scorchmark"
local SHOT_EFFECT_ID = NAME.."-shot"
local VISUAL_CONFIG = severance_array_config.resolve()
local RANGE = 85
local MIN_RANGE = 3
local TRIGGER_BEAM_DURATION = 1
local FIRE_STICKER_DURATION = VISUAL_CONFIG.fire_sticker_duration
local HIT_FIRE_DURATION = VISUAL_CONFIG.hit_fire_duration
local SCORCHMARK_DURATION = VISUAL_CONFIG.scorchmark_duration
local ATTACK_SOURCE_OFFSET = {0, -0.55}
local BEAM_SOURCE_OFFSET = {0, -2.6}
local VISUAL_BEAM_TINT = {r = 0.94, g = 0.24, b = 1.0, a = 1}
local VISUAL_GROUND_LIGHT_TINT = {r = 0.28, g = 0.08, b = 1.0, a = 0.72}
local IMPACT_BEAM_TINT = {r = 1.0, g = 0.10, b = 1.0, a = 1}
local IMPACT_GROUND_LIGHT_TINT = {r = 0.78, g = 0.08, b = 1.0, a = 0.95}
local TURRET_GLOW_TINT = {r = 0.74, g = 0.14, b = 1.0, a = 0.90}
local FIRE_GLOW_TINT = {r = 0.92, g = 0.18, b = 1.0, a = 0.85}
local SCORCHMARK_TINT = {r = 0.30, g = 0.05, b = 0.48, a = 0.86}
local SCORCHMARK_GLOW_TINT = {r = 0.82, g = 0.20, b = 1.0, a = 0.56}
local IMPACT_SOUND_VARIATIONS = {
    {filename = "__base__/sound/fight/electric-beam.ogg", volume = 0.24},
    {filename = "__base__/sound/fight/laser-1.ogg", volume = 0.20},
    {filename = "__base__/sound/fight/laser-2.ogg", volume = 0.19},
    {filename = "__base__/sound/fight/laser-3.ogg", volume = 0.21},
}
local START_SOUND_VARIATIONS = {
    {filename = "__base__/sound/fight/laser-1.ogg", volume = 0.28},
    {filename = "__base__/sound/fight/laser-2.ogg", volume = 0.26},
    {filename = "__base__/sound/fight/laser-3.ogg", volume = 0.30},
}
local MIDDLE_SOUND_VARIATIONS = {
    {filename = "__base__/sound/fight/electric-beam.ogg", volume = 0.12},
    {filename = "__base__/sound/fight/electric-beam.ogg", volume = 0.14},
    {filename = "__base__/sound/fight/electric-beam.ogg", volume = 0.16},
}
local END_SOUND_VARIATIONS = {
    {filename = "__base__/sound/fight/laser-1.ogg", volume = 0.16},
    {filename = "__base__/sound/fight/laser-2.ogg", volume = 0.15},
    {filename = "__base__/sound/fight/laser-3.ogg", volume = 0.17},
}

local function scale_and_tint_beam_animation(node, scale, tint)
    if not node then return end

    if node.filename or node.filenames or node.stripes or node.width or node.frame_count or node.line_length then
        node.scale = (node.scale or 1) * scale
        node.tint = tint
        if node.hr_version then
            scale_and_tint_beam_animation(node.hr_version, scale, tint)
        end
        if node.layers then
            for _, layer in pairs(node.layers) do
                scale_and_tint_beam_animation(layer, scale, tint)
            end
        end
        return
    end

    for _, child in pairs(node) do
        if type(child) == "table" then
            scale_and_tint_beam_animation(child, scale, tint)
        end
    end
end

local function tint_glow_animation(node, tint)
    if type(node) ~= "table" then return end

    if node.draw_as_glow or node.draw_as_light then
        node.tint = tint
        node.blend_mode = node.blend_mode or "additive"
    end

    for _, child in pairs(node) do
        if type(child) == "table" then
            tint_glow_animation(child, tint)
        end
    end
end

local function tint_scorchmark_patch(patch, tint)
    local sheet = patch and patch.sheet
    if not sheet then return end

    sheet.tint = tint
    sheet.apply_runtime_tint = nil
end

local function make_empty_beam_graphics_set(empty_sprite)
    local function empty()
        return table.deepcopy(empty_sprite)
    end

    return {
        beam = {
            head = empty(),
            tail = empty(),
            body = {empty()},
        },
        ground = {
            head = empty(),
            tail = empty(),
            body = empty(),
        },
    }
end

local function make_sound_variations(variations, max_count, audible_distance_modifier)
    local sound = {
        category = "weapon",
        variations = table.deepcopy(variations),
        audible_distance_modifier = audible_distance_modifier,
        allow_random_repeat = false,
    }

    if max_count then
        sound.aggregation = {
            max_count = max_count,
            remove = true,
            count_already_playing = true,
        }
    end

    return sound
end

local function make_beam_working_sound(variations, max_count, audible_distance_modifier)
    local working_sound = {
        sound = make_sound_variations(variations, max_count, audible_distance_modifier),
    }

    if max_count then
        working_sound.max_sounds_per_prototype = max_count
    end

    return working_sound
end

local function make_cyclic_laser_sound()
    return {
        begin_sound = make_sound_variations(START_SOUND_VARIATIONS, VISUAL_CONFIG.start_sound_cap, 0.55),
        middle_sound = make_sound_variations(MIDDLE_SOUND_VARIATIONS, VISUAL_CONFIG.middle_sound_cap, 0.48),
        end_sound = make_sound_variations(END_SOUND_VARIATIONS, VISUAL_CONFIG.end_sound_cap, 0.45),
    }
end

local severance_icons = ei_lib.make_icons(
    "__space-age__/graphics/icons/tesla-turret.png",
    64,
    ei_graphics_3_path.."graphics/items/high-energy-crystal.png",
    64,
    0.38,
    {9, 8},
    {r = 0.72, g = 0.24, b = 1.0, a = 0.95}
)

local function copy_turret_visuals(target, source)
    if not target or not source then return end

    local fields = {
        "circuit_connector",
        "circuit_wire_max_distance",
        "close_sound",
        "corpse",
        "dying_explosion",
        "ending_attack_animation",
        "ending_attack_speed",
        "energy_glow_animation",
        "folded_animation",
        "folding_animation",
        "folding_sound",
        "glow_light_intensity",
        "graphics_set",
        "open_sound",
        "prepared_animation",
        "preparing_animation",
        "preparing_sound",
        "resource_indicator_animation",
        "rotating_sound",
        "turret_base_has_direction",
        "water_reflection",
        "working_sound",
    }

    for _, field in pairs(fields) do
        if source[field] ~= nil then
            target[field] = table.deepcopy(source[field])
        end
    end
end

local function selection_width(entity)
    if not entity or not entity.selection_box then return 4 end

    return math.abs((entity.selection_box[2][1] or 2) - (entity.selection_box[1][1] or -2))
end

local severance_beam = table.deepcopy(data.raw.beam["laser-beam"])
severance_beam.name = BEAM_NAME
severance_beam.width = VISUAL_CONFIG.visual_beam_width
severance_beam.light = {
    intensity = VISUAL_CONFIG.visual_beam_light_intensity,
    size = VISUAL_CONFIG.visual_beam_light_size,
    minimum_darkness = 0,
    color = VISUAL_GROUND_LIGHT_TINT,
}
severance_beam.hidden = true
severance_beam.hidden_in_factoriopedia = true
severance_beam.damage_interval = 60
severance_beam.random_target_offset = false
severance_beam.target_offset = {0, 0}
severance_beam.action = nil
severance_beam.working_sound = nil
scale_and_tint_beam_animation(severance_beam.head, 3, VISUAL_BEAM_TINT)
scale_and_tint_beam_animation(severance_beam.tail, 3, VISUAL_BEAM_TINT)
scale_and_tint_beam_animation(severance_beam.body, 3, VISUAL_BEAM_TINT)
if severance_beam.graphics_set then
    scale_and_tint_beam_animation(severance_beam.graphics_set.beam, 2.6, VISUAL_BEAM_TINT)
    scale_and_tint_beam_animation(severance_beam.graphics_set.ground, 1.6, VISUAL_GROUND_LIGHT_TINT)
    tint_glow_animation(severance_beam.graphics_set.beam, TURRET_GLOW_TINT)
    tint_glow_animation(severance_beam.graphics_set.ground, VISUAL_GROUND_LIGHT_TINT)
    scale_and_tint_beam_animation(severance_beam.graphics_set.start, 6, VISUAL_BEAM_TINT)
    scale_and_tint_beam_animation(severance_beam.graphics_set.ending, 6, VISUAL_BEAM_TINT)
    scale_and_tint_beam_animation(severance_beam.graphics_set.head, 6, VISUAL_BEAM_TINT)
    scale_and_tint_beam_animation(severance_beam.graphics_set.tail, 6, VISUAL_BEAM_TINT)
    scale_and_tint_beam_animation(severance_beam.graphics_set.body, 6, VISUAL_BEAM_TINT)
end

local severance_impact_beam = table.deepcopy(severance_beam)
severance_impact_beam.name = IMPACT_BEAM_NAME
severance_impact_beam.width = VISUAL_CONFIG.impact_beam_width
severance_impact_beam.random_target_offset = false
severance_impact_beam.target_offset = {0, 0}
severance_impact_beam.light = {
    intensity = VISUAL_CONFIG.impact_beam_light_intensity,
    size = VISUAL_CONFIG.impact_beam_light_size,
    minimum_darkness = 0,
    color = IMPACT_GROUND_LIGHT_TINT,
}
scale_and_tint_beam_animation(severance_impact_beam.head, 1.15, IMPACT_BEAM_TINT)
scale_and_tint_beam_animation(severance_impact_beam.tail, 1.15, IMPACT_BEAM_TINT)
scale_and_tint_beam_animation(severance_impact_beam.body, 1.15, IMPACT_BEAM_TINT)
severance_impact_beam.working_sound = make_beam_working_sound(IMPACT_SOUND_VARIATIONS, VISUAL_CONFIG.impact_sound_cap, 0.50)
if severance_impact_beam.graphics_set then
    scale_and_tint_beam_animation(severance_impact_beam.graphics_set.beam, 1.12, IMPACT_BEAM_TINT)
    scale_and_tint_beam_animation(severance_impact_beam.graphics_set.ground, 1.18, IMPACT_GROUND_LIGHT_TINT)
    tint_glow_animation(severance_impact_beam.graphics_set.beam, IMPACT_BEAM_TINT)
    tint_glow_animation(severance_impact_beam.graphics_set.ground, IMPACT_GROUND_LIGHT_TINT)
end

local severance_trigger_beam = table.deepcopy(data.raw.beam["laser-beam"])
severance_trigger_beam.name = TRIGGER_BEAM_NAME
severance_trigger_beam.width = 0.01
severance_trigger_beam.light = nil
severance_trigger_beam.hidden = true
severance_trigger_beam.hidden_in_factoriopedia = true
severance_trigger_beam.damage_interval = 1
severance_trigger_beam.random_target_offset = false
severance_trigger_beam.target_offset = {0, 0}
severance_trigger_beam.action_triggered_automatically = false

local empty_beam_sprite = util.empty_sprite()
severance_trigger_beam.graphics_set = make_empty_beam_graphics_set(empty_beam_sprite)
severance_trigger_beam.head = table.deepcopy(empty_beam_sprite)
severance_trigger_beam.tail = table.deepcopy(empty_beam_sprite)
severance_trigger_beam.body = {table.deepcopy(empty_beam_sprite)}
severance_trigger_beam.working_sound = nil
severance_trigger_beam.action = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "script",
                effect_id = SHOT_EFFECT_ID,
            },
        },
    },
}

local severance_fire_sticker = table.deepcopy(data.raw.sticker["fire-sticker"])
severance_fire_sticker.name = FIRE_STICKER_NAME
severance_fire_sticker.hidden = true
severance_fire_sticker.flags = {"not-on-map"}
severance_fire_sticker.duration_in_ticks = FIRE_STICKER_DURATION
severance_fire_sticker.damage_interval = FIRE_STICKER_DURATION
severance_fire_sticker.target_movement_modifier = 0.95
severance_fire_sticker.damage_per_tick = {amount = 1.25, type = "fire"}
severance_fire_sticker.spread_fire_entity = nil
severance_fire_sticker.fire_spread_cooldown = nil
severance_fire_sticker.fire_spread_radius = nil
if severance_fire_sticker.animation then
    severance_fire_sticker.animation = table.deepcopy(severance_fire_sticker.animation)
    severance_fire_sticker.animation.tint = {r = 0.92, g = 0.18, b = 1.0, a = 0.36}
    severance_fire_sticker.animation.scale = 0.32
end

local severance_hit_fire = table.deepcopy(data.raw.fire["fire-flame"])
severance_hit_fire.name = HIT_FIRE_NAME
severance_hit_fire.hidden = true
severance_hit_fire.hidden_in_factoriopedia = true
severance_hit_fire.flags = {"placeable-off-grid", "not-on-map"}
severance_hit_fire.damage_per_tick = {amount = 0.3, type = "fire"}
severance_hit_fire.maximum_damage_multiplier = 1
severance_hit_fire.damage_multiplier_increase_per_added_fuel = 0
severance_hit_fire.damage_multiplier_decrease_per_tick = 0
severance_hit_fire.spawn_entity = nil
severance_hit_fire.maximum_spread_count = 0
severance_hit_fire.spread_delay = 60 * 60
severance_hit_fire.spread_delay_deviation = 0
severance_hit_fire.initial_lifetime = HIT_FIRE_DURATION
severance_hit_fire.lifetime_increase_by = 0
severance_hit_fire.lifetime_increase_cooldown = 1
severance_hit_fire.maximum_lifetime = HIT_FIRE_DURATION
severance_hit_fire.delay_between_initial_flames = 1
severance_hit_fire.initial_flame_count = 1
severance_hit_fire.fade_out_duration = math.min(15, HIT_FIRE_DURATION)
severance_hit_fire.burnt_patch_lifetime = 0
severance_hit_fire.emissions_per_second = nil
severance_hit_fire.tree_dying_factor = nil
severance_hit_fire.light = {
    intensity = VISUAL_CONFIG.hit_fire_light_intensity,
    size = VISUAL_CONFIG.hit_fire_light_size,
    color = FIRE_GLOW_TINT,
}
scale_and_tint_beam_animation(severance_hit_fire.pictures, 1, {r = 0.92, g = 0.18, b = 1.0, a = 0.64})

local severance_scorchmark = table.deepcopy(data.raw.corpse["small-scorchmark-tintable"] or data.raw.corpse["small-scorchmark"])
severance_scorchmark.name = SCORCHMARK_NAME
severance_scorchmark.hidden_in_factoriopedia = true
severance_scorchmark.time_before_removed = SCORCHMARK_DURATION
severance_scorchmark.selectable_in_game = false
tint_scorchmark_patch(severance_scorchmark.ground_patch, SCORCHMARK_TINT)
tint_scorchmark_patch(severance_scorchmark.ground_patch_higher, SCORCHMARK_GLOW_TINT)

local tesla_visual_source = data.raw["electric-turret"]["tesla-turret"]
    or data.raw["electric-turret"]["tl-basic-tesla-coil"]
    or data.raw["electric-turret"]["tl-advanced-tesla-coil"]
if tesla_visual_source then
    tesla_visual_source = table.deepcopy(tesla_visual_source)
    ei_lib.entity_icon_scaler(tesla_visual_source, 4 / selection_width(tesla_visual_source))
end

local severance_turret = table.deepcopy(data.raw["electric-turret"]["laser-turret"])
local inherited_attack_parameters = tesla_visual_source and tesla_visual_source.attack_parameters
severance_turret.name = NAME
severance_turret.localised_name = {"entity-name."..NAME}
severance_turret.localised_description = {"entity-description."..NAME}
severance_turret.icon = nil
severance_turret.icon_size = nil
severance_turret.icons = severance_icons
copy_turret_visuals(severance_turret, tesla_visual_source)
severance_turret.flags = {"placeable-player", "placeable-enemy", "player-creation", "get-by-unit-number"}
severance_turret.minable = {
    mining_time = 0.75,
    result = NAME,
}
severance_turret.max_health = 2000
severance_turret.heating_energy = "100kW"
severance_turret.collision_box = {{-1.8, -1.8}, {1.8, 1.8}}
severance_turret.selection_box = {{-2, -2}, {2, 2}}
severance_turret.rotation_speed = math.max(tesla_visual_source and tesla_visual_source.rotation_speed or 0.005, 0.08)
severance_turret.preparing_speed = tesla_visual_source and tesla_visual_source.preparing_speed or 0.1
severance_turret.folding_speed = tesla_visual_source and tesla_visual_source.folding_speed or 0.1
severance_turret.attacking_speed = tesla_visual_source and tesla_visual_source.attacking_speed or nil
severance_turret.ending_attack_speed = tesla_visual_source and tesla_visual_source.ending_attack_speed or 0.03225806451612903
severance_turret.start_attacking_only_when_can_shoot = tesla_visual_source and tesla_visual_source.start_attacking_only_when_can_shoot or true
severance_turret.prepare_range = RANGE
severance_turret.call_for_help_radius = 60
severance_turret.energy_source = {
    type = "electric",
    buffer_capacity = "700MJ",
    input_flow_limit = "400MW",
    drain = "20MW",
    usage_priority = "primary-input",
}

severance_turret.attack_parameters = table.deepcopy(data.raw["electric-turret"]["laser-turret"].attack_parameters)
severance_turret.attack_parameters.type = "beam"
severance_turret.attack_parameters.ammo_category = "laser"
severance_turret.attack_parameters.cooldown = 1
severance_turret.attack_parameters.cooldown_deviation = 0
severance_turret.attack_parameters.range = RANGE
severance_turret.attack_parameters.min_range = MIN_RANGE
severance_turret.attack_parameters.range_mode = inherited_attack_parameters and inherited_attack_parameters.range_mode or "center-to-bounding-box"
severance_turret.attack_parameters.source_direction_count = inherited_attack_parameters and inherited_attack_parameters.source_direction_count or 64
severance_turret.attack_parameters.source_offset = table.deepcopy(
    inherited_attack_parameters and inherited_attack_parameters.source_offset or ATTACK_SOURCE_OFFSET
)
severance_turret.attack_parameters.damage_modifier = 1
severance_turret.attack_parameters.fire_penalty = 0
severance_turret.attack_parameters.health_penalty = nil
severance_turret.attack_parameters.rotate_penalty = 40
severance_turret.attack_parameters.cyclic_sound = make_cyclic_laser_sound()
severance_turret.attack_parameters.ammo_type = {
    energy_consumption = "100MJ",
    action = {
        type = "direct",
        action_delivery = {
            type = "beam",
            beam = TRIGGER_BEAM_NAME,
            max_length = RANGE,
            duration = TRIGGER_BEAM_DURATION,
            source_offset = BEAM_SOURCE_OFFSET,
            add_to_shooter = true,
        },
    },
}

if severance_turret.energy_glow_animation then
    tint_glow_animation(severance_turret.energy_glow_animation, TURRET_GLOW_TINT)
end
if severance_turret.graphics_set then
    tint_glow_animation(severance_turret.graphics_set, TURRET_GLOW_TINT)
end
severance_turret.glow_light_intensity = 0.85
severance_turret.water_reflection = nil

data:extend({
    severance_fire_sticker,
    severance_hit_fire,
    severance_scorchmark,
    {
        name = NAME,
        type = "item",
        icons = severance_icons,
        subgroup = "defensive-structure",
        order = "c-b",
        place_result = NAME,
        stack_size = 10,
    },
    {
        name = NAME,
        type = "recipe",
        category = "crafting-with-fluid",
        additional_categories = {"electronics-with-fluid"},
        energy_required = 20,
        ingredients = {
            {type = "fluid", name = "electrolyte", amount = 1200},
            {type = "item", name = "laser-turret", amount = 8},
            {type = "item", name = "superconductor", amount = 200},
            {type = "item", name = "holmium-plate", amount = 200},
            {type = "item", name = "quantum-processor", amount = 80},
            {type = "item", name = "ei-high-energy-crystal", amount = 160},
            {type = "item", name = "ei-superior-data", amount = 150},
            {type = "item", name = "ei-induction-matrix-core", amount = 1},
            {type = "item", name = "ei-induction-matrix-superior-coil", amount = 12},
            {type = "item", name = "ei-induction-matrix-superior-converter", amount = 12},
        },
        results = {{type = "item", name = NAME, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = NAME,
        icons = severance_icons,
    },
    {
        name = NAME,
        type = "technology",
        icons = severance_icons,
        prerequisites = {"ei-accelerator", "laser-weapons-damage-6"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = NAME,
            },
        },
        unit = {
            count = 250,
            ingredients = ei_data.science["quantum-age"],
            time = 30,
        },
        age = "quantum-age",
    },
    severance_turret,
    severance_beam,
    severance_impact_beam,
    severance_trigger_beam,
})
