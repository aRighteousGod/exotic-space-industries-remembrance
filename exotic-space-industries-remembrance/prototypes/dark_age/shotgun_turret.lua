--originally from Past's defense stuff by @PastTheFuture
data:extend({
	{
		type = "item",
		name = "ei-shotgun-turret",
		icon = ei_path .. "graphics/icons/shotgun-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		subgroup = "defensive-structure",
		order = "b[turret]-a[gun-turret]",
		place_result = "ei-shotgun-turret",
		stack_size = 50,
	},
	{
		type = "ammo-turret",
		name = "ei-shotgun-turret",
		icon = ei_path .. "graphics/icons/shotgun-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		flags = { "placeable-player", "player-creation" },
		minable = { mining_time = 0.5, result = "ei-shotgun-turret" },
		circuit_connector = data.raw["ammo-turret"]["gun-turret"].circuit_connector,
		circuit_wire_max_distance = default_circuit_wire_max_distance,
		max_health = 400,
		heating_energy = "50kW",
		corpse = "gun-turret-remnants",
		dying_explosion = "gun-turret-explosion",
		collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
		selection_box = { { -1, -1 }, { 1, 1 } },
		--damaged_trigger_effect = hit_effects.entity(),
		rotation_speed = 0.004958333,
		preparing_speed = 0.08,
		preparing_sound = sounds.gun_turret_activate,
		folding_sound = sounds.gun_turret_deactivate,
		folding_speed = 0.08,
		inventory_size = 1,
		automated_ammo_count = 10,
		alert_when_attacking = true,
		open_sound = sounds.machine_open,
		close_sound = sounds.machine_close,
		graphics_set = {
			base_visualisation = {
				animation = {
					layers = {
						{
							filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-base.png",
							priority = "high",
							width = 70,
							height = 52,
							frame_count = 1,
							direction_count = 1,
							shift = util.by_pixel(0, 2),
							hr_version = {
								filename = ei_path .. "graphics/entities/shotgun-turret/hr-shotgun-turret-base.png",
								priority = "high",
								width = 138,
								height = 104,
								frame_count = 1,
								direction_count = 1,
								shift = util.by_pixel(-0.5, 2),
								scale = 0.5,
							},
						},
						{
							filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-base-shadow.png",
							width = 66,
							height = 42,
							frame_count = 1,
							direction_count = 1,
							draw_as_shadow = true,
							shift = util.by_pixel(6, 3),
							hr_version = {
								filename = ei_path
									.. "graphics/entities/shotgun-turret/hr-shotgun-turret-base-shadow.png",
								width = 132,
								height = 82,
								frame_count = 1,
								direction_count = 1,
								draw_as_shadow = true,
								shift = util.by_pixel(6, 3),
								scale = 0.5,
							},
						},
					},
				},
			},
		},
		folded_animation = {
			layers = {
				{
					--filename = "__base__/graphics/entity/tank/hr-tank-turret.png",
					priority = "low",
					line_length = 8,
					--width = 179,
					--height = 132,
					width = 71,
					height = 57,
					axially_symmetrical = false,
					frame_count = 1,
					direction_count = 64,
					shift = util.by_pixel(0, -20),
					animation_speed = 8,
					scale = 1,
					stripes = {
						{
							filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-1.png",
							width_in_frames = 1,
							height_in_frames = 32,
						},
						{
							filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-2.png",
							width_in_frames = 1,
							height_in_frames = 32,
						},
					},
				},
				{
					--filename = "__base__/graphics/entity/tank/hr-tank-turret.png",
					priority = "low",
					line_length = 8,
					--width = 179,
					--height = 132,
					width = 71,
					height = 57,
					axially_symmetrical = false,
					apply_runtime_tint = true,
					frame_count = 1,
					direction_count = 64,
					shift = util.by_pixel(0, -20),
					animation_speed = 8,
					scale = 1,
					stripes = {
						{
							filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-mask-1.png",
							width_in_frames = 1,
							height_in_frames = 32,
						},
						{
							filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-mask-2.png",
							width_in_frames = 1,
							height_in_frames = 32,
						},
					},
				},
				{
					--filename = "__base__/graphics/entity/tank/hr-tank-turret-shadow.png",
					filename = "__base__/graphics/entity/car/car-turret-shadow.png",
					priority = "low",
					line_length = 8,
					--width = 193,
					--height = 134,
					width = 46,
					height = 31,
					frame_count = 1,
					draw_as_shadow = true,
					direction_count = 64,
					shift = util.by_pixel(20, -3.5),
					scale = 1,
				},
			},
		},
		--[[ 1.1 proto style
		base_picture = {
			layers = {
				{
					filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-base.png",
					priority = "high",
					width = 70,
					height = 52,
					direction_count = 1,
					frame_count = 1,
					shift = util.by_pixel(0, 2),
					hr_version = {
						filename = ei_path .. "graphics/entities/shotgun-turret/hr-shotgun-turret-base.png",
						priority = "high",
						width = 138,
						height = 104,
						direction_count = 1,
						frame_count = 1,
						shift = util.by_pixel(-0.5, 2),
						scale = 0.5,
					},
				},
				{
					filename = ei_path .. "graphics/entities/shotgun-turret/shotgun-turret-base-shadow.png",
					line_length = 1,
					width = 66,
					height = 42,
					draw_as_shadow = true,
					direction_count = 1,
					frame_count = 1,
					shift = util.by_pixel(6, 3),
					hr_version = {
						filename = ei_path .. "graphics/entities/shotgun-turret/hr-shotgun-turret-base-shadow.png",
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
        ]]
		vehicle_impact_sound = sounds.generic_impact,

		attack_parameters = {
			type = "projectile",
			ammo_category = "shotgun-shell",
			cooldown = 60,
			projectile_creation_distance = 1.39375,
			projectile_center = { 0, -0.0875 },
			shell_particle = {
				name = "shell-particle",
				direction_deviation = 0.1,
				speed = 0.1,
				speed_deviation = 0.03,
				center = { -0.0625, 0 },
				creation_distance = -1.925,
				starting_frame_speed = 0.2,
				starting_frame_speed_deviation = 0.1,
			},
			range = 15,
			sound = sounds.shotgun,
		},

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
		name = "ei-shotgun-turret",
		type = "recipe",
		category = "crafting",
		energy_required = 8,
		ingredients = {
			{ type = "item", name = "shotgun", amount = 1 },
			{ type = "item", name = "gun-turret", amount = 1 },
			{ type = "item", name = "ei-iron-mechanical-parts", amount = 20 },
		},
		results = { { type = "item", name = "ei-shotgun-turret", amount = 1 } },
		enabled = false,
		always_show_made_in = true,
		main_product = "ei-shotgun-turret",
	},
	{
		name = "ei-shotgun-turret",
		type = "technology",
		icon = ei_path .. "graphics/icons/shotgun-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		prerequisites = { "gun-turret", "military" },
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-shotgun-turret",
			},
		},
		unit = {
			count = 100,
			ingredients = ei_data.science["dark-age"],
			time = 20,
		},
		age = "dark-age",
	},
})

table.insert(
	data.raw.technology["physical-projectile-damage-1"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-2"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-3"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-4"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-5"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-6"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-7"].effects,
	{ type = "turret-attack", turret_id = "ei-shotgun-turret", modifier = 0.2 }
)

data:extend({
	{
		type = "projectile",
		name = "ei-dragons-breath-shotgun-pellet",
		flags = { "not-on-map" },
		collision_box = { { -0.05, -0.25 }, { 0.05, 0.25 } },
		acceleration = 0,
		direction_only = true,
		action = {
			{
				type = "area",
				radius = 0.75,
				action_delivery = {
					type = "instant",
					target_effects = {
						{
							type = "damage",
							damage = { amount = 14, type = "explosion" },
						},
					},
				},
			},
			{
				type = "area",
				radius = 2.5,
				action_delivery = {
					type = "instant",
					target_effects = {
						{
							type = "create-sticker",
							sticker = "fire-sticker",
							show_in_tooltip = true,
						},
						{
							type = "damage",
							damage = { amount = 3, type = "fire" },
							apply_damage_to_trees = true,
						},
					},
				},
			},
			{
				type = "direct",
				action_delivery = {
					type = "instant",
					target_effects = {
						{
							type = "create-fire",
							entity_name = "fire-flame",
							show_in_tooltip = true,
							initial_ground_flame_count = 2,
						},
					},
				},
			},
		},
		light = { intensity = 0.85, size = 4, color = { r = 1.0, g = 0.2, b = 0.1 } },
		animation = {
			{
				filename = "__base__/graphics/entity/bullet/bullet.png",
				draw_as_glow = true,
				frame_count = 1,
				width = 3,
				height = 50,
				priority = "high",
			},
			{
				filename = "__base__/graphics/entity/fire-flame/fire-flame-02.png",
				line_length = 10,
				width = 82,
				height = 106,
				frame_count = 90,
				axially_symmetrical = false,
				direction_count = 1,
				draw_as_glow = true,
				blend_mode = "additive",
				animation_speed = 0.125,
				scale = 1,
				tint = { r = 1, g = 1, b = 1, a = 1 },
				flags = nil,
			},
		},
	},
	{
		type = "ammo",
		name = "ei-dragons-breath-shotgun-shell",
		icon = ei_path .. "graphics/icons/dragons-breath-shotgun-shell.png",
		icon_size = 512,
		icon_mipmaps = 5,
		ammo_category = "shotgun-shell",
		ammo_type = {
			target_type = "direction",
			clamp_position = true,
			action = {
				{
					type = "direct",
					action_delivery = {
						type = "instant",
						source_effects = {
							{
								type = "create-explosion",
								entity_name = "explosion-gunshot",
							},
						},
					},
				},
				{
					type = "direct",
					repeat_count = 16,
					action_delivery = {
						type = "projectile",
						projectile = "ei-dragons-breath-shotgun-pellet",
						starting_speed = 1,
						starting_speed_deviation = 0.1,
						direction_deviation = 0.3,
						range_deviation = 0.3,
						max_range = 15,
					},
				},
			},
		},
		magazine_size = 10,
		subgroup = "ammo",
		order = "b[shotgun]-c[incendiary]-b[piercing]",
		stack_size = 100,
	},
	{
		name = "ei-dragons-breath-shotgun-shell",
		type = "recipe",
		category = "metallurgy",
		energy_required = 10,
		ingredients = {
			{ type = "fluid", name = "ei-molten-carbon-symbiote", amount = 5 }, --fire spirit
			{ type = "item", name = "piercing-shotgun-shell", amount = 1 }, --regular shells
			{ type = "item", name = "tungsten-carbide", amount = 1 }, --shell
			{ type = "item", name = "explosives", amount = 10 }, --spice
			{ type = "fluid", name = "lava", amount = 100 }, --life
		},
		results = {
			{ type = "item", name = "ei-dragons-breath-shotgun-shell", amount = 1 },
			{ type = "item", name = "ei-slag", amount_min = 6, amount_max = 18 },
			{ type = "item", name = "atan-ash", amount_min = 15, amount_max = 30, probability = 0.98 },
		},
		enabled = false,
		always_show_made_in = true,
		main_product = "ei-dragons-breath-shotgun-shell",
	},
	{
		name = "ei-dragons-breath-shotgun-shell",
		type = "technology",
		icon = ei_path .. "graphics/icons/dragons-breath-shotgun-shell.png",
		icon_size = 512,
		icon_mipmaps = 5,
		prerequisites = { "metallurgic-science-pack", "military-4", "ei-carbon-manipulation" },
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-dragons-breath-shotgun-shell",
			},
		},
		unit = {
			count = 100,
			ingredients = ei_data.science["computer-age"],
			time = 20,
		},
		age = "computer-age",
	},
})
