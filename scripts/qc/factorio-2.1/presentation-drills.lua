-- Supplemental native dry/wet connector captures; shipping scene strings above
-- remain unmodified and run with isolated runtime controls.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local rigs,started,done=nil,nil,false
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not rigs then
            rigs={};started=event.tick
            local prototype=prototypes.mod_data["esir-upgrade-drill-qc"]
            local spec={drills=prototype.get("drills"),wet_resource=prototype.get("wet_resource"),wet_fluid=prototype.get("wet_fluid")}
            local surface=game.create_surface("upgrade-drill-connectors",{width=128,height=128})
            surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities()) do entity.destroy() end
            surface.destroy_decoratives{}
            local tiles={}
            for x=-50,50 do for y=-50,50 do tiles[#tiles+1]={name=(x+y)%2==0 and "lab-dark-1" or "lab-dark-2",position={x,y}} end end
            surface.set_tiles(tiles);surface.always_day=true
            local index=0
            for _,drill in ipairs(spec.drills) do
                for _,wet in ipairs{false,true} do
                    for direction_index=0,3 do
                        index=index+1
                        local position={x=((index-1)%4)*12-18,y=math.floor((index-1)/4)*12-18}
                        for x=-1,1 do for y=-1,1 do surface.create_entity{
                            name=wet and spec.wet_resource or "iron-ore",position={position.x+x,position.y+y},amount=100000} end end
                        local entity=assert(surface.create_entity{name=drill.name,position=position,direction=direction_index*4,force="player"})
                        local pole=surface.create_entity{name="substation",position={position.x+4,position.y-3},force="player"}
                        local power=surface.create_entity{name="electric-energy-interface",position={position.x+6,position.y-3},force="player"}
                        power.power_production=1e9;power.electric_buffer_size=1e9;power.energy=1e9
                        assert(entity.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(
                            pole.get_wire_connector(defines.wire_connector_id.circuit_red,true),false,defines.wire_origin.player),"Native drill red wire")
                        assert(surface.create_entity{name="steel-chest",position=entity.drop_position,force="player"},"Drill output chest")
                        rigs[#rigs+1]={entity=entity,wet=wet,fluid=spec.wet_fluid,direction=direction_index*4}
                    end
                end
            end
        end
        for _,rig in ipairs(rigs) do
            if rig.wet and rig.entity.fluids_count>0 then rig.entity.insert_fluid{name=rig.fluid,amount=100} end
        end
        if not done and event.tick-started==180 then
            done=true
            local report={passed=true,cases={},engine=script.active_mods.base}
            for _,rig in ipairs(rigs) do
                assert(rig.entity.valid and rig.entity.direction==rig.direction,"Native drill direction")
                local name=rig.entity.name.."-"..(rig.wet and "wet" or "dry").."-"..rig.direction
                if rig.wet then assert(rig.entity.get_fluid_count(rig.fluid)>0,"Wet drill has no admitted fluid") end
                local status_name
                for key,value in pairs(defines.entity_status) do if value==rig.entity.status then status_name=key;break end end
                report.cases[#report.cases+1]={name=name,direction=rig.direction,wet=rig.wet,status=rig.entity.status,status_name=status_name,
                    drop_position=rig.entity.drop_position,drop_target=rig.entity.drop_target and rig.entity.drop_target.name}
                game.take_screenshot{surface=rig.entity.surface,position=rig.entity.position,resolution={512,384},zoom=1.6,
                    path="drill-connectors/"..name..".png",daytime=0,show_gui=false,show_entity_info=true,force_render=true}
            end
            helpers.write_file("drill-connectors.json",helpers.table_to_json(report),false)
        end
    end)
end
