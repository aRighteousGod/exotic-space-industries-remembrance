ei_data = require("lib/data")

--====================================================================================================
--Purifier
--====================================================================================================

data:extend({
    {
        name = "ei-purifier",
        type = "recipe-category",
    },
    {
        name = "ei-purifier",
        type = "item",
        icon = ei_graphics_item_path.."purifier.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-2",
        place_result = "ei-purifier",
        stack_size = 50
    },
    {
        name = "ei-pure-iron",
        type = "item",
        icon = "__base__/graphics/icons/iron-ore.png",
        icon_mipmaps = 4,
        icon_size = 64,
        subgroup = "ei-refining-purified",
        order = "b-a",
        stack_size = 100,
        pictures = {
            {
                filename = "__base__/graphics/icons/iron-ore.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = "__base__/graphics/icons/iron-ore-1.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = "__base__/graphics/icons/iron-ore-2.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = "__base__/graphics/icons/iron-ore-3.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            }
        },
    },
    {
        name = "ei-pure-copper",
        type = "item",
        icon = "__base__/graphics/icons/copper-ore.png",
        icon_mipmaps = 4,
        icon_size = 64,
        subgroup = "ei-refining-purified",
        order = "b-b",
        stack_size = 100,
        pictures = {
            {
                filename = "__base__/graphics/icons/copper-ore.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = "__base__/graphics/icons/copper-ore-1.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = "__base__/graphics/icons/copper-ore-2.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = "__base__/graphics/icons/copper-ore-3.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            }
        },
    },
    {
        name = "ei-pure-lead",
        type = "item",
        icon = ei_graphics_item_path.."pure-lead.png",
        icon_mipmaps = 4,
        icon_size = 64,
        subgroup = "ei-refining-purified",
        order = "b-c",
        stack_size = 100,
        pictures = {
            {
                filename = ei_graphics_item_path.."pure-lead.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."pure-lead-1.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."pure-lead-2.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."pure-lead-3.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            }
        },
    },
    {
        name = "ei-pure-gold",
        type = "item",
        icon = ei_graphics_item_path.."pure-gold.png",
        icon_mipmaps = 4,
        icon_size = 64,
        subgroup = "ei-refining-purified",
        order = "b-d",
        stack_size = 100,
        pictures = {
            {
                filename = ei_graphics_item_path.."pure-gold.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."pure-gold-1.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."pure-gold-2.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."pure-gold-3.png",
                mipmap_count = 4,
                scale = 0.25,
                size = 64
            }
        },
    },
    {
        name = "ei-purifier",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="chemical-plant", amount=1},
            {type="item", name="electric-engine-unit", amount=6},
            {type="item", name="storage-tank", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=8}
        },
        results = {{type="item", name="ei-purifier", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-purifier",
    },
    {
        name = "ei-purifier",
        type = "technology",
        icon = ei_graphics_tech_path.."purifier.png",
        icon_size = 256,
        prerequisites = {"ei-deep-mining"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-purifier"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-hydrofluoric-acid"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-gold-chunk-purifier"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-iron-chunk-purifier"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-copper-chunk-purifier"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lead-chunk-purifier"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-gold-ingot-pure-smelting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-iron-ingot-pure-smelting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-copper-ingot-pure-smelting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lead-ingot-pure-smelting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-fluorite"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-water-vent"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-landfill"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-slag"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-dirty-water-sand"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-slag-extraction-sulfuric"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-slag-extraction-hydro"
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
        name = "ei-purifier",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."purifier.png",
        icon_size = 64,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true },
            { variation = 30, main_offset = util.by_pixel( 0.625,  58.875), shadow_offset = util.by_pixel( 0.625,  58.875), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-purifier"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-purifier"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "2MW",
        allowed_effects = {"speed", "productivity", "consumption", "pollution"},
        module_slots = 4,
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {2, 0}},
                },
                production_type = "input",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.west, position = {-2, 0}},
                },
                production_type = "output",
            },
        },
        fluid_boxes_off_when_no_fluid_recipe = true,
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."purifier.png",
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
                    filename = ei_graphics_entity_path.."purifier_animation.png",
                    size = {512,512},
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
                    intensity = 1,
                    size = 15
                    }
                }
            },
        },
        working_sound =
        {
            sound = {filename = "__base__/sound/chemical-plant-3.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    },
    {
        name = "ei-gold-chunk-purifier",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "water", amount = 10},
            {type = "item", name = "ei-gold-chunk", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 10,allow_productivity=false},
            {type = "item", name = "ei-pure-gold", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."gold-purification.png",
        subgroup = "ei-refining-purified",
        order = "a-d",
    },
    {
        name = "ei-lead-chunk-purifier",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "water", amount = 10},
            {type = "item", name = "ei-lead-chunk", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 10,allow_productivity=false},
            {type = "item", name = "ei-pure-lead", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."lead-purification.png",
        subgroup = "ei-refining-purified",
        order = "a-c",
    },
    {
        name = "ei-iron-chunk-purifier",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "water", amount = 5},
            {type = "item", name = "ei-iron-chunk", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 5,allow_productivity=false},
            {type = "item", name = "ei-pure-iron", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."iron-purification.png",
        subgroup = "ei-refining-purified",
        order = "a-a",
    },
    {
        name = "ei-copper-chunk-purifier",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "water", amount = 5},
            {type = "item", name = "ei-copper-chunk", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 5,allow_productivity=false},
            {type = "item", name = "ei-pure-copper", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."copper-purification.png",
        subgroup = "ei-refining-purified",
        order = "a-b",
    },
    {
        name = "ei-copper-ingot-pure-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-pure-copper", amount = 1},
        },
        results = {
            {type = "item", name = "copper-plate", amount = 2},
            {type ="item", name="ei-slag",amount_min=1,amount_max=2,probability=0.01,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        --hide_from_player_crafting = true,
        main_product = "copper-plate",
    },
    {
        name = "ei-iron-ingot-pure-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-pure-iron", amount = 1},
        },
        results = {
            {type = "item", name = "iron-plate", amount = 2},
            {type ="item", name="ei-slag",amount_min=1,amount_max=2,probability=0.01,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        --hide_from_player_crafting = true,
        main_product = "iron-plate",
    },
    {
        name = "ei-lead-ingot-pure-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-pure-lead", amount = 2},
        },
        results = {
            {type = "item", name = "ei-lead-ingot", amount = 1},
            {type ="item", name="ei-slag",amount_min=1,amount_max=2,probability=0.01,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        --hide_from_player_crafting = true,
        main_product = "ei-lead-ingot",
    },
    {
        name = "ei-gold-ingot-pure-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-pure-gold", amount = 2},
        },
        results = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
            {type ="item", name="ei-slag",amount_min=1,amount_max=2,probability=0.01,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = false,
        --hide_from_player_crafting = true,
        main_product = "ei-gold-ingot",
    },
    {
        name = "ei-dirty-water-fluorite",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 8,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 100},
        },
        results = {
            {type = "item", name = "ei-fluorite", amount_min = 1, amount_max=3, probability=0.35},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-fluorite",
    },
    {
        name = "ei-morphium-fluorite",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 4,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 50},
            {type = "item", name ="ei-high-energy-crystal", amount = 1}
        },
        results = {
            {type = "item", name = "ei-fluorite", amount = 1},
            {type = "item", name = "ei-energy-crystal", amount = 1, probability=0.05}
        },
        always_show_made_in = true,
        enabled = false,
        subgroup = "ei-alien-intermediates",
        order = "a-a2b",
        main_product = "ei-fluorite",
    },
    {
        name = "ei-dirty-water-vent",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 100},
        },
        results = {

        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."dirty-water_venting.png",
        subgroup = "ei-refining-purified",
        order = "a-e",
    },
    {
        name = "ei-water-vent",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "water", amount = 100},
        },
        results = {

        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."vent_water.png",
        subgroup = "ei-refining-purified",
        order = "a-f",
    },
    {
        name = "ei-dirty-water-landfill",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-dirty-water", amount = 1000},
        },
        results = {
            {type = "item", name = "landfill", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "landfill",
    },
    {
        name = "ei-dirty-water-slag",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "water", amount = 5},
            {type = "item", name = "ei-slag", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-dirty-water",
    },
    {
        name = "ei-dirty-water-sand",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "water", amount = 5},
            {type = "item", name = "ei-sand", amount = 5},
        },
        results = {
            {type = "fluid", name = "ei-dirty-water", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-dirty-water",
    },
    {
        name = "ei-slag-extraction-morphium",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 6,
        ingredients = {
            {type = "fluid", name = "ei-morphium", amount = 10},
            {type="item",name="ei-high-energy-crystal",amount=1},
            {type = "item", name = "ei-slag", amount = 100},
        },
        results = {
            {type = "fluid", name = "ei-bio-sludge", amount_min = 1, amount_max=2,allow_productivity=false},
            {type="item",name="ei-energy-crystal",amount=1,probability=0.05,allow_productivity=false},
            {type= "item",name="ei-coal-chunk", amount_min=1, amount_max=3,probability=0.015},
            {type= "item",name="ei-iron-chunk", amount_min=1, amount_max=3,probability=0.01},
            {type= "item",name="ei-copper-chunk", amount_min=1, amount_max=3,probability=0.008},
            {type= "item",name="ei-gold-chunk", amount_min=1, amount_max=3,probability=0.004},
            {type= "item",name="ei-lead-chunk", amount_min=1, amount_max=3,probability=0.006},
            {type= "item",name="ei-sulfur-chunk", amount_min=1, amount_max=3,probability=0.007},
            {type= "item",name="ei-uranium-chunk", amount_min=1, amount_max=3,probability=0.0009},
            {type= "item",name="ei-neodym-chunk", amount_min=1, amount_max=3,probability=0.0004},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-bio-sludge",
    },
    {
        name = "ei-slag-extraction-hydro",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 8,
        ingredients = {
            {type = "fluid", name = "ei-hydrofluoric-acid", amount = 33},
            {type = "item", name = "ei-slag", amount = 100},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount_min = 5, amount_max=15,allow_productivity=false},
            {type= "item",name="ei-coal-chunk", amount_min=0, amount_max=2,probability=0.015},
            {type= "item",name="ei-iron-chunk", amount_min=0, amount_max=2,probability=0.01},
            {type= "item",name="ei-copper-chunk", amount_min=0, amount_max=2,probability=0.008},
            {type= "item",name="ei-gold-chunk", amount_min=0, amount_max=2,probability=0.004},
            {type= "item",name="ei-lead-chunk", amount_min=0, amount_max=2,probability=0.006},
            {type= "item",name="ei-sulfur-chunk", amount_min=0, amount_max=2,probability=0.007},
            {type= "item",name="ei-uranium-chunk", amount_min=0, amount_max=2,probability=0.0009},
            {type= "item",name="ei-neodym-chunk", amount_min=0, amount_max=2,probability=0.0004},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-acidic-water",
    },
    {
        name = "ei-slag-extraction-sulfuric",
        type = "recipe",
        category = "ei-purifier",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "sulfuric-acid", amount = 100},
            {type = "item", name = "ei-slag", amount = 100},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount_min = 15, amount_max=45,allow_productivity=false},
            {type= "item",name="ei-coal-chunk", amount_min=0, amount_max=1,probability=0.015},
            {type= "item",name="ei-iron-chunk", amount_min=0, amount_max=1,probability=0.01},
            {type= "item",name="ei-copper-chunk", amount_min=0, amount_max=1,probability=0.008},
            {type= "item",name="ei-gold-chunk", amount_min=0, amount_max=1,probability=0.004},
            {type= "item",name="ei-lead-chunk", amount_min=0, amount_max=1,probability=0.006},
            {type= "item",name="ei-sulfur-chunk", amount_min=0, amount_max=1,probability=0.007},
            {type= "item",name="ei-uranium-chunk", amount_min=0, amount_max=1,probability=0.0009},
            {type= "item",name="ei-neodym-chunk", amount_min=0, amount_max=1,probability=0.0004},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-acidic-water",
    },
})