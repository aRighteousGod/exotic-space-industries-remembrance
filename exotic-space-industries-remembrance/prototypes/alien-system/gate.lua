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

local gate_wire_proxy = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
gate_wire_proxy.name = "ei-gate-circuit-interface"
gate_wire_proxy.icon = ei_graphics_other_path.."64_empty.png"
gate_wire_proxy.flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-flammable", "not-repairable", "not-upgradable", "hide-alt-info"}
gate_wire_proxy.hidden = true
gate_wire_proxy.gui_mode = "none"
gate_wire_proxy.selectable_in_game = true
gate_wire_proxy.minable = nil
gate_wire_proxy.max_health = 300
gate_wire_proxy.collision_box = {{0, 0}, {0, 0}}
gate_wire_proxy.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
gate_wire_proxy.item_slot_count = 3
gate_wire_proxy.activity_led_light = {intensity = 0, size = 0, color = {r = 1, g = 1, b = 1}}
gate_wire_proxy.activity_led_sprites = {
    north = util.empty_sprite(),
    east = util.empty_sprite(),
    south = util.empty_sprite(),
    west = util.empty_sprite(),
}
gate_wire_proxy.sprites = {
    north = util.empty_sprite(),
    east = util.empty_sprite(),
    south = util.empty_sprite(),
    west = util.empty_sprite(),
}
gate_wire_proxy.circuit_wire_max_distance = default_circuit_wire_max_distance

