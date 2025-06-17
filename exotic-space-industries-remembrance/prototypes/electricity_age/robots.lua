--====================================================================================================
--ITEMS
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-logistic-bot",
        type = "item",
        icon = ei_robots_item_path.."advanced-logistic-bot.png",
        icon_size = 64,
        subgroup = "logistic-network",
        order = "a[robot]-a[logistic-robot]-c",
        place_result = "ei-advanced-logistic-bot",
        stack_size = 50
    },
    {
        name = "ei-advanced-construction-bot",
        type = "item",
        icon = ei_robots_item_path.."advanced-construction-bot.png",
        icon_size = 64,
        subgroup = "logistic-network",
        order = "a[robot]-b[construction-robot]-c",
        place_result = "ei-advanced-construction-bot",
        stack_size = 50
    },
    {
        name = "ei-cargo-bot",
        type = "item",
        icon = ei_robots_item_path.."cargo-bot.png",
        icon_size = 64,
        subgroup = "logistic-network",
        order = "a[robot]-a[logistic-robot]-b",
        place_result = "ei-cargo-bot",
        stack_size = 50
    },
    {
        name = "ei-construction-bot",
        type = "item",
        icon = ei_robots_item_path.."construction-bot.png",
        icon_size = 64,
        subgroup = "logistic-network",
        order = "a[robot]-b[construction-robot]-b",
        place_result = "ei-construction-bot",
        stack_size = 50
    },
    {
        name = "ei-advanced-bot-engine",
        type = "item",
        icon = ei_robots_item_path.."advanced-engine.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "l[flying-robot-frame]-b",
        stack_size = 50
    },
    {
        name = "ei-advanced-port",
        type = "item",
        icon = ei_robots_item_path.."advanced-port.png",
        icon_size = 64,
        subgroup = "logistic-network",
        order = "d",
        place_result = "ei-advanced-port",
        stack_size = 10
    },
})

--====================================================================================================
--RECIPES
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-logistic-bot",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "logistic-robot", amount = 2},
            {type = "item", name = "processing-unit", amount = 4},
            {type = "item", name = "ei-advanced-bot-engine", amount = 4},
        },
        results = {
            {type = "item", name = "ei-advanced-logistic-bot", amount = 1}
        },
        enabled = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_productivity = true,
        always_show_made_in = true,
        main_product = "ei-advanced-logistic-bot",
    },
    {
        name = "ei-advanced-construction-bot",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "construction-robot", amount = 2},
            {type = "item", name = "processing-unit", amount = 4},
            {type = "item", name = "ei-advanced-bot-engine", amount = 4},
        },
        results = {
            {type = "item", name = "ei-advanced-construction-bot", amount = 1}
        },
        enabled = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_productivity = true,
        always_show_made_in = true,
        main_product = "ei-advanced-construction-bot",
    },
    {
        name = "ei-cargo-bot",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "logistic-robot", amount = 1},
            {type = "item", name = "iron-chest", amount = 6},
            {type = "item", name = "electric-engine-unit", amount = 4},
        },
        results = {
            {type = "item", name = "ei-cargo-bot", amount = 1}
        },
        enabled = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_productivity = true,
        always_show_made_in = true,
        main_product = "ei-cargo-bot",
    },
    {
        name = "ei-construction-bot",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "construction-robot", amount = 1},
            {type = "item", name = "fast-inserter", amount = 2},
            {type = "item", name = "advanced-circuit", amount = 2},
        },
        results = {
            {type = "item", name = "ei-construction-bot", amount = 1}
        },
        enabled = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_productivity = true,
        always_show_made_in = true,
        main_product = "ei-construction-bot",
    },
    {
        name = "ei-advanced-bot-engine",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 20,
        ingredients = {
            {type = "item", name = "flying-robot-frame", amount = 2},
            {type = "item", name = "battery", amount = 4},
            {type = "item", name = "electric-engine-unit", amount = 6},
            {type = "fluid", name = "lubricant", amount = 50},
        },
        results = {
            {type = "item", name = "ei-advanced-bot-engine", amount = 1}
        },
        enabled = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_productivity = true,
        always_show_made_in = true,
        main_product = "ei-advanced-bot-engine",
    },
    {
        name = "ei-advanced-port",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "roboport", amount = 8},
            {type = "item", name = "steel-plate", amount = 40},
            {type = "item", name = "ei-steel-beam", amount=40},
            {type = "item", name = "processing-unit", amount = 40},
            {type = "item", name = "ei-electronic-parts", amount = 50},        
            {type = "item", name = "electric-engine-unit", amount = 40},
        },
        results = {
            {type = "item", name = "ei-advanced-port", amount = 1}
        },
        enabled = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_productivity = false,
        always_show_made_in = true,
        main_product = "ei-advanced-port",
    },
})


