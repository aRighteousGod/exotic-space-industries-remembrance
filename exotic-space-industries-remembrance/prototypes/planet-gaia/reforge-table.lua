-- Used if gaia spawned in malformed, called in nth tick and/or reforge_gaia
local model = {
    name= "gaia",
    default_enable_all_autoplace_controls = false,
    terrain_segmentation = 0.75,
    water = "ei-gaia-water",
    autoplace_controls = {
      ["ei-ammonia-patch"] = { frequency = 5, richness = 1, size = 1 },
      ["ei-coal-gas-patch"] = { frequency = 5, richness = 1, size = 1 },
      ["ei-cryoflux-patch"] = { frequency = 5, richness = 1, size = 1 },
      ["ei-morphium-patch"] = { frequency = 5, richness = 1, size = 1 },
      ["ei-phytogas-patch"] = { frequency = 5, richness = 1, size = 1 },
      ["gaia_water"]        = { frequency = 1, size = 1 },
      ["gaia_trees"]        = { frequency = 1, size = 1 },
      ["gaia_meadow"]       = { frequency = 1, size = 1 },
      ["gaia_wetlands"]     = { frequency = 1, size = 1 },
      ["gaia_rocks"]        = { frequency = 1, size = 1 },
      ["gaia_boulders"]     = { frequency = 1, size = 1 },
      ["gaia_decoratives"]  = { frequency = 1, size = 1 },
      ["gaia_cliff"]        = {},
      ["scrap"]             = {frequency = 0.05, richness = 0.05, size = 0.05 },
      ["electric_enemies"]  = { frequency = 1, richness = 1, size = 1 },
      },
    autoplace_settings = {
      decorative = {
        settings = {
        },
      },
      entity = {
        settings = {
          ["ei-ammonia-patch"]        = { frequency = 5, richness = 1, size = 1 },
          ["ei-coal-gas-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["ei-cryoflux-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["ei-morphium-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["ei-phytogas-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["scrap"]                   = {frequency = 0.05, richness = 0.05, size = 0.05 },
          ["ei-gaia-tree-01"]         = { frequency = 1.4, richness = 1, size = 0.85 },
          ["ei-gaia-tree-02"]         = { frequency = 1.15, richness = 1, size = 0.75 },
          ["ei-gaia-tree-03"]         = { frequency = 1.0, richness = 1, size = 0.65 },
          ["ei-gaia-tree-04"]         = { frequency = 0.8, richness = 1, size = 0.6 },
          ["ei-gaia-tree-05"]         = { frequency = 0.55, richness = 1, size = 0.5 },
          ["ei-gaia-tree-06"]         = { frequency = 0.7, richness = 1, size = 0.55 },
          ["ei-gaia-boulder-big"]     = { frequency = 0.28, richness = 1, size = 0.5 },
          ["ei-gaia-crystal-boulder"] = { frequency = 0.08, richness = 1, size = 0.25 },
          ["flying-electric-unit-spawner"] = {},
          ["walker-electric-unit-spawner"] = {},
          --[[
          ["ei-alien-flowers-1"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-2"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-3"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-4"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-5"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-6"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-7"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-8"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-9"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-10"] = {frequency = 1, size = 4, richness = 1},
          ["ei-alien-flowers-11"] = {frequency = 1, size = 4, richness = 1}
          ]]
        },
      },
      tile = {
        settings = {
          ["ei-gaia-grass-1"]       = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-grass-1-var"]   = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-grass-2"]       = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-grass-2-var"]   = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-grass-2-var-2"] = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-rock-1"]        = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-rock-2"]        = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-rock-3"]        = { frequency = 1, richness = 1, size = 1 },
          ["ei-gaia-water"]         = { frequency = 1, richness = 1, size = 1 },
        },
      },
    },
    cliff_settings = {
      cliff_elevation_0       = 18,
      cliff_elevation_interval= 80,
      cliff_smoothing         = 0.15,
      control                 = "gaia_cliff",
      name                    = "cliff-gaia",
      richness                = 0.35,
    },
    property_expression_names = {
      -- Match Gaia's main map-gen climate: rebuilt surfaces must keep water, biome, and
      -- vegetation state on the same Gaia-owned expression family.
      aux             = "gaia_aux",
      cliff_elevation = "cliff_elevation_from_elevation",
      cliffiness      = "gaia_cliffiness",
      elevation       = "gaia_elevation",
      moisture        = "gaia_moisture",
      temperature     = "gaia_temperature",
    },
  }

return  model
