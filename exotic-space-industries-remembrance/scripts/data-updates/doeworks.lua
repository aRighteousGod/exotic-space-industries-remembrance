--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["doeworks-deer"] then
    return
end

local ei_lib = require("lib/lib")

--ammo-turret dw-deer-turret
--weapon stream dw-deer-basic-stream
--remnant dw-deer-remnants
--ammo category dw-deer-ammo
--tech dw-deer-tech
--recipes
--dw-deer-ammo-basic
--dw-deer-crating-basic
--dw-deer-uncrating-basic

ei_lib.set_prerequisites("dw-deer-tech",{"rocketry","explosives"})
ei_lib.set_age_packs("dw-deer-tech","computer-age")