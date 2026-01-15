local icon_dir = ei_graphics_3_path.."graphics/items/"
local sprite_dir = ei_graphics_3_path.."graphics/entities/thermal-furnace/"
--From Heated Fabrication by @MrLumme
ei_lib = require("lib/lib")
ei_data = require("lib/data")
data:extend({
    {
    type = "corpse",
    name = "ei-thermal-furnace-remnants",
    icon = sprite_dir.."remnants/thermal-furnace-remnants.png",
    flags = {"placeable-neutral", "building-direction-8-way", "not-on-map"},
    hidden_in_factoriopedia = true,
    subgroup = "smelting-machine-remnants",
    order = "a-a-a",
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    tile_width = 3,
    tile_height = 3,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    expires = false,
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation =
    {
      filename = "__base__/graphics/entity/electric-furnace/remnants/electric-furnace-remnants.png",
      line_length = 1,
      width = 454,
      height = 448,
      direction_count = 1,
      shift = util.by_pixel(-3.25, 7.25),
      scale = 0.5
    }
  },
{
    type = "furnace",
    name = "ei-thermal-furnace",
    icon = icon_dir.."thermal-furnace.png",
    flags = {"placeable-neutral", "placeable-player", "player-creation","not-rotatable"},
    minable = {mining_time = 0.2, result = "ei-thermal-furnace"},
    fast_replaceable_group = "furnace",
    circuit_wire_max_distance = furnace_circuit_wire_max_distance,
    circuit_connector = circuit_connector_definitions["electric-furnace"],
    max_health = 350,
    corpse = "ei-thermal-furnace-remnants",
    dying_explosion = "electric-furnace-explosion",
    resistances =
    {
      {
        type = "fire",
        percent = 80
      }
    },
    collision_box = {{-1.7, -1.2}, {1.7, 1.2}},
    selection_box = {{-2, -1.5}, {2, 1.5}},
    damaged_trigger_effect = hit_effects.entity(),
    module_slots = 3,
    icon_draw_specification = {shift = {0, -0.1}},
    icons_positioning =
    {
      {inventory_index = defines.inventory.furnace_modules, shift = {0, 0.8}}
    },
    allowed_effects = {"consumption", "speed", "productivity", "pollution", "quality"},
    crafting_categories = {"smelting"},
    result_inventory_size = 2,
    crafting_speed = 4.5,
    energy_usage = "1MW",
    source_inventory_size = 1,
    energy_source =
    {
      type = 'heat',
      max_temperature = 900,
      min_working_temperature = 500,
      specific_heat = ei_data.high_specific_heat,
      minimum_glow_temperature = 550,
      max_transfer = '1GW',
      emissions_per_minute = { pollution = 0.5 },
        heat_picture = {
            sheets = {
                {
                    frames = 1,
                    filename = sprite_dir .. "thermal-furnace-heat-pipe-heated.png",
                    width = 300,
                    height = 316,
                    scale = 0.5,
                    shift = {-0.15, -0.60}
                },
                {
                    draw_as_light = true,
                    frames = 1,
                    filename = sprite_dir .. "thermal-furnace-heat-pipe-heated.png",
                    width = 300,
                    height = 316,
                    scale = 0.5,
                    shift = {-0.15, -0.61}
                },
                {
                    frames = 1,
                    filename = sprite_dir .. "thermal-furnace-heated.png",
                    width = 300,
                    height = 316,
                    scale = 0.5,
                    shift = {-0.15, -0.60}
                },
                {
                    draw_as_light = true,
                    frames = 1,
                    filename = sprite_dir .. "thermal-furnace-heated.png",
                    width = 300,
                    height = 316,
                    scale = 0.5,
                    shift = {-0.15, -0.60}
                }
            }
        },
        pipe_covers = {
            north = {
                frames = 1,
                filename = sprite_dir .. "thermal-furnace-heat-con.png",
                width = 64,
                height = 64,
                x = 0,
                scale = 0.5,
                shift = util.by_pixel(-0.5, 0)
            },
            east = {
                frames = 1,
                filename = sprite_dir .. "thermal-furnace-heat-con.png",
                width = 64,
                height = 64,
                x = 64,
                scale = 0.5,
                shift = util.by_pixel(0, 0)
            },
            south = {
                frames = 1,
                filename = sprite_dir .. "thermal-furnace-heat-con.png",
                width = 64,
                height = 64,
                x = 128,
                scale = 0.5,
                shift = util.by_pixel(0, 1.0)
            },
            west = {
                frames = 1,
                filename = sprite_dir .. "thermal-furnace-heat-con.png",
                width = 64,
                height = 64,
                x = 192,
                scale = 0.5,
                shift = util.by_pixel(-0.5, 0)
            }
        },
        heat_pipe_covers = {
            north = {
                layers = {
                    {
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 0,
                        scale = 0.5,
                        shift = util.by_pixel(-0.5, 0)
                    },
                    {
                        draw_as_light = true;
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 0,
                        scale = 0.5,
                        shift = util.by_pixel(-0.5, 0)
                    }
                }
            },
            east = {
                layers = {
                    {
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 64,
                        scale = 0.5,
                        shift = util.by_pixel(0, 0)
                    },
                    {
                        draw_as_light = true;
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 0,
                        scale = 0.5,
                        shift = util.by_pixel(0, 0)
                    }
                }
            },
            south = {
                layers = {
                    {
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 128,
                        scale = 0.5,
                        shift = util.by_pixel(0, 1.0)
                    },
                    {
                        draw_as_light = true;
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 0,
                        scale = 0.5,
                        shift = util.by_pixel(0, 1.0)
                    }
                }
            },
            west = {
                layers = {
                    {
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 192,
                        scale = 0.5,
                        shift = util.by_pixel(-0.5, 0)
                    },
                    {
                        draw_as_light = true;
                        frames = 1,
                        filename = sprite_dir .. "thermal-furnace-heat-con-heated.png",
                        width = 64,
                        height = 64,
                        x = 0,
                        scale = 0.5,
                        shift = util.by_pixel(-0.5, 0)
                    }
                }
            }
        },
        connections = {
            {direction = 0, position = {-1.5, -1}},
            {direction = 12, position = {-1.5, -1}},
            {direction = 0, position = {1.5, -1}},
            {direction = 4, position = {1.5, -1}},
            {direction = 8, position = {-1.5, 1}},
            {direction = 12, position = {-1.5, 1}}
        }
    },

    impact_category = "metal",
    open_sound = sounds.electric_large_open,
    close_sound = sounds.electric_large_close,
    working_sound =
    {
      sound =
      {
        filename = "__base__/sound/electric-furnace.ogg",
        volume = 0.85,
        modifiers = volume_multiplier("main-menu", 4.2),
        advanced_volume_control = {attenuation = "exponential"},
        audible_distance_modifier = 0.7,
      },
      max_sounds_per_prototype = 4,
      fade_in_ticks = 4,
      fade_out_ticks = 20
    },
    graphics_set = {
	animation = {
		layers = {
			{
				filename = sprite_dir .. "thermal-furnace-heat-pipe.png",
				frame_count = 1,
				priority = "high",
				scale = 0.5,
				width = 300,
				height = 316,
				shift = {-0.15, -0.61}
			},
			{
				filename = sprite_dir .. "thermal-furnace.png",
				frame_count = 1,
				priority = "high",
				scale = 0.5,
				width = 300,
				height = 316,
				shift = {-0.15, -0.60}
			},
			{
				draw_as_shadow = true,
				filename = sprite_dir .. "thermal-furnace-shadow.png",
				frame_count = 1,
				priority = "high",
				scale = 0.5,
				width = 227,
				height = 171,
				shift = {0.775, 0.1484375}
			}
		}
	},
	working_visualisations = {
		{
			animation = {
				filename = sprite_dir .. "thermal-furnace-working.png",
				frame_count = 8,
				line_length = 4,
				animation_speed = 0.1,
				width = 65,
				height = 33,
				scale = 0.5,
				shift = {0.35, 0.87}
			}
		},
		{
			draw_as_sprite = false,
			draw_as_light = true,
			animation = {
				filename = sprite_dir .. "thermal-furnace-light.png",
				frame_count = 1,
				line_length = 1,
				blend_mode = "additive",
				width = 300,
				height = 316,
				scale = 0.5,
				shift = {-0.2, -0.57}
			}
		},
		{
			draw_as_sprite = false,
			draw_as_light = true,
			animation = {
				filename = sprite_dir .. "thermal-furnace-ground-light.png",
				frame_count = 1,
				line_length = 1,
				blend_mode = "additive",
				width = 166,
				height = 124,
				scale = 0.5,
				shift = {0.35, 2.1}
			}
		}
	},
	frozen_patch = {
		sheet = {
			frames = 1,
			filename = sprite_dir .. "thermal-furnace-frozen.png",
			frame_count = 1,
			priority = "high",
			scale = 0.5,
			width = 300,
			height = 316,
			shift = {-0.15, -0.60}
		}
	},
      water_reflection =
      {
        pictures =
        {
          filename = "__base__/graphics/entity/electric-furnace/electric-furnace-reflection.png",
          priority = "extra-high",
          width = 24,
          height = 24,
          shift = util.by_pixel(5, 40),
          variation_count = 1,
          scale = 5
        },
        rotate = false,
        orientation_to_variation = false
      }
    }
  }
})

