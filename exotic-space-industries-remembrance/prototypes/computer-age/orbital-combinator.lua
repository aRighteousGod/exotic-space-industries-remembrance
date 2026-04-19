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
    icon = ei_graphics_3_path.."graphics/icons/orbital-request-combinator.png",
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
      filename = ei_graphics_3_path.."graphics/entities/orbital-request-combinator/orbital-request-combinator-remnants.png",
      line_length = 1,
      width = 118,
      height = 112,
      frame_count = 1,
      variation_count = 1,
      axially_symmetrical = false,
      direction_count = 4,
      shift = util.by_pixel(0, 0),
      scale = 0.5,
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
          filename = ei_graphics_3_path.."graphics/entities/orbital-request-combinator/orbital-request-combinator.png",
          width = 114,
          height = 102,
          frame_count = 1,
          shift = util.by_pixel(0, 5),
          scale = 0.5,
        },
        {
          filename = ei_graphics_3_path.."graphics/entities/orbital-request-combinator/orbital-request-combinator-shadow.png",
          width = 98,
          height = 66,
          frame_count = 1,
          shift = util.by_pixel(8.5, 5.5),
          scale = 0.5,
          draw_as_shadow = true,
        }
      }
    })
  combinator.activity_led_sprites =
  {
    north = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-N.png",
      width = 14,
      height = 12,
      frame_count = 1,
      shift = util.by_pixel(9, -11.5),
      scale = 0.5,
    },
    east = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-E.png",
      width = 14,
      height = 14,
      frame_count = 1,
      shift = util.by_pixel(7.5, -0.5),
      scale = 0.5,
    },
    south = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-S.png",
      width = 14,
      height = 16,
      frame_count = 1,
      shift = util.by_pixel(-9, 2.5),
      scale = 0.5,
    },
    west = util.draw_as_glow
    {
      filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-W.png",
      width = 14,
      height = 16,
      frame_count = 1,
      shift = util.by_pixel(-7, -15),
      scale = 0.5,
    }
  }
  combinator.circuit_wire_connection_points =
  {
    -- north
    {
      shadow =
      {
        red = util.by_pixel(7, -6),
        green = util.by_pixel(23, -6)
      },
      wire =
      {
        red = util.by_pixel(-8.5, -14.5),
        green = util.by_pixel(7, -14.5)
      }
    },
    -- east
    {
      shadow =
      {
        red = util.by_pixel(32, -5),
        green = util.by_pixel(32, 8)
      },
      wire =
      {
        red = util.by_pixel(15, -13.5),
        green = util.by_pixel(17.5, -0.5)
      }
    },
    -- south
    {
      shadow =
      {
        red = util.by_pixel(25, 20),
        green = util.by_pixel(9, 20)
      },
      wire =
      {
        red = util.by_pixel(9, 9.5),
        green = util.by_pixel(-6, 9.5)
      }
    },
    -- west
    {
      shadow =
      {
        red = util.by_pixel(1, 11),
        green = util.by_pixel(1, -2)
      },
      wire =
      {
        red = util.by_pixel(-14, 3.5),
        green = util.by_pixel(-16, -10.5)
      }
    }
  }
  return combinator
end

local orbital_combinator_power_sensor = table.deepcopy(data.raw["lamp"]["small-lamp"])
orbital_combinator_power_sensor.name = "ei-orbital-combinator-power-sensor"
orbital_combinator_power_sensor.localised_name = {"entity-name.ei-orbital-combinator"}
orbital_combinator_power_sensor.localised_description = {"item-description.ei-orbital-combinator"}
orbital_combinator_power_sensor.icon = ei_graphics_3_path.."graphics/icons/orbital-request-combinator.png"
orbital_combinator_power_sensor.icon_size = 64
orbital_combinator_power_sensor.icon_mipmaps = 4
orbital_combinator_power_sensor.flags = {
  "not-blueprintable",
  "not-deconstructable",
  "not-on-map",
  "not-flammable",
  "not-repairable",
  "not-upgradable",
  "not-selectable-in-game",
  "placeable-off-grid",
  "hide-alt-info",
}
orbital_combinator_power_sensor.hidden = true
orbital_combinator_power_sensor.selectable_in_game = false
orbital_combinator_power_sensor.minable = nil
orbital_combinator_power_sensor.max_health = 1
orbital_combinator_power_sensor.collision_box = {{0, 0}, {0, 0}}
orbital_combinator_power_sensor.selection_box = {{0, 0}, {0, 0}}
orbital_combinator_power_sensor.collision_mask = {layers = {}}
orbital_combinator_power_sensor.always_on = true
orbital_combinator_power_sensor.energy_source = {
  type = "electric",
  usage_priority = "lamp",
}
orbital_combinator_power_sensor.energy_usage_per_tick = "750kW"
orbital_combinator_power_sensor.energy_usage = nil
orbital_combinator_power_sensor.light = {
  intensity = 0,
  size = 0,
  color = {r = 1, g = 1, b = 1},
}
orbital_combinator_power_sensor.picture_on = util.empty_sprite()
orbital_combinator_power_sensor.picture_off = util.empty_sprite()
orbital_combinator_power_sensor.circuit_wire_max_distance = 0

data:extend
{
  orbital_combinator_power_sensor,
  OrbitalCombinator
  {
    type = "constant-combinator",
    se_allow_in_space = true,
    name = "ei-orbital-combinator",
    icon = ei_graphics_3_path.."graphics/icons/orbital-request-combinator.png",
    icon_size = 64, icon_mipmaps = 4,
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 0.1, result = "ei-orbital-combinator"},
    max_health = 120,
    corpse = "ei-orbital-combinator-remnants",
    dying_explosion = "constant-combinator-explosion",
    selection_priority = 255,
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
      color = {r = 1.0, g = 0.5, b = 0.0}
    },

    activity_led_light_offsets =
    {
      {0.296875, -0.40625},
      {0.25, -0.03125},
      {-0.296875, -0.078125},
      {-0.21875, -0.46875}
    },

    circuit_wire_max_distance = 100
  },
  {
    type = "virtual-signal",
    name = "ei-orbital-overflow",
    icons = {
      {
        icon = ei_graphics_3_path.."graphics/icons/orbital-request-combinator.png",
        icon_size = 64,
      },
      {
        icon = ei_graphics_other_path.."overlay_1.png",
        icon_size = 64,
        tint = {r = 1, g = 0.45, b = 0.2, a = 0.95},
      },
    },
    order = "ei-orbital-a",
  }
}


data:extend
{
  {
    type = "item",
    se_allow_in_space = true,
    name = "ei-orbital-combinator",
    icon = ei_graphics_3_path.."graphics/icons/orbital-request-combinator.png",
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