--====================================================================================================
--TECHS
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-bots",
        type = "technology",
        icon = ei_robots_tech_path.."advanced-bots.png",
        icon_size = 128,
        prerequisites = {"space-science-pack"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-logistic-bot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-construction-bot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-bot-engine"
            },
        },
        unit = {
            count = 600,
            ingredients = ei_data.science["computer-age"],
            time = 60
        },
        age = "quantum-age",
    },
    {
        name = "ei-cargo-bots",
        type = "technology",
        icon = ei_robots_tech_path.."cargo-bots.png",
        icon_size = 256,
        prerequisites = {"logistic-robotics"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-cargo-bot"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 30
        },
        age = "electricity-age",
    },
    {
        name = "ei-construction-bots",
        type = "technology",
        icon = ei_robots_tech_path.."construction-bots.png",
        icon_size = 256,
        prerequisites = {"construction-robotics"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-construction-bot"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["computer-age"],
            time = 30
        },
        age = "electricity-age",
    },
    {
        name = "ei-advanced-port",
        type = "technology",
        icon = ei_robots_tech_path.."advanced-port.png",
        icon_size = 256,
        prerequisites = {"space-science-pack"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-advanced-port"
            },
        },
        unit = {
            count = 600,
            ingredients = ei_data.science["computer-age"],
            time = 60
        },
        age = "quantum-age",
    },
})
--====================================================================================================
--ROBOT ADDITIONS
--====================================================================================================

