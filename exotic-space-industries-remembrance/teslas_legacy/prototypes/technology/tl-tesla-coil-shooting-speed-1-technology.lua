local level = 1
local base = 75
local step = 15

data:extend({
  {
    type = "technology",
    name = "tl-tesla-coil-shooting-speed-1",
    icon_size = 128, icon_mipmaps = 4,
    icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/technology/icons/tl-tesla-coil-shooting-speed-technology.png",
    effects =
    {
      {
        type = "gun-speed",
        ammo_category = "tl-basic-tesla-coil-turret-category",
        modifier = 0.10
      },
      {
        type = "gun-speed",
        ammo_category = "tl-advanced-tesla-coil-turret-category",
        modifier = 0.15
      },
    },
    prerequisites = {"tl-basic-tesla-coils-technology"},
    unit =
    {
      count = (base+step*(level-1))*level,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
      },
      time = 30
    },
    upgrade = true,
    order = "e-j-a"
  }
})

