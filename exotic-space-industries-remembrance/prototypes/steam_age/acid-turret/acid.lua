--Originally by @DarkNova
--Updated by @Beathoven
require "util"
ei_lib = require("lib/lib")
require ("circuit-connector-sprites")
local math3d = require "math3d"
local sounds = require("__base__.prototypes.entity.sounds")
local acidutil = require("acid-util")
local acid_sticker_damage_per_tick = 100 / 60
local acid_frame_damage_per_tick = 13 / 60
local acid_tree_damage_per_tick = 20 / 60
--local flamethrower_stream_on_hit_damage = 3
local acid_small_damage_per_tick = 8 / 60
local fire_small_damage_per_tick = 7 / 60

--sticker
local sticker_option = {
  	poison = {
		tint = {r = 0.5, g = 0.5, b = 0.5, a = 0.3},
		target_movement_modifier = 0.5,
		duration_in_ticks = 10 * 60,
		damage_per_tick = { amount = (50 / 60)*1.15, type = "poison" }
	},
}
function sticker_set(inputs)
return
{
	type = "sticker",
	name = inputs.name,
	flags = {"not-on-map"},
	
	animation = 
	{
		filename = inputs.filename and inputs.filename or ei_graphics_3_path.."graphics/entities/acid-turret/acid-flame/spark.png",
		line_length = inputs.line_length and inputs.line_length or 5,
		width = inputs.width and inputs.width or 64,
		height = inputs.height and inputs.height or 64,
		frame_count = inputs.frame_count and inputs.frame_count or 5,
		axially_symmetrical = false,
		direction_count = inputs.direction_count and inputs.direction_count or 1,
		blend_mode = "normal",
		animation_speed = 0.5,
		scale = inputs.scale and inputs.scale or 0.5,
		tint = inputs.tint and inputs.tint or electric_tint,
		shift = math3d.vector2.mul({-0.078125, -1.8125}, 0.1),
	},
	duration_in_ticks = inputs.duration_in_ticks and inputs.duration_in_ticks or 7 * 60,
	target_movement_modifier = inputs.target_movement_modifier and inputs.target_movement_modifier or 0.4,
	damage_per_tick = inputs.damage_per_tick and inputs.damage_per_tick
}
end
data:extend({

  	sticker_set{name="ei-poison-sticker", filename=ei_graphics_3_path.."graphics/entities/acid-turret/acid-flame/spark.png",
		line_length=5, width=64, height=64, frame_count=5, direction_count=1, scale=0.5,
		target_movement_modifier = sticker_option.poison.target_movement_modifier,
		tint = sticker_option.poison.tint,
		duration_in_ticks = sticker_option.poison.duration_in_ticks,
		damage_per_tick = sticker_option.poison.damage_per_tick
	},
})

--turret
local function make_color(r_,g_,b_,a_)
	return { r = r_ * a_, g = g_ * a_, b = b_ * a_, a = a_ }
end

function acidutil.flamethrower_turret_extension_animation(shft, opts)
local m_line_length = 5
local m_frame_count = 15
local ret_layers =
  {
    -- diffuse
    {
      filename = ei_graphics_3_path.."graphics/entities/acid-turret/acid-turret-gun-extension.png",
      priority = "medium",
      frame_count = opts and opts.frame_count or m_frame_count,
      line_length = opts and opts.line_length or m_line_length,
      run_mode = opts and opts.run_mode or "forward",
      width = 152,
      height = 128,
      direction_count = 1,
      shift = util.by_pixel(0, -26),
      scale = 0.5
    },
    -- mask
    {
      filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-gun-extension-mask.png",
      flags = { "mask" },
      frame_count = opts and opts.frame_count or m_frame_count,
      line_length = opts and opts.line_length or m_line_length,
      run_mode = opts and opts.run_mode or "forward",
      width = 144,
      height = 120,
      direction_count = 1,
      shift = util.by_pixel(0, -26),
      apply_runtime_tint = true,
      scale = 0.5
    },
    -- shadow
    {
      filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-gun-extension-shadow.png",
      frame_count = opts and opts.frame_count or m_frame_count,
      line_length = opts and opts.line_length or m_line_length,
      run_mode = opts and opts.run_mode or "forward",
      width = 180,
      height = 114,
      direction_count = 1,
      shift = util.by_pixel(33, -1),
      draw_as_shadow = true,
      scale = 0.5
    }
  }

  local yoffsets = { north = 0, east = 3, south = 2, west = 1 }
  local m_lines = m_frame_count / m_line_length

  return { layers = acidutil.foreach(ret_layers, function(tab)
    if tab.shift then tab.shift = { tab.shift[1] + shft[1], tab.shift[2] + shft[2] } end
    if tab.height then tab.y = tab.height * m_lines * yoffsets[opts.direction] end
  end) }
end

acidutil.turret_gun_shift =
{
  north = util.by_pixel(0.0, -6.0),
  east = util.by_pixel(18.5, 9.5),
  south = util.by_pixel(0.0, 19.0),
  west = util.by_pixel(-12.0, 5.5)
}

acidutil.turret_model_info =
{
  tilt_pivot = { -1.68551, 0, 2.35439 },
  gun_tip_lowered = { 4.27735, 0, 3.97644 },
  gun_tip_raised = { 2.2515, 0, 7.10942 },
  units_per_tile = 4
}

acidutil.gun_center_base = math3d.vector2.sub({0,  -0.725}, acidutil.turret_gun_shift.south)

