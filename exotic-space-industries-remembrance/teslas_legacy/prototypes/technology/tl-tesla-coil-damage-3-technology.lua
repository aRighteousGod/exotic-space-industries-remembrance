
data:extend({
  
{
  type = "technology",
  name = "tl-tesla-coil-damage-technology-3",
  icon_size = 128,
  icon = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/tl-tesla-coil-damage-technology.png",
  effects =
  {
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.20
    },
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 0.60
    },
  },
  prerequisites = {"tl-tesla-coil-damage-technology-2"},
  unit =
  {
    count = 100*3,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"military-science-pack", 1},
      {"chemical-science-pack", 1}
    },
    time = 60
  },
  upgrade = true,
  order = "e-l-c"
}

})

