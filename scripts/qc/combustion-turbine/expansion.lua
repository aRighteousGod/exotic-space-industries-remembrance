-- Native expansion acceptance; no mock production and no shipping telemetry.
local support=require("__esir-qc-native-tests__.support")
local config=require("__exotic-space-industries-remembrance__/lib/combustion-turbine-config")
local process=require("__exotic-space-industries-remembrance__/scripts/control/combustion-turbine-process")
local check=support.record
local function near(a,b,tolerance) return math.abs(a-b)<(tolerance or 0.01) end
local function owner(e) return storage.ei.combustion_turbine.turbines_by_unit[e.unit_number] end
local function amount(e,index) local f=e.get_fluid(index);return f and f.amount or 0 end
local function exhaust_amount(e)
    local f=e.has_fluid_segment(2) and e.get_fluid_segment_fluid(2) or e.get_fluid(2)
    -- The one-way output and downstream pipe are separate 2.1 segments.
    local pipe=e.surface.find_entity("pipe",{e.position.x,e.position.y+5})
    local downstream=pipe and pipe.get_fluid_segment_fluid(1)
    return (f and f.amount or 0)+(downstream and downstream.amount or 0)
end
local function snapshot(e)
    local r=owner(e)
    local p=process.capture(e,r)
    return {fuel=e.get_fuel_inventory().get_item_count("coal")*prototypes.item.coal.fuel_value+e.burner.remaining_burning_fuel,
        oxygen=process.is_oxygen(e) and amount(e,1) or 0,
        exhaust=r.generator and exhaust_amount(r.generator) or 0,
        working=(process.is_oxygen(e) and amount(e,2) or 0)+(r.generator and amount(r.generator,1) or 0),
        energy=p.electrical_energy,heat=p.atmospheric_heat+(p.process and p.process.energy or 0),
        progress=p.process and p.process.progress or 0,
        residue=e.get_burnt_result_inventory() and e.get_burnt_result_inventory().get_item_count() or 0}
end
local function equal(a,b,label)
    for key,value in pairs(a) do check(label.."-"..key,near(value,b[key],0.1),helpers.table_to_json{before=a,after=b}) end
