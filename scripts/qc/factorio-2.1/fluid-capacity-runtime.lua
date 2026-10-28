-- Read actual native capacities in an otherwise unchanged pinned full core.
local modern=script.active_mods.base:match("^2%.1%.")~=nil
script.on_event(defines.events.on_tick,function(event)
    if event.tick~=1 then return end
    local surface=game.create_surface("fluid-capacity-qc",{width=128,height=128})
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    local result={version=script.active_mods.base,cases={}}
    local index=0
    for _,volume in ipairs{1,30,100} do
        for _,amount in ipairs{1,15,30,100} do
            for multiplier=1,3 do
                index=index+1
                local entity=assert(surface.create_entity{name="qc-fluid-capacity-"..index,
                    position={(index%6)*5,math.floor(index/6)*5},force="player"})
                local cold=modern and entity.get_fluid_capacity(1) or entity.fluidbox.get_capacity(1)
                local hot=modern and entity.get_fluid_capacity(2) or entity.fluidbox.get_capacity(2)
                result.cases[#result.cases+1]={volume=volume,amount=amount,multiplier=multiplier,
                    input_capacity=cold,output_capacity=hot}
            end
        end
    end
    helpers.write_file("fluid-capacity.json",helpers.table_to_json(result),false)
    log("FLUID CAPACITY PROBE COMPLETE")
end)
