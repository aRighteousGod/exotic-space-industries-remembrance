data:extend({
  {
    type = "technology",
    name = "kr-fluid-excess-handling",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/flare-stack.png",
    icon_size = 256,
    unit = {
      time = 45,
      count = 150,
      ingredients = {
        { "basic-tech-card", 1 },
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
    },
    prerequisites = { "kr-fluids-chemistry", "electronics" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-flare-stack" },
    },
  },
  {
    type = "technology",
    name = "kr-gas-power-station",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/gas-power-station.png",
    icon_size = 256,
    unit = {
      time = 30,
      count = 250,
      ingredients = {
        { "basic-tech-card", 1 },
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
    },
    prerequisites = { "oil-processing", "engine" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-gas-power-station" },
    },
  },
  {
    type = "technology",
    name = "kr-silicon-processing",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/silicon-processing.png",
    icon_size = 256,
    order = "c-a",
    unit = {
      time = 30,
      count = 125,
      ingredients = {
        { "basic-tech-card", 1 },
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
    },
    prerequisites = { "kr-fluids-chemistry", "automation-2" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-filtration-plant" },
      { type = "unlock-recipe", recipe = "silicon" },
      { type = "unlock-recipe", recipe = "quartz" },
    },
  },
  {
    type = "technology",
    name = "kr-steel-fluid-handling",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/steel-fluid-handling.png",
    icon_size = 256,
    unit = {
      time = 30,
      count = 100,
      ingredients = {
        { "basic-tech-card", 1 },
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
      },
    },
    prerequisites = { "steel-processing", "fluid-handling" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-steel-pipe" },
      { type = "unlock-recipe", recipe = "kr-steel-pipe-to-ground" },
      { type = "unlock-recipe", recipe = "kr-steel-pump" },
    },
  },
})
