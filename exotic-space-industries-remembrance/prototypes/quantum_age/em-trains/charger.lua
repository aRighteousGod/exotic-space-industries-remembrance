--====================================================================================================
--CHARGER
--====================================================================================================



data:extend({

    {
        name = "ei_charger",
        type = "item",
        icon = ei_trains_item_path.."charger.png",
        icon_size = 64,
        subgroup = "transport",
        order = "x4",
        place_result = "ei_charger",
        stack_size = 1
    },
    {
        name = "ei_charger",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients =
        {
          {type="item", name="ei-copper-beacon", amount=6},
          {type="item", name="processing-unit", amount=25},
          {type="item", name="ei_em-fielder", amount=2},
        },
        results = {{type="item", name="ei_charger", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_charger",
    },
    {
        name = "ei_charger",
        type = "electric-energy-interface",
        --type = "assembling-machine",
        icon = ei_trains_item_path.."charger.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 4,
            result = "ei_charger"
        },
        max_health = 1000,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = {r = 1, g = 0.67, b = 0.3},
        -- fixed_recipe = "ei_charger:running",
        crafting_categories = {"ei_charger"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            buffer_capacity = "1GJ",
            output_flow_limit = "0W",
        },
        energy_usage = "10MW",
        --[[
        animation = {
            filename = ei_trains_entity_path.."charger.png",
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
                filename = ei_trains_entity_path.."charger_animation.png",
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
        ]]
        animation = {
            filename = ei_trains_entity_path.."charger_animation.png",
            size = {512,512},
            shift = {0, 0},
            scale = 0.35,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.3,
            run_mode = "backward",
        },
        gui_mode = "none",
        continuous_animation = true,
        radius_visualisation_specification = {
            sprite = {
                filename = ei_trains_entity_path.."radius.png",
                width = 256,
                height = 256
            },
            distance = 96
        },
    },
    --[[
    {
        name = "ei_charger:running",
        type = "recipe",
        category = "ei_charger",
        energy_required = 1000,
        ingredients = {},
        results = {},
        result_count = 1,
        enabled = false,
        hidden = true,
        icon = ei_trains_item_path.."charging.png",
        icon_size = 64,
        subgroup = "transport",
        order = "x4",
    },
    {
        name = "ei_charger",
        type = "recipe-category",
    },
    ]]
})