function acidutil.flamethrower_turret_preparing_muzzle_animation(opts)
  opts.frame_count = opts.frame_count or 15
  opts.run_mode = opts.run_mode or "forward"
  assert(opts.orientation_count)

  local model = acidutil.turret_model_info
  local angle_raised = -math3d.vector3.angle({1, 0, 0}, math3d.vector3.sub(model.gun_tip_raised, model.tilt_pivot))
  local angle_lowered = -math3d.vector3.angle({1, 0, 0}, math3d.vector3.sub(model.gun_tip_lowered, model.tilt_pivot))
  local delta_angle = angle_raised - angle_lowered

  local generated_orientations = {}
  for r = 0, opts.orientation_count-1 do
    local phi = (r / opts.orientation_count - 0.25) * math.pi * 2
    local generated_frames = {}
    for i = 0, opts.frame_count-1 do
      local k = opts.run_mode == "backward" and (opts.frame_count - i - 1) or i
      local progress = opts.progress or (k / (opts.frame_count - 1))

      local matrix = math3d.matrix4x4
      local mat = matrix.compose({
        matrix.translation_vec3(math3d.vector3.mul(model.tilt_pivot, -1)),
        matrix.rotation_y(progress * delta_angle),
        matrix.translation_vec3(model.tilt_pivot),
        matrix.rotation_z(phi),
        matrix.scale(1 / model.units_per_tile, 1 / model.units_per_tile, -1 / model.units_per_tile)
      })

      local vec = math3d.matrix4x4.mul_vec3(mat, model.gun_tip_lowered)
      table.insert(generated_frames, math3d.project_vec3(vec))
    end
    local direction_data = { frames = generated_frames }
    if (opts.layers and opts.layers[r]) then
      direction_data.render_layer = opts.layers[r]
    end
    table.insert(generated_orientations, direction_data)
  end

  return
  {
    rotations = generated_orientations,
    direction_shift = acidutil.turret_gun_shift
  }
end

function acidutil.flamethrower_turret_extension(opts)
  local set_direction = function (opts, dir)
    opts.direction = dir
    return opts
  end

  return
  {
    north = acidutil.flamethrower_turret_extension_animation(acidutil.turret_gun_shift.north, set_direction(opts, "north")),
    east = acidutil.flamethrower_turret_extension_animation(acidutil.turret_gun_shift.east, set_direction(opts, "east")),
    south = acidutil.flamethrower_turret_extension_animation(acidutil.turret_gun_shift.south, set_direction(opts, "south")),
    west = acidutil.flamethrower_turret_extension_animation(acidutil.turret_gun_shift.west, set_direction(opts, "west"))
  }
end

function acidutil.flamethrower_turret_prepared_animation(shft, opts)
  local diffuse_layer =
  {
    filename = ei_graphics_3_path.."graphics/entities/acid-turret/acid-turret-gun.png",
    priority = "medium",
    counterclockwise = true,
    line_length = 8,
    width = 158,
    height = 128,
    direction_count = 64,
    shift = util.by_pixel(-1, -25),
    scale = 0.5
  }
  local glow_layer =
  {
    filename = ei_graphics_3_path.."graphics/entities/acid-turret/acid-turret-gun-active.png",
    counterclockwise = true,
    line_length = 8,
    width = 158,
    height = 126,
    direction_count = 64,
    shift = util.by_pixel(-1, -25),
    tint = util.premul_color{1, 1, 1, 0.5},
    blend_mode = "additive",
    scale = 0.5
  }

  local glow_light_layer =
  {
    filename = ei_graphics_3_path.."graphics/entities/acid-turret/acid-turret-gun-active.png",
    counterclockwise = true,
    line_length = 8,
    width = 158,
    height = 126,
    direction_count = 64,
    shift = util.by_pixel(-1, -25),
    tint = util.premul_color{1, 1, 1, 0.5},
    blend_mode = "additive",
    draw_as_light = true,
    scale = 0.5
  }

  local mask_layer =
  {
    filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-gun-mask.png",
    flags = { "mask" },
    counterclockwise = true,
    line_length = 8,
    width = 144,
    height = 112,
    direction_count = 64,
    shift = util.by_pixel(-1, -28),
    apply_runtime_tint = true,
    scale = 0.5
  }
  local shadow_layer =
  {
    filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-gun-shadow.png",
    counterclockwise = true,
    line_length = 8,
    width = 182,
    height = 116,
    direction_count = 64,
    shift = util.by_pixel(31, -1),
    draw_as_shadow = true,
    scale = 0.5
  }

  local ret_layers = opts and opts.attacking and { diffuse_layer, glow_layer, glow_light_layer, mask_layer, shadow_layer }
                                             or  { diffuse_layer, mask_layer, shadow_layer }

  return { layers = acidutil.foreach(ret_layers, function(tab)
    if tab.shift then tab.shift = { tab.shift[1] + shft[1], tab.shift[2] + shft[2] } end
  end) }
end

function acidutil.flamethrower_prepared_animation(opts)
  return
  {
    north = acidutil.flamethrower_turret_prepared_animation(acidutil.turret_gun_shift.north, opts),
    east = acidutil.flamethrower_turret_prepared_animation(acidutil.turret_gun_shift.east, opts),
    south = acidutil.flamethrower_turret_prepared_animation(acidutil.turret_gun_shift.south, opts),
    west = acidutil.flamethrower_turret_prepared_animation(acidutil.turret_gun_shift.west, opts)
  }
end

local function set_shift(shift, tab)
  tab.shift = shift
  return tab
end

