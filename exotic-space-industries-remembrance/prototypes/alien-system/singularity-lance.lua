local ei_data = require("lib/data")
local ei_lib = require("lib/lib")
local singularity_lance_config = require("lib/singularity-lance-config")
local util = require("__core__/lualib/util")

--====================================================================================================
--SINGULARITY LANCE
--====================================================================================================

local NAME = "ei-singularity-lance"
local BEAM_NAME = NAME.."-beam"
local IMPACT_BEAM_NAME = NAME.."-impact-beam"
local TRIGGER_BEAM_NAME = NAME.."-trigger-beam"
local FIRE_STICKER_NAME = NAME.."-fire-sticker"
local HIT_FIRE_NAME = NAME.."-hit-fire"
local SCORCHMARK_NAME = NAME.."-scorchmark"
local SHOT_EFFECT_ID = NAME.."-shot"
local VISUAL_CONFIG = singularity_lance_config.resolve()
local RANGE = singularity_lance_config.range or 85
local MIN_RANGE = 3
local ATTACK_COOLDOWN = singularity_lance_config.attack_cooldown or 1
local TRIGGER_BEAM_DURATION = 1
local FIRE_STICKER_DURATION = VISUAL_CONFIG.fire_sticker_duration
local HIT_FIRE_DURATION = VISUAL_CONFIG.hit_fire_duration
local SCORCHMARK_DURATION = VISUAL_CONFIG.scorchmark_duration
local SCRIPTED_DAMAGE_TYPE = singularity_lance_config.damage_type or "laser"
local SCRIPTED_AMMO_DAMAGE_CATEGORY = singularity_lance_config.ammo_damage_category or "laser"
local SCRIPTED_DIRECT_DAMAGE = singularity_lance_config.direct_damage or 500
local SCRIPTED_SPLASH_DAMAGE = singularity_lance_config.splash_damage or 125
local SCRIPTED_SPLASH_RADIUS = singularity_lance_config.splash_radius or 1.5
local SCRIPTED_BURST_DPS = singularity_lance_config.direct_burst_dps or
    (SCRIPTED_DIRECT_DAMAGE * (singularity_lance_config.ticks_per_second or 60) / ATTACK_COOLDOWN)
