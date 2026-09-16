--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

-- Assault's optional Enhancements bridge copies a nil fuel size from a void
-- vanilla spider. Repair it before Enhancements clones its dummy prototypes.
if mods["SpidertronEnhancements"] then
    local assault=data.raw["spider-vehicle"].assault_spidertron
    if assault and assault.energy_source.type=="burner" then
        assault.energy_source.fuel_inventory_size=assault.energy_source.fuel_inventory_size or 2
    end
end

if not mods["SpidertronPatrols"] then
    return
end
--====================================================================================================

local ei_lib = require("lib/lib")
local ei_data = require("lib/data")


--====================================================================================================
--CHANGES
--====================================================================================================

-- remove guns from spiderling
data.raw["spider-vehicle"]["sp-spiderling"].guns = {}

-- change spiderling tech
data.raw["technology"]["sp-spiderling"].prerequisites = {"advanced-circuit", "military-3", "ei-grower"}
data.raw["technology"]["sp-spiderling"].age = "electricity-age"

ei_lib.recipe_new("sp-spiderling", {
    {type="item", name="advanced-circuit", amount=10},
    {type="item", name="ei-energy-crystal", amount=20},
    {type="item", name="electric-engine-unit", amount=20},
    {type="item", name="ei-steel-mechanical-parts", amount=45},
    {type="item", name="radar", amount=6},
})

-- adjust spidertron automation tech
data.raw["technology"]["sp-spidertron-automation"].prerequisites = {"sp-spiderling", "logistic-robotics", "construction-robotics", "ei-electronic-parts"}

ei_lib.recipe_new("sp-spidertron-dock", {
    {type="item", name="ei-electronic-parts", amount=10},
    {type="item", name="radar", amount=1},
    {type="item", name="steel-plate", amount=6},
    {type="item", name="ei-copper-mechanical-parts", amount=12},
})

-- adjust the optional spiderling trunk
data.raw["spider-vehicle"]["sp-spiderling"].inventory_size = 20
