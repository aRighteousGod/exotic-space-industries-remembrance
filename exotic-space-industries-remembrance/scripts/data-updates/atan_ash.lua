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