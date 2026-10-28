-- Actual capacity/custody, with no recipe able to run without its iron input.
do
    local old=script.get_event_handler(defines.events.on_tick)
    local loaded=false
    local first_tick=true
    script.on_event(defines.events.on_tick,function(event)
        if first_tick then loaded=storage.native_buffers_qc~=nil;first_tick=false end
        old(event)
        if storage.native_buffers_qc then
            if loaded and event.tick>=storage.native_buffers_qc.tick+60 then
                for _,row in ipairs(storage.native_buffers_qc.rows) do
                    local entity=row.entity
                    assert(entity.valid and entity.quality.name==row.quality)
                    assert(entity.get_fluid_capacity(1)==row.input_capacity and entity.get_fluid_capacity(2)==row.output_capacity)
                    assert(entity.get_fluid(1).amount==120 and entity.get_fluid(1).temperature==37)
                    assert(entity.get_fluid(2).amount==120 and entity.get_fluid(2).temperature==74)
                end
                helpers.write_file("native-buffers-reload.json",helpers.table_to_json{passed=true,cases=#storage.native_buffers_qc.rows},false)
            end
            return
        end
        local surface=game.create_surface("native-buffer-custody",{width=128,height=128})
        surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
        local rows={};local result={passed=true,rows={}}
        for _,volume in ipairs{1,100} do
            for _,spec in ipairs{{"native-default",4,3},{"legacy-default",2,2},{"native-explicit",11,3},{"legacy-explicit",10,2}} do
                for _,quality in ipairs{"normal","rare","legendary"} do
                    local n=#rows;local name="qc-buffer-"..spec[1].."-"..volume
                    local entity=assert(surface.create_entity{name=name,quality=quality,force="player",position={-20+(n%6)*7,-20+math.floor(n/6)*7}})
                    local input=entity.get_fluid_capacity(1);local output=entity.get_fluid_capacity(2)
                    assert(input==math.max(volume,60*spec[2]),name.." input "..input)
                    assert(output==math.max(volume,60*spec[3]),name.." output "..output)
                    entity.set_fluid(1,{name="water",amount=120,temperature=37})
                    entity.set_fluid(2,{name="water",amount=120,temperature=74})
                    assert(entity.get_fluid(1).amount==120 and entity.get_fluid(2).amount==120)
                    rows[#rows+1]={entity=entity,quality=quality,input_capacity=input,output_capacity=output}
                    result.rows[#result.rows+1]={name=name,quality=quality,volume=volume,input_capacity=input,output_capacity=output}
                end
            end
        end
        storage.native_buffers_qc={rows=rows,tick=event.tick}
        game.auto_save("native-buffers")
        helpers.write_file("native-buffers.json",helpers.table_to_json(result),false)
    end)
end
