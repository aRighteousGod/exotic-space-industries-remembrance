--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["Teleporters"] then
    return
end
--====================================================================================================
local ei_lib = require("lib/lib")
local ei_data = require("lib/data")


--====================================================================================================
--CHANGES
--====================================================================================================

-- tech changes
data.raw.technology["teleporter"].prerequisites = {"ei-high-energy-crystal", "ei-computer-core"}
data.raw.technology["teleporter"].age = "computer-age"

-- recipe changes
data.raw.recipe["teleporter"].ingredients = {
    {type = "item", name = "ei-alien-resin", amount = 25},
    {type = "item", name = "ei-simulation-data", amount = 20},
    {type = "item", name = "ei-high-energy-crystal", amount = 10},
}