-- Private paired native handling probe. No shipping callbacks or prototypes change.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local started,cases,reported=nil,{},false
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not started then
            started=event.tick
            local surface=game.create_surface("vehicle-handling-qc",{width=1024,height=1024,water=0,peaceful_mode=true})
            surface.request_to_generate_chunks({0,-64},9);surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities()) do entity.destroy() end
            local tiles={}
            for x=-160,160 do for y=-320,64 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
            surface.set_tiles(tiles)
            local index=0
            -- ei-drone is an inactive source definition, absent from merged data.
            for _,name in ipairs{"car","tank","ei-emerald-apocalypse-hover-tank"} do
                for _,quality in ipairs{"normal","rare"} do
                    for _,mode in ipairs{"coast","brake","accelerate"} do
                        index=index+1
                        local position={x=(index-12)*12,y=0}
                        local entity=assert(surface.create_entity{name=name,position=position,force="player",quality=quality,raise_built=true})
                        local driver=surface.create_entity{name="character",position={position.x,3},force="player"}
                        entity.set_driver(driver)
                        local fuel=entity.get_fuel_inventory()
                        local fuel_name
                        if fuel then
                            -- Use the same first admitted fuel on both engine versions.
                            local candidates={"coal","nuclear-fuel"}
                            for _,candidate in ipairs(candidates) do
                                if prototypes.item[candidate] and fuel.insert{name=candidate,count=1}>0 then fuel_name=candidate;break end
                            end
                            assert(fuel_name,"Missing admitted handling fuel: "..name)
                        end
                        local hover=name=="ei-emerald-apocalypse-hover-tank"
                        entity.speed=(hover or mode=="accelerate") and 0 or 0.8
                        entity.riding_state={acceleration=hover and defines.riding.acceleration.accelerating or mode=="brake" and defines.riding.acceleration.braking
                            or mode=="accelerate" and defines.riding.acceleration.accelerating or defines.riding.acceleration.nothing,
                            direction=defines.riding.direction.straight}
                        if hover then ei_emerald_apocalypse_hover_tank.on_built_entity{entity=entity,tick=event.tick} end
                        cases[#cases+1]={entity=entity,name=name,quality=quality,mode=mode,fuel=fuel_name,start=position,samples={},hover=hover}
                    end
                end
            end
        end
        local elapsed=event.tick-started
        if elapsed==1 or elapsed==10 or elapsed==30 or elapsed==60 or elapsed==120 or elapsed==180 then
            for _,case in ipairs(cases) do
                assert(case.entity.valid,"Handling body lost")
                local record=case.hover and storage.ei.emerald_apocalypse_hover_tank.tanks_by_unit[case.entity.unit_number]
                local speed=record and math.sqrt(record.drift_x^2+record.drift_y^2) or case.entity.speed
                case.samples[#case.samples+1]={tick=elapsed,speed=speed,native_speed=case.entity.speed,position=case.entity.position,orientation=case.entity.orientation}
            end
        end
        if elapsed==60 then
            for _,case in ipairs(cases) do
                if case.hover and case.mode~="accelerate" then
                    case.entity.riding_state={acceleration=case.mode=="brake" and defines.riding.acceleration.braking or defines.riding.acceleration.nothing,
                        direction=defines.riding.direction.straight}
                end
            end
        end
        if elapsed==180 and not reported then
            reported=true
            local rows={}
            for _,case in ipairs(cases) do
                local speed=math.abs(case.samples[#case.samples].speed)
                assert(case.mode~="accelerate" or speed>0,"Acceleration did not move "..case.name)
                assert(case.mode~="brake" or speed<0.8,"Brake did not reduce speed "..case.name)
                rows[#rows+1]={name=case.name,quality=case.quality,mode=case.mode,fuel=case.fuel,samples=case.samples}
            end
            helpers.write_file("vehicle-handling.json",helpers.table_to_json({passed=true,engine=script.active_mods.base,registered_builds=true,hover_thrust_preroll_ticks=60,cases=rows}),false)
        end
    end)
end
