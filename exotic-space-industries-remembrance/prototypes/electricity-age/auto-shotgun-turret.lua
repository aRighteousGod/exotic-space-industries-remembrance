--originally from Factorio+ by fishbus
---------------------------------------- SHOTGUN TURRET ----------------------------------------
shotgun_turret_scale = 0.48

function shotgun_turret_extension(inputs)
	return {
		filename = ei_path .. "graphics/entities/auto-shotgun-turret/shotgun-turret.png",
		priority = "medium",
		width = 1328 / 8,
		height = 1208 / 8,
		direction_count = 8,
		frame_count = 1,
		line_length = 0,
		run_mode = inputs.run_mode or "forward",
		shift = util.by_pixel(2 - 2, -16),
		axially_symmetrical = false,
		scale = shotgun_turret_scale,
	}
end

function shotgun_turret_extension_mask(inputs)
	return {
		filename = ei_path .. "graphics/entities/auto-shotgun-turret/shotgun-turret-mask.png",
		flags = { "mask" },
		width = 1328 / 8,
		height = 1208 / 8,
		direction_count = 8,
		frame_count = 1,
		line_length = 0,
		run_mode = inputs.run_mode or "forward",
		shift = util.by_pixel(2 - 2, -16),
		axially_symmetrical = false,
		apply_runtime_tint = true,
		scale = shotgun_turret_scale,
	}
end

function shotgun_turret_extension_shadow(inputs)
	return {
		filename = ei_path .. "graphics/entities/auto-shotgun-turret/shotgun-turret-shadow.png",
		width = 1328 / 8,
		height = 1208 / 8,
		direction_count = 8,
		frame_count = 1,
		line_length = 0,
		run_mode = inputs.run_mode or "forward",
		shift = util.by_pixel(19, 2),
		axially_symmetrical = false,
		draw_as_shadow = true,
		scale = shotgun_turret_scale,
	}
end

function shotgun_turret_attack(inputs)
	return {
		layers = {
			{
				filename = ei_path .. "graphics/entities/auto-shotgun-turret/shotgun-turret.png",
				priority = "low",
				line_length = 8,
				width = 1328 / 8,
				height = 1208 / 8,
				frame_count = 1,
				direction_count = 64,
				shift = util.by_pixel(2 - 2, -16),
				animation_speed = 8,
				scale = shotgun_turret_scale,
			},
			{
				filename = ei_path .. "graphics/entities/auto-shotgun-turret/shotgun-turret-mask.png",
				flags = { "mask" },
				width = 1328 / 8,
				height = 1208 / 8,
				direction_count = 64,
				frame_count = 1,
				line_length = 8,
				run_mode = inputs.run_mode or "forward",
				shift = util.by_pixel(2 - 2, -16),
				axially_symmetrical = false,
				apply_runtime_tint = true,
				scale = shotgun_turret_scale,
			},
			{
				filename = ei_path .. "graphics/entities/auto-shotgun-turret/shotgun-turret-shadow.png",
				width = 1328 / 8,
				height = 1208 / 8,
				direction_count = 64,
				frame_count = 1,
				line_length = 8,
				run_mode = inputs.run_mode or "forward",
				shift = util.by_pixel(19, 2),
				axially_symmetrical = false,
				draw_as_shadow = true,
				scale = shotgun_turret_scale,
			},
		},
	}
end

