ei_data = require("lib/data")

--====================================================================================================
--GROWER
--====================================================================================================

data:extend({
    {
        name = "ei-growing",
        type = "recipe-category",
    },
    {
        name = "ei-grower",
        type = "item",
        icon = ei_graphics_item_path.."grower.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-1",
        place_result = "ei-grower",
        stack_size = 50
    },
    {
        name = "ei-energy-crystal",
        type = "item",
        icon = ei_graphics_item_path.."energy-crystal.png",
        icon_size = 64,
        subgroup = "raw-material",
        order = "g",
        stack_size = 100
    },
    {
        name = "ei-grower",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="chemical-plant", amount=1},
            {type="item", name="electric-engine-unit", amount=6},
            {type="item", name="storage-tank", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=8}
        },
        results = {{type="item", name="ei-grower", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-grower",
    },
    {
        name = "ei-energy-crystal-washing",
        type = "recipe",
        category = "chemistry",
        energy_required = 15,
        ingredients = {
            {type = "fluid", name = "sulfuric-acid", amount = 100},
            {type = "fluid", name = "steam", amount = 50},
            {type = "item", name = modprefix.."sand", amount = 10},
        },
        results = {
            {type = "item", name = modprefix.."sand", amount = 9},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability = 0.1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-energy-crystal",
    },
    {
        name = "ei-energy-crystal-growing",
        type = "recipe",
        category = "ei-growing",
        energy_required = 15,
        ingredients = {
            {type = "fluid", name = "ei-acidic-water", amount = 15},
            {type = "item", name = "ei-energy-crystal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-energy-crystal", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-energy-crystal",
    },
    {
        name = "ei-grower",
        type = "technology",
        icon = ei_graphics_tech_path.."grower.png",
        icon_size = 256,
        prerequisites = {"sulfur-processing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-grower"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-energy-crystal-growing"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-energy-crystal-washing"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-grower",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."grower.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-grower"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-growing"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "1.6MW",
        allowed_effects = {"speed", "consumption", "pollution"},
        module_slots = 2,
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {2, 0}},
                },
                production_type = "input",
            },
        },
        fluid_boxes_off_when_no_fluid_recipe = true,
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."grower.png",
                size = {512,512},
                shift = {0, 0},
    	        scale = 0.35,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                {
                  animation = 
                  {
                    filename = ei_graphics_entity_path.."grower_animation.png",
                    size = {512,512},
                    shift = {0, 0},
    	            scale = 0.35,
                    line_length = 6,
                    lines_per_file = 6,
                    frame_count = 36,
                    animation_speed = 0.4,
                    run_mode = "backward",
                  }
                },
                {
                    light = {
                    type = "basic",
                    intensity = 1,
                    size = 15
                    }
                }
            },
        },
        working_sound =
        {
            sound = {filename = "__base__/sound/chemical-plant-3.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    }
})