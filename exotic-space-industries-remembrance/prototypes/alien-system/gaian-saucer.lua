local ei_data = require("lib/data")

--====================================================================================================
--GAIAN SAUCER
--====================================================================================================

local saucer_name = "ei-gaian-saucer"
local leg_name = saucer_name.."-leg"
local grid_name = saucer_name.."-equipment-grid"
local main_graphics_entity_path = ei_path.."graphics/entities/"
local main_graphics_item_path = ei_path.."graphics/items/"
local main_graphics_tech_path = ei_path.."graphics/techs/"
local icon_path = main_graphics_item_path.."gaian-saucer.png"
local tech_icon_path = main_graphics_tech_path.."gaian-saucer.png"
local SAUCER_FRAME_SIZE = 768
local SAUCER_SCALE = 0.23

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
        direction_count = 64,
        frame_count = 1,
        scale = options.scale or SAUCER_SCALE,
        shift = options.shift or {0, 0},
        draw_as_shadow = options.draw_as_shadow,
        draw_as_glow = options.draw_as_glow,
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
saucer_leg.initial_movement_speed = 1
saucer_leg.movement_acceleration = 1
saucer_leg.base_position_selection_distance = 1
saucer_leg.movement_based_position_selection_distance = 1
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
saucer.create_ghost_on_death = false
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
saucer.minimap_representation = map_icon()
saucer.selected_minimap_representation = map_icon()
saucer.factoriopedia_simulation = {
    init = 'game.simulation.camera_zoom = 1.2\n'
        ..'game.simulation.camera_position = {0, -0.5}\n'
        ..'game.surfaces[1].create_entity{name = "ei-gaian-saucer", position = {0, 0}, force = "player"}\n'
}
saucer.graphics_set = {
    render_layer = "air-object",
    base_render_layer = "air-object",
    animation = {
        layers = {
            saucer_sprite(main_graphics_entity_path.."gaian-saucer/ei-gaian-saucer.png"),
            saucer_sprite(main_graphics_entity_path.."gaian-saucer/ei-gaian-saucer_glow.png", {
                draw_as_glow = true,
            }),
        },
    },
    shadow_animation = saucer_sprite(main_graphics_entity_path.."gaian-saucer/ei-gaian-saucer_shadow.png", {
        draw_as_shadow = true,
    }),
    light = {
        type = "basic",
        minimum_darkness = 0.25,
        intensity = 0.5,
        size = 18,
        color = {r = 0.25, g = 0.95, b = 0.55},
    },
}
saucer.spider_engine = {
    legs = {
        {
            leg = leg_name,
            mount_position = {0.65, -0.55},
            ground_position = {1.75, -1.55},
            walking_group = 1,
        },
        {
            leg = leg_name,
            mount_position = {0.65, 0.45},
            ground_position = {1.75, 1.45},
            walking_group = 2,
        },
        {
            leg = leg_name,
            mount_position = {-0.65, -0.55},
            ground_position = {-1.75, -1.55},
            walking_group = 2,
        },
        {
            leg = leg_name,
            mount_position = {-0.65, 0.45},
            ground_position = {-1.75, 1.45},
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
        ingredients = {
            {type = "item", name = "spidertron", amount = 1},
            {type = "item", name = "low-density-structure", amount = 50},
            {type = "item", name = "processing-unit", amount = 40},
            {type = "item", name = "ei-high-energy-crystal", amount = 80},
            {type = "item", name = "ei-alien-resin", amount = 100},
            {type = "item", name = "ei-bio-matter", amount = 100},
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
        prerequisites = {"ei-alien-computer-age-tech", "spidertron"},
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
        width = 10,
        height = 6,
    },
    saucer_leg,
    saucer,
})
