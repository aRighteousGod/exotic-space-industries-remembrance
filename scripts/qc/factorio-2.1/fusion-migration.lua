-- Three populated historical reactors retain manual/circuit and native state.
local mode=require("test-config")
local modern=script.active_mods.base:match("^2%.1%.")~=nil
local loaded=false
script.on_load(function() loaded=true end)

local function snapshot(entity)
    local entry=remote.call("esir-fusion-qc","record",entity)
    -- The owner's derived normalization marker is not a saved user selection.
    local manual={fuel_1=entry.manual_selection.fuel_1,fuel_2=entry.manual_selection.fuel_2,
        temperature=entry.manual_selection.temperature,injection_rate=entry.manual_selection.injection_rate}
    local result={unit=entity.unit_number,name=entity.name,quality=entity.quality.name,
        position=entity.position,health=entity.health,energy=entity.energy,
        progress=entity.crafting_progress,recipe=entity.get_recipe().name,recipe_locked=entity.recipe_locked,
        minable=modern and entity.minable_flag or entity.minable,
        disabled=modern and entity.disabled_by_script or not entity.active,
        manual=manual,effective=entry.effective_selection,control_source=entry.control_source,
        proxy_unit=entry.wire_proxy.unit_number,proxy_connected=entry.wire_proxy_connected,
        wired=entry.wire_proxy_wired,signals=entry.signal_cache or {},fluids={}}
    for index=1,entity.fluids_count do result.fluids[index]=entity.get_fluid(index) or false end
    return result
end

local function compare(before,after,path,report)
    for key,value in pairs(before) do
        local other=after[key]
        local label=path.."."..tostring(key)
        if type(value)=="table" then
            assert(type(other)=="table",label.." missing table")
            compare(value,other,label,report)
        else
            report.fields=report.fields+1
            assert(type(value)=="number" and type(other)=="number" and math.abs(value-other)<1e-6
                or value==other,label.." changed: "..tostring(value).." / "..tostring(other))
        end
    end
    for key in pairs(after) do assert(before[key]~=nil,path.." added "..tostring(key)) end
end

local function save_report(phase)
    local report={engine=script.active_mods.base,phase=phase,tick=game.tick,fields=0,cases={}}
    for index,entity in ipairs(storage.entities) do
        local state=snapshot(entity)
        compare(storage.baseline[index],state,"reactor"..index,report)
        report.cases[index]=state
    end
    report.passed=true
    helpers.write_file("fusion-"..phase..".json",helpers.table_to_json(report),false)
    game.auto_save("fusion-"..phase)
end

script.on_event(defines.events.on_tick,function(event)
    if mode=="donor" and event.tick==1 then
        local surface=game.create_surface("fusion-migration-qc",{width=256,height=128,peaceful_mode=true})
        surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        storage.entities={}
        local selections={
            {fuel_1="ei-heated-protium",fuel_2="ei-heated-lithium-6",temperature="high",injection_rate="low"},
            {fuel_1="ei-heated-deuterium",fuel_2="ei-heated-tritium",temperature="low",injection_rate="high"},
            {fuel_1="ei-heated-deuterium",fuel_2="ei-heated-deuterium",temperature="high",injection_rate="low"},
        }
        for index,selection in ipairs(selections) do
            local entity=assert(surface.create_entity{name="ei-fusion-reactor",position={(index-2)*64,0},force="player",quality="rare"})
            entity.active=false;entity.minable=false;entity.health=123;entity.energy=45678
            remote.call("esir-fusion-qc","register",entity,event.tick)
            remote.call("esir-fusion-qc","select",entity,selection,index==2 and "circuit" or "manual",event.tick)
            storage.entities[index]=entity
        end
        local control=surface.create_entity{name="constant-combinator",position={7,0},force="player"}
        local section=control.get_or_create_control_behavior().get_section(1)
        for index,signal in ipairs{{"fuel-1",3},{"fuel-2",4},{"temperature",1},{"injection",2}} do
            section.set_slot(index,{value={type="virtual",name="ei-fusion-set-"..signal[1],quality="normal"},min=signal[2]})
        end
        assert(control.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(
            storage.entities[2].get_wire_connector(defines.wire_connector_id.circuit_red,true),false,defines.wire_origin.player))
        storage.control=control
    elseif mode=="donor" and event.tick==61 then
        remote.call("esir-fusion-qc","service",event.tick)
        storage.baseline={}
        for index,entity in ipairs(storage.entities) do
            for fluid_index=1,entity.fluids_count do
                local filter=entity.fluidbox.get_filter(fluid_index)
                assert(filter and filter.name,"Missing fusion filter")
                entity.fluidbox[fluid_index]={name=filter.name,amount=11+fluid_index,temperature=prototypes.fluid[filter.name].default_temperature}
            end
            entity.crafting_progress=0.375
            storage.baseline[index]=snapshot(entity)
        end
        assert(storage.baseline[2].control_source=="circuit" and storage.baseline[2].manual.fuel_1~=storage.baseline[2].effective.fuel_1)
        storage.ready=true
        save_report("donor")
    elseif mode~="donor" and loaded and storage.ready then
        loaded=false
        local current={}
        for index,entity in ipairs(storage.entities) do current[index]=snapshot(entity) end
        helpers.write_file("fusion-first-"..mode..".json",helpers.table_to_json(current),false)
        local report={fields=0}
        for index,row in ipairs(current) do compare(storage.baseline[index],row,"first-load"..index,report) end
        storage.verify_at=event.tick+600
    elseif mode~="donor" and storage.verify_at and event.tick==storage.verify_at then
        storage.verify_at=nil
        save_report(mode)
    end
end)
