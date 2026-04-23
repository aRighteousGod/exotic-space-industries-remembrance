local util = require("util")

local function deepcopy_light(light, color, size_multiplier)
    if not light then
        return nil
    end

    local copied = util.table.deepcopy(light)
    if color then
        copied.color = color
    end
    if size_multiplier and copied.size then
        copied.size = copied.size * size_multiplier
    end

    return copied
end

local function make_rupture_fire(name, lifetime, damage, light_color, light_size_multiplier, options)
    options = options or {}

    local fire = util.table.deepcopy(data.raw.fire["fire-flame"])
    fire.name = name
    fire.initial_lifetime = lifetime
    fire.damage_per_tick = damage
    fire.light = deepcopy_light(fire.light, light_color, light_size_multiplier)

    if options.platform_safe then
        fire.tree_dying_factor = nil
        fire.spawn_entity = nil
        fire.maximum_spread_count = 0
        fire.spread_delay = options.spread_delay or (60 * 60)
        fire.spread_delay_deviation = 0
        fire.lifetime_increase_by = 0
        fire.lifetime_increase_cooldown = 1
        fire.maximum_lifetime = options.maximum_lifetime or lifetime
        fire.burnt_patch_lifetime = 0
        fire.emissions_per_second = nil
    elseif data.raw.fire["fire-flame-on-tree"] then
        fire.tree_dying_factor = data.raw.fire["fire-flame-on-tree"].tree_dying_factor
    end

    return fire
end

local function make_rupture_smoke(name, color, options)
    return {
        type = "trivial-smoke",
        name = name,
        flags = {"not-on-map"},
        show_when_smoke_off = true,
        duration = options.duration,
        fade_in_duration = options.fade_in_duration or 0,
        fade_away_duration = options.fade_away_duration,
        spread_duration = options.spread_duration,
        start_scale = options.start_scale,
        end_scale = options.end_scale,
        color = color,
        cyclic = true,
        affected_by_wind = options.affected_by_wind ~= false,
        animation = {
            filename = "__base__/graphics/entity/fire-smoke/fire-smoke.png",
            flags = {"always-compressed"},
            line_length = 8,
            width = 253,
            height = 210,
            frame_count = 60,
            axially_symmetrical = false,
            direction_count = 1,
            shift = {-0.265625, -0.09375},
            priority = "high",
            animation_speed = options.animation_speed or 0.25,
            tint = options.animation_tint
        },
        glow_animation = options.glow_color and {
            filename = "__base__/graphics/entity/fire-smoke/fire-smoke-glow.png",
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
            animation_speed = options.animation_speed or 0.25,
            tint = options.glow_color
        } or nil,
        glow_fade_away_duration = options.glow_fade_away_duration
    }
end

