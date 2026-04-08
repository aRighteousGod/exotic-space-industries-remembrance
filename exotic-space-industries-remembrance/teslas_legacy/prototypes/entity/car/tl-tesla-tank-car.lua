local hit_effects = require ("__base__/prototypes/entity/hit-effects")
local sounds = require("__base__/prototypes/entity/sounds.lua")
local movement_triggers = require("__base__.prototypes.entity.movement-triggers")

local tesla_only = 
{
  "tl-tesla-tank-gun-item"
}

local default_tesla = 
{
  "tl-tesla-tank-gun-item",
  "tank-machine-gun",
  "tank-flamethrower"
}

data:extend({
  {
    type = "car",
    name = "tl-tesla-tank",
    icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/icons/Teslatank.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = 
    {
        "placeable-neutral", 
        "player-creation", 
        "placeable-off-grid", 
        "not-flammable"
    },
    minable = 
    {
      mining_time = 0.5, 
      result = "tl-tesla-tank"
    },
    mined_sound = {filename = "__core__/sound/deconstruct-large.ogg",volume = 0.8},
    max_health = 2000,
    corpse = "tank-remnants",
    dying_explosion = "tank-explosion",
    alert_icon_shift = util.by_pixel(0, -13),
    immune_to_tree_impacts = true,
    immune_to_rock_impacts = true,
    energy_per_hit_point = 0.5,
    allow_remote_driving = true,
    equipment_grid = "medium-equipment-grid",
    trash_inventory_size = 20,
    hide_resistances = false,
    resistances =
    {
      {
        type = "fire",
        decrease = 15,
        percent = 60
      },
      {
        type = "physical",
        decrease = 15,
        percent = 60
      },
      {
        type = "impact",
        decrease = 50,
        percent = 80
      },
      {
        type = "explosion",
        decrease = 15,
        percent = 70
      },
      {
        type = "acid",
        decrease = 0,
        percent = 70
      },
      {
        type = "electric",
        decrease = 30,
        percent = 95
      }
    },
    collision_box = {{-1.3, -1.3}, {1.3, 1.3}},
    selection_box = {{-1.3, -1.3}, {1.3, 1.3}},
    damaged_trigger_effect = hit_effects.entity(),
    drawing_box = {{-1.8, -1.8}, {1.8, 1.5}},
    effectivity = 0.9,
    braking_power = "800kW",
    energy_source =
    {
      type = "burner",
      fuel_categories = {"chemical"},
      effectivity = 1,
      fuel_inventory_size = 2,
      smoke =
      {
        {
          name = "tank-smoke",
          deviation = {0.25, 0.25},
          frequency = 50,
          position = {-0.8, 1.0},
          starting_frame = 0,
          starting_frame_deviation = 60
        },
        {
          name = "tank-smoke",
          deviation = {0.25, 0.25},
          frequency = 50,
          position = {0.8, 1.0},
          starting_frame = 0,
          starting_frame_deviation = 60
        }
      }
    },        
    consumption = "600kW",
    terrain_friction_modifier = 0.2,
    friction = 0.002,
    light =
    {
      {
        type = "oriented",
        minimum_darkness = 0.3,
        picture =
        {
          filename = "__core__/graphics/light-cone.png",
          priority = "extra-high",
          flags = { "light" },
          scale = 2,
          width = 200,
          height = 200
        },
        shift = {-0.5,-14},
        size = 2,
        intensity = 0.8,
        color = {r = 1.0, g = 1.0, b = 0.8},
        source_orientation_offset = 0
      },
      {
        type = "oriented",
        minimum_darkness = 0.3,
        picture =
        {
          filename = "__core__/graphics/light-cone.png",
          priority = "extra-high",
          flags = { "light" },
          scale = 2,
          width = 200,
          height = 200
        },
        shift = {0.5,-14},
        size = 2,
        intensity = 0.8,
        color = {r = 1.0, g = 1.0, b = 0.8},
        source_orientation_offset = 0
      }
    },
    light_animation =
    {
      priority = "low",
      width = 140,
      height = 140,
      frame_count = 2,
      direction_count = 64,
      shift = util.by_pixel(0,0),
      animation_speed = 8,
      max_advance = 1,
      stripes =
      {
        {
         filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-light-1.png",
         width_in_frames = 2,
         height_in_frames = 16
        },
        {
         filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-light-2.png",
         width_in_frames = 2,
         height_in_frames = 16
        },
        {
         filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-light-3.png",
         width_in_frames = 2,
         height_in_frames = 16
        },
        {
         filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-light-4.png",
         width_in_frames = 2,
         height_in_frames = 16
        }
      },
      hr_version =
      {
        priority = "low",
        width = 280,
        height = 280,
        frame_count = 2,
        direction_count = 64,
        shift = util.by_pixel(0,0),
        animation_speed = 8,
        max_advance = 1,
        stripes =
        {
          {
           filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-light-1.png",
           width_in_frames = 2,
           height_in_frames = 16
          },
          {
           filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-light-2.png",
           width_in_frames = 2,
           height_in_frames = 16
          },
          {
           filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-light-3.png",
           width_in_frames = 2,
           height_in_frames = 16
          },
          {
           filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-light-4.png",
           width_in_frames = 2,
           height_in_frames = 16
          }
        },
        scale = 0.5
      }
    },
	
    animation =
    {
      layers =
      {
        {
          priority = "low",
          width = 140,
          height = 140,
          frame_count = 2,
          direction_count = 64,
          shift = util.by_pixel(0,0),
          animation_speed = 8,
          max_advance = 1,
          stripes =
          {
            {
             filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-1.png",
             width_in_frames = 2,
             height_in_frames = 16
            },
            {
             filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-2.png",
             width_in_frames = 2,
             height_in_frames = 16
            },
            {
             filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-3.png",
             width_in_frames = 2,
             height_in_frames = 16
            },
            {
             filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-4.png",
             width_in_frames = 2,
             height_in_frames = 16
            }
          },
          hr_version =
          {
            priority = "low",
            width = 280,
            height = 280,
            frame_count = 2,
            direction_count = 64,
            shift = util.by_pixel(0,0),
            animation_speed = 8,
            max_advance = 1,
            stripes =
            {
              {
               filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-1.png",
               width_in_frames = 2,
               height_in_frames = 16
              },
              {
               filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-2.png",
               width_in_frames = 2,
               height_in_frames = 16
              },
              {
               filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-3.png",
               width_in_frames = 2,
               height_in_frames = 16
              },
              {
               filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-4.png",
               width_in_frames = 2,
               height_in_frames = 16
              }
            },
            scale = 0.5
          }
        },
        {
          priority = "low",
          width = 140,
          height = 140,
          frame_count = 2,
          apply_runtime_tint = true,
          direction_count = 64,
          shift = util.by_pixel(0,0),
          max_advance = 1,
          line_length = 2,
          stripes = 
          {
            {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-mask-1.png",
              width_in_frames = 2,
              height_in_frames = 16
            },
            {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-mask-2.png",
              width_in_frames = 2,
              height_in_frames = 16
            },
            {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-mask-3.png",
              width_in_frames = 2,
              height_in_frames = 16
            },
            {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-mask-4.png",
              width_in_frames = 2,
              height_in_frames = 16
            }
          },
          hr_version =
          {
            priority = "low",
            width = 280,
            height = 280,
            frame_count = 2,
            apply_runtime_tint = true,
            direction_count = 64,
            shift = util.by_pixel(0,0),
            max_advance = 1,
            line_length = 2,
            stripes = 
            {
              {
                filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-mask-1.png",
                width_in_frames = 2,
                height_in_frames = 16
               },
               {
                filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-mask-2.png",
                width_in_frames = 2,
                height_in_frames = 16
               },
               {
                filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-mask-3.png",
                width_in_frames = 2,
                height_in_frames = 16
               },
               {
                filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-mask-4.png",
                width_in_frames = 2,
                height_in_frames = 16
               }             
            },
            scale = 0.5
          }
        },
        {
          priority = "low",
          width = 168,
          height = 130,
          frame_count = 2,
          draw_as_shadow = true,
          direction_count = 64,
          shift = util.by_pixel(26,0),
          max_advance = 1,
          stripes = util.multiplystripes(2,
          {
           {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-shadow-1.png",
            width_in_frames = 1,
            height_in_frames = 16
           },
           {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-shadow-2.png",
            width_in_frames = 1,
            height_in_frames = 16
           },
           {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-shadow-3.png",
            width_in_frames = 1,
            height_in_frames = 16
           },
           {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-base-shadow-4.png",
            width_in_frames = 1,
            height_in_frames = 16
           }
          }),
          hr_version =
          {
            priority = "low",
            width = 336,
            height = 260,
            frame_count = 2,
            draw_as_shadow = true,
            direction_count = 64,
            shift = util.by_pixel(26,0),
            max_advance = 1,
            stripes = util.multiplystripes(2,
            {
             {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-shadow-1.png",
              width_in_frames = 1,
              height_in_frames = 16
             },
             {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-shadow-2.png",
              width_in_frames = 1,
              height_in_frames = 16
             },
             {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-shadow-3.png",
              width_in_frames = 1,
              height_in_frames = 16
             },
             {
              filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-base-shadow-4.png",
              width_in_frames = 1,
              height_in_frames = 16
             }
            }),
            scale = 0.5
          }
        }
      }
    },
    turret_animation =
    {
      layers =
      {
        {
          filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-turret.png",
          priority = "low",
          line_length = 8,
          width = 140,
          height = 140,
          frame_count = 1,
          direction_count = 64,
          shift = util.by_pixel(0,0),
          animation_speed = 8,
          hr_version =
          {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-turret.png",
            priority = "low",
            line_length = 8,
            width = 280,
            height = 280,
            frame_count = 1,
            direction_count = 64,            
            animation_speed = 8,
            scale = 0.5
          }
        },
        {
          filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-turret-mask.png",
          priority = "low",
          line_length = 8,
          width = 140,
          height = 140,
          frame_count = 1,
          apply_runtime_tint = true,
          direction_count = 64,
          shift = util.by_pixel(0,0),
          hr_version =
          {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-turret-mask.png",
            priority = "low",
            line_length = 8,
            width = 280,
            height = 280,
            frame_count = 1,
            apply_runtime_tint = true,
            direction_count = 64,            
            scale = 0.5
          }
        },
        {
          filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/lr-tank-turret-shadow.png",
          priority = "low",
          line_length = 8,
          width = 111,
          height = 81,
          frame_count = 1,
          draw_as_shadow = true,
          direction_count = 64,
          shift = util.by_pixel(0,0),
          hr_version =
          {
            filename = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/entity/Teslatank/hr-tank-turret-shadow.png",
            priority = "low",
            line_length = 8,
            width = 221,
            height = 162,
            frame_count = 1,
            draw_as_shadow = true,
            direction_count = 64, 
            shift = util.by_pixel(0,0),
            scale = 0.5
          }
        }
      }
    },
    turret_rotation_speed = 0.35 / 60,
    turret_return_timeout = 300,
    sound_no_fuel =
    {
      {
        filename = "__base__/sound/fight/tank-no-fuel-1.ogg",
        volume = 0.4
      }
    },
    sound_minimum_speed = 0.2,
    sound_scaling_ratio = 0.8,
    impact_category = "metal-large",
    impact_speed_to_volume_ratio = 5.0,
    -- TODO sound section differ from the original tank, maybe it is a problem?
    working_sound =
    {
      sound =
      {
        filename = "__base__/sound/fight/tank-engine.ogg",
        volume = 0.37
      },
      activate_sound =
      {
        filename = "__base__/sound/fight/tank-engine-start.ogg",
        volume = 0.37
      },
      deactivate_sound =
      {
        filename = "__base__/sound/fight/tank-engine-stop.ogg",
        volume = 0.37
      },
      match_speed_to_activity = true
    },
    stop_trigger_speed = 0.1,
    stop_trigger =
    {
      {
        type = "play-sound",
        sound =
        {
          {
            filename = "__base__/sound/fight/tank-brakes.ogg",
            volume = 0.3
          }
        }
      }
    },
    open_sound = { filename = "__base__/sound/fight/tank-door-open.ogg", volume=0.48 },
    close_sound = { filename = "__base__/sound/fight/tank-door-close.ogg", volume = 0.43 },
    rotation_speed = 0.0035,
    rotation_snap_angle = 0.01,
    tank_driving = true,
    weight = 20000,
    inventory_size = 80,
    track_particle_triggers = movement_triggers.tank,
    -- TODO guns = settings.startup["teslaguns"].value and tesla_only or default_tesla,
    guns = tesla_only,
    water_reflection = car_reflection(1.2)
  },
})

