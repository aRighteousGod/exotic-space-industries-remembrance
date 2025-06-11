--====================================================================================================
--ITEMS
--====================================================================================================
local impact_sounds = function()
    return
    {
        type = "play-sound",
        sound = sound_variations(ei_trains_sounds_path.."em_train_collide", 6, 0.3, { volume_multiplier("main-menu", 3.25), volume_multiplier("driving", 1.9) } )
    }
end
local drive_over_tie = function()
	return
	{
	  type = "play-sound",
	  sound = sound_variations(ei_trains_sounds_path.."em_train_tie", 6, 0.3, { volume_multiplier("main-menu", 3.25), volume_multiplier("driving", 1.9) } )
	}
  end
function train_front_light()
    local train_front_light =
    {
        {
            type = "oriented",
            minimum_darkness = 0.3,
            picture =
            {
                filename = ei_trains_entity_path.."em_train_light_cone_280x700.png",
                priority = "medium",
                scale = 1,
                width = 280,
                height = 700,
                draw_as_light = true,
                blend_mode = "multiplicative-with-alpha"
            },
            shift = {-0.85, -10.5},
            size = 1,
            intensity = 0.98
        },
        {
            type = "oriented",
            minimum_darkness = 0.3,
            picture =
            {
                filename = ei_trains_entity_path.."em_train_light_cone_280x700.png",
                priority = "medium",
                scale = 1,
                width = 280,
                height = 700,
                draw_as_light = true,
                blend_mode = "multiplicative-with-alpha"
            },
            shift = {0.85, -10.5},
            size = 1,
            intensity = 0.98
        }
    }
return train_front_light
end
function rolling_stock_standby_light()
    local standby_light =
    {
        {
            type = "oriented",
            picture =
            {
                filename = ei_trains_entity_path.."em_train_under_glow_512x512.png",
                priority = "medium",
                scale = 1,
                width = 171,
                height = 171,
                draw_as_glow = true,
                blend_mode = "multiplicative"
            },
            size = 3.5,
            intensity = 0.88,
            frame_count = 60,
            line_length = 9,
            animation_speed = 1
        }
    }
    return standby_light
end

function rolling_stock_back_light()
--[[
    local back_light =
    {
        {
            type = "oriented",
            minimum_darkness = 0.3,
            picture =
            {
                filename = ei_path.."graphics/em_trains/em_train_rear_light_170x170.png",
                priority = "medium",
                scale = 1,
                width = 170,
                height = 170,
                draw_as_glow = true,
                blend_mode = "additive-soft"
            },
            shift = {0, 3.6},
            size = 1,
            intensity = 0.75
        }
    }
]]
local back_light =
		{
			{
				type = "oriented",
				minimum_darkness = 0.3,
				picture =
				{
					filename = ei_trains_entity_path.."em_train_light_cone_280x700.png",
					priority = "medium",
					scale = 1,
					width = 280,
					height = 700,
					draw_as_light = true,
                    blend_mode = "multiplicative-with-alpha"
				},
				shift = {-0.3, 7.0},
				size = 0.5,
				intensity = 0.98
			},
			{
				type = "oriented",
				minimum_darkness = 0.3,
				picture =
				{
					filename = ei_trains_entity_path.."em_train_light_cone_280x700.png",
					priority = "medium",
					scale = 1,
					width = 280,
					height = 700,
					draw_as_light = true,
					blend_mode = "multiplicative-with-alpha"
				},
				shift = {0.3, 7.0},
				size = 0.5,
				intensity = 0.98
			}
		}
    return back_light
