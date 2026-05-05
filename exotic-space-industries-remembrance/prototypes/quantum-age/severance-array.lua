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
local ATTACK_SOURCE_OFFSET = {0, -3.35}
local BEAM_SOURCE_OFFSET = {0, -3.35}
local TURRET_GLOW_TINT = {r = 0.74, g = 0.14, b = 1.0, a = 0.90}
local ARRAY_GRAPHICS_PATH = ei_path.."graphics/entities/severance-array/"
local ARRAY_FRAME_SIZE = 768
local ARRAY_FRAME_COUNT = 64
local ARRAY_LINE_LENGTH = 8
local ARRAY_ANIMATION_SPEED = 0.12
local ARRAY_BODY_SCALE = 0.65
local ARRAY_BODY_SHIFT = {0, -2.66}
local ARRAY_BODY_SHADOW_SHIFT = {0, 0.65}
local ARRAY_CRYSTAL_SCALE = 0.5
local ARRAY_CRYSTAL_SHIFT = {0, -1.75}
local ARRAY_CRYSTAL_GLOW_TINT = {r = 0.64, g = 0.98, b = 1.0, a = 0.52}
local ARRAY_CRYSTAL_LINK_ANIMATION_SPEED = 0.55
local ARRAY_CRYSTAL_LINK_SCALE = ARRAY_CRYSTAL_SCALE
local ARRAY_CRYSTAL_LINK_SHIFT = ARRAY_CRYSTAL_SHIFT
local ARRAY_CRYSTAL_LINK_GRAPHICS_PATH = ARRAY_GRAPHICS_PATH.."crystal-link/"
local PRISMATIC_BEAM_GRAPHICS_PATH = ARRAY_GRAPHICS_PATH.."beam/"
local PRISMATIC_BEAM_SCALE = 0.34
local PRISMATIC_IMPACT_BEAM_SCALE = 0.42
local PRISMATIC_BEAM_LIGHT_TINT = {r = 1.0, g = 0.58, b = 0.24, a = 0.82}
local PRISMATIC_IMPACT_LIGHT_TINT = {r = 1.0, g = 0.74, b = 0.34, a = 0.95}
local AFTERBURN_GRAPHICS_PATH = ARRAY_GRAPHICS_PATH.."afterburn/"
local AFTERBURN_LIGHT_TINT = {r = 1.0, g = 0.58, b = 0.24, a = 0.90}
local AFTERBURN_FIRE_SCALE = 0.34
local AFTERBURN_FIRE_SHIFT = {0, -0.16}
local AFTERBURN_STICKER_SCALE = 0.38
local AFTERBURN_STICKER_SHIFT = {0, -0.10}
local AFTERBURN_SCORCHMARK_SCALE = 0.5
local AFTERBURN_SCORCHMARK_SHIFT = {0, 0.0625}
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

local function make_prismatic_beam_animation(filename, glow_filename, width, height, frame_count, line_length, scale)
    scale = scale or 1

    return {
        layers = {
            {
                filename = PRISMATIC_BEAM_GRAPHICS_PATH..filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = 0.55,
                scale = scale,
            },
            {
                filename = PRISMATIC_BEAM_GRAPHICS_PATH..glow_filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = 0.55,
                scale = scale,
                draw_as_glow = true,
                blend_mode = "additive-soft",
            },
        },
    }
end

local function make_prismatic_beam_graphics_set(scale, options)
    options = options or {}

    local body = make_prismatic_beam_animation(
        "ei-severance-array-beam-body.png",
        "ei-severance-array-beam-body-glow.png",
        256,
        96,
        16,
        4,
        scale
    )
    local head = make_prismatic_beam_animation(
        "ei-severance-array-beam-head.png",
        "ei-severance-array-beam-head-glow.png",
        192,
        160,
        16,
        4,
        scale
    )
    local tail = make_prismatic_beam_animation(
        "ei-severance-array-beam-tail.png",
        "ei-severance-array-beam-tail-glow.png",
        192,
        160,
        16,
        4,
        scale
    )
    local impact = options.impact_ending and make_prismatic_beam_animation(
        "ei-severance-array-impact-prism.png",
        "ei-severance-array-impact-prism-glow.png",
        256,
        256,
        24,
        6,
        scale
    ) or nil

    return {
        beam = {
            start = table.deepcopy(tail),
            ending = impact or table.deepcopy(head),
            head = head,
            tail = tail,
            body = {body},
            render_layer = "projectile",
        },
        ground = {
            head = util.empty_sprite(),
            tail = util.empty_sprite(),
            body = util.empty_sprite(),
        },
        desired_segment_length = 1,
        transparent_start_end_animations = true,
        random_end_animation_rotation = false,
        randomize_animation_per_segment = false,
    }
