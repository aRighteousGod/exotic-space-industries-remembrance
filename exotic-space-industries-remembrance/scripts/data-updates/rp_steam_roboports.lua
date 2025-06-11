if not mods["rp_steam_roboports"] then return end
--====================================================================================================
--settings are also enforced in data_updates
local ei_lib = require("lib/lib")

ei_lib.set_age_packs("rp-steam-piston","steam-age")
ei_lib.set_age_packs("rp-steam-soul","steam-age")
ei_lib.set_age_packs("rp-steam-calculator","steam-age")
ei_lib.set_age_packs("rp-steam-roboports","steam-age")
ei_lib.set_age_packs("rp-steam-logistics-chests","steam-age")


ei_lib.set_prerequisites("rp-steam-soul",{"rp-steam-calculator","rp-steam-piston"})
ei_lib.set_prerequisites("rp-steam-calculator",{"ei-steam-assembler"})

