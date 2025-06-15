-- prototpye definition for steam trains with textures from YuokiTani
-- new basic steam train from cupcakescankill
local ei_lib = require("lib/lib")
--====================================================================================================
--STEAM TRAINS
--====================================================================================================
local thick_smoke = table.deepcopy(data.raw["trivial-smoke"]["train-smoke"])
thick_smoke.name = "ei-train-smoke"
thick_smoke.start_scale = 0.2
thick_smoke.end_scale = 3.5

-- basic steam train

local max_speed_sound_leveloff = 0.8 --pitch stops increasing
local max_speed_sound_levelon = 0.5 --starts
local steam_sound_minimum_speed = 0.5
local steam_sound_maximum_speed = 0.8
local drive_over_tie_speed = 0.4
local drive_over_tie = function()
	return
	{
	  type = "play-sound",
	  sound = sound_variations("__base__/sound/train-tie", 6, 0.4, { volume_multiplier("main-menu", 2.4), volume_multiplier("driving", 1.3) } )
	}
  end

data:extend({
	thick_smoke,
    {
        name = "ei-steam-basic-locomotive",
        type = "item",
        icon = ei_graphics_train_path.."sewt_bl_icon.png",
        icon_size = 32,
        subgroup = "ei-trains",
        order = "a1",
        place_result = "ei-steam-basic-locomotive-placement-entity",
        stack_size = 10
    },
    {
        name = "ei-steam-basic-wagon",
        type = "item",
        icon = ei_graphics_train_path.."4a-tw-s3-icon.png",
        icon_size = 32,
        subgroup = "ei-trains",
        order = "a2",
        place_result = "ei-steam-basic-wagon",
        stack_size = 10
    },
    {
        name = "ei-steam-basic-locomotive",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="iron-plate", amount=20},
            {type="item", name="ei-iron-mechanical-parts", amount=10},
            {type="item", name="ei-copper-mechanical-parts", amount=10},
            {type="item", name="ei-steam-engine", amount=10},
            {type="item", name="boiler", amount=1},
        },
        results = {{type="item", name="ei-steam-basic-locomotive", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-basic-locomotive",
    },
    {
        name = "ei-steam-basic-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="iron-plate", amount=20},
            {type="item", name="ei-iron-mechanical-parts", amount=5},
            {type="item", name="ei-copper-mechanical-parts", amount=5},
        },
        results = {{type="item", name="ei-steam-basic-wagon", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-basic-wagon",
    },
    {
        name = "ei-iron-rail",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients =
        {
            {type="item", name="stone", amount=1},
            {type="item", name="ei-iron-mechanical-parts", amount=2},
            {type="item", name="copper-plate", amount=1}
        },
        results = {{type="item", name="rail", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "rail",
    },
    {
        name = "ei-steam-basic-train",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/technology/steam-locomotion.png",
        icon_size = 512,
        prerequisites = {"ei-steam-power"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-steam-basic-locomotive"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-steam-basic-wagon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-iron-rail"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
		type = "locomotive",
		name = "ei-steam-basic-locomotive",
		icon = ei_graphics_train_path.."sewt_bl_icon.png",
        icon_size = 32,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		minable = 
        {
            mining_time = 1,
            result = "ei-steam-basic-locomotive"
        },
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 800,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",

		collision_box = {{-0.6, -2.6}, {0.6, 2.6}},
		selection_box = {{-1, -3}, {1, 3}},
		drawing_boxes =
		{
		north = {{-3,-2.5}, {0.8, 1.25}},
		east = {{-1.75, -4.25},{1.625, 0.5}},
		south = {{-0.8125, -3.625},{2.75, 0.4375}},
		west = {{-1.75, -1.6875},{2.0625, 2.75}}
		},
		connection_distance = 3,
        joint_distance = 4,

		weight = 4500,
		max_speed = 0.625,
		max_power = "900kW",
		reversing_power_modifier = 0.6,
		braking_force = 8,
		friction_force = 0.4,
		-- this is a percentage of current speed that will be subtracted
		air_resistance = 0.01,
		vertical_selection_shift = -0.5,
		energy_per_hit_point = 5,
		resistances =
		{
			{type = "fire", decrease = 15, percent = 50 },
			{type = "physical", decrease = 15, percent = 30 },
			{type = "impact",decrease = 50,percent = 60},
			{type = "explosion",decrease = 15,percent = 30},
			{type = "acid",decrease = 10,percent = 20}
		},
		energy_source =
		{
			type = "burner",
			fuel_categories = {"chemical"},
			effectivity = 0.70,
			fuel_inventory_size = 3,
			burnt_inventory_size = 2,
			emissions_per_minute = { pollution = 10 },
			smoke =
			{
				{
					name = "ei-train-smoke",
					deviation = {0.6, 0.6},
					frequency = 300,
					position = {0, -3},
					--position = {0, 0},
					starting_frame = 0,
					starting_frame_deviation = 60,
					height = 2.15,
					height_deviation = 1,
					starting_vertical_speed = 0.2,
					starting_vertical_speed_deviation = 0.1,
				}
			}
		},		
		front_light =
		{
			{
				type = "oriented",
				minimum_darkness = 0.3,
				picture =
				{
					filename = ei_graphics_2_path.."graphics/entities/steam_trains/steam_train_light_cone_280x389.png",
					priority = "medium",
					scale = 1,
					width = 280,
					height = 389,
					draw_as_light = true,
                    blend_mode = "multiplicative-with-alpha"
				},
				shift = {0, -14},
				size = 2,
				intensity = 0.66,
				color = { r = 0.9, g = 0.75, b = 0.4 }
			}
			--[[
			{
				type = "oriented",
				minimum_darkness = 0.3,
				picture =
				{
					filename = "__core__/graphics/light-cone.png",
					priority = "medium",
					scale = 2,
					width = 200,
					height = 200
				},
				shift = {0.6, -16},
				size = 2,
				intensity = 0.6
			}
			]]
		},
		front_light_pictures = {
			rotated = {
				draw_as_light = true,
				direction_count = 256,
				line_length = 16,
				lines_per_file = 16,
				width = 512,
				height = 512,
				blend_mode = "normal",
				filename =  ei_graphics_3_path .. "graphics/entity/steam-locomotive/body/lights.png",
				scale = 0.525,
				shift = util.by_pixel(0, -19)
			},
			sloped = {
				draw_as_light = true,
				direction_count = 128,
				line_length = 16,
				lines_per_file = 8,
				width = 512,
				height = 512,
				blend_mode = "normal",
				filename =  ei_graphics_3_path .. "graphics/entity/steam-locomotive/sloped/lights_sloped.png",
				scale = 0.525,
				shift = util.by_pixel(0, -19)
			}
		},
		--back_light = rolling_stock_back_light(),
		--stand_by_light = rolling_stock_stand_by_light(),
		
		pictures = {
			rotated = {
				layers = {
					--base image
					{
						direction_count = 256,
						line_length = 16,
						lines_per_file = 16,
						width = 512,
						height = 512,
						filename = ei_graphics_3_path .. "graphics/entity/steam-locomotive/body/body.png",
						scale = 0.525,
						shift = util.by_pixel(0, -19)
					},
					--color mask
					{
						apply_runtime_tint = true,
						direction_count = 256,
						line_length = 16,
						lines_per_file = 16,
						width = 512,
						height = 512,
						blend_mode = "additive",
						filename = ei_graphics_3_path .. "graphics/entity/steam-locomotive/body/mask.png",
						scale = 0.525,
						shift = util.by_pixel(0, -19)
					},
					--shadow
					{
						draw_as_shadow = true,
						direction_count = 256,
						line_length = 16,
						lines_per_file = 16,
						width = 512,
						height = 512,
						filename = ei_graphics_3_path .. "graphics/entity/steam-locomotive/body/shadow.png",
						scale = 0.525,
						shift = util.by_pixel(-7, -19)
					}
				}
			},
			sloped = {
				layers = {
					--base image
					{
						direction_count = 128,
						line_length = 16,
						lines_per_file = 8,
						width = 512,
						height = 512,
						filename = ei_graphics_3_path .. "graphics/entity/steam-locomotive/sloped/sloped.png",
						scale = 0.525,
						shift = util.by_pixel(0, -19)
					},
					--color mask
					{
						apply_runtime_tint = true,
						direction_count = 128,
						line_length = 16,
						lines_per_file = 8,
						width = 512,
						height = 512,
						blend_mode = "additive",
						filename = ei_graphics_3_path .. "graphics/entity/steam-locomotive/sloped/mask_sloped.png",
						scale = 0.525,
						shift = util.by_pixel(0, -19)
					}
				}
			}
		},
		minimap_representation =
		{
		  filename = "__base__/graphics/entity/locomotive/minimap-representation/locomotive-minimap-representation.png",
		  flags = {"icon"},
		  size = {20, 40},
		  scale = 0.5
		},
		selected_minimap_representation =
		{
		  filename = "__base__/graphics/entity/locomotive/minimap-representation/locomotive-selected-minimap-representation.png",
		  flags = {"icon"},
		  size = {20, 40},
		  scale = 0.5
		},
--[[
		wheels = {
			rotated = {
				priority = "very-low",
				direction_count = 256,
				line_length = 4,
				lines_per_file = 8,
				width = 230,
				height = 195,
				blend_mode = "normal",
				scale = 0.5,
				shift = util.by_pixel(0, 8),
				usage = "train",
				filenames = {
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-1.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-2.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-3.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-4.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-5.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-6.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-7.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/rotated/train-wheel-8.png"
				}
			},
			sloped = {
				priority = "very-low",
				direction_count = 256,
				line_length = 4,
				lines_per_file = 8,
				width = 230,
				height = 195,
				blend_mode = "normal",
				scale = 0.5,
				shift = util.by_pixel(0, 8),
		     	 usage = "train",
				filenames = {
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-1.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-2.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-3.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-4.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-5.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-6.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-7.png",
				ei_graphics_3_path.. "graphics/entity/train-wheel/sloped/train-wheel-sloped-8.png"
				}
			}
		},
		]]
		rail_category = "regular",

		stop_trigger =
		{
			-- left side
			{
				type = "create-trivial-smoke",
				repeat_count = 75,
				smoke_name = "smoke-train-stop",
				initial_height = 0,
				-- smoke goes to the left
				speed = {-0.03, 0},
				speed_multiplier = 0.75,
				speed_multiplier_deviation = 1.33,
				offset_deviation = {{-0.75, -2.7}, {-0.3, 2.7}}
			},
			-- right side
			{
				type = "create-trivial-smoke",
				repeat_count = 75,
				smoke_name = "smoke-train-stop",
				initial_height = 0,
				-- smoke goes to the right
				speed = {0.03, 0},
				speed_multiplier = 0.75,
				speed_multiplier_deviation = 1.33,
				offset_deviation = {{0.3, -2.7}, {0.75, 2.7}}
			},
			{
				type = "play-sound",
				sound =
				{
					aggregation = {
                    max_count = 20,
                    remove = true
                },
                variations = {
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_1.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_2.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_3.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_4.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_5.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_6.ogg",
						volume = 0.6
					},

				}
				}
			},
		},
		drive_over_tie_trigger = drive_over_tie(),
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 50,
		vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
		impact_category = "metal-large",
		working_sound =
		{
		main_sounds =
		{
			{
			sound =
			{
				filename = ei_steam_trains_sounds_path.."steam_train_engine.ogg",
				volume = 0.95,
				modifiers =
				{
				volume_multiplier("main-menu", 1.8),
				volume_multiplier("driving", 0.7),
				volume_multiplier("tips-and-tricks", 0.8),
				volume_multiplier("elevation", 0.5)
				},
			},
			match_volume_to_activity = true,
			min_speed = max_speed_sound_levelon,
			max_speed = max_speed_sound_leveloff,
			activity_to_volume_modifiers =
			{
				multiplier = 2,
				offset = 1.0,
			},
			match_speed_to_activity = true,
			activity_to_speed_modifiers =
			{
				multiplier = 0.6,
				minimum = 1.0,
				maximum = 1.15,
				offset = 0.2,
			}
			},
			{
			sound =
			{
				filename = ei_steam_trains_sounds_path.."steam_train_engine_idle.ogg",
				volume = 0.65,
				modifiers =
				{
				volume_multiplier("main-menu", 1.8),
				volume_multiplier("driving", 0.9),
				volume_multiplier("tips-and-tricks", 0.8)
				},
			},
			match_volume_to_activity = true,
			min_speed = max_speed_sound_levelon,
			max_speed = max_speed_sound_leveloff,
			activity_to_volume_modifiers =
			{
				multiplier = 1.5,
				offset = 1.5,
				minimum = 0.4,
				inverted = true
			},
			},
			{
			sound =
			{
				filename = "__base__/sound/train-wheels.ogg",
				volume = 1.0,
				modifiers =
				{
				volume_multiplier("main-menu", 2.0),
				volume_multiplier("driving", 0.35),
				volume_multiplier("elevation", 0.5)
				},
			},
			match_volume_to_activity = true,
			activity_to_volume_modifiers =
			{
				multiplier = 1.5,
				maximum = 1.0,
				offset = 1.1,
			},
			match_speed_to_activity = true,
			activity_to_speed_modifiers =
			{
				multiplier = 0.6,
				minimum = 1.0,
				maximum = 1.2,
				offset = 0.2,
			},
			},
		},
		max_sounds_per_prototype = 2,
		activate_sound = { filename = ei_steam_trains_sounds_path.."steam_train_engine_start.ogg", volume = 0.65 },
		deactivate_sound = { filename = ei_steam_trains_sounds_path.."steam_train_engine_stop.ogg", volume = 0.65 },
	},
		open_sound = { filename = "__base__/sound/car-door-open.ogg", volume=0.7 },
		close_sound = { filename = "__base__/sound/car-door-close.ogg", volume = 0.7 },
	},
    {
		type = "cargo-wagon",
		name = "ei-steam-basic-wagon",
		icon = ei_graphics_train_path.."4a-tw-s3-icon.png",
        icon_size = 32,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		inventory_size = 20,
		minable = {
            mining_time = 1,
            result = "ei-steam-basic-wagon"
        },
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 600,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",
		
		collision_box = {{-0.6, -2.4}, {0.6, 2.4}},
		selection_box = {{-1.0, -2.7}, {1, 3.3}},		
		connection_distance = 3, joint_distance = 4,
		
		weight = 1000,
		max_speed = 1.2,
		braking_force = 2,
		friction_force = 0.1,
		air_resistance = 0.006,
		energy_per_hit_point = 5,    
		resistances =
		{
			{type = "fire", decrease = 15, percent = 50 },
			{type = "physical", decrease = 15, percent = 30 },
			{type = "impact",decrease = 50,percent = 60},
			{type = "explosion",decrease = 15,percent = 30},
			{type = "acid",decrease = 10,percent = 20}
		},
		vertical_selection_shift = -0.8,
		--back_light = rolling_stock_back_light(),
		--stand_by_light = rolling_stock_stand_by_light(),
		pictures =
		{
			rotated = {
				priority = "very-low",
				width = 256,
				height = 256,
				back_equals_front = true,
				direction_count = 64,
				filename = ei_graphics_train_path.."4acw_gr_sheet.png",      
				line_length = 8,
				lines_per_file = 8,
				shift = {0.42, -1.125}
			}
		},
		minimap_representation = {
			filename = "__base__/graphics/entity/cargo-wagon/minimap-representation/cargo-wagon-minimap-representation.png",
			flags = {"icon"},
			size = {20, 40},
			scale = 0.5
		},
		selected_minimap_representation = {
			filename = "__base__/graphics/entity/cargo-wagon/minimap-representation/cargo-wagon-selected-minimap-representation.png",
			flags = {"icon"},
			size = {20, 40},
			scale = 0.5
		},

		wheels = standard_train_wheels,
		rail_category = "regular",
		drive_over_tie_trigger = drive_over_tie(),
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 50,
		working_sound =
		{
			sound =
			{
				filename = "__base__/sound/train-wheels.ogg",
				volume = 0.5
			},
			match_volume_to_activity = true,
		},
		crash_trigger = crash_trigger(),
		open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 },
		close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 },
		sound_minimum_speed = steam_sound_minimum_speed;
		vehicle_impact_sound =  { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 },
	},


	{
        name = "ei-steam-advanced-locomotive",
        type = "item",
        icon = ei_graphics_train_path.."se_krgreen_icon.png",
        icon_size = 32,
        subgroup = "ei-trains",
        order = "b1",
        place_result = "ei-steam-advanced-locomotive",
        stack_size = 10
    },
    {
        name = "ei-steam-advanced-wagon",
        type = "item",
        icon = ei_graphics_train_path.."4a-cw_vc_icon.png",
        icon_size = 32,
        subgroup = "ei-trains",
        order = "b2",
        place_result = "ei-steam-advanced-wagon",
        stack_size = 10
    },
	{
        name = "ei-steam-advanced-fluid-wagon",
        type = "item",
        icon = ei_graphics_train_path.."4aw_fw_vc_icon.png",
        icon_size = 32,
        subgroup = "ei-trains",
        order = "b3",
        place_result = "ei-steam-advanced-fluid-wagon",
        stack_size = 10
    },
    {
        name = "ei-steam-advanced-locomotive",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-steam-basic-locomotive", amount=1},
            {type="item", name="ei-steel-mechanical-parts", amount=10},
            {type="item", name="steel-plate", amount=30},
        },
        results = {{type="item", name="ei-steam-advanced-locomotive", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-advanced-locomotive",
    },
    {
        name = "ei-steam-advanced-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-steam-basic-wagon", amount=1},
            {type="item", name="ei-steel-mechanical-parts", amount=5},
            {type="item", name="steel-plate", amount=5},
        },
        results = {{type="item", name="ei-steam-advanced-wagon", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-advanced-wagon",
    },
	{
        name = "ei-steam-advanced-fluid-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients =
        {
            {type="item", name="ei-steam-basic-wagon", amount=1},
            {type="item", name="ei-steel-mechanical-parts", amount=5},
            {type="item", name="steel-plate", amount=5},
			{type="item", name="storage-tank", amount=1},
        },
        results = {{type="item", name="ei-steam-advanced-fluid-wagon", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei-steam-advanced-fluid-wagon",
    },
    {
        name = "ei-steam-advanced-train",
        type = "technology",
        icon = ei_graphics_tech_path.."steam-advanced-train.png",
        icon_size = 500,
        prerequisites = {"ei-steam-basic-train", "ei-tank", "engine", "automated-rail-transportation"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-steam-advanced-locomotive"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-steam-advanced-wagon"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-steam-advanced-fluid-wagon"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
	{
		type = "cargo-wagon",
		name = "ei-steam-advanced-wagon",
		icon = ei_graphics_train_path.."4a-cw_vc_icon.png",
		icon_size = 32,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		inventory_size = 30,
		minable = {
			mining_time = 1,
			result = "ei-steam-advanced-wagon"
		},
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 900, corpse = "medium-remnants", dying_explosion = "medium-explosion",
		collision_box = {{-0.6, -2.4}, {0.6, 2.4}},
		selection_box = {{-1.0, -2.7}, {1, 3.3}},		
		connection_distance = 3, joint_distance = 4,
		weight = 1000,
		max_speed = 2.0, braking_force = 4, friction_force = 0.05, air_resistance = 0.035,
		energy_per_hit_point = 5,    
		resistances = { {type = "impact",decrease = 50,percent = 60},},
		vertical_selection_shift = -0.8,
		--back_light = rolling_stock_back_light(),
		--stand_by_light = rolling_stock_stand_by_light(),
		pictures =
		{
			rotated = {
				priority = "very-low",			
				width = 512,
				height = 512,
				scale = 0.5,
				back_equals_front = true,
				direction_count = 64,
				filenames = {
					ei_graphics_train_path.."4aw_cw_vc_sheet-0.png",      
					ei_graphics_train_path.."4aw_cw_vc_sheet-1.png",      
					ei_graphics_train_path.."4aw_cw_vc_sheet-2.png",      
					ei_graphics_train_path.."4aw_cw_vc_sheet-3.png",      				
				},
				line_length = 4,
				lines_per_file = 4,
				shift = {0.42, -0.875}
			}
		},
		minimap_representation = {
			filename = "__base__/graphics/entity/cargo-wagon/minimap-representation/cargo-wagon-minimap-representation.png",
			flags = {"icon"},
			size = {20, 40},
			scale = 0.5
		},
		selected_minimap_representation = {
			filename = "__base__/graphics/entity/cargo-wagon/minimap-representation/cargo-wagon-selected-minimap-representation.png",
			flags = {"icon"},
			size = {20, 40},
			scale = 0.5
		},

		wheels = standard_train_wheels,
		rail_category = "regular",
		drive_over_tie_trigger = drive_over_tie(),
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 50,
		working_sound =	{ sound = { filename = "__base__/sound/train-wheels.ogg", volume = 0.5 }, match_volume_to_activity = true, },
		crash_trigger = crash_trigger(),
		open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 },
		close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 },
		sound_minimum_speed = steam_sound_minimum_speed;
		vehicle_impact_sound =  { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 },
	},
	{
		type = "fluid-wagon",
		name = "ei-steam-advanced-fluid-wagon",
		icon = ei_graphics_train_path.."4aw_fw_vc_icon.png",icon_size = 32,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		
		minable = {
			mining_time = 1,
			result = "ei-steam-advanced-fluid-wagon"
		},
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 1000,
		capacity = 10000,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",
		collision_box = {{-0.6, -2.4}, {0.6, 2.4}},
		selection_box = {{-1, -2.7}, {1, 3.297}},

		gui_front_tank =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/front-tank.png",
			width = 64,
			height = 64,
			flags = {"icon"}
		},
		gui_center_tank =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/center-tank.png",
			width = 64,
			height = 64,
			flags = {"icon"}
		},
		gui_back_tank =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/back-tank.png",
			width = 64,
			height = 64,
			flags = {"icon"}
		},
		gui_connect_front_center_tank =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/connector-front-center.png",
			width = 64,
			height = 64,
			flags = {"icon"}
		},
		gui_connect_center_back_tank =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/connector-center-back.png",
			width = 64,
			height = 64,
			flags = {"icon"}
		},
		gui_front_center_tank_indiciation =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/1.png",
			width = 32,
			height = 32,
			flags = {"icon"}
		},
		gui_center_back_tank_indiciation =
		{
			filename = "__base__/graphics/entity/fluid-wagon/gui/2.png",
			width = 32,
			height = 32,
			flags = {"icon"}
		},

		vertical_selection_shift = -0.8,

		weight = 1000,
		max_speed = 2.0, braking_force = 4, friction_force = 0.05, air_resistance = 0.035,
		connection_distance = 3,
		joint_distance = 4,
		energy_per_hit_point = 8,    
		resistances =
		{
			{type = "fire", decrease = 15, percent = 50 },
			{type = "physical", decrease = 15, percent = 30 },
			{type = "impact",decrease = 50,percent = 60},
			{type = "explosion",decrease = 15,percent = 30},
			{type = "acid",decrease = 10,percent = 20}
		},
		
		--back_light = rolling_stock_back_light(),
		--stand_by_light = rolling_stock_stand_by_light(),
		pictures =
		{
			rotated = {
				priority = "very-low",
				width = 512, height = 512, scale = 0.5,
				back_equals_front = true,
				direction_count = 64,
				filenames = {
					ei_graphics_train_path.."4aw_fw_vc_sheet-0.png",      
					ei_graphics_train_path.."4aw_fw_vc_sheet-1.png",      
					ei_graphics_train_path.."4aw_fw_vc_sheet-2.png",      
					ei_graphics_train_path.."4aw_fw_vc_sheet-3.png",      				
				},
				line_length = 4,
				lines_per_file = 4,
				shift = {0.42, -0.875}
			}
		},
		minimap_representation =
		{
		  filename = "__base__/graphics/entity/fluid-wagon/minimap-representation/fluid-wagon-minimap-representation.png",
		  flags = {"icon"},
		  size = {20, 40},
		  scale = 0.5
		},
		selected_minimap_representation =
		{
		  filename = "__base__/graphics/entity/fluid-wagon/minimap-representation/fluid-wagon-selected-minimap-representation.png",
		  flags = {"icon"},
		  size = {20, 40},
		  scale = 0.5
		},
		wheels = standard_train_wheels,
		rail_category = "regular",
		drive_over_tie_trigger = drive_over_tie(),
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 50,
		working_sound =
		{
			sound =
			{
				filename = "__base__/sound/train-wheels.ogg",
				volume = 0.5
			},
			match_volume_to_activity = true,
		},
		crash_trigger = crash_trigger(),
		sound_minimum_speed = steam_sound_minimum_speed;
		vehicle_impact_sound =  { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 },
	},
	{
		type = "locomotive",
		name = "ei-steam-advanced-locomotive",
		icon = ei_graphics_train_path.."se_krgreen_icon.png",
		icon_size = 32,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid"},
		minable = {
			mining_time = 1,
			result = "ei-steam-advanced-locomotive"
		},
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 700,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",
		collision_box = {{-0.6, -2.6}, {0.6, 2.6}},
		selection_box = {{-1, -3}, {1, 3}},
		drawing_box = {{-1, -4}, {1, 3}},
		connection_distance = 3,
		joint_distance = 4,
		weight = 4000,
		max_speed = 0.8,
		max_power = "1400kW",
		reversing_power_modifier = 0.6,
		braking_force = 18,
		friction_force = 0.2,
		-- this is a percentage of current speed that will be subtracted
		air_resistance = 0.01,
		vertical_selection_shift = -0.5,
		energy_per_hit_point = 5,
		resistances = {
			{type = "physical", decrease = 15, percent = 30},
			{type = "impact", decrease = 50, percent = 60}
		},
		energy_source = {
			type = "burner",
			fuel_categories = {"chemical"},
			effectivity = 0.85,
			fuel_inventory_size = 2,
			burnt_inventory_size = 1,
			emissions_per_minute = { pollution = 5 },
			smoke = {
				{
					name = "ei-train-smoke",
					deviation = {0.3, 0.3},
					frequency = 215,
					position = {0, -3},
					starting_frame = 0,
					starting_frame_deviation = 60,
					height = 2,
					height_deviation = 0.5,
					starting_vertical_speed = 0.2,
					starting_vertical_speed_deviation = 0.1
				}
			}
		},
		front_light = {
			{
				type = "oriented",
				minimum_darkness = 0.3,
				picture = {
					filename = ei_graphics_2_path.."graphics/entities/steam_trains/steam_train_light_cone_280x389.png",
					priority = "medium",
					scale = 1,
					width = 280,
					height = 389,
					draw_as_light = true,
                    blend_mode = "multiplicative-with-alpha"
				},
				shift = {-1.8, -14},
				size = 2,
				intensity = 0.6,
				color = { r = 1.0, g = 0.85, b = 0.5 }
			},
			{
				type = "oriented",
				minimum_darkness = 0.3,
				picture = {
					filename = ei_graphics_2_path.."graphics/entities/steam_trains/steam_train_light_cone_280x389.png",
					priority = "medium",
					scale = 1,
					width = 280,
					height = 389,
					draw_as_light = true,
                    blend_mode = "multiplicative-with-alpha"
				},
				shift = {1.8, -14},
				size = 2,
				intensity = 0.6,
				color = { r = 1.0, g = 0.85, b = 0.5 }
			}
		},
		--back_light = rolling_stock_back_light(),
		--stand_by_light = rolling_stock_stand_by_light(),
		pictures = {
			rotated = {
				priority = "very-low",
				width = 512,
				height = 512,
				scale = 0.5,
				direction_count = 128,
				filenames = {
					ei_graphics_train_path.."se_krgreen_sheet-0.png",
					ei_graphics_train_path.."se_krgreen_sheet-1.png",
					ei_graphics_train_path.."se_krgreen_sheet-2.png",
					ei_graphics_train_path.."se_krgreen_sheet-3.png",
					ei_graphics_train_path.."se_krgreen_sheet-4.png",
					ei_graphics_train_path.."se_krgreen_sheet-5.png",
					ei_graphics_train_path.."se_krgreen_sheet-6.png",
					ei_graphics_train_path.."se_krgreen_sheet-7.png"
				},
				line_length = 4,
				lines_per_file = 4,
				shift = {0, -1.125}
			}
		},
		minimap_representation = {
			filename = "__base__/graphics/entity/locomotive/minimap-representation/locomotive-minimap-representation.png",
			flags = {"icon"},
			size = {20, 40},
			scale = 0.5
		},
		selected_minimap_representation = {
			filename = "__base__/graphics/entity/locomotive/minimap-representation/locomotive-selected-minimap-representation.png",
			flags = {"icon"},
			size = {20, 40},
			scale = 0.5
		},
		wheels = standard_train_wheels,
		rail_category = "regular",
		stop_trigger = {
			-- left side
			{
				type = "create-trivial-smoke",
				repeat_count = 75,
				smoke_name = "smoke-train-stop",
				initial_height = 0,
				-- smoke goes to the left
				speed = {-0.03, 0},
				speed_multiplier = 0.75,
				speed_multiplier_deviation = 1.33,
				offset_deviation = {{-0.75, -2.7}, {-0.3, 2.7}}
			},
			-- right side
			{
				type = "create-trivial-smoke",
				repeat_count = 75,
				smoke_name = "smoke-train-stop",
				initial_height = 0,
				-- smoke goes to the right
				speed = {0.03, 0},
				speed_multiplier = 0.75,
				speed_multiplier_deviation = 1.33,
				offset_deviation = {{0.3, -2.7}, {0.75, 2.7}}
			},
			{
				type = "play-sound",
				sound = {
					aggregation = {
                    max_count = 20,
                    remove = true
                },
                variations = {
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_1.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_2.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_3.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_4.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_5.ogg",
						volume = 0.6
					},
					{
						filename = ei_steam_trains_sounds_path.."steam_train_whistle_6.ogg",
						volume = 0.6
					},

				}
				}
			}
		},
		drive_over_tie_trigger = drive_over_tie(),
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 50,
		vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
		impact_category = "metal-large",
		working_sound =
		{
		main_sounds =
		{
			{
			sound =
			{
				filename = ei_steam_trains_sounds_path.."steam_train_engine.ogg",
				volume = 0.7,
				modifiers =
				{
				volume_multiplier("main-menu", 1.8),
				volume_multiplier("driving", 0.7),
				volume_multiplier("tips-and-tricks", 0.8),
				volume_multiplier("elevation", 0.5)
				},
			},
			match_volume_to_activity = true,
			min_speed = max_speed_sound_levelon,
			max_speed = max_speed_sound_leveloff,
			activity_to_volume_modifiers =
			{
				multiplier = 1.5,
				offset = 1.0,
			},
			match_speed_to_activity = true,
			activity_to_speed_modifiers =
			{
				multiplier = 0.6,
				minimum = 1.0,
				maximum = 1.15,
				offset = 0.2,
			}
			},
			{
			sound =
			{
				filename = ei_steam_trains_sounds_path.."steam_train_engine_idle.ogg",
				volume = 0.5,
				modifiers =
				{
				volume_multiplier("main-menu", 1.8),
				volume_multiplier("driving", 0.9),
				volume_multiplier("tips-and-tricks", 0.8)
				},
			},
			match_volume_to_activity = true,
			min_speed = max_speed_sound_levelon,
			max_speed = max_speed_sound_leveloff,
			activity_to_volume_modifiers =
			{
				multiplier = 1.4,
				offset = 1.4,
				minimum = 0.3,
				inverted = true
			},
			},
			{
			sound =
			{
				filename = "__base__/sound/train-wheels.ogg",
				volume = 1.0,
				modifiers =
				{
				volume_multiplier("main-menu", 2.0),
				volume_multiplier("driving", 0.35),
				volume_multiplier("elevation", 0.5)
				},
			},
			match_volume_to_activity = true,
			activity_to_volume_modifiers =
			{
				multiplier = 1.5,
				maximum = 1.0,
				offset = 1.1,
			},
			match_speed_to_activity = true,
			activity_to_speed_modifiers =
			{
				multiplier = 0.6,
				minimum = 1.0,
				maximum = 1.2,
				offset = 0.2,
			},
			},
		},
		max_sounds_per_prototype = 2,
		activate_sound = { filename = ei_steam_trains_sounds_path.."steam_train_engine_start.ogg", volume = 0.65 },
		deactivate_sound = { filename = ei_steam_trains_sounds_path.."steam_train_engine_stop.ogg", volume = 0.65 },
		},
			open_sound = {filename = "__base__/sound/car-door-open.ogg", volume = 0.7},
			close_sound = {filename = "__base__/sound/car-door-close.ogg", volume = 0.7}
		},
	{
	name = "ei-steam-wheels",
	type = "car",
	effectivity = 0,
	consumption = "0kW",
	rotation_speed = 100,
	weight = 1e-5,
	braking_force = 1e-5,
	friction_force = 1e-5,
	energy_per_hit_point = 0,
	allow_passengers = false,
	flags = {"placeable-off-grid", "not-on-map"},
	render_layer = "lower-object-above-shadow",
	energy_source = {
		type = "void",
		emissions_per_minute = {},
		render_no_power_icon = false,
		render_no_network_icon = false
	},
	inventory_size = 0,
	collision_box = {{0,0},{0,0}},
	collision_mask = {layers = {}},
	max_health = 2147483648,
	healing_per_tick = 2147483648,
	animation = {
		name = "ei-wheel-animation",
		type = "animation",
		direction_count = 256,
		frame_count = 12,
		height = 512,
		width = 512,
		scale = 0.525,
		shift = util.by_pixel(0, -19),
		lines_per_file=16,
		slice=16,
		animation_speed = 1.25,
		filenames = {
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_0.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_1.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_2.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_3.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_4.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_5.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_6.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_7.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_8.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_9.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_10.png",
			ei_graphics_3_path.."graphics/entity/steam-wheels/wheel_11.png"
		}
	}
},
})

--meow
local elevated_wheels = table.deepcopy(ei_lib.raw.car["ei-steam-wheels"])
elevated_wheels.name = "ei-steam-wheels-elevated"
elevated_wheels.render_layer = "elevated-lower-object"

local placement_entity = table.deepcopy(ei_lib.raw.locomotive["ei-steam-basic-locomotive"])
placement_entity.name = "ei-steam-basic-locomotive-placement-entity"
placement_entity.pictures.rotated = {
	direction_count = 256,
	line_length = 16,
	lines_per_file = 16,
	width = 512,
	height = 512,
	filename = ei_graphics_3_path .. "graphics/entity/steam-locomotive/body/placement_entity.png",
	scale = 0.525,
	shift = util.by_pixel(0, -19)
}

data:extend({elevated_wheels, placement_entity})
