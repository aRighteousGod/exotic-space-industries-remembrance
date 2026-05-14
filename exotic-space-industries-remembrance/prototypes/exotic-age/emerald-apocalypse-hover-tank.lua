--==============================================================================
-- ESIR FILE MAP
-- owns: Emerald Apocalypse Hover Tank prototype/data slice
-- loaded_by: prototypes/exotic-age/exotic-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================

local ei_lib = require("lib/lib")

local tank_name = "ei-emerald-apocalypse-hover-tank"
local cannon_name = "ei-emerald-apocalypse-cannon"
local ammo_name = "ei-emerald-apocalypse-charge"
local ammo_category = cannon_name
local shot_effect_id = "ei-emerald-apocalypse-charge-shot"
local orbital_shard_beam_name = tank_name.."-orbital-shard-beam"
local orbital_shard_beam_aperture_1_name = tank_name.."-orbital-shard-beam-aperture-1"
local orbital_shard_beam_aperture_2_name = tank_name.."-orbital-shard-beam-aperture-2"
local orbital_shard_beam_aperture_3_name = tank_name.."-orbital-shard-beam-aperture-3"
local grid_name = tank_name.."-equipment-grid"
local equipment_category = "ei_emerald_hover_tank_core"
local core_equipment_name = "ei-emerald-fusion-core-equipment"
local shield_equipment_name = "ei-emerald-aegis-shield-equipment"

local tank_icon = ei_path.."graphics/items/emerald-apocalypse-hover-tank.png"
local tank_tech_icon = ei_path.."graphics/techs/emerald-apocalypse-hover-tank.png"
local cannon_icon = "__base__/graphics/icons/tank-cannon.png"
local charge_icon = ei_path.."graphics/items/emerald-apocalypse-charge.png"
local charge_glow_icon = ei_path.."graphics/items/emerald-apocalypse-charge-glow.png"
local core_icon = ei_graphics_item_path.."fusion-reactor.png"
local shield_icon = "__base__/graphics/equipment/energy-shield-mk2-equipment.png"
local tank_graphics_path = ei_path.."graphics/entities/emerald-apocalypse-hover-tank/"
local orbital_shard_graphics_path = ei_path.."graphics/entities/emerald-apocalypse-orbital-shard/"
local effect_graphics_path = tank_graphics_path.."effects/"
local hover_sound_path = ei_path.."sounds/emerald-apocalypse-tank-hover.ogg"
local chargeup_sound_name = "ei-emerald-apocalypse-hover-tank-charge-start"
local chargeup_sound_path = ei_path.."sounds/emerald-apocalypse-tank-beam-chargeup.ogg"
local hover_emitter_animation_name = tank_name.."-hover-emitter"
local orbital_shard_animation_name = tank_name.."-orbital-shard"
local chargeup_animation_name = "ei-emerald-apocalypse-chargeup"
local muzzle_flash_animation_name = "ei-emerald-apocalypse-muzzle-flash"
local main_beam_name = "ei-emerald-apocalypse-beam"
local impact_explosion_name = "ei-emerald-collapse-impact"
local shockwave_explosion_name = "ei-emerald-apocalypse-shockwave"
local hit_flash_animation_name = "ei-emerald-collapse-hit-flash"
local scorchmark_name = "ei-emerald-collapse-scorchmark"
local shield_pulse_animation_name = "ei-emerald-shield-pulse"

local emerald_tint = {r = 0.1, g = 1.0, b = 0.42, a = 1.0}
local orbital_shard_tint = {r = 0.08, g = 1.0, b = 0.52, a = 0.88}
local ORBITAL_SHARD_BASE_BEAM_WIDTH = 0.42
local TANK_FRAME_SIZE = 768
local TANK_LINE_LENGTH = 4
local TANK_LINES_PER_FILE = 4
local TANK_DIRECTION_COUNT = 64
local TANK_SCALE = 0.7
local TANK_BASE_PREFIX = "object_lit_v8"
local TANK_BODY_RENDER_LAYER = "higher-object-above"
local HOVER_EMITTER_FRAME_SIZE = 256
local HOVER_EMITTER_FRAME_COUNT = 32
local HOVER_EMITTER_LINE_LENGTH = 8
local ORBITAL_SHARD_FRAME_SIZE = 128
local ORBITAL_SHARD_DIRECTION_COUNT = 64
local ORBITAL_SHARD_LINE_LENGTH = 8
local ORBITAL_SHARD_SCALE = 0.64
local ORBITAL_SHARD_COUNT = 3
local ORBITAL_SHARD_ATTACK_RANGE = 36
local ORBITAL_SHARD_COOLDOWN_TICKS = 70
local ORBITAL_SHARD_BASE_DAMAGE = 240
local ORBITAL_SHARD_DAMAGE_TYPE = "ei-plasma"
local ORBITAL_SHARD_LASER_7_BONUS = 0.70
local ORBITAL_SHARD_QUALITY_MAX_BONUS = 1.00
local TICKS_PER_SECOND = 60
local BEAM_EFFECT_FRAME_COUNT = 24
local BEAM_EFFECT_LINE_LENGTH = 6

