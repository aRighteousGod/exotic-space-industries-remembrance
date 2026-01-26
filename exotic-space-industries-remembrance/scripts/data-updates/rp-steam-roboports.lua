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

ei_lib.recipe_add("rp-steam-roboport","ei-iron-beam",20)

ei_lib.raw.roboport["rp-steam-roboport"].surface_conditions = {
    {property = "pressure",    min = 10},
}
local chests = {
    ["rp-steam-logistic-chest-active-provider"] = 32,
    ["rp-steam-logistic-chest-passive-provider"] = 32,
    ["rp-steam-logistic-chest-storage"] = 32,
    ["rp-steam-logistic-chest-buffer"] = 32,
    ["rp-steam-logistic-chest-requester"] = 32,
}
for chest,capacity in pairs(chests) do
    ei_lib.raw["logistic-container"][chest]["inventory_size"] = capacity
end
--meaning at 35% battery the steam bots will seek to charge. default 20% results in mass casualties
local rscb = ei_lib.raw["construction-robot"]["rp-steam-construction-bot"]
if rscb then
    rscb.min_to_charge = 0.35
end
local rslb = ei_lib.raw["logistic-robot"]["rp-steam-logistic-bot"]
if rslb then
    rslb.min_to_charge = 0.35
end
