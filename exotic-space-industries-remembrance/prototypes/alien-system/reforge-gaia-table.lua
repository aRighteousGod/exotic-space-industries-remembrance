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
          ["electric_enemies"]       = { frequency = 1, richness = 1, size = 1 },
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
      cliff_elevation_0       = 0,
      cliff_elevation_interval= 0,
      cliff_smoothing         = 0,
      control                 = "gaia_cliff",
      name                    = "cliff-gaia",
      richness                = 0,
    },
    property_expression_names = {
      aux             = "aux_basic",
      cliff_elevation = "cliff_elevation_from_elevation",
      cliffiness      = "fulgora_cliffiness",
      elevation       = "fulgora_elevation",
      moisture        = "moisture_basic",
      temperature     = "temperature_basic",
    },
  }

return  model