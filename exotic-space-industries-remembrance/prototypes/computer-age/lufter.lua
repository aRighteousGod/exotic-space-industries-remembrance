ei_data = require("lib/data")
local carbon_dioxide_fluid = data.raw.fluid["ei-carbon-dioxide"]
local carbon_dioxide_icon = (carbon_dioxide_fluid and carbon_dioxide_fluid.icon) or (ei_path.."graphics/fluids/carbon-dioxide.png")
local carbon_dioxide_icon_size = (carbon_dioxide_fluid and carbon_dioxide_fluid.icon_size) or 64

--====================================================================================================
--LUFTER aka AIR FILTER air filter Air filter
--====================================================================================================

data:extend({
    {
        name = "ei-lufter",
        type = "recipe-category",
    },
    {
        name = "ei-lufter",
        type = "item",
        icon = ei_graphics_item_path.."lufter.png",
        icon_size = 64,
        subgroup = "production-machine",
        order = "d-a-c",
        place_result = "ei-lufter",
        stack_size = 50
    },
    {
        name = "ei-lufter",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="electronic-circuit", amount=2},
            {type="item", name="electric-engine-unit", amount=4},
            {type="item", name="steel-plate", amount=4},
            {type="item", name="ei-steel-mechanical-parts", amount=12}
        },
        results = {{type="item", name="ei-lufter", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-lufter",
    },
    {
        name = "ei-lufter",
        type = "assembling-machine",
        icon = ei_graphics_item_path.."lufter.png",
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
            mining_time = 1,
            result = "ei-lufter"
        },
        max_health = 300,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        crafting_categories = {"ei-lufter"},
        heating_energy = "100kW",
        crafting_speed = 1,
        energy_source = {
            type = 'electric',
            usage_priority = 'secondary-input',
        },
        energy_usage = "300kW",
        graphics_set = {
            animation = {
                filename = ei_graphics_entity_path.."lufter.png",
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
                    filename = ei_graphics_entity_path.."lufter_animation.png",
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
        allowed_effects = {"speed", "consumption", "pollution"},
        module_slots = 3,
        fluid_boxes = {
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_electricity,
                pipe_connections = {
                    {flow_direction = "output", direction = defines.direction.east, position = {1, 0}},
                },
                production_type = "output",
            },
            {   
                volume = 200,
                pipe_covers = pipecoverspictures(),
                pipe_picture = ei_pipe_electricity,
                pipe_connections = {
                    {flow_direction = "input", direction = defines.direction.west, position = {-1, 0}},
                },
                production_type = "input",
            },
        },
        fluid_boxes_off_when_no_fluid_recipe = true,
        working_sound =
        {
            sound = {filename = "__base__/sound/electric-mining-drill.ogg", volume = 0.8},
            apparent_volume = 0.3,
        },
    },
    {
        name = "ei-nitrogen-gas",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {},
        results = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-nitrogen-gas",
        surface_conditions = {
            {property = "pressure",    min = 33, max = 100000},
        },
    },
    {
        name = "ei-nitrogen-gas-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-nitrogen-gas", amount = 20},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."vent_nitrogen.png",
        icon_size = 64,
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-h[ei-nitrogen-gas-vent]"
    },
    {
        name = "ei-oxygen-gas",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {},
        results = {
            {type = "fluid", name = "ei-oxygen-gas", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-oxygen-gas",
        surface_conditions = {
            {property = "pressure",    min = 33, max = 100000},
        },
    },
    {
        name = "ei-oxygen-gas-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-oxygen-gas", amount = 20},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."vent_oxygen.png",
        icon_size = 64,
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-h[ei-oxygen-gas-vent]"
    },
    {
        name = "ei-carbon-dioxide-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-carbon-dioxide", amount = 20},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icons = {
            {icon = carbon_dioxide_icon, icon_size = carbon_dioxide_icon_size, scale = 1.12},
            {icon = "__base__/graphics/icons/signal/signal-no-entry.png", icon_size = 64, scale = 1.5},
        },
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-h[ei-carbon-dioxide-vent]"
    },
    {
        name = "ei-extract-water",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {},
        results = {
            {type = "fluid", name = "water", amount = 50},
        },
        always_show_made_in = true,
        surface_conditions = {
            {property = "pressure",    min = 1000, max = 2000},
        },
        enabled = false,
        main_product = "water",
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-j[water]",
    },
    {
        name = "ei-steam-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "steam", amount = 50},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."vent_steam.png",
        icon_size = 64,
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-i[ei-steam-vent]"
    },
    {
        name = "ei-benzol-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-benzol", amount = 50},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = data.raw.fluid["ei-benzol"].icon,
        icon_size = data.raw.fluid["ei-benzol"].icon_size,
        icons = {
            { icon = data.raw.fluid["ei-benzol"].icon, scale = 1 },
            { icon = "__base__/graphics/icons/signal/signal-no-entry.png", scale = 1.5}
        },
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-i[ei-benzol-vent]"
    },
    {
        name = "ei-coal-gas-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-coal-gas", amount = 50},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = data.raw.fluid["ei-coal-gas"].icon,
        icon_size = data.raw.fluid["ei-coal-gas"].icon_size,
        icons = {
            { icon = data.raw.fluid["ei-coal-gas"].icon, scale = 1 },
            { icon = "__base__/graphics/icons/signal/signal-no-entry.png", scale = 1.5}
        },
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-i[ei-benzol-vent]"
    },
    {
        name = "ei-hydrogen-gas-vent",
        type = "recipe",
        category = "ei-lufter",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-hydrogen-gas", amount = 50},
        },
        results = {},
        always_show_made_in = true,
        enabled = false,
        icon = data.raw.fluid["ei-hydrogen-gas"].icon,
        icon_size = data.raw.fluid["ei-coal-gas"].icon_size,
        icons = {
            { icon = data.raw.fluid["ei-hydrogen-gas"].icon, scale = 1 },
            { icon = "__base__/graphics/icons/signal/signal-no-entry.png", scale = 1.5}
        },
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-i[ei-hydrogen-vent]"
    },
})
