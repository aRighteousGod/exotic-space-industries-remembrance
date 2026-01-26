-- this file contains the prototype definition for the stone quarry
-- made from kirazy's mining drill
-- Copyright (c) 2024 Kirazy

local ei_data = require("lib/data")

--from base mining-drill.lua
function electric_mining_drill_smoke()
	return {
		priority = "high",
		filename = "__base__/graphics/entity/electric-mining-drill/electric-mining-drill-smoke.png",
		line_length = 6,
		width = 48,
		height = 72,
		frame_count = 30,
		animation_speed = 0.4,
		shift = util.by_pixel(0, 3),
		scale = 0.5,
	}
end
--====================================================================================================
--DRY ANIMATION
--====================================================================================================

---@type data.Animation4Way
local drill_animations = {
	north = {
		layers = {
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-N.png",
				line_length = 8,
				width = 196,
				height = 226,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(0, -8),
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-N-drill-shadow.png",
				flags = { "shadow" },
				line_length = 8,
				width = 201,
				height = 223,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(1.25, -7.25),
				draw_as_shadow = true,
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
		},
	},
	east = {
		layers = {
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-E.png",
				line_length = 8,
				width = 211,
				height = 197,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(3.75, -1.25),
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-E-drill-shadow.png",
				flags = { "shadow" },
				line_length = 8,
				width = 221,
				height = 195,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(6.25, -0.25),
				draw_as_shadow = true,
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
		},
	},
	south = {
		layers = {
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-S.png",
				line_length = 8,
				width = 196,
				height = 219,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(0, -1.25),
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-S-drill-shadow.png",
				flags = { "shadow" },
				line_length = 8,
				width = 200,
				height = 206,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(1, 2.5),
				draw_as_shadow = true,
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
		},
	},
	west = {
		layers = {
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-W.png",
				line_length = 8,
				width = 211,
				height = 197,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(-3.75, -0.75),
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
			{
				priority = "high",
				filename = ei_graphics_kirazy_path .. "entity/hr-electric-mining-drill-W-drill-shadow.png",
				flags = { "shadow" },
				line_length = 8,
				width = 229,
				height = 195,
				frame_count = 64,
				animation_speed = 0.5,
				direction_count = 1,
				shift = util.by_pixel(1.25, -0.25),
				draw_as_shadow = true,
				run_mode = "forward-then-backward",
				scale = 0.5,
			},
		},
	},
}
--[[
----------------------------------------------------------------------------------------------------
-- Wet Mining Animations
----------------------------------------------------------------------------------------------------

-- Wet mining frame
---@type data.Animation4Way
local input_fluid_patch_sprites = {
    north = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-N-patch.png",
        width = 200,
        height = 222,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(-0.5, -6.5),
        scale = 0.5
    },
    east = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-E-patch.png",
        width = 200,
        height = 219,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(0, -5.75),
        scale = 0.5
    },
    south = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-S-patch.png",
        width = 200,
        height = 226,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(-0.5, -7.5),
        scale = 0.5
    },
    west = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-W-patch.png",
        width = 200,
        height = 220,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(-0.5, -6),
        scale = 0.5
    }
}

-- Wet mining frame shadow
---@type data.Animation4Way
local input_fluid_patch_shadow_sprites = {
    north = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-N-patch-shadow.png",
        flags = { "shadow" },
        width = 220,
        height = 197,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(5, -0.25),
        draw_as_shadow = true,
        scale = 0.5
    },
    east = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-E-patch-shadow.png",
        flags = { "shadow" },
        width = 224,
        height = 198,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(6, 0),
        draw_as_shadow = true,
        scale = 0.5
    },
    south = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-S-patch-shadow.png",
        flags = { "shadow" },
        width = 220,
        height = 197,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(5, -0.25),
        draw_as_shadow = true,
        scale = 0.5
    },
    west = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-W-patch-shadow.png",
        flags = { "shadow" },
        width = 220,
        height = 197,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(5, -0.25),
        draw_as_shadow = true,
        scale = 0.5
    }
}

