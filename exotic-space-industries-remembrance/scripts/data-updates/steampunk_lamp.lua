--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["SteampunkLamp"] then
	return
end
--====================================================================================================

local ei_lib = require("lib/lib")
--lamp steampunk-lamp
--item steampunk-lamp
--recipe steampunk-lamp
--corpse steampunk-lamp-remnants

local path = "__SteampunkLamp__"

data:extend({
	{
		type = "item",
		name = "ei-steampunk-lamp",
		icon = data.raw.item["steampunk-lamp"].icon,
		icon_size = data.raw.item["steampunk-lamp"].icon_size,
		subgroup = "circuit-network",
		order = "a[light]-a[small-lamp]",
		place_result = "ei-steampunk-lamp",
		stack_size = 50,
	},
	{
		type = "recipe",
		name = "ei-steampunk-lamp",
		enabled = false,
		ingredients = {
			{ type = "item", name = "engine-unit", amount = 1 },
            { type = "item", name = "ei-iron-beam", amount = 1 },
            { type = "item", name = "ei-glass", amount = 1 },
		},
		results = { { type = "item", name = "ei-steampunk-lamp", amount = 1 } },
	},
	{
		type = "recipe-category",
		name = "ei-steampunk-lamp",
	},
	{
		name = "ei-steampunk-lamp",
		type = "assembling-machine",
		icon = data.raw.lamp["steampunk-lamp"].icon,
		icon_size = data.raw.lamp["steampunk-lamp"].icon_size,
		--circuit_connector = data.raw.lamp["steampunk-lamp"].circuit_connector,
		--circuit_wire_max_distance = data.raw.lamp["steampunk-lamp"].circuit_wire_max_distance,
		flags = { "placeable-neutral", "placeable-player", "player-creation" },
		minable = {
			mining_time = 1,
			result = "ei-steampunk-lamp",
		},
		max_health = 100,
		corpse = data.raw.lamp["steampunk-lamp"].corpse,
		dying_explosion = data.raw.lamp["steampunk-lamp"].dying_explosion,
        collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
        selection_box = {{-0.25, -0.25}, {0.25, 0.25}},
		damaged_trigger_effect = data.raw.lamp["steampunk-lamp"].damaged_trigger_effect,
		map_color = data.raw.lamp["steampunk-lamp"].map_color,
		fixed_recipe = "ei-steampunk-lamp-running",
		crafting_categories = { "ei-steampunk-lamp" },
		crafting_speed = 1,
		--heating_energy = "25kW",
		energy_source = {
			type = "void",
			usage_priority = "lamp",
			emissions_per_minute = { pollution = 2 },
			smoke = {
				{
					name = "smoke",
					deviation = { 0.4, 0.4 },
					frequency = 10,
					position = { 0, 3 },
					starting_frame = 0,
					starting_frame_deviation = 60,
					height = 0.5,
					height_deviation = 1,
					starting_vertical_speed = 0.01,
					starting_vertical_speed_deviation = 0.35,
				},
			},
		},
		fluid_boxes = {
			{
				production_type = "input",
				--pipe_picture = assembler2pipepictures(),
				pipe_covers = pipecoverspictures(),
				volume = 10,
				pipe_connections = {
					{ flow_direction = "input", direction = defines.direction.north, position = { 0, 0 } },
				},
				--secondary_draw_orders = { north = -1 },
			},
		},

		energy_usage = "60kW",
		graphics_set = {
			animation = {
				layers = {
					{
						filename = path .. "/graphics/steampunklamp/steampunklamp.png",
						priority = "medium",
						width = 240,
						height = 416,
						shift = util.by_pixel(0, -44),
						scale = 0.25,
					},
					{
						filename = path .. "/graphics/steampunklamp/steampunklampshadow.png",
						priority = "high",
						width = 576,
						height = 96,
						shift = util.by_pixel(64, 0),
						draw_as_shadow = true,
						scale = 0.25,
					},
				},
			},
			working_visualisations = {
				{
					animation = {
						layers = {
							{
								filename = path .. "/graphics/steampunklamp/steampunklampon.png",
								priority = "high",
                                tint = { r = 1.0, g = 0.78, b = 0.45 },
								width = 240,
								height = 416,
								shift = util.by_pixel(0, -44),
								scale = 0.25,
							},
							{
								filename = path .. "/graphics/steampunklamp/steampunklampglow.png",
								priority = "high",
								blend_mode = "additive",
								width = 240,
								height = 416,
								shift = util.by_pixel(0, -44),
								draw_as_glow = true,
								scale = 0.25,
							},
						},
					},
				},
				{
					light = {
						type = "basic",
						sprite = "emt_train_glow",
						draw_as_glow = true,
						blend_mode = "multiplicative-with-alpha",
						apply_runtime_tint = true,
						intensity = 0.55,
						flicker_interval = 120,
						flicker_min_modifier = 0.55,
						flicker_max_modifier = 0.85,
						color = { r = 1.0, g = 0.78, b = 0.45 },
						size = 120,
					},
				},
			},
		},
	},
	{
		name = "ei-steampunk-lamp-running",
		type = "recipe",
		category = "ei-steampunk-lamp",
		energy_required = 60,
		ingredients = {
			{ type = "fluid", name = "ei-kerosene", amount = 2 },
		},
		results = {},
		enabled = false,
		hidden = true,
		icon = data.raw.lamp["steampunk-lamp"].icon,
		icon_size = data.raw.lamp["steampunk-lamp"].icon_size,
	},
	{
		name = "ei-steampunk-lamp",
		type = "technology",
		icon = data.raw.lamp["steampunk-lamp"].icon,
		icon_size = data.raw.lamp["steampunk-lamp"].icon_size,
		prerequisites = { "ei-destill-tower", "ei-glass", "engine" },
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-steampunk-lamp",
			},
		},
		unit = {
			count = 100,
			ingredients = ei_data.science["steam-age"],
			time = 20,
		},
		age = "steam-age",
	},
})

ei_lib.remove_unlock_recipe("lamp", "steampunk-lamp")
data.raw.lamp["steampunk-lamp"] = nil
data.raw.recipe["steampunk-lamp"] = nil
data.raw.recipe["steampunk-lamp-recycling"] = nil
data.raw.item["steampunk-lamp"] = nil