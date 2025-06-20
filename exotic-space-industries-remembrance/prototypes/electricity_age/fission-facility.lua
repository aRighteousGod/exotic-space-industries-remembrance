ei_data = require("lib/data")

ei_lib = require("lib/lib")

--====================================================================================================
--FISSION FACILITY
--====================================================================================================

data:extend({
    {
        name = "ei-fission-facility",
        type = "recipe-category",
    },
    {
        name = "ei-fission-facility",
        type = "item",
        icon = ei_graphics_item_path.."fission-facility.png",
        icon_size = 64,
        subgroup = "ei-nuclear-buildings",
        order = "a-a",
        place_result = "ei-fission-facility",
        stack_size = 50
    },
    {
        name = "ei-crushed-uranium",
        type = "item",
        icon = ei_graphics_item_path.."crushed-uranium.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "d1",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-uranium.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-uranium-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-uranium-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-uranium-3.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-crushed-pure-uranium",
        type = "item",
        icon = ei_graphics_item_path.."crushed-pure-uranium.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-purified",
        order = "c-a",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-pure-uranium.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-pure-uranium-1.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-pure-uranium-2.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-pure-uranium-3.png",
                icon_mipmaps = 4,
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-nuclear-waste",
        type = "item",
        icon = ei_graphics_item_path.."nuclear-waste.png",
        icon_size = 64,
        subgroup = "ei-refining-secondary",
        order = "d1",
        stack_size = 1,
    },
    {
        name = "ei-uranium-test-fuel",
        type = "item",
        icon = ei_graphics_item_path.."test-fuel.png",
        icon_size = 64,
        subgroup = "ei-nuclear-processing",
        order = "a-c-a",
        stack_size = 10,
    },
    {
        name = "ei-fission-tech",
        type = "item",
        icon = ei_graphics_item_path.."fission-tech.png",
        icon_size = 128,
        subgroup = "ei-nuclear-processing",
        order = "a-c-b",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."fission-tech.png",
                scale = 0.25/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."fission-tech_light.png",
                scale = 0.25/2
              }
            }
        },
    },
    {
        name = "ei-uranium-235-fuel",
        type = "item",
        icon = ei_graphics_item_path.."uranium-235-fuel.png",
        icon_size = 64,
        subgroup = "ei-nuclear-fission-fuel",
        order = "a-a-1",
        fuel_category = "ei-nuclear-fuel",
        fuel_value = "25GJ",
        burnt_result = "ei-used-uranium-235-fuel",
        stack_size = 10,
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."uranium-235-fuel.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."fission-fuel_light.png",
                scale = 0.25
              }
            }
        },
    },
    {
        name = "ei-used-uranium-235-fuel",
        type = "item",
        icon = ei_graphics_item_path.."used-uranium-235-fuel.png",
        icon_size = 64,
        subgroup = "ei-nuclear-fission-fuel",
        order = "a-a-2",
        stack_size = 10
    },
    {
        name = "ei-fission-facility",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="advanced-circuit", amount=40},
            {type="item", name="ei-lead-ingot", amount=50},
            {type="item", name="ei-energy-crystal", amount=25},
            {type="item", name="steel-plate", amount=50},
        },
        results = {{type="item", name="ei-fission-facility", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-fission-facility",
    },
    {
        name = "ei-fission-facility",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."fission-facility.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-fission-facility"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-fission-facility"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "8.8MW",
        allowed_effects = {"speed", "productivity", "consumption", "pollution"},
        module_slots = 4,
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."fission-facility.png",
                size = {512,512},
                shift = {-0.1, 0},
    	        scale = 0.38,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                {
                  animation = 
                  {
                    filename = ei_graphics_entity_path.."fission-facility_animation.png",
                    size = {512,512},
                    shift = {-0.1, 0},
    	            scale = 0.38,
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
                    intensity = 1,
                    size = 15
                    }
                }
            },
        },
        working_sound =
        {
            sound = {filename = "__base__/sound/nuclear-reactor-2.ogg", volume = 0.4},
            apparent_volume = 0.3,
        },
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation =  7, main_offset = util.by_pixel(-41.5,  12.875), shadow_offset = util.by_pixel(-41.5,  12.875), show_shadow = true },
            { variation =  7, main_offset = util.by_pixel(-41.5,  12.875), shadow_offset = util.by_pixel(-41.5,  12.875), show_shadow = true },
            { variation =  7, main_offset = util.by_pixel(-41.5,  12.875), shadow_offset = util.by_pixel(-41.5,  12.875), show_shadow = true },
            { variation =  7, main_offset = util.by_pixel(-41.5,  12.875), shadow_offset = util.by_pixel(-41.5,  12.875), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    },
    {
        name = "ei-uranium-ore",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-uranium-chunk", amount = 1},
        },
        results = {
            {type = "item", name = "uranium-ore", amount_min = 1, amount_max = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "uranium-ore",
    },

    {
        name = "ei-crushed-uranium",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "uranium-ore", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-uranium", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-uranium",
    },    
    {
        name = "ei-crushed-pure-uranium",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-crushed-uranium", amount = 25},
            {type = "fluid", name = "sulfuric-acid", amount = 5},
        },
        results = {
            {type = "item", name = "ei-crushed-pure-uranium", amount = 5},
            {type = "fluid", name = "ei-uranium-solution", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-pure-uranium",
    },
    {
        name = "ei-uranium-solution",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-uranium-solution", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 5},
            {type = "item", name = "ei-crushed-uranium", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-uranium",
        icon = ei_graphics_other_path.."uranium-solution.png",
        icon_size = 64,
        subgroup = "ei-refining-extraction",
        order = "g-a",
    },
    {
        name = "ei-uranium-hexafluorite",
        type = "recipe",
        category = "chemistry",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-crushed-pure-uranium", amount = 25},
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 100},
        },
        results = {
            {type = "fluid", name = "ei-uranium-hexafluorite", amount = 25},
            {type = "item", name = "ei-nuclear-waste", amount = 1, probability = 0.1},
            {type = "item", name = modprefix.."sand", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-uranium-hexafluorite",
    },
    {
        name = "ei-seperate-uranium",
        type = "recipe",
        category = "centrifuging",
        energy_required = 8,
        ingredients = {
            {type = "fluid", name = "ei-uranium-hexafluorite", amount = 100},
        },
        results = {
            {type = "fluid", name = "ei-uranium-hexafluorite", amount = 99},
            {type = "item", name = "uranium-235", amount = 1, probability = 0.0072},
            {type = "item", name = "uranium-238", amount = 1, probability = 0.9927},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."seperate-uranium.png",
        icon_size = 64,
        main_product = "uranium-235",
        subgroup = "ei-nuclear-processing",
        order = "a-a",
    },
    {
        name = "ei-uranium-235-fuel",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-lead-ingot", amount = 2},
            {type = "item", name = "ei-ceramic", amount = 10},
            {type = "item", name = "uranium-238", amount = 9},
            {type = "item", name = "uranium-235", amount = 1},
        },
        results = {
            {type = "item", name = "ei-uranium-235-fuel", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-uranium-235-fuel",
    },
    {
        name = "ei-uranium-test-fuel",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "ei-lead-ingot", amount = 4},
            {type = "item", name = "ei-ceramic", amount = 4},
            {type = "item", name = "uranium-238", amount = 10},
        },
        results = {
            {type = "item", name = "ei-uranium-test-fuel", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-uranium-test-fuel",
    },
    {
        name = "ei-fission-tech",
        type = "recipe",
        category = "ei-fission-facility",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "stone", amount = 4},
            {type = "item", name = "ei-uranium-test-fuel", amount = 1},
            {type = "item", name = "advanced-circuit", amount = 1},
            {type = "item", name = "ei-lead-ingot", amount = 2},
        },
        results = {
            {type = "item", name = "ei-fission-tech", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fission-tech",
    },
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-fission-facility"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-crushed-uranium"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-uranium-ore"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "uranium-processing"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-crushed-pure-uranium"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-uranium-hexafluorite"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-seperate-uranium"
})

table.insert(data.raw.technology["nuclear-power"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-uranium-235-fuel"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-uranium-test-fuel"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-fission-tech"
})

table.insert(data.raw.technology["uranium-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-uranium-solution"
})

ei_lib.remove_unlock_recipe("uranium-processing", "uranium-processing")
ei_lib.remove_unlock_recipe("uranium-processing", "uranium-fuel-cell")
