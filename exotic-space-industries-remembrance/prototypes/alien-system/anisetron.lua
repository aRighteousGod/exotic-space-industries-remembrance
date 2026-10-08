--==============================================================================
-- ESIR FILE MAP
-- owns: ANISETRON standalone hover chassis, native crystal charge and beam
-- loaded_by: prototypes/alien-system/alien-system.lua after gaian-saucer
-- cadence: data stage; native movement/payment, runtime owns prepaid sweep
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: native spider vehicle GUI
-- remote_interfaces: native spidertron remote
-- rebuild_on: data stage reload
--==============================================================================
-- blueprint: .codex/esir/blueprints/anisetron.md#contract

local name = "ei-anisetron"
local category = require("lib/anisetron-config").ammo_damage_category
local ammo_name = name.."-crystal-charge"
local gun_name = name.."-beam-gun"
local beam_name = name.."-beam"
local graphics = ei_path.."graphics/entities/anisetron/"
local icon = ei_path.."graphics/items/anisetron.png"
local charge_icon = ei_path.."graphics/items/anisetron-crystal-charge.png"

local config = require("lib/anisetron-config")
local mobility = require("lib/anisetron-mobility-config")
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#mobility
-- Finite native multipliers compensate severe stacked slows on this chassis.
-- Original enemy stickers and their damage remain untouched.
for tier, factor in ipairs(mobility.factors) do
    ---@type data.StickerPrototype
    local sticker = {
        type = "sticker", name = mobility.names[tier], hidden = true,
        flags = {"not-on-map"}, duration_in_ticks = mobility.safety_lifetime,
        target_movement_modifier = 1, vehicle_speed_modifier = factor,
        vehicle_friction_modifier = 1,
    }
    data:extend{sticker}
end
local FRAME_SIZE = 512
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#framing
-- Lookup offsets and sheet dimensions share one reviewed framing authority.
local framing = require("lib/anisetron-graphics")
assert(framing.direction_count == 128 and framing.sheets_per_pass == 2
    and framing.frame_size == FRAME_SIZE, "ANISETRON requires the reviewed 128-direction package")
local SPRITE_SCALE = framing.scale

---@type data.RotatedAnimation
local body = {
    filenames = {graphics.."anisetron_1.png", graphics.."anisetron_2.png"},
    width = FRAME_SIZE, height = FRAME_SIZE,
    line_length = framing.line_length, lines_per_file = framing.lines_per_file,
    slice = framing.slice, direction_count = framing.direction_count, frame_count = 1,
    scale = SPRITE_SCALE, shift = {0, 0},
    apply_projection = false,
}
local glow = table.deepcopy(body)
glow.filenames = {graphics.."anisetron_glow_1.png", graphics.."anisetron_glow_2.png"}
glow.draw_as_glow = true
local mask = table.deepcopy(body)
mask.filenames = {graphics.."anisetron_mask_1.png", graphics.."anisetron_mask_2.png"}
mask.flags = {"mask"}
mask.apply_runtime_tint = true
local shadow = table.deepcopy(body)
shadow.filenames = {graphics.."anisetron_shadow_1.png", graphics.."anisetron_shadow_2.png"}
shadow.draw_as_shadow = true

-- Independent copies of the saucer's native hover anchors avoid its wake/runtime
-- ownership and the researched scout/assault/rocket replacement catalog.
---@type data.SpiderLegPrototype
local leg = table.deepcopy(data.raw["spider-leg"]["ei-gaian-saucer-leg"])
leg.name = name.."-leg"
leg.localised_name = {"entity-name."..name}
leg.icon = icon
leg.icon_size = 128
leg.icon_mipmaps = 3
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#hover
-- Retain the four-anchor shipping gait. The ten-leg trial improved cruise but
-- failed decorative attachment QC with the retained native hover motion.
leg.initial_movement_speed = 0.02
leg.movement_acceleration = 0.02

