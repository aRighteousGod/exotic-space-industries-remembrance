-- this file contains the prototype definition for varios stuff from exotic age

local ei_data = require("lib/data")

--====================================================================================================
--PROTOTYPE DEFINITIONS
--====================================================================================================

--ITEMS
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-black-hole-data",
        type = "item",
        icon = ei_graphics_item_path.."black-hole-data.png",
        icon_size = 128,
        subgroup = "ei-refining-tech",
        order = "c-a",
        stack_size = 200,
        pictures = {
            layers =
            {
              {
                size = 128,
                filename = ei_graphics_item_path.."black-hole-data.png",
                scale = 0.5/2
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 128,
                filename = ei_graphics_item_path.."space-data_light.png",
                scale = 0.5/2
              }
            }
          },
    },

    {
        name = "ei-black-hole-exotic-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."black-hole-exotic-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a7",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."black-hole-exotic-age-tech.png",
                scale = 0.5
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."exotic-age-tech_light.png",
                scale = 0.5
              }
            }
        },
    },
})


--RECIPES
------------------------------------------------------------------------------------------------------

data:extend({
    {
        name = "ei-black-hole-exotic-age-tech",
        type = "recipe",
        category = "ei-nano-factory",
        energy_required = 240,
        ingredients = {
            {type = "item", name = "ei-clean-plating", amount = 25},
            {type = "item", name = "ei-high-tech-parts", amount = 25},
            {type="item", name="ei-gauss-module", amount=1},          
            {type="item", name="ei-simulation-data", amount=25},
            {type="item", name="ei-superior-data", amount=25},
            {type="item", name="ei-fusion-data", amount=25},
            {type="item", name="ei-fission-tech", amount=25},
            {type = "item", name = "ei-charged-neutron-container", amount = 10},
        },
        results = {
            {type = "item", name = "ei-black-hole-exotic-age-tech", amount = 1},
            {type = "item", name = "ei-neutron-container", amount_min = 5, amount_max=10, probability = 0.96},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-black-hole-exotic-age-tech",
    },

    {
      name = "ei-black-hole-exploration",
      type = "technology",
      icon = ei_graphics_tech_path.."black-hole-exploration.png",
      icon_size = 256,
      prerequisites = {"ei-exotic-age","ei-gauss-module"},
      effects = {
          {
              type = "unlock-recipe",
              recipe = "ei-black-hole-exotic-age-tech"
          },
      },
      unit = {
          count = 900,
          ingredients = ei_data.science["exotic-age"],
          time = 20
      },
      age = "exotic-age",
      enabled = ei_mod.show_exotic_gates,
      visible_when_disabled = false,
  },

  {
    name = "ei-black-hole-exotic-age-tech",
    type = "tool",
    icon = ei_graphics_item_path.."black-hole-exotic-age-tech.png",
    icon_size = 64,
    stack_size = 200,
    durability = 1,
    subgroup = "science-pack",
    order = "a7",
    pictures = {
        layers =
        {
          {
            size = 64,
            filename = ei_graphics_item_path.."black-hole-exotic-age-tech.png",
            scale = 0.5
          },
          {
            draw_as_light = true,
            flags = {"light"},
            size = 64,
            filename = ei_graphics_item_path.."exotic-age-tech_light.png",
            scale = 0.5
          }
        }
    },
  },

  {
    name = "ei-crushed-promethium-asteroid-chunk",
    type = "recipe",
    category = "ei-crushing",
    energy_required = 20,
    ingredients = {
        {type="item", name="promethium-asteroid-chunk", amount=1},
    },
    results = {
        {type = "item", name = "ei-exotic-ore", amount_min = 0, amount_max = 9},
    },
    always_show_made_in = true,
    enabled = false,
    main_product = "ei-exotic-ore",
  },

  {
      name = "ei-exotic-matter",
      type = "recipe",
      category = "centrifuging",
      energy_required = 1,
      ingredients = {
          {type = "item", name = "ei-exotic-ore", amount = 1},
      },
      results = {
          {type = "item", name = "ei-exotic-matter-up", amount_min = 1,amount_max = 2, probability = 0.25},
          {type = "item", name = "ei-exotic-matter-down", amount_min = 1,amount_max = 2, probability = 0.25},
      },
      always_show_made_in = true,
      enabled = false,
      subgroup = "ei-alien-items",
      order = "x-1",
      icon = ei_graphics_other_path.."exotic-matter.png",
      icon_size = 128,
  },

})
