require("teslas_legacy.config.settings")
local sounds = require("__base__/prototypes/entity/sounds")

local settings = get_settings()

data:extend({
  {  
    type = "electric-turret",
    name = "tl-basic-tesla-coil",
    icon = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/basic/icons/tesla-turret.png",
    icon_size = 64, 
    icon_mipmaps = 4,
    flags = 
    {
      "placeable-player", 
      "player-creation"
    },
    minable = 
    {
      mining_time = 0.5, 
      result = "tl-basic-tesla-coil"
    },
    
    max_health = 400,
    corpse = "big-remnants",
    dying_explosion = "laser-turret-explosion",
    collision_box = {{-0.7, -0.7 }, {0.7, 0.7}},
    selection_box = {{-1, -1 }, {1, 1}},
	
    rotation_speed = 60,
    preparing_speed = 0.08,
    folding_speed = 0.08,
    alert_when_attacking = true,
	
    hide_resistances = false,
    resistances = {
      { type = "acid",     decrease = 5,  percent = 40 },
      { type = "electric", decrease = 0,  percent = 95 },
    },
	
    energy_source =
    {
      --TODO check if the values are balanced
      type = "electric",
      buffer_capacity = "601kJ",
      input_flow_limit = "9600kW",
      drain = "12kW",
      usage_priority = "primary-input"
    },
    folded_animation =
    {
        layers =
        {
          {
            filename = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/basic/entity/tesla-turret/tesla-turret.png",
            priority = "low",
            line_length = 1,
            width = 150,
            height = 200,
            frame_count = 1,
            direction_count = 1,
            shift = util.by_pixel(0, -20),
            animation_speed = 8,
            scale = 0.5
          },
          {
            filename = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/basic/entity/tesla-turret/tesla-turret-mask.png",
            priority = "low",
            line_length = 1,
            width = 150,
            height = 200,
            frame_count = 1,
            apply_runtime_tint = true,
            direction_count = 1,
            shift = util.by_pixel(0, -20),
            scale = 0.5
          },
          {
            filename = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/basic/entity/tesla-turret/tesla-turret-shadow.png",
            priority = "low",
            line_length = 1,
            width = 89,
            height = 58,
            frame_count = 1,
            draw_as_shadow = true,
            direction_count = 1,
            shift = util.by_pixel(24, -3.5),
            scale = 1
          }
        }
    },
    base_picture = 
    {
      layers =
      {
        {
          filename = "__base__/graphics/entity/gun-turret/gun-turret-base.png",
          priority = "high",
          width = 76,
          height = 60,
          axially_symmetrical = false,
          direction_count = 1,
          frame_count = 1,
          shift = util.by_pixel(1, -1),
          hr_version =
          {
            filename = "__base__/graphics/entity/gun-turret/hr-gun-turret-base.png",
            priority = "high",
            width = 150,
            height = 118,
            axially_symmetrical = false,
            direction_count = 1,
            frame_count = 1,
            shift = util.by_pixel(0.5, -1),
            scale = 0.5
          }
        },
        {
          filename = "__base__/graphics/entity/gun-turret/gun-turret-base-mask.png",
          flags = { "mask", "low-object" },
          line_length = 1,
          width = 62,
          height = 52,
          axially_symmetrical = false,
          direction_count = 1,
          frame_count = 1,
          shift = util.by_pixel(0, -4),
          apply_runtime_tint = true,
          hr_version =
          {
            filename = "__base__/graphics/entity/gun-turret/hr-gun-turret-base-mask.png",
            flags = { "mask", "low-object" },
            line_length = 1,
            width = 122,
            height = 102,
            axially_symmetrical = false,
            direction_count = 1,
            frame_count = 1,
            shift = util.by_pixel(0, -4.5),
            apply_runtime_tint = true,
            scale = 0.5
          }
        }
      }
    },
    vehicle_impact_sound = sounds.generic_impact,
  
    attack_parameters =
    {
        type = "beam",
        cooldown = 60 / settings.turret.basic.fire_rate,
        range = settings.turret.basic.range.max,
        min_range = settings.turret.basic.range.min,
        damage_modifier = 1,
        ammo_category = "tl-basic-tesla-coil-turret-category",
        ammo_type =
        {
            energy_consumption = "200J",
            action =
            {
                type = "area",
                show_in_tooltip = true,
                radius = 2,
                force = "enemy",
                action_delivery =
                {
                    type = "beam",
                    beam = get_beam_name_turret(),
                    max_length = settings.turret.basic.range.max,
                    duration = 15,
                    source_offset = {0, -2}
                }
            }
        }
    },
  
    call_for_help_radius = 40,
    water_reflection =
    {
      pictures =
      {
        filename = "__base__/graphics/entity/gun-turret/gun-turret-reflection.png",
        priority = "extra-high",
        width = 20,
        height = 32,
        shift = util.by_pixel(0, 40),
        variation_count = 1,
        scale = 5
      },
      rotate = false,
      orientation_to_variation = false
    },
    graphics_set = {}
  }
});

