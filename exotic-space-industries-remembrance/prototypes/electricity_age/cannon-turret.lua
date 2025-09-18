ei_data = require("lib/data")
local sounds = require("__base__/prototypes/entity/sounds")
--====================================================================================================
-- CANNON TURRET MK2
--====================================================================================================

data:extend({
    {
        name = "ei-cannon-turret",
        type = "item",
        icon = ei_graphics_item_path.."cannon-turret.png",
        icon_size = 64,
        subgroup = "defensive-structure",
        order = "c-ab",
        place_result = "ei-cannon-turret",
        stack_size = 50
    },
    {
        name = "ei-cannon-turret",
        type = "recipe",
        category = "crafting",
        energy_required = 8,
        order = "b[turret]-a3[laser-turret]",
        ingredients =
        {
            {type="item", name="ei-cannon-turret-mk1", amount=2},
            {type="item", name="ei-steel-mechanical-parts", amount=35},
            {type="item", name="electric-engine-unit", amount=15},
            {type="item", name="advanced-circuit", amount=8}
        },
        results = {{type="item", name="ei-cannon-turret", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-cannon-turret",
    },
    {
        name = "ei-cannon-turret",
        type = "technology",
        icon = ei_graphics_tech_path.."cannon-turret.png",
        icon_size = 256,
        prerequisites = {"advanced-circuit","ei-cannon-turret-mk1","electric-engine","ei-electricity-power"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-cannon-turret"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        type = "ammo-turret",
        name = "ei-cannon-turret",
        icon = ei_graphics_item_path.."cannon-turret.png",
        icon_size = 64,
        flags = {"placeable-player", "player-creation"},
        minable = {
            mining_time = 0.75,
            result = "ei-cannon-turret"
        },
        max_health = 1500,
        corpse = "medium-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        resistances = {
			{type = "physical", percent = 50},
			{type = "fire", percent = 75},
			{type = "impact", percent = 75},
		},
        rotation_speed = 0.005,
        preparing_speed = 0.04,
        folding_speed = 0.04,
        inventory_size = 1,
        heating_energy = "100kW",
        automated_ammo_count = 10,
        attacking_speed = 0.6,
        preparing_sound = sounds.gun_turret_activate,
        folding_sound = sounds.gun_turret_deactivate,
        alert_when_attacking = true,
        open_sound = sounds.machine_open,
        close_sound = sounds.machine_close,
        folded_animation = {
            filename = ei_graphics_entity_path.."cannon-turret_animation.png",
            size = {512,512},
            shift = {0, 0},
	        scale = 0.35,
            line_length = 8,
            lines_per_file = 8,
            direction_count = 64,
            animation_speed = 0.35,
        },
        attacking_animation = {
            filename = ei_graphics_entity_path.."cannon-turret_animation.png",
            size = {512,512},
            shift = {0, 0},
            scale = 0.35,
            line_length = 8,
            lines_per_file = 8,
            direction_count = 64,
            animation_speed = 0.35,
        },
        graphics_set = {
            base_visualisation = {
                animation = {
                    layers = {
                        {
                            filename = ei_graphics_other_path.."64_empty.png",
                            size = {64,64},
                            shift = {0, 0},
                            scale = 0.44/2,
                            line_length = 1,
                            direction_count = 1,
                            frame_count = 1,
                        }
                    }
                }
            }
        },
        energy_source =
            {
                type = "electric",
                buffer_capacity = "666kJ",
                --input_flow_limit = "500kW",
                drain = "12kW",
                usage_priority = "primary-input"
            },
        call_for_help_radius = 45,
        energy_per_shot = "200kJ",
        attack_parameters = {
            type = "projectile",
            ammo_category = "cannon-shell",
            lead_target_for_projectile_speed = 0.125,
            cooldown = 108,
            projectile_center = {0, 0.14},
            projectile_creation_distance = 2,
            range = 30,
            prepare_range = 34,
            min_range = 10,
            rotate_penalty = 20,
            health_penalty = -10,
            sound = {
                {
                    filename = "__base__/sound/fight/tank-cannon.ogg",
                    volume = 0.8
                }
            },
            shell_particle = {
                name = "shell-particle",
                direction_deviation = 0.1,
                speed = 0.125,
                speed_deviation = 0.03,
                center = {-0.0625, 0},
                creation_distance = -1.925,
                starting_frame_speed = 0.21,
                starting_frame_speed_deviation = 0.1
            },
        },
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation =  6, main_offset = util.by_pixel(-41.375,  10.875), shadow_offset = util.by_pixel(-41.375,  10.875), show_shadow = true },
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance
    }
    
})