ei_data = require("lib/data")

--====================================================================================================
--ADVANCED CHEM PLANT
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-chem-plant",
        type = "recipe-category",
    },
    {
        name = "ei-advanced-chem-plant",
        type = "item",
        icon = ei_graphics_item_path.."advanced-chem-plant.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "e[chemical-plant]-a",
        place_result = "ei-advanced-chem-plant",
        stack_size = 50
    },
    {
        name = "ei-advanced-chem-plant",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="chemical-plant", amount=2},
            {type="item", name="ei-advanced-motor", amount=10},
            {type="item", name="storage-tank", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=8}
        },
        results = {{type="item", name="ei-advanced-chem-plant", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-advanced-chem-plant",
    },
    {
        name = "ei-advanced-chem-plant",
        type = "technology",
        icon = ei_graphics_tech_path.."advanced-chem-plant.png",
        icon_size = 256,
        prerequisites = {"automation-3"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-chem-plant"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-ceramic-water"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-plastic-crushed-coke"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-ceramic-water",
        type = "recipe",
        category = "ei-advanced-chem-plant",
        energy_required = 3,
        ingredients = {
            {type = "item", name = modprefix.."sand", amount = 6},
            {type = "fluid", name = "water", amount = 60}
        },
        results = {
            {type = "item", name = "ei-ceramic", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-ceramic",
    },
    {
        name = "ei-plastic-crushed-coke",
        type = "recipe",
        category = "ei-advanced-chem-plant",
        energy_required = 24,
        ingredients = {
            {type = "item", name = "ei-crushed-coke", amount = 8},
            {type = "fluid", name = "petroleum-gas", amount = 60},
            {type = "fluid", name = "light-oil", amount = 40}
        },
        results = {
            {type = "item", name = "plastic-bar", amount = 28},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "plastic-bar",
    },
    {
        name = "ei-advanced-chem-plant",
        type = "assembling-machine",
        crafting_categories = {"chemistry", "ei-advanced-chem-plant"},
        icon = ei_graphics_item_path.."advanced-chem-plant.png",
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
            result = "ei-advanced-chem-plant"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_speed = 3,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            emissions_per_minute = {pollution=8}
        },
        allowed_effects = {"speed", "consumption", "pollution", "productivity","quality"},
        module_slots = 4,
        energy_usage = "2.5MW",
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {2, 1}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {2, -1}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-2, 1}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-2, -1}},
                },
                production_type = "output",
            },
        },
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."advanced-chem-plant.png",
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
                    filename = ei_graphics_entity_path.."advanced-chem-plant_animation.png",
                    size = {512,512},
                    shift = {0, 0},
    	            scale = 0.35,
                    line_length = 4,
                    lines_per_file = 4,
                    frame_count = 16,
                    animation_speed = 0.5,
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
            sound = {filename = "__base__/sound/chemical-plant-3.ogg", volume = 0.2},
            apparent_volume = 0.1,
        },
    }
})