data:extend({
	{
		type = "item",
		name = "ei-auto-shotgun-turret",
		icon = ei_path .. "graphics/icons/auto-shotgun-turret.png",
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = "defensive-structure",
		order = "b[turret]-a[gun-turret]",
		place_result = "ei-auto-shotgun-turret",
		stack_size = 50,
	},
	{
		type = "ammo-turret",
		name = "ei-auto-shotgun-turret",
		placeable_by = { item = "ei-auto-shotgun-turret", count = 1 },
		icon = ei_path .. "graphics/icons/auto-shotgun-turret.png",
		icon_size = 64,
		icon_mipmaps = 4,
		circuit_connector = data.raw["ammo-turret"]["gun-turret"].circuit_connector,
		circuit_wire_max_distance = default_circuit_wire_max_distance,
		flags = { "placeable-player", "player-creation"},
		minable = { mining_time = 0.5, result = "ei-auto-shotgun-turret" },
        fast_replaceable_group = "ei-shotgun-turret",
		max_health = 800,
		heating_energy = "50kW",
		--turret_base_has_direction = true,
		hide_resistances = false,
        energy_source =
            {
                type = "electric",
                buffer_capacity = "66kJ",
                --input_flow_limit = "500kW",
                drain = "2kW",
                usage_priority = "primary-input"
            },
        energy_per_shot = "22kJ",
        resistances = {
			{type = "physical", percent = 50},
			{type = "fire", percent = 75},
			{type = "impact", percent = 75},
		},
		corpse = "small-remnants",
		dying_explosion = "gun-turret-explosion",
		collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
		selection_box = { { -1, -1 }, { 1, 1 } },
		damaged_trigger_effect = hit_effects.entity(),
		rotation_speed = 0.004958333*4,
		preparing_speed = 0.8,
		preparing_sound = sounds.gun_turret_activate,
		folding_sound = sounds.gun_turret_deactivate,
		folding_speed = 1,
		inventory_size = 1,
		automated_ammo_count = 10,
		attacking_speed = 1.0,
		alert_when_attacking = true,
		open_sound = sounds.machine_open,
		close_sound = sounds.machine_close,
		folded_animation = {
			layers = {
				shotgun_turret_extension({ frame_count = 1, line_length = 1 }),
				shotgun_turret_extension_mask({ frame_count = 1, line_length = 1 }),
				shotgun_turret_extension_shadow({ frame_count = 1, line_length = 1 }),
			},
		},
		preparing_animation = {
			layers = {
				shotgun_turret_extension({}),
				shotgun_turret_extension_mask({}),
				shotgun_turret_extension_shadow({}),
			},
		},
		prepared_animation = shotgun_turret_attack({ frame_count = 1 }),
		attacking_animation = shotgun_turret_attack({}),
		folding_animation = {
			layers = {
				shotgun_turret_extension({ run_mode = "backward" }),
				shotgun_turret_extension_mask({ run_mode = "backward" }),
				shotgun_turret_extension_shadow({ run_mode = "backward" }),
			},
		},
		graphics_set = {
			base_visualisation = {
				animation = {
					layers = {
						{
							filename = "__base__/graphics/entity/laser-turret/laser-turret-base.png",
							priority = "high",
							width = 138,
							height = 104,
							direction_count = 1,
							frame_count = 1,
							shift = util.by_pixel(-0.5, 2),
							scale = 0.5,
						},
						{
							filename = "__base__/graphics/entity/laser-turret/laser-turret-base-shadow.png",
							line_length = 1,
							width = 132,
							height = 82,
							draw_as_shadow = true,
							direction_count = 1,
							frame_count = 1,
							shift = util.by_pixel(6, 3),
							scale = 0.5,
						},
					},
				},
			},
		},
		vehicle_impact_sound = sounds.generic_impact,

		attack_parameters = {
			type = "projectile",
			ammo_category = "shotgun-shell",
			cooldown = 30,
			rotate_penalty = 0.25, -- >0 will discourage turrets from targeting units that would take longer to turn to face.
			health_penalty = 0.5, -- >0 will discourage turrets from targeting units with higher health. <0 will encourage turrets to target units with higher health.
            projectile_creation_distance = 1.2,
			projectile_center = util.by_pixel(0, 7),
			damage_modifier = 1.0,
			--turn_range = 0.25,
			shell_particle = {
				name = "shell-particle",
				direction_deviation = 0.1,
				speed = 0.25,
				speed_deviation = 0.03,
                center = {-0.0625, 0},
                creation_distance = 1.24,
				starting_frame_speed = 0.2,
				starting_frame_speed_deviation = 0.1,
			},
			range = 18,
			sound = sounds.shotgun,
		},
		icon_draw_specification = { scale = 0.75 },
		call_for_help_radius = 40,
		water_reflection = {
			pictures = {
				filename = "__base__/graphics/entity/gun-turret/gun-turret-reflection.png",
				priority = "extra-high",
				width = 20,
				height = 32,
				shift = util.by_pixel(0, 40),
				variation_count = 1,
				scale = 5,
			},
			rotate = false,
			orientation_to_variation = false,
		},
	},
	{
		name = "ei-auto-shotgun-turret",
		type = "recipe",
		category = "crafting",
		energy_required = 8,
		ingredients = {
			{ type = "item", name = "ei-shotgun-turret", amount = 1 },
			{ type = "item", name = "combat-shotgun", amount = 1 },
            {type="item", name="ei-steel-mechanical-parts", amount=12},
            {type="item", name="electric-engine-unit", amount=2},
            {type="item", name="advanced-circuit", amount=2}
		},
		results = { { type = "item", name = "ei-auto-shotgun-turret", amount = 1 } },
		enabled = false,
		always_show_made_in = true,
		main_product = "ei-auto-shotgun-turret",
	},
	{
		name = "ei-auto-shotgun-turret",
		type = "technology",
		icon = ei_path .. "graphics/tech/auto-shotgun-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		prerequisites = { "ei-shotgun-turret", "ei-electricity-power", "military-3", "advanced-circuit", "electric-engine" },
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-auto-shotgun-turret",
			},
		},
		unit = {
			count = 100,
			ingredients = ei_data.science["electricity-age"],
			time = 20,
		},
		age = "electricity-age",
	},
})

table.insert(
	data.raw.technology["physical-projectile-damage-1"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-2"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-3"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-4"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-5"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-6"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-7"].effects,
	{ type = "turret-attack", turret_id = "ei-auto-shotgun-turret", modifier = 0.2 }
)