--====================================================================================================
--CRYSTAL ACCUMULATOR
--====================================================================================================

data:extend({
    {
        name = "ei-crystal-accumulator",
        type = "item",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-d",
        place_result = "ei-crystal-accumulator",
        stack_size = 10,
    },
    {
        name = "ei-crystal-accumulator-gaia",
        type = "item",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-d",
        place_result = "ei-crystal-accumulator-gaia",
        stack_size = 10,
    },
    {
        name = "ei-crystal-accumulator-repair",
        type = "selection-tool",
        stack_size = 1,
        icon_size = 64,
        icon = ei_graphics_item_2_path.."crystal-accumulator-repair.png",
        -- flags = {"mod-openable"},
        select = {
            border_color = {r=0.79, g=0.4, b=0, a=0.5 },
            mode = {"any-entity"},
            cursor_box_type = "entity",
        },
        alt_select = {
            border_color = {r=0, g=1, b=0, a=0.5 },
            cursor_box_type = "entity",
            mode = {"any-entity"},
        },
        entity_filter_mode = "whitelist",
        entity_filters = ei_data.repair_tool_entity_filter("ei-crystal-accumulator-repair"),
        subgroup = "ei-repairs",
        order = "a-a",
    },
    {
        name = "ei-crystal-accumulator",
        type = "electric-energy-interface",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 4,
            result = "ei-crystal-accumulator"
        },
        max_health = 1000,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        energy_source = {
            type = 'electric',
            usage_priority = 'primary-output',
            input_flow_limit = "10MW",
            output_flow_limit = "10MW",
            buffer_capacity = "1GJ",
            render_no_power_icon = false,
        },
        animation = {
            filename = ei_graphics_entity_2_path.."crystal-accumulator_animation_nauvis.png",
            size = {512,512},
            shift = {0,0},
	        scale = 0.44/2,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.3,
        },
        energy_production = "7.5MW",
        energy_usage = "0GW",
        --gui_mode = "none",
        continuous_animation = true,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 27, main_offset = util.by_pixel( 38.125,  21.125), shadow_offset = util.by_pixel( 38.125,  21.125), show_shadow = true },
            { variation = 27, main_offset = util.by_pixel( 38.125,  21.125), shadow_offset = util.by_pixel( 38.125,  21.125), show_shadow = true },
            { variation = 27, main_offset = util.by_pixel( 38.125,  21.125), shadow_offset = util.by_pixel( 38.125,  21.125), show_shadow = true },
            { variation = 27, main_offset = util.by_pixel( 38.125,  21.125), shadow_offset = util.by_pixel( 38.125,  21.125), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    },
    {
        name = "ei-crystal-accumulator-gaia",
        type = "electric-energy-interface",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 4,
            result = "ei-crystal-accumulator-gaia"
        },
        max_health = 1000,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.assembler,
        energy_source = {
            type = 'electric',
            usage_priority = 'primary-output',
            input_flow_limit = "10MW",
            output_flow_limit = "10MW",
            buffer_capacity = "1GJ",
            render_no_power_icon = false,
        },
        animation = {
            filename = ei_graphics_entity_2_path.."crystal-accumulator_animation.png",
            size = {512,512},
            shift = {0,0},
	        scale = 0.44/2,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.3,
        },
        energy_production = "15MW",
        energy_usage = "0GW",
        --gui_mode = "none",
        continuous_animation = true,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 27, main_offset = util.by_pixel( 38.125,  21.125), shadow_offset = util.by_pixel( 38.125,  21.125), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    },
    -- add destroyed accumulator as containers
    {
        name = "ei-crystal-accumulator_off-1",
        type = "item",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "z1",
        place_result = "ei-crystal-accumulator_off-1",
        stack_size = 1,
    },
    {
        name = "ei-crystal-accumulator_off-2",
        type = "item",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "z1",
        place_result = "ei-crystal-accumulator_off-2",
        stack_size = 1,
    },
    {
        name = "ei-crystal-accumulator_off-3",
        type = "item",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "z1",
        place_result = "ei-crystal-accumulator_off-3",
        stack_size = 1,
    },
    {
        name = "ei-crystal-accumulator_off-4",
        type = "item",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "z1",
        place_result = "ei-crystal-accumulator_off-4",
        stack_size = 1,
    },
    {
        name = "ei-crystal-accumulator_off-1",
        type = "container",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_2_path.."crystal-accumulator_off-1.png",
            size = {512,512},
            shift = {0,0},
	        scale = 0.44/2,
        },
        minable = {
            mining_time = 2,
            result = "ei-crystal-accumulator_off-1",
        },
    },
    {
        name = "ei-crystal-accumulator_off-2",
        type = "container",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_2_path.."crystal-accumulator_off-2.png",
            size = {512,512},
            shift = {0,0},
	        scale = 0.44/2,
        },
        minable = {
            mining_time = 2,
            result = "ei-crystal-accumulator_off-2",
        },
    },
    {
        name = "ei-crystal-accumulator_off-3",
        type = "container",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_2_path.."crystal-accumulator_off-3.png",
            size = {512,512},
            shift = {0,0},
	        scale = 0.44/2,
        },
        minable = {
            mining_time = 2,
            result = "ei-crystal-accumulator_off-3",
        },
    },
    {
        name = "ei-crystal-accumulator_off-4",
        type = "container",
        icon = ei_graphics_item_2_path.."crystal-accumulator.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_2_path.."crystal-accumulator_off-4.png",
            size = {512,512},
            shift = {0,0},
	        scale = 0.44/2,
        },
        minable = {
            mining_time = 2,
            result = "ei-crystal-accumulator_off-4",
        },
    },
    -- techs and recipes
    {
        name = "ei-crystal-accumulator-repair",
        type = "technology",
        icon = ei_graphics_tech_2_path.."crystal-accumulator-repair.png",
        icon_size = 256,
        prerequisites = {"ei-farstation-repair"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-crystal-accumulator-repair"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        -- age = "computer-age",
    },

    {
        name = "ei-crystal-accumulator",
        type = "technology",
        icon = ei_graphics_tech_2_path.."crystal-accumulator.png",
        icon_size = 256,
        prerequisites = {"ei-crystal-accumulator-repair"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-crystal-accumulator"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        age = "computer-age",
    },

    {
        name = "ei-crystal-accumulator-repair",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-alien-resin", amount = 10},
            {type = "item", name = "ei-electronic-parts", amount = 6},
            {type = "item", name = "ei-energy-crystal", amount = 25},
        },
        results = {
            {type = "item", name = "ei-crystal-accumulator-repair", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crystal-accumulator-repair",
    },
    {
        name = "ei-crystal-accumulator",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-alien-resin", amount = 10},
            {type = "item", name = "ei-electronic-parts", amount = 6},
            {type = "item", name = "ei-energy-crystal", amount = 25},
        },
        results = {
            {type = "item", name = "ei-crystal-accumulator", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crystal-accumulator",
    },
    {
        name = "ei-crystal-accumulator-gaia",
        type = "recipe",
        category = "crafting",
        energy_required = 9999,
        ingredients = {

        },
        results = {
            {type = "item", name = "ei-crystal-accumulator-gaia", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crystal-accumulator-gaia",
    },
})
