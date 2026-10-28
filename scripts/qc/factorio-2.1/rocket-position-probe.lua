-- Private native phase/position survey. No shipping API or launch modifications.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local rows,started
    local triggers={}
    local old_trigger=script.get_event_handler(defines.events.on_script_trigger_effect)
    script.on_event(defines.events.on_script_trigger_effect,function(event)
        if old_trigger then old_trigger(event) end
        if event.effect_id=="rocket-position-probe" then
            triggers[#triggers+1]={tick=event.tick-started,source=event.source_position,target=event.target_position,
                entity=event.source_entity and event.source_entity.valid and event.source_entity.position}
        end
    end)
    local names={}
    for name,value in pairs(defines.rocket_silo_status) do names[value]=name end
    local confirmed=script.get_event_handler(defines.events.on_rocket_launched)
    script.on_event(defines.events.on_rocket_launched,function(event)
        for _,row in ipairs(rows or {}) do
            if row.rocket==event.rocket then row.confirmed={tick=event.tick-started,position=event.rocket.position} end
        end
        confirmed(event)
    end)
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not rows then
            rows={};started=event.tick
            local surface=game.surfaces.nauvis
            surface.request_to_generate_chunks({800,800},3);surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities_filtered{area={{750,750},{850,850}}}) do entity.destroy() end
            for index,quality in ipairs{"normal","rare","legendary"} do
                local silo=assert(surface.create_entity{name="rocket-silo",position={770+index*18,800},force="player",quality=quality})
                silo.rocket_parts=silo.prototype.rocket_parts_required
                local proto=silo.prototype.rocket_entity_prototype
                rows[#rows+1]={silo=silo,quality=quality,samples={},prototype={engine=proto.engine_starting_speed,
                    speed=proto.flying_speed,accel=proto.flying_acceleration,rising=proto.rising_speed}}
            end
        end
        local t=event.tick-started
        for _,row in ipairs(rows) do
            row.silo.energy=1000000000
            local phase=names[row.silo.rocket_silo_status]
            if phase=="rocket_ready" and not row.ordered then
                row.silo.get_inventory(defines.inventory.rocket_silo_rocket).insert{name="iron-plate",count=1}
                assert(row.silo.launch_rocket{type=defines.cargo_destination.orbit})
                row.ordered=t;row.rocket=row.silo.rocket
            end
            if row.rocket and row.rocket.valid and (phase~=row.phase or t%20==0) then
                row.samples[#row.samples+1]={tick=t,phase=phase,position=row.rocket.position}
            end
            row.phase=phase
        end
        if t==2500 then
            local result={passed=true,rows={},triggers=triggers}
            for _,row in ipairs(rows) do result.rows[#result.rows+1]={quality=row.quality,ordered=row.ordered,
                confirmed=row.confirmed,prototype=row.prototype,samples=row.samples} end
            helpers.write_file("rocket-position.json",helpers.table_to_json(result),false)
            script.on_event(defines.events.on_tick,previous)
        end
    end)
end
