-- Paired native rocket timings and physical cargo custody; private fixture.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local started,rows
    local status_names={}
    for name,value in pairs(defines.rocket_silo_status) do status_names[value]=name end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not started then
            started=event.tick
            rows={}
            local surface=game.surfaces.nauvis
            surface.request_to_generate_chunks({800,800},3)
            surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities_filtered{area={{750,750},{850,850}}}) do entity.destroy() end
            local tiles={}
            for x=750,850 do for y=750,850 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
            surface.set_tiles(tiles)
            for index,quality in ipairs{"normal","rare","legendary"} do
                local platform=assert(game.forces.player.create_space_platform{
                    name="Rocket quality "..quality,planet="nauvis",starter_pack="space-platform-starter-pack"})
                local hub=platform.hub or platform.apply_starter_pack()
                assert(hub and hub.valid,"Platform did not acquire a native hub")
                local silo=assert(surface.create_entity{name="rocket-silo",position={770+index*18,800},force="player",quality=quality})
                silo.rocket_parts=silo.prototype.rocket_parts_required
                rows[#rows+1]={silo=silo,hub=hub,quality=quality,states={},parts_required=silo.prototype.rocket_parts_required}
            end
        end
        local elapsed=event.tick-started
        local complete=true
        for _,row in ipairs(rows) do
            local silo=row.silo
            silo.energy=1000000000
            local status=status_names[silo.rocket_silo_status]
            if status~=row.last_status then
                row.states[#row.states+1]={tick=elapsed,status=status}
                row.last_status=status
            end
            if not row.launch_tick and status=="rocket_ready" then
                local inventory=assert(silo.get_inventory(defines.inventory.rocket_silo_rocket))
                assert(inventory.insert{name="iron-plate",quality="rare",count=37}==37)
                assert(silo.launch_rocket{type=defines.cargo_destination.station,station=row.hub})
                row.launch_tick=elapsed
            end
            local count=row.hub.get_inventory(defines.inventory.hub_main).get_item_count{name="iron-plate",quality="rare"}
            assert(count==0 or count==37,"Cargo conservation failed")
            if count==37 and not row.delivery_tick then row.delivery_tick=elapsed end
            if not row.delivery_tick or status~="building_rocket" then complete=false end
        end
        if complete or elapsed==4000 then
            local result={passed=complete,engine=script.active_mods.base,rows={}}
            for _,row in ipairs(rows) do
                result.rows[#result.rows+1]={quality=row.quality,parts_required=row.parts_required,
                    launch_tick=row.launch_tick,delivery_tick=row.delivery_tick,states=row.states,
                    delivered=row.hub.get_inventory(defines.inventory.hub_main).get_item_count{name="iron-plate",quality="rare"}}
            end
            helpers.write_file("rocket-delivery.json",helpers.table_to_json(result),false)
            assert(complete,"Native rocket delivery did not complete")
            script.on_event(defines.events.on_tick,previous)
        end
    end)
end
