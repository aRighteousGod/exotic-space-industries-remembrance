ei_data = require("lib/data")

--====================================================================================================
--ADVANCED REFINERY
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-refinery",
        type = "recipe-category",
    },
    {
        name = "ei-advanced-refinery",
        type = "item",
        icon = ei_graphics_item_path.."advanced-refinery.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d[refinery]-a",
        place_result = "ei-advanced-refinery",
        stack_size = 50
    },
    {
        name = "ei-advanced-refinery",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="oil-refinery", amount=2},
            {type="item", name="ei-advanced-motor", amount=10},
            {type="item", name="storage-tank", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=8}
        },
        results = {{type="item", name="ei-advanced-refinery", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-advanced-refinery",
    },
    {
        name = "ei-advanced-refinery",
        type = "technology",
        icon = ei_graphics_tech_path.."advanced-refinery.png",
        icon_size = 1024,
        prerequisites = {"ei-advanced-chem-plant", "ei-cooler"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-refinery"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-destill-tower"
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
        name = "ei-advanced-refinery",
        type = "assembling-machine",
        crafting_categories = {"oil-processing", "ei-advanced-refinery"},
        icon = ei_graphics_item_path.."advanced-refinery.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 34, main_offset = util.by_pixel( 27.75, -14.75), shadow_offset = util.by_pixel( 27.75, -14.75), show_shadow = true },
            { variation = 34, main_offset = util.by_pixel( 27.75, -14.75), shadow_offset = util.by_pixel( 27.75, -14.75), show_shadow = true },
            { variation = 34, main_offset = util.by_pixel( 27.75, -14.75), shadow_offset = util.by_pixel( 27.75, -14.75), show_shadow = true },
            { variation = 34, main_offset = util.by_pixel( 27.75, -14.75), shadow_offset = util.by_pixel( 27.75, -14.75), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-advanced-refinery"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-3.4, -3.4}, {3.4, 3.4}},
        selection_box = {{-3.5, -3.5}, {3.5, 3.5}},
        map_color = ei_data.colors.assembler,
        crafting_speed = 3,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            emissions_per_minute = {pollution = 10 },
        },
        allowed_effects = {"speed", "consumption", "pollution", "productivity"},
        module_slots = 4,
        energy_usage = "500kW",
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {3, 1}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {3, -1}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-3, 1}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-3, -1}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.south, position = {1, 3}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.south, position = {-1, 3}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.north, position = {1, -3}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.north, position = {-1, -3}},
                },
                production_type = "output",
            },
        },
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."advanced-refinery.png",
                size = {512*2, 512*2},
                shift = {0, -0.35},
    	        scale = 0.51,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                {
                  animation = 
                  {
                    filename = ei_graphics_entity_path.."advanced-refinery_animation.png",
                    size = {512*2, 512*2},
                    shift = {0, -0.35},
    	            scale = 0.51,
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
            sound = {filename = "__base__/sound/oil-refinery.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    }
})