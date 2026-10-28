local mode=require("test-config")
local modern=script.active_mods.base:match("^2%.1%.")~=nil
local loaded=false
script.on_load(function() loaded=true end)
local function capture()
    local report={engine=script.active_mods.base,phase=mode,tick=game.tick,cases={}}
    for index,entity in ipairs(storage.entities) do
        local row={seeded=storage.amounts[index],storages={}}
        if modern then
            row.total=0
            local seen={}
            for fluid_index=1,entity.fluids_count do
                local fluid=entity.get_fluid(fluid_index)
                local segment=entity.has_fluid_segment(fluid_index)
                row.storages[fluid_index]={fluid=fluid,capacity=entity.get_fluid_capacity(fluid_index),has_segment=segment}
                if segment then
                    local id=entity.get_fluid_segment_id(fluid_index)
                    if not seen[id] then
                        seen[id]=true
                        local contents=entity.get_fluid_segment_fluid(fluid_index)
                        row.segment=contents
                        row.total=row.total+(contents and contents.amount or 0)
                    end
                else row.total=row.total+(fluid and fluid.amount or 0) end
            end
        else
            row.private=entity.get_fluid_count("qc-native-fuel")
            row.segment=entity.fluidbox.get_fluid_segment_contents(1)
            row.total=row.private+(row.segment["qc-native-fuel"] or 0)
            row.storages[1]={fluid=entity.get_fluid(1),capacity=entity.fluidbox.get_capacity(1)}
        end
        row.conserved=math.abs(row.total-row.seeded)<1e-6
        report.cases[index]=row
    end
    helpers.write_file("native-generator-"..mode..".json",helpers.table_to_json(report),false)
    game.auto_save("native-generator-"..mode)
end
script.on_event(defines.events.on_tick,function(event)
    if mode=="donor" and event.tick==1 then
        local surface=game.create_surface("native-generator-qc",{width=128,height=128})
        surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        storage.entities={};storage.amounts={100,200,230}
        for index,amount in ipairs(storage.amounts) do
            local entity=assert(surface.create_entity{name="qc-native-generator",position={index*20,0},force="player"})
            local pipe=assert(surface.create_entity{name="qc-native-pipe",position={index*20+2,0},force="player"})
            entity.active=false
            entity.fluidbox[1]={name="qc-native-fuel",amount=amount,temperature=60}
            storage.entities[index]=entity
        end
    elseif mode=="donor" and event.tick==601 then capture()
    elseif mode=="prepare" and loaded then
        loaded=false
        for _,entity in ipairs(storage.entities) do
            assert(entity.surface.create_entity{name="qc-native-pipe",
                position={entity.position.x+3,entity.position.y},force="player"})
        end
        capture()
    elseif mode=="migration" and loaded then loaded=false;capture() end
end)
