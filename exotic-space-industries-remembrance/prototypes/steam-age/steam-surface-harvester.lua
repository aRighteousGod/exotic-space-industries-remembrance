data:extend({
	{
		name = "ei-steam-surface-harvester",
		type = "technology",
		icon = ei_graphics_3_path .. "graphics/tech/steam-surface-harvester.png",
		icon_size = 512,
		icon_mipmaps = 5,
		age = "steam-age",
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-steam-surface-harvester",
			},
		},
		prerequisites = { "ei-burner-surface-harvester", "ei-steam-power" },
		unit = {
			count = 100,
			ingredients = ei_data.science["steam-age"],
			time = 20,
		},
	},
	{
		name = "ei-steam-surface-harvester",
		type = "item",
		icon = ei_graphics_kirazy_path .. "icon/electric-mining-drill.png",
		icon_size = 64,
		icon_mipmaps = 4,
		place_result = "ei-steam-surface-harvester",
		stack_size = 20,
		subgroup = "extraction-machine",
		order = "a[items]-a[surface-harvester]-b",
	},
	{
		name = "ei-steam-surface-harvester",
		type = "recipe",
		enabled = false,
		ingredients = {
            {type="item", name="ei-burner-surface-harvester", amount=1},
            {type="item", name="ei-steam-engine", amount=2},
            {type="item", name="ei-iron-mechanical-parts", amount=4},
            {type="item", name="ei-iron-beam", amount=4}
		},
		results = {
			{ type = "item", name = modprefix .. "steam-surface-harvester", amount = 1 },
		},
		always_show_made_in = true,
		energy_required = 1,
	},
	{
		name = "ei-steam-surface-harvester",
		type = "assembling-machine",
		icon = ei_graphics_kirazy_path .. "icon/electric-mining-drill.png",
		icon_size = 64,
		icon_mipmaps = 4,
		flags = { "placeable-neutral", "placeable-player", "player-creation" },
		max_health = 150,
		corpse = "medium-remnants",
		dying_explosion = "electric-mining-drill-explosion",
		collision_box = { { -1.35, -1.35 }, { 1.35, 1.35 } },
		selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
		map_color = ei_data.colors.miner,
		minable = {
			mining_time = 1,
			result = "ei-steam-surface-harvester",
		},
		crafting_categories = { "ei-surface-harvester" },
		crafting_speed = 0.75,
		--fixed_recipe = "ei-surface-harvester-mining",
		heating_energy = "50kW",
		energy_source = {
			type = "fluid",
			emissions_per_minute = { pollution = 10 },
			fluid_box = {
				filter = "steam",
				volume = 200,
				pipe_covers = pipecoverspictures(),
				pipe_picture = ei_pipe_miner, --ei_pipe_steam
				pipe_connections = {
					{ flow_direction = "input-output", direction = defines.direction.north, position = { 0, -1 } },
					{ flow_direction = "input-output", direction = defines.direction.south, position = { 0, 1 } },
				},
				production_type = "input-output",
			},
			effectivity = 0.7,
			scale_fluid_usage = true,
		},
		energy_usage = "150kW",
		working_sound = {
			sound = {
                filename = ei_sounds_path .. "classic-electric-mining-drill.ogg",
				volume = 0.75,
			},
			idle_sound = {
				filename = "__base__/sound/idle1.ogg",
				volume = 0.6,
			},
			apparent_volume = 1.5,
		},

		graphics_set = data.raw["assembling-machine"]["ei-burner-surface-harvester"].graphics_set,
		working_visualisations = {
			-- dust animation 1
			{
				constant_speed = true,
				synced_fadeout = true,
				align_to_waypoint = true,
				--apply_tint = "resource-color",
				animation = electric_mining_drill_smoke(),
				north_position = { 0, 0.25 },
				east_position = { 0, 0 },
				south_position = { 0, 0.25 },
				west_position = { 0, 0 },
			},
		},
		damaged_trigger_effect = hit_effects.entity(),
		open_sound = sounds.machine_open,
		close_sound = sounds.machine_close,
		impact_category = "metal",
		circuit_connector = data.raw["assembling-machine"]["ei-burner-surface-harvester"].circuit_connector,
		circuit_wire_max_distance = default_circuit_wire_max_distance,
		surface_conditions = {
			{
				property = "gravity",
				min = 1,
				max = 100,
			},
		},
		module_slots = 2,
		allowed_effects = {"consumption", "speed", "pollution","quality"},
        fast_replaceable_group = "ei-surface-harvester",
        next_upgrade = "ei-electric-surface-harvester",
	},
})
