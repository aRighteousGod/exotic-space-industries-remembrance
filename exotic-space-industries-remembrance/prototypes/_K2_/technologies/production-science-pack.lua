data:extend({
  {
    type = "technology",
    name = "kr-advanced-fuel",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/advanced-fuel.png",
    icon_size = 256,
    unit = {
      time = 30,
      count = 250,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
      },
    },
    prerequisites = { "kr-quarry-minerals-extraction", "kr-advanced-chemistry" },
    effects = {
      { type = "unlock-recipe", recipe = "advanced-fuel" },
    },
  },
  {
    type = "technology",
    name = "kr-quarry-minerals-extraction",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/quarry-drill.png",
    icon_size = 256,
    order = "g-e-d",
    unit = {
      time = 60,
      count = 350,
      ingredients = {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
      },
    },
    prerequisites = { "kr-advanced-chemistry", "processing-unit", "electric-engine" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-quarry-drill" },
      { type = "unlock-recipe", recipe = "imersite-powder" },
      { type = "unlock-recipe", recipe = "imersite-crystal" },
    },
  },
})