function acidutil.flamethrower_turret_pipepictures()
  local pipe_sprites = pipepictures()

  return
  {
    north = set_shift({0, 1}, util.table.deepcopy(pipe_sprites.straight_vertical)),
    south = set_shift({0, -1}, util.table.deepcopy(pipe_sprites.straight_vertical)),
    east = set_shift({-1, 0}, util.table.deepcopy(pipe_sprites.straight_horizontal)),
    west = set_shift({1, 0}, util.table.deepcopy(pipe_sprites.straight_horizontal))
  }
end

data:extend({
acidutil.add_basic_acid_graphics_and_effects_definitions{
  type = "fire",
  name = "ei-acid-flame",
  flags = {"placeable-off-grid", "not-on-map"},
  hidden = true,
  damage_per_tick = {amount = 13 / 60, type = "acid"},
  maximum_damage_multiplier = 6,
  damage_multiplier_increase_per_added_fuel = 1,
  damage_multiplier_decrease_per_tick = 0.005,
  scale = 0.25,
  spawn_entity = "ei-acid-flame-on-tree",

  spread_delay = 300,
  spread_delay_deviation = 180,
  maximum_spread_count = 100,

  emissions_per_second = { pollution = 0.005 },

  initial_lifetime = 120,
  lifetime_increase_by = 150,
  lifetime_increase_cooldown = 4,
  maximum_lifetime = 600,
  delay_between_initial_flames = 10,
  --initial_flame_count = 1,

}})
data:extend({
	
{
	type = "fire",
	name = "ei-fire-flame-small",
	flags = {"placeable-off-grid", "not-on-map"},
	duration = 180,
	fade_away_duration = 60,
	spread_duration = 60,
	start_scale = 0.15,
	end_scale = 0.33,
	color = {r=0, g=0.0, b=0.7, a=0.9},
	damage_per_tick = {amount = acid_frame_damage_per_tick, type = "acid"},
	
	spawn_entity = "fire-flame-on-tree",
	
	spread_delay = 150,
	spread_delay_deviation = 60,
	maximum_spread_count = 50,
	initial_lifetime = 60,
	
	flame_alpha = 0.35,
	flame_alpha_deviation = 0.05,
	
	emissions_per_tick = 0.005,
	
	add_fuel_cooldown = 10,
	increase_duration_cooldown = 10,
	increase_duration_by = 10,
	fade_in_duration = 30,
	fade_out_duration = 30,
	
	lifetime_increase_by = 10,
	lifetime_increase_cooldown = 10,
	delay_between_initial_flames = 10,
	burnt_patch_lifetime = 1800,
	
	on_fuel_added_action =
	{
		type = "direct",
		action_delivery =
		{
			type = "instant",
			target_effects =
			{
				{
					type = "create-trivial-smoke",
					smoke_name = "ei-acid-smoke-on-adding-fuel",
					-- speed = {-0.03, 0},
					-- speed_multiplier = 0.99,
					-- speed_multiplier_deviation = 1.1,
					offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
					speed_from_center = 0.01
				}
			}
		}
	},
	
	pictures = acidutil.create_acid_pictures({ blend_mode = "normal", animation_speed = 1, scale = 0.3, acid_tint = {r=1,g=1,b=1,a=1}}),
	
	smoke_source_pictures = 
	{
		{ 
			filename = "__base__/graphics/entity/fire-flame/fire-smoke-source-1.png",
			line_length = 8,
			width = 101,
			height = 138,
			frame_count = 31,
			axially_symmetrical = false,
			direction_count = 1,
			shift = {-0.109375, -1.1875},
			animation_speed = 0.5,
		tint = make_color(1, 0.5, 1, 0.75),
		},
		{ 
			filename = "__base__/graphics/entity/fire-flame/fire-smoke-source-2.png",
			line_length = 8,
			width = 99,
			height = 138,
			frame_count = 31,
			axially_symmetrical = false,
			direction_count = 1,
			shift = {-0.203125, -1.21875},
			animation_speed = 0.5,
		tint = make_color(1, 0.5, 1, 0.75),
		},
	},
	
	burnt_patch_pictures = acidutil.create_burnt_patch_pictures(),
	burnt_patch_alpha_default = 0.4,
	burnt_patch_alpha_variations = {
		-- { tile = "grass-1", alpha = 0.45 },
		-- { tile = "grass-2", alpha = 0.45 },
		-- { tile = "grass-3", alpha = 0.45 },
		-- { tile = "grass-4", alpha = 0.45 },
		-- { tile = "dry-dirt", alpha = 0.3 },
		-- { tile = "dirt-1", alpha = 0.3 },
		-- { tile = "dirt-2", alpha = 0.3 },
		-- { tile = "dirt-3", alpha = 0.3 },
		-- { tile = "dirt-4", alpha = 0.3 },
		-- { tile = "dirt-5", alpha = 0.3 },
		-- { tile = "dirt-6", alpha = 0.3 },
		-- { tile = "dirt-7", alpha = 0.3 },
		-- { tile = "sand-1", alpha = 0.24 },
		-- { tile = "sand-2", alpha = 0.24 },
		-- { tile = "sand-3", alpha = 0.24 },
		-- { tile = "red-desert-0", alpha = 0.28 },
		-- { tile = "red-desert-1", alpha = 0.28 },
		-- { tile = "red-desert-2", alpha = 0.28 },
		-- { tile = "red-desert-3", alpha = 0.28 },
		{ tile = "stone-path", alpha = 0.26 },
		{ tile = "concrete", alpha = 0.24 },
	},

	smoke =
	{
		{
			name = "ei-acid-smoke",
			deviation = {0.5, 0.5},
			frequency = 0.25 / 2,
			position = {0.0, -0.8},
			starting_vertical_speed = 0.05,
			starting_vertical_speed_deviation = 0.005,
			vertical_speed_slowdown = 0.99,
			starting_frame_deviation = 60,
			height = -0.5,
		}
	},

	light = {intensity = 1, size = 20},
	
	working_sound =
	{
		sound = { filename = "__base__/sound/furnace.ogg" },
		max_sounds_per_type = 3
	},
},
{
	type = "fire",
	name = "ei-acid-flame-small",
	flags = {"placeable-off-grid", "not-on-map"},
	duration = 180,
	fade_away_duration = 600,
	spread_duration = 600,
	start_scale = 0.10,
	end_scale = 0.3,
	color = {r=0, g=0.5, b=0.7, a=0.9},
	damage_per_tick = {amount = fire_small_damage_per_tick, type = "acid"},
	
	spawn_entity = "ei-acid-flame-on-tree",
	
	spread_delay = 300,
	spread_delay_deviation = 180,
	maximum_spread_count = 100,
	initial_lifetime = 120,
	
	flame_alpha = 0.35,
	flame_alpha_deviation = 0.05,
	
	emissions_per_tick = 0.005,
	
	add_fuel_cooldown = 10,
	increase_duration_cooldown = 10,
	increase_duration_by = 20,
	fade_in_duration = 30,
	fade_out_duration = 30,
	
	lifetime_increase_by = 20,
	lifetime_increase_cooldown = 10,
	delay_between_initial_flames = 10,
	burnt_patch_lifetime = 1800,
	
	on_fuel_added_action =
	{
		type = "direct",
		action_delivery =
		{
			type = "instant",
			target_effects =
			{
				{
					type = "create-trivial-smoke",
					smoke_name = "ei-acid-smoke-on-adding-fuel",
					-- speed = {-0.03, 0},
					-- speed_multiplier = 0.99,
					-- speed_multiplier_deviation = 1.1,
					offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
					speed_from_center = 0.01
				}
			}
		}
	}}})
	--Debuff animation on units
