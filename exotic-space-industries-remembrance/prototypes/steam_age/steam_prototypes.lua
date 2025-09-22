-- this file contains the prototype definition for varios stuff from steam age

local ei_data = require("lib/data")

--====================================================================================================
--PROTOTYPE DEFINITIONS
--====================================================================================================

--ITEMS
------------------------------------------------------------------------------------------------------

data:extend({
  {
    icon = ei_graphics_item_path.."sand.png",
    icon_size = 64,
    name = modprefix.."sand",
    order = "a[wood]-b-b",
    stack_size = 200,
    subgroup = "ei-refining-crushed",
    type = "item"
  }
})

data:extend({
    {
        name = "ei-coke",
        type = "item",
        icon = ei_graphics_item_path.."coke.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "ei-refining-secondary",
        order = "a2",
        fuel_category = "chemical",
        fuel_value = "6MJ",
        fuel_emissions_multiplier = 0.8
    },
    {
        name = "ei-coke-pellets",
        type = "item",
        icon = ei_graphics_item_path.."coke-pellets.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "ei-refining-secondary",
        order = "a3",
        fuel_category = "chemical",
        fuel_value = "34.5MJ",
        fuel_emissions_multiplier = 0.7
    },
    {
        name = "ei-crushed-coke",
        type = "item",
        icon = ei_graphics_item_path.."crushed-coke.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "c1",
        fuel_category = "chemical",
        fuel_value = "3MJ",
        fuel_emissions_multiplier = 0.72,
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-coke.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-coke-1.png",
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        name = "ei-charcoal",
        type = "item",
        icon = ei_graphics_item_path.."charcoal.png",
        icon_size = 64,
        stack_size = 50,
        subgroup = "ei-refining-secondary",
        order = "a1",
        fuel_category = "chemical",
        fuel_value = "2MJ",
    },
    {
        name = "ei-crushed-iron",
        type = "item",
        icon = ei_graphics_item_path.."crushed-iron.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "a1",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-iron.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-iron-1.png",
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        name = "ei-steel-blend",
        type = "item",
        icon = ei_graphics_item_path.."steel-blend.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "a3",
        pictures = {
            {
                filename = ei_graphics_item_path.."steel-blend.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."steel-blend-1.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."steel-blend-2.png",
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        name = "ei-steel-mechanical-parts",
        type = "item",
        icon = ei_graphics_item_path.."steel-mechanical-parts.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-parts",
        order = "a3",
    },
    {
        name = "ei-steel-beam",
        type = "item",
        icon = ei_graphics_item_path.."steel-beam.png",
        icon_size = 256,
        stack_size = 100,
        subgroup = "ei-refining-beam",
        order = "a3",
    },
        {
        name = "ei-crushed-coal",
        type = "item",
        icon = ei_graphics_item_path.."crushed-coal.png",
        icon_mipmaps = 4,
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-crushed",
        order = "c1",
        fuel_category = "chemical",
        fuel_value = "2MJ",
        fuel_emissions_multiplier=0.92,
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-coal.png",
                icon_mipmaps = 4,
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-coal-1.png",
                icon_mipmaps = 4,
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-coal-2.png",
                icon_mipmaps = 4,
                scale = 0.5,
                size = 64
            },
        },
    },
    {
        name = "ei-ceramic",
        type = "item",
        icon = ei_graphics_3_path.."graphics/item/ceramic.png",
        icon_size = 512,
        icon_mipmaps = 5,
        pictures = {
            {
                filename = ei_graphics_3_path.."graphics/item/ceramic.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/ceramic-2.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/ceramic-3.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            }
        },
        stack_size = 100,
        subgroup = "ei-refining-secondary",
        order = "a8",
    },
    {
        name = "ei-electron-tube",
        type = "item",
        icon = ei_graphics_item_path.."electron-tube.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "intermediate-product",
        order = "b2",
    },
    {
        name = "ei-glass",
        type = "item",
        icon = ei_graphics_3_path.."graphics/item/industrial-glass.png",
        icon_size = 512,
        icon_mipmaps = 5,
        pictures = {
            {
                filename = ei_graphics_3_path.."graphics/item/industrial-glass.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/industrial-glass-2.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            },
            {
                filename = ei_graphics_3_path.."graphics/item/industrial-glass-3.png",
                mipmap_count = 5,
                size = 512,
                scale = 0.0625
            }
        },
        stack_size = 100,
        subgroup = "ei-refining-secondary",
        order = "c1",
    },
    {
        name = "ei-electricity-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."electric-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a3",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."electric-age-tech.png",
                scale = 0.5
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."electric-age-tech_light.png",
                scale = 0.5
              }
            }
        },
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
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-gold-1.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-gold-2.png",
                scale = 0.5,
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
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-sulfur-1.png",
                scale = 0.5,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-sulfur-2.png",
                scale = 0.5,
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
})


