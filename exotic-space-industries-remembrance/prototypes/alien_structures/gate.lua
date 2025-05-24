local ei_lib = require("lib/lib")

--====================================================================================================
--GATE
--====================================================================================================
local gate_glow = {
    type = "sprite",
    name = "gate_glow",
    filename = ei_graphics_glow_path.."big_pngs/glow_3.png",
    priority = "high",
    width = 820,
    height = 826,
    scale = 1,
    frame_count = 3,
    animation_speed = 0.3,
}

data:extend({
        gate_glow,
    {
        name = "ei-gate",
        type = "item",
        icon = ei_graphics_item_2_path.."gate.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-b",
        place_result = "ei-gate",
        stack_size = 10
    },
    {
        name = "ei-gate",
        type = "recipe",
        category = "crafting",
        energy_required = 30,
        ingredients =
        {
            {type="item", name="concrete", amount=50},
            {type="item", name="ei-electronic-parts", amount=100},
            {type="item", name="battery", amount=200},
            {type="item", name="ei-high-energy-crystal", amount=50},
            {type="item", name="steel-plate", amount=200},
            {type="item", name="ei-steel-mechanical-parts", amount=100}
        },
        results = {{type="item", name="ei-gate", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-gate",
    },
    {
        name = "ei-gate",
        type = "technology",
        icon = ei_graphics_tech_2_path.."gate.png",
        icon_size = 256,
        prerequisites = {"ei-alien-computer-age-tech","ei-gaia"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-gate"
            },
            -- {
            --     type = "unlock-recipe",
            --     recipe = "ei-gaia-pump"
            -- },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["alien-computer-age"],
            time = 20
        },
        -- age = "advanced-computer-age",
    },
    {
        name = "ei-gate",
        type = "electric-energy-interface",
        icon = ei_graphics_item_2_path.."gate.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        max_health = 1000,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-5.4, -5.4}, {5.4, 5.4}},
        selection_box = {{-5.4, -5.4}, {5.4, 5.4}},
        map_color = ei_data.colors.assembler,
        -- minable = {mining_time = 1, result = "ei-gate"},
        gui_mode = "none",
        -- overlay other when no power and no destination
        --[[
        animation = {
            filename = ei_graphics_entity_2_path.."gate_animation.png",
            width = 1024,
            height = 1024,
            shift = {0, -1},
            scale = 0.39,
            line_length = 4,
            lines_per_file = 4,
            frame_count = 16,
            animation_speed = 0.3,
            run_mode = "backward",
        },
        picture = {
            filename = ei_graphics_path.."graphics/64_empty.png",
            width = 64,
            height = 64,
        },
        ]]
        picture = {
            filename = ei_graphics_entity_2_path.."gate.png",
            width = 1024,
            height = 1024,
            shift = {0, -1},
            scale = 0.39
        },
        -- continuous_animation = true,
        energy_source = {
            type = "electric",
            buffer_capacity = "50GJ",
            usage_priority = "secondary-input",
            input_flow_limit = "1GW",
            output_flow_limit = "0MW",
        },
        energy_usage = "200MW",
        selectable_in_game = false,
    },
    {
        name = "ei-gate-container",
        type = "container",
        inventory_size = 30,
        picture = {
            filename = ei_graphics_entity_2_path.."gate.png",
            width = 1024,
            height = 1024,
            shift = {0, -1},
            scale = 0.39
        },
        inventory_type = "with_filters_and_bar",
        health = 3000,
        minable = {mining_time = 1, --[[result = "ei-gate"]]},
        flags = {"not-blueprintable", "not-on-map", "not-flammable", "not-repairable", "not-upgradable", "hide-alt-info", "not-deconstructable"},
        hidden = true,
        collision_box = {{-5.4, -5.4}, {5.4, 5.4}},
        selection_box = {{-5.5, -5.5}, {5.5, 5.5}},
        --circuit_wire_connection_point = data.raw["container"]["steel-chest"].circuit_wire_connection_point,
        circuit_wire_max_distance = data.raw["container"]["steel-chest"].circuit_wire_max_distance,
        circuit_connector_sprites = ei_lib.make_circuit_connector(-0.77, 1.6)[2],
        circuit_wire_connection_point = ei_lib.make_circuit_connector(-0.77, 1.6)[1]
    },
    {
        type = "animation",
        name = "ei-gate-running",
        priority = "extra-high",
        filename = ei_graphics_entity_2_path.."gate_animation.png",
        width = 1024,
        height = 1024,
        shift = {0, -1},
        scale = 0.39,
        line_length = 4,
        lines_per_file = 4,
        frame_count = 16,
        animation_speed = 0.3,
        run_mode = "backward",
    },
    {
        type = "animation",
        name = "ei-exit-simple",
        priority = "extra-high",
        filename = ei_graphics_entity_2_path.."exit_simple.png",
        width = 512,
        height = 512,
        shift = {0, 0},
        scale = 0.35,
        line_length = 4,
        lines_per_file = 4,
        frame_count = 16,
        animation_speed = 0.3,
        run_mode = "backward",
    },
    {
        type = "capsule",
        name = "ei-gate-remote",
        icon = ei_graphics_item_2_path.."gate-remote.png",
        icon_size = 64,
        stack_size = 1,
        flags = {"only-in-cursor"},
        hidden = true,
        capsule_action = {
            type = "throw",
            uses_stack = false,
            attack_parameters = {
                type = "projectile",
                range = 1000,
                cooldown = 60,
                ammo_category = "ei-gate-remote-ammo",
                ammo_type = {
                    target_type = "position",
                    action = {
                        type = "direct",
                        action_delivery = {
                            type = "instant",
                            target_effects = {
                                {
                                    type = "script",
                                    effect_id = "ei-gate-remote"
                                }
                            }
                        }
                    }
                }
            }
        }
    },
    {
        type = "ammo-category",
        name = "ei-gate-remote-ammo"
    },
    {
        type = "sprite",
        name = "ei-gate-remote-sprite",
        filename = ei_graphics_entity_2_path.."position_marker.png",
        width = 258,
        height = 183,
    }
    --[[
    {
        type = "artillery-flare",
        name = "ei-gate-flare",
        pictures = data.raw["artillery-flare"]["artillery-flare"].pictures,
        render_layer = "higher-object-under",
        render_layer_when_on_ground = "higher-object-under",
        shots_per_flare = 0,
        life_time = 60,
        map_color = {r=1, g=0, b=0},

    }
    ]]
})