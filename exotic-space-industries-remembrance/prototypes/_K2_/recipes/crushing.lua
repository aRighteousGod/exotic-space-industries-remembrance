data:extend({
  {
    type = "recipe",
    name = "imersite-crystal-to-dust",
    localised_name = { "recipe-name.imersite-crystal-to-dust" },
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/icons/items/imersite-powder.png",
    subgroup = "intermediate-product",
    order = "e[ei-electronic-components]",
    hide_from_player_crafting = true,
    enabled = true,
    category = "crushing",
    energy_required = 1,
    ingredients = {
      { type = "item", name = "imersite-crystal", amount = 1 },
    },
    results = {
      { type = "item", name = "imersite-powder", amount = 3 },
    },
    allow_as_intermediate = false,
    allow_intermediates = false,
    always_show_made_in = true,
    always_show_products = true,
  },
  {
    type = "recipe",
    name = "imersite-powder",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/icons/items/imersite-powder.png",
    enabled = false,
    category = "crushing",
    energy_required = 3,
    ingredients = {
      { type = "item", name = "raw-imersite", amount = 3 },
    },
    results = {
      { type = "item", name = "imersite-powder", amount = 3 },
      { type = "item", name = "stone", amount = 3 },
    },
    main_product = "imersite-powder",
    allow_as_intermediate = false,
    allow_intermediates = false,
    allow_productivity = true,
    always_show_made_in = true,
    always_show_products = true,
  }
})
