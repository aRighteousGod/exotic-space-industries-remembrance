if not data.raw["fluid-turret"]["ei-water-turret"] then return end
local turret=data.raw["fluid-turret"]["ei-water-turret"]
assert(turret.attack_parameters.range==24 and turret.attack_parameters.min_range==0,"water-range")
assert(#turret.attack_parameters.fluids==1 and turret.attack_parameters.fluids[1].type=="water","water-only")
assert(turret.attack_parameters.cooldown==4 and turret.attack_parameters.fluid_consumption==2,"water-consumption")
assert(data.raw.stream["ei-water-combat-stream"].action.force=="enemy","enemy-only")
assert(data.raw.stream["ei-water-combat-stream"].action.action_delivery.target_effects[1].type=="create-sticker","no-damage")
assert(not data.raw.sticker["ei-water-slow"].damage_per_tick,"no-sticker-damage")
assert(data.raw.sticker["ei-water-slow"].target_movement_modifier==0.75,"slow")
assert(data.raw.gun["ei-extinguisher"] and not data.raw.gun.extinguisher,"gun-ownership")
assert(data.raw.ammo["ei-extinguisher-ammo"].magazine_size==100,"canister-size")
assert(data.raw.recipe["ei-extinguisher-recycling"] and data.raw.recipe["ei-extinguisher-ammo-recycling"],"recycling")
local prerequisite=false
for _,name in pairs(data.raw.technology["ei-water-turret"].prerequisites) do
    if name=="ei-extinguisher" then prerequisite=true end
end
assert(prerequisite,"extinguisher-prerequisite")
local ingredient=false
for _,entry in pairs(data.raw.recipe["ei-water-turret"].ingredients) do
    if entry.name=="ei-extinguisher" and entry.amount==1 then ingredient=true end
end
assert(ingredient,"extinguisher-ingredient")
if require("test-config").muzzle then require("muzzle-data") end