local heat_furnace_item = table.deepcopy(ei_lib.raw["item"]["electric-furnace"])
heat_furnace_item.name = "ei-thermal-furnace"
heat_furnace_item.place_result = "ei-thermal-furnace"
heat_furnace_item.icon = icon_dir .. "thermal-furnace.png"

local heat_furnace_recipe = table.deepcopy(ei_lib.raw["recipe"]["electric-furnace"])
heat_furnace_recipe.name = "ei-thermal-furnace"
heat_furnace_recipe.ingredients = {
  {type="item",name="electronic-circuit", amount=10},
  {type="item",name="ei-heat-steel-furnace", amount=1},
  {type="item",name="ei-steel-beam",amount=5},
  {type="item",name="ei-steel-mechanical-parts",amount=10},
  {type="item",name="ei-copper-mechanical-parts",amount=5},
  {type="item",name="heat-pipe",amount=20},
}
heat_furnace_recipe.results = {{type="item", name="ei-thermal-furnace", amount=1}}
heat_furnace_recipe.main_product = "ei-thermal-furnace"

data:extend({heat_furnace_item, heat_furnace_recipe,
{
		type = "technology",
		name = "ei-thermal-furnace",
		icon_size = 256,
		icon_mipmaps = 4,
		icon = ei_graphics_3_path.."graphics/tech/thermal-furnace.png",
		effects = {
			{type = "unlock-recipe", recipe = "ei-thermal-furnace"}
		},
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",

		prerequisites = {"nuclear-power", "advanced-material-processing-2"},
	}
})
