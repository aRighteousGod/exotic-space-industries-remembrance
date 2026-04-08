
data:extend({
  {
    type = "technology",
    name = "tl-advanced-tesla-coils-technology",
    icon_size = 64, icon_mipmaps = 4,
    icon = "__exotic-space-industries-remembrance__/teslas_legacy/graphics/advanced/icons/soviet-tesla.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "tl-advanced-tesla-coil",
      }
    },
    prerequisites = {
      "tl-basic-tesla-coils-technology",
      "electric-energy-distribution-2",
      "electric-energy-accumulators",
      "processing-unit",
      "military-3",
    },
    unit =
    {
      count = 200,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 40
    },
    order = "a-j-b"
  }
})


