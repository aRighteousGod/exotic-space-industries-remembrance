local decorative_trigger_effects = require "__base__.prototypes.decorative.decorative-trigger-effects"
local hit_effects = require "__base__.prototypes.entity.hit-effects"
local sounds = require "__base__.prototypes.entity.sounds"


local picture = {
    filename = ei_path.."graphics/entity/camp-fire.png",
    width = 192,
    height = 192,
    scale = 0.5,
}


local fire = table.deepcopy(data.raw.fire["fire-flame"])
fire.name = "ei-small-fire"
fire.light.size = fire.light.size * 4
fire.tree_dying_factor = data.raw.fire["fire-flame-on-tree"].tree_dying_factor

data:extend{

    fire,

    -- entities

    {
        type = "furnace",
        name = "ei-camp-fire",
        icon = ei_path.."graphics/entity/camp-fire.png",
        icon_size = 128, icon_mipmaps = 2,
        minable = {mining_time = 0.1, result = "ei-camp-fire"},
        flags = {"placeable-neutral", "placeable-player", "player-creation", "placeable-off-grid"},
        integration_patch_render_layer = "ground-patch-higher2",
        collision_mask = { layers = {water_tile = true, transport_belt = true } },
        collision_box = {{-1.35, -1.35}, {1.35, 1.35}},
        selection_box = {{-1.50, -1.50}, {1.50, 1.50}},
        max_health = 200,
        repair_sound = sounds.manual_repair,
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg",volume = 0.8},
        open_sound = sounds.machine_open,
        close_sound = sounds.machine_close,
        damaged_trigger_effect = hit_effects.rock(),
        dying_trigger_effect = decorative_trigger_effects.huge_rock(),
        energy_usage = "50kW",
        crafting_speed = 1,
        crafting_categories = {"ei-burning"},
        source_inventory_size = 1,
        result_inventory_size = 2,
        resistances = {
            {
                type = "fire",
                percent = 100,
            },
        },
        energy_source = {
            type = "void",
            --fuel_categories = {"chemical"},
            --effectivity = 0.4,
            --fuel_inventory_size = 1,
            emissions_per_minute = { pollution = 3 },
            light_flicker = {
                color = {r=0.3, g=0, b=0},
                maximum_intensity = 1,
                minimum_intensity = 0.95,
                derivation_change_frequency = 0.6,
                minimum_light_size = 0.2,
                border_fix_speed = 0.01,
            },
            smoke = {
                {
                    name = "smoke",
                    frequency = 13,
                    deviation = {0.1, 0.1},
                    position  = {0.0, 0.0},
                    starting_vertical_speed = 0.08,
                    starting_frame_deviation = 60,
                },
            },
        },
        map_color = {r=0.32,g=0.23,b=0},
        integration_patch = {
            north = picture,
            east  = picture,
            west  = picture,
            south = picture,
        },
    },

    -- items

    {
        type = "item",
        name = "ei-camp-fire",
        icon = ei_path.."graphics/item/camp-fire.png",
        icon_size = 128, icon_mipmaps = 2,
        subgroup = "smelting-machine",
        order = "A",
        place_result = "ei-camp-fire",
        stack_size = 50,
    },

    -- recipes

    {
        type = "recipe",
        name = "ei-camp-fire",
        category = "crafting",
        ingredients = {{type="item", name="stone", amount=2}},
        results = {{type="item", name="ei-camp-fire", amount=1}},
        enabled=true,
    },

    -- categories

    {
        type = "recipe-category",
        name = "ei-burning",
    },
}
