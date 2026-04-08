data:extend({
  
{
  type = "technology",
  name = "tl-tesla-tank-technology",
  icon_size = 64, icon_mipmaps = 4,
  icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/tank/icons/Teslatank.png",
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "tl-tesla-tank",
    },
    {
      type = "unlock-recipe",
      recipe = "tl-tesla-coil-ammo",
    }
  },
  
  prerequisites = 
  {
    "tank", 
    "tl-advanced-tesla-coils-technology",
    -- TODO portable tesla coils
  },
  
  unit =
  {
    count = 300,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"military-science-pack", 1},      
      {"chemical-science-pack", 1}
    },
    time = 50
  },
  order = "a-j-b"
},

})

