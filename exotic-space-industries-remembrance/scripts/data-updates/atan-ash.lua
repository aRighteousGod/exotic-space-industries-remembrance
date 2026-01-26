--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["atan-ash"] then
    return
end

local ei_lib = require("lib/lib")

ei_lib.raw["item"]["atan-ash"].pictures[1].scale = 0.7
ei_lib.raw["item"]["atan-ash"].pictures[2].scale = 0.7
ei_lib.raw["item"]["atan-ash"].pictures[3].scale = 0.7

ei_lib.raw.recipe["atan-ash-seperation"].results = {
    {type="item", name="ei-poor-iron-chunk", amount=1,probability=0.08},
    {type="item", name="ei-slag", amount=1,probability=0.05},
    {type="item", name="coal",amount=1,probability=0.33}
},

ei_lib.remove_unlock_recipe("automation-3","atan-ash-seperation")
ei_lib.add_unlock_recipe("ei-coke-processing","atan-ash-seperation")