---@type data.SpiderVehiclePrototype
local cathedral = table.deepcopy(data.raw["spider-vehicle"]["ei-gaian-saucer"])
cathedral.name = name
cathedral.localised_name = {"entity-name."..name}
cathedral.localised_description = {"entity-description."..name}
cathedral.icon = icon
cathedral.icon_size = 128
cathedral.icon_mipmaps = 3
cathedral.minable = {mining_time = 1, result = name}
cathedral.placeable_by = {item = name, count = 1}
cathedral.collision_box = {{-2.4, -3.2}, {2.4, 3.2}}
cathedral.selection_box = {{-2.7, -3.6}, {2.7, 3.6}}
cathedral.guns = {gun_name}
cathedral.automatic_weapon_cycling = false
cathedral.equipment_grid = name.."-equipment-grid"
cathedral.friction_force = 0.7
cathedral.torso_rotation_speed = cathedral.torso_rotation_speed * 0.5
-- In 2.0.77 a slow bob rate also magnifies its excursion: .08 produced a
-- measured 41px swing. Native default 1 retains a restrained 3-4px hover.
cathedral.torso_bob_speed = 1
-- The same Gaian hum descends into a heavier register. Native movement still
-- owns its rise and fall; startup visual resonance does not govern audio.
cathedral.working_sound.sound.min_speed = 0.78
cathedral.working_sound.sound.max_speed = 0.82
cathedral.working_sound.sound.volume = 0.38
cathedral.working_sound.idle_sound.min_speed = 0.72
cathedral.working_sound.idle_sound.max_speed = 0.76
cathedral.working_sound.idle_sound.volume = 0.16
cathedral.working_sound.activity_to_speed_modifiers = {
    multiplier = 0.45, minimum = 0.90, maximum = 1.22, offset = 0.90,
}
cathedral.working_sound.fade_in_ticks = 20
cathedral.working_sound.fade_out_ticks = 60
cathedral.graphics_set = {
    render_layer = "air-object", base_render_layer = "air-object",
    animation = {layers = {body, glow, mask}},
    shadow_animation = shadow,
    light = {{type = "basic", minimum_darkness = 0.2, intensity = 0.42,
              size = 8, color = {0.08, 0.72, 0.62}}},
}
for _, anchor in ipairs(cathedral.spider_engine.legs) do
    anchor.leg = leg.name
end
cathedral.minimap_representation = {
    filename = icon, flags = {"icon"}, size = 128, scale = 0.25,
}
cathedral.selected_minimap_representation = table.deepcopy(cathedral.minimap_representation)

-- Cosmetic beam graphics are copied from the baseline Lance in final updates.
-- The paid runtime controller is the sole damage owner.
---@type data.BeamPrototype
local beam = table.deepcopy(data.raw.beam["laser-beam"])
beam.name = beam_name
beam.width = 0.18
beam.damage_interval = config.contact_ticks
beam.action_triggered_automatically = false
beam.random_target_offset = false
beam.target_offset = {0, 0}
beam.action = nil
beam.working_sound = nil
beam.hidden = true
beam.hidden_in_factoriopedia = true
local crown = table.deepcopy(beam)
crown.name = name.."-crown-beam"
crown.localised_name = {"entity-name."..crown.name}
crown.width = beam.width * 2
local trigger = table.deepcopy(beam)
trigger.name = name.."-charge-trigger"
trigger.damage_interval = 1
trigger.working_sound = nil
trigger.light = nil
local empty = util.empty_sprite()
trigger.graphics_set = {beam = {head = empty, tail = empty, body = {empty}},
    ground = {head = empty, tail = empty, body = empty}}
trigger.action = {type = "direct", action_delivery = {type = "instant",
    target_effects = {{type = "script", effect_id = config.charge_effect}}}}

