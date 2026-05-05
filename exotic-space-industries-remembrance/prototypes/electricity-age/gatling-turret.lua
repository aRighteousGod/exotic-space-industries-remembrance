function gatling_place(inputs)
	return {
		layers = {
			{
				filename = ei_graphics_3_path .. "graphics/entities/gatling-turret/gatling-place.png",
				priority = "medium",
				scale = 1.5,
				width = 128,
				height = 128,
				frame_count = inputs.frame_count and inputs.frame_count or 8,
				line_length = inputs.line_length and inputs.line_length or 0,
				run_mode = inputs.run_mode and inputs.run_mode or "forward",
				direction_count = 4,
				axially_symmetrical = false,
				shift = { 0.5 * 1.5, -0.75 * 1.5 }, --{ 0.4375, -0.375},
			},
		},
	}
end

function gatling_sheet(inputs)
	return {
		layers = {
			{
				filename = ei_graphics_3_path .. "graphics/entities/gatling-turret/gatling-sheet.png",
				priority = "medium",
				scale = 0.75,
				width = 256,
				height = 256,
				frame_count = 1,
				direction_count = 64,
				line_length = 8,
				axially_symmetrical = false,
				shift = { 0.5 * 1.5, -0.75 * 1.5 },
			},
		},
	}
end

