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
      fulgora_cliff        = {},
      fulgora_islands      = {},
      scrap                = {frequency = 0.05, richness = 0.05, size = 0.05 },
    },
    autoplace_settings = {
      decorative = {
        settings = {
          ["fulgoran-gravewort"]  = {},
          ["fulgoran-ruin-tiny"]  = {},
          ["medium-fulgora-rock"] = {},
          ["small-fulgora-rock"]  = {},
          ["tiny-fulgora-rock"]   = {},
          ["urchin-cactus"]       = {},
        },
      },
      entity = {
        settings = {
          ["big-fulgora-rock"]        = {},
          ["ei-ammonia-patch"]        = { frequency = 5, richness = 1, size = 1 },
          ["ei-coal-gas-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["ei-cryoflux-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["ei-morphium-patch"]       = { frequency = 5, richness = 1, size = 1 },
          ["ei-phytogas-patch"]       = { frequency = 5, richness = 1, size = 1 },
          scrap                       = {frequency = 0.25, richness = 0.25, size = 0.25 },
        },
      },
      tile = {
        settings = {
          ["ei-gaia-grass-1"]       = {},
          ["ei-gaia-grass-1-var"]   = {},
          ["ei-gaia-grass-2"]       = {},
          ["ei-gaia-grass-2-var"]   = {},
          ["ei-gaia-grass-2-var-2"] = {},
          ["ei-gaia-rock-1"]        = {},
          ["ei-gaia-rock-2"]        = {},
          ["ei-gaia-rock-3"]        = {},
          ["ei-gaia-water"]         = {},
        },
      },
    },
    cliff_settings = {
      cliff_elevation_0       = 0,
      cliff_elevation_interval= 0,
      cliff_smoothing         = 0,
      control                 = "fulgora_cliff",
      name                    = "cliff-fulgora",
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