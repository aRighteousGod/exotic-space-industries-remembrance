
--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["ch-concentrated-solar"] then
    return
end
--====================================================================================================
local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

-- 0.6.0 still places the 10 C input floor on the removed FluidBox field.
-- Keep energy-conversion maximum_temperature separate from admission limits.
-- Native 2.1 storage may hold colder solar fluid, but the consumer must not burn it.
local tower_source = data.raw.reactor["chcs-solar-power-tower"].energy_source
local tower_box = tower_source.fluid_box
for _, bound in ipairs({"minimum", "maximum"}) do
    local old_key, new_key = bound .. "_temperature", bound .. "_input_temperature"
    if tower_box[old_key] ~= nil then
        if tower_source[new_key] == nil then tower_source[new_key] = tower_box[old_key] end
        tower_box[old_key] = nil
    end
end


--====================================================================================================
--CHANGES
--====================================================================================================
ei_lib.remove_unlock_recipe("chcs-concentrated-solar-energy","steam-turbine")
ei_lib.remove_unlock_recipe("chcs-concentrated-solar-energy","heat-exchanger")
ei_lib.remove_unlock_recipe("chcs-concentrated-solar-energy","heat-pipe")


ei_lib.raw.technology["chcs-concentrated-solar-energy"].age = "steam-age"
ei_lib.raw.technology["chcs-concentrated-solar-energy"].prerequisites = {
    "ei-burner-heater",
    "electronics"
}

ei_lib.raw.technology["chcs-weaponized-solar-energy"].age = "steam-age"
ei_lib.raw.technology["chcs-weaponized-solar-energy"].prerequisites = {
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