-- Wet mining frame animated shadows cast on drill
---@type data.Animation4Way
local input_fluid_patch_shadow_animations = {
    north = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-N-drill-received-shadow.png",
        tint = { r=0.5, g=0.5, b=0.5, a=0.5 },
        line_length = 8,
        width = 204,
        height = 206,
        frame_count = 64,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-0.5, -2),
        run_mode = "forward-then-backward",
        scale = 0.5
    },
    east = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-E-drill-received-shadow.png",
        tint = { r=0.5, g=0.5, b=0.5, a=0.5 },
        line_length = 8,
        width = 204,
        height = 209,
        frame_count = 64,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-0.5, -1.25),
        run_mode = "forward-then-backward",
        scale = 0.5
    },
    south = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-S-drill-received-shadow.png",
        tint = { r=0.5, g=0.5, b=0.5, a=0.5 },
        line_length = 8,
        width = 204,
        height = 204,
        frame_count = 64,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-0.5, -2.5),
        run_mode = "forward-then-backward",
        scale = 0.5
    },
    west = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-W-drill-received-shadow.png",
        tint = { r=0.5, g=0.5, b=0.5, a=0.5 },
        line_length = 8,
        width = 198,
        height = 206,
        frame_count = 64,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(1, -2),
        run_mode = "forward-then-backward",
        scale = 0.5
    }
}

-- Wet mining frame windows
---@type data.Animation4Way
local input_fluid_patch_window_sprites = {
    north = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-N-window-background.png",
        width = 142,
        height = 107,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(-1, 0.75),
        scale = 0.5
    },
    east = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-E-window-background.png",
        width = 104,
        height = 147,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(-11, -11.25),
        scale = 0.5
    },
    south = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-S-window-background.png",
        width = 141,
        height = 86,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(-1.75, -29),
        scale = 0.5
    },
    west = {
        priority = "extra-high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-W-window-background.png",
        width = 80,
        height = 137,
        frame_count = 1,
        direction_count = 1,
        shift = util.by_pixel(11.5, -11.25),
        scale = 0.5
    }
}

-- Wet mining frame fluid flow
---@type data.Animation4Way
local input_fluid_patch_fluid_flow_sprites = {
    north = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-N-fluid-flow.png",
        width = 136,
        height = 99,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-2.5, -0.75),
        scale = 0.5
    },
    east = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-E-fluid-flow.png",
        width = 82,
        height = 139,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-11.5, -11.25),
        scale = 0.5
    },
    south = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-S-fluid-flow.png",
        width = 136,
        height = 80,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-2.5, -29.5),
        scale = 0.5
    },
    west = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-W-fluid-flow.png",
        width = 83,
        height = 140,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(10.75, -11),
        scale = 0.5
    }
}

-- Wet mining frame fluid background
---@type data.Animation4Way
local input_fluid_patch_fluid_base_sprites = {
    north = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-N-fluid-background.png",
        width = 138,
        height = 94,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-2, 0),
        scale = 0.5
    },
    east = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-E-fluid-background.png",
        width = 84,
        height = 138,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-12, -11),
        scale = 0.5
    },
    south = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-S-fluid-background.png",
        width = 138,
        height = 80,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(-2, -29),
        scale = 0.5
    },
    west = {
        priority = "high",
        filename = ei_graphics_kirazy_path.."entity/unused/electric-mining-drill-W-fluid-background.png",
        width = 83,
        height = 137,
        line_length = 1,
        frame_count = 1,
        animation_speed = 0.5,
        direction_count = 1,
        shift = util.by_pixel(11.75, -10.75),
        scale = 0.5
    }
}

