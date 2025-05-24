data:extend({
  {
    type = "technology",
    name = "kr-advanced-chemical-plant",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/advanced-chemical-plant.png",
    icon_size = 256,
    unit = {
      time = 60,
      count = 500,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
      },
    },
    prerequisites = { "kr-imersium-processing", "kr-advanced-tech-card" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-advanced-chemical-plant" },
      { type = "unlock-recipe", recipe = "electronic-components-with-lithium" },
    },
  },
  {
    type = "technology",
    name = "kr-laser-artillery-turret",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/laser-artillery-turret.png",
    icon_size = 256,
    order = "g-f-z",
    unit = {
      time = 60,
      count = 750,
      ingredients = {
        { "military-science-pack", 1 },
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "advanced-tech-card", 1 },
      },
    },
    prerequisites = { "kr-military-5", "kr-advanced-tech-card", "kr-energy-control-unit" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-laser-artillery-turret" },
    },
  },
  {
    type = "technology",
    name = "kr-rocket-turret",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/rocket-turret.png",
    icon_size = 256,
    order = "g-f-z",
    unit = {
      time = 60,
      count = 750,
      ingredients = {
        { "military-science-pack", 1 },
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "advanced-tech-card", 1 },
      },
    },
    prerequisites = { "kr-military-5", "kr-advanced-tech-card", "atomic-bomb" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-rocket-turret" },
      { type = "unlock-recipe", recipe = "explosive-turret-rocket" },
      { type = "unlock-recipe", recipe = "nuclear-turret-rocket" },
    },
  },
  {
    type = "technology",
    name = "kr-singularity-tech-card",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/singularity-tech-card.png",
    icon_size = 256,
    unit = {
      time = 45,
      count = 1250,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
      },
    },
    prerequisites = { "kr-advanced-tech-card", "kr-matter-processing" },
    effects = {
      { type = "unlock-recipe", recipe = "singularity-tech-card" },
    },
  },
})