local SCRIPTED_SUSTAINED_DPS = singularity_lance_config.direct_sustained_dps or SCRIPTED_BURST_DPS
local SHOT_ENERGY_CONSUMPTION = (singularity_lance_config.shot_energy_mj or 125).."MJ"
local ENERGY_BUFFER_CAPACITY = singularity_lance_config.energy_buffer_capacity or "700MJ"
local ENERGY_INPUT_FLOW_LIMIT = singularity_lance_config.energy_input_flow_limit or "400MW"
local ENERGY_DRAIN = singularity_lance_config.energy_drain or "20MW"
local ATTACK_SOURCE_OFFSET = {0, -3.50}
local BEAM_SOURCE_OFFSET = {0, -3.50}
local TURRET_GLOW_TINT = {r = 0.74, g = 0.14, b = 1.0, a = 0.90}
local LANCE_GRAPHICS_PATH = ei_graphics_entity_4_path.."singularity-lance/"
local LANCE_SOUND_PATH = ei_sounds_4_path
local LANCE_FRAME_SIZE = 768
local LANCE_FRAME_COUNT = 64
local LANCE_LINE_LENGTH = 8
local LANCE_ANIMATION_SPEED = 0.12
local LANCE_STATIC_FRAME_COUNT = 1
local LANCE_STATIC_LINE_LENGTH = 1
local LANCE_RUNE_GLOW_ANIMATION_SPEED = 0.16
local LANCE_BODY_SCALE = 0.65
local LANCE_BODY_SHIFT = {0, -2.66}
local LANCE_BODY_SHADOW_SHIFT = {0, 0.65}
local LANCE_CRYSTAL_SCALE = 0.5
local LANCE_CRYSTAL_SHIFT = {0, -1.90}
local LANCE_CRYSTAL_GLOW_TINT = {r = 0.64, g = 0.98, b = 1.0, a = 0.52}
local LANCE_CRYSTAL_LINK_ANIMATION_SPEED = 0.55
local LANCE_CRYSTAL_LINK_SCALE = LANCE_CRYSTAL_SCALE
local LANCE_CRYSTAL_LINK_SHIFT = {0, -1.75}
local LANCE_CRYSTAL_LINK_GRAPHICS_PATH = LANCE_GRAPHICS_PATH.."crystal-link/"
local PRISMATIC_BEAM_GRAPHICS_PATH = LANCE_GRAPHICS_PATH.."beam/"
local PRISMATIC_BEAM_SCALE = 0.34
local PRISMATIC_IMPACT_BEAM_SCALE = 0.42
local PRISMATIC_BEAM_LIGHT_TINT = {r = 1.0, g = 0.58, b = 0.24, a = 0.82}
local PRISMATIC_IMPACT_LIGHT_TINT = {r = 0.52, g = 0.95, b = 1.0, a = 0.95}
local AFTERBURN_GRAPHICS_PATH = LANCE_GRAPHICS_PATH.."afterburn/"
local AFTERBURN_LIGHT_TINT = {r = 0.48, g = 0.88, b = 1.0, a = 0.90}
local AFTERBURN_FIRE_SCALE = 0.34
local AFTERBURN_FIRE_SHIFT = {0, -0.16}
local AFTERBURN_STICKER_SCALE = 0.38
local AFTERBURN_STICKER_SHIFT = {0, -0.10}
local AFTERBURN_SCORCHMARK_SCALE = 0.5
local AFTERBURN_SCORCHMARK_SHIFT = {0, 0.0625}
local LANCE_BEAM_SOUND_REGULAR = LANCE_SOUND_PATH.."singularity-lance-beam-1.ogg"
local LANCE_BEAM_SOUND_LOWER = LANCE_SOUND_PATH.."singularity-lance-beam-2.ogg"
local LANCE_BEAM_SOUND_HIGHER = LANCE_SOUND_PATH.."singularity-lance-beam-3.ogg"
local IMPACT_SOUND_VARIATIONS = {
    {filename = LANCE_BEAM_SOUND_LOWER, volume = 0.34},
    {filename = LANCE_BEAM_SOUND_REGULAR, volume = 0.30},
    {filename = LANCE_BEAM_SOUND_HIGHER, volume = 0.34},
}
local START_SOUND_VARIATIONS = {
    {filename = LANCE_BEAM_SOUND_LOWER, volume = 0.36},
}

