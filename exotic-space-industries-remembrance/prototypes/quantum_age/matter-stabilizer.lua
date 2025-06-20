ei_data = require("lib/data")

--====================================================================================================
--MATTER STABILIZER
--====================================================================================================

data:extend({
    {
        name = "ei-matter-stabilizer",
        type = "recipe-category",
    },
    {
        name = "ei-matter-stabilizer",
        type = "item",
        icon = ei_graphics_item_path.."matter-stabilizer.png",
        icon_size = 64,
        subgroup = "ei-labs",
        order = "b4",
        place_result = "ei-matter-stabilizer",
        stack_size = 10
    },
    {
        name = "ei-matter-stabilizer",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-advanced-motor", amount=10},
            {type="item", name="ei-high-tech-parts", amount=16},
            {type="item", name="ei-carbon-structure", amount=20},
            {type="item", name="ei-odd-plating", amount=20}
        },
        results = {{type="item", name="ei-matter-stabilizer", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-matter-stabilizer",
    },
    {
        name = "ei-matter-stabilizer",
        type = "technology",
        icon = ei_graphics_tech_path.."matter-stabilizer.png",
        icon_size = 256,
        prerequisites = {"ei-high-tech-parts"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-matter-stabilizer"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["both-quantum-age"],
            time = 20
        },
        age = "both-quantum-age",
    },
    {
        name = "ei-matter-stabilizer",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."matter-stabilizer.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 30, main_offset = util.by_pixel( 3.875,  33.375), shadow_offset = util.by_pixel( 3.875,  33.375), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 3.875,  33.375), shadow_offset = util.by_pixel( 3.875,  33.375), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 3.875,  33.375), shadow_offset = util.by_pixel( 3.875,  33.375), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 3.875,  33.375), shadow_offset = util.by_pixel( 3.875,  33.375), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-matter-stabilizer"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        fixed_recipe = "ei-matter-stabilizer-running",
        crafting_categories = {"ei-matter-stabilizer"},
        crafting_speed = 2,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "10MW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."matter-stabilizer.png",
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
                    filename = ei_graphics_entity_path.."matter-stabilizer_animation.png",
                    size = {512,512},
                    shift = {0, 0},
    	            scale = 0.35,
                    line_length = 4,
                    lines_per_file = 4,
                    frame_count = 16,
                    animation_speed = 0.3,
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
        radius_visualisation_specification = {
            sprite = {
                filename = ei_graphics_other_path.."radius.png",
                width = 256,
                height = 256
            },
            distance = ei_data.matter_stabilizer.matter_range
        },
    },
    {
        name = "ei-matter-stabilizer-running",
        type = "recipe",
        category = "ei-matter-stabilizer",
        energy_required = 1000,
        ingredients = {},
        results = {},
        enabled = false,
        hidden = true,
        icon = ei_graphics_other_path.."matter-stabilizer.png",
        icon_size = 64,
        subgroup = "ei-labs",
        order = "b4",
    },
    {
        type = "sprite",
        name = "ei-stabilizer-radius",
        filename = ei_graphics_other_path.."radius.png",
        width = 256,
        height = 256
    },
})