local util = require("util")

--==============================================================================
-- ESIR ROCKET ORDNANCE EFFECTS
--==============================================================================
-- Placeholder-but-real prototypes for the modular rocket ordnance pass.
-- The main prototype and recipe wiring will bind these ids later.

local plasma_explosion_sheet = ei_graphics_other_path .. "plasma-explosion.png"
local plasma_explosion_frame_size = {1944 / 6, 1248 / 3}
local spark_sheet = ei_graphics_3_path .. "graphics/entities/acid-turret/acid-flame/spark.png"
local smoke_sheet = "__base__/graphics/entity/fire-smoke/fire-smoke.png"
local smoke_glow_sheet = "__base__/graphics/entity/fire-smoke/fire-smoke-glow.png"
local stream_spine_sheet = "__base__/graphics/entity/flamethrower-fire-stream/flamethrower-fire-stream-spine.png"
local stream_particle_sheet = "__base__/graphics/entity/flamethrower-fire-stream/flamethrower-explosion.png"
local stream_shadow_sheet = "__base__/graphics/entity/acid-projectile/projectile-shadow.png"
local toxic_biters_enabled = mods["Toxic_biters"]

local function sound_variations(volume_scale)
    local files = {
        "plasma_bullet_explosion_1.ogg",
        "plasma_bullet_explosion_2.ogg",
        "plasma_bullet_explosion_3.ogg",
        "plasma_bullet_explosion_4.ogg",
        "plasma_bullet_explosion_5.ogg",
        "plasma_bullet_explosion_6.ogg",
    }

    local variations = {}
    for _, file_name in ipairs(files) do
        variations[#variations + 1] = {
            filename = ei_graphics_2_path .. "sounds/weapons/" .. file_name,
            volume = volume_scale,
        }
    end

    return {
        aggregation = {
            max_count = 40,
            remove = true,
        },
        variations = variations,
    }
end

local function make_explosion(name, opts)
    opts = opts or {}

    return {
        type = "explosion",
        name = name,
        flags = {"not-on-map"},
        animations = {
            {
                filename = opts.filename or plasma_explosion_sheet,
                -- The plasma sheet is packed as 6x6 frames at 324x416. Half-height
                -- frames crop the blast and produce a visible cutoff in-game.
                size = opts.size or plasma_explosion_frame_size,
                shift = opts.shift or {0, -6},
                scale = opts.scale or 3,
                line_length = opts.line_length or 6,
                lines_per_file = opts.lines_per_file or 6,
                frame_count = opts.frame_count or 36,
                animation_speed = opts.animation_speed or 0.3,
                draw_as_glow = true,
                priority = "high",
                tint = opts.tint,
            },
        },
        light_intensity_peak_end_progress = opts.light_intensity_peak_end_progress or 0.6,
        light_size_peak_start_progress = opts.light_size_peak_start_progress or 0.05,
        light_size_peak_end_progress = opts.light_size_peak_end_progress or 0.9,
        scale_out_duration = opts.scale_out_duration or 45,
        scale_end = opts.scale_end or 0.85,
        scale_animation_speed = true,
        light = opts.light or {
            intensity = 0.75,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 0.65, g = 0.8, b = 1.0},
            size = 100,
        },
        sound = opts.sound or sound_variations(0.9),
        smoke = opts.smoke or "smoke-fast",
        smoke_count = opts.smoke_count or 2,
        smoke_slow_down_factor = opts.smoke_slow_down_factor or 1,
        created_effect = opts.created_effect or {
            type = "direct",
            action_delivery = {
                type = "instant",
                target_effects = {
                    {
                        type = "create-entity",
                        entity_name = "medium-scorchmark",
                        check_buildability = true,
                    },
                },
            },
        },
        subgroup = "explosions",
        order = opts.order or "c-a-a",
    }
end

local function apply_animation_overrides(root, opts)
    if type(root) ~= "table" then
        return
    end

    if root.filename or root.filenames or root.stripes then
        if opts.scale ~= nil then
            root.scale = opts.scale
        end
        if opts.shift ~= nil then
            root.shift = opts.shift
        end
        if opts.tint ~= nil then
            root.tint = opts.tint
        end
        if opts.animation_speed ~= nil then
            root.animation_speed = opts.animation_speed
        end
        if opts.draw_as_glow ~= nil then
            root.draw_as_glow = opts.draw_as_glow
        end
    end

    for _, value in pairs(root) do
        if type(value) == "table" then
            apply_animation_overrides(value, opts)
        end
    end
