--====================================================================================================
--PRE INIT
--====================================================================================================

-- info

ei_mod = {}
ei_mod.stage = "data"

ei_mod.dev_mode = false
ei_mod.show_temp = false
ei_mod.show_dummy = false
ei_mod.show_exotic_gates = true

-- lib and paths

require("lib/paths")

ei_lib = require("lib/lib")
ei_data = require("lib/data")

-- base globals
sounds = require("__base__.prototypes.entity.sounds")
hit_effects = require("__base__.prototypes.entity.hit-effects")
item_sounds = require("__base__.prototypes.item_sounds")
item_tints = require("__base__.prototypes.item-tints")
simulations = require("__base__.prototypes.factoriopedia-simulations")

--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

-- add new categories, entities, items, techs, recipes fluids, resources

require("prototypes/pipe-covers")
require("prototypes/other")
require("prototypes/fluids")
require("prototypes/styles")
require("prototypes/informatron-sprites")
require("prototypes/age-techs")
require("prototypes/containers")

require("prototypes/dark-age/dark-age")
require("prototypes/steam-age/steam-age")
require("prototypes/electricity-age/electricity-age")
require("prototypes/computer-age/computer-age")
require("prototypes/quantum-age/quantum-age")
require("prototypes/alien-system/alien-system")
require("prototypes/planet-gaia/gaia")
require("prototypes/exotic-age/exotic-age")
require("prototypes/electricity-age/robots")
require("prototypes/planet-gleba/gleba")
require("prototypes/loaders")
require("prototypes/more-asteroids")
require("prototypes/productivity")
require("teslas_legacy.data")
--====================================================================================================
--COMPATIBILITY CODE
--====================================================================================================

alien_biomes_priority_tiles = alien_biomes_priority_tiles or {}
table.insert(alien_biomes_priority_tiles, "ei-induction-matrix-tile")

--====================================================================================================

-- dummy lab so that Factorio doesn't complain about there being no lab that can handle techs

data:extend({
  {
    name = "ei-dummy-lab",
    type = "lab",
    energy_source = {type = "void"},
    energy_usage = "1J",
    inputs = {},
  }
})

--====================================================================================================

alien_biomes_priority_tiles = alien_biomes_priority_tiles or {}

-- error(data.raw.tile)

for _,tile in pairs(data.raw.tile) do 
  if ei_lib.contains(tile.name,"gaia") then 
    table.insert(alien_biomes_priority_tiles, tile.name)
  end 
  if ei_lib.contains(tile.name,"induction-matrix") then 
    table.insert(alien_biomes_priority_tiles, tile.name)
  end 
end

-- ei_lib.sb(alien_biomes_priority_tiles)