data:extend({
{
	type = "sticker",
	name = "ei-acid-sticker",
	flags = {"not-on-map"},
	
	animation = 
	{       
		filename = ei_graphics_3_path.."graphics/entities/acid-turret/acid-flame/acid-flame-01.png",
		line_length = 10,
		width = 84,
		height = 130,
		frame_count = 90,
		axially_symmetrical = false,
		direction_count = 1,
		blend_mode = "normal",
		animation_speed = 1,
		scale = 0.2,
		shift = math3d.vector2.mul({-0.078125, -1.8125}, 0.1),
	},
	
	duration_in_ticks = 15 * 60,
	target_movement_modifier = 0.6,
	damage_per_tick = { amount = acid_sticker_damage_per_tick , type = "acid" },
	spread_acid_entity = "e-acid-flame-on-tree",
	acid_spread_cooldown = 30,
	acid_spread_radius = 0.75,
}})

data:extend({
{
  type = "fire",
  name = "ei-acid-flame-on-tree",
  localised_name = {"entity-name.fire-flame"},
  flags = {"placeable-off-grid", "not-on-map"},
  hidden = true,
  damage_per_tick = {amount = 35 / 60, type = "acid"},

  spawn_entity = "ei-acid-flame-on-tree",
  maximum_spread_count = 100,

  spread_delay = 300,
  spread_delay_deviation = 180,
  flame_alpha = 0.44,
  flame_alpha_deviation = 0.05,

  tree_dying_factor = 0.8,
  emissions_per_second = { pollution = 0.005 },

  fade_in_duration = 120,
  fade_out_duration = 100,
  smoke_fade_in_duration = 100,
  smoke_fade_out_duration = 130,
  delay_between_initial_flames = 20,

  small_tree_acid_pictures = acidutil.create_small_tree_flame_animations(),

  pictures = acidutil.create_acid_pictures({}),

  smoke_source_pictures = acidutil.create_fire_smoke_source_pictures(0.6, util.premul_color{1,1,1, 0.75}),

  smoke =
  {
    {
      name = "fire-smoke-without-glow",
      deviation = {0.5, 0.5},
      frequency = 0.25 / 2,
      position = {0.0, -0.8},
      starting_vertical_speed = 0.008,
      starting_vertical_speed_deviation = 0.05,
      starting_frame_deviation = 60,
      height = -0.5
    }
  },

  light = util.table.deepcopy(acidutil.default_fire_light),

  working_sound =
  {
    sound = {category = "weapon", filename = "__base__/sound/fire-1.ogg"},
    max_sounds_per_type = 2
  }
}})

local indicator_pictures =
{
  north = util.draw_as_glow
  {
    filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-led-indicator-north.png",
    width = 10,
    height = 18,
    shift = util.by_pixel(7, 20),
    scale = 0.5
  },
  east = util.draw_as_glow
  {
    filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-led-indicator-east.png",
    width = 18,
    height = 8,
    shift = util.by_pixel(-33, -5),
    scale = 0.5
  },
  south = util.draw_as_glow
  {
    filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-led-indicator-south.png",
    width = 8,
    height = 18,
    shift = util.by_pixel(-8, -45),
    scale = 0.5
  },
  west = util.draw_as_glow
  {
    filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-led-indicator-west.png",
    width = 20,
    height = 10,
    shift = util.by_pixel(32, -20),
    scale = 0.5
  }
}