end

local function clone_explosion(name, source_name, opts)
    opts = opts or {}

    local source = data.raw.explosion[source_name]
    if not source then
        return make_explosion(name, opts.fallback)
    end

    local explosion = table.deepcopy(source)
    explosion.name = name
    explosion.flags = {"not-on-map"}
    explosion.subgroup = "explosions"
    explosion.order = opts.order or explosion.order or "c-a-a"

    if opts.smoke ~= nil then
        explosion.smoke = opts.smoke
    end
    if opts.smoke_count ~= nil then
        explosion.smoke_count = opts.smoke_count
    end
    if opts.smoke_slow_down_factor ~= nil then
        explosion.smoke_slow_down_factor = opts.smoke_slow_down_factor
    end
    if opts.sound ~= nil then
        explosion.sound = opts.sound
    end
    if opts.light ~= nil then
        explosion.light = opts.light
    end
    if opts.remove_created_effect then
        explosion.created_effect = nil
    elseif opts.created_effect ~= nil then
        explosion.created_effect = opts.created_effect
    end
    if opts.scale_out_duration ~= nil then
        explosion.scale_out_duration = opts.scale_out_duration
    end
    if opts.scale_end ~= nil then
        explosion.scale_end = opts.scale_end
    end
    if opts.light_intensity_peak_end_progress ~= nil then
        explosion.light_intensity_peak_end_progress = opts.light_intensity_peak_end_progress
    end
    if opts.light_size_peak_start_progress ~= nil then
        explosion.light_size_peak_start_progress = opts.light_size_peak_start_progress
    end
    if opts.light_size_peak_end_progress ~= nil then
        explosion.light_size_peak_end_progress = opts.light_size_peak_end_progress
    end
    if opts.scale_animation_speed ~= nil then
        explosion.scale_animation_speed = opts.scale_animation_speed
    end

    apply_animation_overrides(explosion.animations, opts)
    return explosion
end

local function make_smoke(name, opts)
    opts = opts or {}

    return {
        type = "trivial-smoke",
        name = name,
        flags = {"not-on-map"},
        color = opts.color or {r = 0.7, g = 0.75, b = 0.8, a = 0.35},
        start_scale = opts.start_scale or 0.35,
        end_scale = opts.end_scale or 0.12,
        duration = opts.duration or 60,
        spread_duration = opts.spread_duration or 120,
        fade_away_duration = opts.fade_away_duration or 30,
        fade_in_duration = opts.fade_in_duration or 15,
        animation = {
            filename = opts.filename or smoke_sheet,
            flags = {"always-compressed"},
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            axially_symmetrical = false,
            direction_count = 1,
            shift = opts.shift or {-0.265625, -0.09375},
            priority = "high",
            animation_speed = 0.25,
            tint = opts.tint,
        },
        glow_animation = opts.glow_animation or {
            filename = smoke_glow_sheet,
            flags = {"always-compressed"},
            blend_mode = "additive",
            line_length = 8,
            width = 253,
            height = 152,
            frame_count = 60,
            axially_symmetrical = false,
            direction_count = 1,
            shift = {-0.265625, 0.8125},
            priority = "high",
            animation_speed = 0.25,
            tint = opts.glow_tint,
        },
        glow_fade_away_duration = opts.glow_fade_away_duration or 70,
    }
end

local function make_sticker(name, opts)
    opts = opts or {}

    return {
        type = "sticker",
        name = name,
        flags = {"not-on-map"},
        animation = {
            filename = opts.filename or spark_sheet,
            line_length = opts.line_length or 5,
            width = opts.width or 64,
            height = opts.height or 64,
            frame_count = opts.frame_count or 5,
            axially_symmetrical = false,
            direction_count = opts.direction_count or 1,
            blend_mode = "normal",
            animation_speed = opts.animation_speed or 0.5,
            scale = opts.scale or 0.5,
            tint = opts.tint or {r = 1, g = 1, b = 1, a = 1},
            shift = opts.shift or {-0.078125, -1.8125},
        },
        duration_in_ticks = opts.duration_in_ticks or 7 * 60,
        target_movement_modifier = opts.target_movement_modifier or 0.4,
        damage_per_tick = opts.damage_per_tick,
    }
end

