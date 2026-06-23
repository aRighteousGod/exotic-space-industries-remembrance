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

local steam_chest_upgrades = {
    ["rp-steam-logistic-chest-active-provider"] = "ei-2x2-container-pink",
    ["rp-steam-logistic-chest-passive-provider"] = "ei-2x2-container-red",
    ["rp-steam-logistic-chest-storage"] = "ei-2x2-container-yellow",
    ["rp-steam-logistic-chest-buffer"] = "ei-2x2-container-green",
    ["rp-steam-logistic-chest-requester"] = "ei-2x2-container-blue",
}

for steam_chest, esir_chest in pairs(steam_chest_upgrades) do
    local steam_entity = ei_lib.raw["logistic-container"][steam_chest]
    local esir_entity = ei_lib.raw["logistic-container"][esir_chest]

    if steam_entity and esir_entity then
        -- Upgrade planner pairs must share fast-replace group, collision box, and collision mask.
        steam_entity.next_upgrade = esir_chest
        steam_entity.fast_replaceable_group = "container"
        esir_entity.fast_replaceable_group = "container"
        steam_entity.collision_box = table.deepcopy(esir_entity.collision_box)
        steam_entity.collision_mask = esir_entity.collision_mask and table.deepcopy(esir_entity.collision_mask) or nil
    end
end

local steam_roboport = ei_lib.raw.roboport["rp-steam-roboport"]
local electric_roboport = ei_lib.raw.roboport["roboport"]

if steam_roboport and electric_roboport then
    -- Upgrade planner pairs must share fast-replace group, collision box, and collision mask.
    steam_roboport.next_upgrade = "roboport"
    steam_roboport.fast_replaceable_group = "roboport"
    electric_roboport.fast_replaceable_group = "roboport"
    steam_roboport.collision_box = table.deepcopy(electric_roboport.collision_box)
    steam_roboport.collision_mask = electric_roboport.collision_mask and table.deepcopy(electric_roboport.collision_mask) or nil
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
