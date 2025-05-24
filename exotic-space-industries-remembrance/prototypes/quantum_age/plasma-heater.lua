ei_data = require("lib/data")

--====================================================================================================
--PLASMA HEATER
--====================================================================================================
local plasma_heater_glow = {
    type = "sprite",
    name = "plasma_heater_glow",
    filename = ei_graphics_glow_path.."small_pngs/frame_count_3/glow_3_25.png",
    priority = "high",
    width = 205,
    height = 207,
    scale = 1,
    frame_count = 3,
    animation_speed = 20,
}

data:extend({
        plasma_heater_glow,
    {
        name = "ei-plasma-heater",
        type = "recipe-category",
    },
    {
        name = "ei-plasma-heater",
        type = "item",
        icon = ei_graphics_item_path.."plasma-heater.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-5",
        place_result = "ei-plasma-heater",
        stack_size = 50
    },
    {
        name = "ei-plasma-heater",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-insulated-tank", amount=2},
            {type="item", name="ei-arc-furnace", amount=1},
            {type="item", name="ei-magnet", amount=20},
            {type="item", name="ei-steel-mechanical-parts", amount=18}
        },
        results = {{type="item", name="ei-plasma-heater", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-plasma-heater",
    },
    {
        name = "ei-plasma-heater",
        type = "technology",
        icon = ei_graphics_tech_path.."plasma-heater.png",
        icon_size = 256,
        prerequisites = {"ei-quantum-computer"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-plasma-heater"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-protium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-heated-protium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-heated-deuterium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-heated-tritium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-heated-helium-3"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-plasma-data-protium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-plasma-data-deuterium"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-plasma-data-tritium"
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
        name = "ei-plasma-heater",
        type = "furnace",
        icon = ei_graphics_item_path.."plasma-heater.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-plasma-heater"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-arc-furnace", "ei-plasma-heater"},
        crafting_speed = 1.25,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            emissions_per_minute = { pollution = 3 },
            drain = "24MW"
        },
        energy_usage = "70MW",
        result_inventory_size = 1,
        source_inventory_size = 1,
        allowed_effects = {"speed", "consumption", "pollution","quality"},
        module_slots = 2,
        fluid_boxes = {
            
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big_insulated,
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
        fluid_boxes_off_when_no_fluid_recipe = true,
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."plasma-heater.png",
                size = {512,512},
                shift = {0, 0},
    	        scale = 0.35,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                -- Simulate always-on energy draw Violet core glow
                {
                    always_draw = true,
                    animation = {
                        filename = ei_graphics_glow_path.."plasma-heater-glow-pulse-purple.png",
                        width = 64,
                        height = 64,
                        frame_count = 4,
                        scale = 4.4,
                        shift = {0, 0},
                        blend_mode = "additive",
                        draw_as_glow = true,
                        animation_speed = 0.4
                    },
                    light = {
                        intensity = 0.4,
                        size = 6,
                        color = {r = 0.6, g = 0.1, b = 0.12},
                        blend_mode = "additive",
                        apply_runtime_tint = true
                    }
                },
                -- Yellow outer aura
                {
                    always_draw = true,
                    animation = {
                        filename = ei_graphics_glow_path.."plasma-heater-glow-pulse-yellow.png",
                        width = 64,
                        height = 64,
                        frame_count = 4,
                        scale = 6.4,
                        shift = {0, 0},
                        blend_mode = "additive",
                        draw_as_glow = true,
                        animation_speed = 0.25
                    },
                    light = {
                        intensity = 0.3,
                        size = 6,
                        color = {r = 1, g = 0.85, b = 0.1},
                        apply_runtime_tint = true
                    }
                },
                {
                    animation = {
                        filename = ei_graphics_entity_path.."plasma-heater_animation.png",
                        size = {512, 512},
                        shift = {0, 0},
                        scale = 0.35,
                        line_length = 4,
                        lines_per_file = 4,
                        frame_count = 16,
                        animation_speed = 0.4,
                        run_mode = "backward",
                    }
                },
                {
                    light = {
                        type = "basic",
                        sprite = "plasma_heater_glow",
                        flicker_interval = 15,
                        flicker_min_modifier = 0.4,
                        flicker_max_modifier = 0.9,
                        offset_flicker = true,
                        intensity = 0.9,
                        size = 22,
                        color = {r = 0.1, g = 0.4, b = 1.0},
                        blend_mode = "multiplicative",
                        apply_runtime_tint = true,
                        draw_as_glow = true,
                    }
                },
                {
                    light = {
                        type = "basic",
                        sprite = "plasma_heater_glow",
                        flicker_interval = 12,
                        flicker_min_modifier = 0.2,
                        flicker_max_modifier = 0.8,
                        offset_flicker = true,
                        intensity = 1.0,
                        size = 22,
                        color = {r = 1.0, g = 0.4, b = 0.0},
                        blend_mode = "multiplicative",
                        apply_runtime_tint = true,
                        draw_as_glow = true,
                    }
                },
                {
                    light = {
                        type = "basic",
                        sprite = "plasma_heater_glow",
                        flicker_interval = 10,
                        flicker_min_modifier = 0.1,
                        flicker_max_modifier = 1,
                        offset_flicker = true,
                        intensity = 0.7,
                        size = 16,
                        color = {r = 1.0, g = 0.5, b = 1.0},
                        blend_mode = "multiplicative",
                        apply_runtime_tint = true,
                    }
                },
                {
                    light = {
                        type = "basic",
                        sprite = "plasma_heater_glow",
                        flicker_interval = 20,
                        flicker_min_modifier = 0.3,
                        flicker_max_modifier = 0.5,
                        offset_flicker = true,
                        intensity = 0.5,
                        size = 24,
                        color = {r = 1, g = 0.8, b = 1.0},
                        blend_mode = "multiplicative",
                        apply_runtime_tint = true,
                        draw_as_glow = true,
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
        name = "ei-protium",
        type = "recipe",
        category = "oil-processing",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-hydrogen-gas", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-protium", amount = 10, probability = 0.9998},
            {type = "fluid", name = "ei-deuterium", amount = 10, probability = 0.001},
            {type = "fluid", name = "ei-tritium", amount = 10, probability = 0.0001},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-protium",
    },
    {
        name = "ei-heated-protium",
        type = "recipe",
        category = "ei-plasma-heater",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-protium", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-heated-protium", amount = ei_data.fusion.plasma_per_unit},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-heated-protium",
    },
    {
        name = "ei-heated-deuterium",
        type = "recipe",
        category = "ei-plasma-heater",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-deuterium", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-heated-deuterium", amount = ei_data.fusion.plasma_per_unit},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-heated-deuterium",
    },
    {
        name = "ei-heated-tritium",
        type = "recipe",
        category = "ei-plasma-heater",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-tritium", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-heated-tritium", amount = ei_data.fusion.plasma_per_unit},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-heated-tritium",
    },
    {
        name = "ei-heated-helium-3",
        type = "recipe",
        category = "ei-plasma-heater",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-helium-3", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-heated-helium-3", amount = ei_data.fusion.plasma_per_unit},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-heated-helium-3",
    },
    {
        name = "ei-plasma-data",
        type = "item",
        icon = ei_graphics_item_path.."plasma-data.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "a-a-e",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."plasma-data.png",
                scale = 0.25/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."plasma-data_light.png",
                scale = 0.25/2
              }
            }
          },
    },
    {
        name = "ei-plasma-data-protium",
        type = "recipe",
        category = "ei-quantum-computer",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power", amount = 100},
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
            {type = "fluid", name = "ei-heated-protium", amount = 80},
            {type = "item", name = "stone", amount = 20},
        },
        results = {
            {type = "item", name = "ei-plasma-data", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-plasma-data",
    },
    {
        name = "ei-plasma-data-deuterium",
        type = "recipe",
        category = "ei-quantum-computer",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power", amount = 100},
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
            {type = "fluid", name = "ei-heated-deuterium", amount = 1},
            {type = "item", name = "stone", amount = 20},
        },
        results = {
            {type = "item", name = "ei-plasma-data", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-plasma-data",
    },
    {
        name = "ei-plasma-data-tritium",
        type = "recipe",
        category = "ei-quantum-computer",
        energy_required = 5,
        ingredients = {
            {type = "fluid", name = "ei-computing-power", amount = 100},
            {type = "fluid", name = "ei-liquid-nitrogen", amount = 100},
            {type = "fluid", name = "ei-heated-tritium", amount = 1},
            {type = "item", name = "stone", amount = 20},
        },
        results = {
            {type = "item", name = "ei-plasma-data", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-plasma-data",
    },
})