local function format_tooltip_number(value)
    value = tonumber(value) or 0
    if value % 1 == 0 then
        return tostring(math.floor(value))
    end

    return string.format("%.1f", value)
end

local function format_seconds_from_ticks(ticks)
    local seconds = (tonumber(ticks) or 0) / TICKS_PER_SECOND
    local rounded = math.floor(seconds * 100 + 0.5) / 100
    if rounded % 1 == 0 then
        return tostring(math.floor(rounded))
    end

    local text = string.format("%.2f", rounded)
    return (text:gsub("0+$", ""):gsub("%.$", ""))
end

local function make_orbital_shard_tooltip_fields()
    local base_swarm_dps = ORBITAL_SHARD_COUNT
        * ORBITAL_SHARD_BASE_DAMAGE
        * TICKS_PER_SECOND
        / ORBITAL_SHARD_COOLDOWN_TICKS

    return {
        {
            name = "",
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-header",
                {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-title"},
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-count"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-count-value",
                tostring(ORBITAL_SHARD_COUNT),
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-direct-hit"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-damage-value",
                format_tooltip_number(ORBITAL_SHARD_BASE_DAMAGE),
                {"damage-type-name."..ORBITAL_SHARD_DAMAGE_TYPE},
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-swarm-dps"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-dps-value",
                format_tooltip_number(base_swarm_dps),
                {"damage-type-name."..ORBITAL_SHARD_DAMAGE_TYPE},
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-range"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-range-value",
                tostring(ORBITAL_SHARD_ATTACK_RANGE),
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-cooldown"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-cooldown-value",
                format_seconds_from_ticks(ORBITAL_SHARD_COOLDOWN_TICKS),
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-scaling"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-scaling-value",
                format_tooltip_number(ORBITAL_SHARD_LASER_7_BONUS * 100).."%",
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-quality-scaling"},
            value = {
                "custom-tooltip.ei-emerald-apocalypse-orbital-shards-quality-scaling-value",
                format_tooltip_number(ORBITAL_SHARD_QUALITY_MAX_BONUS * 100).."%",
            },
        },
        {
            name = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-upgrades"},
            value = {"custom-tooltip.ei-emerald-apocalypse-orbital-shards-upgrades-value"},
        },
    }
end

local function tank_stripes(prefix)
    return {
        {
            filename = tank_graphics_path..prefix.."_0.png",
            width_in_frames = TANK_LINE_LENGTH,
            height_in_frames = TANK_LINES_PER_FILE,
        },
        {
            filename = tank_graphics_path..prefix.."_0_1.png",
            width_in_frames = TANK_LINE_LENGTH,
            height_in_frames = TANK_LINES_PER_FILE,
        },
        {
            filename = tank_graphics_path..prefix.."_0_2.png",
            width_in_frames = TANK_LINE_LENGTH,
            height_in_frames = TANK_LINES_PER_FILE,
        },
        {
            filename = tank_graphics_path..prefix.."_0_3.png",
            width_in_frames = TANK_LINE_LENGTH,
            height_in_frames = TANK_LINES_PER_FILE,
        },
    }
end

local function tank_layer(prefix, options)
    options = options or {}

    local layer = {
        priority = "high",
        width = TANK_FRAME_SIZE,
        height = TANK_FRAME_SIZE,
        frame_count = 1,
        direction_count = TANK_DIRECTION_COUNT,
        line_length = TANK_LINE_LENGTH,
        lines_per_file = TANK_LINES_PER_FILE,
        shift = {0, 0},
        scale = TANK_SCALE,
        stripes = tank_stripes(prefix),
    }

    if options.render_layer then
        layer.render_layer = options.render_layer
    end
    if options.draw_as_shadow then
        layer.draw_as_shadow = true
    end
    if options.draw_as_glow then
        layer.draw_as_glow = true
        layer.blend_mode = options.blend_mode or "additive"
    end

    return layer
end

local function emerald_tank_animation()
    return {
        layers = {
            tank_layer(TANK_BASE_PREFIX, {
                render_layer = TANK_BODY_RENDER_LAYER,
            }),
            tank_layer("emerald_crystal_glow", {
                render_layer = TANK_BODY_RENDER_LAYER,
                draw_as_glow = true,
                blend_mode = "additive-soft",
            }),
            tank_layer("object_shadow", {
                draw_as_shadow = true,
            }),
        },
    }
end

local function hover_emitter_animation_layer(filename, options)
    options = options or {}

    return {
        filename = tank_graphics_path..filename,
        priority = "high",
        width = HOVER_EMITTER_FRAME_SIZE,
        height = HOVER_EMITTER_FRAME_SIZE,
        line_length = HOVER_EMITTER_LINE_LENGTH,
        lines_per_file = HOVER_EMITTER_FRAME_COUNT / HOVER_EMITTER_LINE_LENGTH,
        frame_count = HOVER_EMITTER_FRAME_COUNT,
        animation_speed = options.animation_speed or 0.42,
        draw_as_glow = options.draw_as_glow,
        blend_mode = options.blend_mode,
    }
end

local function hover_emitter_animation()
    return {
        name = hover_emitter_animation_name,
        type = "animation",
        layers = {
            hover_emitter_animation_layer("emerald-apocalypse-hover-tank-hover-emitter.png"),
            hover_emitter_animation_layer("emerald-apocalypse-hover-tank-hover-emitter-glow.png", {
                draw_as_glow = true,
                blend_mode = "additive-soft",
            }),
        },
    }
end

local function orbital_shard_animation_layer(filename, options)
    options = options or {}

    local layer = {
        filename = orbital_shard_graphics_path..filename,
        priority = "high",
        width = ORBITAL_SHARD_FRAME_SIZE,
        height = ORBITAL_SHARD_FRAME_SIZE,
        frame_count = 1,
        direction_count = ORBITAL_SHARD_DIRECTION_COUNT,
        line_length = ORBITAL_SHARD_LINE_LENGTH,
        scale = ORBITAL_SHARD_SCALE,
        shift = {0, 0},
        draw_as_shadow = options.draw_as_shadow,
        draw_as_glow = options.draw_as_glow,
        blend_mode = options.blend_mode,
    }

    return layer
end

local function orbital_shard_animation()
    return {
        name = orbital_shard_animation_name,
        type = "animation",
        layers = {
            orbital_shard_animation_layer("emerald-apocalypse-orbital-shard.png"),
            orbital_shard_animation_layer("emerald-apocalypse-orbital-shard-glow.png", {
                draw_as_glow = true,
                blend_mode = "additive-soft",
            }),
            orbital_shard_animation_layer("emerald-apocalypse-orbital-shard-shadow.png", {
                draw_as_shadow = true,
            }),
        },
    }
end

local function effect_animation_layer(filename, width, height, frame_count, line_length, options)
    options = options or {}

    local layer = {
        filename = effect_graphics_path..filename,
        priority = "high",
        width = width,
        height = height,
        frame_count = frame_count,
        line_length = line_length,
        animation_speed = options.animation_speed or 0.5,
        scale = options.scale,
        shift = options.shift,
    }

    if options.draw_as_glow then
        layer.draw_as_glow = true
        layer.blend_mode = options.blend_mode or "additive-soft"
    end

    return layer
end

local function effect_animation_layers(base_filename, glow_filename, width, height, frame_count, line_length, options)
    options = options or {}
    local base_options = table.deepcopy(options)
    local glow_options = table.deepcopy(options)
    glow_options.draw_as_glow = true
    glow_options.blend_mode = options.glow_blend_mode or "additive-soft"

    return {
        layers = {
            effect_animation_layer(base_filename, width, height, frame_count, line_length, base_options),
            effect_animation_layer(glow_filename, width, height, frame_count, line_length, glow_options),
        },
    }
end

local function effect_animation(name, base_filename, glow_filename, width, height, frame_count, line_length, options)
    local animation = effect_animation_layers(base_filename, glow_filename, width, height, frame_count, line_length, options)
    animation.name = name
    animation.type = "animation"
    return animation
end

local function beam_effect_animation(base_filename, glow_filename)
    return effect_animation_layers(base_filename, glow_filename, 192, 64, BEAM_EFFECT_FRAME_COUNT, BEAM_EFFECT_LINE_LENGTH, {
        animation_speed = 0.72,
        scale = 1.16,
    })
end

local function emerald_main_beam()
    local base_beam = data.raw.beam and data.raw.beam["laser-beam"]
    if not base_beam then
        error("Emerald Apocalypse main beam requires the vanilla laser-beam prototype")
    end

    local body = beam_effect_animation(
        "emerald-apocalypse-hover-tank-beam-body.png",
        "emerald-apocalypse-hover-tank-beam-body-glow.png"
    )
    local head = beam_effect_animation(
        "emerald-apocalypse-hover-tank-beam-head.png",
        "emerald-apocalypse-hover-tank-beam-head-glow.png"
    )
    local tail = beam_effect_animation(
        "emerald-apocalypse-hover-tank-beam-tail.png",
        "emerald-apocalypse-hover-tank-beam-tail-glow.png"
    )

    local beam = table.deepcopy(base_beam)
    beam.name = main_beam_name
    beam.hidden = true
    beam.hidden_in_factoriopedia = true
    beam.width = 2.25
    beam.damage_interval = 60
    beam.random_target_offset = false
    beam.target_offset = {0, 0}
    beam.action = nil
    beam.action_triggered_automatically = false
    beam.working_sound = nil
    beam.light = {
        intensity = 1.15,
        size = 34,
        minimum_darkness = 0,
        color = {r = 0.10, g = 1.0, b = 0.52, a = 1.0},
    }
    beam.graphics_set = {
        beam = {
            start = table.deepcopy(tail),
            ending = table.deepcopy(head),
            head = table.deepcopy(head),
            tail = table.deepcopy(tail),
            body = {table.deepcopy(body)},
            render_layer = "projectile",
        },
        ground = {
            head = util.empty_sprite(),
            tail = util.empty_sprite(),
            body = util.empty_sprite(),
        },
        desired_segment_length = 1.35,
        transparent_start_end_animations = true,
        random_end_animation_rotation = false,
        randomize_animation_per_segment = false,
    }
    beam.head = nil
    beam.tail = nil
    beam.body = nil
    return beam
end

local function emerald_impact_explosion()
    return {
        name = impact_explosion_name,
        type = "explosion",
        flags = {"not-on-map"},
        hidden = true,
        hidden_in_factoriopedia = true,
        render_layer = "explosion",
        animations = effect_animation_layers(
            "emerald-apocalypse-hover-tank-impact.png",
            "emerald-apocalypse-hover-tank-impact-glow.png",
            768,
            768,
            64,
            8,
            {
                animation_speed = 0.78,
                scale = 1.5,
            }
        ),
        light = {
            intensity = 1.75,
            size = 88,
            minimum_darkness = 0,
            color = emerald_tint,
        },
        sound = nil,
    }
end

local function emerald_shockwave_explosion()
    local base_shockwave = data.raw.explosion and data.raw.explosion["atomic-nuke-shockwave"]
    if not base_shockwave then
        error("Emerald Apocalypse shockwave requires the vanilla atomic-nuke-shockwave prototype")
    end

    local shockwave = table.deepcopy(base_shockwave)
    shockwave.name = shockwave_explosion_name
    shockwave.hidden = true
    shockwave.hidden_in_factoriopedia = true
    shockwave.sound = nil
    shockwave.created_effect = nil
    shockwave.scale_deviation = 0.08
    shockwave.scale_initial = 0.08
    shockwave.scale_increment_per_tick = 0.006
    shockwave.scale_end = 0.48
    shockwave.scale_in_duration = 8
    shockwave.scale_out_duration = 34
    shockwave.fade_out_duration = 24
    for _, layer in pairs(shockwave.animations or {}) do
        if type(layer) == "table" then
            layer.tint = {r = 0.08, g = 1.0, b = 0.52, a = 0.72}
            layer.draw_as_glow = true
        end
    end
    return shockwave
end

local function emerald_scorchmark()
    local base_scorchmark = data.raw.corpse and (data.raw.corpse["small-scorchmark-tintable"] or data.raw.corpse["small-scorchmark"])
    if not base_scorchmark then
        error("Emerald Apocalypse scorchmark requires a vanilla scorchmark corpse prototype")
    end

    local scorchmark = table.deepcopy(base_scorchmark)
    scorchmark.name = scorchmark_name
    scorchmark.hidden_in_factoriopedia = true
    scorchmark.selectable_in_game = false
    scorchmark.time_before_removed = 60 * 60 * 20
    scorchmark.use_tile_color_for_ground_patch_tint = false
    scorchmark.remove_on_entity_placement = true
    scorchmark.remove_on_tile_placement = false
    scorchmark.ground_patch = {
        sheet = {
            filename = effect_graphics_path.."emerald-apocalypse-hover-tank-scorchmark.png",
            width = 768,
            height = 768,
            line_length = 1,
            variation_count = 1,
            scale = 1.5,
        },
    }
    scorchmark.ground_patch_higher = {
        sheet = {
            filename = effect_graphics_path.."emerald-apocalypse-hover-tank-scorchmark-glow.png",
            width = 768,
            height = 768,
            line_length = 1,
            variation_count = 1,
            scale = 1.5,
            draw_as_glow = true,
            blend_mode = "additive-soft",
        },
    }
    return scorchmark
end

local function force_sprite_tint_nodes(node, tint)
    if type(node) ~= "table" then
        return
    end

    if node.filename or node.filenames or node.stripes or node.layers then
        node.tint = tint
    end

    for _, child in pairs(node) do
        if type(child) == "table" then
            force_sprite_tint_nodes(child, tint)
        end
    end
end

local function scale_sprite_nodes(node, scale_multiplier)
    if type(node) ~= "table" then
        return
    end

    if node.filename or node.filenames or node.stripes then
        node.scale = (tonumber(node.scale) or 1) * scale_multiplier
    end

    for _, child in pairs(node) do
        if type(child) == "table" then
            scale_sprite_nodes(child, scale_multiplier)
        end
    end
end

local function orbital_shard_beam(name, width, light_size, light_intensity, tint)
    local base_beam = data.raw.beam and data.raw.beam["laser-beam"]
    if not base_beam then
        error("Emerald Apocalypse orbital shards require the vanilla laser-beam prototype")
    end

    tint = tint or orbital_shard_tint

    local beam = table.deepcopy(base_beam)
    beam.name = name
    beam.hidden = true
    beam.hidden_in_factoriopedia = true
    beam.width = width
    beam.damage_interval = 60
    beam.random_target_offset = false
    beam.target_offset = {0, 0}
    beam.action = nil
    beam.action_triggered_automatically = false
    beam.working_sound = nil
    beam.light = {
        intensity = light_intensity,
        size = light_size,
        minimum_darkness = 0,
        color = tint,
    }

    force_sprite_tint_nodes(beam.graphics_set or beam, tint)
    scale_sprite_nodes(
        beam.graphics_set and beam.graphics_set.beam or beam,
        math.max(1, width / ORBITAL_SHARD_BASE_BEAM_WIDTH)
    )
    return beam
end

local function emerald_tank_working_sound()
    return {
        sound = {
            filename = hover_sound_path,
            volume = 1.18,
            speed = 0.76,
            audible_distance_modifier = 1.45,
        },
        idle_sound = {
            filename = hover_sound_path,
            volume = 0.48,
            speed = 0.58,
            audible_distance_modifier = 1.10,
        },
        match_speed_to_activity = true,
        activity_to_speed_modifiers = {
            multiplier = 0.62,
            minimum = 0.54,
            maximum = 1.12,
            offset = 0.54,
        },
        match_volume_to_activity = true,
        activity_to_volume_modifiers = {
            multiplier = 1.95,
            minimum = 0.46,
            maximum = 2.05,
            offset = 0.12,
        },
        use_doppler_shift = false,
        fade_in_ticks = 20,
        fade_out_ticks = 60,
        max_sounds_per_prototype = 3,
    }
end

local base_tank = data.raw.car and data.raw.car.tank
local base_cannon = data.raw.gun and data.raw.gun["tank-cannon"]

if not base_tank then
    error("Emerald Apocalypse Hover Tank requires the vanilla tank car prototype")
end

if not base_cannon then
    error("Emerald Apocalypse Cannon requires the vanilla tank-cannon gun prototype")
end

if not mods["Hovercrafts"] and not data.raw["collision-layer"]["ei_hovercraft"] then
    data:extend({
        {
            type = "collision-layer",
            name = "ei_hovercraft",
        },
    })
end

local hover_tank = table.deepcopy(base_tank)
hover_tank.name = tank_name
hover_tank.localised_name = {"entity-name."..tank_name}
hover_tank.localised_description = {"entity-description."..tank_name}
hover_tank.icon = tank_icon
hover_tank.icon_size = 64
hover_tank.icon_mipmaps = nil
hover_tank.minable = {mining_time = 1, result = tank_name}
hover_tank.placeable_by = {item = tank_name, count = 1}
hover_tank.equipment_grid = grid_name
hover_tank.guns = {cannon_name}
hover_tank.max_health = 50000
hover_tank.inventory_size = 120
hover_tank.trash_inventory_size = 40
hover_tank.collision_box = {{-4.35, -4.35}, {4.35, 4.35}}
hover_tank.selection_box = {{-4.5, -4.5}, {4.5, 4.5}}
hover_tank.drawing_box = {{-8, -8}, {8, 8}}
hover_tank.weight = 60000
hover_tank.consumption = "3.6MW"
hover_tank.braking_power = "2500kW"
hover_tank.effectivity = 0.85
hover_tank.rotation_speed = 0.0035
hover_tank.terrain_friction_modifier = 0
hover_tank.friction = 0.0008
hover_tank.render_layer = TANK_BODY_RENDER_LAYER
hover_tank.resistances = {
    {type = "fire", decrease = 120, percent = 95},
    {type = "physical", decrease = 80, percent = 95},
    {type = "impact", decrease = 180, percent = 95},
    {type = "explosion", decrease = 140, percent = 95},
    {type = "acid", decrease = 80, percent = 95},
    {type = "laser", decrease = 80, percent = 95},
    {type = "electric", decrease = 80, percent = 95},
    {type = "ei-plasma", decrease = 140, percent = 95},
}
hover_tank.energy_source = {
    type = "burner",
    fuel_categories = {"ei-fusion-fuel", "ei-nuclear-fuel", "ei-nuclear-fuel-cell"},
    effectivity = 1,
    fuel_inventory_size = 2,
    burnt_inventory_size = 2,
}
hover_tank.animation = emerald_tank_animation()
hover_tank.turret_animation = nil
hover_tank.light_animation = nil
hover_tank.working_sound = emerald_tank_working_sound()
if hover_tank.light then
    for _, light in pairs(hover_tank.light) do
        light.color = emerald_tint
    end
end
ei_lib.set_custom_tooltip_fields(hover_tank, make_orbital_shard_tooltip_fields())

local emerald_cannon = table.deepcopy(base_cannon)
emerald_cannon.name = cannon_name
emerald_cannon.localised_name = {"item-name."..cannon_name}
emerald_cannon.localised_description = {"item-description."..cannon_name}
emerald_cannon.icon = cannon_icon
emerald_cannon.hidden = true
emerald_cannon.attack_parameters.ammo_category = ammo_category
emerald_cannon.attack_parameters.cooldown = 1080
emerald_cannon.attack_parameters.range = 96
emerald_cannon.attack_parameters.damage_modifier = 1
emerald_cannon.attack_parameters.projectile_creation_distance = 4.2

local hover_tank_item = {
    name = tank_name,
    type = "item-with-entity-data",
    icon = tank_icon,
    icon_size = 64,
    subgroup = "transport",
    order = "b[personal-transport]-d["..tank_name.."]",
    place_result = tank_name,
    stack_size = 1,
    weight = 2000 * kg,
}
ei_lib.set_custom_tooltip_fields(hover_tank_item, make_orbital_shard_tooltip_fields())

data:extend({
    {
        name = ammo_category,
        type = "ammo-category",
        localised_name = {"ammo-category-name."..ammo_category},
        icon = cannon_icon,
        icon_size = 64,
    },
    {
        name = equipment_category,
        type = "equipment-category",
    },
    hover_emitter_animation(),
    orbital_shard_animation(),
    effect_animation(
        chargeup_animation_name,
        "emerald-apocalypse-hover-tank-chargeup.png",
        "emerald-apocalypse-hover-tank-chargeup-glow.png",
        256,
        256,
        60,
        10,
        {
            animation_speed = 1 / 3,
        }
    ),
    effect_animation(
        muzzle_flash_animation_name,
        "emerald-apocalypse-hover-tank-muzzle-flash.png",
        "emerald-apocalypse-hover-tank-muzzle-flash-glow.png",
        192,
        192,
        24,
        6,
        {
            animation_speed = 0.88,
        }
    ),
    effect_animation(
        hit_flash_animation_name,
        "emerald-apocalypse-hover-tank-hit-flash.png",
        "emerald-apocalypse-hover-tank-hit-flash-glow.png",
        192,
        192,
        24,
        6,
        {
            animation_speed = 0.82,
        }
    ),
    effect_animation(
        shield_pulse_animation_name,
        "emerald-apocalypse-hover-tank-shield-pulse-v3.png",
        "emerald-apocalypse-hover-tank-shield-pulse-v3-glow.png",
        384,
        384,
        48,
        8,
        {
            animation_speed = 0.9,
        }
    ),
    emerald_main_beam(),
    emerald_impact_explosion(),
    emerald_shockwave_explosion(),
    emerald_scorchmark(),
    orbital_shard_beam(orbital_shard_beam_name, 0.42, 16, 0.82, orbital_shard_tint),
    orbital_shard_beam(orbital_shard_beam_aperture_1_name, 0.70, 22, 0.98, {r = 0.07, g = 1.0, b = 0.50, a = 0.92}),
    orbital_shard_beam(orbital_shard_beam_aperture_2_name, 0.95, 28, 1.14, {r = 0.06, g = 1.0, b = 0.48, a = 0.96}),
    orbital_shard_beam(orbital_shard_beam_aperture_3_name, 1.25, 36, 1.32, {r = 0.05, g = 1.0, b = 0.46, a = 1.00}),
    {
        name = chargeup_sound_name,
        type = "sound",
        category = "weapon",
        filename = chargeup_sound_path,
        volume = 1.35,
        audible_distance_modifier = 1.65,
        advanced_volume_control = {
            attenuation = "exponential",
        },
    },
    {
        name = chargeup_sound_name.."-upgrade-1",
        type = "sound",
        category = "weapon",
        filename = ei_path.."sounds/emerald-apocalypse-tank-beam-chargeup-upgrade-1.ogg",
        volume = 1.35,
        audible_distance_modifier = 1.65,
        advanced_volume_control = {
            attenuation = "exponential",
        },
    },
    {
        name = chargeup_sound_name.."-upgrade-2",
        type = "sound",
        category = "weapon",
        filename = ei_path.."sounds/emerald-apocalypse-tank-beam-chargeup-upgrade-2.ogg",
        volume = 1.35,
        audible_distance_modifier = 1.65,
        advanced_volume_control = {
            attenuation = "exponential",
        },
    },
    {
        name = chargeup_sound_name.."-upgrade-3",
        type = "sound",
        category = "weapon",
        filename = ei_path.."sounds/emerald-apocalypse-tank-beam-chargeup-upgrade-3.ogg",
        volume = 1.35,
        audible_distance_modifier = 1.65,
        advanced_volume_control = {
            attenuation = "exponential",
        },
    },
    {
        name = "ei-emerald-apocalypse-hover-tank-beam-fire",
        type = "sound",
        category = "weapon",
        filename = ei_path.."sounds/emerald-apocalypse-tank-beam-fire.ogg",
        volume = 1.55,
        audible_distance_modifier = 1.9,
        advanced_volume_control = {
            attenuation = "exponential",
        },
    },
    hover_tank_item,
    {
        name = ammo_name,
        type = "ammo",
        icon = charge_icon,
        icon_size = 128,
        icon_mipmaps = 3,
        pictures = {
            {
                layers = {
                    {
                        filename = charge_icon,
                        size = 128,
                        scale = 0.25,
                        mipmap_count = 3,
                    },
                    {
                        filename = charge_glow_icon,
                        size = 128,
                        scale = 0.25,
                        mipmap_count = 3,
                        draw_as_glow = true,
                        blend_mode = "additive-soft",
                    },
                },
            },
        },
        subgroup = "ammo",
        order = "d[explosive-cannon-shell]-z["..ammo_name.."]",
        ammo_category = ammo_category,
        magazine_size = 1,
        stack_size = 1,
        ammo_type = {
            category = ammo_category,
            target_type = "position",
            action = {
                type = "direct",
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        {
                            type = "script",
                            effect_id = shot_effect_id,
                        },
                    },
                },
            },
        },
    },
    {
        name = tank_name,
        type = "recipe",
        category = "ei-exotic-assembler",
        energy_required = 600,
        ingredients = {
            {type = "item", name = "tank", amount = 1},
            {type = "item", name = "ei-fusion-reactor", amount = 1},
            {type = "item", name = "ei-accelerator", amount = 1},
            {type = "item", name = "ei-gauss-module", amount = 2},
            {type = "item", name = "ei-quantum-computer", amount = 1},
            {type = "item", name = "ei-high-tech-parts", amount = 300},
            {type = "item", name = "ei-clean-plating", amount = 700},
            {type = "item", name = "ei-eu-circuit", amount = 120},
            {type = "item", name = "ei-eu-magnet", amount = 120},
            {type = "item", name = "ei-cavity", amount = 16},
            {type = "item", name = "ei-plasma-cube", amount = 24},
            {type = "item", name = "ei-exotic-matter-up", amount = 120},
            {type = "item", name = "ei-high-energy-crystal", amount = 500},
        },
        results = {{type = "item", name = tank_name, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = tank_name,
    },
    {
        name = ammo_name,
        type = "recipe",
        category = "ei-accelerator",
        energy_required = 180,
        ingredients = {
            {type = "item", name = "ei-high-energy-crystal", amount = 64},
            {type = "item", name = "ei-high-tech-parts", amount = 18},
            {type = "item", name = "ei-clean-plating", amount = 24},
            {type = "item", name = "ei-eu-circuit", amount = 16},
            {type = "item", name = "ei-eu-magnet", amount = 16},
            {type = "item", name = "ei-exotic-matter-up", amount = 32},
            {type = "item", name = "ei-cavity", amount = 6},
            {type = "item", name = "ei-plasma-cube", amount = 8},
        },
        results = {{type = "item", name = ammo_name, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = ammo_name,
    },
    {
        name = tank_name,
        type = "technology",
        icon = tank_tech_icon,
        icon_size = 256,
        prerequisites = {
            "ei-exotic-age",
            "ei-high-tech-parts",
            "ei-fusion-reactor",
            "ei-accelerator",
        },
        effects = {
            {type = "unlock-recipe", recipe = tank_name},
            {type = "unlock-recipe", recipe = ammo_name},
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["exotic-age"],
            time = 20,
        },
        age = "exotic-age",
    },
    {
        name = grid_name,
        type = "equipment-grid",
        equipment_categories = {"armor", equipment_category},
        width = 24,
        height = 24,
    },
    {
        name = core_equipment_name,
        type = "item",
        icon = core_icon,
        icon_size = 64,
        hidden = true,
        subgroup = "equipment",
        order = "z[emerald-apocalypse]-a[core]",
        stack_size = 1,
        place_as_equipment_result = core_equipment_name,
    },
    {
        name = core_equipment_name,
        type = "generator-equipment",
        power = "2GW",
        categories = {equipment_category},
        sprite = {
            filename = core_icon,
            width = 64,
            height = 64,
            priority = "medium",
        },
        shape = {
            width = 6,
            height = 6,
            type = "full",
        },
        energy_source = {
            type = "electric",
            usage_priority = "primary-output",
        },
    },
    {
        name = shield_equipment_name,
        type = "item",
        icon = "__base__/graphics/icons/energy-shield-mk2-equipment.png",
        icon_size = 64,
        hidden = true,
        subgroup = "military-equipment",
        order = "z[emerald-apocalypse]-b[shield]",
        stack_size = 1,
        place_as_equipment_result = shield_equipment_name,
    },
    {
        name = shield_equipment_name,
        type = "energy-shield-equipment",
        categories = {equipment_category},
        sprite = {
            filename = shield_icon,
            width = 64,
            height = 64,
            priority = "medium",
            tint = emerald_tint,
        },
        shape = {
            width = 5,
            height = 5,
            type = "full",
        },
        max_shield_value = 25000,
        energy_per_shield = "50kJ",
        energy_source = {
            type = "electric",
            buffer_capacity = "1GJ",
            input_flow_limit = "1GW",
            usage_priority = "primary-input",
        },
    },
    emerald_cannon,
    hover_tank,
})
