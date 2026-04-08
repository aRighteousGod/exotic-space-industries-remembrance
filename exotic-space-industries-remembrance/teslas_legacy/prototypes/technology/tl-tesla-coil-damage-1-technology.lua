
data:extend({
  
{
  type = "technology",
  name = "tl-tesla-coil-damage-technology-1",
  icon_size = 128,
  icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/technology/icons/tl-tesla-coil-damage-technology.png",
  effects =
  {
    {
      type = "ammo-damage",
      ammo_category = "tl-basic-tesla-coil-turret-category",
      modifier = 0.15
    },
    {
      type = "ammo-damage",
      ammo_category = "tl-advanced-tesla-coil-turret-category",
      modifier = 0.50
    },
  },
  prerequisites = {"tl-advanced-tesla-coils-technology"},
  unit =
  {
    count = 100*1,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"military-science-pack", 1},
      {"chemical-science-pack", 1}
    },
    time = 30
  },
  upgrade = true,
  order = "e-j-a"
}

})