end

local function make_prismatic_beam(name, width, light, graphics_set, working_sound)
    local beam = table.deepcopy(data.raw.beam["laser-beam"])
    beam.name = name
    beam.width = width
    beam.light = light
    beam.hidden = true
    beam.hidden_in_factoriopedia = true
    beam.damage_interval = 60
    beam.random_target_offset = false
    beam.target_offset = {0, 0}
    beam.action = nil
    beam.working_sound = working_sound
    beam.graphics_set = graphics_set
    beam.head = nil
    beam.tail = nil
    beam.body = nil

    return beam
end

local function make_afterburn_animation(filename, glow_filename, width, height, frame_count, line_length, scale, shift, animation_speed)
    return {
        layers = {
            {
                filename = AFTERBURN_GRAPHICS_PATH..filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = animation_speed,
                scale = scale,
                shift = shift,
            },
            {
                filename = AFTERBURN_GRAPHICS_PATH..glow_filename,
                width = width,
                height = height,
                frame_count = frame_count,
                line_length = line_length,
                animation_speed = animation_speed,
                scale = scale,
                shift = shift,
                draw_as_glow = true,
                blend_mode = "additive-soft",
            },
        },
    }
end

local function make_afterburn_scorchmark_patch(filename, glow)
    local sheet = {
        filename = AFTERBURN_GRAPHICS_PATH..filename,
        width = 256,
        height = 182,
        line_length = 4,
        variation_count = 4,
        scale = AFTERBURN_SCORCHMARK_SCALE,
        shift = table.deepcopy(AFTERBURN_SCORCHMARK_SHIFT),
    }

    if glow then
        sheet.draw_as_glow = true
        sheet.blend_mode = "additive-soft"
    end

    return {sheet = sheet}
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

local function make_array_animation_layer(filename, options)
    options = options or {}
    local layer = {
        filename = (options.graphics_path or ARRAY_GRAPHICS_PATH)..filename,
        width = ARRAY_FRAME_SIZE,
        height = ARRAY_FRAME_SIZE,
        frame_count = options.frame_count or ARRAY_FRAME_COUNT,
        line_length = options.line_length or ARRAY_LINE_LENGTH,
        lines_per_file = options.lines_per_file or options.line_length or ARRAY_LINE_LENGTH,
        animation_speed = options.animation_speed or ARRAY_ANIMATION_SPEED,
        scale = options.scale or ARRAY_BODY_SCALE,
        shift = table.deepcopy(options.shift or ARRAY_BODY_SHIFT),
    }

    if options.draw_as_shadow then
        layer.draw_as_shadow = true
    end
    if options.tint then
        layer.tint = table.deepcopy(options.tint)
    end
    if options.draw_as_glow then
        layer.draw_as_glow = true
        layer.blend_mode = options.blend_mode or "additive"
    elseif options.blend_mode then
        layer.blend_mode = options.blend_mode
    end

    return layer
end

