ei_lib = require("lib/lib")

data:extend({
{
    type = "furnace",
    name = "ei-heat-steel-furnace",
    icon = "__base__/graphics/icons/steel-furnace.png",
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.2, result = "ei-heat-steel-furnace"},
    fast_replaceable_group = "furnace",
    circuit_wire_max_distance = furnace_circuit_wire_max_distance,
    circuit_connector = circuit_connector_definitions["steel-furnace"],
    max_health = 300,
    corpse = "steel-furnace-remnants",
    dying_explosion = "steel-furnace-explosion",
    impact_category = "metal",
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,
    allowed_effects = {"speed", "consumption", "pollution"},
    effect_receiver = {uses_module_effects = false, uses_beacon_effects = false, uses_surface_effects = true},
    icon_draw_specification = {scale = 0.66, shift = {0, -0.1}},
    working_sound =
    {
      sound =
      {
        filename = "__base__/sound/steel-furnace.ogg",
        volume = 0.32,
        advanced_volume_control = {attenuation = "exponential"},
        audible_distance_modifier = 0.5,
      },
      max_sounds_per_prototype = 4,
      fade_in_ticks = 4,
      fade_out_ticks = 20
    },
    resistances =
    {
      {
        type = "fire",
        percent = 100
      }
    },
    collision_box = {{-0.7, -0.7}, {0.7, 0.7}},
    selection_box = {{-0.8, -1}, {0.8, 1}},
    damaged_trigger_effect = hit_effects.entity(),
    crafting_categories = {"smelting"},
    result_inventory_size = 1,
    energy_usage = "260kW",
    crafting_speed = 2,
    source_inventory_size = 1,
    energy_source =
    {
      type = 'heat',
      max_temperature = 275,
      min_working_temperature = 185,
      specific_heat = ei_data.specific_heat,
      max_transfer = '10MW',
      emissions_per_minute = { pollution = 1.25 },
      connections = {
        {
          position = {-0.5, -0.5},
          direction = defines.direction.north
        },
        {
          position = {-0.5, -0.5},
          direction = defines.direction.west
        },
        {
          position = {0.5, -0.5},
          direction = defines.direction.north
        },
        {
          position = {0.5, -0.5},
          direction = defines.direction.east
        },
        {
          position = {-0.5, 0.5},
          direction = defines.direction.south
        },
        {
          position = {-0.5, 0.5},
          direction = defines.direction.west
        },
        {
          position = {0.5, 0.5},
          direction = defines.direction.south
        },
        {
          position = {0.5, 0.5},
          direction = defines.direction.east
        },
      },
    light_flicker = {
      color = {r = 1, g = 0.4, b = 0.1}, -- fiery orange-red glow
      minimum_intensity = 0.75,
      maximum_intensity = 0.95,
    },

    smoke = {
      {
        name = "smoke", -- lighter, faster dissipating smoke
        frequency = 4,       -- much lower frequency
        position = {0.7, -1.2},
        starting_vertical_speed = 0.12,
        starting_frame_deviation = 60,
      }
    },

    },
    graphics_set =
    {
      animation =
      {
        layers =
        {
          {
            filename = "__base__/graphics/entity/steel-furnace/steel-furnace.png",
            priority = "high",
            width = 171,
            height = 174,
            shift = util.by_pixel(-1.25, 2),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/steel-furnace/steel-furnace-shadow.png",
            priority = "high",
            width = 277,
            height = 85,
            draw_as_shadow = true,
            shift = util.by_pixel(39.25, 11.25),
            scale = 0.5
          }
        }
      },
      working_visualisations =
      {
        {
          fadeout = true,
          effect = "flicker",
          animation =
          {
            filename = "__base__/graphics/entity/steel-furnace/steel-furnace-fire.png",
            priority = "high",
            line_length = 8,
            width = 57,
            height = 81,
            frame_count = 48,
            draw_as_glow = true,
            shift = util.by_pixel(-0.75, 5.75),
            scale = 0.5
          },
        },
        {
          fadeout = true,
          effect = "flicker",
          animation =
          {
            filename = "__base__/graphics/entity/steel-furnace/steel-furnace-glow.png",
            priority = "high",
            width = 60,
            height = 43,
            draw_as_glow = true,
            shift = {0.03125, 0.640625},
            blend_mode = "additive"
          }
        },
        {
          fadeout = true,
          effect = "flicker",
          animation =
          {
            filename = "__base__/graphics/entity/steel-furnace/steel-furnace-working.png",
            priority = "high",
            line_length = 1,
            width = 128,
            height = 150,
            draw_as_glow = true,
            shift = util.by_pixel(0, -5),
            blend_mode = "additive",
            scale = 0.5,
          }
        },
        {
          fadeout = true,
          effect = "flicker",
          animation =
          {
            filename = "__base__/graphics/entity/steel-furnace/steel-furnace-ground-light.png",
            priority = "high",
            line_length = 1,
            width = 152,
            height = 126,
            draw_as_light = true,
            shift = util.by_pixel(1, 48),
            blend_mode = "additive",
            scale = 0.5,
          },
        },
      },
      water_reflection =
      {
        pictures =
        {
          filename = "__base__/graphics/entity/steel-furnace/steel-furnace-reflection.png",
          priority = "extra-high",
          width = 20,
          height = 24,
          shift = util.by_pixel(0, 45),
          variation_count = 1,
          scale = 5
        },
        rotate = false,
        orientation_to_variation = false
      }
    }
  }
})

local heat_furnace_item = table.deepcopy(ei_lib.raw["item"]["steel-furnace"])
heat_furnace_item.name = "ei-heat-steel-furnace"
heat_furnace_item.place_result = "ei-heat-steel-furnace"

local heat_furnace_recipe = table.deepcopy(ei_lib.raw["recipe"]["steel-furnace"])
heat_furnace_recipe.name = "ei-heat-steel-furnace"
heat_furnace_recipe.ingredients = {
  {type="item",name="ei-steel-beam", amount=4},
  {type="item",name="stone-brick", amount=10},
  {type="item",name="stone-furnace", amount=1},
  {type="item",name="ei-basic-heat-pipe",amount=1}
}
heat_furnace_recipe.results = {{type="item", name="ei-heat-steel-furnace", amount=1}}
heat_furnace_recipe.main_product = "ei-heat-steel-furnace"

data:extend({heat_furnace_item, heat_furnace_recipe})
ei_lib.add_unlock_recipe("advanced-material-processing", "ei-heat-steel-furnace")