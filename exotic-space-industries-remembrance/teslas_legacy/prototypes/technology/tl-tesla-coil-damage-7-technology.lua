
data:extend({
  
{
  type = "technology",
  name = "tl-tesla-coil-damage-technology-7",
  icon_size = 128,
  icon = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/tl-tesla-coil-damage-technology.png",
  effects =
  {
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.40
    },
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 1.00
    },
  },
  prerequisites = {
    "tl-tesla-coil-damage-technology-6"
  },
  unit =
  {
    count_formula = "850*2^(L-8)",
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"military-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1}
    },
    time = 90
  },
  max_level = "infinite",
  upgrade = true,
  order = "e-l-f"
}

})

