local spark_sheet = ei_graphics_3_path .. "graphics/entities/acid-turret/acid-flame/spark.png"
local smoke_sheet = "__base__/graphics/entity/fire-smoke/fire-smoke.png"
local smoke_glow_sheet = "__base__/graphics/entity/fire-smoke/fire-smoke-glow.png"
local stream_particle_sheet = "__base__/graphics/entity/flamethrower-fire-stream/flamethrower-explosion.png"

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
        if opts.blend_mode ~= nil then
            root.blend_mode = opts.blend_mode
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
        return nil
    end

    local explosion = table.deepcopy(source)
    explosion.name = name
    explosion.flags = {"not-on-map"}
    explosion.subgroup = "explosions"
    explosion.order = "c-a-a"

    if opts.light ~= nil then
        explosion.light = opts.light
    end
    if opts.sound == false then
        explosion.sound = nil
    elseif opts.sound ~= nil then
        explosion.sound = opts.sound
    end
    if opts.smoke == false then
        explosion.smoke = nil
    elseif opts.smoke ~= nil then
        explosion.smoke = opts.smoke
    end
    if opts.smoke_count ~= nil then
        explosion.smoke_count = opts.smoke_count
    end
    if opts.smoke_slow_down_factor ~= nil then
        explosion.smoke_slow_down_factor = opts.smoke_slow_down_factor
    end
    if opts.created_effect == false then
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

    apply_animation_overrides(explosion.animations, opts)
    return explosion
end

local function make_smoke(name, opts)
    opts = opts or {}

    return {
        type = "trivial-smoke",
        name = name,
        flags = {"not-on-map"},
        color = opts.color or {r = 0.75, g = 0.8, b = 0.85, a = 0.2},
        start_scale = opts.start_scale or 0.22,
        end_scale = opts.end_scale or 0.08,
        duration = opts.duration or 45,
        spread_duration = opts.spread_duration or 80,
        fade_away_duration = opts.fade_away_duration or 24,
        fade_in_duration = opts.fade_in_duration or 3,
        animation = {
            filename = smoke_sheet,
            flags = {"always-compressed"},
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            axially_symmetrical = false,
            direction_count = 1,
            shift = {-0.265625, -0.09375},
            priority = "high",
            animation_speed = opts.animation_speed or 0.25,
            tint = opts.tint or opts.color,
        },
        glow_animation = {
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
            animation_speed = opts.glow_animation_speed or opts.animation_speed or 0.25,
            tint = opts.glow_tint or opts.tint or opts.color,
        },
        glow_fade_away_duration = opts.glow_fade_away_duration or 45,
    }
end

local function make_sticker(name, opts)
    opts = opts or {}

    local animation = {
        filename = opts.filename or spark_sheet,
        line_length = opts.line_length or 5,
        width = opts.width or 64,
        height = opts.height or 64,
        frame_count = opts.frame_count or 5,
        axially_symmetrical = false,
        direction_count = opts.direction_count or 1,
        blend_mode = opts.blend_mode or "normal",
        animation_speed = opts.animation_speed or 0.5,
        scale = opts.scale or 0.5,
        tint = opts.tint or {r = 1, g = 1, b = 1, a = 1},
        shift = opts.shift or {-0.078125, -1.8125},
    }

    if opts.draw_as_glow ~= nil then
        animation.draw_as_glow = opts.draw_as_glow
    end

    return {
        type = "sticker",
        name = name,
        flags = {"not-on-map"},
        animation = animation,
        duration_in_ticks = opts.duration_in_ticks,
        target_movement_modifier = opts.target_movement_modifier,
        damage_per_tick = opts.damage_per_tick,
    }
end

local function make_smoke_effect(opts)
    return {
        type = "create-trivial-smoke",
        smoke_name = opts.smoke_name,
        repeat_count = opts.repeat_count or 1,
        offset_deviation = opts.offset_deviation or {{-0.28, -0.28}, {0.28, 0.28}},
        speed_from_center = opts.speed_from_center or 0.012,
        speed_from_center_deviation = opts.speed_from_center_deviation or 0.008,
        initial_height = opts.initial_height or 0,
        initial_height_deviation = opts.initial_height_deviation or 0.02,
    }