local wet_mining_graphics_set = {
    animation = drill_animations,
    circuit_connector_layer = "object",
    working_visualisations = {
        -- Fluid window background
        {
            always_draw = true,
            north_animation = input_fluid_patch_window_sprites.north,
            east_animation = input_fluid_patch_window_sprites.east,
            south_animation = input_fluid_patch_window_sprites.south,
            west_animation = input_fluid_patch_window_sprites.west,

        },
        -- Fluid base
        {
            always_draw = true,
            apply_tint = "input-fluid-base-color",
            north_animation = input_fluid_patch_fluid_base_sprites.north,
            east_animation = input_fluid_patch_fluid_base_sprites.east,
            south_animation = input_fluid_patch_fluid_base_sprites.south,
            west_animation = input_fluid_patch_fluid_base_sprites.west,

        },
        -- Fluid flow
        {
            always_draw = true,
            apply_tint = "input-fluid-flow-color",
            north_animation = input_fluid_patch_fluid_flow_sprites.north,
            east_animation = input_fluid_patch_fluid_flow_sprites.east,
            south_animation = input_fluid_patch_fluid_flow_sprites.south,
            west_animation = input_fluid_patch_fluid_flow_sprites.west,
        },
        -- Fluid frame
        {
            always_draw = true,
            north_animation = {
                layers = {
                    input_fluid_patch_sprites.north,
                    input_fluid_patch_shadow_sprites.north
                }
            },
            east_animation = {
                layers = {
                    input_fluid_patch_sprites.east,
                    input_fluid_patch_shadow_sprites.east
                }
            },
            south_animation = {
                layers = {
                    input_fluid_patch_sprites.south,
                    input_fluid_patch_shadow_sprites.south
                }
            },
            west_animation = {
                layers = {
                    input_fluid_patch_sprites.west,
                    input_fluid_patch_shadow_sprites.west
                }
            },
        },
        -- Fluid frame shadow
        {
            always_draw = true,
            north_animation = input_fluid_patch_shadow_animations.north,
            east_animation = input_fluid_patch_shadow_animations.east,
            south_animation = input_fluid_patch_shadow_animations.south,
            west_animation = input_fluid_patch_shadow_animations.west,
        },
    }
}
]]
-- Circuit connection points
---@type data.CircuitConnectorDefinition[]
local circuit_connectors = circuit_connector_definitions.create_vector(universal_connector_template, {
	{
		variation = 4,
		main_offset = util.by_pixel(-3.5, -55.5),
		shadow_offset = util.by_pixel(-2, -44.5),
		show_shadow = true,
	},
	{
		variation = 2,
		main_offset = util.by_pixel(42, -12.5),
		shadow_offset = util.by_pixel(43.5, -0.5),
		show_shadow = true,
	},
	{
		variation = 0,
		main_offset = util.by_pixel(4.5, 33),
		shadow_offset = util.by_pixel(8.5, 44.5),
		show_shadow = true,
	},
	{
		variation = 6,
		main_offset = util.by_pixel(-41.5, -6.5),
		shadow_offset = util.by_pixel(-33.5, 5),
		show_shadow = true,
	},
})

--====================================================================================================
--SURFACE HARVESTER
--====================================================================================================

