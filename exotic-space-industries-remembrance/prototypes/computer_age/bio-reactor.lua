ei_data = require("lib/data")

--====================================================================================================
--BIO REACTOR
--====================================================================================================

data:extend({
    {
        name = "ei-bio-reactor",
        type = "recipe-category",
    },
    {
        name = "ei-bio-reactor",
        type = "item",
        icon = ei_graphics_item_2_path.."bio-reactor.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "a-b",
        place_result = "ei-bio-reactor",
        stack_size = 50
    },
    {
        name = "ei-bio-reactor",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="chemical-plant", amount=2},
            {type="item", name="ei-bio-chamber", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=16}
        },
        results = {{type="item", name="ei-bio-reactor", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-bio-reactor",
    },
    {
        name = "ei-bio-reactor",
        type = "technology",
        icon = ei_graphics_tech_2_path.."bio-reactor.png",
        icon_size = 256,
        prerequisites = {"ei-alien-computer-age-tech"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-bio-reactor"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-evolved-alien-seed"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-blooming-evolved-alien-seed"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-bio-sludge"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-bio-matter"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "alien-computer-age",
    },
    {
        name = "ei-bio-reactor",
        type = "assembling-machine",
        crafting_categories = {"ei-bio-chamber", "ei-bio-reactor"},
        icon = ei_graphics_item_2_path.."bio-reactor.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-bio-reactor"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_speed = 2,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
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
                filename = ei_graphics_entity_2_path.."bio-reactor.png",
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
                    filename = ei_graphics_entity_2_path.."bio-reactor_animation.png",
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