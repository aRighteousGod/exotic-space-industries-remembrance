
--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["ch-concentrated-solar"] then
    return
end
--====================================================================================================
local ei_lib = require("lib/lib")
local ei_data = require("lib/data")


--====================================================================================================
--CHANGES
--====================================================================================================
ei_lib.remove_unlock_recipe("chcs-concentrated-solar-energy","steam-turbine")

data.raw.technology["chcs-concentrated-solar-energy"].age = "steam-age"
data.raw.technology["chcs-concentrated-solar-energy"].prerequisites = {
    "ei-burner-heater",
    "electronics"
}

data.raw.technology["chcs-weaponized-solar-energy"].age = "steam-age"
data.raw.technology["chcs-weaponized-solar-energy"].prerequisites = {
    "chcs-concentrated-solar-energy",
    "flammables"
}

ei_lib.recipe_new("chcs-heliostat-mirror", {
    {type="item", name="electronic-circuit", amount=2},
    {type="item", name="ei-glass", amount=10},
    {type="item", name="ei-iron-mechanical-parts", amount=4}
})

ei_lib.recipe_new("chcs-solar-power-tower", {
    {type="item", name="electronic-circuit", amount=5},
    {type="item", name="ei-burner-heater", amount=2},
    {type="item", name="ei-basic-heat-pipe", amount=10},
    {type="item", name="ei-iron-mechanical-parts", amount=24},
    {type="item", name="ei-iron-beam", amount=12}
})

ei_lib.recipe_new("chcs-solar-laser-tower", {
    {type="item", name="chcs-solar-power-tower", amount=1},
    {type="item", name="steel-plate", amount=24},
    {type="item", name="gun-turret", amount=2},
    {type="item", name="ei-steel-mechanical-parts", amount=12},
    {type="item", name="ei-steel-beam", amount=12}
})

