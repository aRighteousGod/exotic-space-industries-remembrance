--===========================================================================================
--Productivity technology
local formula = "100 * (1 + 0.15 * L)" --1.5&L*500 fucklot
data:extend({
{
	type = "technology",
	name = "ei-productivity-slag-chunk-extraction",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png", 
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-slag-extraction-morphium",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-slag-extraction-sulfuric",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-slag-extraction-nitric",
        change = 0.1
      },
    },
    prerequisites = {"ei-morphium-usage","ei-nitric-acid","ei-purifier","ei-advanced-computer-age-tech"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["advanced-computer-age"],
      time = 20
    },
    max_level = 5,
    upgrade = true,
    age = "advanced-computer-age",
	},
{
	type = "technology",
	name = "ei-productivity-dirty-water-usage",
	icon = ei_graphics_tech_path.."morphium-usage.png", --used to be named dirty-water-usage.png ...
    icon_size = 128,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-dirty-water-iron-extraction",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-dirty-water-copper-extraction",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-dirty-water-lead-extraction",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-dirty-water-uranium-extraction",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-dirty-water-gold-extraction",
        change = 0.1
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-dirty-water-copper-extraction",
        change = 0.1
      }
    },
    prerequisites = {"ei-dirty-water-usage","ei-neodym-dirty-water-usage"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["quantum-age"],
      time = 20
    },
    max_level = "infinite",
    upgrade = true,
    age = "quantum-age",
	},
{
	type = "technology",
	name = "ei-productivity-morphium-usage",
	icon = ei_graphics_3_path.."graphics/tech/morphium-usage.png",
    icon_size = 128,
    icon_mipmaps = 3,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-iron-extraction",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-extraction",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-lead-extraction",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-uranium-extraction",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-stone-extraction",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-gold-extraction",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-sulfur-extraction",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-extraction",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-concentrated-morphium",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-water",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-concentrated-morphium-light-oil",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-concentrated-morphium-kerosene",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-concentrated-morphium-heavy-oil",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-concentrated-morphium-lubricant",
        change = 0.1
		}
    
    },
    prerequisites = {"ei-morphium-usage","ei-morphium-usage-petro"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["alien-computer-age"],
      time = 20
    },
    max_level = "infinite",
    upgrade = true,
    age = "alien-computer-age",
	},
{
	type = "technology",
	name = "ei-productivity-pure-ore-smelting",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
    {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-ore",
        change = 0.05
      },
	  {
	    	type = "change-recipe-productivity",
        recipe = "ei-molten-iron-ore",
        change = 0.05
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-iron-pure-ore",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-gold-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-lead-pure-ore",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-neodym",
        change = 0.1
		},
    },
    prerequisites = {"ei-arc-furnace","ei-computer-age"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["computer-age"],
      time = 20
    },
    max_level = 2,
    upgrade = true,
    age = "computer-age",
	},
{
	type = "technology",
	name = "ei-productivity-pure-ore-smelting-advanced",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
    {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-ore",
        change = 0.05
      },
	  {
	    	type = "change-recipe-productivity",
        recipe = "ei-molten-iron-ore",
        change = 0.05
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-iron-pure-ore",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-gold-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-lead-pure-ore",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-neodym",
        change = 0.1
		},
    },
    prerequisites = {"ei-advanced-computer-age-tech","ei-productivity-pure-ore-smelting"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["advanced-computer-age"],
      time = 20
    },
    max_level = 2,
    upgrade = true,
    age = "advanced-computer-age",
	},
{
	type = "technology",
	name = "ei-productivity-pure-ore-smelting-quantum",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
    {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-ore",
        change = 0.05
      },
	  {
	    	type = "change-recipe-productivity",
        recipe = "ei-molten-iron-ore",
        change = 0.05
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-iron-pure-ore",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-gold-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-lead-pure-ore",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-neodym",
        change = 0.1
		},
    },
    prerequisites = {"ei-advanced-computer-age-tech","ei-productivity-pure-ore-smelting-advanced"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["quantum-age"],
      time = 20
    },
    max_level = 2,
    upgrade = true,
    age = "quantum-age",
	},
{
	type = "technology",
	name = "ei-productivity-pure-ore-smelting-exotic",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
      icon_mipmaps = 4,
    effects =
    {
    {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-ore",
        change = 0.05
      },
	  {
	    	type = "change-recipe-productivity",
        recipe = "ei-molten-iron-ore",
        change = 0.05
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-iron-pure-ore",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-gold-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-lead-pure-ore",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-neodym",
        change = 0.1
		},
    },
    prerequisites = {"ei-exotic-age","ei-productivity-pure-ore-smelting-quantum"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["exotic-age"],
      time = 20
    },
    max_level = 2,
    upgrade = true,
    age = "exotic-age",
	},
{
	type = "technology",
	name = "ei-productivity-pure-ore-smelting-black-hole",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
    {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-ore",
        change = 0.05
      },
	  {
	    	type = "change-recipe-productivity",
        recipe = "ei-molten-iron-ore",
        change = 0.05
      },
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-copper-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-iron-pure-ore",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-molten-gold-pure-ore",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-lead-pure-ore",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-molten-neodym",
        change = 0.1
		},
    },
    prerequisites = {"ei-black-hole","ei-productivity-pure-ore-smelting-exotic"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["black-hole-exotic-age"],
      time = 20
    },
    max_level = "infinite",
    upgrade = true,
    age = "black-hole-exotic-age",
	},
{
	type = "technology",
	name = "ei-productivity-ore-purification",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-iron-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-chunk-purifier",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-gold-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-lead-chunk-purifier",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-pure-crushed-neodym",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-crushed-pure-uranium",
        change = 0.1
		},
    },
    prerequisites = {"ei-purifier","ei-computer-age"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["computer-age"],
      time = 20
    },
    max_level = 5,
    upgrade = true,
    age = "computer-age",
	},
{
	type = "technology",
	name = "ei-productivity-ore-purification-simulation",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-iron-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-chunk-purifier",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-gold-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-lead-chunk-purifier",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-pure-crushed-neodym",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-crushed-pure-uranium",
        change = 0.1
		},
    },
    prerequisites = {"ei-productivity-ore-purification","ei-advanced-computer-age-tech"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["advanced-computer-age"],
      time = 20
    },
    max_level = 5,
    upgrade = true,
    age = "advanced-computer-age",
	},
{
	type = "technology",
	name = "ei-productivity-ore-purification-quantum",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-iron-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-chunk-purifier",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-gold-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-lead-chunk-purifier",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-pure-crushed-neodym",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-crushed-pure-uranium",
        change = 0.1
		},
    },
    prerequisites = {"ei-productivity-ore-purification-simulation","ei-quantum-age"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["quantum-age"],
      time = 20
    },
    max_level = 5,
    upgrade = true,
    age = "quantum-age",
	},
{
	type = "technology",
	name = "ei-productivity-ore-purification-exotic",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-iron-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-chunk-purifier",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-gold-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-lead-chunk-purifier",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-pure-crushed-neodym",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-crushed-pure-uranium",
        change = 0.1
		},
    },
    prerequisites = {"ei-productivity-ore-purification-quantum","ei-exotic-age"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["exotic-age"],
      time = 20
    },
    max_level = 5,
    upgrade = true,
    age = "exotic-age",
	},
{
	type = "technology",
	name = "ei-productivity-ore-purification-black-hole",
	icon = ei_graphics_3_path.."graphics/tech/ore-purification-productivity.png",
    icon_size = 256,
    icon_mipmaps = 4,
    effects =
    {
      {
        type = "change-recipe-productivity",
        recipe = "ei-iron-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-copper-chunk-purifier",
        change = 0.1
		},
      {
        type = "change-recipe-productivity",
        recipe = "ei-gold-chunk-purifier",
        change = 0.1
      },
	  {
		type = "change-recipe-productivity",
        recipe = "ei-lead-chunk-purifier",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-pure-crushed-neodym",
        change = 0.1
		},
	  {
		type = "change-recipe-productivity",
        recipe = "ei-crushed-pure-uranium",
        change = 0.1
		},
    },
    prerequisites = {"ei-productivity-ore-purification-exotic","ei-black-hole"},
    unit =
    {
      count_formula = formula,
      ingredients = ei_data.science["black-hole-exotic-age"],
      time = 20
    },
    max_level = "infinite",
    upgrade = true,
    age = "black-hole-exotic-age",
	},
})