ei_data = require("lib/data")

--====================================================================================================
--EXCAVATOR
--====================================================================================================

data:extend({
    {
        name = "ei-excavator",
        type = "recipe-category",
    },
    {
        name = "ei-excavator",
        type = "item",
        icon = ei_graphics_item_2_path.."excavator.png",
        icon_size = 64,
        subgroup = "extraction-machine",
        order = "a[items]-a[stone-quarry]-b",
        place_result = "ei-excavator",
        stack_size = 50
    },
    {
        name = "ei-excavator",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients =
        {
            {type="item", name="ei-electric-quarry", amount=4},
            {type="item", name="ei-advanced-motor", amount=8},
            {type="item", name="steel-plate", amount=12},
            {type="item", name="ei-steel-beam", amount=12},
            {type="item", name="ei-steel-mechanical-parts", amount=40}
        },
        results = {{type="item", name="ei-excavator", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-excavator",
    },
    {
        name = "ei-excavator",
        type = "technology",
        icon = ei_graphics_tech_2_path.."excavator.png",
        icon_size = 256,
        prerequisites = {"ei-advanced-computer-age-tech"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-excavator"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-excavator-running-nauvis"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["advanced-computer-age"],
            time = 20
        },
        age = "advanced-computer-age",
    },
    {
        name = "ei-excavator",
        type = "assembling-machine",
        crafting_categories = {"ei-excavator"},
        icon = ei_graphics_item_2_path.."excavator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 2,
            result = "ei-excavator"
        },
        max_health = 1000,
		surface_conditions =
        {
           {
              property = "gravity",
              min = 1,
              max = 100
            }
        },
        --fixed_recipe = "ei-excavator-running",
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-5.4, -5.4}, {5.4, 5.4}},
        selection_box = {{-5.5, -5.5}, {5.5, 5.5}},
        map_color = ei_data.colors.assembler,
        crafting_speed = 1,
        heating_energy = "300kW",
        energy_source = {
            type = 'electric',
            emissions_per_minute={pollution=25},
            usage_priority = 'secondary-input',
        },
        allowed_effects = {"speed", "consumption", "pollution", "quality"},
        module_slots = 2,
        energy_usage = "3MW",
        fluid_boxes = {
            {   
                --filter = "",
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big_round,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {5, 0}},
                },
                production_type = "input",
            },
            {   
                --filter = "",
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big_round,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.south, position = {0, 5}},
                },
                production_type = "input",
            },
            {   
                --filter = "",
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big_round,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-5, 0}},
                },
                production_type = "output",
            },
            {   
                --filter = "",
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big_round,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.north, position = {0, -5}},
                },
                production_type = "output",
            },
        },
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_2_path.."excavator.png",
                size = {512*2,512*2},
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
                    filename = ei_graphics_entity_2_path.."excavator_animation.png",
                    size = {512*2,512*2},
                    shift = {0, 0},
    	            scale = 0.35,
                    line_length = 3,
                    lines_per_file = 3,
                    frame_count = 9,
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
            sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
            apparent_volume = 0.1,
        },
    },
    {
        name = "ei-excavator-running-nauvis",
        type = "recipe",
        category = "ei-excavator",
        energy_required = 6,
        ingredients = {
            {type = "fluid", name = "water", amount = 20},
            {type = "fluid", name = "ei-drill-fluid", amount = 25},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 10, amount_max=20},
            {type = "item", name = "stone", amount_min = 15*3, amount_max = 15*5,probability=0.99}, -- yellow belt
            {type = "item", name = "ei-uranium-chunk", amount_min = 1, amount_max = 2,probability=0.04},
            {type = "item", name = "ei-gold-chunk", amount_min = 1, amount_max = 3,probability=0.08},
            {type = "item", name = "ei-sulfur-chunk", amount_min = 1, amount_max = 3,probability=0.11},
            {type = "item", name = "ei-iron-chunk", amount_min = 1, amount_max = 5,probability=0.22},
            {type = "item", name = "ei-copper-chunk", amount_min = 1, amount_max = 4,probability=0.18},
            {type = "item", name = "ei-coal-chunk", amount_min = 1, amount_max = 3,probability=0.12},
            {type = "item", name = "ei-neodym-chunk", amount_min = 1, amount_max = 2,probability=0.02}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        surface_conditions =
        {
           {
              property = "magnetic-field",
              min = 90,
              max = 90
            }
        },
    },
    {
        name = "ei-excavator-running-fulgora",
        type = "recipe",
        category = "ei-excavator",
        energy_required = 25,
        ingredients = {
            {type = "fluid", name = "water", amount = 20},
            {type = "fluid", name = "ei-drill-fluid", amount = 105},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 5,amount_max=20},
            {type = "fluid", name = "crude-oil", amount_min = 15, amount_max = 60, probability=0.33},
            {type = "item", name = "stone", amount_min = 15*1, amount_max = 15*2,probability=0.6},
            {type = "item", name = "ei-sand", amount_min = 30, amount_max = 45, probability=0.85},
            {type = "item", name = "scrap", amount_min = 15, amount_max = 30, probability=0.9},
            {type = "item", name = "holmium-ore", amount_min = 1, amount_max = 5, probability=0.008},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        surface_conditions =
        {
           {
              property = "gravity",
              min = 8,
              max = 8
            }
        },
    },
    {
        name = "ei-excavator-running-vulcanus",
        type = "recipe",
        category = "ei-excavator",
        energy_required = 30,
        ingredients = {
            {type = "fluid", name = "steam", amount = 200},
            {type = "fluid", name = "ei-drill-fluid", amount = 126},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 5,amount_max = 20},
            {type = "fluid", name = "lava", amount_min = 12, amount_max= 30,probability=0.9},
            {type = "item", name = "ei-coal-chunk", amount_min = 4, amount_max = 8,probability=0.65},
            {type = "item", name = "calcite", amount_min = 5, amount_max = 15,probability=0.38},
            {type = "item", name = "tungsten-ore", amount_min = 5, amount_max = 30,probability=0.03},
            {type = "item", name = "stone", amount_min = 15*3, amount_max = 15*5,probability=0.88},
            {type = "item", name = "atan-ash", amount_min = 15, amount_max = 60,probability=0.99},
            {type = "item", name = "ei-slag", amount_min = 5, amount_max = 30,probability=0.9}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        surface_conditions =
        {
           {
              property = "gravity",
              min = 40,
              max = 40
            }
        },
    },
    {
        name = "ei-excavator-running-gleba",
        type = "recipe",
        category = "ei-excavator",
        energy_required = 6.5,
        ingredients = {
            {type = "fluid", name = "water", amount = 20},
            {type = "fluid", name = "ei-drill-fluid", amount = 27},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 15,amount_max=20},
            {type = "item", name = "stone", amount_min = 15*2, amount_max = 15*4,probability=0.85},
            {type = "item", name = "jellynut-seed", amount_min = 1, amount_max = 5,probability=0.08},
            {type = "item", name = "yumako-seed", amount_min = 1, amount_max = 5,probability=0.08},
            {type = "item", name = "spoilage", amount_min = 5, amount_max = 15,probability=0.65},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        surface_conditions =
        {
           {
              property = "gravity",
              min = 20,
              max = 20
            }
        },
    },
    {
        name = "ei-excavator-running-aquilo",
        type = "recipe",
        category = "ei-excavator",
        energy_required = 180,
        ingredients = {
            {type = "fluid", name = "ei-drill-fluid", amount = 756},
            {type = "fluid", name = "fluoroketone-hot", amount = 150},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 10,amount_max=75},
            {type = "fluid", name = "fluoroketone-cold", amount = 150},
            {type = "item", name = "stone", amount_min = 15*1, amount_max = 15*3, probability=0.33},
            {type = "item", name = "ice", amount_min = 15,amount_max=15*10, probability=0.99},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        surface_conditions =
        {
           {
              property = "pressure",
              min = 300,
              max = 300
            }
        },
    },
    {
        name = "ei-excavator-running-gaia",
        type = "recipe",
        category = "ei-excavator",
        energy_required = 3,
        ingredients = {
            {type = "fluid", name = "ei-diluted-morphium", amount = 20},
            {type = "fluid", name = "ei-drill-fluid", amount = 12},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount_min = 10,amount_max=20},
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1,amount_max=3, probability = 0.09},
            {type = "item", name = "stone", amount_min = 15*2, amount_max = 15*4, probability=0.95},
            {type = "item", name = "ei-energy-crystal", amount_min = 1, amount_max = 2,probability=0.08},
            {type = "item", name = "ei-high-energy-crystal", amount_min = 1, amount_max = 2,probability=0.04},
            {type = "item", name = "ei-neodym-chunk", amount_min = 1, amount_max = 2,probability=0.03},
            {type = "item", name = "ei-alien-seed", amount_min = 0, amount_max = 1,probability=0.01}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "stone",
        surface_conditions =
        {
           {
              property = "gravity",
              min = 15.5,
              max = 15.5
            }
        },
    }
})
local pdf = ei_lib.raw.technology["planet-discovery-fulgora"]
if pdf and pdf.effects then
    table.insert(pdf.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-excavator-running-fulgora"
    })
end
local pdv = ei_lib.raw.technology["planet-discovery-vulcanus"]
if pdv and pdv.effects then
    table.insert(pdv.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-excavator-running-vulcanus"
    })
end
local pdg = ei_lib.raw.technology["planet-discovery-gleba"]
if pdg and pdg.effects then
    table.insert(pdg.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-excavator-running-gleba"
    })
end
local pda = ei_lib.raw.technology["planet-discovery-aquilo"]
if pda and pda.effects then
    table.insert(pda.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-excavator-running-aquilo"
    })
end
local pdgaia = ei_lib.raw.technology["ei-gaia"]
if pdgaia and pdgaia.effects then
    table.insert(pdgaia.effects,
    {
        type = "unlock-recipe",
        recipe = "ei-excavator-running-gaia"
    })
end