function gatling_projectile_creation_parameters()
	local points = {
		{15, -106.5},
		{27.75, -106.125},
		{40.5, -105.75},
		{53.25, -91.5},
		{66, -77.25},
		{74.625, -64.875},
		{83.25, -52.5},
		{81.375, -48.75},
		{79.5, -45},
		{72.75, -31.875},
		{66, -18.75},
		{58.5, -5.625},
		{51, 7.5},
		{31.5, 11.25},
		{12, 15},
		{-9, 13.875},
		{-30, 12.75},
		{-34.875, 4.125},
		{-39.75, -4.5},
		{-39.75, -16.875},
		{-39.75, -29.25},
		{-39.75, -40.5},
		{-39.75, -51.75},
		{-39.375, -58.875},
		{-39, -66},
		{-30.375, -68.25},
		{-21.75, -70.5},
		{-13.5, -81.375},
		{-5.25, -92.25},
		{1.5, -96.375},
		{8.25, -100.5},
		{11.625, -103.5},
	}

	local samples_per_segment = 4
	local result = {}
	for index, point in ipairs(points) do
		local next_point = points[index % #points + 1]

		for segment_index = 0, samples_per_segment - 1 do
			local ratio = segment_index / samples_per_segment
			local direction_index = (index - 1) * samples_per_segment + segment_index

			result[#result + 1] = {
				0.0078125 * direction_index,
				util.by_pixel(
					point[1] + (next_point[1] - point[1]) * ratio,
					point[2] + (next_point[2] - point[2]) * ratio
				),
			}
		end
	end

	return result
end

data:extend({
	{
		name = "ei-gatling-turret",
		type = "item",
		icon = ei_graphics_3_path .. "graphics/icons/gatling-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		subgroup = "defensive-structure",
		order = "c-ab",
		place_result = "ei-gatling-turret",
		stack_size = 10,
	},
	{
		type = "ammo-turret",
		name = "ei-gatling-turret",
		icon = ei_graphics_3_path .. "graphics/icons/gatling-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		flags = { "placeable-player", "player-creation" },
		minable = { mining_time = 0.75, result = "ei-gatling-turret" },
		max_health = 1500,
		heating_energy = "100kW",
		hide_resistances = false,
        circuit_connector =  circuit_connector_definitions.create_vector(
        universal_connector_template,
        {
            { variation = 28, main_offset = util.by_pixel( 47.5,  32.25), shadow_offset = util.by_pixel( 47.5,  32.25), show_shadow = true },
        }
        ),
        circuit_wire_max_distance = default_circuit_wire_max_distance,
		energy_source = {
			type = "electric",
			buffer_capacity = "666kJ",
			--input_flow_limit = "500kW",
			drain = "15kW",
			usage_priority = "primary-input",
		},
		energy_per_shot = "1kJ",
		resistances = {
			{ type = "physical", percent = 50 },
			{ type = "fire", percent = 75 },
			{ type = "impact", percent = 75 },
		},
		corpse = "big-remnants",
		damaged_trigger_effect = hit_effects.entity(),
		collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
		selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
		--collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
		--selection_box = { { -1, -1 }, { 1, 1 } },
		rotation_speed = 0.01,
		shoot_in_prepare_state = false,
		preparing_speed = 0.125 * 0.5,
		folding_speed = 0.125 * 0.5,
		dying_explosion = "big-explosion",
		inventory_size = 1,
		prepare_range = 35,
		automated_ammo_count = 10,
		can_retarget_while_starting_attack = true,
		attacking_speed = 20,
        preparing_sound = {
				{
                filename = ei_sounds_path .. "gatling-turret-preparing.ogg",
					volume = 0.6,
					audible_distance_modifier = 0.66,
				},
			},
        folding_sound = {
				{
                filename = ei_sounds_path .. "gatling-turret-folding.ogg",
					volume = 0.6,
					audible_distance_modifier = 0.66,
				},
			},
        alert_when_attacking = true,
        open_sound = sounds.machine_open,
        close_sound = sounds.machine_close,
		graphics_set = {},

		folded_animation = gatling_place({ frame_count = 1, line_length = 1 }),
		preparing_animation = gatling_place({}),
		prepared_animation = gatling_sheet({}),
		attacking_animation = gatling_sheet({}),
		folding_animation = gatling_place({ run_mode = "backward" }),

		vehicle_impact_sound = { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.8 },

		attack_parameters = {
			type = "projectile",
			ammo_categories = { "bullet" },
			cooldown = 0.25,
			rotate_penalty = 14.0,
			projectile_center = { -0.56, -0.72 },
			projectile_creation_distance = 2,
			projectile_creation_parameters = gatling_projectile_creation_parameters(),
			shell_particle = {
				name = "shell-particle",
				direction_deviation = 40,
				speed = 0.3,
				speed_deviation = 0.05,
				center = { -0.07, 1 },
				creation_distance = -2,
				starting_frame_speed = 0.2,
				starting_frame_speed_deviation = 0.1,
			},
			range = 32,
			min_range = 4,
			sound = {
				{
                filename = ei_sounds_path .. "gatling-turret-firing.ogg",
					volume = 0.7,
				},
			},
		},

		call_for_help_radius = 35,
	},

	{
		name = "ei-gatling-turret",
		type = "recipe",
		category = "crafting",
		energy_required = 8,
		ingredients = {
			{ type = "item", name = "gun-turret", amount = 1 },
			{ type = "item", name = "ei-minigun", amount = 1 },
			{ type = "item", name = "ei-steel-mechanical-parts", amount = 30 },
			{ type = "item", name = "electric-engine-unit", amount = 8 },
			{ type = "item", name = "advanced-circuit", amount = 15 },
		},
		results = { { type = "item", name = "ei-gatling-turret", amount = 1 } },
		enabled = false,
		always_show_made_in = true,
		main_product = "ei-gatling-turret",
	},
	{
		name = "ei-gatling-turret",
		type = "technology",
		icon = ei_graphics_3_path .. "graphics/icons/gatling-turret.png",
		icon_size = 512,
		icon_mipmaps = 5,
		prerequisites = {
			"gun-turret",
			"ei-electricity-power",
			"ei-minigun",
			"advanced-circuit",
			"electric-engine",
		},
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-gatling-turret",
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
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-2"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.1 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-3"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-4"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-5"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-6"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
table.insert(
	data.raw.technology["physical-projectile-damage-7"].effects,
	{ type = "turret-attack", turret_id = "ei-gatling-turret", modifier = 0.2 }
)
