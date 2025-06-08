if not mods["rp_steam_roboports"] then return end
local ei_lib = require("lib/lib")
--[[
local techs_to_set = {
    "rp-steam-piston",
    "rp-steam-soul",
    "rp-steam-calculator",
    "rp-steam-roboports",
    "rp-steam-logistics-chests"
}
for set in techs_to_set do
    data.raw.technology[set].age = "steam-age"
]]
ei_lib.set_age_packs("rp-steam-piston","steam-age")
ei_lib.set_age_packs("rp-steam-soul","steam-age")
ei_lib.set_age_packs("rp-steam-calculator","steam-age")
ei_lib.set_age_packs("rp-steam-roboports","steam-age")
ei_lib.set_age_packs("rp-steam-logistics-chests","steam-age")


ei_lib.set_prerequisites("rp-steam-soul",{"rp-steam-calculator","rp-steam-piston"})
ei_lib.set_prerequisites("rp-steam-calculator",{"ei-steam-assembler"})
