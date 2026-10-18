if not data.raw["fluid-turret"]["ei-water-turret"] then return end
local turret=data.raw["fluid-turret"]["ei-water-turret"]
local config=require("__exotic-space-industries-remembrance__/lib/firefighting-config")
if config.created_effect then
    local flames=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
    local function count_effect(value,id)
        if type(value)~="table" then return 0 end
        local count=value.type=="script" and value.effect_id==id and 1 or 0
        for _,v in pairs(value) do if type(v)=="table" then count=count+count_effect(v,id) end end
        return count
    end
    for name,fire in pairs(data.raw.fire) do
        local supported=config.thermal_fires[name] or flames.ground_fires[name]
        assert(count_effect(fire.created_effect,config.created_effect)==(supported and 1 or 0),"fire-birth-hook: "..name)
    end
    assert(not settings.startup["ei-water-turret-fire-check-seconds"],"obsolete-search-setting")
    assert(settings.startup[config.targeting_setting].value==require("test-config").targeting,"target-setting")
end
assert(turret.rotation_speed==0.02,"water-turn-speed")
local graphics=ei_graphics_6_path.."graphics/"
local seen={}
local function check_water_graphics(value)
    if type(value)~="table" then return end
    for key,child in pairs(value) do
        if (key=="filename" or key=="icon") and type(child)=="string" and child:find("water-turret",1,true) then
            assert(child:sub(1,#graphics)==graphics,"water-graphics-companion: "..child)
            seen[child]=true
        elseif type(child)=="table" then check_water_graphics(child) end
    end
end
check_water_graphics(turret)
check_water_graphics(data.raw.item["ei-water-turret"])
check_water_graphics(data.raw.technology["ei-water-turret"])
for _,path in ipairs{"entities/water-turret/water-turret-base.png","entities/water-turret/water-turret-base_shadow.png",
    "entities/water-turret/water-turret-head.png","entities/water-turret/water-turret-head_mask.png",
    "entities/water-turret/water-turret-head_shadow.png","items/water-turret.png","technology/water-turret.png"} do
    assert(seen[graphics..path],"water-graphics-role-missing: "..path)
end
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
