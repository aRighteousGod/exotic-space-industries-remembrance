-- this file contains the prototype definition for varios stuff from dark age

local ei_data = require("lib/data")

--====================================================================================================
--PROTOTYPE DEFINITIONS
--====================================================================================================

--ITEMS
------------------------------------------------------------------------------------------------------
data:extend({
    {
        name = "ei-handcrafting",
        type = "recipe-category",
    },
    {
        name = "ei-iron-beam",
        type = "item",
        icon = ei_graphics_item_path.."iron-beam.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-beam",
        order = "a1",
    },
    {
        name = "ei-copper-beam",
        type = "item",
        icon = ei_graphics_item_path.."copper-beam.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-beam",
        order = "a2",
    },
    {
        name = "ei-iron-mechanical-parts",
        type = "item",
        icon = ei_graphics_item_path.."iron-mechanical-parts.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-parts",
        order = "a1",
    },
    {
        name = "ei-copper-mechanical-parts",
        type = "item",
        icon = ei_graphics_item_path.."copper-mechanical-parts.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-parts",
        order = "a2",
    },
    {
        name = "ei-poor-iron-chunk",
        type = "item",
        icon = ei_graphics_item_path.."poor-iron-chunk.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a1",
    },
    {
        name = "ei-poor-copper-chunk",
        type = "item",
        icon = ei_graphics_item_path.."poor-copper-chunk.png",
        icon_size = 64,
        icon_mipmaps = 4,
        stack_size = 100,
        subgroup = "ei-refining-raw",
        order = "a2",
    },
{
        name = "ei-slag",
        type = "item",
        icon = ei_graphics_item_path.."slag.png",
        icon_size = 64,
        stack_size = 100,
        subgroup = "ei-refining-byproduct",
        order = "a1",
    },
    {
        name = "ei-steam-engine",
        type = "item",
        icon = ei_graphics_item_path.."steam-engine.png",
        icon_size = 64,
        icon_mipmaps = 4,
        stack_size = 50,
        subgroup = "intermediate-product",
        order = "b1",
    },
    {
        name = "ei-dark-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."dark-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a1",
        pictures = {
          layers =
          {
            {
              size = 64,
              filename = ei_graphics_item_path.."dark-age-tech.png",
              scale = 0.25
            },
            {
              draw_as_light = true,
              flags = {"light"},
              size = 64,
              filename = ei_graphics_item_path.."dark-age-tech_light.png",
              scale = 0.25
            }
          }
        },
    },
    {
        name = "ei-steam-age-tech",
        type = "tool",
        icon = ei_graphics_item_path.."steam-age-tech.png",
        icon_size = 64,
        stack_size = 200,
        durability = 1,
        subgroup = "science-pack",
        order = "a2",
        pictures = {
            layers =
            {
              {
                size = 64,
                filename = ei_graphics_item_path.."steam-age-tech.png",
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."steam-age-tech_light.png",
                scale = 0.25
              }
            }
        },
    }
    
})

--RECIPES
------------------------------------------------------------------------------------------------------
data:extend({
    {
        name = "ei-poor-iron-chunk-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type="item",name="ei-poor-iron-chunk", amount=3}
        },
        results = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "ei-slag", amount_min = 1,amount_max=2, probability = 0.33,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "iron-plate",
    },
    {
        name = "ei-poor-copper-chunk-smelting",
        type = "recipe",
        category = "smelting",
        energy_required = 3.2,
        ingredients = {
            {type="item",name="ei-poor-copper-chunk", amount=3}
        },
        results = {
            {type = "item", name = "copper-plate", amount = 1},
            {type = "item", name = "ei-slag", amount_min = 1,amount_max=2, probability = 0.33,allow_productivity=false}
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "copper-plate",
    },
    {
        name = "ei-iron-beam",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type ="item", name="iron-plate", amount=2},
        },
        results = {
            {type = "item", name = "ei-iron-beam", amount = 1},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "ei-iron-beam",
    },
    {
        name = "ei-copper-beam",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type="item",name="copper-plate", amount=2},
        },
        results = {
            {type = "item", name = "ei-copper-beam", amount = 1},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "ei-copper-beam",
    },
    {
        name = "ei-iron-mechanical-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type="item", name="iron-plate", amount=1},
        },
        results = {
            {type = "item", name = "ei-iron-mechanical-parts", amount = 2},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "ei-iron-mechanical-parts",
    },
    {
        name = "ei-copper-mechanical-parts",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type="item", name="copper-plate", amount=1},
        },
        results = {
            {type = "item", name = "ei-copper-mechanical-parts", amount = 2},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "ei-copper-mechanical-parts",
    },
    {
        name = "ei-stone-slag-processing",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type="item",name="ei-slag", amount=2},
        },
        results = {
            {type = "item", name = "stone", amount = 1},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "stone",
    },
    {
        name = "ei-dark-age-tech",
        type = "recipe",
        category = "crafting",
        energy_required = 0.5,
        ingredients = {
            {type="item", name="iron-plate", amount=1},
            {type="item", name="copper-plate", amount=1},
        },
        results = {
            {type = "item", name = "ei-dark-age-tech", amount = 2},
        },
        always_show_made_in = true,
        enabled = true,
        main_product = "ei-dark-age-tech",
    },
    {
        name = "ei-steam-engine",
        type = "recipe",
        category = "crafting",
        energy_required = 2,
        ingredients = {
            {type="item", name="ei-iron-mechanical-parts", amount=2},
            {type="item", name="ei-copper-mechanical-parts", amount=2},
            {type="item", name="pipe", amount=1},
        },
        results = {
            {type = "item", name = "ei-steam-engine", amount = 1},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-steam-engine",
    },
    {
        name = "ei-steam-age-tech",
        type = "recipe",
        category = "crafting",
        energy_required = 4,
        ingredients = {
            {type="item", name="ei-copper-mechanical-parts", amount=4},
            {type="item", name="ei-steam-engine", amount=1},
            {type="item", name="pipe", amount=2},
        },
        results = {
            {type = "item", name = "ei-steam-age-tech", amount = 2},
        },
        always_show_made_in = true,
        enabled = false,
        main_product = "ei-steam-age-tech",
    }
})

--TECHS
------------------------------------------------------------------------------------------------------

-- insert steam-age-tech and engine unit aswell as pipe into steam-age-tech

data.raw["technology"]["ei-steam-age"].effects = {
    {
        type = "unlock-recipe",
        recipe = "pipe"
    },
    {
        type = "unlock-recipe",
        recipe = "ei-steam-engine"
    },
    {
        type = "unlock-recipe",
        recipe = "ei-steam-age-tech"
    },

}