local level = 1
local base = 75
local step = 15

data:extend({
  {
    type = "technology",
    name = "tl-tesla-coil-shooting-speed-3",
    icon_size = 128, icon_mipmaps = 4,
    icon = "__exotic-space-industries-remembrance-graphics-3__/teslas_legacy/graphics/technology/icons/tl-tesla-coil-shooting-speed-technology.png",
    effects =
    {
      {
        type = "gun-speed",
        ammo_category = "tl-basic-tesla-coil-turret-category",
        modifier = 0.15
      },
      {
        type = "gun-speed",
        ammo_category = "tl-advanced-tesla-coil-turret-category",
        modifier = 0.20
      },
    },
    prerequisites = {"tl-tesla-coil-shooting-speed-2"},
    unit =
    {
      count = (base+step*(level-1))*level,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 40
    },
    upgrade = true,
    order = "e-l-c"
  }
})