data:extend({
	{
		name = "ei-burner-surface-harvester",
		type = "technology",
		icon = ei_path .. "graphics/tech/burner-surface-harvester.png",
		icon_size = 512,
		icon_mipmaps = 5,
		age = "dark-age",
		effects = {
			{
				type = "unlock-recipe",
				recipe = "ei-burner-surface-harvester",
			},
			{
				type = "unlock-recipe",
				recipe = "ei-surface-harvester-running-nauvis",
			},
		},
		prerequisites = { "ei-dark-age" },
		unit = {
			count = 100,
			ingredients = ei_data.science["dark-age"],
			time = 20,
		},
	},
	{
		name = "ei-burner-surface-harvester",
		type = "item",
		icon = ei_graphics_kirazy_path .. "icon/electric-mining-drill.png",
		icon_size = 64,
		icon_mipmaps = 4,
		place_result = "ei-burner-surface-harvester",
		stack_size = 20,
		subgroup = "extraction-machine",
		order = "a[items]-a[surface-harvester]-a",
	},
	{
		name = "ei-burner-surface-harvester",
		type = "recipe",
		enabled = false,
		ingredients = {
			{ type = "item", name = "burner-mining-drill", amount = 1 },
			{ type = "item", name = "ei-iron-mechanical-parts", amount = 4 },
			{ type = "item", name = "ei-iron-beam", amount = 2 },
		},
		results = {
			{ type = "item", name = modprefix .. "burner-surface-harvester", amount = 1 },
		},
		always_show_made_in = true,
		energy_required = 1,
	},
	{
		name = "ei-surface-harvester",
		type = "recipe-category",
	},
	{
		name = "ei-burner-surface-harvester",
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
			result = "ei-burner-surface-harvester",
		},
		crafting_categories = { "ei-surface-harvester" },
		crafting_speed = 0.5,
		--fixed_recipe = "ei-surface-harvester-mining",
		heating_energy = "50kW",
		energy_source = {
			type = "burner",
			emissions_per_minute = { pollution = 12 },
			fuel_inventory_size = 1,
			burnt_inventory_size = 1,
			smoke = {
				{
					name = "smoke",
					tape = "trival-smoke",
					frequency = 5,
					position = { 0, -1.3 },
					duration = 1,
				},
			},
			effectivity = 1,
			fuel_categories = { "chemical" },
		},
		energy_usage = "150kW",
		working_sound = {
			sound = {
				filename = ei_path .. "sounds/classic-electric-mining-drill.ogg",
				volume = 0.75,
			},
			idle_sound = {
				filename = "__base__/sound/idle1.ogg",
				volume = 0.6,
			},
			apparent_volume = 1.5,
		},

		graphics_set = {
			animation = drill_animations,
			circuit_connector_layer = "object",
		},
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
		circuit_connector = circuit_connectors,
		circuit_wire_max_distance = default_circuit_wire_max_distance,
		surface_conditions = {
			{ property = "pressure", min = 10 },
			{
				property = "gravity",
				min = 1,
				max = 100,
			},
		},
		fast_replaceable_group = "ei-surface-harvester",
		next_upgrade = "ei-steam-surface-harvester",
	},
	{
		name = "ei-surface-harvester-running-nauvis",
		type = "recipe",
		category = "ei-surface-harvester",
		energy_required = 1,
		ingredients = {},
		results = {
			{ type = "item", name = "stone", amount_min = 1, amount_max = 6, probability = 0.1 },
		},
		always_show_made_in = true,
		enabled = false,
		main_product = "stone",
		surface_conditions = {
			{
				property = "magnetic-field",
				min = 90,
				max = 90,
			},
		},
	},
	{
		name = "ei-surface-harvester-running-fulgora",
		type = "recipe",
		category = "ei-surface-harvester",
		energy_required = 1,
		ingredients = {},
		results = {
			{ type = "item", name = "stone", amount_min = 1, amount_max = 3, probability = 0.06 },
			{ type = "item", name = "ei-sand", amount_min = 1, amount_max = 3, probability = 0.125 },
		},
		always_show_made_in = true,
		enabled = false,
		main_product = "stone",
		surface_conditions = {
			{
				property = "gravity",
				min = 8,
				max = 8,
			},
		},
	},
	{
		name = "ei-surface-harvester-running-vulcanus",
		type = "recipe",
		category = "ei-surface-harvester",
		energy_required = 1,
		ingredients = {},
		results = {
			{ type = "item", name = "stone", amount_min = 1, amount_max = 3, probability = 0.1 },
			{ type = "item", name = "atan-ash", amount_min = 1, amount_max = 3, probability = 0.15 },
		},
		always_show_made_in = true,
		enabled = false,
		main_product = "stone",
		surface_conditions = {
			{
				property = "gravity",
				min = 40,
				max = 40,
			},
		},
	},
	{
		name = "ei-surface-harvester-running-gleba",
		type = "recipe",
		category = "ei-surface-harvester",
		energy_required = 1,
		ingredients = {},
		results = {
			{ type = "item", name = "stone", amount_min = 1, amount_max = 4, probability = 0.1 },
			{ type = "item", name = "spoilage", amount_min = 1, amount_max = 2, probability = 0.05 },
		},
		always_show_made_in = true,
		enabled = false,
		main_product = "stone",
		surface_conditions = {
			{
				property = "gravity",
				min = 20,
				max = 20,
			},
		},
	},
	{
		name = "ei-surface-harvester-running-aquilo",
		type = "recipe",
		category = "ei-surface-harvester",
		energy_required = 1,
		ingredients = {},
		results = {
			{ type = "item", name = "ice", amount_min = 1, amount_max = 2, probability = 0.5 },
		},
		always_show_made_in = true,
		enabled = false,
		main_product = "ice",
		surface_conditions = {
			{
				property = "pressure",
				min = 300,
				max = 300,
			},
		},
	},
	{
		name = "ei-surface-harvester-running-gaia",
		type = "recipe",
		category = "ei-surface-harvester",
		energy_required = 1,
		ingredients = {},
		results = {
			{ type = "item", name = "stone", amount_min = 1, amount_max = 3, probability = 0.1 },
		},
		always_show_made_in = true,
		enabled = false,
		main_product = "stone",
		surface_conditions = {
			{
				property = "gravity",
				min = 15.5,
				max = 15.5,
			},
		},
	},
})

local pdf = ei_lib.raw.technology["planet-discovery-fulgora"]
if pdf and pdf.effects then
	table.insert(pdf.effects, {
		type = "unlock-recipe",
		recipe = "ei-surface-harvester-running-fulgora",
	})
end
local pdv = ei_lib.raw.technology["planet-discovery-vulcanus"]
if pdv and pdv.effects then
	table.insert(pdv.effects, {
		type = "unlock-recipe",
		recipe = "ei-surface-harvester-running-vulcanus",
	})
end
local pdg = ei_lib.raw.technology["planet-discovery-gleba"]
if pdg and pdg.effects then
	table.insert(pdg.effects, {
		type = "unlock-recipe",
		recipe = "ei-surface-harvester-running-gleba",
	})
end
local pda = ei_lib.raw.technology["planet-discovery-aquilo"]
if pda and pda.effects then
	table.insert(pda.effects, {
		type = "unlock-recipe",
		recipe = "ei-surface-harvester-running-aquilo",
	})
end
