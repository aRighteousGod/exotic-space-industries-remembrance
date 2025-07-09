ei_data = require("lib/data")

--====================================================================================================
--ARC FURNACE
--====================================================================================================
local arc_furnace_glow = {
    type = "sprite",
    name = "arc_furnace_glow",
    filename = ei_graphics_glow_path.."small_pngs/frame_count_3/glow_3.png",
    priority = "high",
    width = 205,
    height = 207,
    scale = 1,
    frame_count = 3,
    animation_speed = 0.4,
}

data:extend({
        arc_furnace_glow,
    {
        name = "ei-arc-furnace",
        type = "recipe-category",
    },
    {
        name = "ei-arc-furnace",
        type = "item",
        icon = ei_graphics_item_path.."arc-furnace.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c-3",
        place_result = "ei-arc-furnace",
        stack_size = 50
    },
    {
        name = "ei-arc-furnace",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="electric-furnace", amount=1},
            {type="item", name="electric-engine-unit", amount=4},
            {type="item", name="storage-tank", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=8},
            {type="item",name="ei-steel-beam",amount=10}
        },
        results = {{type="item", name="ei-arc-furnace", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-arc-furnace",
    },
    {
        name = "ei-arc-furnace",
        type = "technology",
        icon = ei_graphics_tech_path.."arc-furnace.png",
        icon_size = 256,
        prerequisites = {"ei-purifier", "advanced-material-processing-2"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-arc-furnace"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-iron-pure-ore"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-iron-plate"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-iron-beam"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-iron-mechanical-parts"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-copper-pure-ore"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-copper-plate"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-copper-beam"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-copper-mechanical-parts"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-steel-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-steel-beam"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-steel-mechanical-parts"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-gold-pure-ore"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-gold-ingot"
            },
--            {
--                type = "unlock-recipe",
--                recipe = "ei-molten-gold-plate"
--            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-lead-pure-ore"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-molten-lead-ingot"
            },
--            {
--                type = "unlock-recipe",
--                recipe = "ei-molten-lead-plate"
--            },
            {
                type = "unlock-recipe",
                recipe = "ei-caster"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-gold-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-iron-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-copper-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-steel-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-lead-ingot"
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
        name = "ei-arc-furnace",
        type = "furnace",
        icon = ei_graphics_item_path.."arc-furnace.png",
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
            mining_time = 1,
            result = "ei-arc-furnace"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-arc-furnace"},
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
            emissions_per_minute = { pollution = 6 },
            drain = "12MW"
        },
        energy_usage = "30MW",
        result_inventory_size = 1,
        source_inventory_size = 1,
        allowed_effects = {"speed", "consumption", "pollution"},
        module_slots = 2,
        fluid_boxes = {
            --[[
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_big,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.east, position = {2, 0}},
                },
                production_type = "input",
            },
            ]]
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
                filename = ei_graphics_entity_path.."arc-furnace.png",
                size = {512,512},
                shift = {0, 0},
    	        scale = 0.35,
                line_length = 1,
                --lines_per_file = 2,
                frame_count = 1,
                -- animation_speed = 0.2,
            },
            working_visualisations = {
                -- simulate always on idle capacitor glow
                {
                    always_draw = true,
                    animation = {
                    filename = ei_graphics_glow_path.."arc-furnace-glow-pulse-red.png",
                    width = 64,
                    height = 64,
                    frame_count = 4,
                    scale = 6,
                    shift = {0, 0},
                    blend_mode = "additive",
                    draw_as_glow = true,
                    animation_speed = 0.1,
                    },
                    light = {
                        intensity = 0.36,
                        size = 6,
                        color = {r = 0.8, g = 0.05, b = 0.05},
                        apply_runtime_tint = true
                    }
                },
                {
                  animation = 
                  {
                    filename = ei_graphics_entity_path.."arc-furnace_animation.png",
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
                    sprite = "arc_furnace_glow",
                    flicker_interval = 6,
                    flicker_min_modifier = 0.3,
                    flicker_max_modifier = 0.8,
                    offset_flicker = true,
                    intensity = 0.8,
                    size = 15,
                    color = {r = 0.1, g = 0.4, b = 1.0}, -- Bright electric blue
                    blend_mode = "multiplicative",
                    apply_runtime_tint = true,
                    draw_as_glow = true,
                    }
                },
                {

                    light = {
                    type = "basic",
                    sprite = "arc_furnace_glow",
                    flicker_interval = 4,
                    flicker_min_modifier = 0.1,
                    flicker_max_modifier = 0.7,
                    offset_flicker = true,
                    intensity = 0.9,
                    size = 15,
                    color = {r = 1.0, g = 0.4, b = 0.0}, -- Hot orange with a hint of red (molten feel)
                    blend_mode = "multiplicative",
                    apply_runtime_tint = true,
                    draw_as_glow = true,
                    }
                },
                {

                    light = {
                    type = "basic",
                    sprite = "arc_furnace_glow",
                    flicker_interval = 2,
                    flicker_min_modifier = 0,
                    flicker_max_modifier = 1,
                    offset_flicker = true,
                    intensity = 1,
                    size = 5,
                    color = {r = 1.0, g = 0.5, b = 1.0}, -- White ish
                    blend_mode = "multiplicative",
                    apply_runtime_tint = true,
                    draw_as_glow = true,
                    }
                },
                {

                    light = {
                    type = "basic",
                    sprite = "arc_furnace_glow",
                    flicker_interval = 1,
                    flicker_min_modifier = 0,
                    flicker_max_modifier = 0.3,
                    offset_flicker = true,
                    intensity = 0.4,
                    size = 65,
                    color = {r = 1, g = 0.8, b = 1.0}, -- White ish
                    blend_mode = "multiplicative",
                    apply_runtime_tint = true,
                    draw_as_glow = true,
                    }
                },
            },
        },
        working_sound =
        {
            sound = {filename = "__base__/sound/electric-furnace.ogg", volume = 0.6},
            apparent_volume = 0.3,
        },
    },
    -- IRON
    {
        name = "ei-molten-iron-pure-ore",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-pure-iron", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-iron", amount = 15},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-iron",
    },
    {
        name = "ei-molten-iron-plate",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-iron", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-iron",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-molten-iron-beam",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-iron-beam", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-iron", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-iron",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-molten-iron-mechanical-parts",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-iron-mechanical-parts", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-iron", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-iron",
        hide_from_player_crafting = true,
    },

    -- copper
    {
        name = "ei-molten-copper-pure-ore",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-pure-copper", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-copper", amount = 15},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-copper",
    },
    {
        name = "ei-molten-copper-plate",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "copper-plate", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-copper", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-copper",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-molten-copper-beam",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-copper-beam", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-copper", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-copper",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-molten-copper-mechanical-parts",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-copper-mechanical-parts", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-copper", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-copper",
        hide_from_player_crafting = true,
    },

     -- steel
    {
        name = "ei-molten-steel-ingot",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-steel", amount = 10},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-steel",
    },
    {
        name = "ei-molten-steel-beam",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "steel-plate", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-steel", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-steel",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-molten-steel-mechanical-parts",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-steel-mechanical-parts", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-steel", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-steel",
        hide_from_player_crafting = true,
    },

    -- gold
    {
        name = "ei-molten-gold-pure-ore",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-pure-gold", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-gold", amount = 15},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-gold",
    },
    {
        name = "ei-molten-gold-ingot",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-gold", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-gold",
    },
--[[
    {
        name = "ei-molten-gold-plate",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-gold", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-gold",
        hide_from_player_crafting = true,
    },
]]
    -- lead
    {
        name = "ei-molten-lead-pure-ore",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-pure-lead", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-lead", amount = 15},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.01}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-lead",
    },
    {
        name = "ei-molten-lead-ingot",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-lead-ingot", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-lead", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-lead",
    },
    --[[
    {
        name = "ei-molten-lead-plate",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.25,
        ingredients = {
            {type = "item", name = "ei-lead-ingot", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-molten-lead", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-lead",
        hide_from_player_crafting = true,
    },
    ]]
})