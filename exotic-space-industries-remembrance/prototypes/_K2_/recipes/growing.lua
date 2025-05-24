data:extend({
  {
    type = "recipe",
    name = "wood",
    enabled = false,
    category = "growing",
    energy_required = 60,
    ingredients = {
      { type = "fluid", name = "water", amount = 200 },
    },
    results = {
      { type = "item", name = "wood", amount = 40 },
    },
  },
  {
    type = "recipe",
    name = "wood-with-fertilizer",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/icons/recipes/wood-with-fertilizer.png",
    enabled = false,
    category = "growing",
    energy_required = 60,
    ingredients = {
      { type = "fluid", name = "water", amount = 200 },
      { type = "item", name = "fertilizer", amount = 1 },
    },
    results = {
      { type = "item", name = "wood", amount = 80 },
    },
  },
})