end

local function make_source_effects(family)
    if not family.source_effect_name then
        return nil
    end

    return {
        {
            type = "create-explosion",
            entity_name = family.source_effect_name,
        },
    }
end

local function make_impact_created_effect(family)
    local target_effects = {}
    local impact_smokes = family.impact_smokes or {
        {
            smoke_name = family.smoke_name,
            repeat_count = family.smoke_repeat_count or 2,
            speed_from_center = family.smoke_speed or 0.012,
            speed_from_center_deviation = family.smoke_speed_deviation or 0.008,
        },
    }

    for _, smoke in ipairs(impact_smokes) do
        target_effects[#target_effects + 1] = make_smoke_effect(smoke)
    end

    if family.scorchmark then
        target_effects[#target_effects + 1] = {
            type = "create-entity",
            entity_name = "medium-scorchmark",
            check_buildability = true,
        }
    end

    return {
        type = "direct",
        action_delivery = {
            type = "instant",
            target_effects = target_effects,
        },
    }
end

local function add_if_present(target, prototype)
    if prototype then
        target[#target + 1] = prototype
    end
end

local families = {
    {
        key = "compound",
        source_tint = {r = 0.32, g = 0.96, b = 1.0, a = 0.96},
        hit_tint = {r = 0.84, g = 0.98, b = 1.0, a = 0.95},
        source_light = {intensity = 0.58, size = 18, color = {r = 0.34, g = 0.92, b = 1.0}},
        impact_light = {intensity = 0.68, size = 28, color = {r = 0.84, g = 0.96, b = 1.0}},
        source_scale = 0.72,
        source_animation_speed = 0.46,
        hit_scale = 0.95,
        hit_animation_speed = 0.32,
        hit_scale_out_duration = 16,
        hit_scale_end = 0.78,
        smoke = {
            color = {r = 0.76, g = 0.96, b = 1.0, a = 0.14},
            tint = {r = 0.78, g = 0.98, b = 1.0, a = 0.2},
            glow_tint = {r = 1.0, g = 0.9, b = 0.55, a = 0.14},
            start_scale = 0.22,
            end_scale = 0.07,
            duration = 34,
            spread_duration = 68,
            fade_away_duration = 22,
            animation_speed = 0.28,
        },
        smoke_repeat_count = 2,
        smoke_speed = 0.014,
        smoke_speed_deviation = 0.008,
        impact_smokes = {
            {
                repeat_count = 2,
                offset_deviation = {{-0.22, -0.22}, {0.22, 0.22}},
                speed_from_center = 0.014,
                speed_from_center_deviation = 0.008,
                initial_height = 0.04,
                initial_height_deviation = 0.02,
            },
            {
                suffix = "afterglow",
                repeat_count = 1,
                offset_deviation = {{-0.18, -0.18}, {0.18, 0.18}},
                speed_from_center = 0.006,
                speed_from_center_deviation = 0.004,
                smoke = {
                    color = {r = 0.98, g = 0.88, b = 0.54, a = 0.12},
                    tint = {r = 1.0, g = 0.92, b = 0.64, a = 0.16},
                    glow_tint = {r = 1.0, g = 0.96, b = 0.78, a = 0.12},
                    start_scale = 0.16,
                    end_scale = 0.05,
                    duration = 26,
                    spread_duration = 42,
                    fade_away_duration = 16,
                    animation_speed = 0.34,
                },
            },
        },
        sticker = {
            filename = spark_sheet,
            tint = {r = 0.8, g = 0.98, b = 1.0, a = 0.94},
            blend_mode = "additive",
            animation_speed = 0.8,
            scale = 0.72,
            shift = {-0.046875, -1.59375},
            duration_in_ticks = 240,
            target_movement_modifier = 0.7,
            damage_per_tick = {amount = 5 / 60, type = "electric"},
            draw_as_glow = true,
        },
        accent_sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 1.0, g = 0.92, b = 0.62, a = 0.2},
            blend_mode = "additive",
            animation_speed = 0.22,
            scale = 0.13,
            shift = {-0.265625, -0.15625},
            duration_in_ticks = 102,
            draw_as_glow = true,
        },
    },
    {
        key = "corrosive",
        source_tint = {r = 0.94, g = 1.0, b = 0.28, a = 0.96},
        hit_tint = {r = 0.4, g = 0.92, b = 0.28, a = 0.95},
        source_light = {intensity = 0.5, size = 16, color = {r = 0.92, g = 1.0, b = 0.32}},
        impact_light = {intensity = 0.62, size = 27, color = {r = 0.38, g = 0.95, b = 0.28}},
        source_scale = 0.66,
        source_animation_speed = 0.34,
        hit_scale = 0.9,
        hit_animation_speed = 0.28,
        hit_scale_out_duration = 18,
        hit_scale_end = 0.74,
        smoke = {
            color = {r = 0.4, g = 0.88, b = 0.28, a = 0.18},
            tint = {r = 0.48, g = 1.0, b = 0.36, a = 0.22},
            glow_tint = {r = 0.62, g = 1.0, b = 0.42, a = 0.12},
            start_scale = 0.24,
            end_scale = 0.1,
            duration = 54,
            spread_duration = 102,
            fade_away_duration = 32,
            animation_speed = 0.22,
        },
        smoke_repeat_count = 3,
        smoke_speed = 0.011,
        smoke_speed_deviation = 0.008,
        impact_smokes = {
            {
                repeat_count = 2,
                offset_deviation = {{-0.34, -0.34}, {0.34, 0.34}},
                speed_from_center = 0.011,
                speed_from_center_deviation = 0.008,
                initial_height = 0.01,
                initial_height_deviation = 0.02,
            },
            {
                suffix = "mist",
                repeat_count = 2,
                speed_from_center = 0.006,
                speed_from_center_deviation = 0.004,
                smoke = {
                    color = {r = 0.58, g = 0.94, b = 0.24, a = 0.14},
                    tint = {r = 0.72, g = 1.0, b = 0.38, a = 0.18},
                    glow_tint = {r = 0.8, g = 1.0, b = 0.5, a = 0.1},
                    start_scale = 0.22,
                    end_scale = 0.09,
                    duration = 64,
                    spread_duration = 118,
                    fade_away_duration = 36,
                    animation_speed = 0.18,
                },
            },
        },
        sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 0.56, g = 1.0, b = 0.38, a = 0.42},
            blend_mode = "normal",
            animation_speed = 0.18,
            scale = 0.18,
            shift = {-0.265625, -0.171875},
            duration_in_ticks = 300,
            target_movement_modifier = 0.7,
            damage_per_tick = {amount = 4 / 60, type = "acid"},
        },
        accent_sticker = {
            filename = spark_sheet,
            tint = {r = 0.82, g = 1.0, b = 0.48, a = 0.68},
            blend_mode = "additive",
            animation_speed = 0.42,
            scale = 0.38,
            shift = {-0.03125, -1.578125},
            duration_in_ticks = 96,
            draw_as_glow = true,
        },
    },
    {
        key = "cryo",
        source_tint = {r = 0.72, g = 0.9, b = 1.0, a = 0.94},
        hit_tint = {r = 0.68, g = 0.93, b = 1.0, a = 0.95},
        source_light = {intensity = 0.4, size = 17, color = {r = 0.76, g = 0.92, b = 1.0}},
        impact_light = {intensity = 0.58, size = 26, color = {r = 0.78, g = 0.96, b = 1.0}},
        impact_base_explosion = "big-cold-explosion",
        source_scale = 0.8,
        source_animation_speed = 0.26,
        hit_scale = 0.5,
        hit_animation_speed = 0.26,
        hit_scale_out_duration = 18,
        hit_scale_end = 0.74,
        smoke = {
            color = {r = 0.76, g = 0.95, b = 1.0, a = 0.16},
            tint = {r = 0.86, g = 0.98, b = 1.0, a = 0.2},
            glow_tint = {r = 0.86, g = 0.98, b = 1.0, a = 0.16},
            start_scale = 0.24,
            end_scale = 0.08,
            duration = 68,
            spread_duration = 124,
            fade_away_duration = 36,
            animation_speed = 0.18,
        },
        smoke_repeat_count = 2,
        smoke_speed = 0.006,
        smoke_speed_deviation = 0.004,
        impact_smokes = {
            {
                repeat_count = 2,
                offset_deviation = {{-0.32, -0.32}, {0.32, 0.32}},
                speed_from_center = 0.005,
                speed_from_center_deviation = 0.003,
                initial_height = 0.04,
                initial_height_deviation = 0.02,
            },
            {
                suffix = "vapor",
                repeat_count = 2,
                speed_from_center = 0.003,
                speed_from_center_deviation = 0.002,
                smoke = {
                    color = {r = 0.92, g = 0.98, b = 1.0, a = 0.12},
                    tint = {r = 0.96, g = 1.0, b = 1.0, a = 0.16},
                    glow_tint = {r = 0.88, g = 0.98, b = 1.0, a = 0.1},
                    start_scale = 0.3,
                    end_scale = 0.1,
                    duration = 76,
                    spread_duration = 136,
                    fade_away_duration = 40,
                    animation_speed = 0.14,
                },
            },
        },
        sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 0.9, g = 0.98, b = 1.0, a = 0.44},
            blend_mode = "additive",
            animation_speed = 0.16,
            scale = 0.18,
            shift = {-0.265625, -0.171875},
            duration_in_ticks = 300,
            target_movement_modifier = 0.5,
            damage_per_tick = {amount = 3 / 60, type = "cold"},
            draw_as_glow = true,
        },
        accent_sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 0.94, g = 1.0, b = 1.0, a = 0.24},
            blend_mode = "additive",
            animation_speed = 0.14,
            scale = 0.12,
            shift = {-0.265625, -0.15625},
            duration_in_ticks = 108,
            draw_as_glow = true,
        },
    },
    {
        key = "oxyfluoride",
        source_tint = {r = 1.0, g = 0.82, b = 0.34, a = 0.98},
        hit_tint = {r = 1.0, g = 0.86, b = 0.45, a = 0.95},
        source_light = {intensity = 0.9, size = 21, color = {r = 1.0, g = 0.9, b = 0.56}},
        impact_light = {intensity = 0.74, size = 30, color = {r = 1.0, g = 0.88, b = 0.52}},
        impact_base_explosion = "big-explosion",
        source_scale = 0.82,
        source_animation_speed = 0.88,
        hit_scale = 0.5,
        hit_animation_speed = 0.46,
        hit_scale_out_duration = 12,
        hit_scale_end = 0.88,
        scorchmark = true,
        smoke = {
            color = {r = 1.0, g = 0.84, b = 0.42, a = 0.18},
            tint = {r = 1.0, g = 0.88, b = 0.54, a = 0.24},
            glow_tint = {r = 1.0, g = 0.96, b = 0.72, a = 0.16},
            start_scale = 0.26,
            end_scale = 0.1,
            duration = 42,
            spread_duration = 84,
            fade_away_duration = 26,
            animation_speed = 0.34,
        },
        smoke_repeat_count = 3,
        smoke_speed = 0.02,
        smoke_speed_deviation = 0.012,
        impact_smokes = {
            {
                repeat_count = 2,
                offset_deviation = {{-0.18, -0.18}, {0.18, 0.18}},
                speed_from_center = 0.022,
                speed_from_center_deviation = 0.012,
                initial_height = 0.08,
                initial_height_deviation = 0.03,
            },
            {
                suffix = "whiteout",
                repeat_count = 1,
                speed_from_center = 0.014,
                speed_from_center_deviation = 0.008,
                smoke = {
                    color = {r = 1.0, g = 0.96, b = 0.76, a = 0.12},
                    tint = {r = 1.0, g = 0.98, b = 0.86, a = 0.16},
                    glow_tint = {r = 1.0, g = 1.0, b = 0.92, a = 0.12},
                    start_scale = 0.18,
                    end_scale = 0.05,
                    duration = 22,
                    spread_duration = 40,
                    fade_away_duration = 14,
                    animation_speed = 0.42,
                },
            },
        },
        sticker = {
            filename = stream_particle_sheet,
            line_length = 6,
            width = 124,
            height = 108,
            frame_count = 36,
            tint = {r = 1.0, g = 0.92, b = 0.62, a = 0.92},
            blend_mode = "additive",
            animation_speed = 0.8,
            scale = 0.34,
            shift = {0, -0.75},
            duration_in_ticks = 240,
            target_movement_modifier = 0.85,
            damage_per_tick = {amount = 6 / 60, type = "fire"},
            draw_as_glow = true,
        },
        accent_sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 1.0, g = 0.98, b = 0.86, a = 0.22},
            blend_mode = "additive",
            animation_speed = 0.28,
            scale = 0.14,
            shift = {-0.265625, -0.140625},
            duration_in_ticks = 84,
            draw_as_glow = true,
        },
    },
    {
        key = "morphium",
        source_tint = {r = 0.92, g = 0.22, b = 1.0, a = 0.94},
        hit_tint = {r = 0.3, g = 0.02, b = 0.48, a = 0.92},
        source_light = {intensity = 0.38, size = 15, color = {r = 0.86, g = 0.28, b = 1.0}},
        impact_light = {intensity = 0.48, size = 22, color = {r = 0.58, g = 0.16, b = 0.76}},
        source_scale = 0.7,
        source_animation_speed = 0.36,
        hit_scale = 0.88,
        hit_animation_speed = 0.24,
        hit_scale_out_duration = 20,
        hit_scale_end = 0.7,
        smoke = {
            color = {r = 0.24, g = 0.06, b = 0.34, a = 0.16},
            tint = {r = 0.34, g = 0.08, b = 0.46, a = 0.2},
            glow_tint = {r = 0.64, g = 0.18, b = 0.78, a = 0.12},
            start_scale = 0.28,
            end_scale = 0.1,
            duration = 82,
            spread_duration = 150,
            fade_away_duration = 40,
            animation_speed = 0.16,
        },
        smoke_repeat_count = 2,
        smoke_speed = 0.008,
        smoke_speed_deviation = 0.005,
        impact_smokes = {
            {
                repeat_count = 2,
                offset_deviation = {{-0.2, -0.2}, {0.2, 0.2}},
                speed_from_center = 0.008,
                speed_from_center_deviation = 0.005,
                initial_height = 0,
                initial_height_deviation = 0.015,
            },
            {
                suffix = "bruise",
                repeat_count = 1,
                speed_from_center = 0.004,
                speed_from_center_deviation = 0.003,
                smoke = {
                    color = {r = 0.42, g = 0.08, b = 0.56, a = 0.14},
                    tint = {r = 0.6, g = 0.16, b = 0.72, a = 0.18},
                    glow_tint = {r = 0.82, g = 0.3, b = 0.94, a = 0.1},
                    start_scale = 0.22,
                    end_scale = 0.08,
                    duration = 96,
                    spread_duration = 160,
                    fade_away_duration = 44,
                    animation_speed = 0.14,
                },
            },
        },
        sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 0.42, g = 0.1, b = 0.54, a = 0.7},
            blend_mode = "normal",
            animation_speed = 0.18,
            scale = 0.26,
            shift = {-0.265625, -0.203125},
            duration_in_ticks = 420,
            target_movement_modifier = 0.65,
            damage_per_tick = {amount = 5 / 60, type = "ei-morphium"},
        },
        accent_sticker = {
            filename = spark_sheet,
            tint = {r = 0.86, g = 0.26, b = 0.96, a = 0.68},
            blend_mode = "additive",
            animation_speed = 0.28,
            scale = 0.46,
            shift = {-0.015625, -1.46875},
            duration_in_ticks = 180,
            draw_as_glow = true,
        },
    },
    {
        key = "hexafluoride",
        source_tint = {r = 0.22, g = 0.94, b = 0.72, a = 0.95},
        hit_tint = {r = 0.3, g = 0.86, b = 0.62, a = 0.95},
        source_light = {intensity = 0.52, size = 17, color = {r = 0.34, g = 0.96, b = 0.8}},
        impact_light = {intensity = 0.64, size = 24, color = {r = 0.34, g = 0.92, b = 0.7}},
        source_scale = 0.7,
        source_animation_speed = 0.5,
        hit_scale = 0.94,
        hit_animation_speed = 0.34,
        hit_scale_out_duration = 13,
        hit_scale_end = 0.82,
        scorchmark = true,
        smoke = {
            color = {r = 0.32, g = 0.86, b = 0.68, a = 0.16},
            tint = {r = 0.42, g = 0.94, b = 0.74, a = 0.18},
            glow_tint = {r = 0.64, g = 1.0, b = 0.86, a = 0.1},
            start_scale = 0.2,
            end_scale = 0.08,
            duration = 46,
            spread_duration = 74,
            fade_away_duration = 24,
            animation_speed = 0.24,
        },
        smoke_repeat_count = 2,
        smoke_speed = 0.014,
        smoke_speed_deviation = 0.008,
        impact_smokes = {
            {
                repeat_count = 1,
                offset_deviation = {{-0.12, -0.12}, {0.12, 0.12}},
                speed_from_center = 0.016,
                speed_from_center_deviation = 0.009,
                initial_height = 0.02,
                initial_height_deviation = 0.015,
            },
            {
                suffix = "etch",
                repeat_count = 1,
                offset_deviation = {{-0.16, -0.16}, {0.16, 0.16}},
                speed_from_center = 0.02,
                speed_from_center_deviation = 0.01,
                smoke = {
                    color = {r = 0.58, g = 1.0, b = 0.82, a = 0.12},
                    tint = {r = 0.64, g = 1.0, b = 0.88, a = 0.16},
                    glow_tint = {r = 0.82, g = 1.0, b = 0.94, a = 0.12},
                    start_scale = 0.14,
                    end_scale = 0.04,
                    duration = 26,
                    spread_duration = 38,
                    fade_away_duration = 16,
                    animation_speed = 0.34,
                },
            },
        },
        sticker = {
            filename = spark_sheet,
            tint = {r = 0.44, g = 0.94, b = 0.74, a = 0.88},
            blend_mode = "additive",
            animation_speed = 0.6,
            scale = 0.57,
            shift = {-0.0625, -1.671875},
            duration_in_ticks = 360,
            target_movement_modifier = 0.75,
            damage_per_tick = {amount = 5 / 60, type = "acid"},
            draw_as_glow = true,
        },
        accent_sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 0.74, g = 1.0, b = 0.88, a = 0.18},
            blend_mode = "additive",
            animation_speed = 0.2,
            scale = 0.12,
            shift = {-0.265625, -0.140625},
            duration_in_ticks = 120,
            draw_as_glow = true,
        },
    },
    {
        key = "arc",
        source_tint = {r = 0.32, g = 0.42, b = 1.0, a = 0.98},
        hit_tint = {r = 0.34, g = 0.46, b = 1.0, a = 0.95},
        source_light = {intensity = 0.84, size = 17, color = {r = 0.46, g = 0.34, b = 1.0}},
        impact_light = {intensity = 0.72, size = 30, color = {r = 0.62, g = 0.74, b = 1.0}},
        source_scale = 0.62,
        source_animation_speed = 0.9,
        hit_scale = 0.98,
        hit_animation_speed = 0.54,
        hit_scale_out_duration = 10,
        hit_scale_end = 0.9,
        smoke = {
            color = {r = 0.42, g = 0.56, b = 1.0, a = 0.12},
            tint = {r = 0.5, g = 0.64, b = 1.0, a = 0.16},
            glow_tint = {r = 0.74, g = 0.82, b = 1.0, a = 0.14},
            start_scale = 0.18,
            end_scale = 0.06,
            duration = 28,
            spread_duration = 48,
            fade_away_duration = 16,
            animation_speed = 0.4,
        },
        smoke_repeat_count = 1,
        smoke_speed = 0.02,
        smoke_speed_deviation = 0.012,
        impact_smokes = {
            {
                repeat_count = 1,
                offset_deviation = {{-0.1, -0.1}, {0.1, 0.1}},
                speed_from_center = 0.022,
                speed_from_center_deviation = 0.012,
                initial_height = 0.08,
                initial_height_deviation = 0.03,
            },
            {
                suffix = "aftershock",
                repeat_count = 1,
                offset_deviation = {{-0.14, -0.14}, {0.14, 0.14}},
                speed_from_center = 0.028,
                speed_from_center_deviation = 0.014,
                smoke = {
                    color = {r = 0.66, g = 0.76, b = 1.0, a = 0.1},
                    tint = {r = 0.78, g = 0.84, b = 1.0, a = 0.14},
                    glow_tint = {r = 0.9, g = 0.92, b = 1.0, a = 0.12},
                    start_scale = 0.1,
                    end_scale = 0.03,
                    duration = 18,
                    spread_duration = 26,
                    fade_away_duration = 10,
                    animation_speed = 0.6,
                },
            },
        },
        sticker = {
            filename = spark_sheet,
            tint = {r = 0.46, g = 0.6, b = 1.0, a = 0.96},
            blend_mode = "additive",
            animation_speed = 1.24,
            scale = 0.54,
            shift = {-0.03125, -1.5},
            duration_in_ticks = 150,
            target_movement_modifier = 0.35,
            damage_per_tick = {amount = 6 / 60, type = "electric"},
            draw_as_glow = true,
        },
        accent_sticker = {
            filename = stream_particle_sheet,
            line_length = 6,
            width = 124,
            height = 108,
            frame_count = 36,
            tint = {r = 0.74, g = 0.84, b = 1.0, a = 0.76},
            blend_mode = "additive",
            animation_speed = 0.58,
            scale = 0.18,
            shift = {0, -0.75},
            duration_in_ticks = 54,
            draw_as_glow = true,
        },
    },
    {
        key = "neutron",
        source_tint = {r = 0.88, g = 0.95, b = 1.0, a = 0.9},
        hit_tint = {r = 0.7, g = 0.88, b = 1.0, a = 0.95},
        source_light = {intensity = 0.62, size = 18, color = {r = 0.72, g = 0.86, b = 1.0}},
        impact_light = {intensity = 0.8, size = 32, color = {r = 0.76, g = 0.9, b = 1.0}},
        impact_base_explosion = "big-explosion",
        source_scale = 0.68,
        source_animation_speed = 0.42,
        hit_scale = 0.46,
        hit_animation_speed = 0.3,
        hit_scale_out_duration = 16,
        hit_scale_end = 0.76,
        scorchmark = true,
        smoke = {
            color = {r = 0.72, g = 0.88, b = 1.0, a = 0.1},
            tint = {r = 0.78, g = 0.9, b = 1.0, a = 0.14},
            glow_tint = {r = 0.9, g = 0.96, b = 1.0, a = 0.12},
            start_scale = 0.22,
            end_scale = 0.08,
            duration = 58,
            spread_duration = 108,
            fade_away_duration = 32,
            animation_speed = 0.18,
        },
        smoke_repeat_count = 2,
        smoke_speed = 0.01,
        smoke_speed_deviation = 0.006,
        impact_smokes = {
            {
                repeat_count = 1,
                offset_deviation = {{-0.18, -0.18}, {0.18, 0.18}},
                speed_from_center = 0.012,
                speed_from_center_deviation = 0.006,
                initial_height = 0.04,
                initial_height_deviation = 0.02,
            },
            {
                suffix = "shadow",
                repeat_count = 1,
                speed_from_center = 0.002,
                speed_from_center_deviation = 0.0015,
                smoke = {
                    color = {r = 0.08, g = 0.12, b = 0.2, a = 0.1},
                    tint = {r = 0.18, g = 0.22, b = 0.32, a = 0.14},
                    glow_tint = {r = 0.48, g = 0.58, b = 0.72, a = 0.08},
                    start_scale = 0.26,
                    end_scale = 0.1,
                    duration = 72,
                    spread_duration = 128,
                    fade_away_duration = 38,
                    animation_speed = 0.12,
                },
            },
        },
        sticker = {
            filename = spark_sheet,
            tint = {r = 0.84, g = 0.94, b = 1.0, a = 0.9},
            blend_mode = "additive",
            animation_speed = 0.34,
            scale = 0.62,
            shift = {-0.015625, -1.5625},
            duration_in_ticks = 360,
            target_movement_modifier = 0.85,
            damage_per_tick = {amount = 7 / 60, type = "ei-radiological"},
            draw_as_glow = true,
        },
        accent_sticker = {
            filename = smoke_sheet,
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            tint = {r = 0.18, g = 0.22, b = 0.3, a = 0.22},
            blend_mode = "normal",
            animation_speed = 0.12,
            scale = 0.18,
            shift = {-0.265625, -0.15625},
            duration_in_ticks = 180,
        },
    },
}

