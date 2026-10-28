-- Private native connector capability and custody through the public build handler.
do
    local crystal=require("scripts/control/crystal-accumulator")
    local previous=script.get_event_handler(defines.events.on_tick)
    local loaded=false
    local first_tick=true
    script.on_event(defines.events.on_tick,function(event)
        if first_tick then loaded=storage.crystal_wire_qc~=nil;first_tick=false end
        previous(event)
        if loaded and storage.crystal_wire_qc then
            if event.tick>=storage.crystal_wire_qc.tick+60 then
                for _,row in ipairs(storage.crystal_wire_qc.rows) do
                    -- EEI shells lack get-by-unit-number; the saved unit is
                    -- still an identity check on the bounded fixture surfaces.
                    local entity
                    for _,surface in pairs(game.surfaces) do
                        for _,candidate in pairs(surface.find_entities_filtered{name=row.name}) do
                            if candidate.unit_number==row.unit then entity=candidate;break end
                        end
                        if entity then break end
                    end
                    assert(entity and entity.valid and entity.name==row.name and entity.quality.name==row.quality)
                    assert(next(entity.get_wire_connectors(false))==nil,"Unexpected core connector capability")
                end
                helpers.write_file("crystal-wire-reload.json",helpers.table_to_json{passed=true,rows=storage.crystal_wire_qc.rows},false)
            end
            return
        end
        if storage.crystal_wire_qc then return end
        local rows={}
        local gaia=game.planets.gaia.surface or game.planets.gaia.create_surface()
        -- The ESIR Gaia-start preset may classify Nauvis as Gaia. Use an
        -- explicitly ordinary surface for the downgrade half of this fixture.
        local ordinary=game.create_surface("crystal-ordinary-qc",{width=64,height=64})
        for index,surface in ipairs{ordinary,gaia} do
            local position={1000,0}
            surface.request_to_generate_chunks(position,2);surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities_filtered{area={{980,-20},{1020,20}}}) do entity.destroy() end
            local tiles={}
            for x=980,1020 do for y=-20,20 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
            surface.set_tiles(tiles)
            for qindex,quality in ipairs{"normal","rare"} do
                local x=990+qindex*10
                local before=index==1 and "ei-crystal-accumulator-gaia" or "ei-crystal-accumulator"
                local after=index==1 and "ei-crystal-accumulator" or "ei-crystal-accumulator-gaia"
                local entity=assert(surface.create_entity{name=before,position={x,0},quality=quality,force="player"})
                local actual_position=entity.position
                local energy=12345678
                entity.energy=energy
                local health=entity.max_health*0.7;entity.health=health
                -- Core bodies are electric-energy-interface prototypes and do
                -- not expose circuit connectors. Do not invent wire coverage.
                assert(entity.type=="electric-energy-interface")
                assert(next(entity.get_wire_connectors(false))==nil)
                local wrong_call_ok=pcall(entity.get_wire_connectors,entity,false)
                assert(not wrong_call_ok,"The duplicate-self diagnostic changed")
                crystal.on_built_entity{entity=entity,tick=event.tick}
                local candidates=surface.find_entities_filtered{position=actual_position,radius=2,name=after}
                local replacement=candidates[1]
                assert(replacement,"Missing swapped shell: "..helpers.table_to_json{surface=surface.name,
                    before=before,after=after,old_valid=entity.valid,unit=entity.valid and entity.unit_number,
                    gaia=storage.gaia_surfaces and storage.gaia_surfaces[surface.name],position=actual_position})
                assert(not entity.valid and replacement.quality.name==quality)
                assert(replacement.energy==energy and replacement.health==health,"Shell resource custody changed")
                assert(next(replacement.get_wire_connectors(false))==nil)
                rows[#rows+1]={unit=replacement.unit_number,name=after,quality=quality,energy=energy,health=health,circuit_capable=false}
            end
        end
        storage.crystal_wire_qc={rows=rows,tick=event.tick}
        game.auto_save("crystal-wire")
        helpers.write_file("crystal-wire.json",helpers.table_to_json{passed=true,rows=rows},false)
    end)
end
