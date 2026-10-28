-- Populated native donor, configuration migration, then a second saved reload.
local mode=require("test-config")
local modern=script.active_mods.base:match("^2%.1%.")~=nil
local loaded=false
script.on_load(function() loaded=true end)
local function fluid_debug(phase)
    local entity=storage.entities[2]
    local result={version=script.active_mods.base,tick=game.tick,storages={},pipe_valid=storage.pipe.valid}
    for index=1,entity.fluids_count do
        local row={index=index,fluid=entity.get_fluid(index)}
        if modern then
            row.capacity=entity.get_fluid_capacity(index)
            row.segment=entity.has_fluid_segment(index) and entity.get_fluid_segment_fluid(index) or nil
        end
        table.insert(result.storages,row)
    end
    if not modern then
        result.old_boxes={}
        for index=1,#entity.fluidbox do
            result.old_boxes[index]={fluid=entity.fluidbox[index],capacity=entity.fluidbox.get_capacity(index),
                segment=entity.fluidbox.get_fluid_segment_contents(index)}
        end
    end
    helpers.write_file("turbine-fluid-"..phase..".json",helpers.table_to_json(result),false)
end
local function snapshot(entity)
    local burner=entity.burner
    local record=remote.call("esir-turbine-qc","record",entity)
    local minable,disabled
    if modern then minable=entity.minable_flag;disabled=entity.disabled_by_script
    else minable=entity.minable;disabled=not entity.active end
    local result={name=entity.name,unit=entity.unit_number,quality=entity.quality.name,
        position=entity.position,direction=entity.direction,health=entity.health,energy=entity.energy,
        minable=minable,
        destructible=entity.destructible,operable=entity.operable,rotatable=entity.rotatable,
        disabled=disabled,
        mode=record.mode,owner_unit=record.unit_number}
    if burner then
        result.fuel=entity.get_fuel_inventory().get_contents()
        local burnt=entity.get_burnt_result_inventory()
        result.burnt=burnt and burnt.get_contents() or {}
        local burning=burner.currently_burning
        result.burning=burning and {name=burning.name.name,quality=burning.quality.name}
        result.remaining=burner.remaining_burning_fuel
    else
        local fluid=entity.get_fluid(1)
        result.fluid_name=fluid and fluid.name
        result.fluid_temperature=fluid and fluid.temperature
        local total,segments=0,{}
        if not modern then
            -- The old generator exposes its private consumer store through
            -- get_fluid and its connected flow store through LuaFluidBox.
            total=entity.get_fluid_count("ei-diesel")
            for index=1,#entity.fluidbox do
                local contents=entity.fluidbox.get_fluid_segment_contents(index)
                local id=contents and entity.fluidbox.get_fluid_segment_id(index)
                if id and not segments[id] then
                    segments[id]=true
                    total=total+(contents["ei-diesel"] or 0)
                end
            end
        end
        for index=1,modern and entity.fluids_count or 0 do
            local segment
            if modern then
                if entity.has_fluid_segment(index) then segment=entity.get_fluid_segment_id(index) end
            else
                if entity.fluidbox.get_fluid_segment_contents(index) then segment=entity.fluidbox.get_fluid_segment_id(index) end
            end
            if segment then
                if not segments[segment] then
                    segments[segment]=true
                    if modern then
                        local contents=entity.get_fluid_segment_fluid(index)
                        total=total+(contents and contents.amount or 0)
                    else
                        total=total+(entity.fluidbox.get_fluid_segment_contents(index)["ei-diesel"] or 0)
                    end
                end
            else
                local contents=entity.get_fluid(index)
                total=total+(contents and contents.amount or 0)
            end
        end
        result.fluid_total=total
        result.proxy_exists=record.proxy and record.proxy.valid or false
        result.proxy_quality=record.proxy.quality.name
    end
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
local function report_and_save(phase)
    fluid_debug(phase)
    local report={passed=true,version=script.active_mods.base,phase=phase,fields=0,tick=game.tick,cases={},
        accepted_native_overflow=storage.accepted_native_overflow}
    for index,entity in ipairs(storage.entities) do
        local state=snapshot(entity)
        compare(storage.baseline[index],state,"turbine"..index,report)
        report.cases[index]=state
    end
    helpers.write_file("turbine-"..phase..".json",helpers.table_to_json(report),false)
    game.auto_save("turbine-"..phase)
end
script.on_event(defines.events.on_tick,function(event)
    if mode=="donor" and event.tick==1 and not storage.ready then
        local surface=game.create_surface("turbine-migration-qc",{width=128,height=128})
        surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        storage.entities={}
        for index,name in ipairs{"ei-combustion-turbine","ei-combustion-turbine-fluid"} do
            local entity=assert(surface.create_entity{name=name,position={index*25,0},force="player",quality="rare"})
            entity.health=123;entity.energy=12345
            if modern then entity.minable_flag=false;entity.disabled_by_script=true
            else entity.minable=false;entity.active=false end
            entity.destructible=false;entity.operable=false;entity.rotatable=false
            remote.call("esir-turbine-qc","register",entity,event.tick)
            if entity.burner then
                entity.get_fuel_inventory().insert{name="coal",count=13,quality="rare"}
                local burnt=entity.get_burnt_result_inventory()
                if burnt and #burnt>0 then assert(burnt.insert{name="atan-ash",count=5,quality="rare"}==5) end
                entity.burner.currently_burning={name="coal",quality="rare"};entity.burner.remaining_burning_fuel=123456
            else
                storage.pipe=assert(surface.create_entity{name="pipe",position={55,0},force="player"})
                entity.fluidbox[1]={name="ei-diesel",amount=230,temperature=60}
            end
            storage.entities[index]=entity
        end
    elseif mode=="donor" and event.tick==5 and not storage.ready then
        storage.baseline={snapshot(storage.entities[1]),snapshot(storage.entities[2])}
        storage.ready=true
        report_and_save("donor")
    elseif mode~="donor" and loaded and storage.ready then
        loaded=false
        storage.verify_at=event.tick+600
        fluid_debug("first-"..mode)
        if mode=="migration" and not storage.accepted_native_overflow then
            local total=snapshot(storage.entities[2]).fluid_total
            -- This exact donor has a 109.6345603466-unit legacy segment with
            -- nominal capacity 100. Native 2.1 clips its excess before Lua runs.
            -- The user explicitly accepted this limit instead of a prep step.
            assert(math.abs(total-220.3654396533966)<1e-6,"Unexpected native fluid migration result")
            storage.accepted_native_overflow={before=storage.baseline[2].fluid_total,after=total,
                lost=storage.baseline[2].fluid_total-total,reason="accepted native overfilled-segment clipping"}
            storage.baseline[2].fluid_total=total
        end
        local report={fields=0}
        for index,entity in ipairs(storage.entities) do compare(storage.baseline[index],snapshot(entity),"first-load"..index,report) end
    elseif mode~="donor" and storage.verify_at and event.tick==storage.verify_at then
        storage.verify_at=nil
        report_and_save(mode)
    end
end)