data:extend({
  {
    type = "fluid-turret",
	  name = "ei-acidthrower-turret",
	  icon = ei_graphics_3_path.."graphics/items/acid-turret.png",
	  icon_size = 32,
    flags = {"placeable-player", "player-creation"},
	  minable = {mining_time = 0.5, result = "ei-acidthrower-turret"},
    fast_replaceable_group = "flamethrower-turret",
    max_health = 1400,
    corpse = "flamethrower-turret-remnants",
    collision_box = {{-0.7, -1.2 }, {0.7, 1.2}},
    selection_box = {{-1, -1.5 }, {1, 1.5}},
    rotation_speed = 0.015,
    preparing_speed = 0.08,
    open_sound = {filename = "__base__/sound/open-close/turret-open.ogg", volume = 0.6},
    close_sound = {filename = "__base__/sound/open-close/turret-close.ogg", volume = 0.6},
    preparing_sound = sounds.flamethrower_turret_activate,
    folding_sound = sounds.flamethrower_turret_deactivate,
    folding_speed = 0.08,
    attacking_speed = 1,
    ending_attack_speed = 0.2,
    dying_explosion = "medium-explosion",
    turret_base_has_direction = true,
    resistances =
    {
      {
        type = "fire",
        percent = 25
      },
	  {
        type = "acid",
        percent = 100
      }
    },

    fluid_box =
    {
      production_type = "none", -- FluidTurret has its own logic
      secondary_draw_order = 0,
      render_layer = "lower-object",
      --pipe_picture = acidutil.flamethrower_turret_pipepictures(),
      pipe_covers = pipecoverspictures(),
      volume = 100,
      pipe_connections =
      {
        { direction = defines.direction.west, position = {-0.5, 1.0} },
        { direction = defines.direction.east, position = {0.5, 1.0} }
      }
    },
    fluid_buffer_size = 100,
    fluid_buffer_input_flow = 250 / 60 / 5, -- 5s to fill the buffer
    activation_buffer_ratio = 0.25,

    circuit_connector = circuit_connector_definitions["flamethrower-turret"],
    circuit_wire_max_distance = default_circuit_wire_max_distance,

    folded_animation = acidutil.flamethrower_turret_extension({frame_count = 1, line_length = 1}),

    preparing_animation = acidutil.flamethrower_turret_extension({}),
    prepared_animation = acidutil.flamethrower_prepared_animation(),
    attacking_animation = acidutil.flamethrower_prepared_animation({attacking = true}),
    ending_attack_animation = acidutil.flamethrower_prepared_animation({attacking = true}),

    folding_animation = acidutil.flamethrower_turret_extension({ run_mode = "backward" }),

    not_enough_fuel_indicator_picture = indicator_pictures,
    not_enough_fuel_indicator_light = {intensity = 0.2, size = 1.5, color = {1, 0, 0}},
    enough_fuel_indicator_picture = acidutil.foreach(util.table.deepcopy(indicator_pictures), function (tab) tab.x = tab.width end),
    enough_fuel_indicator_light = {intensity = 0.2, size = 1.5, color = {0, 1, 0}},
    out_of_ammo_alert_icon =
    {
      filename = "__core__/graphics/icons/alerts/fuel-icon-red.png",
      priority = "extra-high-no-scale",
      width = 64,
      height = 64,
      flags = {"icon"}
    },

    gun_animation_render_layer = "object",
    gun_animation_secondary_draw_order = 1,
    graphics_set =
    {
      base_visualisation =
      {
        render_layer = "lower-object-above-shadow",
        secondary_draw_order = 1,
        animation =
        {
          north =
          {
            layers =
            {
              -- diffuse
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-north.png",
                line_length = 1,
                width = 158,
                height = 196,
                shift = util.by_pixel(-1, 13),
                scale = 0.5
              },
              -- mask
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-north-mask.png",
                flags = { "mask" },
                line_length = 1,
                width = 74,
                height = 70,
                shift = util.by_pixel(-1, 33),
                apply_runtime_tint = true,
                scale = 0.5
              },
              -- shadow
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-north-shadow.png",
                draw_as_shadow = true,
                line_length = 1,
                width = 134,
                height = 152,
                shift = util.by_pixel(3, 15),
                scale = 0.5
              }
            }
          },
          east =
          {
            layers =
            {
              -- diffuse
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-east.png",
                line_length = 1,
                width = 216,
                height = 146,
                shift = util.by_pixel(-6, 3),
                scale = 0.5
              },
              -- mask
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-east-mask.png",
                flags = { "mask" },
                apply_runtime_tint = true,
                line_length = 1,
                width = 66,
                height = 82,
                shift = util.by_pixel(-33, 1),
                scale = 0.5
              },
              -- shadow
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-east-shadow.png",
                draw_as_shadow = true,
                line_length = 1,
                width = 144,
                height = 86,
                shift = util.by_pixel(14, 9),
                scale = 0.5
              }
            }
          },
          south =
          {
            layers =
            {
              -- diffuse
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-south.png",
                line_length = 1,
                width = 128,
                height = 166,
                shift = util.by_pixel(0, -8),
                scale = 0.5
              },
              -- mask
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-south-mask.png",
                flags = { "mask" },
                apply_runtime_tint = true,
                line_length = 1,
                width = 72,
                height = 72,
                shift = util.by_pixel(0, -31),
                scale = 0.5
              },
              -- shadow
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-south-shadow.png",
                draw_as_shadow = true,
                line_length = 1,
                width = 134,
                height = 98,
                shift = util.by_pixel(3, 9),
                scale = 0.5
              }
            }

          },
          west =
          {
            layers =
            {
              -- diffuse
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-west.png",
                line_length = 1,
                width = 208,
                height = 144,
                shift = util.by_pixel(7, -1),
                scale = 0.5
              },
              -- mask
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-west-mask.png",
                flags = { "mask" },
                apply_runtime_tint = true,
                line_length = 1,
                width = 64,
                height = 74,
                shift = util.by_pixel(32, -1),
                scale = 0.5
              },
              -- shadow
              {
                filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-base-west-shadow.png",
                draw_as_shadow = true,
                line_length = 1,
                width = 206,
                height = 88,
                shift = util.by_pixel(15, 4),
                scale = 0.5
              }
            }
          }
        }
      }
    },

    muzzle_animation = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/flamethrower-turret/flamethrower-turret-muzzle-fire.png",
      line_length = 8,
      width = 16,
      height = 30,
      frame_count = 32,
      blend_mode = "additive",
      scale = 0.45,
      shift = {0.015625 * 0.5, -0.546875 * 0.5 + 0.05},
	  tint = make_color(0, 0.5, 0.7, 0.9),
    },
    muzzle_light = {size = 1.5, intensity = 0.2, color = {1, 0.5, 0}},

    folded_muzzle_animation_shift          = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 1,  orientation_count = 4, progress = 0, layers = {[0] = "object"} },
    preparing_muzzle_animation_shift       = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 15, orientation_count = 4, layers = {[0] = "object"} },
    prepared_muzzle_animation_shift        = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 1, orientation_count =  64, progress = 1},
    --starting_attack_muzzle_animation_shift = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 1,  orientation_count = 64, progress = 1},
    attacking_muzzle_animation_shift       = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 1,  orientation_count = 64, progress = 1},
    ending_attack_muzzle_animation_shift   = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 1,  orientation_count = 64, progress = 1},
    folding_muzzle_animation_shift         = acidutil.flamethrower_turret_preparing_muzzle_animation{ frame_count = 15, orientation_count = 4, run_mode = "backward", layers = {[0] = "object"}},

    prepare_range = 40,
    shoot_in_prepare_state = false,
    attack_parameters =
    {
      type = "stream",
      cooldown = 4,
      range = 38,
      min_range = 9,

      turn_range = (1.0 / 3.0)*0.8,
      fire_penalty = 15,

      lead_target_for_projectile_speed = 0.45, -- same as flamer after vanilla_patches buff

	  fluids = { 
    {type = "ei-acidic-water", damage_modifier = 0.2},
		{type = "sulfuric-acid", damage_modifier = 1.0},
		{type = "ei-nitric-acid", damage_modifier = 1.25},
    {type = "ei-hydrofluoric-acid", damage_modifier = 1.35},
	},
      fluid_consumption = 1,

      gun_center_shift =
      {
        north = math3d.vector2.add(acidutil.gun_center_base, acidutil.turret_gun_shift.north),
        east = math3d.vector2.add(acidutil.gun_center_base, acidutil.turret_gun_shift.east),
        south = math3d.vector2.add(acidutil.gun_center_base, acidutil.turret_gun_shift.south),
        west = math3d.vector2.add(acidutil.gun_center_base, acidutil.turret_gun_shift.west)
      },
      gun_barrel_length = 0.4,

      ammo_category = "flamethrower",
      ammo_type =
      {
        action =
        {
          type = "direct",
          action_delivery =
          {
            type = "stream",
            stream = "ei-flamethrower-acid-stream",
            source_offset = {0.15, -0.5}
          }
        }
      },

      cyclic_sound =
      {
        begin_sound = sound_variations("__base__/sound/fight/flamethrower-turret-start", 3, 0.5),
        middle_sound = sound_variations("__base__/sound/fight/flamethrower-turret-mid", 3, 0.5),
        end_sound = sound_variations("__base__/sound/fight/flamethrower-turret-end", 3, 0.5)
      }
    },
    call_for_help_radius = 40
  }
})

