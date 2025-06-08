ei_data = require("lib/data")

--====================================================================================================
-- PLASMA TURRET
--====================================================================================================

data:extend({
    {
        name = "ei-plasma-turret",
        type = "item",
        icon = ei_graphics_item_path.."plasma-turret.png",
        icon_size = 64,
        subgroup = "defensive-structure",
        order = "c-a",
        place_result = "ei-plasma-turret",
        stack_size = 50
    },
    {
        name = "ei-plasma-turret",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 4,
        ingredients =
        {
            {type = "fluid", name = "electrolyte", amount = 800},
            {type = "item", name = "superconductor", amount = 140},
            {type = "item", name = "holmium-plate", amount = 140},
            {type = "item", name = "ei-induction-matrix-core", amount = 1},
            {type = "item", name = "ei-induction-matrix-advanced-solenoid", amount = 8},
            {type = "item", name = "ei-induction-matrix-superior-coil", amount = 8},
            {type = "item", name = "ei-induction-matrix-superior-converter", amount = 8},
            {type="item", name="laser-turret", amount=4},
            {type="item", name="ei-high-energy-crystal", amount=80},
            {type="item", name="ei-high-tech-parts", amount=100},
            {type="item", name="ei-magnet", amount=100},
            {type="item", name="ei-superior-data", amount=100},
            {type="item", name="ei-plasma-data", amount=100},
        },
        results = {{type="item", name="ei-plasma-turret", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-plasma-turret",
    },
    {
        name = "ei-plasma-turret",
        type = "technology",
        icon = ei_graphics_tech_path.."plasma-turret.png",
        icon_size = 256,
        prerequisites = {"ei-plasma-heater"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-plasma-turret"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    },
    {
        type = "electric-turret",
        name = "ei-plasma-turret",
        icon = ei_graphics_item_path.."plasma-turret.png",
        icon_size = 64,
        flags = {"placeable-player", "player-creation"},
        minable = {
            mining_time = 0.5,
            result = "ei-plasma-turret"
        },
        max_health = 2000,
        corpse = "big-remnants",
        dying_explosion = "big-explosion",
--        collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
--        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        collision_box = {{-2.8, -2.8}, {2.8, 2.8}},
        selection_box = {{-3, -3}, {3, 3}},
        resistances = {
			{type = "physical", percent = 50},
			{type = "fire", percent = 75},
			{type = "impact", percent = 75}
		},
        energy_source = {
			type = "electric",
			buffer_capacity = "950MJ",
			input_flow_limit = "400MW",
			drain = "70MW",
			usage_priority = "primary-input"
		},
        rotation_speed = 0.0025,
        preparing_speed = 0.06,
        folding_speed = 0.06,
        attacking_speed = 0.2,
        prepare_range = 210,
        folded_animation = {
            filename = ei_graphics_entity_path.."plasma-turret_animation.png",
            size = {512,512},
            shift = {0, 0},
	        scale = 0.7,
            line_length = 8,
            lines_per_file = 8,
            direction_count = 64,
            animation_speed = 0.35,
        },
        energy_glow_animation = {
                filename = "__base__/graphics/entity/laser-turret/laser-turret-shooting-light.png",
                line_length = 8,
                width = 122,
                height = 116,
                direction_count = 64,
                shift = util.by_pixel(-0.5, -35),
                blend_mode = "additive",
                color = {r = 0.45, g = 0.1, b = 0.6},
                scale = 2.5,
                apply_runtime_tint = true,
            },
        glow_light_intensity = 0.6,
        attacking_animation = {
            layers = {
                {
                    filename = ei_graphics_entity_path.."plasma-turret_animation.png",
                    size = {512,512},
                    shift = {0, 0},
                    scale = 0.7,
                    line_length = 8,
                    lines_per_file = 8,
                    direction_count = 64,
                    animation_speed = 0.35,
                }
            }
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
        call_for_help_radius = 40,
        attack_parameters = {
            type = "projectile",
            ammo_category = "electric",
            cooldown = 300,
            projectile_center = {0, 0.14},
            projectile_creation_distance = 2.3,
            range = 200,
            min_range = 40,
            health_penalty = -1000,
            rotate_penalty = 100,
            sound = {
                
                aggregation = {
                    max_count = 40,
                    remove = true
                },
                variations = {
                        {
                            filename = ei_graphics_2_path.."sounds/weapons/plasma_turret_firing_1.ogg",
                            volume = 0.9
                        },
                        {
                            filename = ei_graphics_2_path.."sounds/weapons/plasma_turret_firing_2.ogg",
                            volume = 0.95
                        },
                        {
                            filename = ei_graphics_2_path.."sounds/weapons/plasma_turret_firing_3.ogg",
                            volume = 0.95
                        },
                        {
                            filename = ei_graphics_2_path.."sounds/weapons/plasma_turret_firing_4.ogg",
                            volume = 0.9
                        },
                        {
                            filename = ei_graphics_2_path.."sounds/weapons/plasma_turret_firing_5.ogg",
                            volume = 0.95
                        },
                        {
                            filename = ei_graphics_2_path.."sounds/weapons/plasma_turret_firing_6.ogg",
                            volume = 0.9
                        }
                    }
                
            },
            damage_modifier = 1,
            ammo_type = {
                type = "projectile",
                category = "electric",
                energy_consumption = "900MJ",
                projectile = "ei-plasma-bullet",
                speed = 10,
                action = {
                    type = "direct",
                    action_delivery = {
                        type = "projectile",
                        projectile = "ei-plasma-bullet",
                        starting_speed = 0.1,
                        direction_deviation = 0.5,
                        range_deviation = 0.5,
                        max_range = 300,
                    }
                }
            }
        },
    },
    {
        name = "ei-plasma-bullet",
        type = "projectile",
        flags = {"not-on-map"},
        acceleration = 0.07,
        action = {
            action_delivery = {
                target_effects = {
                    {
                        type = "damage",
                        damage = {amount = 2500, type = "electric"},
                        force = "not-same",
                    },
                    {
                        action = {
                            action_delivery = {
                                target_effects = {
                                    {
                                        damage = {amount = 1250,type = "explosion"},
                                        force = "not-same",
                                        type = "damage"
                                    },
                                },
                                type = "instant"
                            },
                            radius = 13.5,
                            type = "area"
                        },
                        type = "nested-result"
                    },
                    {
                        type = "create-entity",
                        entity_name = "ei-plasma-explosion"
                    },
                    {
                        check_buildability = true,
                        entity_name = "huge-scorchmark-tintable",
                        type = "create-entity"
                    },
                    {
                        repeat_count = 1,
                        type = "invoke-tile-trigger"
                    },
                    {
                        decoratives_with_trigger_only = false,
                        from_render_layer = "decorative",
                        include_decals = false,
                        include_soft_decoratives = true,
                        invoke_decorative_trigger = true,
                        radius = 13.5,
                        to_render_layer = "object",
                        type = "destroy-decoratives"
                    }
                },
                type = "instant",
            },
            type = "direct",
        },
        animation = {
            filename = ei_graphics_other_path.."plasma-bullet.png",
            width = 3,
            height = 50,
            shift = {0, 0},
            scale = 10,
            frame_count = 1,
            draw_as_glow = true,
            priority = "high",
        },
    },
    {
        name = "ei-plasma-explosion",
        type = "explosion",
        flags = {"not-on-map"},
        animations = {
            {
                filename = ei_graphics_other_path.."plasma-explosion.png",
                size = {1944/6, 1248/3},
                shift = {0, -6},
                scale = 3,
                line_length = 6,
                lines_per_file = 6,
                frame_count = 36,
                animation_speed = 0.3,
                draw_as_glow = true,
                priority = "high",
            },
        },
        light_intensity_peak_end_progress = 0.6,
        light_size_peak_start_progress = 0.0675,
        light_size_peak_end_progress = 0.9,
        scale_out_duration = 45,
        scale_end = 0.85,
        scale_animation_speed = true,
        light = {
            intensity = 0.85,
            blend_mode = "multiplicative",
            draw_as_glow = true,
            color = {r = 0.45, g = 0.1, b = 0.6},
            size = 125
        },
        sound = {
            aggregation = {
                max_count = 40,
                remove = true
            },
            variations = {
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_1.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_2.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_3.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_4.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_5.ogg",
                    volume = 0.95
                },
                {
                    filename = ei_graphics_2_path.."sounds/weapons/plasma_bullet_explosion_6.ogg",
                    volume = 0.95
                }
            }
        },
        smoke = "smoke-fast",
        smoke_count = 2,
        smoke_slow_down_factor = 1,

        created_effect = {
            type = "direct",
            action_delivery = {
                type = "instant",
                target_effects = {
                    {
                        type = "create-entity",
                        entity_name = "medium-scorchmark",
                        check_buildability = true
                    }
                }
            }
        },
        
        subgroup = "explosions",
        order = "c-a-a"
    }
    
})