local function make_optional_corrosive_toxic_sticker(name)
    if not toxic_biters_enabled then
        return nil
    end

    local source = data.raw.sticker["tb-fire-sticker"]
        or data.raw.sticker["tb-poison-sticker"]
        or data.raw.sticker["tb_poison_sticker"]
        or data.raw.sticker["ei-poison-sticker"]
    if not source then
        return nil
    end

    local sticker = table.deepcopy(source)
    sticker.name = name or "ei-corrosive-rocket-toxic-sticker"
    sticker.flags = {"not-on-map"}
    sticker.duration_in_ticks = 5 * 60
    sticker.damage_per_tick = {
        amount = 3 / 60,
        type = "poison",
    }

    if sticker.animation then
        sticker.animation = table.deepcopy(sticker.animation)
        sticker.animation.tint = {r = 0.72, g = 0.3, b = 0.9, a = 0.72}
        sticker.animation.scale = sticker.animation.scale or 0.5
    end

    return sticker
end

local function stream_sprites(tint)
    return {
        spine_animation = util.draw_as_glow {
            filename = stream_spine_sheet,
            blend_mode = "normal",
            tint = tint,
            line_length = 6,
            width = 54,
            height = 26,
            frame_count = 36,
            animation_speed = 2,
            shift = {0, 0},
        },
        shadow = {
            filename = stream_shadow_sheet,
            line_length = 5,
            width = 28,
            height = 16,
            frame_count = 33,
            priority = "high",
            shift = {-0.09, 0.395},
        },
        particle = util.draw_as_glow {
            filename = stream_particle_sheet,
            priority = "extra-high",
            blend_mode = "normal",
            tint = tint,
            line_length = 6,
            width = 124,
            height = 108,
            frame_count = 36,
            scale = 0.666,
        },
    }
end

local function make_stream(name, opts)
    opts = opts or {}
    local sprites = stream_sprites(opts.tint or {r = 0.8, g = 0.9, b = 1.0, a = 0.7})

    return {
        type = "stream",
        name = name,
        flags = {"not-on-map"},
        hidden = true,
        particle_buffer_size = opts.particle_buffer_size or 90,
        particle_spawn_interval = opts.particle_spawn_interval or 2,
        particle_spawn_timeout = opts.particle_spawn_timeout or 14,
        particle_vertical_acceleration = opts.particle_vertical_acceleration or 0.009,
        particle_horizontal_speed = opts.particle_horizontal_speed or 0.22,
        particle_horizontal_speed_deviation = opts.particle_horizontal_speed_deviation or 0.005,
        particle_start_alpha = opts.particle_start_alpha or 1.0,
        particle_end_alpha = opts.particle_end_alpha or 0.2,
        particle_start_scale = opts.particle_start_scale or 0.2,
        particle_end_scale = opts.particle_end_scale or 1.6,
        particle_loop_frame_count = opts.particle_loop_frame_count or 3,
        particle_fade_out_threshold = opts.particle_fade_out_threshold or 0.9,
        particle_loop_exit_threshold = opts.particle_loop_exit_threshold or 0.25,
        smoke_sources = opts.smoke_sources,
        action = opts.action,
        spine_animation = sprites.spine_animation,
        shadow = sprites.shadow,
        particle = sprites.particle,
    }
end

local function make_corrosive_cloud_visual()
    local source = data.raw["smoke-with-trigger"]["tb_poison-cloud-visual-dummy"]
        or data.raw["smoke-with-trigger"]["poison-cloud-visual-dummy"]

    local visual = source and table.deepcopy(source) or {
        type = "smoke-with-trigger",
        name = "ei-corrosive-rocket-cloud-visual",
        flags = {"not-on-map"},
        show_when_smoke_off = true,
        particle_count = 8,
        particle_spread = {3.2, 2.0},
        particle_distance_scale_factor = 0.1,
        particle_duration_variance = 60,
        wave_distance = {0.3, 0.2},
        wave_speed = {0.012, 0.014},
        duration = 8 * 60,
        fade_away_duration = 2 * 60,
        spread_duration = 6 * 60,
        color = {r = 0.22, g = 0.85, b = 0.3, a = 0.35},
        animation = {
            width = 152,
            height = 120,
            line_length = 5,
            frame_count = 60,
            shift = {-0.53125, -0.4375},
            priority = "high",
            animation_speed = 0.25,
            filename = "__base__/graphics/entity/smoke/smoke.png",
            flags = {"compressed"},
        },
        affected_by_wind = false,
        cyclic = true,
    }

    visual.name = "ei-corrosive-rocket-cloud-visual"
    visual.flags = {"not-on-map"}
    visual.show_when_smoke_off = true
    visual.duration = 8 * 60
    visual.fade_away_duration = 2 * 60
    visual.spread_duration = 6 * 60
    visual.color = {r = 0.22, g = 0.85, b = 0.3, a = 0.35}
    visual.affected_by_wind = false
    visual.cyclic = true

    if visual.animation then
        visual.animation = table.deepcopy(visual.animation)
        visual.animation.tint = {r = 0.45, g = 1.0, b = 0.42, a = 0.75}
    end

    return visual