--- ******************************************************************
--- ******************************************************************
--- ******************************************************************

local stream_sprites =
{
  spine_animation = util.draw_as_glow
  {
    filename = "__base__/graphics/entity/flamethrower-fire-stream/flamethrower-fire-stream-spine.png",
    blend_mode = "normal",
	  tint = {r=0.3,g=0.8,b=0.8,a=0.7},
    line_length = 6,
    width = 54,
    height = 26,
    frame_count = 36,
    animation_speed = 2,
    shift = {0, 0}
  },

  shadow =
  {
    filename = "__base__/graphics/entity/acid-projectile/projectile-shadow.png",
    line_length = 5,
    width = 28,
    height = 16,
    frame_count = 33,
    priority = "high",
    shift = {-0.09, 0.395}
  },

  particle = util.draw_as_glow
  {
    filename = "__base__/graphics/entity/flamethrower-fire-stream/flamethrower-explosion.png",
    priority = "extra-high",
    blend_mode = "normal",
    tint = {r=0.3,g=0.8,b=0.8,a=0.7},
    line_length = 6,
    width = 124,
    height = 108,
    frame_count = 36,
    scale = 0.666,
  }
}

data:extend(
{
  {
    type = "stream",
    name = "ei-flamethrower-acid-stream",
    flags = {"not-on-map"},
    hidden = true,
    --stream_light = {intensity = 1, size = 4},
    --ground_light = {intensity = 0.8, size = 4},
--[[
    smoke_sources =
    {
      {
        name = "ei-soft-acid-smoke",
        frequency = 0.001, --0.25, 0.05
        position = {0.0, 0}, -- -0.8},
        starting_frame_deviation = 60
      }
    },
    ]]
    particle_buffer_size = 120,
    particle_spawn_interval = 2,
    particle_spawn_timeout = 16,
    particle_vertical_acceleration = (0.005 * 0.60)*1.5,
    particle_horizontal_speed = (0.2* 0.75 * 1.5)*1.5,
    particle_horizontal_speed_deviation = (0.005 * 0.70)*1.5,
    particle_start_alpha = 1.0, --0.5/0.666
    particle_end_alpha = 0.19,
    particle_start_scale = 0.125,
    particle_end_scale = 1.75,
    particle_loop_frame_count = 3,
    particle_fade_out_threshold = 0.9,
    particle_loop_exit_threshold = 0.25,
    action =
    {
      {
        type = "area",
        radius = 3,
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "create-sticker",
              sticker = "ei-acid-sticker",
              show_in_tooltip = true
            },
            {
              type = "damage",
              damage = { amount = 3.3, type = "acid" },
              apply_damage_to_trees = false
            }
          }
        }
      },
      --[[{
        type = "direct",
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "create-fire",
              entity_name = "ei-acid-flame",
              show_in_tooltip = true
            }
          }
        }
      }]]
    },
    spine_animation = stream_sprites.spine_animation,
    shadow = stream_sprites.shadow,
    particle = stream_sprites.particle
  }
}
)

