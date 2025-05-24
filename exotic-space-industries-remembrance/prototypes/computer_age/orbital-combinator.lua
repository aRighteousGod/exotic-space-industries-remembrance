require("__base__.prototypes.entity.combinator-pictures")
require ("util")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")

local remnants =
{
  {
    type = "corpse",
    se_allow_in_space = true,
    name = "ei-orbital-combinator-remnants",
    icon = ei_graphics_3_path.."graphics/orbital-combinator/icon.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"placeable-neutral", "not-on-map"},
    subgroup = "circuit-network-remnants",
    order = "a-d-a",
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    tile_width = 1,
    tile_height = 1,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = make_rotated_animation_variations_from_sheet (1,
    {
      filename = ei_graphics_3_path.."graphics/orbital-combinator/remnants.png",
      line_length = 1,
      width = 60,
      height = 56,
      frame_count = 1,
      variation_count = 1,
      axially_symmetrical = false,
      direction_count = 4,
      shift = util.by_pixel(0, 0),
    })
  },
}

for k, remnant in pairs (remnants) do
  if not remnant.localised_name then
    local name = remnant.name
    if name:find("%-remnants") then
      remnant.localised_name = {"remnant-name", {"entity-name."..name:gsub("%-remnants", "")}}
    end
  end
end

data:extend(remnants)



function OrbitalCombinator(combinator)
  combinator.sprites =
    make_4way_animation_from_spritesheet({ layers =
      {
        {
          filename = ei_graphics_3_path.."graphics/orbital-combinator/entity.png",
          width = 58,
          height = 52,
          frame_count = 1,
          shift = util.by_pixel(0, 5),
        },
        {
          filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
          width = 50,
          height = 34,
          frame_count = 1,
          shift = util.by_pixel(9, 6),
          draw_as_shadow = true,
        }
      }
    })
  combinator.activity_led_sprites =
  {
    north = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-N.png",
      width = 8,
      height = 6,
      frame_count = 1,
      shift = util.by_pixel(9, -12),
    },
    east = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-E.png",
      width = 8,
      height = 8,
      frame_count = 1,
      shift = util.by_pixel(8, 0),
    },
    south = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-S.png",
      width = 8,
      height = 8,
      frame_count = 1,
      shift = util.by_pixel(-9, 2),
    },
    west = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-W.png",
      width = 8,
      height = 8,
      frame_count = 1,
      shift = util.by_pixel(-7, -15),
    }
  }
  combinator.circuit_wire_connection_points =
  {
    {
      shadow =
      {
        red = util.by_pixel(7, -6),
        green = util.by_pixel(23, -6)
      },
      wire =
      {
        red = util.by_pixel(-8.5, -17.5),
        green = util.by_pixel(7, -17.5)
      }
    },
    {
      shadow =
      {
        red = util.by_pixel(32, -5),
        green = util.by_pixel(32, 8)
      },
      wire =
      {
        red = util.by_pixel(16, -16.5),
        green = util.by_pixel(16, -3.5)
      }
    },
    {
      shadow =
      {
        red = util.by_pixel(25, 20),
        green = util.by_pixel(9, 20)
      },
      wire =
      {
        red = util.by_pixel(9, 7.5),
        green = util.by_pixel(-6.5, 7.5)
      }
    },
    {
      shadow =
      {
        red = util.by_pixel(1, 11),
        green = util.by_pixel(1, -2)
      },
      wire =
      {
        red = util.by_pixel(-15, -0.5),
        green = util.by_pixel(-15, -13.5)
      }
    }
  }
  return combinator
end


data:extend
{
  OrbitalCombinator
  {
    type = "constant-combinator",
    se_allow_in_space = true,
    name = "ei-orbital-combinator",
    icon = ei_graphics_3_path.."graphics/orbital-combinator/icon.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 0.1, result = "ei-orbital-combinator"},
    max_health = 120,
    corpse = "ei-orbital-combinator-remnants",
    dying_explosion = "constant-combinator-explosion",
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    damaged_trigger_effect = hit_effects.entity(),
    fast_replaceable_group = "ei-orbital-combinator",

    item_slot_count = 10000,

    vehicle_impact_sound = sounds.generic_impact,
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,

    activity_led_light =
    {
      intensity = 0,
      size = 1,
      color = {r = 1.0, g = 1.0, b = 1.0}
    },

    activity_led_light_offsets =
    {
      {0.296875, -0.40625},
      {0.25, -0.03125},
      {-0.296875, -0.078125},
      {-0.21875, -0.46875}
    },

    circuit_wire_max_distance = 100
  }
}


data:extend
{
  {
    type = "item",
    se_allow_in_space = true,
    name = "ei-orbital-combinator",
    icon = ei_graphics_3_path.."graphics/orbital-combinator/icon.png",
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "circuit-network",
    place_result="ei-orbital-combinator",
    order = "c[combinators]-c[constant-combinator]",
    stack_size= 50
  }
}



data:extend
{
  {
    type = "recipe",
    name = "ei-orbital-combinator",
    enabled = false,
    ingredients =
    {
      {type="item", name="copper-cable", amount=5},
      {type="item", name="iron-plate", amount=5},
      {type="item", name="radar", amount=1},
      {type="item", name="constant-combinator", amount=1}
    },
    results = {{type="item", name="ei-orbital-combinator", amount=1}},
    energy_required = 30,
  }
}



