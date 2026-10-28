--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["atan-ash-fork"] then
    return
end

local ei_lib = require("lib/lib")

-- atan-ash-fork 1.0.1 still reads the removed singular fuel_category. Retain
-- Ash's item/capsule policy with native array membership before ESIR's later
-- fuel exclusions and explicit burnt-result overrides run.
for _, item_type in ipairs({"item", "capsule"}) do
    for _, item in pairs(data.raw[item_type] or {}) do
        if ei_lib.item_has_fuel_category(item, {"chemical"}) then item.burnt_result = "atan-ash" end
    end
end

ei_lib.raw["item"]["atan-ash"].pictures[1].scale = 0.7
ei_lib.raw["item"]["atan-ash"].pictures[2].scale = 0.7
ei_lib.raw["item"]["atan-ash"].pictures[3].scale = 0.7

ei_lib.raw.recipe["atan-ash-seperation"].results = {
    {type="item", name="ei-poor-iron-chunk", amount=1,independent_probability = 0.08},
    {type="item", name="ei-slag", amount=1,independent_probability = 0.05},
    {type="item", name="coal",amount=1,independent_probability = 0.33}
},

ei_lib.remove_unlock_recipe("automation-3","atan-ash-seperation")
ei_lib.add_unlock_recipe("ei-coke-processing","atan-ash-seperation")
