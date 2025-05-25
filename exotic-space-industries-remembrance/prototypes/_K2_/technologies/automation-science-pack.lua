data:extend({
  {
    type = "technology",
    name = "kr-fluids-chemistry",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/fluids-chemistry.png",
    icon_size = 256,
    unit = {
      time = 45,
      count = 100,
      ingredients = {
        { "basic-tech-card", 1 },
        { "automation-science-pack", 1 },
      },
    },
    prerequisites = { "steam-power", "steel-processing", "engine" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-electrolysis-plant" },
      { type = "unlock-recipe", recipe = "chemical-plant" },
      { type = "unlock-recipe", recipe = "kr-water-electrolysis" },
    },
  },
  {
    type = "technology",
    name = "kr-sentinel",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/sentinel.png",
    icon_size = 256,
    unit = {
      time = 30,
      count = 100,
      ingredients = {
        { "basic-tech-card", 1 },
        { "automation-science-pack", 1 },
      },
    },
    prerequisites = { "lamp" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-sentinel" },
    },
  },
})