data:extend({
    {
        name = "ei-advanced-logistic-bot",
        type = "logistic-robot",
        icon = ei_robots_item_path .. "advanced-logistic-bot.png",
        icon_size = 64,
        flags = {"placeable-player", "player-creation", "placeable-off-grid", "not-on-map"},
        max_health = 1400,
        corpse = "big-remnants",
        collision_box = {{0, 0}, {0, 0}},
        selection_box = {{-0.5, -1.5}, {0.5, 0.5}},
        minable = {
            mining_time = 1,
            result = "ei-advanced-logistic-bot",
        },
        max_payload_size = 5,
        speed = 0.24,
        transfer_distance = 0.5,
        max_energy = "200MJ",
        energy_per_tick = "0.1kJ",
        speed_multiplier_when_out_of_energy = 0.2,
        energy_per_move = "10kJ",
        min_to_charge = 0.2,
        max_to_charge = 0.9,
        cargo_centered = {0.0, 0.2},
        idle = {
            filename = ei_robots_entity_path .. "advanced-logistic-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128,
            height = 128,
            scale = 0.5,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        shadow_idle = {
            filename = ei_robots_entity_path .. "advanced_logistic_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        in_motion = {
            filename = ei_robots_entity_path .. "advanced-logistic-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128,
            height = 128,
            scale = 0.5,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        shadow_in_motion = {
            filename = ei_robots_entity_path .. "advanced_logistic_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
    },
    {
        name = "ei-cargo-bot",
        type = "logistic-robot",
        icon = ei_robots_item_path .. "cargo-bot.png",
        icon_size = 64,
        flags = {"placeable-player", "player-creation", "placeable-off-grid", "not-on-map"},
        max_health = 1400,
        corpse = "big-remnants",
        collision_box = {{0, 0}, {0, 0}},
        selection_box = {{-0.5, -1.5}, {0.5, -0.5}},
        minable = {
            mining_time = 1,
            result = "ei-cargo-bot",
        },
        max_payload_size = 100,
        speed = 0.01,
        transfer_distance = 0.5,
        max_energy = "100MJ",
        energy_per_tick = "0.1kJ",
        speed_multiplier_when_out_of_energy = 0.2,
        energy_per_move = "1kJ",
        min_to_charge = 0.2,
        max_to_charge = 0.9,
        cargo_centered = {0.0, 0.2},
        idle = {
            filename = ei_robots_entity_path .. "cargo-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128 * 2,
            height = 128 * 2,
            scale = 0.25,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        idle_with_cargo = {
            filename = ei_robots_entity_path .. "cargo-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128 * 2,
            height = 128 * 2,
            scale = 0.25,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        in_motion = {
            filename = ei_robots_entity_path .. "cargo-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128 * 2,
            height = 128 * 2,
            scale = 0.25,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        in_motion_with_cargo = {
            filename = ei_robots_entity_path .. "cargo-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128 * 2,
            height = 128 * 2,
            scale = 0.25,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        shadow_idle = {
            filename = ei_robots_entity_path .. "cargo_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        shadow_in_motion = {
            filename = ei_robots_entity_path .. "cargo_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        shadow_idle_with_cargo = {
            filename = ei_robots_entity_path .. "cargo_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        shadow_in_motion_with_cargo = {
            filename = ei_robots_entity_path .. "cargo_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
    },
    {
        name = "ei-advanced-construction-bot",
        type = "construction-robot",
        icon = ei_robots_item_path .. "advanced-construction-bot.png",
        icon_size = 64,
        flags = {"placeable-player", "player-creation", "placeable-off-grid", "not-on-map"},
        max_health = 1400,
        corpse = "big-remnants",
        collision_box = {{0, 0}, {0, 0}},
        selection_box = {{-0.5, -1.5}, {0.5, 0.5}},
        minable = {
            mining_time = 1,
            result = "ei-advanced-construction-bot",
        },
        max_payload_size = 3,
        speed = 0.16,
        transfer_distance = 0.5,
        max_energy = "50MJ",
        energy_per_tick = "0.1kJ",
        speed_multiplier_when_out_of_energy = 0.2,
        energy_per_move = "5kJ",
        min_to_charge = 0.2,
        max_to_charge = 0.9,
        cargo_centered = {0.0, 0.2},
        construction_vector = {0.30, 0.22},
        idle = {
            filename = ei_robots_entity_path .. "advanced-construction-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128,
            height = 128,
            scale = 0.5,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        shadow_idle = {
            filename = ei_robots_entity_path .. "advanced_construction_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        in_motion = {
            filename = ei_robots_entity_path .. "advanced-construction-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128,
            height = 128,
            scale = 0.5,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        shadow_in_motion = {
            filename = ei_robots_entity_path .. "advanced_construction_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
    },
    {
        name = "ei-construction-bot",
        type = "construction-robot",
        icon = ei_robots_item_path .. "construction-bot.png",
        icon_size = 64,
        flags = {"placeable-player", "player-creation", "placeable-off-grid", "not-on-map"},
        max_health = 1400,
        corpse = "big-remnants",
        collision_box = {{0, 0}, {0, 0}},
        selection_box = {{-0.5, -1.5}, {0.5, 0.5}},
        minable = {
            mining_time = 1,
            result = "ei-construction-bot",
        },
        working_light = {intensity = 0.8, size = 3},
        max_payload_size = 5,
        speed = 0.1,
        transfer_distance = 0.5,
        max_energy = "5MJ",
        energy_per_tick = "0.1kJ",
        speed_multiplier_when_out_of_energy = 0.2,
        energy_per_move = "10kJ",
        min_to_charge = 0.2,
        max_to_charge = 0.9,
        cargo_centered = {0.0, 0.2},
        construction_vector = {0.30, 0.22},
        idle = {
            filename = ei_robots_entity_path .. "construction-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128 * 2,
            height = 128 * 2,
            scale = 0.25,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        in_motion = {
            filename = ei_robots_entity_path .. "construction-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 128 * 2,
            height = 128 * 2,
            scale = 0.25,
            frame_count = 1,
            shift = {0, 0},
            direction_count = 16,
        },
        shadow_idle = {
            filename = ei_robots_entity_path .. "construction_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            y = 29,
            draw_as_shadow = true,
        },
        shadow_in_motion = {
            filename = ei_robots_entity_path .. "construction_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        working = {
            filename = ei_robots_entity_path .. "construction-bot_animation.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        shadow_working = {
            filename = ei_robots_entity_path .. "construction_bot_shadow.png",
            priority = "high",
            line_length = 16,
            width = 58,
            height = 29,
            frame_count = 1,
            direction_count = 16,
            draw_as_shadow = true,
        },
        smoke = {
            filename = "__base__/graphics/entity/smoke-construction/smoke-01.png",
            width = 39,
            height = 32,
            frame_count = 19,
            line_length = 19,
            shift = {0.078125, -0.15625},
            animation_speed = 0.3,
        },
    },
    {
        name = "ei-advanced-port",
        type = "roboport",
        icon = ei_robots_item_path .. "advanced-port.png",
        icon_size = 64,
        flags = {"placeable-player", "placeable-neutral", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-advanced-port",
        },
        fast_replaceable_group = "roboport",
        max_health = 2000,
        corpse = "big-remnants",
        collision_box = {{-4.8, -4.8}, {4.8, 4.8}},
        selection_box = {{-5, -5}, {5, 5}},
        resistances = {
            {type = "fire", percent = 60},
            {type = "impact", percent = 30}
        },
        dying_explosion = "medium-explosion",
        energy_source = {
            type = "electric",
            buffer_capacity = "1GJ",
            input_flow_limit = "300MW",
            usage_priority = "secondary-input",
        },
        energy_usage = "8MW",
        recharge_minimum = "40MJ",
        charging_energy = "12MW",
        logistics_radius = 115,
        construction_radius = 115,
        charge_approach_distance = 20,
        robot_slots_count = 20,
        material_slots_count = 20,
        stationing_offset = {0, -1},
        charging_offsets = {{-3, -0.75}, {3, -0.75}, {-2, 2.85}, {2, 2.85}, {-2, -2.85}, {2, -2.85},
    {-1.5, -0.25}, {1.5, -0.25}, {-1, 1.55}, {1, 1.55}, {-1, -1.05}, {1, -1.05}},
--        charging_offsets = {{-3, -1}, {3, -1}, {-2, 2.6}, {2, 2.6}, {-2, -2.6}, {2, -2.6},
--    {-1.5, -0.5}, {1.5, -0.5}, {-1, 1.3}, {1, 1.3}, {-1, -1.3}, {1, -1.3}},
        robots_shrink_when_entering_and_exiting = true,
        request_to_open_door_timeout = 15,
        spawn_and_station_height = 1,
        base = {
            layers = {
                {
                    filename = ei_robots_entity_path .. "advanced-port.png",
                    width = 512,
                    height = 512,
                    scale = 0.7,
                },
                {
                    filename = "__base__/graphics/entity/roboport/roboport-shadow.png",
                    width = 294,
                    height = 201,
                    draw_as_shadow = true,
                    shift = {0.5, 0.5},
                    scale = 1.0,
                },
            },
        },
        base = {
            filename = ei_robots_entity_path.."advanced-port.png",
            width = 512,
            height = 512,
            scale = 0.7,
        },
        base_patch = {
            filename = ei_robots_entity_path.."advanced-port.png",
            width = 512,
            height = 512,
            scale = 0.7,
        },
        base_animation = {
            filename = ei_robots_entity_path.."/64x64_empty.png",
            width = 64,
            height = 64,
            shift = {0, 0},
            size = 1,
            frame_count = 1,
            animation_speed = 1,
        },
        door_animation_up = {
            filename = ei_robots_entity_path.."advanced-port_animation.png",
            width = 512,
            height = 512,
            scale = 0.7,
            line_length = 5,
            --lines_per_file = 1,
            animation_speed = 0.5,
            frame_count = 5,
        },
        door_animation_down = {
            filename = ei_robots_entity_path.."advanced-port_animation.png",
            width = 512,
            height = 512,
            scale = 0.7,
            line_length = 5,
            --lines_per_file = 1,
            animation_speed = 0.5,
            frame_count = 5,
        },
        recharging_animation = {
            filename = "__base__/graphics/entity/roboport/roboport-recharging.png",
			priority = "high",
			width = 37,
			height = 35,
			frame_count = 16,
			scale = 3,
			animation_speed = 0.5
        },

        circuit_wire_connection_point = circuit_connector_definitions["roboport"].points,
        circuit_connector_sprites = circuit_connector_definitions["roboport"].sprites,
        circuit_wire_max_distance = 20,
        default_available_logistic_output_signal = {type = "virtual", name = "signal-X"},
        default_total_logistic_output_signal = {type = "virtual", name = "signal-Y"},
        default_available_construction_output_signal = {type = "virtual", name = "signal-Z"},
        default_total_construction_output_signal = {type = "virtual", name = "signal-T"},
    },
})



table.insert(
    data.raw.technology["ei-construction-bots"].prerequisites,
    "ei-electronic-parts"
)


table.insert(
    data.raw.technology["ei-cargo-bots"].prerequisites,
    "ei-electronic-parts"
)

data.raw.recipe["ei-construction-bot"].ingredients = {
    {type="item", name="construction-robot", amount=1},
    {type="item", name="fast-inserter", amount=2},
    {type="item", name="ei-electronic-parts", amount=2}
}

data.raw.technology["ei-advanced-port"].prerequisites = {
    "ei-neodym-refining",
    "ei-nano-factory",
}

data.raw.technology["ei-advanced-bots"].prerequisites = {
    "ei-quantum-computer",
    "ei-nano-factory",
}

data.raw.recipe["ei-advanced-bot-engine"].ingredients = {
    {type="item", name="flying-robot-frame", amount=2},
    {type="item", name="ei-carbon-structure", amount=3},
    {type="item", name="ei-advanced-motor", amount=2},
    {type="item", name="ei-superior-data", amount=1},
    {type="fluid", name="lubricant", amount=50},
}

data.raw.recipe["ei-advanced-port"].ingredients = {
    {type="item", name="roboport", amount=4},
    {type="item", name="processing-unit", amount=25},
    {type="item", name="ei-advanced-motor", amount=15},
    {type="item", name="ei-magnet", amount=6},
}