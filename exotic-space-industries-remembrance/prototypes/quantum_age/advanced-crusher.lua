ei_data = require("lib/data")

--====================================================================================================
--ADVANCED CRUSHER
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-crusher",
        type = "item",
        icon = ei_graphics_item_path.."advanced-crusher.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-a-2",
        place_result = "ei-advanced-crusher",
        stack_size = 50
    },
    {
        name = "ei-advanced-crusher",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-crusher", amount=1},
            {type="item", name="ei-advanced-motor", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=6}
        },
        results = {{type="item", name="ei-advanced-crusher", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-advanced-crusher",
    },
    {
        name = "ei-advanced-crusher",
        type = "technology",
        icon = ei_graphics_tech_path.."advanced-crusher.png",
        icon_size = 256,
        prerequisites = {"ei-quantum-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-crusher"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        name = "ei-advanced-crusher",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."advanced-crusher.png",
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
            result = "ei-advanced-crusher"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-crushing"},
        crafting_speed = 2,
        energy_source = {
            type = 'electric',
            emissions_per_minute={pollution=4},
            usage_priority = 'secondary-input',
        },
        energy_usage = "1.4MW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."advanced-crusher.png",
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
                    filename = ei_graphics_entity_path.."advanced-crusher_animation.png",
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
        fast_replaceable_group = "ei-crusher",
        allowed_effects = {"speed", "productivity", "consumption", "pollution","quality"},
        module_slots = 2,
        working_sound =
        {
            sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
            apparent_volume = 0.3,
        },
    }
})