end
data:extend({
    {
        name = "ei_em-locomotive",
        type = "item",
        icon = ei_trains_item_path.."em-locomotive.png",
        icon_size = 64,
        subgroup = "transport",
        order = "x1",
        place_result = "ei_em-locomotive",
        stack_size = 50
    },
	{
        name = "ei_em-fluid-wagon",
        type = "item",
        icon = ei_trains_item_path.."em-fluid-wagon.png",
        icon_size = 64,
        subgroup = "transport",
        order = "x3",
        place_result = "ei_em-fluid-wagon",
        stack_size = 50
    },
	{
        name = "ei_em-cargo-wagon",
        type = "item",
        icon = ei_trains_item_path.."em-cargo-wagon.png",
        icon_size = 64,
        subgroup = "transport",
        order = "x2",
        place_result = "ei_em-cargo-wagon",
        stack_size = 50
    },
	{
        name = "ei_em-fielder",
        type = "item",
        icon = ei_trains_item_path.."fielder.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "n[rocket-control-unit]-a",
        stack_size = 10
    },
})

--====================================================================================================
--RECIPES
--====================================================================================================

data:extend({
    {
        name = "ei_em-locomotive",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
          {type="item", name="locomotive", amount=1},
          {type="item", name="ei-carbon-structure", amount=25},
          {type="item", name="ei-clean-plating", amount=25},
          {type="item", name="ei-advanced-motor", amount=20},
          {type="item", name="ei_em-fielder", amount=14},
		},
        results = {{type="item", name="ei_em-locomotive", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_em-locomotive",
    },
	{
        name = "ei_em-fluid-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
    {type="item", name="fluid-wagon", amount=1},
	{type="item", name="ei-carbon-structure", amount=15},
	{type="item", name="ei-clean-plating", amount=15},
	{type="item", name="ei_em-fielder", amount=8},
		},
        results = {{type="item", name="ei_em-fluid-wagon", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_em-fluid-wagon",
    },
	{
        name = "ei_em-cargo-wagon",
        type = "recipe",
        category = "crafting",
        energy_required = 10,
        ingredients = {
   {type="item", name="cargo-wagon", amount=1},
	{type="item", name="ei-carbon-structure", amount=15},
	{type="item", name="ei-clean-plating", amount=15},
	{type="item", name="ei_em-fielder", amount=8},
		},
        results = {{type="item", name="ei_em-cargo-wagon", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_em-cargo-wagon",
    },
	{
        name = "ei_em-fielder",
        type = "recipe",
        category = "crafting",
        energy_required = 20,
        ingredients =
        {
    {type="item", name="energy-shield-mk2-equipment", amount=1},
    {type="item", name="ei-eu-magnet", amount=2},
    {type="item", name="ei-superior-data", amount=6},
        },
        results = {{type="item", name="ei_em-fielder", amount=1}},
        enabled = false,
        always_show_made_in = true,
        main_product = "ei_em-fielder",
    },
})

--====================================================================================================
--TECHS
--====================================================================================================

data:extend({
    {
        name = "ei_em-trains",
        type = "technology",
        icon = ei_trains_tech_path.."em-locomotive.png",
        icon_size = 256,
        prerequisites = {"ei-clean-plating", "energy-shield-mk2-equipment", "fluid-wagon", "ei-copper-beacon"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei_em-locomotive"
            },
			{
				type = "unlock-recipe",
				recipe = "ei_em-fluid-wagon"
			},
			{
				type = "unlock-recipe",
				recipe = "ei_em-cargo-wagon"
			},
			{
				type = "unlock-recipe",
				recipe = "ei_charger"
			},
			{
				type = "unlock-recipe",
				recipe = "ei_em-fielder"
			},
        },

        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },

        age = "quantum-age",
    },
})


unit = {
  count = 100,
  ingredients = ei_data.science["quantum-age"],
  time = 20
}

local eff = {1,5,{["dynamic"] = "eff_"}, unit}
local speed = {1,20,{["static"] = "em-locomotive", ["dynamic"] = "spd_"}, unit}
local acc = {1,20,{["dynamic"] = "acc_"}, unit}

local function make_multiple_techs(tab)

	local blank = {
        name = "ei_advanced-port",
        type = "technology",
        icon = "advanced-port.png",
        icon_size = 256,
        prerequisites = {"ei_em-trains"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei_advanced-port"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["quantum-age"],
            time = 20
        },
        age = "quantum-age",
    }

	for i=tab[1], tab[2] do

		local blank_copy = util.table.deepcopy(blank)
		local path = tab[3]["dynamic"]..tostring(i)

		blank_copy.name = "ei_"..path
		blank_copy.localised_name = {"exotic-industries-emt."..tab[3]["dynamic"].."name", tostring(i)}

		if not tab[3]["static"] then
			blank_copy.icon = ei_trains_tech_path..path..".png"
		else
			blank_copy.icons = {
				{
					icon = ei_trains_tech_path..tab[3]["static"]..".png",
          icon_size = 256
				},
				{
					icon = ei_trains_tech_path..path..".png",
          icon_size = 256
				}
			}
		end

		if i > 1 then
			blank_copy.prerequisites = {"ei_"..tab[3]["dynamic"]..tostring(i-1)}
		end

		blank_copy.effects = {
			{
				type = "nothing",
				effect_description = {"exotic-industries-emt."..tab[3]["dynamic"].."effect", tostring(i)}
			}
		}
		blank_copy.unit = table.deepcopy(tab[4])
		blank_copy.unit.count = (tab[4].count)*(i*10)
		blank_copy.ignore_tech_cost_multiplier = true

		data:extend({blank_copy})
		
	end

end

make_multiple_techs(eff)
make_multiple_techs(acc)
make_multiple_techs(speed)


--====================================================================================================
--ENTITIES
--====================================================================================================

local weight = 500
local max_speed = 2
local max_speed_wagon = 10
local max_speed_sound_leveloff = 4 --pitch stops increasing
local max_speed_sound_levelon = 0.1 --starts
local em_sound_minimum_speed = 0.09
local em_sound_maximum_speed = 4
local max_power = "1MW"
local braking_force = 35
local braking_force_wagon = 10
local friction_force = 0.01
local air_resistance = 0.0001
local drive_over_tie_speed = 1.5
data:extend({
    {
		type = "locomotive",
		name = "ei_em-locomotive",
		icon = ei_trains_item_path.."em-locomotive.png",
        icon_size = 64,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		minable = 
        {
            mining_time = 1,
            result = "ei_em-locomotive"
        },
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 800,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",

		collision_box = {{-0.6, -2.6}, {0.6, 2.6}},
		selection_box = {{-1, -3}, {1, 3}},
		drawing_box = {{-1, -4}, {1, 3}},
		connection_distance = 3,
        joint_distance = 4,		

		weight = weight,
		max_speed = max_speed,
		max_power = max_power,
		reversing_power_modifier = 1,
		braking_force = 35,
		friction_force = 0.01,
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
    energy_source = {
      type = "burner",
			fuel_categories = {"ei_emt-fuel"},
			effectivity = 1,
			fuel_inventory_size = 1,
		},		
		front_light = train_front_light(),
		back_light = rolling_stock_back_light(),
		stand_by_light = rolling_stock_standby_light(),
		pictures =
		{
      rotated = {
        priority = "very-low",
        width = 512,
        height = 512,
        direction_count = 128,
        filenames =
        {
          ei_trains_entity_path.."em-locomotive_1.png",
          ei_trains_entity_path.."em-locomotive_2.png"
        },
        line_length = 8,
        lines_per_file = 8,
          shift = {0, -0.5},
        scale = 0.58,
			},

			layers = {
				{
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					filenames =
					{
						ei_trains_entity_path.."em-locomotive_1.png",
						ei_trains_entity_path.."em-locomotive_2.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				},
				{
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					draw_as_shadow = true,
					filenames =
					{
						ei_trains_entity_path.."em-locomotive_1_shadow.png",
						ei_trains_entity_path.."em-locomotive_2_shadow.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
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
  
		wheels = standard_train_wheels,
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
				speed_multiplier_deviation = 1.1,
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
				speed_multiplier_deviation = 1.1,
				offset_deviation = {{0.3, -2.7}, {0.75, 2.7}}
			},
			{
				type = "play-sound",
				sound =
				{
					{
						filename = ei_trains_sounds_path.."em_train_brakes.ogg",
						volume = 0.21
					},
				}
			},
		},
	drive_over_tie_trigger = drive_over_tie(), --we floating over them ties
	drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
	tie_distance = 90,
	vehicle_impact_sound =  impact_sounds(),
	impact_category = "metal-large",
    working_sound =
    {
      main_sounds =
      {
        {
          sound =
          {
            filename = ei_trains_sounds_path.."em_train_engine.ogg",
            volume = 1.0,
            modifiers =
            {
              volume_multiplier("main-menu", 1.8),
              volume_multiplier("driving", 0.9),
              volume_multiplier("tips-and-tricks", 0.8),
              volume_multiplier("elevation", 0.7)
            },
          },
		  min_speed_sound_levelon = em_sound_minimum_speed,
		  max_speed_sound_leveloff = em_sound_maximum_speed,
          match_volume_to_activity = true,
          activity_to_volume_modifiers =
          {
            multiplier = 3.5,
            offset = 0.0,
          },
          match_speed_to_activity = true,
          min_speed = max_speed_sound_levelon,
          max_speed = max_speed_sound_leveloff,
          activity_to_speed_modifiers =
          {
            multiplier = 1,
            minimum = 0.5,
            maximum = 4,
            offset = 0.2,
          }
        },
        {
          sound =
          {
            filename = ei_trains_sounds_path.."em_train_engine_idle.ogg",
            volume = 0.9,
            modifiers =
            {
              volume_multiplier("main-menu", 1.8),
              volume_multiplier("driving", 0.9),
              volume_multiplier("tips-and-tricks", 0.8)
            },
          },
          match_volume_to_activity = true,
          activity_to_volume_modifiers =
          {
            multiplier = 2.25,
            offset = 2.25,
            inverted = true
          },
        },
      },
	max_sounds_per_prototype = 2,
	activate_sound = { filename = ei_trains_sounds_path.."em_train_engine_start.ogg", volume = 0.7 },
	deactivate_sound = { filename = ei_trains_sounds_path.."em_train_engine_stop.ogg", volume = 0.7 },
	allow_remote_driving = true
    },
		open_sound = { filename = "__base__/sound/car-door-open.ogg", volume=0.7 },
		close_sound = { filename = "__base__/sound/car-door-close.ogg", volume = 0.7 },
		sound_minimum_speed = em_sound_minimum_speed,
        sound_maximum_speed = em_sound_maximum_speed
	},
	{
		type = "fluid-wagon",
		name = "ei_em-fluid-wagon",
		icon = ei_trains_item_path.."em-fluid-wagon.png",
        icon_size = 64,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		capacity = 50000,
		minable = {
            mining_time = 1,
            result = "ei_em-fluid-wagon"
        },
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 600,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",
		
		collision_box = {{-0.6, -2.4}, {0.6, 2.4}},
		selection_box = {{-1.0, -2.7}, {1, 3.3}},		
		connection_distance = 3, joint_distance = 4,
		
		weight = weight,
		max_speed = max_speed_wagon,
		braking_force = braking_force_wagon,
		friction_force = friction_force,
		air_resistance = air_resistance,
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
		--back_light = rolling_stock_back_light(),
		stand_by_light = rolling_stock_standby_light(),
		pictures =
		{
      rotated = {
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					filenames =
					{
						ei_trains_entity_path.."em-wagon_1.png",
						ei_trains_entity_path.."em-wagon_2.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				},

			layers = {
				{
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					filenames =
					{
						ei_trains_entity_path.."em-wagon_1.png",
						ei_trains_entity_path.."em-wagon_2.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				},
				{
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					draw_as_shadow = true,
					filenames =
					{
						ei_trains_entity_path.."em-wagon_1_shadow.png",
						ei_trains_entity_path.."em-wagon_2_shadow.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				}
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
		drive_over_tie_trigger = drive_over_tie(), --drive_over_tie()
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 90,
		working_sound =
		{
			sound =
			{
				filename = ei_trains_sounds_path.."em_train_engine.ogg",
				volume = 0.8
			},
            match_speed_to_activity = true,
            min_speed = max_speed_sound_levelon,
            max_speed = max_speed_sound_leveloff
		},
		crash_trigger = crash_trigger(),
		open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 },
		close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 },
		sound_minimum_speed = em_sound_minimum_speed,
        sound_maximum_speed = em_sound_maximum_speed,
		vehicle_impact_sound =  impact_sounds(),
	},
	{
		type = "cargo-wagon",
		name = "ei_em-cargo-wagon",
		icon = ei_trains_item_path.."em-cargo-wagon.png",
        icon_size = 64,
		flags = {"placeable-neutral", "player-creation", "placeable-off-grid", },
		inventory_size = 60,
		minable = {
            mining_time = 1,
            result = "ei_em-cargo-wagon"
        },
		mined_sound = {filename = "__core__/sound/deconstruct-medium.ogg"},
		max_health = 600,
		corpse = "medium-remnants",
		dying_explosion = "medium-explosion",
		
		collision_box = {{-0.6, -2.4}, {0.6, 2.4}},
		selection_box = {{-1.0, -2.7}, {1, 3.3}},		
		connection_distance = 3, joint_distance = 4,
		
		weight = weight,
		max_speed = max_speed_wagon,
		braking_force = braking_force_wagon,
		friction_force = friction_force,
		air_resistance = air_resistance,
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
		stand_by_light = rolling_stock_standby_light(),
		pictures =
		{
			rotated = {
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					filenames =
					{
						ei_trains_entity_path.."em-cargo-wagon_1.png",
						ei_trains_entity_path.."em-cargo-wagon_2.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				},

			layers = {
				{
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					filenames =
					{
						ei_trains_entity_path.."em-cargo-wagon_1.png",
						ei_trains_entity_path.."em-cargo-wagon_2.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				},
				{
					priority = "very-low",
					width = 512,
					height = 512,
					direction_count = 128,
					draw_as_shadow = true,
					filenames =
					{
						ei_trains_entity_path.."em-wagon_1_shadow.png",
						ei_trains_entity_path.."em-wagon_2_shadow.png"
					},
					line_length = 8,
					lines_per_file = 8,
		    		shift = {0, -0.5},
					scale = 0.58,
				}
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
		drive_over_tie_trigger = drive_over_tie(), --drive_over_tie()
		drive_over_tie_trigger_minimal_speed = drive_over_tie_speed,
		tie_distance = 90,
		working_sound =
		{
			sound =
			{
				filename = ei_trains_sounds_path.."em_train_engine.ogg",
				volume = 0.8
			},
            match_speed_to_activity = true,
            min_speed = max_speed_sound_levelon,
            max_speed = max_speed_sound_leveloff
		},
		crash_trigger = crash_trigger(),
		open_sound = { filename = "__base__/sound/machine-open.ogg", volume = 0.85 },
		close_sound = { filename = "__base__/sound/machine-close.ogg", volume = 0.75 },
		sound_minimum_speed = em_sound_minimum_speed,
        sound_maximum_speed = em_sound_maximum_speed,
		vehicle_impact_sound =  impact_sounds(),
	},
})

--====================================================================================================
--OTHER
--====================================================================================================

data:extend({
	{
		type = "fuel-category",
		name = "ei_emt-fuel"
	},
})

local foo = {
	type = "item",
	name = "ei_emt-fuel_0_0",
	icon = ei_trains_item_path.."dummy.png",
	icon_size = 64,
	stack_size = 1,
	fuel_category = "ei_emt-fuel",
	hidden = true,
	fuel_value = "1GJ",
	fuel_acceleration_multiplier = 1,
	fuel_top_speed_multiplier = 1,
}

for i=0,20 do
	for j=0,20 do
		local bar = table.deepcopy(foo)
		bar.name = "ei_emt-fuel_"..i.."_"..j
		bar.localised_name = {"exotic-industries-emt.fuelname", tostring(j), tostring(i)}
		bar.fuel_acceleration_multiplier = 1 + (0.1*i)
		bar.fuel_top_speed_multiplier = 1 + (0.1*j)
		data:extend({bar})
	end
end