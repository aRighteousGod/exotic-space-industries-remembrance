data:extend({
  {
    type = "technology",
    name = "kr-antimatter-ammo",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/antimatter-ammo.png",
    icon_size = 256,
    unit = {
      time = 60,
      count = 2500,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
        { "singularity-tech-card", 1 },
      },
    },
    prerequisites = { "kr-antimatter-reactor", "kr-laser-artillery-turret", "kr-rocket-turret" },
    effects = {
      { type = "unlock-recipe", recipe = "antimatter-turret-rocket" },
      { type = "unlock-recipe", recipe = "antimatter-artillery-shell" },
      { type = "unlock-recipe", recipe = "antimatter-rocket" },
    },
  },
  {
    type = "technology",
    name = "kr-antimatter-reactor",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/antimatter-reactor.png",
    icon_size = 256,
    prerequisites = { "kr-fusion-energy", "kr-singularity-tech-card" },
    unit = {
      time = 60,
      count = 2000,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
        { "singularity-tech-card", 1 },
      },
    },
    order = "g-f-z",
    effects = {
      { type = "unlock-recipe", recipe = "kr-antimatter-reactor" },
      { type = "unlock-recipe", recipe = "empty-antimatter-fuel-cell" },
      { type = "unlock-recipe", recipe = "charged-antimatter-fuel-cell" },
    },
  },
  {
    type = "technology",
    name = "kr-intergalactic-transceiver",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/intergalactic-transceiver.png",
    icon_size = 256,
    unit = {
      time = 60,
      count = 3000,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
        { "singularity-tech-card", 1 },
      },
    },
    prerequisites = { "kr-singularity-tech-card" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-intergalactic-transceiver" },
    },
  },
  {
    type = "technology",
    name = "kr-matter-cube",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/matter-cube.png",
    icon_size = 256,
    order = "g-f-z",
    unit = {
      time = 60,
      count = 500,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
        { "singularity-tech-card", 1 },
      },
    },
    prerequisites = { "kr-singularity-tech-card" },
    effects = {}, -- Populated by matter util
  },
  {
    type = "technology",
    name = "kr-planetary-teleporter",
    icon = "__exotic-space-industries-graphics-3__/K2_ASSETS/technologies/planetary-teleporter.png",
    icon_size = 256,
    unit = {
      time = 60,
      count = 500,
      ingredients = {
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 },
        { "matter-tech-card", 1 },
        { "advanced-tech-card", 1 },
        { "singularity-tech-card", 1 },
      },
    },
    prerequisites = { "effect-transmission", "kr-singularity-tech-card" },
    effects = {
      { type = "unlock-recipe", recipe = "kr-planetary-teleporter" },
      { type = "unlock-recipe", recipe = "gps-satellite" },
    },
  },
})
