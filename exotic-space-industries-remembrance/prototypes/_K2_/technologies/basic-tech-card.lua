data:extend({
  {
    type = "technology",
    name = "automation-science-pack",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/automation-tech-card.png",
    icon_size = 256,
    unit = {
      time = 30,
      count = 50,
      ingredients = {
        { "basic-tech-card", 1 },
      },
    },
    prerequisites = { "kr-automation-core" },
    effects = {
      { type = "unlock-recipe", recipe = "automation-science-pack" },
    },
  },
  {
    type = "technology",
    name = "kr-automation-core",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/automation-core.png",
    icon_size = 256,
    unit = {
      time = 10,
      count = 10,
      ingredients = {
        { "basic-tech-card", 1 },
      },
    },
    prerequisites = {},
    effects = {
      { type = "unlock-recipe", recipe = "automation-core" },
    },
    -- Disable cost multiplier to avoid manually harvesting unreasonable amount of wood.
    ignore_tech_cost_multiplier = true,
  },
  {
    type = "technology",
    name = "kr-greenhouse",
    icon = ei_graphics_3_path.."K2_ASSETS/technologies/greenhouse.png",
    icon_size = 256,
    unit = {
      time = 45,
      count = 40,
      ingredients = {
        { "basic-tech-card", 1 },
      },
    },
    prerequisites = { "kr-automation-core", "steam-power" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-greenhouse" },
      { type = "unlock-recipe", recipe = "wood" },
    },
    -- Disable cost multiplier to avoid manually harvesting unreasonable amount of wood.
    ignore_tech_cost_multiplier = true,
  },
  {
    type = "technology",
    name = "kr-iron-pickaxe",
    icons = util.technology_icon_constant_mining(ei_graphics_3_path.."K2_ASSETS/technologies/iron-pickaxe.png"),
    order = "b-c-a",
    unit = {
      time = 30,
      count = 25,
      ingredients = {
        { "basic-tech-card", 1 },
      },
    },
    prerequisites = {},
    effects = {
      { type = "character-mining-speed", modifier = 0.50 },
    },
  },
})