-- Invisible sound helpers give the paid beam a continuous native voice even
-- when changing sprite headings recreates its visible core.
---@type data.SimpleEntityWithOwnerPrototype[]
local voices = {}
for _, emitter in ipairs{"crown", "facade"} do
    ---@type data.SimpleEntityWithOwnerPrototype
    local voice = {
        type = "simple-entity-with-owner", name = name.."-"..emitter.."-voice",
        flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-in-kill-statistics"},
        hidden = true, hidden_in_factoriopedia = true, selectable_in_game = false,
        allow_copy_paste = false, is_military_target = false,
        collision_mask = {layers = {}}, collision_box = {{0, 0}, {0, 0}},
        selection_box = {{0, 0}, {0, 0}}, picture = util.empty_sprite(), max_health = 1,
    }
    voice.working_sound = {
        sound = {filename = ei_path.."sounds/anisetron-lance-loop.ogg",
            category = "weapon", volume = emitter == "crown" and .32 or .18,
            speed = emitter == "crown" and .90 or 1.05, audible_distance_modifier = .50},
        fade_in_ticks = 6, fade_out_ticks = 12, max_sounds_per_prototype = 5,
        use_doppler_shift = false,
    }
    voices[#voices + 1] = voice
end
data:extend(voices)

data:extend({
    {type = "ammo-category", name = category},
    {
        type = "item-with-entity-data", name = name,
        localised_name = {"entity-name."..name},
        localised_description = {"entity-description."..name},
        icon = icon, icon_size = 128, icon_mipmaps = 3,
        subgroup = "ei-alien-structures-2", order = "a-e[anisetron]",
        place_result = name, stack_size = 1, weight = 200 * kg,
    },
    {
        type = "equipment-grid", name = cathedral.equipment_grid,
        equipment_categories = {"armor"}, width = 12, height = 8,
    },
    {
        type = "gun", name = gun_name, hidden = true,
        localised_name = {"item-name."..gun_name},
        icon = charge_icon, icon_size = 128, icon_mipmaps = 3,
        subgroup = "gun", order = "z[anisetron]", stack_size = 1,
        -- Native attack consumes exactly one charge; its callback owns the burst.
        attack_parameters = {
            type = "beam", ammo_category = category,
            cooldown = config.duration_ticks, cooldown_deviation = 0,
            range = config.crown_range, range_mode = "bounding-box-to-bounding-box",
            min_range = 0, damage_modifier = 1,
            turn_range = config.crown_arc_degrees / 360,
            movement_slow_down_factor = 0, use_shooter_direction = true,
        },
    },
    {
        type = "ammo", name = ammo_name,
        ammo_category = category,
        localised_description = {"item-description."..ammo_name},
        icon = charge_icon, icon_size = 128, icon_mipmaps = 3,
        subgroup = "ammo", order = "z[anisetron]", stack_size = 100,
        magazine_size = 1, weight = 10 * kg,
        ammo_type = {
            target_type = "entity",
            action = {type = "direct", force = "enemy", action_delivery = {
                type = "beam", beam = trigger.name, max_length = 0,
                duration = 1,
                add_to_shooter = true, destroy_with_source_or_target = true,
            }},
        },
    },
    {
        type = "recipe", name = name, category = "crafting",
        energy_required = 120, enabled = false,
        surface_conditions = {{property = "gravity", min = 15.5, max = 15.5}},
        ingredients = {
            {type = "item", name = "ei-gaian-saucer", amount = 1},
            {type = "item", name = "ei-singularity-lance", amount = 1},
            {type = "item", name = "ei-crystal-accumulator", amount = 1},
            {type = "item", name = "ei-high-energy-crystal", amount = 160},
            {type = "item", name = "ei-sus-plating", amount = 250},
            {type = "item", name = "ei-computing-unit", amount = 60},
            {type = "item", name = "ei-alien-resin", amount = 220},
            {type = "item", name = "ei-magnet", amount = 150},
        },
        results = {{type = "item", name = name, amount = 1}},
        main_product = name, always_show_made_in = true,
    },
    {
        type = "recipe", name = ammo_name, category = "crafting",
        energy_required = 10, enabled = false,
        ingredients = {
            {type = "item", name = "ei-high-energy-crystal", amount = 10},
            {type = "item", name = "ei-electronic-parts", amount = 2},
            {type = "item", name = "ei-sus-plating", amount = 2},
        },
        results = {{type = "item", name = ammo_name, amount = 1}},
        main_product = ammo_name, always_show_made_in = true,
    },
    {
        type = "technology", name = name,
        icon = ei_path.."graphics/technology/anisetron.png", icon_size = 256,
        prerequisites = {
            "ei-gaian-saucer", "ei-crystal-accumulator", "ei-computing-unit",
            "ei-neodymium-magnet", "ei-sus-plating", "ei-high-energy-crystal",
            "ei-electronic-parts", "laser-weapons-damage-5", "ei-singularity-lance",
        },
        effects = {
            {type = "unlock-recipe", recipe = name},
            {type = "unlock-recipe", recipe = ammo_name},
        },
        unit = {count = 300, time = 30, ingredients = ei_data.science["alien-computer-age"]},
        age = "alien-computer-age",
    },
    leg, cathedral, beam, crown, trigger,
    {
        type = "animation", name = name.."-movement-strand",
        filename = "__base__/graphics/entity/beam/beam-body-1.png",
        width = 32, height = 39, frame_count = 16, line_length = 16,
        scale = .5, shift = {0, 0}, draw_as_glow = true,
        blend_mode = "additive-soft", tint = {r = .05, g = 1, b = .18, a = .8},
        animation_speed = .5,
    },
})