data:extend({
        gate_glow,
        gate_wire_proxy,
    {
        name = "ei-gate",
        type = "item",
        icon = ei_graphics_item_2_path.."gate.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-b",
        place_result = "ei-gate-container",
        stack_size = 10
    },
    {
        name = "ei-gate",
        type = "recipe",
        category = "crafting",
        energy_required = 60,
        ingredients =
        {
            {type="item", name="concrete", amount=250},
            {type="item", name="ei-electronic-parts", amount=200},
            {type="item", name="battery", amount=200},
            {type="item", name="ei-high-energy-crystal", amount=100},
            {type="item", name="steel-plate", amount=100},
            {type="item", name="ei-steel-beam", amount=100},
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
        prerequisites = {"ei-alien-computer-age-tech", "ei-purifier"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-gate"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-gate-receiver"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-breach-residue-neutralization"
            },
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
        heating_energy = "500kW",
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-5.4, -5.4}, {5.4, 5.4}},
        selection_box = {{-5.4, -5.4}, {5.4, 5.4}},
        map_color = ei_data.colors.assembler,
        minable = {mining_time = 1},
        selectable_in_game = false,
        --gui_mode = "none",
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
        picture = util.empty_sprite(),
        -- continuous_animation = true,
        energy_source = {
            type = "electric",
            buffer_capacity = "180GJ",
            usage_priority = "secondary-input",
            input_flow_limit = "60GW",
            output_flow_limit = "0MW",
        },
        energy_usage = "0W",
    },
    {
        name = "ei-gate-container",
        type = "container",
        icon = ei_graphics_item_2_path.."gate.png",
        icon_size = 64,
        inventory_size = 30,
        picture = {
            filename = ei_graphics_entity_2_path.."gate.png",
            width = 1024,
            height = 1024,
            shift = {0, -1},
            scale = 0.39,
            render_layer = "lower-object-above-shadow"
        },
        inventory_type = "with_filters_and_bar",
        health = 3000,
        minable = {mining_time = 1, result = "ei-gate"},
        flags = {"placeable-neutral", "placeable-player", "player-creation", "not-blueprintable", "not-on-map", "not-flammable", "not-repairable", "not-upgradable", "hide-alt-info", },
        collision_box = {{-5.4, -5.4}, {5.4, 5.4}},
        selection_box = {{-5.5, -5.5}, {5.5, 5.5}},
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 30, main_offset = util.by_pixel(-93.125,  128), shadow_offset = util.by_pixel(-93.125,  128), show_shadow = true }
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    },
    {
        name = "ei-gate-receiver",
        type = "item",
        icon = ei_graphics_item_2_path.."drone-port.png",
        icon_size = 64,
        subgroup = "ei-alien-structures-2",
        order = "a-b-c",
        place_result = "ei-gate-receiver",
        stack_size = 10
    },
    {
        name = "ei-gate-receiver",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients =
        {
            {type="item", name="steel-plate", amount=30},
            {type="item", name="ei-steel-mechanical-parts", amount=24},
            {type="item", name="ei-electronic-parts", amount=30},
            {type="item", name="battery", amount=20},
            {type="item", name="ei-high-energy-crystal", amount=10}
        },
        results = {{type="item", name="ei-gate-receiver", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-gate-receiver",
    },
    {
        name = "ei-gate-receiver",
        type = "container",
        icon = ei_graphics_item_2_path.."drone-port.png",
        icon_size = 64,
        flags = {"placeable-neutral", "placeable-player", "player-creation"},
        minable = {
            mining_time = 1,
            result = "ei-gate-receiver"
        },
        max_health = 2500,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-2.4, -2.4}, {2.4, 2.4}},
        selection_box = {{-2.5, -2.5}, {2.5, 2.5}},
        map_color = ei_data.colors.assembler,
        inventory_size = 40,
        inventory_type = "with_filters_and_bar",
        picture = {
            filename = ei_graphics_entity_2_path.."drone-port.png",
            size = {512,512},
            shift = {-0.1, 0.2},
            scale = 0.35,
        },
        circuit_connector = circuit_connector_definitions.create_vector(
            universal_connector_template,
            {
                { variation = 26, main_offset = util.by_pixel(-2, 72), shadow_offset = util.by_pixel(-2, 72), show_shadow = true }
            }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    },
    {
        type = "virtual-signal",
        name = "ei-gate-active",
        icons = {
            {
                icon = ei_graphics_item_2_path.."gate.png",
                icon_size = 64,
            },
            {
                icon = ei_graphics_other_path.."overlay_1.png",
                icon_size = 64,
                tint = {r = 0.2, g = 0.95, b = 0.4, a = 0.9},
            },
        },
        order = "ei-gate-a",
    },
    {
        type = "virtual-signal",
        name = "ei-gate-energy",
        icons = {
            {
                icon = ei_graphics_item_2_path.."gate.png",
                icon_size = 64,
            },
            {
                icon = ei_graphics_other_path.."overlay_2.png",
                icon_size = 64,
                tint = {r = 0.25, g = 0.65, b = 1, a = 0.9},
            },
        },
        order = "ei-gate-b",
    },
    {
        type = "virtual-signal",
        name = "ei-gate-stress",
        icons = {
            {
                icon = ei_graphics_item_2_path.."gate.png",
                icon_size = 64,
            },
            {
                icon = ei_graphics_other_path.."overlay_3.png",
                icon_size = 64,
                tint = {r = 1, g = 0.35, b = 0.2, a = 0.9},
            },
        },
        order = "ei-gate-c",
    },
    {
        type = "item",
        name = "ei-breach-residue",
        icon = ei_path.."graphics/items/breach-residue-1.png",
        icon_size = 512,
        icon_mipmaps = 5,
        pictures = {
            {
                filename = ei_path.."graphics/items/breach-residue-1.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_path.."graphics/items/breach-residue-2.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_path.."graphics/items/breach-residue-3.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            }
        },
        subgroup = "ei-refining-secondary",
        order = "z-a",
        stack_size = 100,
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
    },
    {
        type = "selection-tool",
        name = "ei-gate-position-selector",
        icon = ei_graphics_item_2_path.."gate-remote.png",
        icon_size = 64,
        stack_size = 1,
        flags = {"only-in-cursor", "spawnable"},
        hidden = true,
        select = {
            border_color = {r = 0.6, g = 0.2, b = 0.8, a = 0.5},
            mode = {"any-entity", "any-tile"},
            cursor_box_type = "entity",
        },
        alt_select = {
            border_color = {r = 0.6, g = 0.2, b = 0.8, a = 0.5},
            mode = {"any-entity", "any-tile"},
            cursor_box_type = "entity",
        },
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
