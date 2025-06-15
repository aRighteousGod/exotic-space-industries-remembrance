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

--====================================================================================================
--MAIN CONTENT CODE
--====================================================================================================

--require("prototypes/_K2_/data")

-- add new categories, entities, items, techs, recipes fluids, resources

require("prototypes/pipe-covers")
require("prototypes/other")
require("prototypes/fluids")
require("prototypes/styles")
require("prototypes/informatron_sprites")
require("prototypes/age_techs")
require("prototypes/containers")
require("prototypes/dark_age/dark_age")
require("prototypes/steam_age/steam_age")
require("prototypes/electricity_age/electricity_age")
require("prototypes/computer_age/computer_age")
require("prototypes/quantum_age/quantum_age")
require("prototypes/alien_structures/alien_structures")
require("prototypes/exotic_age/exotic_age")
require("prototypes/electricity_age/robots")
require("prototypes/loaders")
--These use overrides, keep them after
--[[
if ei_lib.config("slag") then
    require("prototypes/slag")
end
if ei_lib.config("ei-ash") then
    require("prototypes/ash")
end
]]
--====================================================================================================
--COMPATIBILITY CODE
--====================================================================================================

alien_biomes_priority_tiles = alien_biomes_priority_tiles or {}
table.insert(alien_biomes_priority_tiles, "ei-induction-matrix-tile")
table.insert(alien_biomes_priority_tiles, "ei-gaia-rock-3")
table.insert(alien_biomes_priority_tiles, "ei-gaia-rock-2")
table.insert(alien_biomes_priority_tiles, "ei-gaia-rock-1")
table.insert(alien_biomes_priority_tiles, "ei-gaia-grass-2_var")
table.insert(alien_biomes_priority_tiles, "ei-gaia-grass-2")
table.insert(alien_biomes_priority_tiles, "ei-gaia-grass-1_var")
table.insert(alien_biomes_priority_tiles, "ei-gaia-grass-1")

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