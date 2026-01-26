ei_data = require("lib/data")

--====================================================================================================
--SMALL SIMULATOR
--====================================================================================================

data:extend({
    {
        name = "ei-small-simulator",
        type = "recipe-category",
    },
    {
        name = "ei-small-simulator",
        type = "item",
        icon = ei_graphics_item_path.."small-simulator.png",
        icon_size = 64,
        subgroup = "ei-labs",
        order = "b2",
        place_result = "ei-small-simulator",
        stack_size = 50
    },
    {
        name = "ei-simulation-data",
        type = "item",
        icon = ei_graphics_item_path.."simulation-data.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-b",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."simulation-data.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-simulation-data-chemical",
        type = "item",
        icon = ei_graphics_3_path.."graphics/items/simulation-data-chemical.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-c",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_3_path.."graphics/items/simulation-data-chemical.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-simulation-data-organic",
        type = "item",
        icon = ei_graphics_3_path.."graphics/items/simulation-data-organic.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-d",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_3_path.."graphics/items/simulation-data-organic.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-simulation-data-stone",
        type = "item",
        icon = ei_graphics_3_path.."graphics/items/simulation-data-stone.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-e",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_3_path.."graphics/items/simulation-data-stone.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-simulation-data-uranium",
        type = "item",
        icon = ei_graphics_3_path.."graphics/items/simulation-data-uranium.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-f",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_3_path.."graphics/items/simulation-data-uranium.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-simulation-data-petrified",
        type = "item",
        icon = ei_graphics_3_path.."graphics/items/simulation-data-petrified.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-g",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_3_path.."graphics/items/simulation-data-petrified.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-simulation-data-scrap",
        type = "item",
        icon = ei_graphics_3_path.."graphics/items/simulation-data-scrap.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-h",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_3_path.."graphics/items/simulation-data-scrap.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."simulation-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-space-data",
        type = "item",
        icon = ei_graphics_item_path.."space-data.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-c",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."space-data.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."space-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },
    {
        name = "ei-small-simulator",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="ei-electronic-parts", amount=4},
            {type="item", name="ei-advanced-motor", amount=8},
            {type="item", name="steel-plate", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=12}
        },
        results = {{type="item", name="ei-small-simulator", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-small-simulator",
    },
    {
        name = "ei-small-simulator",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."small-simulator.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 25, main_offset = util.by_pixel(-37.625,  25.875), shadow_offset = util.by_pixel(-37.625,  25.875), show_shadow = true },
            { variation = 25, main_offset = util.by_pixel(-37.625,  25.875), shadow_offset = util.by_pixel(-37.625,  25.875), show_shadow = true },
            { variation = 25, main_offset = util.by_pixel(-37.625,  25.875), shadow_offset = util.by_pixel(-37.625,  25.875), show_shadow = true },
            { variation = 25, main_offset = util.by_pixel(-37.625,  25.875), shadow_offset = util.by_pixel(-37.625,  25.875), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-small-simulator"
        },
        max_health = 300,
        corpse = "big-remnants",
        heating_energy = "200kW",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-small-simulator"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        --fixed_recipe = "ei-simulation-data",
        energy_usage = "3MW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."small-simulator.png",
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
                    filename = ei_graphics_entity_path.."small-simulator_animation.png",
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
                pipe_picture = ei_pipe_data,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {1, 0}},
                },
                production_type = "input",
            },
            -- off_when_no_fluid_recipe = true
        },
    },
    {
        name = "ei-simulation-data",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data",
    },
    --anomalies
    {
        name = "ei-simulation-data-chemical",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power-chemical", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data-chemical", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data-chemical",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
    },
    {
        name = "ei-simulation-data-organic",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power-organic", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data-organic", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data-organic",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
    },
    {
        name = "ei-simulation-data-stone",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power-stone", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data-stone", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data-stone",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
    },
    {
        name = "ei-simulation-data-uranium",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power-uranium", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data-uranium", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data-uranium",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
    },
    {
        name = "ei-simulation-data-petrified",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power-petrified", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data-petrified", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data-petrified",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
    },
    {
        name = "ei-simulation-data-scrap",
        type = "recipe",
        category = "ei-small-simulator",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power-scrap", amount = 4},
        },
        results = {
            {type = "item", name = "ei-simulation-data-scrap", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-simulation-data-scrap",
		surface_conditions =
        {
           {
              property = "gravity",
              min = 0,
              max = 0
            }
        },
    },

})