end
local function step(model,tick)
    local state=storage.turbine_expansion
    if support.phase()=="reload" then
        check("ash-checkpoint-exists",state and state.completed)
        if state then
            for index,r in ipairs(state.rows) do
                equal(r.saved,snapshot(r.entity),"ash-reload-"..index)
                check("ash-reload-preferences-"..index,owner(r.entity).ash_requested==r.ash and not owner(r.entity).enabled)
            end
        end
        return
    end
    if not state then
        state={start=tick,rows={}}
        storage.turbine_expansion=state
        for index=1,4 do
            local oxygen=index>2
            local ash=index%2==0
            local s=game.create_surface("turbine-ash-"..index,{width=64,height=64})
            s.request_to_generate_chunks({0,0},1);s.force_generate_chunk_requests()
            local tiles={}
            for x=-16,16 do for y=-16,16 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
            s.set_tiles(tiles);s.set_property("pressure",33)
            local e=assert(s.create_entity{name=config.solid,position={0,0},force="player"})
            e=model.on_built_entity{entity=e,tick=tick,tags={[config.ash_tag]=ash,[config.oxygen_tag]=oxygen}}
            e.insert{name="coal",count=50}
            if oxygen then e.set_fluid(1,{name="ei-oxygen-gas",amount=200}) end
            if index==4 then s.create_entity{name="pipe",position={0,5},force="player"} end
            local load=s.create_entity{name="esir-turbine-integration-load",position={8,4},force="player"}
            s.create_entity{name="substation",position={8,0},force="player"}
            state.rows[index]={entity=e,ash=ash,oxygen=oxygen,load=load,output=0}
            check("ash-tag-mode-"..index,process.is_ash(e)==ash and process.is_oxygen(e)==oxygen)
            local residue=e.get_burnt_result_inventory()
            check("ash-native-slots-"..index,(residue and #residue or 0)==(ash and 3 or 0))
            local power=oxygen and owner(e).generator or e
            check("ash-native-capacity-"..index,near(power.prototype.get_max_energy_production(power.quality)*60,ash and 10800000 or 12000000,1))
            if script.active_mods.quality and not oxygen then
                local base=prototypes.entity[config.solid].get_max_energy_production("rare")
                check("ash-quality-capacity-ratio-"..index,near(e.prototype.get_max_energy_production("rare")/base,ash and 0.9 or 1))
            end
        end
        return
    end
    local elapsed=tick-state.start
    if elapsed>120 and elapsed<=300 then
        for _,r in ipairs(state.rows) do
            if r.oxygen then r.output=r.output+owner(r.entity).generator.energy_generated_last_tick end
        end
    end
    if elapsed==120 then
        for _,r in ipairs(state.rows) do r.before=snapshot(r.entity);r.pollution=r.entity.surface.get_total_pollution() end
    elseif elapsed==300 then
        for index,r in ipairs(state.rows) do
            local after=snapshot(r.entity)
            check("ash-full-load-fuel-rate-"..index,near(r.before.fuel-after.fuel,12000000,400000))
            if r.oxygen then
                local rate=r.ash and 18 or 20
                check("ash-oxygen-rate-"..index,near(r.before.oxygen-after.oxygen,rate*3,1.1))
                check("ash-exhaust-rate-"..index,near(after.exhaust-r.before.exhaust,rate*3,0.7),helpers.table_to_json{before=r.before,after=after})
                check("ash-electrical-output-"..index,near(r.output,(r.ash and 10800000 or 12000000)*3,300000))
            end
            check("ash-native-residue-"..index,r.ash and after.residue>0 or not r.ash and after.residue==0)
            r.pollution_delta=r.entity.surface.get_total_pollution()-r.pollution
        end
        for _,i in ipairs({1,3}) do
            check("ash-pollution-ratio-"..i,near(state.rows[i+1].pollution_delta/state.rows[i].pollution_delta,0.9,0.03),
                helpers.table_to_json{base=state.rows[i].pollution_delta,ash=state.rows[i+1].pollution_delta})
        end
        local atmospheric=state.rows[2]
        atmospheric.entity.get_burnt_result_inventory().clear()
        local atmospheric_before=snapshot(atmospheric.entity)
        for _=1,10 do
            atmospheric.entity=model.swap_to_mode(atmospheric.entity,"solid",tick,nil,nil,false)
            atmospheric.entity=model.swap_to_mode(atmospheric.entity,"solid",tick,nil,nil,true)
        end
        equal(atmospheric_before,snapshot(atmospheric.entity),"ash-atmospheric-toggle-custody")
        local r=state.rows[4]
        local e=r.entity
        local before=snapshot(e)
        local rejected,success=model.swap_to_mode(e,"solid",tick,nil,nil,false,false)
        check("ash-nonempty-switch-blocked",rejected==e and success==false and owner(e).enabled and owner(e).ash_requested)
        equal(before,snapshot(e),"ash-rejected-custody")
        rejected,success=model.swap_to_mode(e,"fluid",tick)
        check("ash-nonempty-fluid-blocked",rejected==e and success==false)
        model.on_entity_settings_pasted{source=state.rows[3].entity,destination=e,tick=tick}
        check("ash-paste-atomic-rejection",e.valid and owner(e).ash_requested and owner(e).enabled)
        e.get_burnt_result_inventory().clear()
        before=snapshot(e)
        for _=1,10 do
            e=model.swap_to_mode(e,"solid",tick,nil,nil,false)
            e=model.swap_to_mode(e,"solid",tick,nil,nil,true)
        end
        equal(before,snapshot(e),"ash-toggle-custody")
        r.entity=e
        e.get_burnt_result_inventory().insert{name="atan-ash",count=7}
        before=snapshot(e)
        e=model.swap_to_mode(e,"solid",tick,nil,false)
        e=model.swap_to_mode(e,"solid",tick,nil,true)
        equal(before,snapshot(e),"ash-oxygen-switch-residue")
        r.entity=e
        for _,row in ipairs(state.rows) do
            row.entity=model.swap_to_mode(row.entity,"solid",tick,nil,nil,nil,false)
            row.off=snapshot(row.entity)
        end
    elseif elapsed==400 then
        for index,r in ipairs(state.rows) do
            local after=snapshot(r.entity)
            check("ash-off-no-consumption-"..index,near(r.off.fuel,after.fuel) and near(r.off.oxygen,after.oxygen) and near(r.off.exhaust,after.exhaust))
            check("ash-off-native-hold-"..index,r.entity.disabled_by_script and (not r.oxygen or owner(r.entity).generator.disabled_by_script))
            r.entity=model.swap_to_mode(r.entity,"solid",tick,nil,nil,nil,true)
            check("ash-enabled-restores-"..index,not r.entity.disabled_by_script)
        end
        local r=state.rows[4]
        local inv=r.entity.get_burnt_result_inventory()
        for i=1,#inv do inv[i].set_stack{name="atan-ash",count=prototypes.item["atan-ash"].stack_size} end
        r.entity.set_fluid(1,{name="ei-oxygen-gas",amount=200})
        owner(r.entity).generator.clear_fluid(2)
    elseif elapsed==500 then
        local r=state.rows[4]
        check("ash-full-residue-native-block",r.entity.status==defines.entity_status.full_burnt_result_output)
        r.blocked=snapshot(r.entity)
    elseif elapsed==550 then
        local r=state.rows[4]
        local after=snapshot(r.entity)
        check("ash-full-residue-no-consumption",near(r.blocked.fuel,after.fuel) and near(r.blocked.oxygen,after.oxygen))
        r.entity.get_burnt_result_inventory().clear()
    elseif elapsed==600 then
        for _,r in ipairs(state.rows) do
            r.entity=model.swap_to_mode(r.entity,"solid",tick,nil,nil,nil,false)
        end
        state.residue_fuels={}
        for i,name in ipairs({"esir-turbine-qc-residue-fuel","esir-turbine-qc-clean-fuel"}) do
            local s=state.rows[i].entity.surface
            local e=s.create_entity{name=config.ash_solid,position={0,20},force="player"}
            e=model.on_built_entity{entity=e,tick=tick}
            e.insert{name=name,count=10}
            s.create_entity{name="substation",position={8,14},force="player"}
            s.create_entity{name="esir-turbine-integration-load",position={8,20},force="player"}
            state.residue_fuels[i]=e
        end
    elseif elapsed==690 then
        local dirty,clean=state.residue_fuels[1],state.residue_fuels[2]
        check("native-alternative-residue",dirty.get_burnt_result_inventory().get_item_count("stone")==10)
        check("native-no-result-fuel",clean.get_fuel_inventory().is_empty() and clean.get_burnt_result_inventory().is_empty())
        for _,e in ipairs(state.residue_fuels) do e.destroy{raise_destroy=true} end
    elseif elapsed==705 then
        for _,r in ipairs(state.rows) do r.saved=snapshot(r.entity) end
        state.completed=true
    end
end
return {step=step}
