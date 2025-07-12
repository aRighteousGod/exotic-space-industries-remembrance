ei_data = require("lib/data")

--====================================================================================================
--COOLER
--====================================================================================================

data:extend({
    {
        name = "ei-cooler",
        type = "recipe-category",
    },
    {
        name = "ei-cooler",
        type = "item",
        icon = ei_graphics_item_path.."cooler.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-4",
        place_result = "ei-cooler",
        stack_size = 50
    },
    {
        name = "ei-cooler",
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
        results = {{type="item", name="ei-cooler", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-cooler",
    },
    {
        name = "ei-liquid-nitrogen",
        type = "recipe",
        category = "ei-cooler",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 50},
        },
        results = {
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-liquid-nitrogen",
    },

    {
        name = "ei-liquid-oxygen",
        type = "recipe",
        category = "ei-cooler",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-oxygen-gas", amount = 50},
        },
        results = {
            {type = "fluid", name = "ei-liquid-oxygen", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-liquid-oxygen",
    },

    {
        name = "ei-liquid-ammonia",
        type = "recipe",
        category = "ei-cooler",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-ammonia-gas", amount = 100},
        },
        results = {
            {type = "fluid", name = "ammonia", amount = 10},
        },
        always_show_made_in = true,
        hide_from_player_crafting = true,
        enabled = false,
        main_product = "ammonia",
    },


    {
        name = "ei-cooler",
        type = "technology",
        icon = ei_graphics_tech_path.."cooler.png",
        icon_size = 256,
        prerequisites = {"ei-computer-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-cooler"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-liquid-nitrogen"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-nitrogen-gas"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-liquid-ammonia"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-nitrogen-gas-vent"
            },
            --[[
            {
                type = "unlock-recipe",
                recipe = "ei-extract-water"
            },
            ]]
            {
                type = "unlock-recipe",
                recipe = "ei-steam-vent"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lufter"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-insulated-pipe"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-insulated-underground-pipe"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-insulated-tank"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        age = "computer-age",
    },
    {
        name = "ei-cooler",
        type = "furnace",
        result_inventory_size = 1,
        source_inventory_size = 0,
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
        crafting_categories = {"ei-cooler"},
        icon = ei_graphics_item_path.."cooler.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-cooler"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            emissions_per_minute={pollution=8},
            usage_priority = 'secondary-input',
        },
        allowed_effects = {"speed", "consumption", "pollution"},
        module_slots = 3,
        energy_usage = "5000kW",
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
                pipe_picture = ei_pipe_big_insulated,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-2, 0}},
                },
                production_type = "output",
            },
        },
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."cooler.png",
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
                    filename = ei_graphics_entity_path.."cooler_animation.png",
                    size = {512,512},
                    shift = {0, 0},
    	            scale = 0.35,
                    line_length = 1,
                    lines_per_file = 1,
                    frame_count = 1,
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