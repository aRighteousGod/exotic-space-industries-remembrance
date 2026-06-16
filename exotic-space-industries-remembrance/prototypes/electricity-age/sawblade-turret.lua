local util = require("__core__/lualib/util")
local sounds = require("__base__.prototypes.entity.sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local ei_data = require("lib/data")

--====================================================================================================
-- OATHBREAKER SAW
--====================================================================================================

local NAME = "ei-sawblade-turret"
local TRIGGER_BEAM_NAME = NAME.."-trigger-beam"
local IMPACT_NAME = NAME.."-impact"
local SHOT_EFFECT_ID = NAME.."-shot"
local STATIC_BLADE_ANIMATION_NAME = NAME.."-blade-static"
local SPIN_ANIMATION_NAME = NAME.."-spin"
local GRAPHICS_PATH = ei_graphics_entity_4_path.."sawblade-turret/"
local SOUND_PATH = ei_sounds_4_path
local ICON_PATH = ei_graphics_item_4_path.."sawblade-turret.png"
local TECH_ICON_UNDERLAY_PATH = ei_graphics_tech_4_path.."sawblade-turret-underlay.png"
local TECH_ICON_ENTITY_PATH = ei_graphics_tech_4_path.."sawblade-turret-entity.png"
local FRAME_SIZE = 384
local FRAME_SCALE = 0.5
local FRAME_SHIFT = util.by_pixel(0, 24)
local RANGE = 3

local function make_sawblade_animation(filename, shadow_filename, frame_count, line_length, animation_speed)
    return {
        layers = {
            {
                filename = GRAPHICS_PATH..filename,
                priority = "high",
                width = FRAME_SIZE,
                height = FRAME_SIZE,
                direction_count = 1,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = animation_speed,
                shift = FRAME_SHIFT,
                scale = FRAME_SCALE,
            },
            {
                filename = GRAPHICS_PATH..shadow_filename,
                priority = "high",
                width = FRAME_SIZE,
                height = FRAME_SIZE,
                direction_count = 1,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = animation_speed,
                shift = FRAME_SHIFT,
                scale = FRAME_SCALE,
                draw_as_shadow = true,
            },
        },
    }
end

local function make_static_animation()
    return make_sawblade_animation("sawblade-turret.png", "sawblade-turret-shadow.png", 1, 1, 1.0)
end

local function make_spin_render_animation()
    return {
        name = SPIN_ANIMATION_NAME,
        type = "animation",
        filename = GRAPHICS_PATH.."sawblade-turret-attack.png",
        priority = "high",
        width = FRAME_SIZE,
        height = FRAME_SIZE,
        frame_count = 64,
        line_length = 8,
        animation_speed = 1.0,
        shift = FRAME_SHIFT,
        scale = FRAME_SCALE,
    }
end

local function make_static_blade_render_animation()
    return {
        name = STATIC_BLADE_ANIMATION_NAME,
        type = "animation",
        filename = GRAPHICS_PATH.."sawblade-turret-blade.png",
        priority = "high",
        width = FRAME_SIZE,
        height = FRAME_SIZE,
        frame_count = 1,
        line_length = 1,
        animation_speed = 1.0,
        shift = FRAME_SHIFT,
        scale = FRAME_SCALE,
    }
end

local function make_attack_sound_prototype(index)
    return {
        name = NAME.."-attack-sound-"..index,
        type = "sound",
        category = "weapon",
        filename = SOUND_PATH.."sawblade-"..index..".ogg",
        volume = 0.28,
        audible_distance_modifier = 0.28,
        advanced_volume_control = {
            attenuation = "exponential",
        },
        aggregation = {max_count = 8, remove = true, count_already_playing = true},
    }
end

local function make_attack_sound_prototypes()
    local prototypes = {}

    for index = 1, 5 do
        prototypes[#prototypes + 1] = make_attack_sound_prototype(index)
    end

    return prototypes
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

local function make_trigger_beam()
    local beam = table.deepcopy(data.raw.beam["laser-beam"])
    local empty_sprite = util.empty_sprite()

    beam.name = TRIGGER_BEAM_NAME
    beam.width = 0.01
    beam.light = nil
    beam.hidden = true
    beam.hidden_in_factoriopedia = true
    beam.damage_interval = 1
    beam.random_target_offset = false
    beam.target_offset = {0, 0}
    beam.action_triggered_automatically = false
    beam.graphics_set = make_empty_beam_graphics_set(empty_sprite)
    beam.head = table.deepcopy(empty_sprite)
    beam.tail = table.deepcopy(empty_sprite)
    beam.body = {table.deepcopy(empty_sprite)}
    beam.working_sound = nil
    beam.action = {
        type = "direct",
        action_delivery = {
            type = "instant",
            target_effects = {
                {
                    type = "damage",
                    damage = {
                        amount = 60,
                        type = "physical",
                    },
                },
                {
                    type = "create-entity",
                    entity_name = IMPACT_NAME,
                    trigger_created_entity = true,
                },
                {
                    type = "script",
                    effect_id = SHOT_EFFECT_ID,
                },
            },
        },
    }

    return beam
end

local function make_impact_explosion()
    return {
        name = IMPACT_NAME,
        type = "explosion",
        flags = {"not-on-map"},
        animations = {
            {
                filename = GRAPHICS_PATH.."sawblade-turret-impact.png",
                width = 128,
                height = 128,
                frame_count = 16,
                line_length = 8,
                animation_speed = 1.0,
                scale = 0.46,
                priority = "high",
            },
        },
        light_intensity_peak_end_progress = 0.35,
        light_size_peak_start_progress = 0.05,
        light_size_peak_end_progress = 0.65,
        scale_out_duration = 8,
        scale_end = 0.65,
        scale_animation_speed = true,
        light = {
            intensity = 0.34,
            size = 3.5,
            color = {r = 1.0, g = 0.70, b = 0.32},
        },
    }
end

local sawblade_turret = table.deepcopy(data.raw["electric-turret"]["laser-turret"])
sawblade_turret.name = NAME
sawblade_turret.localised_name = {"entity-name."..NAME}
sawblade_turret.localised_description = {"entity-description."..NAME}
sawblade_turret.icon = ICON_PATH
sawblade_turret.icon_size = 64
sawblade_turret.icon_mipmaps = 4
sawblade_turret.placeable_by = {item = NAME, count = 1}
sawblade_turret.flags = {"placeable-player", "player-creation"}
sawblade_turret.minable = {mining_time = 0.75, result = NAME}
sawblade_turret.max_health = 1100
sawblade_turret.heating_energy = "75kW"
sawblade_turret.hide_resistances = false
sawblade_turret.resistances = {
    {type = "physical", percent = 55},
    {type = "fire", percent = 75},
    {type = "impact", percent = 70},
    {type = "explosion", percent = 35},
    {type = "acid", percent = 20},
}
sawblade_turret.energy_source = {
    type = "electric",
    buffer_capacity = "900kJ",
    input_flow_limit = "900kW",
    drain = "12kW",
    usage_priority = "primary-input",
}
sawblade_turret.corpse = "medium-remnants"
sawblade_turret.dying_explosion = "artillery-turret-explosion"
sawblade_turret.collision_box = {{-1.2, -1.2}, {1.2, 1.2}}
sawblade_turret.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
sawblade_turret.damaged_trigger_effect = hit_effects.entity()
sawblade_turret.rotation_speed = 0.10
sawblade_turret.preparing_speed = 1.0
sawblade_turret.prepared_speed = 1.0
sawblade_turret.prepared_speed_secondary = 1.0
sawblade_turret.folding_speed = 1.0
sawblade_turret.prepare_range = RANGE + 0.5
sawblade_turret.can_retarget_while_starting_attack = true
sawblade_turret.start_attacking_only_when_can_shoot = true
sawblade_turret.alert_when_attacking = true
sawblade_turret.open_sound = sounds.machine_open
sawblade_turret.close_sound = sounds.machine_close
sawblade_turret.vehicle_impact_sound = sounds.generic_impact
sawblade_turret.graphics_set = {}
sawblade_turret.energy_glow_animation = nil
sawblade_turret.glow_light_intensity = 0
sawblade_turret.water_reflection = nil
sawblade_turret.folded_animation = make_static_animation()
sawblade_turret.preparing_animation = make_static_animation()
sawblade_turret.prepared_animation = make_static_animation()
sawblade_turret.starting_attack_animation = nil
sawblade_turret.attacking_animation = nil
sawblade_turret.ending_attack_animation = nil
sawblade_turret.folding_animation = make_static_animation()
sawblade_turret.folded_animation_is_stateless = true
sawblade_turret.random_animation_offset = true
sawblade_turret.icon_draw_specification = {scale = 0.75}
sawblade_turret.attack_parameters = table.deepcopy(data.raw["electric-turret"]["laser-turret"].attack_parameters)
sawblade_turret.attack_parameters.type = "beam"
sawblade_turret.attack_parameters.ammo_category = NAME
sawblade_turret.attack_parameters.cooldown = 12
sawblade_turret.attack_parameters.cooldown_deviation = 0
sawblade_turret.attack_parameters.range = RANGE
sawblade_turret.attack_parameters.range_mode = "center-to-bounding-box"
sawblade_turret.attack_parameters.source_direction_count = 1
sawblade_turret.attack_parameters.source_offset = {0, -0.2}
sawblade_turret.attack_parameters.damage_modifier = 1
sawblade_turret.attack_parameters.fire_penalty = 0
sawblade_turret.attack_parameters.rotate_penalty = 0
sawblade_turret.attack_parameters.health_penalty = 0
sawblade_turret.attack_parameters.cyclic_sound = nil
sawblade_turret.attack_parameters.ammo_type = {
    energy_consumption = "90kJ",
    action = {
        type = "direct",
        action_delivery = {
            type = "beam",
            beam = TRIGGER_BEAM_NAME,
            max_length = RANGE,
            duration = 1,
            source_offset = {0, -0.2},
            add_to_shooter = true,
        },
    },
}
sawblade_turret.call_for_help_radius = 25

data:extend(make_attack_sound_prototypes())

data:extend({
    {
        name = NAME,
        type = "ammo-category",
        icon = ICON_PATH,
        icon_size = 64,
        icon_mipmaps = 4,
    },
    make_trigger_beam(),
    make_impact_explosion(),
    make_static_blade_render_animation(),
    make_spin_render_animation(),
    {
        name = NAME,
        type = "item",
        icon = ICON_PATH,
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "defensive-structure",
        order = "b[turret]-d[oathbreaker-saw]",
        place_result = NAME,
        stack_size = 20,
    },
    sawblade_turret,
    {
        name = NAME,
        type = "recipe",
        category = "crafting",
        energy_required = 8,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 24},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
            {type = "item", name = "ei-steel-beam", amount = 4},
            {type = "item", name = "electric-engine-unit", amount = 4},
            {type = "item", name = "electronic-circuit", amount = 12},
        },
        results = {{type = "item", name = NAME, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = NAME,
    },
    {
        name = NAME,
        type = "technology",
        icons = {
            {
                icon = TECH_ICON_UNDERLAY_PATH,
                icon_size = 256,
            },
            {
                icon = TECH_ICON_ENTITY_PATH,
                icon_size = 256,
            },
        },
        icon_size = 256,
        prerequisites = {
            "military-2",
            "ei-electricity-power",
            "electric-engine",
            "steel-processing",
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = NAME,
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20,
        },
        age = "electricity-age",
    },
})

local physical_projectile_modifiers = {
    ["physical-projectile-damage-1"] = 0.1,
    ["physical-projectile-damage-2"] = 0.1,
    ["physical-projectile-damage-3"] = 0.2,
    ["physical-projectile-damage-4"] = 0.2,
    ["physical-projectile-damage-5"] = 0.2,
    ["physical-projectile-damage-6"] = 0.2,
    ["physical-projectile-damage-7"] = 0.2,
}

for technology_name, modifier in pairs(physical_projectile_modifiers) do
    local technology = data.raw.technology[technology_name]
    if technology and technology.effects then
        table.insert(technology.effects, {
            type = "turret-attack",
            turret_id = NAME,
            modifier = modifier,
        })
    end
end