local prototypes = {}
local source_effects_by_ammo_name = {}

for _, family in ipairs(families) do
    family.smoke_name = "ei-" .. family.key .. "-ammo-smoke"
    family.source_effect_name = "ei-" .. family.key .. "-ammo-source-flash"

    prototypes[#prototypes + 1] = make_smoke(family.smoke_name, family.smoke)
    if family.impact_smokes then
        for index, smoke in ipairs(family.impact_smokes) do
            if smoke.smoke then
                smoke.smoke_name = "ei-" .. family.key .. "-ammo-impact-smoke-" .. (smoke.suffix or index)
                prototypes[#prototypes + 1] = make_smoke(smoke.smoke_name, smoke.smoke)
            elseif not smoke.smoke_name then
                smoke.smoke_name = family.smoke_name
            end
        end
    end
    add_if_present(prototypes, clone_explosion(
        family.source_effect_name,
        "explosion-gunshot",
        {
            tint = family.source_tint,
            scale = family.source_scale,
            animation_speed = family.source_animation_speed,
            smoke = false,
            smoke_count = 0,
            light = family.source_light,
            created_effect = false,
            sound = false,
        }
    ))

    source_effects_by_ammo_name["ei-" .. family.key .. "-ammo"] = make_source_effects(family)

    add_if_present(prototypes, clone_explosion(
        "ei-" .. family.key .. "-ammo-impact-burst",
        family.impact_base_explosion or "explosion-hit",
        {
            tint = family.hit_tint,
            scale = family.hit_scale,
            animation_speed = family.hit_animation_speed or 0.38,
            smoke_count = 0,
            smoke = "smoke-fast",
            light = family.impact_light or family.light,
            created_effect = make_impact_created_effect(family),
            scale_out_duration = family.hit_scale_out_duration or 14,
            scale_end = family.hit_scale_end or 0.82,
            sound = false,
        }
    ))

    prototypes[#prototypes + 1] = make_sticker(
        "ei-" .. family.key .. "-ammo-sticker",
        family.sticker
    )
    if family.accent_sticker then
        prototypes[#prototypes + 1] = make_sticker(
            "ei-" .. family.key .. "-ammo-accent-sticker",
            family.accent_sticker
        )
    end
end

data:extend(prototypes)

return {
    source_effects_by_ammo_name = source_effects_by_ammo_name,
}