end

local function make_corrosive_cloud(name, pulse_damage)
    local source = data.raw["smoke-with-trigger"]["tb_poison_cloud_1"]
        or data.raw["smoke-with-trigger"]["poison-cloud"]

    local cloud = source and table.deepcopy(source) or {
        type = "smoke-with-trigger",
        name = name or "ei-corrosive-rocket-cloud",
        flags = {"not-on-map"},
        show_when_smoke_off = true,
        particle_count = 8,
        particle_spread = {3.8, 2.2},
        particle_distance_scale_factor = 0.1,
        wave_distance = {0.3, 0.2},
        wave_speed = {0.012, 0.014},
        duration = 8 * 60,
        fade_away_duration = 2 * 60,
        spread_duration = 6 * 60,
        color = {r = 0.14, g = 0.6, b = 0.2, a = 0.4},
        animation = {
            width = 152,
            height = 120,
            line_length = 5,
            frame_count = 60,
            shift = {-0.53125, -0.4375},
            priority = "high",
            animation_speed = 0.25,
            filename = "__base__/graphics/entity/smoke/smoke.png",
            flags = {"compressed"},
        },
        affected_by_wind = false,
        cyclic = true,
    }

    cloud.name = name or "ei-corrosive-rocket-cloud"
    cloud.flags = {"not-on-map"}
    cloud.show_when_smoke_off = true
    cloud.duration = 8 * 60
    cloud.fade_away_duration = 2 * 60
    cloud.spread_duration = 6 * 60
    cloud.action_cooldown = 30
    cloud.color = {r = 0.14, g = 0.6, b = 0.2, a = 0.4}
    cloud.affected_by_wind = false
    cloud.cyclic = true

    if cloud.animation then
        cloud.animation = table.deepcopy(cloud.animation)
        cloud.animation.tint = {r = 0.28, g = 0.95, b = 0.32, a = 0.8}
    end

    cloud.created_effect = {
        {
            type = "cluster",
            cluster_count = 6,
            distance = 2.5,
            distance_deviation = 2,
            action_delivery = {
                type = "instant",
                target_effects = {
                    {
                        type = "create-smoke",
                        entity_name = "ei-corrosive-rocket-cloud-visual",
                        show_in_tooltip = false,
                        initial_height = 0,
                    },
                },
            },
        },
    }
    cloud.action = {
        type = "direct",
        action_delivery = {
            type = "instant",
            target_effects = {
                {
                    type = "nested-result",
                    action = {
                        type = "area",
                        radius = 4.5,
                        force = "enemy",
                        action_delivery = {
                            type = "instant",
                            target_effects = {
                                {
                                    type = "damage",
                                    damage = {amount = pulse_damage or 3, type = "acid"},
                                    apply_damage_to_trees = false,
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    return cloud
end

local optional_stickers = {}
local corrosive_toxic_overlay_sticker = make_optional_corrosive_toxic_sticker()
if corrosive_toxic_overlay_sticker then
    optional_stickers[#optional_stickers + 1] = corrosive_toxic_overlay_sticker
end

local dw_toxic_overlay_sticker = make_optional_corrosive_toxic_sticker("ei-dw-corrosive-rocket-toxic-sticker")
if dw_toxic_overlay_sticker then
    optional_stickers[#optional_stickers + 1] = dw_toxic_overlay_sticker
end

data:extend({
    make_smoke("ei-siege-rocket-smoke", {
        color = {r = 0.65, g = 0.6, b = 0.5, a = 0.3},
        start_scale = 0.45,
        end_scale = 0.18,
        duration = 75,
        spread_duration = 110,
        fade_away_duration = 25,
        fade_in_duration = 20,
        tint = {r = 0.85, g = 0.8, b = 0.6, a = 0.8},
        glow_tint = {r = 0.9, g = 0.82, b = 0.55, a = 0.7},
    }),
    make_smoke("ei-corrosive-rocket-smoke", {
        color = {r = 0.15, g = 0.45, b = 0.12, a = 0.35},
        start_scale = 0.4,
        end_scale = 0.16,
        duration = 90,
        spread_duration = 130,
        fade_away_duration = 35,
        fade_in_duration = 20,
        tint = {r = 0.35, g = 0.9, b = 0.35, a = 0.75},
        glow_tint = {r = 0.25, g = 0.75, b = 0.25, a = 0.75},
    }),
    make_smoke("ei-cryo-rocket-smoke", {
        color = {r = 0.55, g = 0.75, b = 0.95, a = 0.28},
        start_scale = 0.38,
        end_scale = 0.14,
        duration = 80,
        spread_duration = 125,
        fade_away_duration = 30,
        fade_in_duration = 20,
        tint = {r = 0.6, g = 0.85, b = 1.0, a = 0.7},
        glow_tint = {r = 0.8, g = 0.95, b = 1.0, a = 0.85},
    }),
    make_smoke("ei-atomic-rocket-smoke", {
        color = {r = 0.85, g = 0.7, b = 0.35, a = 0.38},
        start_scale = 0.5,
        end_scale = 0.2,
        duration = 110,
        spread_duration = 150,
        fade_away_duration = 40,
        fade_in_duration = 20,
        tint = {r = 1.0, g = 0.9, b = 0.55, a = 0.8},
        glow_tint = {r = 1.0, g = 0.75, b = 0.35, a = 0.9},
    }),
    make_corrosive_cloud_visual(),
    make_corrosive_cloud("ei-corrosive-rocket-cloud", 12.5),
    make_corrosive_cloud("ei-dw-corrosive-rocket-cloud", 12.5),

    make_sticker("ei-corrosive-rocket-sticker", {
        tint = {r = 0.45, g = 1.0, b = 0.42, a = 0.98},
        duration_in_ticks = 8 * 60,
        target_movement_modifier = 0.45,
        damage_per_tick = {
            amount = 12.5 / 60,
            type = "acid",
        },
    }),
    make_sticker("ei-dw-corrosive-rocket-sticker", {
        tint = {r = 0.45, g = 1.0, b = 0.42, a = 0.98},
        duration_in_ticks = 8 * 60,
        target_movement_modifier = 0.45,
        damage_per_tick = {
            amount = 12.5 / 60,
            type = "acid",
        },
    }),
    make_sticker("ei-cryo-rocket-sticker", {
        tint = {r = 0.7, g = 0.95, b = 1.0, a = 0.95},
        duration_in_ticks = 8 * 60,
        target_movement_modifier = 0.25,
        damage_per_tick = {
            amount = 3 / 60,
            type = "cold",
        },
    }),

    clone_explosion("ei-siege-rocket-explosion", "big-explosion", {
        tint = {r = 0.95, g = 0.82, b = 0.48, a = 0.92},
        scale = 1.35,
        light = {
            intensity = 0.72,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 1.0, g = 0.72, b = 0.35},
            size = 20,
        },
        smoke = "ei-siege-rocket-smoke",
        smoke_count = 3,
        sound = sound_variations(0.95),
        order = "c-a-b",
    }),
    clone_explosion("ei-corrosive-rocket-explosion", "big-explosion", {
        tint = {r = 0.4, g = 1.0, b = 0.35, a = 0.9},
        scale = 1.2,
        light = {
            intensity = 0.62,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 0.35, g = 1.0, b = 0.35},
            size = 19,
        },
        smoke = "ei-corrosive-rocket-smoke",
        smoke_count = 3,
        smoke_slow_down_factor = 0.95,
        sound = sound_variations(0.85),
        order = "c-a-c",
    }),
    clone_explosion("ei-cryo-rocket-explosion", "big-cold-explosion", {
        light = {
            intensity = 0.6,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 0.75, g = 0.95, b = 1.0},
            size = 17,
        },
        smoke = "ei-cryo-rocket-smoke",
        smoke_count = 3,
        smoke_slow_down_factor = 0.95,
        order = "c-a-d",
    }),
    clone_explosion("ei-hand-explosive-rocket-explosion", "big-explosion", {
        light = {
            intensity = 0.6,
            color = {r = 1.0, g = 0.85, b = 0.7},
            size = 20,
        },
        order = "c-a-b",
    }),
    clone_explosion("ei-atomic-u235-center-explosion", "nuke-explosion", {
        scale = 0.8,
        shift = {0.015625, -3.828125},
        light = {
            intensity = 0.95,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 1.0, g = 0.92, b = 0.6},
            size = 120,
        },
        smoke = "ei-atomic-rocket-smoke",
        smoke_count = 4,
        remove_created_effect = true,
        scale_out_duration = 50,
        scale_end = 0.9,
        order = "c-a-e",
    }),
    make_explosion("ei-atomic-rocket-explosion", {
        tint = {r = 1.0, g = 0.96, b = 0.65, a = 0.98},
        light = {
            intensity = 1.15,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 1.0, g = 0.9, b = 0.55},
            size = 160,
        },
        smoke = "ei-atomic-rocket-smoke",
        smoke_count = 4,
        smoke_slow_down_factor = 0.92,
        scale_out_duration = 60,
        scale_end = 0.95,
        sound = sound_variations(1.05),
        order = "c-a-e",
    }),

    make_stream("ei-dw-deer-siege-stream", {
        tint = {r = 1.0, g = 0.78, b = 0.35, a = 0.75},
        particle_buffer_size = 100,
        particle_spawn_interval = 2,
        particle_spawn_timeout = 18,
        particle_vertical_acceleration = 0.006,
        particle_horizontal_speed = 0.24,
        particle_horizontal_speed_deviation = 0.006,
        particle_start_alpha = 1.0,
        particle_end_alpha = 0.18,
        particle_start_scale = 0.22,
        particle_end_scale = 1.75,
        smoke_sources = {
            {
                name = "ei-siege-rocket-smoke",
                frequency = 0.02,
                position = {0.0, 0},
                starting_frame_deviation = 60,
            },
        },
        action = {
            {
                type = "area",
                radius = 4.5,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "damage",
                            damage = {amount = 42, type = "explosion"},
                            apply_damage_to_trees = true,
                        },
                    },
                },
            },
        },
    }),
    make_stream("ei-dw-deer-corrosive-stream", {
        tint = {r = 0.35, g = 1.0, b = 0.35, a = 0.75},
        particle_buffer_size = 90,
        particle_spawn_interval = 2,
        particle_spawn_timeout = 16,
        particle_vertical_acceleration = 0.0055,
        particle_horizontal_speed = 0.22,
        particle_horizontal_speed_deviation = 0.005,
        particle_start_alpha = 1.0,
        particle_end_alpha = 0.2,
        particle_start_scale = 0.2,
        particle_end_scale = 1.55,
        smoke_sources = {
            {
                name = "ei-corrosive-rocket-smoke",
                frequency = 0.04,
                position = {0.0, 0},
                starting_frame_deviation = 60,
            },
        },
        action = {
            {
                type = "area",
                radius = 3.5,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-sticker",
                            sticker = "ei-corrosive-rocket-sticker",
                            show_in_tooltip = true,
                        },
                        {
                            type = "damage",
                            damage = {amount = 9, type = "acid"},
                            apply_damage_to_trees = false,
                        },
                    },
                },
            },
        },
    }),
    make_stream("ei-dw-deer-cryo-stream", {
        tint = {r = 0.7, g = 0.95, b = 1.0, a = 0.75},
        particle_buffer_size = 90,
        particle_spawn_interval = 2,
        particle_spawn_timeout = 16,
        particle_vertical_acceleration = 0.0055,
        particle_horizontal_speed = 0.22,
        particle_horizontal_speed_deviation = 0.005,
        particle_start_alpha = 1.0,
        particle_end_alpha = 0.18,
        particle_start_scale = 0.2,
        particle_end_scale = 1.55,
        smoke_sources = {
            {
                name = "ei-cryo-rocket-smoke",
                frequency = 0.04,
                position = {0.0, 0},
                starting_frame_deviation = 60,
            },
        },
        action = {
            {
                type = "area",
                radius = 3.5,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "create-sticker",
                            sticker = "ei-cryo-rocket-sticker",
                            show_in_tooltip = true,
                        },
                        {
                            type = "damage",
                            damage = {amount = 7, type = "cold"},
                            apply_damage_to_trees = false,
                        },
                    },
                },
            },
        },
    }),
})

if #optional_stickers > 0 then
    data:extend(optional_stickers)
end
