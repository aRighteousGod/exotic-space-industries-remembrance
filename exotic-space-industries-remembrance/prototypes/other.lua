-- other prototype definitions

data:extend({
  {
    type = "trivial-smoke",
    name = "electric-smoke",
    flags = {"not-on-map"},
    show_when_smoke_off = true,
    animation = {
      filename = "__base__/graphics/entity/smoke/smoke.png",
      priority = "high",
      width = 152,
      height = 120,
      frame_count = 60,
      line_length = 5,
      animation_speed = 1.75,
      scale = 1
    },
    duration = 60,
    fade_away_duration = 30,
    spread_duration = 10,
    start_scale = 0.2,
    end_scale = 1.0,
    color = { r = 0.6, g = 0.2, b = 0.8, a = 0.8 },
    cyclic = true,
    affected_by_wind = false,
    movement_slow_down_factor = 0.95
  },
    {
        name = "ei-refining",
        type = "item-group",
        icon = ei_graphics_other_path.."refining-group.png",
        icon_size = 64,
        inventory_order = "c-a",
        order = "c-a",
    },
    {
        name = "ei-refining-raw",
        type = "item-subgroup",
        group = "ei-refining",
        order = "a",
    },
    {
        name = "ei-refining-secondary",
        type = "item-subgroup",
        group = "ei-refining",
        order = "b",
    },
    {
        name = "ei-refining-byproduct",
        type = "item-subgroup",
        group = "ei-refining",
        order = "c",
    },

      {
        name = "ei-refining-ingot",
        type = "item-subgroup",
        group = "ei-refining",
        order = "d",
    },

    {
        name = "ei-refining-plate",
        type = "item-subgroup",
        group = "ei-refining",
        order = "e",
    },
    {
        name = "ei-refining-parts",
        type = "item-subgroup",
        group = "ei-refining",
        order = "g",
    },
    {
        name = "ei-refining-crushed",
        type = "item-subgroup",
        group = "ei-refining",
        order = "h",
    },
    {
        name = "ei-refining-purified",
        type = "item-subgroup",
        group = "ei-refining",
        order = "i",
    },
    {
        name = "ei-refining-extraction",
        type = "item-subgroup",
        group = "ei-refining",
        order = "i-a",
    },
    {
        name = "ei-refining-space",
        type = "item-subgroup",
        group = "ei-refining",
        order = "i-a",
    },
    {
        name = "ei-refining-molten",
        type = "item-subgroup",
        group = "ei-refining",
        order = "j",
    },
    {
        name = "ei-refining-tech",
        type = "item-subgroup",
        group = "ei-refining",
        order = "k",
    },
    {
        name = "ei-labs",
        type = "item-subgroup",
        group = "production",
        order = "e-a",
    },
    {
        name = "ei-trains",
        type = "item-subgroup",
        group = "logistics",
        order = "e-a",
    },


    -- nuclear group
    {
        name = "ei-nuclear",
        type = "item-group",
        icon = ei_graphics_other_path.."nuclear-group.png",
        icon_size = 128,
        inventory_order = "c-b",
        order = "c-b",
    },
    {
        name = "ei-nuclear-buildings",
        type = "item-subgroup",
        group = "ei-nuclear",
        order = "a",
    },
    {
        name = "ei-nuclear-fission-fuel",
        type = "item-subgroup",
        group = "ei-nuclear",
        order = "c",
    },
    {
        name = "ei-nuclear-processing",
        type = "item-subgroup",
        group = "ei-nuclear",
        order = "b",
    },
    {
        name = "ei-nuclear-elemental",
        type = "item-subgroup",
        group = "ei-nuclear",
        order = "d",
    },
    {
        name = "ei-nuclear-heated",
        type = "item-subgroup",
        group = "ei-nuclear",
        order = "e",
    },
    {
        name = "ei-htr-recipes",
        type = "item-subgroup",
        group = "ei-nuclear",
        order = "f",
    },

    -- alien group
    {
        name = "ei-alien",
        type = "item-group",
        icon = ei_graphics_other_path.."alien-group.png",
        icon_size = 128,
        inventory_order = "z",
        order = "z",
    },
    {
        name = "ei-alien-structures",
        type = "item-subgroup",
        group = "ei-alien",
        order = "a-a",
    },
    {
        name = "ei-alien-structures-2",
        type = "item-subgroup",
        group = "ei-alien",
        order = "a-b",
    },
    {
        name = "ei-alien-items",
        type = "item-subgroup",
        group = "ei-alien",
        order = "b-a",
    },
    {
        name = "ei-alien-items-2",
        type = "item-subgroup",
        group = "ei-alien",
        order = "b-b",
    },
    {
        name = "ei-alien-intermediates",
        type = "item-subgroup",
        group = "ei-alien",
        order = "c",
    },
    {
        name = "ei-alien-bio",
        type = "item-subgroup",
        group = "ei-alien",
        order = "d",
    },
    {
        name = "ei-black-hole",
        type = "item-subgroup",
        group = "ei-alien",
        order = "e",
    },
    {
        name = "ei-repairs",
        type = "item-subgroup",
        group = "ei-alien",
        order = "f",
    },

    -- fuel categories
    {
        name = "ei-diesel-fuel",
        type = "fuel-category",
    },
    {
        name = "ei-rocket-fuel",
        type = "fuel-category",
    },
    {
        name = "ei-nuclear-fuel",
        type = "fuel-category",
    },
    {
        name = "ei-fusion-fuel",
        type = "fuel-category",
    },

    -- other
    {
        name = "ei-holo",
        type = "item-subgroup",
        group = "production",
        order = "h",
    },
    {
        name = "ei-induction-matrix",
        type = "item-subgroup",
        group = "production",
        order = "i",
    },
})

if not data.raw["item-subgroup"]["loader"] then 
  data:extend{
    {
      type = "item-subgroup",
      name = "loader",
      group = "logistics",
      order = "b[belt]-d"
    },
  }
end