-- this file contains the prototype definition for varios stuff from electricity age

local ei_data = require("lib/data")

--====================================================================================================
--PROTOTYPE DEFINITIONS
--====================================================================================================

--ITEMS
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-minigun",
        type = "gun",
        icon = ei_graphics_item_path.."minigun.png",
        icon_size = 128,
        stack_size = 1,
        subgroup = "gun",
        order = "a[basic-clips]-c[minigun]",
        attack_parameters = {
            ammo_category = "bullet",
            cooldown = 2,
            movement_slow_down_factor = 0.85,
            projectile_creation_distance = 1.125,
            range = 22,
            shell_particle = {
                center = {
                    0,
                    0.1
                },
                creation_distance = -0.5,
                direction_deviation = 0.1,
                name = "shell-particle",
                speed = 0.1,
                speed_deviation = 0.03,
                starting_frame_speed = 0.4,
                starting_frame_speed_deviation = 0.1
            },
            sound = {
                {
                    filename = "__base__/sound/fight/submachine-gunshot-1.ogg",
                    volume = 0.6
                },
                {
                    filename = "__base__/sound/fight/submachine-gunshot-2.ogg",
                    volume = 0.6
                },
                {
                    filename = "__base__/sound/fight/submachine-gunshot-3.ogg",
                    volume = 0.6
                }
            },
            type = "projectile"
          },
    },
    {
        name = "ei-insulated-wire",
        type = "item",
        icon = ei_graphics_item_path.."insulated-wire.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "a[copper-wire]-a[insulated-wire]",
    },
    {
        name = "ei-crushed-copper",
        type = "item",
        icon = ei_graphics_item_path.."crushed-copper.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "a2",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-copper.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-copper-1.png",
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-fluorite",
        type = "item",
        icon = ei_graphics_item_path.."fluorite.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-purified",
        order = "b-a",
    },
    {
        name = "ei-cpu",
        type = "item",
        icon = ei_graphics_item_path.."cpu.png",
        icon_size = 128,
        subgroup = "intermediate-product",
        order = "b5",
        stack_size = 50
    },

    {
      name = "ei-lead-ingot",
      type = "item",
      icon = ei_graphics_item_path.."lead-ingot.png",
      icon_size = 64,
      stack_size = 100,
      subgroup = "intermediate-product",
      order = "a5",
    },

    {
      name = "ei-gold-ingot",
      type = "item",
      icon = ei_graphics_item_path.."gold-ingot.png",
      icon_size = 64,
      stack_size = 100,
      subgroup = "intermediate-product",
      order = "a4",
  },

  {
      name = "ei-neodym-ingot",
      type = "item",
      icon = ei_graphics_item_path.."neodym-ingot.png",
      icon_size = 64,
      stack_size = 100,
      subgroup = "intermediate-product",
      order = "a6",
  },

    {
        name = "ei-electronic-parts",
        type = "item",
        icon = ei_graphics_item_path.."electronic-parts.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "b6",
        stack_size = 100
    },

    -- new materials
    {
        name = "ei-crushed-gold",
        type = "item",
        icon = ei_graphics_item_path.."crushed-gold.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "a4",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-gold.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-gold-1.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-gold-2.png",
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-crushed-sulfur",
        type = "item",
        icon = ei_graphics_item_path.."crushed-sulfur.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "a5",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-sulfur.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-sulfur-1.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-sulfur-2.png",
                scale = 0.25,
                size = 64
            },
        },
    },
    {
        name = "ei-gold-chunk",
        type = "item",
        icon = ei_graphics_item_path.."gold-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-d",
    },
    {
        name = "ei-sulfur-chunk",
        type = "item",
        icon = ei_graphics_item_path.."sulfur-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-f",
    },
    {
        name = "ei-lead-chunk",
        type = "item",
        icon = ei_graphics_item_path.."lead-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-e",
    },
    {
        name = "ei-neodym-chunk",
        type = "item",
        icon = ei_graphics_item_path.."neodym-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-e",
    },
    {
        name = "ei-coal-chunk",
        type = "item",
        icon = ei_graphics_item_path.."coal-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-c",
    },
    {
        name = "ei-iron-chunk",
        type = "item",
        icon = ei_graphics_item_path.."iron-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-a",
    },
    {
        name = "ei-copper-chunk",
        type = "item",
        icon = ei_graphics_item_path.."copper-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-b",
    },
    {
        name = "ei-uranium-chunk",
        type = "item",
        icon = ei_graphics_item_path.."uranium-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a-f",
    },
    {
        name = "ei-diesel-fuel-unit",
        type = "item",
        icon = ei_graphics_item_path.."diesel-fuel-unit.png",
        icon_size = 80,
        stack_size = 10,
        subgroup = "raw-material",
        order = "c[solid-fuel]-a[diesel-fuel-unit]",
        fuel_category = "ei-diesel-fuel",
        fuel_value = "20MJ",
        fuel_acceleration_multiplier = 1.0,
        fuel_top_speed_multiplier = 1.0,
    },
    {
        name = "ei-computer-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."computer-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a4",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."computer-age-tech.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."computer-age-tech_light.png",
                scale = 0.25
              }
            }
        },
    },
    {
        name = "ei-personal-solar-2",
        type = "item",
        icon = ei_graphics_item_path.."personal-solar-2.png",
        icon_size = 64,
        subgroup = "equipment",
        order = "a[energy-source]-b[personal-solar-panel]",
        stack_size = 20,
        place_as_equipment_result = "ei-personal-solar-2",
    },
    {
        name = "ei-personal-solar-2",
        type = "solar-panel-equipment",
        power = "70kW",
        categories = {"armor"},
        sprite = {
            filename = ei_graphics_other_path.."personal-solar-2.png",
            width = 64,
            height = 64,
            priority = "medium"
        },
        shape = {
            width = 1,
            height = 1,
            type = "full"
        },
        energy_source = {
            type = "electric",
            usage_priority = "primary-output"
        },
        take_result = "ei-personal-solar-2",
    }
})