local function make_array_base_visualisation()
    return {
        {
            render_layer = "object",
            secondary_draw_order = 1,
            animation = {
                layers = {
                    make_array_animation_layer("ei-severance-array_base-shadow.png", {
                        draw_as_shadow = true,
                        scale = ARRAY_BODY_SCALE,
                        shift = ARRAY_BODY_SHADOW_SHIFT,
                    }),
                    make_array_animation_layer("ei-severance-array_shadow.png", {
                        draw_as_shadow = true,
                        scale = ARRAY_CRYSTAL_SCALE,
                        shift = ARRAY_CRYSTAL_SHIFT,
                    }),
                    make_array_animation_layer("ei-severance-array.png", {
                        scale = ARRAY_BODY_SCALE,
                        shift = ARRAY_BODY_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 2,
            animation = {
                layers = {
                    make_array_animation_layer("ei-severance-array-crystal-link.png", {
                        graphics_path = ARRAY_CRYSTAL_LINK_GRAPHICS_PATH,
                        animation_speed = ARRAY_CRYSTAL_LINK_ANIMATION_SPEED,
                        scale = ARRAY_CRYSTAL_LINK_SCALE,
                        shift = ARRAY_CRYSTAL_LINK_SHIFT,
                    }),
                    make_array_animation_layer("ei-severance-array-crystal-link-glow.png", {
                        graphics_path = ARRAY_CRYSTAL_LINK_GRAPHICS_PATH,
                        animation_speed = ARRAY_CRYSTAL_LINK_ANIMATION_SPEED,
                        draw_as_glow = true,
                        blend_mode = "additive-soft",
                        scale = ARRAY_CRYSTAL_LINK_SCALE,
                        shift = ARRAY_CRYSTAL_LINK_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 3,
            animation = {
                layers = {
                    make_array_animation_layer("ei-severance-array_crystal.png", {
                        scale = ARRAY_CRYSTAL_SCALE,
                        shift = ARRAY_CRYSTAL_SHIFT,
                    }),
                    make_array_animation_layer("ei-severance-array_crystal.png", {
                        draw_as_glow = true,
                        blend_mode = "normal",
                        tint = ARRAY_CRYSTAL_GLOW_TINT,
                        scale = ARRAY_CRYSTAL_SCALE,
                        shift = ARRAY_CRYSTAL_SHIFT,
                    }),
                },
            },
        },
    }
end

local function make_empty_turret_animation()
    local animation = util.empty_sprite()
    animation.frame_count = 1
    animation.line_length = 1
    animation.direction_count = 1
    return animation
end

local function apply_array_visuals(turret)
    if not turret then return end

    local empty_animation = make_empty_turret_animation()
    local animation_fields = {
        "folded_animation",
        "preparing_animation",
        "prepared_animation",
        "starting_attack_animation",
        "attacking_animation",
        "ending_attack_animation",
        "folding_animation",
    }

    for _, field in pairs(animation_fields) do
        turret[field] = table.deepcopy(empty_animation)
    end

    turret.graphics_set = {
        base_visualisation = make_array_base_visualisation(),
    }
    turret.energy_glow_animation = nil
    turret.resource_indicator_animation = nil
    turret.prepared_alternative_animation = nil
    turret.prepared_alternative_chance = nil
    turret.turret_base_has_direction = false
    turret.folded_animation_is_stateless = true
    turret.random_animation_offset = true
end

local SEVERANCE_ARRAY_ITEM_ICON = ei_path.."graphics/items/ei-severance-array.png"
local SEVERANCE_ARRAY_ITEM_OVERLAY_ICON = ei_path.."graphics/items/ei-severance-array-chromatic-overlay.png"
local SEVERANCE_ARRAY_TECH_ICON = ei_path.."graphics/techs/ei-severance-array.png"
local SEVERANCE_ARRAY_TECH_OVERLAY_ICON = ei_path.."graphics/techs/ei-severance-array-chromatic-overlay.png"
local severance_base_icons = {
    {
        icon = SEVERANCE_ARRAY_ITEM_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
}
local severance_item_icons = {
    {
        icon = SEVERANCE_ARRAY_ITEM_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
    {
        icon = SEVERANCE_ARRAY_ITEM_OVERLAY_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
}
local severance_item_pictures = {
    {
        filename = SEVERANCE_ARRAY_ITEM_ICON,
        mipmap_count = 3,
        scale = 0.25,
        size = 128,
    },
}
local severance_technology_icons = {
    {
        icon = SEVERANCE_ARRAY_TECH_ICON,
        icon_size = 256,
    },
    {
        icon = SEVERANCE_ARRAY_TECH_OVERLAY_ICON,
        icon_size = 256,
    },
}

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

local severance_beam = make_prismatic_beam(
    BEAM_NAME,
    VISUAL_CONFIG.visual_beam_width,
    {
        intensity = VISUAL_CONFIG.visual_beam_light_intensity,
        size = VISUAL_CONFIG.visual_beam_light_size,
        minimum_darkness = 0,
        color = PRISMATIC_BEAM_LIGHT_TINT,
    },
    make_prismatic_beam_graphics_set(PRISMATIC_BEAM_SCALE),
    nil
)

local severance_impact_beam = make_prismatic_beam(
    IMPACT_BEAM_NAME,
    VISUAL_CONFIG.impact_beam_width,
    {
        intensity = VISUAL_CONFIG.impact_beam_light_intensity,
        size = VISUAL_CONFIG.impact_beam_light_size,
        minimum_darkness = 0,
        color = PRISMATIC_IMPACT_LIGHT_TINT,
    },
    make_prismatic_beam_graphics_set(PRISMATIC_IMPACT_BEAM_SCALE, {
        impact_ending = true,
    }),
    make_beam_working_sound(IMPACT_SOUND_VARIATIONS, VISUAL_CONFIG.impact_sound_cap, 0.50)
)

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
severance_fire_sticker.animation = make_afterburn_animation(
    "ei-severance-array-afterburn-sticker.png",
    "ei-severance-array-afterburn-sticker-glow.png",
    96,
    96,
    32,
    8,
    AFTERBURN_STICKER_SCALE,
    table.deepcopy(AFTERBURN_STICKER_SHIFT),
    0.65
)
severance_fire_sticker.light = {
    intensity = 0.22,
    size = 5,
    color = AFTERBURN_LIGHT_TINT,
    flicker_interval = 18,
    flicker_min_modifier = 0.75,
    flicker_max_modifier = 1.25,
}

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
severance_hit_fire.burnt_patch_pictures = nil
severance_hit_fire.emissions_per_second = nil
severance_hit_fire.tree_dying_factor = nil
severance_hit_fire.on_fuel_added_action = nil
severance_hit_fire.smoke_source_pictures = nil
severance_hit_fire.flame_alpha = 0.88
severance_hit_fire.flame_alpha_deviation = 0.03
severance_hit_fire.light = {
    intensity = VISUAL_CONFIG.hit_fire_light_intensity,
    size = VISUAL_CONFIG.hit_fire_light_size,
    color = AFTERBURN_LIGHT_TINT,
}
severance_hit_fire.pictures = {
    make_afterburn_animation(
        "ei-severance-array-afterburn-fire.png",
        "ei-severance-array-afterburn-fire-glow.png",
        192,
        192,
        32,
        8,
        AFTERBURN_FIRE_SCALE,
        table.deepcopy(AFTERBURN_FIRE_SHIFT),
        0.62
    ),
}

local severance_scorchmark = table.deepcopy(data.raw.corpse["small-scorchmark-tintable"] or data.raw.corpse["small-scorchmark"])
severance_scorchmark.name = SCORCHMARK_NAME
severance_scorchmark.hidden_in_factoriopedia = true
severance_scorchmark.time_before_removed = SCORCHMARK_DURATION
severance_scorchmark.selectable_in_game = false
severance_scorchmark.use_tile_color_for_ground_patch_tint = false
severance_scorchmark.ground_patch = make_afterburn_scorchmark_patch(
    "ei-severance-array-afterburn-scorchmark.png"
)
severance_scorchmark.ground_patch_higher = make_afterburn_scorchmark_patch(
    "ei-severance-array-afterburn-scorchmark-glow.png",
    true
)

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
severance_turret.icon_mipmaps = nil
severance_turret.icons = severance_base_icons
copy_turret_visuals(severance_turret, tesla_visual_source)
severance_turret.flags = {"placeable-player", "placeable-enemy", "player-creation", "get-by-unit-number"}
severance_turret.minable = {
    mining_time = 0.75,
    result = NAME,
}
severance_turret.max_health = 2000
severance_turret.heating_energy = "100kW"
severance_turret.collision_box = {{-2.4, -2.4}, {2.4, 2.4}}
severance_turret.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
severance_turret.drawing_box = {{-2.6, -4.5}, {4.35, 3.75}}
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
severance_turret.attack_parameters.source_offset = table.deepcopy(ATTACK_SOURCE_OFFSET)
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
apply_array_visuals(severance_turret)

data:extend({
    severance_fire_sticker,
    severance_hit_fire,
    severance_scorchmark,
    {
        name = NAME,
        type = "item",
        icons = severance_item_icons,
        pictures = severance_item_pictures,
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
        icons = severance_item_icons,
    },
    {
        name = NAME,
        type = "technology",
        icons = severance_technology_icons,
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
