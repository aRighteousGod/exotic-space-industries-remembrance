--====================================================================================================
--ALIEN BEACON
--====================================================================================================

data:extend({
    {
        name = "ei-alien-beacon",
        type = "item",
        icon = ei_graphics_item_path.."alien-beacon.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "a1",
        place_result = "ei-alien-beacon",
        stack_size = 1,
    },
    {
        name = "ei-warp-beacon",
        type = "item",
        icon = ei_graphics_item_path.."alien-beacon.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "a1",
        place_result = "ei-warp-beacon",
        stack_size = 1,
    },

    {
        name = "ei-alien-beacon",
        type = "beacon",
        icon = ei_graphics_item_path.."alien-beacon.png",
        icon_size = 64,
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-2.2, -2.2}, {2.2, 2.2}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.alien,
        allowed_effects = {"speed", "consumption", "pollution","quality"},
        minable = {
            mining_time = 1,
            result = "ei-alien-beacon",
        },
        distribution_effectivity = 1,
        distribution_effectivity_bonus_per_quality_level = 0.25,
        energy_source = {
          type = "electric",
          usage_priority = "secondary-input",
        },
        energy_usage = "125MW",
        module_slots = 8,
        supply_area_distance = 20,
        radius_visualisation_picture =
		{
			filename = "__base__/graphics/entity/beacon/beacon-radius-visualization.png",
			width = 10,
			height = 10,
        },
        animation = {
            filename = ei_graphics_entity_path.."alien-beacon_animation.png",
            size = {512,512},
            shift = {0, 0.5},
	          scale = 0.35,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.4,
            run_mode = "backward",
        },
    },


    {
        name = "ei-warp-beacon",
        type = "beacon",
        icon = ei_graphics_item_path.."alien-beacon.png",
        icon_size = 64,
        max_health = 3000,
        corpse = "big-remnants",
        collision_box = {{-2.2, -2.2}, {2.2, 2.2}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.alien,
        allowed_effects = {"speed", "productivity", "consumption", "pollution", "quality"},
        minable = {
            mining_time = 60,
            result = "ei-warp-beacon",
        },
        distribution_effectivity = 2,
        distribution_effectivity_bonus_per_quality_level = 0.25,
        energy_source = {
          type = "electric",
          usage_priority = "secondary-input",
        },
        energy_usage = "250MW",
        module_slots = 10,
        supply_area_distance = 64,
        animation = {
        filename = ei_graphics_entity_path.."alien-beacon_animation.png",
        size = {512,512},
        shift = {0, 0.5},
        scale = 0.35,
        line_length = 4,
        lines_per_file = 4,
        frame_count = 16,
        animation_speed = 0.4,
        run_mode = "backward",
    },
    },



    -- add destroyed beacons as containers
    {
        name = "ei-alien-beacon_off-1",
        type = "item",
        icon = ei_graphics_item_path.."alien-beacon_off.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "b1",
        place_result = "ei-alien-beacon_off-1",
        stack_size = 1,
    },
    {
        name = "ei-alien-beacon_off-2",
        type = "item",
        icon = ei_graphics_item_path.."alien-beacon_off.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "b2",
        place_result = "ei-alien-beacon_off-2",
        stack_size = 1,
    },
    {
        name = "ei-alien-beacon_off-3",
        type = "item",
        icon = ei_graphics_item_path.."alien-beacon_off.png",
        icon_size = 64,
        subgroup = "ei-alien-structures",
        order = "b2",
        place_result = "ei-alien-beacon_off-3",
        stack_size = 1,
    },
    {
        name = "ei-alien-beacon_off-1",
        type = "container",
        icon = ei_graphics_item_path.."alien-beacon_off.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-2.3, -2.3}, {2.3, 2.3}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_path.."alien-beacon_off-1.png",
            size = {512,512},
            shift = {0, 0.5},
            scale = 0.35,
        },
        minable = {
            mining_time = 2,
            result = "ei-alien-beacon_off-1",
        },
    },
    {
        name = "ei-alien-beacon_off-2",
        type = "container",
        icon = ei_graphics_item_path.."alien-beacon_off.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-2.3, -2.3}, {2.3, 2.3}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_path.."alien-beacon_off-2.png",
            size = {512,512},
            shift = {0, 0.5},
            scale = 0.35,
        },
        minable = {
            mining_time = 2,
            result = "ei-alien-beacon_off-2",
        },
    },
    {
        name = "ei-alien-beacon_off-3",
        type = "container",
        icon = ei_graphics_item_path.."alien-beacon_off.png",
        icon_size = 64,
        flags = {"placeable-neutral", "player-creation", "not-deconstructable", "not-blueprintable"},
        max_health = 300,
        corpse = "big-remnants",
        collision_box = {{-2.3, -2.3}, {2.3, 2.3}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.alien,
        inventory_size = 0,
        picture = {
            filename = ei_graphics_entity_path.."alien-beacon_off-3.png",
            size = {512,512},
            shift = {0, 0.5},
            scale = 0.35,
        },
        minable = {
            mining_time = 2,
            result = "ei-alien-beacon_off-3",
        },
    },

    {
        name = "ei-alien-beacon-repair",
        type = "selection-tool",
        stack_size = 1,
        icon_size = 64,
        icon = ei_graphics_item_2_path.."alien-beacon-repair.png",
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
        entity_filters = ei_data.repair_tool_entity_filter("ei-alien-beacon-repair"),
        subgroup = "ei-repairs",
        order = "a-c",
    },
    {
        name = "ei-alien-beacon-repair",
        type = "technology",
        icon = ei_graphics_tech_2_path.."alien-beacon-repair.png",
        icon_size = 256,
        prerequisites = {"ei-odd-plating", "ei-quantum-computer"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-alien-beacon-repair"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-warp-beacon"
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
        name = "ei-alien-beacon-repair",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "ei-odd-plating", amount = 100},
            {type = "item", name = "ei-carbon-structure", amount = 125},
            {type = "item", name = "ei-superior-data", amount = 200},
            {type = "item", name = "processing-unit", amount = 200},
            {type = "item", name = "ei-high-energy-crystal", amount = 45},
        },
        results = {
            {type = "item", name = "ei-alien-beacon-repair", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-alien-beacon-repair",
    },

    {
        name = "ei-warp-beacon",
        type = "recipe",
        category = "crafting",
        energy_required = 300,
        ingredients = {
            {type = "item", name = "ei-odd-plating", amount = 1000},
            {type = "item", name = "ei-carbon-structure", amount = 1250},
            {type = "item", name = "ei-superior-data", amount = 2000},
            {type = "item", name = "processing-unit", amount = 2000},
            {type = "item", name = "ei-high-energy-crystal", amount = 450},
        },
        results = {
            {type = "item", name = "ei-warp-beacon", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-warp-beacon",
    },

})