--RECIPES
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-concrete-slag",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 10,
        ingredients = {
            {type = "item", name = "stone-brick", amount = 10},
            {type = "fluid", name = "water", amount = 100},
            {type = "item", name = "ei-slag", amount = 20},
        },
        results = {
            {type = "item", name = "concrete", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "concrete",
    },
    {
        name = "ei-minigun",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "submachine-gun", amount = 4},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 20},
            {type = "item", name = "electric-engine-unit", amount = 12},
        },
        results = {
            {type = "item", name = "ei-minigun", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-minigun",
    },
    {
        name = "ei-personal-solar-2",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type = "item", name = "ei-solar-panel-2", amount = 4},
            {type = "item", name = "steel-plate", amount = 6},
            {type = "item", name = "solar-panel-equipment", amount = 2},
        },
        results = {
            {type = "item", name = "ei-personal-solar-2", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-personal-solar-2",
    },
    {
        name = "ei-diesel-fuel-unit",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-diesel", amount = 100},
            {type = "item", name = "barrel", amount = 1},
        },
        results = {
            {type = "item", name = "ei-diesel-fuel-unit", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-diesel-fuel-unit",
    },
    {
        name = "ei-benzol-coal-gas",
        type = "recipe",
        category = "oil-processing",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-coal-gas", amount = 25},
        },
        results = {
            {type = "fluid", name = "ei-benzol", amount = 10},
            {type = "fluid", name = "petroleum-gas", amount = 10},
            {type = "fluid", name = "ei-residual-oil", amount = 5},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-benzol",
    },
    {
        name = "ei-plastic-benzol",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-benzol", amount = 10},
            {type = "fluid", name = "petroleum-gas", amount = 15},
        },
        results = {
            {type = "item", name = "plastic-bar", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "plastic-bar",
    },
    {
        name = "ei-insulated-wire",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type = "item", name = "copper-cable", amount = 2},
            {type = "item", name = "plastic-bar", amount = 1},
        },
        results = {
            {type = "item", name = "ei-insulated-wire", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-insulated-wire",
    },
    {
        name = "ei-desulfurize-kerosene",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-kerosene", amount = 20},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount = 5},
            {type = "fluid", name = "ei-diesel", amount = 15},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-diesel",
        subgroup = "fluid-recipes",
        order = "a[fluid-chemistry]-a[ei_desulfurize-kerosene]",
    },
    {
        name = "ei-acidic-water-sulfur",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "fluid", name = "ei-acidic-water", amount = 10},
        },
        results = {
            {type = "item", name = "sulfur", amount = 1},
            {type = "fluid", name = "water", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "sulfur",
    },
    {
        name = "ei-sulfur-acidic-water",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "sulfur", amount = 1},
            {type = "fluid", name = "water", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-acidic-water",
        subgroup = "fluid-recipes",
        order = "a[fluid-chemistry]-a[ei_sulfur-acidic-water]",
    },
    {
        name = "ei-kerosene-heavy-oil",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "heavy-oil", amount = 25},
            {type = "fluid", name = "steam", amount = 15},
            {type = "item", name = "ei-coke", amount = 1},
        },
        results = {
            {type = "fluid", name = "ei-kerosene", amount = 20},
            {type = "fluid", name = "ei-coal-gas", amount = 35},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-kerosene",
        subgroup = "fluid-recipes",
        order = "a[fluid-chemistry]-c[kerosene]",
    },
    {
        name = "ei-coal-gas-reforming",
        type = "recipe",
        category = "oil-processing",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-coal-gas", amount = 45},
            {type = "fluid", name = "steam", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-benzol", amount = 30},
            {type = "fluid", name = "petroleum-gas", amount = 15},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-benzol",
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-c[benzol]",
    },
    {
        name = "ei-benzol-petroleum",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-benzol", amount = 30},
        },
        results = {
            {type = "fluid", name = "petroleum-gas", amount = 15},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "petroleum-gas",
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-b[petroleum]",
    },
    {
        name = "ei-electric-engine-lube",
        type = "recipe",
        category = "advanced-crafting",
        energy_required = 6,
        ingredients = {
            {type = "fluid", name = "lubricant", amount = 10},
            {type = "item", name = "engine-unit", amount = 1},
            {type = "item", name = "copper-cable", amount = 4},
            {type = "item", name = "ei-iron-mechanical-parts", amount = 2},
        },
        results = {
            {type = "item", name = "electric-engine-unit", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icons = {
            {
                icon = ei_graphics_base_path.."electric-engine-unit.png",
            },
            {
                icon = ei_graphics_other_path.."lube_overlay.png",
            }
        },
    },
    {
        name = "ei-crushed-brick",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type="item", name="stone-brick", amount=1},
        },
        results = {
            {type = "item", name = "stone", amount = 1},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "stone",
    },
    {
        name = "ei-crushed-copper",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type="item", name="copper-plate", amount=1},
        },
        results = {
            {type = "item", name = "ei-crushed-copper", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-copper",
    },
    {
        name = "ei-kerosene-cracking",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type = "fluid", name = "ei-kerosene", amount = 40},
            {type = "fluid", name = "water", amount = 30},
        },
        results = {
            {type = "fluid", name = "light-oil", amount = 30},
        },
        always_show_made_in = true,
        enabled = false,
        icon_size = 64,
        icon = ei_graphics_other_path.."kerosene-cracking.png",
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-a[kerosene-cracking]",
    },
    {
        name = "ei-cpu",
        type = "recipe",
        category = "crafting",
        energy_required = 8,
        ingredients = {
            {type = "item", name = "ei-semiconductor", amount = 1},
            {type = "item", name = "advanced-circuit", amount = 2},
            {type = "item", name = "ei-crushed-gold", amount = 3},
        },
        results = {
            {type = "item", name = "ei-cpu", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-cpu",
    },
    {
        name = "ei-electronic-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 6,
        ingredients = {
            {type = "item", name = "ei-cpu", amount = 1},
            {type = "item", name = "advanced-circuit", amount = 4},
            {type = "item", name = "battery", amount = 3},
            {type = "item", name = "ei-insulated-wire", amount = 2},
        },
        results = {
            {type = "item", name = "ei-electronic-parts", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-electronic-parts",
    },
    {
        name = "ei-computer-age-tech",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 27,
        ingredients = {
            {type = "item", name = "ei-electronic-parts", amount = 1},
            {type = "item", name = "ei-energy-crystal", amount = 1},
            {type = "fluid", name = "lubricant", amount = 25},
        },
        results = {
            {type = "item", name = "ei-computer-age-tech", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-computer-age-tech",
    },
    {
        name = "ei-gold-ingot",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-gold-chunk", amount = 3},
        },
        results = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-gold-ingot",
    },
    {
        name = "ei-crushed-gold",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-gold", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-gold",
    },
    {
        name = "ei-crushed-gold-plate",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-gold", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-gold",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-lead-ingot",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-lead-chunk", amount = 3},
        },
        results = {
            {type = "item", name = "ei-lead-ingot", amount = 1},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-lead-ingot",
    },
    {
        name = "ei-neodym-ingot",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-neodym-chunk", amount = 3},
        },
        results = {
            {type = "item", name = "ei-neodym-ingot", amount = 1},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-neodym-ingot",
    },
    {
        name = "ei-iron-ingot-chunk-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-iron-chunk", amount = 3},
        },
        results = {
            {type = "item", name = "iron-plate", amount = 2},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "iron-plate",
    },
    {
        name = "ei-copper-ingot-chunk-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-copper-chunk", amount = 3},
        },
        results = {
            {type = "item", name = "copper-plate", amount = 2},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "copper-plate",
    },
    {
        name = "ei-coal-chunk-crushing",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-coal-chunk", amount = 1},
        },
        results = {
            {type = "item", name = "coal", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "coal",
    },
    {
        name = "ei-sulfur-chunk-crushing",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-sulfur-chunk", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-sulfur", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-sulfur",
    },
    {
        name = "ei-acidic-water-crushed-sulfur",
        type = "recipe",
        category = "chemistry",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "ei-crushed-sulfur", amount = 4},
            {type = "fluid", name = "water", amount = 40},
        },
        results = {
            {type = "fluid", name = "ei-acidic-water", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-acidic-water",
        subgroup = "fluid-recipes",
        order = "a[fluid-chemistry]-a[ei_crushed-sulfur-acidic-water]",
    },
    {
        name = "ei-drill-fluid",
        type = "recipe",
        category = "chemistry",
        energy_required = 8,
        ingredients = {
            {type = "item", name = "solid-fuel", amount = 5},
            {type = "fluid", name = "sulfuric-acid", amount = 20},
            {type = "fluid", name = "lubricant", amount = 10},
        },
        results = {
            {type = "fluid", name = "ei-drill-fluid", amount = 30},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-drill-fluid",
    },
    {
        name = "ei-lube-destilation",
        type = "recipe",
        category = "chemistry",
        energy_required = 4,
        ingredients = {
            {type = "fluid", name = "steam", amount = 5},
            {type = "fluid", name = "lubricant", amount = 20},
        },
        results = {
            {type = "fluid", name = "heavy-oil", amount = 15},
            {type = "item", name = "coal", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "heavy-oil",
        icon = ei_graphics_tech_path.."lube-extraction.png",
        icon_size = 64,
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-g[lube-extraction]",
    },
    {
        name = "ei-green-circuit-waver",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 10,
        ingredients = {
            {type = "fluid", name = "sulfuric-acid", amount = 10},
            {type = "item", name = "copper-cable", amount = 20},
            {type = "item", name = "iron-plate", amount = 10},
            {type = "item", name = "ei-semiconductor", amount = 1},
        },
        results = {
            {type = "item", name = "electronic-circuit", amount = 20},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "electronic-circuit",
        icon = ei_graphics_other_path.."green-circuit.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "e[electronic-circuit]-1",
    },
    {
        name = "ei-red-circuit-waver",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 18,
        ingredients = {
            {type = "fluid", name = "sulfuric-acid", amount = 10},
            {type = "item", name = "ei-insulated-wire", amount = 8},
            {type = "item", name = "electronic-circuit", amount = 6},
            {type = "item", name = "ei-semiconductor", amount = 1},
        },
        results = {
            {type = "item", name = "advanced-circuit", amount = 4},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "advanced-circuit",
        icon = ei_graphics_other_path.."red-circuit.png",
        icon_size = 64,
        subgroup = "intermediate-product",
        order = "f[advanced-circuit]-1",
    },
    {
        name = "ei-molten-glass",
        type = "recipe",
        category = "ei-arc-furnace",
        energy_required = 0.5,
        ingredients = {
            {type = "item", name = modprefix.."sand", amount = 60},
        },
        results = {
            {type = "fluid", name = "ei-molten-glass", amount = 25},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-molten-glass",
    },
    {
        name = "ei-cast-glass",
        type = "recipe",
        category = "ei-casting",
        energy_required = 0.5,
        ingredients = {
            {type = "fluid", name = "ei-molten-glass", amount = 5},
        },
        results = {
            {type = "item", name = "ei-glass", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-glass",
    },
})

--TECHS
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-electricity-power",
        type = "technology",
        icon = ei_graphics_tech_path.."electricity-power.png",
        icon_size = 350,
        prerequisites = {"electric-engine"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "steam-engine"
            },
            {
                type = "unlock-recipe",
                recipe = "inserter"
            },
            {
                type = "unlock-recipe",
                recipe = "long-handed-inserter"
            },
            {
                type = "unlock-recipe",
                recipe = "small-electric-pole"
            },
            {
                type = "unlock-recipe",
                recipe = modprefix.."electric-quarry"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-containers",
        type = "technology",
        icon = ei_path.."graphics/tech/containers.png",
        icon_size = 256,
        prerequisites = {"ei-electricity-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-1x1-container-filter"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-2x2-container-filter"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-6x6-container-filter"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-benzol",
        type = "technology",
        icon = ei_graphics_tech_path.."benzol.png",
        icon_size = 256,
        prerequisites = {"plastics"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-benzol-coal-gas"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-plastic-benzol"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-electronic-parts",
        type = "technology",
        icon = ei_graphics_tech_path.."electronic-parts.png",
        icon_size = 128,
        prerequisites = {"ei-waver-factory", "battery"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-cpu"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-electronic-parts"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-lube-destilation",
        type = "technology",
        icon = ei_graphics_tech_path.."lube-extraction.png",
        icon_size = 64,
        prerequisites = {"lubricant"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-lube-destilation"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-circuit-waver",
        type = "technology",
        icon = ei_graphics_tech_path.."circuit-waver.png",
        icon_size = 128,
        prerequisites = {"ei-waver-factory"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-green-circuit-waver"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-red-circuit-waver"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-molten-glass",
        type = "technology",
        icon = ei_graphics_tech_path.."molten-glass.png",
        icon_size = 128,
        prerequisites = {"ei-arc-furnace"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-molten-glass"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-cast-glass"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-deep-mining",
        type = "technology",
        icon = ei_graphics_tech_path.."deep-mining.png",
        icon_size = 128,
        prerequisites = {"automation-2", "sulfur-processing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-gold-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-gold"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-gold-plate"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-lead-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-iron-ingot-chunk-smelting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-copper-ingot-chunk-smelting"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-coal-chunk-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-sulfur-chunk-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-acidic-water-crushed-sulfur"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-deep-drill"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-drill-fluid"
            },
            {
                type="mining-with-fluid", 
                modifier=true
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-personal-solar-2",
        type = "technology",
        icon = ei_graphics_tech_path.."personal-solar-2.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-solar-panel-2", "solar-panel-equipment"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-personal-solar-2"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
    {
        name = "ei-minigun",
        type = "technology",
        icon = ei_graphics_tech_path.."minigun.png",
        icon_size = 256,
        prerequisites = {"military-3"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-minigun"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20
        },
        age = "electricity-age",
    },
})

-- insert prereqs
ei_lib.set_prerequisites("ei-electricity-age",{
    "engine",
    "electronics",
    "ei-steam-inserter",
    "logistics",
    "ei-steam-assembler",
    "ei-tank-silo",
    "ei-steam-advanced-train",
    "rp-steam-logistics-chests",
    "ei-fluid-boiler"
})

table.insert(data.raw.technology["lubricant"].prerequisites, "automation-2")
table.insert(data.raw.technology["power-armor"].prerequisites, "ei-grower")
table.insert(data.raw.technology["solar-energy"].prerequisites, "ei-waver-factory")
table.insert(data.raw.technology["ei-computer-age"].prerequisites, "ei-electronic-parts")

table.insert(data.raw.technology["ei-electricity-age"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-electricity-age-tech"
})

table.insert(data.raw.technology["ei-electricity-age"].effects,  {
    type = "unlock-recipe",
    recipe = "lab"
})

table.insert(data.raw.technology["plastics"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-insulated-wire"
})

table.insert(data.raw.technology["sulfur-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-desulfurize-kerosene"
})

table.insert(data.raw.technology["sulfur-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-sulfur-acidic-water"
})

table.insert(data.raw.technology["sulfur-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-acidic-water-sulfur"
})

table.insert(data.raw.technology["coal-liquefaction"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-kerosene-heavy-oil"
})

table.insert(data.raw.technology["lubricant"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-electric-engine-lube"
})

table.insert(data.raw["technology"]["battery"].effects, {
    type = "unlock-recipe",
    recipe = "ei-crushed-copper"
})

table.insert(data.raw["technology"]["advanced-oil-processing"].effects, {
    type = "unlock-recipe",
    recipe = "ei-kerosene-cracking"
})

table.insert(data.raw["technology"]["coal-liquefaction"].effects, {
    type = "unlock-recipe",
    recipe = "ei-coal-gas-reforming"
})

table.insert(data.raw["technology"]["coal-liquefaction"].effects, {
    type = "unlock-recipe",
    recipe = "ei-benzol-petroleum"
})

table.insert(data.raw["technology"]["ei-computer-age"].effects, {
    type = "unlock-recipe",
    recipe = "ei-computer-age-tech"
})

table.insert(data.raw["technology"]["ei-electricity-power"].effects, {
    type = "unlock-recipe",
    recipe = "electric-mining-drill"
})

-- table.insert(data.raw["technology"]["ei-electricity-power"].effects, {
--     type = "unlock-recipe",
--     recipe = "ei-electric-stone-quarry"
-- })

table.insert(data.raw["technology"]["railway"].effects, {
    type = "unlock-recipe",
    recipe = "ei-diesel-fuel-unit"
})

table.insert(data.raw["technology"]["concrete"].effects, {
    type = "unlock-recipe",
    recipe = "ei-concrete-slag"
})
--OTHER
------------------------------------------------------------------------------------------------------

-- make electric powered surface miner using steam age ei_stone-quarry

-- quarry = table.deepcopy(data.raw["assembling-machine"]["ei-stone-quarry"])
-- quarry.name = "ei-electric-stone-quarry"
-- quarry.minable.result = "ei-electric-stone-quarry"
-- quarry.energy_source = {
--     type = "electric",
--     usage_priority = "secondary-input",
-- }
-- quarry.allowed_effects = {"speed", "productivity", "consumption", "pollution"}
-- quarry.module_slots = 2

-- data:extend({
--     {
--         name = "ei-electric-stone-quarry",
--         type = "item",
--         icons = {
--             {
--                 icon = ei_graphics_kirazy_path.."icon/electric-mining-drill.png",
--                 icon_size = 64,
--                 icon_mipmaps = 4,
--             },
--             {
--                 icon = ei_graphics_other_path.."power_overlay.png",
--                 icon_size = 64,
--             }
--         },
--         place_result = "ei-electric-stone-quarry",
--         stack_size = 20,
--         subgroup = "extraction-machine",
--         order = "a[items]-a[stone-quarry]-a",
--     },
--     quarry,
-- })

ei_lib.set_prerequisites("ei-computer-age",{"construction-robotics","logistic-robotics","ei-circuit-waver","oil-gathering","ei-grower","logistics-2","fluid-wagon","ei-castor","ei-benzol","ei-small-inserter","ei-combustion-turbine","ei-arc-furnace"})