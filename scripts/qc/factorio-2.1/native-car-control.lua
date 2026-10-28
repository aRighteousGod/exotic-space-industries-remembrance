local cases,start={},nil
script.on_event(defines.events.on_tick,function(event)
    if not start then
        start=event.tick
        local surface=game.create_surface("native-car-qc",{width=512,height=512,water=0})
        surface.request_to_generate_chunks({0,0},8);surface.force_generate_chunk_requests()
        for _,e in pairs(surface.find_entities()) do e.destroy() end
        local tiles={}
        for x=-60,60 do for y=-220,20 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
        surface.set_tiles(tiles)
        local index=0
        for _,fuel in ipairs{"coal","rocket-fuel","nuclear-fuel"} do
            for _,mode in ipairs{"coast","brake","accelerate"} do
                index=index+1
                local entity=surface.create_entity{name="car",position={(index-5)*12,0},force="player"}
                local driver=surface.create_entity{name="character",position={(index-5)*12,3},force="player"}
                entity.set_driver(driver)
                assert(entity.get_fuel_inventory().insert{name=fuel,count=1}==1)
                entity.speed=mode=="accelerate" and 0 or 0.8
                entity.riding_state={acceleration=mode=="brake" and defines.riding.acceleration.braking
                    or mode=="accelerate" and defines.riding.acceleration.accelerating or defines.riding.acceleration.nothing,
                    direction=defines.riding.direction.straight}
                cases[#cases+1]={entity=entity,fuel=fuel,mode=mode,samples={}}
            end
        end
    end
    local elapsed=event.tick-start
    if elapsed==1 or elapsed==10 or elapsed==30 or elapsed==60 or elapsed==120 or elapsed==180 then
        for _,case in ipairs(cases) do
            case.samples[#case.samples+1]={tick=elapsed,speed=case.entity.speed,position=case.entity.position,health=case.entity.health}
        end
    end
    if elapsed==180 then
        local rows={}
        for _,case in ipairs(cases) do rows[#rows+1]={fuel=case.fuel,mode=case.mode,samples=case.samples} end
        helpers.write_file("native-car.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,cases=rows},false)
    end
end)
