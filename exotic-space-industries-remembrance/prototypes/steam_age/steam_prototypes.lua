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
        fuel_value = "3MJ",
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
        fuel_value = "18MJ",
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
        fuel_value = "1.5MJ",
        pictures = {
            {
                filename = ei_graphics_item_path.."crushed-coke.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-coke-1.png",
                scale = 0.25,
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
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."crushed-iron-1.png",
                scale = 0.25,
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
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."steel-blend-1.png",
                scale = 0.25,
                size = 64
            },
            {
                filename = ei_graphics_item_path.."steel-blend-2.png",
                scale = 0.25,
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
        name = "ei-ceramic",
        type = "item",
        icon = ei_graphics_item_path.."ceramic.png",
        icon_size = 64,
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
        icon = ei_graphics_item_path.."glass.png",
        icon_size = 64,
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
                scale = 0.25
              },
              {
                draw_as_light = true,
                flags = {"light"},
                size = 64,
                filename = ei_graphics_item_path.."electric-age-tech_light.png",
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
            {type = "fluid", name = "ei-coal-gas", amount = 25},
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
            {type = "fluid", name = "ei-coal-gas", amount = 25},
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
        ingredients = {
            {type="item", name="stone", amount=1},
        },
        results = {
            {type = "item", name = modprefix.."sand", amount = 2},
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
            {type = "item", name = "electronic-circuit", amount = 3},
            {type = "item", name = "engine-unit", amount = 2},
            {type = "item", name = "ei-steel-mechanical-parts", amount = 3}
        },
        results = {
            {type = "item", name = "ei-electricity-age-tech", amount = 5},
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
        icon = ei_graphics_tech_path.."glass.png",
        icon_size = 128,
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
ei_lib.set_prerequisites("ei-steam-age",{
    "ei-burner-assembler",
    "military",
    "stone-wall",
    "gun-turret",
    "ei-mechanical-inserter"
})