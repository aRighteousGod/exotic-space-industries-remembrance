--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["distant-misfires"] then
    return
end

local ei_lib = require("lib/lib")

--distant misfires adjusts magazine sizes but not compound rounds so..
local cr_mag = ei_lib.raw["ammo"]["ei-compound-ammo"]
local ur_mag = ei_lib.raw["ammo"]["uranium-rounds-magazine"]
if cr_mag and ur_mag then
    cr_mag.magazine_size = ur_mag.magazine_size
end