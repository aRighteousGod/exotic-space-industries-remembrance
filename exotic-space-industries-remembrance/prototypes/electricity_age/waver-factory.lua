ei_data = require("lib/data")

--====================================================================================================
--WAVER FACTORY
--====================================================================================================

data:extend({
    {
        name = "ei-waver-factory",
        type = "recipe-category",
    },
    {
        name = "ei-waver-factory",
        type = "item",
        icon = ei_graphics_item_path.."waver-factory.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-b",
        place_result = "ei-waver-factory",
        stack_size = 50
    },
    {
        name = "ei-faulty-semiconductor",
        type = "item",
        icon = ei_graphics_item_path.."faulty-waver.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "b4",
        stack_size = 50
    },
    {
        name = "ei-semiconductor",
        type = "item",
        icon = ei_graphics_item_path.."waver.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "b3",
        stack_size = 50
    },
    {
        name = "ei-waver-factory",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="advanced-circuit", amount=10},
            {type="item", name="electric-engine-unit", amount=8},
            {type="item", name="steel-plate", amount=20},
            {type="item", name="small-lamp", amount=6}
        },
        results = {{type="item", name="ei-waver-factory", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-waver-factory",
    },
    {
        name = "ei-waver-factory",
        type = "technology",
        icon = ei_graphics_tech_path.."waver-factory.png",
        icon_size = 256,
        prerequisites = {"advanced-circuit", "ei-purifier", "lamp"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-waver-factory"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-semiconductor"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crush-faulty-semiconductor"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-waver-factory",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."waver-factory.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 14, main_offset = util.by_pixel( 0.875,  22.875), shadow_offset = util.by_pixel( 0.875,  22.875), show_shadow = true },
            { variation = 14, main_offset = util.by_pixel( 0.875,  22.875), shadow_offset = util.by_pixel( 0.875,  22.875), show_shadow = true },
            { variation = 14, main_offset = util.by_pixel( 0.875,  22.875), shadow_offset = util.by_pixel( 0.875,  22.875), show_shadow = true },
            { variation = 14, main_offset = util.by_pixel( 0.875,  22.875), shadow_offset = util.by_pixel( 0.875,  22.875), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-waver-factory"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-waver-factory"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "2.4MW",
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_electricity,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_electricity,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-1, 0}},
                },
                production_type = "output",
            },
        },
        fluid_boxes_off_when_no_fluid_recipe = true,
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."waver-factory.png",
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
                    filename = ei_graphics_entity_path.."waver-factory_animation.png",
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
        allowed_effects = {"speed", "productivity", "consumption", "pollution"},
        module_slots = 2,
        working_sound =
        {
            sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
            apparent_volume = 0.3,
        },
    },
    {
        name = "ei-semiconductor",
        type = "recipe",
        category = "ei-waver-factory",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 10},
            {type = "item", name = "ei-crushed-gold", amount = 5},
            {type = "item", name = modprefix.."sand", amount = 6},
        },
        results = {
            {type = "item", name = "ei-semiconductor", amount = 1, probability = 0.95},
            {type = "item", name = "ei-faulty-semiconductor", amount = 1, probability = 0.05},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-semiconductor",
    },
    {
        name = "ei-crush-faulty-semiconductor",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-faulty-semiconductor", amount = 1},
        },
        results = {
            {type = "item", name = modprefix.."sand", amount_min = 1,amount_max=4},
            {type = "item", name = "ei-crushed-gold", amount_min = 0,amount_max=2,probability=0.25}
        },
        always_show_made_in = true,
        allow_decomposition = false,
        enabled = false,
        main_product = modprefix.."sand",
    },
    {
        name = "ei-crush-faulty-advanced-semiconductor",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-faulty-advanced-semiconductor", amount = 1},
        },
        results = {
            {type = "item", name ="ei-energy-crystal", amount = 1,probability=0.10},
            {type = "item", name = "ei-crushed-gold", amount_min = 0,amount_max=2,probability=0.10},
            {type = "item", name = modprefix.."sand", amount_min = 1,amount_max=4},
        },
        always_show_made_in = true,
        allow_decomposition = false,
        enabled = false,
        main_product = "ei-sand",
    },
    {
        name = "ei-hydrofluoric-acid",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type="fluid", name="water", amount=100},
            {type="fluid", name="sulfuric-acid", amount=50},
            {type="item", name="ei-fluorite", amount=1},
        },
        results = {
            {type="fluid", name="ei-acidic-water", amount=25},
            {type="fluid", name="ei-hydrofluoric-acid", amount=100},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-hydrofluoric-acid",
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-a[ei_hydrofluoric-acid]",
    },
    
})