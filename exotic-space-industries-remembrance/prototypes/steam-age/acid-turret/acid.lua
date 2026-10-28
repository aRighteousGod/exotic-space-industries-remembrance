--==============================================================================
-- ESIR FILE MAP
-- owns: acidthrower turret, native acid impact/sticker, item and research prototypes
-- loaded_by: prototypes/steam-age/steam-age.lua
-- cadence: data stage; native engine owns attack and corrosion lifecycles
--==============================================================================
-- blueprint: .codex/esir/blueprints/acidthrower-pressure-jet.md#contract
--Originally by @DarkNova
--Updated by @Beathoven
require "util"
ei_lib = require("lib/lib")
require ("circuit-connector-sprites")
local math3d = require "math3d"
local sounds = require("__base__.prototypes.entity.sounds")
local acid_sticker_damage_per_tick = 100 / 60
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

	--Debuff animation on units
data:extend({
{
	type = "sticker",
	name = "ei-acid-sticker",
	flags = {"not-on-map"},
	
	animation = 
	{       
		filename = "__base__/graphics/entity/acid-sticker/acid-sticker.png",
		line_length = 5,
		width = 30,
		height = 34,
		frame_count = 50,
		axially_symmetrical = false,
		direction_count = 1,
		blend_mode = "normal",
		animation_speed = 0.5,
		scale = 0.5,
		shift = util.by_pixel(1.5, 0),
		tint = {r = 0.58, g = 0.78, b = 0.22, a = 0.85},
	},
	
	duration_in_ticks = 15 * 60,
	target_movement_modifier = 0.6,
	damage_per_tick = { amount = acid_sticker_damage_per_tick , type = "acid" },
}})

local turret =
  {
    type = "fluid-turret",
	  name = "ei-acidthrower-turret",
	  icon = ei_graphics_6_path.."graphics/items/acid-turret.png",
	  icon_size = 128,
	  icon_mipmaps = 3,
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

    -- Authored body and pipes remain four-way; vanilla now also has diagonals.
    circuit_connector = {
        circuit_connector_definitions["flamethrower-turret"][1],
        circuit_connector_definitions["flamethrower-turret"][3],
        circuit_connector_definitions["flamethrower-turret"][5],
        circuit_connector_definitions["flamethrower-turret"][7],
    },
    circuit_wire_max_distance = default_circuit_wire_max_distance,

    out_of_ammo_alert_icon =
    {
      filename = "__core__/graphics/icons/alerts/fuel-icon-red.png",
      priority = "extra-high-no-scale",
      width = 64,
      height = 64,
      flags = {"icon"}
    },

    -- Revision-03 artwork and muzzle anchors are assigned before registration.
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

require("prototypes/steam-age/acid-turret/graphics")(turret)
data:extend{turret}

-- Native impact payload; liquid presentation is applied before final resolution.

data:extend(
{
  {
    type = "stream",
    name = "ei-flamethrower-acid-stream",
    flags = {"not-on-map"},
    hidden = true,
    --stream_light = {intensity = 1, size = 4},
    --ground_light = {intensity = 0.8, size = 4},
    particle_buffer_size = 120,
    particle_spawn_interval = 2,
    particle_spawn_timeout = 16,
    particle_vertical_acceleration = (0.005 * 0.60)*1.5,
    particle_horizontal_speed = (0.2* 0.75 * 1.5)*1.5,
    particle_horizontal_speed_deviation = (0.005 * 0.70)*1.5,
    particle_start_alpha = 1.0, --0.5/0.666
    particle_end_alpha = 0.19,
    particle_start_scale = 0.125,
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
    },
  }
}
)

require("prototypes/steam-age/acid-turret/pressure-jet")

  --item
  data:extend({
	{
		type = "item",
		name = "ei-acidthrower-turret",
		icon = ei_graphics_6_path.."graphics/items/acid-turret.png",
		icon_size = 128,
		icon_mipmaps = 3,
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
    icon = ei_graphics_6_path.."graphics/techs/acid-turret.png",
    icon_size = 256,
    prerequisites = {"sulfur-processing","flammables","engine"},
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
