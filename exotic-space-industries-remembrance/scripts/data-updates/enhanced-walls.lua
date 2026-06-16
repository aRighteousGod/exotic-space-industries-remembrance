--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

--fire extinguisher
if not mods["enhanced-walls"] then
    return
end

ei_lib = require("lib/lib")
local ei_data = require("lib/data")

local late_wall_graphics_path = ei_graphics_entity_4_path.."walls/"

local function make_wall_pictures(wall_name)
    local graphics_name = wall_name:gsub("^ei%-", "")
    local path = late_wall_graphics_path..graphics_name.."/"

    return {
      single =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-single.png",
            priority = "extra-high",
            width = 64,
            height = 86,
            variation_count = 2,
            line_length = 2,
            shift = util.by_pixel(0, -5),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-single-shadow.png",
            priority = "extra-high",
            width = 98,
            height = 60,
            repeat_count = 2,
            shift = util.by_pixel(10, 17),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      straight_vertical =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-vertical.png",
            priority = "extra-high",
            width = 64,
            height = 134,
            variation_count = 5,
            line_length = 5,
            shift = util.by_pixel(0, 8),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-vertical-shadow.png",
            priority = "extra-high",
            width = 98,
            height = 110,
            repeat_count = 5,
            shift = util.by_pixel(10, 29),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      straight_horizontal =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-horizontal.png",
            priority = "extra-high",
            width = 64,
            height = 92,
            variation_count = 6,
            line_length = 6,
            shift = util.by_pixel(0, -2),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-horizontal-shadow.png",
            priority = "extra-high",
            width = 124,
            height = 68,
            repeat_count = 6,
            shift = util.by_pixel(14, 15),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      corner_right_down =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-corner-right.png",
            priority = "extra-high",
            width = 64,
            height = 128,
            variation_count = 2,
            line_length = 2,
            shift = util.by_pixel(0, 7),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-corner-right-shadow.png",
            priority = "extra-high",
            width = 124,
            height = 120,
            repeat_count = 2,
            shift = util.by_pixel(17, 28),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      corner_left_down =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-corner-left.png",
            priority = "extra-high",
            width = 64,
            height = 134,
            variation_count = 2,
            line_length = 2,
            shift = util.by_pixel(0, 7),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-corner-left-shadow.png",
            priority = "extra-high",
            width = 102,
            height = 120,
            repeat_count = 2,
            shift = util.by_pixel(9, 28),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      t_up =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-t.png",
            priority = "extra-high",
            width = 64,
            height = 134,
            variation_count = 4,
            line_length = 4,
            shift = util.by_pixel(0, 7),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-t-shadow.png",
            priority = "extra-high",
            width = 124,
            height = 120,
            repeat_count = 4,
            shift = util.by_pixel(14, 28),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      ending_right =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-ending-right.png",
            priority = "extra-high",
            width = 64,
            height = 92,
            variation_count = 2,
            line_length = 2,
            shift = util.by_pixel(0, -3),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-ending-right-shadow.png",
            priority = "extra-high",
            width = 124,
            height = 68,
            repeat_count = 2,
            shift = util.by_pixel(17, 15),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      ending_left =
      {
        layers =
        {
          {
            filename = path..graphics_name.."-ending-left.png",
            priority = "extra-high",
            width = 64,
            height = 92,
            variation_count = 2,
            line_length = 2,
            shift = util.by_pixel(0, -3),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-ending-left-shadow.png",
            priority = "extra-high",
            width = 102,
            height = 68,
            repeat_count = 2,
            shift = util.by_pixel(9, 15),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      filling =
      {
        filename = path..graphics_name.."-filling.png",
        priority = "extra-high",
        width = 48,
        height = 56,
        variation_count = 8,
        line_length = 8,
        shift = util.by_pixel(0, -1),
        scale = 0.5
      },
      water_connection_patch =
      {
        sheets =
        {
          {
            filename = path..graphics_name.."-patch.png",
            priority = "extra-high",
            width = 116,
            height = 128,
            shift = util.by_pixel(0, -2),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-patch-shadow.png",
            priority = "extra-high",
            width = 144,
            height = 100,
            shift = util.by_pixel(9, 15),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      },
      gate_connection_patch =
      {
        sheets =
        {
          {
            filename = path..graphics_name.."-gate.png",
            priority = "extra-high",
            width = 82,
            height = 108,
            shift = util.by_pixel(0, -7),
            scale = 0.5
          },
          {
            filename = "__base__/graphics/entity/wall/wall-gate-shadow.png",
            priority = "extra-high",
            width = 130,
            height = 78,
            shift = util.by_pixel(14, 18),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      }
    }
end

local function make_late_wall(opts)
    local name = opts.name
    local graphics_name = name:gsub("^ei%-", "")
    local icon = ei_graphics_item_4_path..graphics_name..".png"
    local tech_icon = ei_graphics_tech_4_path..graphics_name..".png"

    local wall = table.deepcopy(ei_lib.raw.wall["plated-wall"])
    wall.name = name
    wall.icon = icon
    wall.icon_size = 64
    wall.minable = {mining_time = 0.2, result = name}
    wall.max_health = opts.health
    wall.corpse = name.."-remnants"
    wall.localised_name = {"item-name."..name}
    wall.localised_description = {"item-description."..name}
    wall.pictures = make_wall_pictures(name)
    wall.resistances = opts.resistances
    wall.healing_per_tick = opts.healing_per_tick

    local remnants = table.deepcopy(ei_lib.raw.corpse["plated-wall-remnants"] or ei_lib.raw.corpse["wall-remnants"])
    remnants.name = name.."-remnants"

    local item = table.deepcopy(ei_lib.raw.item["plated-wall"])
    item.name = name
    item.localised_name = {"item-name."..name}
    item.localised_description = {"item-description."..name}
    item.icon = icon
    item.icon_size = 64
    item.place_result = name
    item.subgroup = "defensive-structure"
    item.order = opts.order

    local recipe = {
        name = name,
        type = "recipe",
        category = opts.category,
        energy_required = opts.energy_required,
        localised_name = {"item-name."..name},
        subgroup = "defensive-structure",
        order = opts.order,
        ingredients = opts.ingredients,
        results = {{type = "item", name = name, amount = 1}},
        enabled = false,
        always_show_made_in = true,
        main_product = name,
    }

    local tech = {
        name = name,
        type = "technology",
        icon = tech_icon,
        icon_size = 256,
        localised_name = {"technology-name."..name},
        localised_description = {"technology-description."..name},
        prerequisites = opts.prerequisites,
        effects = {
            {
                type = "unlock-recipe",
                recipe = name,
            },
        },
        unit = {
            count = opts.tech_count,
            ingredients = ei_data.science[opts.age],
            time = 30,
        },
        age = opts.age,
    }

    data:extend({wall, remnants, item, recipe, tech})
end

--tough wall
local twi = ei_lib.raw.item["tough-wall"]
twi.subgroup = "defensive-structure"
twi.order = "a[stone-wall]-a[stone-wall]2"
twi.localised_name = {"item-name.ei-tough-wall"}
twi.localised_description = {"item-description.ei-tough-wall"}
local twt = ei_lib.raw.technology["tough-wall"]
twt.localised_name = {"item-name.ei-tough-wall"}
twt.localised_description = {"item-description.ei-tough-wall"}
local twr = ei_lib.raw.recipe["tough-wall"]
twr.energy_required = 2
twr.localised_name = {"item-name.ei-tough-wall"}
ei_lib.set_prerequisites("tough-wall",{"stone-wall","military-2","concrete","steel-processing","electronics"})
ei_lib.set_age_packs("tough-wall","steam-age")
ei_lib.recipe_new("tough-wall",{
    {type="item", name="stone-wall", amount=1},
    {type="item", name="ei-steel-beam", amount=2},
    {type="item", name="ei-ceramic", amount=2},
    {type="item", name="concrete", amount=4},
})
local tw = ei_lib.raw.wall["tough-wall"]
tw.localised_name = {"item-name.ei-tough-wall"}
tw.localised_description = {"item-description.ei-tough-wall"}
tw.resistances = {
  {
    type = "physical",
    decrease = 10,
    percent = 45
  },
  {
    type = "impact",
    decrease = 70,
    percent = 70
  },
  {
    type = "explosion",
    decrease = 20,
    percent = 45
  },
  {
    type = "fire",
    percent = 100
  },
  {
    type = "acid",
    decrease = 10,
    percent = 85
  },
  {
    type = "cold",
    decrease = 10,
    percent = 75
  },
  {
    type = "laser",
    percent = 80,
    decrease = 2,
  }
}

make_late_wall({
    name = "ei-sanguine-wall",
    order = "a[stone-wall]-a[stone-wall]4",
    health = 1800,
    category = "crafting",
    energy_required = 8,
    age = "quantum-age",
    tech_count = 10,
    prerequisites = {"plated-wall", "ei-odd-plating", "military-5"},
    ingredients = {
        {type = "item", name = "plated-wall", amount = 1},
        {type = "item", name = "ei-odd-plating", amount = 2},
        {type = "item", name = "ei-carbon-structure", amount = 2},
        {type = "item", name = "ei-alien-resin", amount = 8},
    },
    resistances = {
      {
        type = "physical",
        decrease = 28,
        percent = 76
      },
      {
        type = "impact",
        decrease = 110,
        percent = 88
      },
      {
        type = "explosion",
        decrease = 50,
        percent = 68
      },
      {
        type = "fire",
        percent = 100
      },
      {
        type = "acid",
        decrease = 26,
        percent = 92
      },
      {
        type = "cold",
        decrease = 26,
        percent = 88
      },
      {
        type = "laser",
        percent = 90,
        decrease = 6,
      }
    },
})

make_late_wall({
    name = "ei-hemocrystal-wall",
    order = "a[stone-wall]-a[stone-wall]5",
    health = 2200,
    category = "crafting-with-fluid",
    energy_required = 16,
    age = "exotic-age",
    tech_count = 10,
    prerequisites = {"ei-sanguine-wall", "ei-clean-plating", "ei-exotic-age"},
    ingredients = {
        {type = "item", name = "ei-sanguine-wall", amount = 1},
        {type = "item", name = "ei-clean-plating", amount = 2},
        {type = "item", name = "ei-bio-matter", amount = 10},
        {type = "item", name = "ei-high-energy-crystal", amount = 1},
        {type = "fluid", name = "ei-concentrated-morphium", amount = 25},
    },
    resistances = {
      {
        type = "physical",
        decrease = 34,
        percent = 82
      },
      {
        type = "impact",
        decrease = 125,
        percent = 90
      },
      {
        type = "explosion",
        decrease = 60,
        percent = 75
      },
      {
        type = "fire",
        percent = 100
      },
      {
        type = "acid",
        decrease = 32,
        percent = 94
      },
      {
        type = "cold",
        decrease = 32,
        percent = 92
      },
      {
        type = "laser",
        percent = 92.5,
        decrease = 8,
      }
    },
})

--plated wall
local pwi = ei_lib.raw.item["plated-wall"]
pwi.subgroup = "defensive-structure"
pwi.order = "a[stone-wall]-a[stone-wall]3"
pwi.localised_name = {"item-name.ei-plated-wall"}
pwi.localised_description = {"item-description.ei-plated-wall"}
local pwt = ei_lib.raw.technology["plated-wall"]
pwt.localised_name = {"item-name.ei-plated-wall"}
pwt.localised_description = {"item-description.ei-plated-wall"}
local pwr = ei_lib.raw.recipe["plated-wall"]
pwr.energy_required = 4
pwr.localised_name = {"item-name.ei-plated-wall"}
ei_lib.set_prerequisites("plated-wall",{"tough-wall","military-3","plastics"})
ei_lib.set_age_packs("plated-wall","electricity-age")
ei_lib.recipe_new("plated-wall",{
    {type="item", name="tough-wall", amount=1},
    {type="item", name="ei-lead-ingot", amount=3},
    {type="item", name="plastic-bar", amount=2},
    {type="item", name="refined-concrete", amount=4},
})
local pw = ei_lib.raw.wall["plated-wall"]
pw.localised_name = {"item-name.ei-plated-wall"}
pw.localised_description = {"item-description.ei-plated-wall"}
pw.resistances = {
  {
    type = "physical",
    decrease = 20,
    percent = 70
  },
  {
    type = "impact",
    decrease = 95,
    percent = 85
  },
  {
    type = "explosion",
    decrease = 40,
    percent = 60
  },
  {
    type = "fire",
    percent = 100
  },
  {
    type = "acid",
    decrease = 20,
    percent = 90
  },
  {
    type = "cold",
    decrease = 20,
    percent = 85
  },
  {
    type = "laser",
    percent = 87.5,
    decrease = 4,
  }
}
