-- Actual 2.0 pending-launch donor and 2.1 custody/second-save acceptance.
do
    local modern=script.active_mods.base:match("^2%.1%.")~=nil
    local previous=script.get_event_handler(defines.events.on_tick)
    local confirmed=script.get_event_handler(defines.events.on_rocket_launched)
    local observed_reload=false
    script.on_event(defines.events.on_rocket_launched,function(event)
        local state=storage.rocket_upgrade_qc
        local matched
        for _,row in ipairs(state and state.rows or {}) do if row.rocket==event.rocket then matched=row end end
        confirmed(event)
        if matched then matched.confirmed=event.tick end
    end)
    script.on_event(defines.events.on_tick,function(event)
        local existing=storage.rocket_upgrade_qc
        if modern and existing and not observed_reload then
            observed_reload=true
            existing.resumptions=(existing.resumptions or 0)+1
            for _,row in ipairs(existing.rows) do
                assert(row.silo.valid and row.silo.quality.name==row.quality,"Silo quality lost")
                local launch=storage.ei.rocket_launch_pollution.pending_launches_by_silo[row.silo.unit_number]
                if not row.confirmed then
                    assert(launch and launch.rocket==row.rocket and row.rocket.valid,"Pending rocket identity lost")
                    assert(launch.emitted_pollution>=row.saved_emitted and launch.emitted_pollution<=10000,"Paid launch balance lost")
                end
            end
        end
        previous(event)
        local state=storage.rocket_upgrade_qc
        if not state then
            assert(not modern,"Migration fixture requires an actual 2.0 donor")
            local surface=game.create_surface("rocket-upgrade-custody",{width=128,height=128})
            surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
            local tiles={}
            for x=-40,40 do for y=-20,20 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
            surface.set_tiles(tiles);game.forces.player.set_evolution_factor(1,surface)
            state={rows={},surface=surface,baseline=surface.pollution_statistics.get_input_count("ei-rocket-launch-pollution")}
            for i,quality in ipairs{"normal","rare","legendary"} do
                local silo=assert(surface.create_entity{name="rocket-silo",position={-40+i*20,0},quality=quality,force="player"})
                silo.rocket_parts=silo.prototype.rocket_parts_required
                state.rows[#state.rows+1]={silo=silo,quality=quality}
            end
            storage.rocket_upgrade_qc=state
            game.speed=16
        end
        for _,row in ipairs(state.rows) do
            row.silo.energy=1000000000
            if not row.rocket and row.silo.rocket_silo_status==defines.rocket_silo_status.rocket_ready then
                local config=storage.ei.rocket_launch_pollution
                config.mode="linear";config.cap=10000;config.visual_style="cinematic"
                row.silo.get_inventory(defines.inventory.rocket_silo_rocket).insert{name="iron-plate",count=1}
                assert(row.silo.launch_rocket{type=defines.cargo_destination.orbit})
                row.rocket=row.silo.rocket
            end
            local launch=storage.ei.rocket_launch_pollution.pending_launches_by_silo[row.silo.unit_number]
            if launch and launch.ignition_tick then row.ignition=launch.ignition_tick end
            if not row.clamp and row.silo.rocket_silo_status==defines.rocket_silo_status.arms_retract then row.clamp=event.tick end
        end
        local first=state.rows[1]
        if not modern then
            local label
            if first.ignition and event.tick==first.ignition+100 then label="ignition" end
            if first.clamp and event.tick==first.clamp+60 then label="ascent" end
            if label then
                for _,row in ipairs(state.rows) do
                    row.saved_emitted=storage.ei.rocket_launch_pollution.pending_launches_by_silo[row.silo.unit_number].emitted_pollution
                end
                state.saved_phase=label;state.saved_tick=event.tick
                game.auto_save("rocket-upgrade-"..label)
                log("ROCKET_MIGRATION_CHECKPOINT "..label)
            end
        else
            local complete=true
            for _,row in ipairs(state.rows) do if not row.confirmed or event.tick<row.confirmed+2 then complete=false end end
            if complete then
                local total=state.surface.pollution_statistics.get_input_count("ei-rocket-launch-pollution")-state.baseline
                assert(math.abs(total-30000)<.01,"Migration duplicated/lost launch pollution: "..total)
                local rows={}
                for _,row in ipairs(state.rows) do rows[#rows+1]={quality=row.quality,ignition=row.ignition,
                    clamp=row.clamp,confirmed=row.confirmed,saved_emitted=row.saved_emitted} end
                if not state.saved_complete then
                    state.saved_complete=true
                    game.auto_save("rocket-upgrade-complete")
                end
                helpers.write_file("rocket-migration.json",helpers.table_to_json{passed=true,rows=rows,
                    total=total,donor_phase=state.saved_phase,resumptions=state.resumptions,
                    completed_checkpoint=state.saved_complete},false)
            end
        end
    end)
end