data:extend(
{
  --handheld yet unused
  {
    type = "stream",
    name = "ei-handheld-flamethrower-acid-stream",
    flags = {"not-on-map"},
    hidden = true,

    smoke_sources =
    {
      {
        name = "soft-fire-smoke",
        frequency = 0.05, --0.25,
        position = {0.0, 0}, -- -0.8},
        starting_frame_deviation = 60
      }
    },

    --stream_light = {intensity = 1, size = 4 * 0.8},
    --ground_light = {intensity = 0.8, size = 4 * 0.8},

    particle_buffer_size = 65,
    particle_spawn_interval = 2,
    particle_spawn_timeout = 2,
    particle_vertical_acceleration = 0.005 * 0.6,
    particle_horizontal_speed = 0.25,
    particle_horizontal_speed_deviation = 0.0035,
    particle_start_alpha = 1.0,
    particle_end_alpha = 0.65,
    particle_start_scale = 0.35,
    particle_end_scale = 0.7,
    particle_loop_frame_count = 3,
    particle_fade_out_threshold = 0.9,
    particle_loop_exit_threshold = 0.25,
    action =
    {
      {
        type = "area",
        radius = 2.5,
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "create-sticker",
              sticker = "ei-acid-sticker",
              show_in_tooltip = true
            },
            {
              type = "damage",
              damage = { amount = 2, type = "acid" },
              apply_damage_to_trees = false
            }
          }
        }
      },
      {
        type = "direct",
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "create-fire",
              entity_name = "ei-acid-flame",
              show_in_tooltip = true,
              initial_ground_flame_count = 2
            }
          }
        }
      }
    },
    spine_animation = stream_sprites.spine_animation,
    shadow = stream_sprites.shadow,
    particle = stream_sprites.particle
  },
  {
    type = "stream",
    name = "ei-tank-flamethrower-acid-stream",
    flags = {"not-on-map"},
    hidden = true,

    smoke_sources =
    {
      {
        name = "soft-fire-smoke",
        frequency = 0.05, --0.25,
        position = {0.0, 0}, -- -0.8},
        starting_frame_deviation = 60
      }
    },

    --stream_light = {intensity = 1, size = 4 * 0.8},
    --ground_light = {intensity = 0.8, size = 4 * 0.8},

    particle_buffer_size = 65,
    particle_spawn_interval = 2,
    particle_spawn_timeout = 2,
    particle_vertical_acceleration = (0.005 * 0.3)*1.5,
    particle_horizontal_speed = (0.45)*1.5,
    particle_horizontal_speed_deviation = (0.0035)*1.5,
    particle_start_alpha = 1.0,
    particle_end_alpha = 0.65,
    particle_start_scale = 0.35,
    particle_end_scale = 0.7,
    particle_loop_frame_count = 3,
    particle_fade_out_threshold = 0.9,
    particle_loop_exit_threshold = 0.25,
    action =
    {
      {
        type = "area",
        radius = 4,
        action_delivery =
        {
          type = "instant",
          target_effects =
          {
            {
              type = "damage",
              damage = { amount = 7, type = "acid" },
              apply_damage_to_trees = true
            }
          }
        }
      }
    },
    spine_animation = stream_sprites.spine_animation,
    shadow = stream_sprites.shadow,
    particle = stream_sprites.particle
  },})

  local function acidsmoke(opts)
	return {
		type = "trivial-smoke",
		name = opts.name,
		flags = {"not-on-map"},
		duration = opts.duration or 180,
		fade_in_duration = opts.fade_in_duration or 0,
		fade_away_duration = opts.fade_away_duration or 600,
		spread_duration = opts.spread_duration or 600,
		start_scale = opts.start_scale or 0.20,
		end_scale = opts.end_scale or 1.0,
		color = opts.color,
		cyclic = true,
		affected_by_wind = opts.affected_by_wind or true,
		animation = opts.animation or
		{
			width = 152,
			height = 120,
			line_length = 5,
			frame_count = 60,
			axially_symmetrical = false,
			direction_count = 1,
			shift = {-0.53125, -0.4375},
			priority = "high",
			flags = { "always-compressed" },
			animation_speed = 0.25,
			filename = "__base__/graphics/entity/smoke/smoke.png"
		},
		glow_animation = opts.glow_animation,
		glow_fade_away_duration = opts.glow_fade_away_duration,
		vertical_speed_slowdown = opts.vertical_speed_slowdown
	}
	end

