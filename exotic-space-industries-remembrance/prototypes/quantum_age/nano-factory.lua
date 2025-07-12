ei_data = require("lib/data")

--====================================================================================================
--NANO FACTORY
--====================================================================================================

data:extend({
    {
        name = "ei-nano-factory",
        type = "recipe-category",
    },
    {
        name = "ei-nano-factory",
        type = "item",
        icon = ei_graphics_item_path.."nano-factory.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-6",
        place_result = "ei-nano-factory",
        stack_size = 50
    },
    {
        name = "ei-nano-factory",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-advanced-motor", amount=20},
            {type="item", name="assembling-machine-3", amount=4},
            {type="item", name="processing-unit", amount=20},
            {type="item", name="ei-steel-mechanical-parts", amount=40}
        },
        results = {{type="item", name="ei-nano-factory", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-nano-factory",
    },
    {
        name = "ei-nano-factory",
        type = "technology",
        icon = ei_graphics_tech_path.."nano-factory.png",
        icon_size = 256,
        prerequisites = {"ei-quantum-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-nano-factory"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-coal"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-carbon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-carbon-nanotube"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-carbon-structure"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-nano-factory",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."nano-factory.png",
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
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-nano-factory"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        -- crafting_categories = {"ei-nano-factory", "crafting", "advanced-crafting", "crafting-with-fluid"},
        crafting_categories = {"ei-nano-factory"},
        crafting_speed = 2,
        energy_source = {
            type = 'electric',
            emissions_per_minute={pollution=8},
            usage_priority = 'secondary-input',
        },
        energy_usage = "80MW",
        allowed_effects = {"speed", "consumption", "pollution","quality"},
        module_slots = 8,
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
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-2, 0}},
                },
                production_type = "output",
            },
        },
        fluid_boxes_off_when_no_fluid_recipe = true,
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."nano-factory.png",
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
                    filename = ei_graphics_entity_path.."nano-factory_animation.png",
                    size = {512,512},
                    shift = {0, 0},
    	            scale = 0.35,
                    line_length = 4,
                    lines_per_file = 4,
                    frame_count = 16,
                    animation_speed = 0.1,
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
            sound = {filename = "__base__/sound/electric-furnace.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    },
    {
        name = "ei-crushed-coal",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "coal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-coal", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-coal",
    },
    {
        name = "ei-carbon",
        type = "recipe",
        category = "chemistry",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "carbon", amount = 1},
            {type = "item", name = "ei-ceramic", amount = 3},
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 15},
            {type = "fluid", name = "steam", amount = 100,min_temperature=900},
        },
        results = {
            {type = "item", name = "ei-carbon", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-carbon",
    },
    {
        name = "ei-carbon-nanotube",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 60,
        ingredients = {
            {type = "item", name = "ei-carbon", amount = 5},
            {type = "item", name = "ei-crushed-coke", amount = 2},
            {type = "fluid", name = "ei-nitric-acid", amount = 15},
        },
        results = {
            {type = "item", name = "ei-carbon-nanotube", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-carbon-nanotube",
    },
    {
        name = "ei-carbon-structure",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 120,
        ingredients = {
            {type = "item", name = "ei-carbon-nanotube", amount = 3},
            {type = "item", name = "low-density-structure", amount = 2},
            {type = "fluid", name = "ei-nitrogen-gas", amount = 100},
        },
        results = {
            {type = "item", name = "ei-carbon-structure", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-carbon-structure",
    },
})