data:extend({
    make_rupture_fire(
        "ei-oil-fire-flame",
        3000,
        {amount = 1, type = "fire"},
        {r = 1.0, g = 0.55, b = 0.20},
        1.15
    ),
    make_rupture_fire(
        "ei-gas-fire-flame",
        900,
        {amount = 0.55, type = "fire"},
        {r = 1.0, g = 0.82, b = 0.42},
        1.35
    ),
    make_rupture_fire(
        "ei-exotic-fire-flame",
        1800,
        {amount = 0.75, type = "acid"},
        {r = 0.72, g = 0.34, b = 1.0},
        1.25
    ),
    make_rupture_fire(
        "ei-lava-fire-flame",
        1200,
        {amount = 1.05, type = "fire"},
        {r = 1.0, g = 0.36, b = 0.08},
        1.20
    ),
    make_rupture_fire(
        "ei-oil-platform-fire-flame",
        420,
        {amount = 1, type = "fire"},
        {r = 1.0, g = 0.55, b = 0.20},
        1.05,
        {platform_safe = true, maximum_lifetime = 420}
    ),
    make_rupture_fire(
        "ei-gas-platform-fire-flame",
        180,
        {amount = 0.55, type = "fire"},
        {r = 1.0, g = 0.82, b = 0.42},
        1.15,
        {platform_safe = true, maximum_lifetime = 180}
    ),
    make_rupture_fire(
        "ei-exotic-platform-fire-flame",
        300,
        {amount = 0.75, type = "acid"},
        {r = 0.72, g = 0.34, b = 1.0},
        1.05,
        {platform_safe = true, maximum_lifetime = 300}
    ),
    make_rupture_fire(
        "ei-lava-platform-fire-flame",
        210,
        {amount = 1.05, type = "fire"},
        {r = 1.0, g = 0.36, b = 0.08},
        1.08,
        {platform_safe = true, maximum_lifetime = 210}
    ),
    make_rupture_smoke(
        "ei-oil-rupture-smoke",
        {r = 0.16, g = 0.15, b = 0.14, a = 0.38},
        {
            duration = 360,
            fade_away_duration = 160,
            spread_duration = 420,
            start_scale = 0.40,
            end_scale = 1.90
        }
    ),
    make_rupture_smoke(
        "ei-gas-rupture-smoke",
        {r = 0.48, g = 0.46, b = 0.42, a = 0.24},
        {
            duration = 150,
            fade_away_duration = 72,
            spread_duration = 180,
            start_scale = 0.32,
            end_scale = 1.35,
            animation_tint = {r = 1.0, g = 0.9, b = 0.75, a = 0.80},
            glow_color = {r = 1.0, g = 0.72, b = 0.28, a = 0.45},
            glow_fade_away_duration = 80
        }
    ),
    make_rupture_smoke(
        "ei-exotic-rupture-smoke",
        {r = 0.38, g = 0.18, b = 0.52, a = 0.28},
        {
            duration = 280,
            fade_away_duration = 120,
            spread_duration = 300,
            start_scale = 0.38,
            end_scale = 1.65,
            animation_tint = {r = 0.86, g = 0.64, b = 1.0, a = 0.78},
            glow_color = {r = 0.48, g = 0.92, b = 1.0, a = 0.35},
            glow_fade_away_duration = 140
        }
    ),
    make_rupture_smoke(
        "ei-lava-rupture-smoke",
        {r = 0.22, g = 0.12, b = 0.08, a = 0.30},
        {
            duration = 220,
            fade_away_duration = 104,
            spread_duration = 180,
            start_scale = 0.32,
            end_scale = 1.18,
            affected_by_wind = false,
            animation_tint = {r = 1.0, g = 0.52, b = 0.18, a = 0.82},
            glow_color = {r = 1.0, g = 0.28, b = 0.04, a = 0.48},
            glow_fade_away_duration = 120,
            animation_speed = 0.20
        }
    ),
    make_rupture_smoke(
        "ei-data-rupture-smoke",
        {r = 0.18, g = 0.52, b = 0.62, a = 0.24},
        {
            duration = 120,
            fade_away_duration = 64,
            spread_duration = 140,
            start_scale = 0.28,
            end_scale = 1.10,
            animation_tint = {r = 0.48, g = 1.0, b = 0.92, a = 0.82},
            glow_color = {r = 0.22, g = 0.88, b = 1.0, a = 0.38},
            glow_fade_away_duration = 70,
            animation_speed = 0.22
        }
    ),
    make_rupture_smoke(
        "ei-cryo-rupture-smoke",
        {r = 0.62, g = 0.78, b = 0.92, a = 0.20},
        {
            duration = 160,
            fade_away_duration = 80,
            spread_duration = 180,
            start_scale = 0.30,
            end_scale = 1.28,
            animation_tint = {r = 0.88, g = 0.97, b = 1.0, a = 0.76},
            glow_color = {r = 0.70, g = 0.88, b = 1.0, a = 0.26},
            glow_fade_away_duration = 84,
            animation_speed = 0.21
        }
    ),
    make_rupture_smoke(
        "ei-chemical-rupture-smoke",
        {r = 0.24, g = 0.40, b = 0.12, a = 0.24},
        {
            duration = 190,
            fade_away_duration = 88,
            spread_duration = 220,
            start_scale = 0.32,
            end_scale = 1.36,
            animation_tint = {r = 0.58, g = 1.0, b = 0.42, a = 0.80},
            glow_color = {r = 0.36, g = 0.92, b = 0.22, a = 0.30},
            glow_fade_away_duration = 100,
            animation_speed = 0.23
        }
    ),
    {
        type = "sprite",
        name = "ei-lava-ground-patch",
        filename = "__space-age__/graphics/terrain/water-transitions/lava-patch.png",
        width = 64,
        height = 64
    }
})
