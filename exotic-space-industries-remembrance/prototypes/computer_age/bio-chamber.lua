ei_data = require("lib/data")

--====================================================================================================
--BIO CHAMBER
--====================================================================================================

data:extend({
    {
        name = "ei-bio-chamber",
        type = "recipe-category",
    },
    {
        name = "ei-bio-chamber",
        type = "item",
        icon = ei_graphics_item_path.."bio-chamber.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "a-a",
        place_result = "ei-bio-chamber",
        stack_size = 50
    },
    {
        name = "ei-bio-chamber",
        type = "technology",
        icon = ei_graphics_tech_path.."bio-chamber.png",
        icon_size = 256,
        prerequisites = {"ei-deep-pumpjack","ei-morphium-usage"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-chamber"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-alien-seed-growing"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-alien-seed-harvesting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-alien-resin-growing"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 20
        },
        -- age = "computer-age",
    },
    {
        name = "ei-bio-chamber",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="steel-plate", amount=6},
            {type="item", name="chemical-plant", amount=1},
            {type="item", name="ei-glass", amount=30},
            {type="item", name="ei-electronic-parts", amount=4}
        },
        results = {{type="item", name="ei-bio-chamber", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-bio-chamber",
    },
    {
        name = "ei-bio-chamber",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."bio-chamber.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-bio-chamber"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-bio-chamber"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            emissions_per_minute={pollution=20,spores=20},
            usage_priority = 'secondary-input',
        },
        energy_usage = "750kW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."bio-chamber.png",
                size = {512,512},
                width = 512,
                height = 512,
                shift = {0,-0.2},
    	        scale = 0.44/2,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                {
                  animation = 
                  {
                    filename = ei_graphics_entity_path.."bio-chamber_animation.png",
                    size = {512,512},
                    width = 512,
                    height = 512,
                    shift = {0,-0.2},
    	            scale = 0.44/2,
                    line_length = 4,
                    lines_per_file = 4,
                    frame_count = 16,
                    animation_speed = 0.6,
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
        allowed_effects = {"speed", "consumption", "pollution","quality"},
        module_slots = 1,
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_bio_chamber,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
                },
                production_type = "input",
            },

            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_bio_chamber,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.north, position = {0, -1}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_bio_chamber,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-1, 0}},
                },
                production_type = "output",
            },

            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_bio_chamber,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.south, position = {0, 1}},
                },
                production_type = "output",
            },
            -- off_when_no_fluid_recipe = true
        },
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 30, main_offset = util.by_pixel( 0.75,  25.625), shadow_offset = util.by_pixel( 0.75,  25.625), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.75,  25.625), shadow_offset = util.by_pixel( 0.75,  25.625), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.75,  25.625), shadow_offset = util.by_pixel( 0.75,  25.625), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.75,  25.625), shadow_offset = util.by_pixel( 0.75,  25.625), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    },
    {
        name = "ei-alien-seed-growing",
        type = "recipe",
        category = "ei-bio-chamber",
        energy_required = 20,
        ingredients = {
            {type = "fluid", name = "ei-oxygen-gas", amount = 50},
            {type = "fluid", name = "ei-phythogas", amount = 15},
            {type = "item", name = "ei-alien-seed", amount = 1},
            {type = "item", name = "ei-alien-resin", amount = 4},
        },
        results = {
            {type = "item", name = "ei-blooming-alien-seed", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-blooming-alien-seed",
    },
    {
        name = "ei-alien-seed-harvesting",
        type = "recipe",
        category = "ei-bio-chamber",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 100},
            {type = "item", name = "ei-blooming-alien-seed", amount = 1},
        },
        results = {
            {type = "item", name = "ei-alien-seed", amount_min = 1, amount_max = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-alien-seed",
    },
    {
        name = "ei-alien-resin-growing",
        type = "recipe",
        category = "ei-bio-chamber",
        energy_required = 20,
        ingredients = {
            {type = "fluid", name = "ei-phythogas", amount = 5},
            {type = "fluid", name = "ei-morphium", amount = 5},
            {type = "item", name = "ei-alien-seed", amount = 1},
        },
        results = {
            {type = "item", name = "ei-alien-resin", amount = 6},
            {type = "item", name = "ei-alien-seed", amount = 1, probability = 0.9},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-alien-resin",
    },
})