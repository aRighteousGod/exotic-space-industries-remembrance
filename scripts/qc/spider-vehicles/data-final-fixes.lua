-- Validate the final dependency stack, after all ESIR data passes.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local checked=0
local function check(name,condition)
    assert(condition,"SPIDER_DATA_QC "..name)
    checked=checked+1
end
local function has_path(name,ancestor,seen)
    if name==ancestor then return true end
    seen=seen or {}
    if seen[name] then return false end
    seen[name]=true
    for _,parent in ipairs(data.raw.technology[name].prerequisites or {}) do
        if has_path(parent,ancestor,seen) then return true end
    end
    return false
end
local function pack(name,ingredient)
    for _,entry in ipairs(data.raw.technology[name].unit.ingredients) do
        if (entry.name or entry[1])==ingredient then return true end
    end
    return false
end
local counts={scout=0,assault=0,rocket=0}
for name,entity in pairs(data.raw["spider-vehicle"]) do
    local family=name:match("^ei%-spider%-(%a+)%-")
    if counts[family] then
        counts[family]=counts[family]+1
        local chassis=tonumber(name:match("%-h(%d+)"))
        local profile=catalog.profiles[family]
        local tier=catalog.grid_tier(chassis)
        local grid=data.raw["equipment-grid"][entity.equipment_grid]
        check(name.."-grid",grid.width==profile.grids[tier][1] and grid.height==profile.grids[tier][2])
        check(name.."-mining",entity.minable.result==catalog.stored_item(family,tier))
        check(name.."-hidden",entity.hidden and entity.hidden_in_factoriopedia)
        check(name.."-cycling",entity.automatic_weapon_cycling==(catalog.mode(name)=="native"))
        if mods.SpidertronEnhancements then
            local proxy=data.raw["spider-vehicle"][catalog.proxy_prefix..name]
            check(name.."-boarding-proxy",proxy and proxy.inventory_size==entity.inventory_size and proxy.equipment_grid==entity.equipment_grid and #proxy.guns==#entity.guns)
        end
        local weapons=#entity.guns
        check(name.."-slots",family=="scout" and weapons==0 or family=="assault" and weapons==(name:find("-a0-",1,true) and 3 or 4) or family=="rocket" and weapons==(name:find("-d0-",1,true) and 4 or 5))
    end
end
check("configuration-count",counts.scout==13 and counts.assault==23400 and counts.rocket==975)
check("scout-three-legs",#data.raw["spider-vehicle"][catalog.variant_name("scout",{})].spider_engine.legs==3)
check("scout-computer-age",pack("ei-spider-vehicles","ei-computer-age-tech") and not pack("ei-spider-vehicles","ei-advanced-computer-age-tech"))
check("assault-simulation",has_path("ei-assault-spidertron","ei-spider-vehicles") and has_path("ei-assault-spidertron","ei-advanced-computer-age-tech"))
check("rocket-gleba",has_path("spidertron","ei-spider-vehicles") and has_path("spidertron","agricultural-science-pack"))
local recipe={}
for _,ingredient in ipairs(data.raw.recipe.spidertron.ingredients) do recipe[ingredient.name or ingredient[1]]=ingredient.amount or ingredient[2] end
check("rocket-recipe",recipe["rocket-launcher"]==4 and recipe["carbon-fiber"]==50 and not recipe.tank and not recipe["rocket-turret"])
check("upstream-tech-disabled",data.raw.technology.assault_spidertron_tech.hidden and data.raw.technology.assault_spidertron_tech.enabled==false)
check("upstream-recipe-disabled",data.raw.recipe.assault_spidertron.hidden and data.raw.recipe.assault_spidertron.enabled==false)
for tier=2,3 do
    local name="ei-gaian-saucer-stored-spidertron-"..tier
    check(name.."-selectable",data.raw.recipe[name].hidden==false)
end
check("smoke-visuals-harmless",data.raw["smoke-with-trigger"]["ei-assault-smoke-cloud"].action==nil and data.raw["smoke-with-trigger"]["ei-assault-smoke-bank"].action==nil)
for _,branch in ipairs(catalog.branch_order) do
    for index,stats in ipairs(catalog.weapons[branch]) do
        if stats then
            local attack=data.raw.gun["ei-spider-gun-"..branch.."-"..(index-1)].attack_parameters
            check(branch..index.."-parameters",attack.cooldown==stats[1] and attack.range==stats[2] and attack.min_range==stats[3])
        end
    end
    for level=1,#catalog.upgrade_names[branch] do
        local name=catalog.weapon_technology(branch,level)
        check(name.."-age",pack(name,"ei-quantum-age-tech")==(level>catalog.simulation_steps[branch]))
        local root=(branch=="rocket" or branch=="doeworks") and "spidertron" or "ei-assault-spidertron"
        check(name.."-root",has_path(name,root))
    end
end
check("minigun-dependency",has_path(catalog.weapon_technology("mg",1),"ei-minigun"))
check("heavy-minigun-dependency",has_path(catalog.weapon_technology("mg",2),"ei-heavy-minigun"))
for _,pair in ipairs({
    {"discharge-defense-equipment","advanced-circuit"},{"discharge-defense-equipment","ei-insulated-wire"},
    {"land-mine","explosives"},{"follower-robot-count-1","defender"},
    {"coal-liquefaction","metallurgic-science-pack"},{"coal-liquefaction","space-science-pack"},
    {"rocket-fuel","ei-oxygen-gas"},{"quality-module-3","ei-computing-unit"},
    {"mining-productivity-3","ei-advanced-computer-age-tech"},
    {"physical-projectile-damage-4","ei-advanced-computer-age-tech"},
    {"weapon-shooting-speed-4","ei-advanced-computer-age-tech"},
    {"laser-weapons-damage-3","ei-advanced-computer-age-tech"},
    {"laser-shooting-speed-4","ei-advanced-computer-age-tech"},
    {"ei-personal-leg","ei-advanced-computer-age-tech"},
}) do check(pair[1].."-dependency-"..pair[2],has_path(pair[1],pair[2])) end
check("mining-two-computer",pack("mining-productivity-2","ei-computer-age-tech") and not pack("mining-productivity-2","ei-advanced-computer-age-tech"))
check("mining-three-simulation",pack("mining-productivity-3","ei-advanced-computer-age-tech"))
check("exoskeleton-no-alien",not has_path("ei-personal-leg","ei-alien-computer-age-tech") and not pack("ei-personal-leg","ei-alien-computer-age-tech"))
local visiting,visited={},{}
local function visit(name)
    check("acyclic-"..name,not visiting[name])
    if visited[name] then return end
    visiting[name]=true
    for _,parent in ipairs(data.raw.technology[name].prerequisites or {}) do visit(parent) end
    visiting[name]=nil;visited[name]=true
end
for name in pairs(data.raw.technology) do visit(name) end
log("SPIDER_DATA_QC PASS checks="..checked.." configurations="..(counts.scout+counts.assault+counts.rocket))
-- Experimental counterpart for the UI feasibility probe; not a shipping entity.
local cycling_off=table.deepcopy(data.raw["spider-vehicle"][catalog.variant_name("assault",{})])
cycling_off.name="esir-spider-qc-cycling-off"
cycling_off.automatic_weapon_cycling=false
data:extend({cycling_off})
local artillery_hold=table.deepcopy(data.raw["spider-vehicle"][catalog.variant_name("assault",{artillery=1})])
artillery_hold.name="esir-spider-qc-artillery-hold"
artillery_hold.automatic_weapon_cycling=false
data:extend({artillery_hold})
local doeworks_hold=table.deepcopy(data.raw["spider-vehicle"][catalog.variant_name("rocket",{doeworks=1})])
doeworks_hold.name="esir-spider-qc-doeworks-hold"
doeworks_hold.automatic_weapon_cycling=false
data:extend({doeworks_hold})
check("doeworks-full-arc",data.raw.gun["ei-spider-gun-doeworks-4"].attack_parameters.turn_range==1)
local partial=table.deepcopy(data.raw.ammo["artillery-shell"])
partial.name="esir-spider-qc-partial-artillery"
partial.magazine_size=10;partial.stack_size=10
data:extend({partial})
