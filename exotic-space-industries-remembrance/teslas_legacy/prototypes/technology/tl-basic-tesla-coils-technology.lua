data:extend({
  {
    type = "technology",
    name = "tl-basic-tesla-coils-technology",
    icon = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/basic/technology/tesla-turret.png",
    icon_size = 256, icon_mipmaps = 4,
    effects =
    {
      { 
        type = "unlock-recipe", 
        recipe = "tl-basic-tesla-coil" 
      },
    },
    prerequisites = {
      "electric-energy-distribution-1",
      "battery",
      "electronics",
      "military",
    },
    unit =
    {
      count = 50,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1}
      },
      time = 30
    },
    order = "e-c-c"
  },
})
  