-- Sustained fire is where the lance should breathe. With two outer pitch files and
-- allow_random_repeat disabled, the middle loop reads as a clearer low/high oscillation.
local MIDDLE_SOUND_VARIATIONS = {
    {filename = LANCE_BEAM_SOUND_LOWER, volume = 0.20},
    {filename = LANCE_BEAM_SOUND_HIGHER, volume = 0.20},
}
local END_SOUND_VARIATIONS = {
    {filename = LANCE_BEAM_SOUND_HIGHER, volume = 0.30},
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
        "singularity-lance-beam-body.png",
        "singularity-lance-beam-body-glow.png",
        256,
        96,
        16,
        4,
        scale
    )
    local head = make_prismatic_beam_animation(
        "singularity-lance-beam-head.png",
        "singularity-lance-beam-head-glow.png",
        192,
        160,
        16,
        4,
        scale
    )
    local tail = make_prismatic_beam_animation(
        "singularity-lance-beam-tail.png",
        "singularity-lance-beam-tail-glow.png",
        192,
        160,
        16,
        4,
        scale
    )
    local impact = options.impact_ending and make_prismatic_beam_animation(
        "singularity-lance-impact-prism.png",
        "singularity-lance-impact-prism-glow.png",
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

local function make_lance_animation_layer(filename, options)
    options = options or {}
    local layer = {
        filename = (options.graphics_path or LANCE_GRAPHICS_PATH)..filename,
        width = LANCE_FRAME_SIZE,
        height = LANCE_FRAME_SIZE,
        frame_count = options.frame_count or LANCE_FRAME_COUNT,
        line_length = options.line_length or LANCE_LINE_LENGTH,
        lines_per_file = options.lines_per_file or options.line_length or LANCE_LINE_LENGTH,
        animation_speed = options.animation_speed or LANCE_ANIMATION_SPEED,
        scale = options.scale or LANCE_BODY_SCALE,
        shift = table.deepcopy(options.shift or LANCE_BODY_SHIFT),
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

local function make_lance_base_visualisation()
    return {
        {
            render_layer = "object",
            secondary_draw_order = 0,
            animation = {
                layers = {
                    make_lance_animation_layer("singularity-lance_base-shadow.png", {
                        draw_as_shadow = true,
                        frame_count = LANCE_STATIC_FRAME_COUNT,
                        line_length = LANCE_STATIC_LINE_LENGTH,
                        lines_per_file = LANCE_STATIC_LINE_LENGTH,
                        scale = LANCE_BODY_SCALE,
                        shift = LANCE_BODY_SHADOW_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 0,
            animation = {
                layers = {
                    make_lance_animation_layer("singularity-lance_shadow.png", {
                        draw_as_shadow = true,
                        frame_count = LANCE_STATIC_FRAME_COUNT,
                        line_length = LANCE_STATIC_LINE_LENGTH,
                        lines_per_file = LANCE_STATIC_LINE_LENGTH,
                        scale = LANCE_CRYSTAL_SCALE,
                        shift = LANCE_CRYSTAL_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 1,
            animation = {
                layers = {
                    make_lance_animation_layer("singularity-lance.png", {
                        frame_count = LANCE_STATIC_FRAME_COUNT,
                        line_length = LANCE_STATIC_LINE_LENGTH,
                        lines_per_file = LANCE_STATIC_LINE_LENGTH,
                        scale = LANCE_BODY_SCALE,
                        shift = LANCE_BODY_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 1,
            animation = {
                layers = {
                    make_lance_animation_layer("singularity-lance-rune-glow.png", {
                        animation_speed = LANCE_RUNE_GLOW_ANIMATION_SPEED,
                        draw_as_glow = true,
                        blend_mode = "additive-soft",
                        scale = LANCE_BODY_SCALE,
                        shift = LANCE_BODY_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 2,
            animation = {
                layers = {
                    make_lance_animation_layer("singularity-lance-crystal-link.png", {
                        graphics_path = LANCE_CRYSTAL_LINK_GRAPHICS_PATH,
                        animation_speed = LANCE_CRYSTAL_LINK_ANIMATION_SPEED,
                        scale = LANCE_CRYSTAL_LINK_SCALE,
                        shift = LANCE_CRYSTAL_LINK_SHIFT,
                    }),
                    make_lance_animation_layer("singularity-lance-crystal-link-glow.png", {
                        graphics_path = LANCE_CRYSTAL_LINK_GRAPHICS_PATH,
                        animation_speed = LANCE_CRYSTAL_LINK_ANIMATION_SPEED,
                        draw_as_glow = true,
                        blend_mode = "additive-soft",
                        scale = LANCE_CRYSTAL_LINK_SCALE,
                        shift = LANCE_CRYSTAL_LINK_SHIFT,
                    }),
                },
            },
        },
        {
            render_layer = "object",
            secondary_draw_order = 3,
            animation = {
                layers = {
                    make_lance_animation_layer("singularity-lance_crystal.png", {
                        scale = LANCE_CRYSTAL_SCALE,
                        shift = LANCE_CRYSTAL_SHIFT,
                    }),
                    make_lance_animation_layer("singularity-lance_crystal.png", {
                        draw_as_glow = true,
                        blend_mode = "normal",
                        tint = LANCE_CRYSTAL_GLOW_TINT,
                        scale = LANCE_CRYSTAL_SCALE,
                        shift = LANCE_CRYSTAL_SHIFT,
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

local function apply_lance_visuals(turret)
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
        base_visualisation = make_lance_base_visualisation(),
    }
    turret.energy_glow_animation = nil
    turret.resource_indicator_animation = nil
    turret.prepared_alternative_animation = nil
    turret.prepared_alternative_chance = nil
    turret.turret_base_has_direction = false
    turret.folded_animation_is_stateless = true
    turret.random_animation_offset = true
end

local SINGULARITY_LANCE_ITEM_ICON = ei_graphics_item_4_path.."singularity-lance.png"
local SINGULARITY_LANCE_ITEM_OVERLAY_ICON = ei_graphics_item_4_path.."singularity-lance-chromatic-overlay.png"
local SINGULARITY_LANCE_TECH_ICON = ei_graphics_tech_4_path.."singularity-lance.png"
local SINGULARITY_LANCE_TECH_OVERLAY_ICON = ei_graphics_tech_4_path.."singularity-lance-chromatic-overlay.png"
local singularity_base_icons = {
    {
        icon = SINGULARITY_LANCE_ITEM_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
}
local singularity_item_icons = {
    {
        icon = SINGULARITY_LANCE_ITEM_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
    {
        icon = SINGULARITY_LANCE_ITEM_OVERLAY_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
}
local singularity_item_pictures = {
    {
        filename = SINGULARITY_LANCE_ITEM_ICON,
        mipmap_count = 3,
        scale = 0.25,
        size = 128,
    },
}
local singularity_technology_icons = {
    {
        icon = SINGULARITY_LANCE_TECH_ICON,
        icon_size = 256,
    },
    {
        icon = SINGULARITY_LANCE_TECH_OVERLAY_ICON,
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

local function format_tooltip_number(value)
    value = tonumber(value) or 0
    if value % 1 == 0 then
        return tostring(math.floor(value))
    end

    return string.format("%.1f", value)
end

local function make_scripted_damage_tooltip_fields()
    return {
        {
            name = "",
            value = {"custom-tooltip.ei-singularity-lance-scripted-header", {"custom-tooltip.ei-singularity-lance-scripted-title"}},
        },
        {
            name = {"custom-tooltip.ei-singularity-lance-direct-hit"},
            value = {
                "custom-tooltip.ei-singularity-lance-direct-hit-value",
                format_tooltip_number(SCRIPTED_DIRECT_DAMAGE),
                {"damage-type-name."..SCRIPTED_DAMAGE_TYPE},
            },
        },
        {
            name = {"custom-tooltip.ei-singularity-lance-sustained-dps"},
            value = {
                "custom-tooltip.ei-singularity-lance-dps-value",
                format_tooltip_number(SCRIPTED_SUSTAINED_DPS),
                {"damage-type-name."..SCRIPTED_DAMAGE_TYPE},
            },
        },
        {
            name = {"custom-tooltip.ei-singularity-lance-burst-dps"},
            value = {
                "custom-tooltip.ei-singularity-lance-dps-value",
                format_tooltip_number(SCRIPTED_BURST_DPS),
                {"damage-type-name."..SCRIPTED_DAMAGE_TYPE},
            },
        },
        {
            name = {"custom-tooltip.ei-singularity-lance-splash"},
            value = {
                "custom-tooltip.ei-singularity-lance-splash-value",
                format_tooltip_number(SCRIPTED_SPLASH_DAMAGE),
                {"damage-type-name."..SCRIPTED_DAMAGE_TYPE},
                format_tooltip_number(SCRIPTED_SPLASH_RADIUS),
            },
        },
    }
end

local function make_scripted_damage_item_tooltip_fields()
    local fields = make_scripted_damage_tooltip_fields()
    for _, field in ipairs(fields) do
        field.show_in_factoriopedia = false
    end

    return fields
end

local singularity_beam = make_prismatic_beam(
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

local singularity_impact_beam = make_prismatic_beam(
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

local singularity_trigger_beam = table.deepcopy(data.raw.beam["laser-beam"])
singularity_trigger_beam.name = TRIGGER_BEAM_NAME
singularity_trigger_beam.width = 0.01
singularity_trigger_beam.light = nil
singularity_trigger_beam.hidden = true
singularity_trigger_beam.hidden_in_factoriopedia = true
singularity_trigger_beam.damage_interval = 1
singularity_trigger_beam.random_target_offset = false
singularity_trigger_beam.target_offset = {0, 0}
singularity_trigger_beam.action_triggered_automatically = false

local empty_beam_sprite = util.empty_sprite()
singularity_trigger_beam.graphics_set = make_empty_beam_graphics_set(empty_beam_sprite)
singularity_trigger_beam.head = table.deepcopy(empty_beam_sprite)
singularity_trigger_beam.tail = table.deepcopy(empty_beam_sprite)
singularity_trigger_beam.body = {table.deepcopy(empty_beam_sprite)}
singularity_trigger_beam.working_sound = nil
singularity_trigger_beam.action = {
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

local singularity_fire_sticker = table.deepcopy(data.raw.sticker["fire-sticker"])
singularity_fire_sticker.name = FIRE_STICKER_NAME
singularity_fire_sticker.hidden = true
singularity_fire_sticker.flags = {"not-on-map"}
singularity_fire_sticker.duration_in_ticks = FIRE_STICKER_DURATION
singularity_fire_sticker.damage_interval = FIRE_STICKER_DURATION
singularity_fire_sticker.target_movement_modifier = 0.95
singularity_fire_sticker.damage_per_tick = {amount = 1.25, type = "fire"}
singularity_fire_sticker.spread_fire_entity = nil
singularity_fire_sticker.fire_spread_cooldown = nil
singularity_fire_sticker.fire_spread_radius = nil
singularity_fire_sticker.animation = make_afterburn_animation(
    "singularity-lance-afterburn-sticker.png",
    "singularity-lance-afterburn-sticker-glow.png",
    96,
    96,
    32,
    8,
    AFTERBURN_STICKER_SCALE,
    table.deepcopy(AFTERBURN_STICKER_SHIFT),
    0.65
)
singularity_fire_sticker.light = {
    intensity = 0.22,
    size = 5,
    color = AFTERBURN_LIGHT_TINT,
    flicker_interval = 18,
    flicker_min_modifier = 0.75,
    flicker_max_modifier = 1.25,
}

local singularity_hit_fire = table.deepcopy(data.raw.fire["fire-flame"])
singularity_hit_fire.name = HIT_FIRE_NAME
singularity_hit_fire.hidden = true
singularity_hit_fire.hidden_in_factoriopedia = true
singularity_hit_fire.flags = {"placeable-off-grid", "not-on-map"}
singularity_hit_fire.damage_per_tick = {amount = 0.3, type = "fire"}
singularity_hit_fire.maximum_damage_multiplier = 1
singularity_hit_fire.damage_multiplier_increase_per_added_fuel = 0
singularity_hit_fire.damage_multiplier_decrease_per_tick = 0
singularity_hit_fire.spawn_entity = nil
singularity_hit_fire.maximum_spread_count = 0
singularity_hit_fire.spread_delay = 60 * 60
singularity_hit_fire.spread_delay_deviation = 0
singularity_hit_fire.initial_lifetime = HIT_FIRE_DURATION
singularity_hit_fire.lifetime_increase_by = 0
singularity_hit_fire.lifetime_increase_cooldown = 1
singularity_hit_fire.maximum_lifetime = HIT_FIRE_DURATION
singularity_hit_fire.delay_between_initial_flames = 1
singularity_hit_fire.initial_flame_count = 1
singularity_hit_fire.fade_out_duration = math.min(15, HIT_FIRE_DURATION)
singularity_hit_fire.burnt_patch_lifetime = 0
singularity_hit_fire.burnt_patch_pictures = nil
singularity_hit_fire.emissions_per_second = nil
singularity_hit_fire.tree_dying_factor = nil
singularity_hit_fire.on_fuel_added_action = nil
singularity_hit_fire.smoke_source_pictures = nil
singularity_hit_fire.flame_alpha = 0.88
singularity_hit_fire.flame_alpha_deviation = 0.03
singularity_hit_fire.light = {
    intensity = VISUAL_CONFIG.hit_fire_light_intensity,
    size = VISUAL_CONFIG.hit_fire_light_size,
    color = AFTERBURN_LIGHT_TINT,
}
singularity_hit_fire.pictures = {
    make_afterburn_animation(
        "singularity-lance-afterburn-fire.png",
        "singularity-lance-afterburn-fire-glow.png",
        192,
        192,
        32,
        8,
        AFTERBURN_FIRE_SCALE,
        table.deepcopy(AFTERBURN_FIRE_SHIFT),
        0.62
    ),
}

local singularity_scorchmark = table.deepcopy(data.raw.corpse["small-scorchmark-tintable"] or data.raw.corpse["small-scorchmark"])
singularity_scorchmark.name = SCORCHMARK_NAME
singularity_scorchmark.hidden_in_factoriopedia = true
singularity_scorchmark.time_before_removed = SCORCHMARK_DURATION
singularity_scorchmark.selectable_in_game = false
singularity_scorchmark.use_tile_color_for_ground_patch_tint = false
singularity_scorchmark.ground_patch = make_afterburn_scorchmark_patch(
    "singularity-lance-afterburn-scorchmark.png"
)
singularity_scorchmark.ground_patch_higher = make_afterburn_scorchmark_patch(
    "singularity-lance-afterburn-scorchmark-glow.png",
    true
)

local tesla_visual_source = data.raw["electric-turret"]["tesla-turret"]
    or data.raw["electric-turret"]["tl-basic-tesla-coil"]
    or data.raw["electric-turret"]["tl-advanced-tesla-coil"]
if tesla_visual_source then
    tesla_visual_source = table.deepcopy(tesla_visual_source)
    ei_lib.entity_icon_scaler(tesla_visual_source, 4 / selection_width(tesla_visual_source))
end

local singularity_turret = table.deepcopy(data.raw["electric-turret"]["laser-turret"])
local inherited_attack_parameters = tesla_visual_source and tesla_visual_source.attack_parameters
singularity_turret.name = NAME
singularity_turret.localised_name = {"entity-name."..NAME}
singularity_turret.localised_description = {"entity-description."..NAME}
singularity_turret.icon = nil
singularity_turret.icon_size = nil
singularity_turret.icon_mipmaps = nil
singularity_turret.icons = singularity_base_icons
copy_turret_visuals(singularity_turret, tesla_visual_source)
singularity_turret.flags = {"placeable-player", "placeable-enemy", "player-creation", "get-by-unit-number"}
singularity_turret.minable = {
    mining_time = 0.75,
    result = NAME,
}
singularity_turret.max_health = 2000
singularity_turret.resistances = {
    {type = "physical", percent = 50},
    {type = "fire", percent = 75},
    {type = "impact", percent = 75}
}
singularity_turret.hide_resistances = false
singularity_turret.heating_energy = "100kW"
singularity_turret.collision_box = {{-2.4, -2.4}, {2.4, 2.4}}
singularity_turret.selection_box = {{-2.5, -2.5}, {2.5, 2.5}}
singularity_turret.drawing_box = {{-2.6, -4.5}, {4.35, 3.75}}
singularity_turret.rotation_speed = math.max(tesla_visual_source and tesla_visual_source.rotation_speed or 0.005, 0.08)
singularity_turret.preparing_speed = tesla_visual_source and tesla_visual_source.preparing_speed or 0.1
singularity_turret.folding_speed = tesla_visual_source and tesla_visual_source.folding_speed or 0.1
singularity_turret.attacking_speed = tesla_visual_source and tesla_visual_source.attacking_speed or nil
singularity_turret.ending_attack_speed = tesla_visual_source and tesla_visual_source.ending_attack_speed or 0.03225806451612903
singularity_turret.start_attacking_only_when_can_shoot = tesla_visual_source and tesla_visual_source.start_attacking_only_when_can_shoot or true
singularity_turret.prepare_range = RANGE
singularity_turret.call_for_help_radius = 60
singularity_turret.energy_source = {
    type = "electric",
    buffer_capacity = ENERGY_BUFFER_CAPACITY,
    input_flow_limit = ENERGY_INPUT_FLOW_LIMIT,
    drain = ENERGY_DRAIN,
    usage_priority = "primary-input",
}

singularity_turret.attack_parameters = table.deepcopy(data.raw["electric-turret"]["laser-turret"].attack_parameters)
singularity_turret.attack_parameters.type = "beam"
singularity_turret.attack_parameters.ammo_category = SCRIPTED_AMMO_DAMAGE_CATEGORY
singularity_turret.attack_parameters.cooldown = ATTACK_COOLDOWN
singularity_turret.attack_parameters.cooldown_deviation = 0
singularity_turret.attack_parameters.range = RANGE
singularity_turret.attack_parameters.min_range = MIN_RANGE
singularity_turret.attack_parameters.range_mode = inherited_attack_parameters and inherited_attack_parameters.range_mode or "center-to-bounding-box"
singularity_turret.attack_parameters.source_direction_count = inherited_attack_parameters and inherited_attack_parameters.source_direction_count or 64
singularity_turret.attack_parameters.source_offset = table.deepcopy(ATTACK_SOURCE_OFFSET)
singularity_turret.attack_parameters.damage_modifier = 1
singularity_turret.attack_parameters.fire_penalty = 0
singularity_turret.attack_parameters.health_penalty = nil
singularity_turret.attack_parameters.rotate_penalty = 40
singularity_turret.attack_parameters.cyclic_sound = make_cyclic_laser_sound()
singularity_turret.attack_parameters.ammo_type = {
    energy_consumption = SHOT_ENERGY_CONSUMPTION,
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

if singularity_turret.energy_glow_animation then
    tint_glow_animation(singularity_turret.energy_glow_animation, TURRET_GLOW_TINT)
end
if singularity_turret.graphics_set then
    tint_glow_animation(singularity_turret.graphics_set, TURRET_GLOW_TINT)
end
singularity_turret.glow_light_intensity = 0.85
singularity_turret.water_reflection = nil
apply_lance_visuals(singularity_turret)
ei_lib.set_custom_tooltip_fields(singularity_turret, make_scripted_damage_tooltip_fields())

local singularity_item = {
    name = NAME,
    type = "item",
    icons = singularity_item_icons,
    pictures = singularity_item_pictures,
    subgroup = "ei-alien-structures-2",
    order = "a-e[ei-singularity-lance]",
    place_result = NAME,
    stack_size = 10,
}
ei_lib.set_custom_tooltip_fields(singularity_item, make_scripted_damage_item_tooltip_fields())

data:extend({
    {
        name = SCRIPTED_AMMO_DAMAGE_CATEGORY,
        type = "ammo-category",
        localised_name = {"ammo-category-name."..SCRIPTED_AMMO_DAMAGE_CATEGORY},
        icon = SINGULARITY_LANCE_ITEM_ICON,
        icon_size = 128,
        icon_mipmaps = 3,
    },
    singularity_fire_sticker,
    singularity_hit_fire,
    singularity_scorchmark,
    singularity_item,
    {
        name = NAME,
        type = "recipe",
        category = "crafting-with-fluid",
        additional_categories = {"electronics-with-fluid"},
        energy_required = 90,
        surface_conditions =
        {
           {
              property = "gravity",
              min = 15.5,
              max = 15.5
            }
        },
        ingredients = {
            {type = "fluid", name = "ei-oxygen-difluoride", amount = 500},
            {type = "item", name = "laser-turret", amount = 8},
            {type = "item", name = "ei-crystal-accumulator", amount = 1},
            {type = "item", name = "ei-sus-plating", amount = 250},
            {type = "item", name = "ei-electronic-parts", amount = 180},
            {type = "item", name = "ei-high-energy-crystal", amount = 160},
            {type = "item", name = "ei-alien-resin", amount = 220},
            {type = "item", name = "ei-computing-unit", amount = 60},
            {type = "item", name = "ei-condensed-cryodust", amount = 120},
        },
        results = {{type = "item", name = NAME, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = NAME,
        icons = singularity_item_icons,
    },
    {
        name = NAME,
        type = "technology",
        icons = singularity_technology_icons,
        prerequisites = {
            "ei-crystal-accumulator",
            "ei-oxygen-difluoride-alien",
            "ei-bio-electronic-parts",
            "ei-bio-high-energy-crystal",
            "ei-cryodust",
            "ei-computing-unit",
            "laser-weapons-damage-5",
        },
        effects = {
            {
                type = "unlock-recipe",
                recipe = NAME,
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 30,
        },
        age = "alien-computer-age",
    },
    singularity_turret,
    singularity_beam,
    singularity_impact_beam,
    singularity_trigger_beam,
})