data:extend({
	acidsmoke
{
	name = "ei-acid-smoke", 
	color = {r=0.4, g=0.4, b=0.4, a=0.25},
	start_scale = 0.5,
	end_scale = 0.15,
	duration = 60,
	spread_delay = 120,
	fade_away_duration = 15,
	fade_in_duration = 30,
	animation = 
	{
		filename = "__base__/graphics/entity/fire-smoke/fire-smoke.png",
		flags = { "always-compressed" },
		line_length = 8,
		width = 253,
		height = 210,
		frame_count = 60,
		axially_symmetrical = false,
		direction_count = 1,
		shift = {-0.265625, -0.09375},
		priority = "high",
		animation_speed = 0.25,
	},
	glow_animation = 
	{
		filename = "__base__/graphics/entity/fire-smoke/fire-smoke-glow.png",
		flags = { "always-compressed" },
		blend_mode = "additive",
		line_length = 8,
		width = 253,
		height = 152,
		frame_count = 60,
		axially_symmetrical = false,
		direction_count = 1,
		shift = {-0.265625, 0.8125},
		priority = "high",
		animation_speed = 0.25,
	},
	glow_fade_away_duration = 70
},

acidsmoke
{
	name = "ei-acid-smoke-without-glow", 
	color = make_color(1,1,1, 0.25),
	start_scale = 0.5,
	end_scale = 0.1,
	duration = 60,
	spread_delay = 120,
	fade_away_duration = 15,
	fade_in_duration = 30,
	animation = 
	{
		filename = "__base__/graphics/entity/fire-smoke/fire-smoke.png",
		flags = { "always-compressed" },
		line_length = 8,
		width = 253,
		height = 210,
		frame_count = 60,
		axially_symmetrical = false,
		direction_count = 1,
		shift = {-0.265625, -0.09375},
		priority = "high",
		animation_speed = 0.25,
	},
},

acidsmoke
{
	name = "ei-soft-acid-smoke", 
	color = make_color(0.3, 0.3, 0.3, 0.1),
	start_scale = 0.45,
	end_scale = 0.25,
	duration = 60,
	spread_delay = 120,
	fade_away_duration = 15,
  fade_in_duration = 30,
}, 

acidsmoke
{
	name = "ei-acid-smoke-on-adding-fuel", 
	start_scale = 0.6,
	end_scale = 0.2,
	duration = 60,
	spread_delay = 120,
	fade_away_duration = 15,
	fade_in_duration = 30,
	animation = 
	{
		 filename = "__base__/graphics/entity/fire-smoke/fire-smoke.png",
		 flags = { "always-compressed" },
     scale = 0.25,
		 line_length = 8,
		 width = 253,
		 height = 210,
		 frame_count = 60,
		 axially_symmetrical = false,
		 direction_count = 1,
		 shift = {-0.265625, -0.09375},
		 priority = "high",
		 animation_speed = 0.25,
	}
},
	})
	
	
  --item
  data:extend({
	{
		type = "item",
		name = "ei-acidthrower-turret",
		icon = ei_graphics_3_path.."graphics/items/acid-turret.png",
		icon_size = 32,
		subgroup = "defensive-structure",
		order = "b[turret]-c[flamethrower-turret]-a[acidthrower-turret]",
		place_result = "ei-acidthrower-turret",
		stack_size = 50,
	},
--recipe
	{
		type = "recipe",
		name = "ei-acidthrower-turret",
		enabled = false,
		energy_required = 10,
    order = "b[turret]-a1[laser-turret]",
		ingredients =
		{
			{ type = "item", name = "steel-plate", amount = 30 },
			{ type = "item", name = "ei-iron-mechanical-parts", amount = 15 },
			{ type = "item", name = "pipe", amount = 10 },
			{ type = "item", name = "engine-unit", amount = 5 }
		},
		results = {{type="item", name="ei-acidthrower-turret", amount=1}},
	},
  {
    name = "ei-acidthrower-turret",
    type = "technology",
    icon = ei_graphics_3_path.."graphics/tech/acid-turret.png",
    icon_size = 128,
    prerequisites = {"sulfur-processing","flammables","engine-unit"},
    effects = {
        {
            type = "unlock-recipe",
            recipe = "ei-acidthrower-turret"
        }
    },
    unit = {
        count = 100,
        ingredients = ei_data.science["steam-age"],
        time = 20
    },
    age = "steam-age",
},
  })

table.insert(data.raw.technology["refined-flammables-1"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.2})
table.insert(data.raw.technology["refined-flammables-2"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.2})
table.insert(data.raw.technology["refined-flammables-3"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.2})
table.insert(data.raw.technology["refined-flammables-4"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.3})
table.insert(data.raw.technology["refined-flammables-5"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.3})
table.insert(data.raw.technology["refined-flammables-6"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.4})
table.insert(data.raw.technology["refined-flammables-7"].effects,{type = "turret-attack", turret_id = "ei-acidthrower-turret",modifier = 0.2})