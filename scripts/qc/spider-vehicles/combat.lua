-- Native fire checks and UI feasibility probes: unbonused force, immobile targets.
-- Expected native cycling stalls remain explicit known limitations in the report.
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local model={}
local function ammunition(stack)
    if not stack.valid_for_read then return 0 end
    return (stack.count-1)*stack.prototype.magazine_size+stack.ammo
end
function model.setup()
    local force=game.create_force("esir-spider-combat")
    local cases={
        {branch="cannon",level=0,slot=1,ammo="cannon-shell",range=25},
        {branch="cannon",level=5,slot=1,ammo="cannon-shell",range=2},
        {branch="mg",level=0,slot=2,ammo="firearm-magazine",range=20},
        {branch="mg",level=1,slot=2,ammo="firearm-magazine",range=20},
        {branch="mg",level=2,slot=2,ammo="firearm-magazine",range=35},
        {branch="flamer",level=4,slot=3,ammo="flamethrower-ammo",range=10},
        {branch="artillery",level=1,slot=4,ammo="artillery-shell",range=60},
    }
    for level=1,4 do cases[#cases+1]={branch="doeworks",level=level,slot=5,ammo="dw-deer-ammo-basic",range=105} end
    cases[#cases+1]={branch="mixed-cycling-on",level=0,slot=1,ammo="cannon-shell",range=10,multiple=true}
    cases[#cases+1]={branch="mixed-cycling-off-cannon",level=0,slot=1,ammo="cannon-shell",range=10,multiple=true,entity_name="esir-spider-qc-cycling-off",selected=1}
    cases[#cases+1]={branch="mixed-cycling-off-mg",level=0,slot=1,ammo="cannon-shell",range=10,multiple=true,entity_name="esir-spider-qc-cycling-off",selected=2}
    cases[#cases+1]={branch="mixed-artillery-range",level=0,slot=1,ammo="cannon-shell",range=60,multiple=true,expected_stall=true,entity_name=catalog.variant_name("assault",{artillery=1}),ammo_names={"cannon-shell","firearm-magazine","flamethrower-ammo","artillery-shell"}}
    cases[#cases+1]={branch="mixed-artillery-hold",level=0,slot=1,ammo="cannon-shell",range=60,multiple=true,entity_name="esir-spider-qc-artillery-hold",selected=4,ammo_names={"cannon-shell","firearm-magazine","flamethrower-ammo","artillery-shell"}}
    cases[#cases+1]={branch="mixed-doeworks-range",level=0,slot=1,ammo="rocket",range=105,multiple=true,expected_stall=true,entity_name=catalog.variant_name("rocket",{doeworks=1}),ammo_names={"rocket","rocket","rocket","rocket","dw-deer-ammo-basic"}}
    cases[#cases+1]={branch="mixed-doeworks-hold",level=0,slot=1,ammo="rocket",range=105,multiple=true,entity_name="esir-spider-qc-doeworks-hold",selected=5,ammo_names={"rocket","rocket","rocket","rocket","dw-deer-ammo-basic"}}
    cases[#cases+1]={branch="mixed-script-alternating",level=0,slot=1,ammo="cannon-shell",range=20,multiple=true,entity_name="esir-spider-qc-cycling-off",alternate=true}
    cases[#cases+1]={branch="mixed-rocket-cycle",level=0,slot=1,ammo="rocket",range=25,multiple=true,entity_name=catalog.variant_name("rocket",{}),ammo_names={"rocket","rocket","rocket","rocket"}}
    cases[#cases+1]={branch="mixed-rocket-hold",level=0,slot=1,ammo="rocket",range=25,multiple=true,entity_name="esir-spider-qc-doeworks-hold",ammo_names={"rocket","rocket","rocket","rocket"}}
    cases[#cases+1]={branch="mixed-artillery-too-close",level=0,slot=1,ammo="cannon-shell",range=10,multiple=true,expected_stall=true,entity_name=catalog.variant_name("assault",{artillery=1}),selected=4,ammo_names={"cannon-shell","firearm-magazine","flamethrower-ammo","artillery-shell"}}
    cases[#cases+1]={branch="mixed-doeworks-too-close",level=0,slot=1,ammo="rocket",range=25,multiple=true,expected_stall=true,entity_name=catalog.variant_name("rocket",{doeworks=1}),selected=5,ammo_names={"rocket","rocket","rocket","rocket","dw-deer-ammo-basic"}}
    cases[#cases+1]={branch="doeworks",level=4,slot=5,ammo="dw-deer-ammo-basic",range=40,entity_name=catalog.variant_name("rocket",{doeworks=4},"smart")}
    for _,level in ipairs({0,3,4}) do
        for _,mode in ipairs({"hold","smart"}) do
            cases[#cases+1]={branch="rocket",level=level,slot=1,ammo="rocket",range=25,entity_name=catalog.variant_name("rocket",{rocket=level},mode),expected_cooldown=catalog.weapons.rocket[level+1][1]/(mode=="smart" and 2 or 1),mode=mode}
        end
        cases[#cases+1]={branch="rocket-battery",level=level,slot=1,ammo="rocket",range=25,multiple=true,entity_name=catalog.variant_name("rocket",{rocket=level}),ammo_names={"rocket","rocket","rocket","rocket"},battery_interval=catalog.weapons.rocket[level+1][1]/2}
    end
    storage.combat=cases
    for index,case in ipairs(cases) do
        local surface=game.create_surface("esir-spider-combat-"..index,{width=256,height=128,autoplace_controls={}})
        surface.request_to_generate_chunks({50,0},4);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-5,110 do for y=-5,5 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
        surface.set_tiles(tiles)
        local family=case.branch=="doeworks" and "rocket" or "assault"
        local entity=surface.create_entity{name=case.entity_name or catalog.variant_name(family,{[case.branch]=case.level}),position={0,0},force=force}
        entity.vehicle_automatic_targeting_parameters={auto_target_without_gunner=true,auto_target_with_gunner=true}
        entity.get_inventory(defines.inventory.spider_ammo)[case.slot].set_stack{name=case.ammo,count=100}
        entity.selected_gun_index=case.selected or case.slot
        local target=surface.create_entity{name="esir-spider-qc-target",position={case.range,0},force="enemy"}
        target.active=false
        case.entity=entity;case.target=target;case.shots=0;case.fire_ticks={};case.first_shots={}
        case.previous=ammunition(entity.get_inventory(defines.inventory.spider_ammo)[case.slot])
        if case.multiple then
            case.previous_slots={};case.shots_by_slot={0,0,0}
            for slot,name in ipairs(case.ammo_names or {"cannon-shell","firearm-magazine","flamethrower-ammo"}) do
                local stack=entity.get_inventory(defines.inventory.spider_ammo)[slot]
                stack.set_stack{name=name,count=100}
                case.previous_slots[slot]=ammunition(stack)
            end
            entity.selected_gun_index=case.selected or 1
        end
    end
end
function model.sample(tick)
    for _,case in ipairs(storage.combat or {}) do
        if case.multiple then
            for slot,name in ipairs(case.ammo_names or {"cannon-shell","firearm-magazine","flamethrower-ammo"}) do
                local stack=case.entity.get_inventory(defines.inventory.spider_ammo)[slot]
                local remaining=ammunition(stack)
                local consumed=math.max(0,case.previous_slots[slot]-remaining)
                case.shots_by_slot[slot]=(case.shots_by_slot[slot] or 0)+consumed
                case.shots=case.shots+consumed
                if consumed>0 and #case.first_shots<12 then case.first_shots[#case.first_shots+1]={tick=tick,slot=slot} end
                if remaining<10 then stack.set_stack{name=name,count=100};remaining=ammunition(stack) end
                case.previous_slots[slot]=remaining
            end
            if case.alternate and tick%10==0 then case.entity.selected_gun_index=case.entity.selected_gun_index==1 and 2 or 1 end
        else
        local stack=case.entity.get_inventory(defines.inventory.spider_ammo)[case.slot]
        local remaining=ammunition(stack)
        if remaining<case.previous then
            case.shots=case.shots+case.previous-remaining
            case.fire_ticks[#case.fire_ticks+1]=tick
        end
        if remaining<10 then stack.set_stack{name=case.ammo,count=100};remaining=ammunition(stack) end
        case.previous=remaining
        end
    end
end
function model.verify(check)
    local results={}
    for _,case in ipairs(storage.combat) do
        local gaps={}
        for index=2,#case.fire_ticks do
            local gap=case.fire_ticks[index]-case.fire_ticks[index-1]
            gaps[gap]=(gaps[gap] or 0)+1
        end
        results[#results+1]={branch=case.branch,level=case.level,ammunition_consumed=case.shots,intervals=gaps,ammo_by_slot=case.shots_by_slot,selected=case.entity.selected_gun_index,first_shots=case.first_shots,known_limitation=case.expected_stall or false}
        if case.expected_stall then
            check("known-native-cycle-stall-"..case.branch,case.shots==0 and case.entity.selected_gun_index==(case.selected or 1),serpent.line(results[#results]))
        else
            check("combat-"..case.branch.."-"..case.level,case.shots>0,serpent.line(results[#results]))
        end
        if #case.fire_ticks>=4 then
            local mean=(case.fire_ticks[#case.fire_ticks]-case.fire_ticks[2])/(#case.fire_ticks-2)
            local expected=case.expected_cooldown or math.max(1,catalog.weapons[case.branch][case.level+1][1])
            check("cadence-"..case.branch.."-"..case.level,math.abs(mean-expected)<0.02,mean)
        end
        if case.battery_interval then
            local correct=#case.first_shots>=4
            for index=2,#case.first_shots do correct=correct and case.first_shots[index].tick-case.first_shots[index-1].tick==case.battery_interval end
            check("native-battery-cadence-"..case.level,correct,serpent.line(case.first_shots))
        end
    end
    return results
end
return model