--RECIPES
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-charcoal",
        type = "recipe",
        category = "ei-coke-furnace",
        energy_required = 3,
        ingredients = {
            {type="item", name="wood", amount=2}
        },
        results = {
            {type = "item", name = "ei-charcoal", amount = 3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-charcoal",
    },
    {
        name = "ei-coke",
        type = "recipe",
        category = "ei-coke-furnace",
        energy_required = 1.5,
        ingredients = {
            {type="item", name="coal", amount=1}
        },
        results = {
            {type = "item", name = "ei-coke", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-coke",
    },
    {
        name = "ei-coke-charcoal",
        type = "recipe",
        category = "ei-coke-furnace",
        energy_required = 1.5,
        ingredients = {
            {type="item", name="ei-charcoal", amount=1}
        },
        results = {
            {type = "item", name = "ei-coke", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-coke",
    },
    {
        name = "ei-coke-advanced_coal",
        type = "recipe",
        category = "oil-processing",
        energy_required = 3.5,
        ingredients = {
            {type="item", name="coal", amount=4}
        },
        results = {
            {type = "item", name = "ei-coke", amount = 6},
            {type = "fluid", name = "ei-coal-gas", amount_min = 23,amount_max=27},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-coke",
    },
    {
        name = "ei-coke-advanced_charcoal",
        type = "recipe",
        category = "oil-processing",
        energy_required = 3.5,
        ingredients = {
            {type="item", name="ei-charcoal", amount=4}
        },
        results = {
            {type = "item", name = "ei-coke", amount = 6},
            {type = "fluid", name = "ei-coal-gas", amount_min = 23,amount_max=27},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-coke",
    },
    {
        name = "ei-coke-pellets",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type="item", name="ei-coke", amount=5}
        },
        results = {
            {type = "item", name = "ei-coke-pellets", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-coke-pellets",
    },
    {
        name = "ei-crushed-coke-pellets",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 3,
        ingredients = {
            {type="item", name="ei-coke-pellets", amount=5}
        },
        results = {
            {type = "item", name = "ei-crushed-coke", amount = 10},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-coke",
    },
    {
        name = "ei-crushed-coke",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type="item", name="ei-coke", amount=1}
        },
        results = {
            {type = "item", name = "ei-crushed-coke", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-coke",
    },
    {
        name = "ei-crushed-coal",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "coal", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-coal", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-coal",
    },
    {
        name = "ei-crushed-iron",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type="item", name="iron-plate", amount=1}
        },
        results = {
            {type = "item", name = "ei-crushed-iron", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-iron",
    },
    --[[
    {
        name = "ei-crushed-iron-plate",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type="item", name="iron-plate", amount=1}
        },
        results = {
            {type = "item", name = "ei-crushed-iron", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-iron",
        hide_from_player_crafting = true,
    },
    ]]
    {
        name = "ei-crushed-iron-mechanical-parts",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type="item", name="ei-iron-mechanical-parts", amount=1}
        },
        results = {
            {type = "item", name = "ei-crushed-iron", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-iron",
        hide_from_player_crafting = true,
    },
    {
        name = "ei-steel-blend",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type="item", name="ei-crushed-coke", amount=2},
            {type="item", name="ei-crushed-iron", amount=10}
        },
        results = {
            {type = "item", name = "ei-steel-blend", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-steel-blend",
    },
    {
        name = "ei-steel-plate",
        type = "recipe",
        category = "smelting",
        energy_required = 20,
        ingredients = {
            {type="item", name = "ei-steel-blend", amount = 1}
        },
        results = {
            {type = "item", name = "steel-plate", amount = 10},
            {type="item",name="ei-slag",amount_min=1,amount_max=2,probability=0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "steel-plate",
    },
    {
        name = "ei-steel-mechanical-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients = {
            {type="item", name="steel-plate", amount=1}
        },
        results = {
            {type = "item", name = "ei-steel-mechanical-parts", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-steel-mechanical-parts",
    },

    {
        name = "ei-steel-mechanical-parts-from-plate",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients = {
            {type="item", name="steel-plate", amount=1}
        },
        results = {
            {type = "item", name = "ei-steel-mechanical-parts", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-steel-mechanical-parts",
    },
    {
        name = "ei-steel-beam",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type="item",name="steel-plate", amount=2}
        },
        results = {
            {type = "item", name = "ei-steel-beam", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-steel-beam",
    },
    {
        name = "ei-tank",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type="item", name="ei-iron-mechanical-parts", amount=10},
            {type="item", name="pipe", amount=4},
            {type="item", name="ei-copper-mechanical-parts", amount=6}
        },
        results = {
            {type = "item", name = "storage-tank", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "storage-tank",
    },
    {
        name = "ei-solid-fuel-residual-oil",
        type = "recipe",
        category = "chemistry",
        energy_required = 2,
        ingredients = {
            {type="fluid", name="ei-residual-oil", amount=30}
        },
        results = {
            {type = "item", name = "solid-fuel", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        icon = ei_graphics_other_path.."residual-oil_solid-fuel.png",
        icon_size = 64,
        subgroup = "fluid-recipes",
        order = "b[fluid-chemistry]-c[solid-fuel-residual-oil]",
    },
    {
        name = "ei-sand",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        icons = {
          {
              icon = data.raw.item["ei-sand"].icon,
              icon_size = data.raw.item["ei-sand"].icon_size,
          },
          {
              icon = ei_graphics_other_path.."overlay_1.png",
              icon_size = 64,
          }
        },
        ingredients = {
            {type="item", name="stone", amount=1},
        },
        results = {
            {type = "item", name = modprefix.."sand", amount_min = 2,amount_max=3},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = modprefix.."sand",
    },
    {
        name = "ei-glass",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type="item", name = modprefix.."sand", amount=16},
        },
        results = {
            {type = "item", name = "ei-glass", amount = 1},
            {type ="item", name="ei-slag", amount_min=1,amount_max=2,probability=0.1}
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-glass",
    },
    {
        name = "ei-ceramic-steam-assembler",
        type = "recipe",
        category = "ei-steam-assembler",
        energy_required = 1,
        ingredients = {
            {type = "item", name = modprefix.."sand", amount = 2},
            {type = "fluid", name = "steam", amount = 15}
        },
        results = {
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-ceramic",
    },
    {
        name = "ei-ceramic",
        type = "recipe",
        category = "crafting-with-fluid",
        energy_required = 1,
        ingredients = {
            {type = "item", name = modprefix.."sand", amount = 2},
            {type = "fluid", name = "steam", amount = 15}
        },
        results = {
            {type = "item", name = "ei-ceramic", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-ceramic",
    },
    {
        name = "ei-electron-tube",
        type = "recipe",
        category = "crafting",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "copper-cable", amount = 1},
            {type = "item", name = "ei-glass", amount = 1},
            {type = "item", name = "ei-ceramic", amount = 1}
        },
        results = {
            {type = "item", name = "ei-electron-tube", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-electron-tube",
    },
    {
        name = "ei-electricity-age-tech",
        type = "recipe",
        category = "crafting",
        energy_required = 18,
        ingredients = {
            {type = "item", name = "electronic-circuit", amount = 4},
            {type = "item", name = "electric-engine-unit", amount = 3},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 4}
        },
        results = {
            {type = "item", name = "ei-electricity-age-tech", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-electricity-age-tech",
    },
    {
        name = "ei-landfill-sand",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type = "item", name = modprefix.."sand", amount = 50},
        },
        results = {
            {type = "item", name = "landfill", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "landfill",
    },
  {
    type = "recipe",
    name = "ei-basic-steam-oil-processing",
    category = "oil-processing",
    enabled = false,
    energy_required = 5,
    ingredients =
    {
      {type = "fluid", name = "steam", amount = 500, minimum_temperature = 165},
      {type = "fluid", name = "crude-oil", amount = 50}
    },
    results =
    {
        {type="fluid", name="ei-residual-oil", amount_min=68,amount_max=72},
        {type="fluid", name="petroleum-gas", amount_min=23,amount_max=27},
        {type="fluid", name="light-oil", amount_min=8,amount_max=12},
    },
    icon = ei_graphics_3_path.."graphics/other/basic-steam-oil-processing.png",
    icon_size = 64,
    subgroup = "fluid-recipes",
    order = "a[oil-processing]-b[basic-oil-processing]b"
  },
  {
    type = "recipe",
    name = "ei-basic-water-oil-processing",
    category = "oil-processing",
    enabled = false,
    energy_required = 5,
    ingredients =
    {
      {type = "fluid", name = "water", amount = 50},
      {type = "fluid", name = "crude-oil", amount = 50}
    },
    results =
    {
        {type="fluid", name="ei-residual-oil", amount_min=48,amount_max=52},
        {type="fluid", name="petroleum-gas", amount_min=48,amount_max=52},
    },
    icon = ei_graphics_3_path.."graphics/other/basic-water-oil-processing.png",
    icon_size = 64,
    subgroup = "fluid-recipes",
    order = "a[oil-processing]-b[basic-oil-processing]a"
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
        {type = "fluid", name = "heavy-oil", amount_min = 13,amount_max=17},
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
    name = "ei-electric-engine-lube",
    type = "recipe",
    category = "advanced-crafting",
    energy_required = 60,
    ingredients = {
        {type = "fluid", name = "lubricant", amount = 100},
        {type="item",name="electronic-circuit", amount=10},
        {type = "item", name = "engine-unit", amount = 10},
        {type = "item", name = "copper-cable", amount = 40},
        {type = "item", name = "ei-iron-mechanical-parts", amount = 20},
    },
    results = {
        {type = "item", name = "electric-engine-unit", amount = 20},
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
        name = "ei-gold-ingot",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type = "item", name = "ei-gold-chunk", amount = 3},
        },
        results = {
            {type = "item", name = "ei-gold-ingot", amount = 1},
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1,allow_productivity=false}
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
    --[[
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
    ]]
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
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1,allow_productivity=false}
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
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1,allow_productivity=false}
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
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1,allow_productivity=false}
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
            {type = "item", name = "ei-slag", amount_min = 1, amount_max = 2, probability = 0.1,allow_productivity=false}
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
            {type = "item", name = "coal", amount_min = 2,amount_max=6},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "coal",
    },
    {
        name = "ei-coal-chunk-crushing-crushed",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 6,
        ingredients = {
            {type = "item", name = "ei-coal-chunk", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-coal", amount_min = 4,amount_max=12},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-coal",
    },
    {
        name = "ei-sulfur-chunk-crushing",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 2,
        ingredients = {
            {type = "item", name = "ei-sulfur-chunk", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-sulfur", amount_min = 4,amount_max=12},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-crushed-sulfur",
    },
    {
        name = "ei-sulfur-chunk-crushing-stone",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 2,
        icons = {
            { icon = data.raw.item["sulfur"].icon,            scale = 0.2, shift = { 3, 4 } },
            { icon = data.raw.item["stone"].icon, scale = 0.2, shift = { -3, -4 } },
        },
        ingredients = {
            {type = "item", name = "ei-sulfur-chunk", amount = 1},
        },
        results = {
            {type = "item", name = "sulfur", amount_min = 1,amount_max=2},
            {type = "item", name = "stone", amount_min = 4,amount_max=8},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "sulfur",
    },
    {
        name = "ei-sulfur-crushing",
        type = "recipe",
        category = "ei-crushing",
        energy_required = 1,
        ingredients = {
            {type = "item", name = "sulfur", amount = 1},
        },
        results = {
            {type = "item", name = "ei-crushed-sulfur", amount=2},
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
            {type = "fluid", name = "water", amount = 20},
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
})

--TECHS
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-steam-power",
        type = "technology",
        icon = ei_graphics_tech_path.."steam-power.png",
        icon_size = 128,
        prerequisites = {"ei-steam-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "pipe-to-ground"
            },
            {
                type = "unlock-recipe",
                recipe = "boiler"
            },
            {
                type = "unlock-recipe",
                recipe = "offshore-pump"
            }
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
        name = "ei-coke-processing",
        type = "technology",
        icon = ei_graphics_tech_path.."coke-processing.png",
        icon_size = 128,
        prerequisites = {"ei-steam-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-charcoal"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-coke"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-coke-charcoal"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-coke-pellets"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-coke-furnace"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
        name = "ei-tank",
        type = "technology",
        icon = ei_graphics_tech_path.."fluid-handling.png",
        icon_size = 256,
        icon_mipmaps = 4,
        prerequisites = {"ei-steam-age"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-tank"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
        name = "ei-advanced-coke-processing",
        type = "technology",
        icon = ei_graphics_tech_path.."advanced-coke-processing.png",
        icon_size = 128,
        prerequisites = {"ei-steam-oil-processing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-coke-advanced_coal"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-coke-advanced_charcoal"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
        name = "ei-glass",
        type = "technology",
        icon = ei_graphics_3_path.."graphics/item/industrial-glass.png",
        icon_size = 512,
        icon_mipmaps = 5,
        prerequisites = {"ei-steam-crusher"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-sand"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-glass"
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
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
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
    {
        name = "ei-deep-mining",
        type = "technology",
        icon = ei_graphics_tech_path.."deep-mining.png",
        icon_size = 128,
        prerequisites = {"electric-engine", "sulfur-processing"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "ei-gold-ingot"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-gold"
            },
            --[[
            {
                type = "unlock-recipe",
                recipe = "ei-crushed-gold-plate"
            },
            ]]
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
                recipe = "ei-coal-chunk-crushing-crushed"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-sulfur-chunk-crushing"
            },
            {
                type = "unlock-recipe",
                recipe = "ei-sulfur-chunk-crushing-stone"
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
            --[[]
            {
                type="mining-with-fluid",
                modifier=true
            },
            ]]
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["steam-age"],
            time = 20
        },
        age = "steam-age",
    },
})

-- add steel recipes to steel-processing

table.insert(data.raw["technology"]["steel-processing"].effects, {
    type = "unlock-recipe",
    recipe = "ei-steel-blend"
})

table.insert(data.raw["technology"]["steel-processing"].effects, {
    type = "unlock-recipe",
    recipe = "ei-steel-plate"
})

table.insert(data.raw["technology"]["steel-processing"].effects, {
    type = "unlock-recipe",
    recipe = "ei-steel-beam"
})
table.insert(data.raw.technology["electric-engine"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-electric-engine-lube"
})
table.insert(data.raw.technology["sulfur-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-sulfur-acidic-water"
})

table.insert(data.raw.technology["sulfur-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-acidic-water-sulfur"
})

table.insert(data.raw.technology["sulfur-processing"].effects,  {
    type = "unlock-recipe",
    recipe = "ei-sulfur-crushing"
})