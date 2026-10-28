-- Appended to the isolated established fixture; its local helpers remain in scope.
local native_loaded=false
local native_start
-- Opening a console legitimately queues its cohort for service. Keep those
-- extra wakeups out of the established timed arbitration fixture; exercise
-- all four native consoles after its 16 mutations have settled.
local native_gui_smoke=collect_gui_smoke
collect_gui_smoke=function(state,tick)
    if tick < state.base_tick+500 then
        return {available=false,runtime_present=true,player_present=false,probes={},deferred_native_phase=true}
    end
    return native_gui_smoke(state,tick)
end
script.on_load(function() native_loaded=true end)
local function prepare_native_player(event)
    local player=game.get_player(event.player_index)
    player.force=get_force()
    player.set_controller{type=defines.controllers.god}
    player.teleport(ORIGIN,game.surfaces.nauvis)
    game.tick_paused=false
    helpers.write_file("orbital-client-ready.json",helpers.table_to_json{tick=game.tick,player=player.index,connected=player.connected},false)
end
script.on_event(defines.events.on_player_created,prepare_native_player)
script.on_event(defines.events.on_player_joined_game,prepare_native_player)
local original_write=write_record
write_record=function(record)
    original_write(record)
    if #game.connected_players==0 then return end
    storage.native_orbital=storage.native_orbital or {actions=0,gui_checks=0}
    local report=storage.native_orbital
    if record.kind=="action" then
        assert(record.config_ok and record.expectation and record.expectation.ok,"Orbital mutation failed: "..record.action)
        report.actions=report.actions+1
    end
    if record.gui_validation and not (record.gui_smoke and record.gui_smoke.deferred_native_phase) then
        assert(record.gui_validation.ok and not record.gui_validation.skipped,"Orbital native GUI probes failed: "..helpers.table_to_json(record.gui_validation))
        report.gui_checks=report.gui_checks+record.gui_validation.summary.probe_count
    end
end
local original_tick=script.get_event_handler(defines.events.on_tick)
script.on_event(defines.events.on_tick,function(event)
    local player=game.connected_players[1]
    if not player then return end
    if not native_start then
        native_start=event.tick
        player.force=get_force()
        player.teleport(ORIGIN,game.surfaces.nauvis)
        player.set_controller{type=defines.controllers.god}
        game.tick_paused=false
    end
    original_tick(event)
    local elapsed=event.tick-native_start
    local state=ensure_state()
    local report=storage.native_orbital
    if native_loaded and report and report.done then
        if elapsed==30 then
            local smoke=collect_gui_smoke(state,event.tick)
            local validation=validate_gui_smoke(smoke)
            assert(validation.ok and not validation.skipped,helpers.table_to_json(validation))
            for key,unit in pairs(report.entity_units) do assert(state.entity_units[key]==unit,"Saved orbital body changed: "..key) end
            helpers.write_file("orbital-client-reload.json",helpers.table_to_json{passed=true,reload=true,gui=smoke,actions=report.actions,gui_checks=report.gui_checks,entity_units=state.entity_units},false)
        end
        return
    end
    if elapsed==520 then
        local smoke=collect_gui_smoke(state,event.tick)
        local validation=validate_gui_smoke(smoke)
        assert(validation.ok and not validation.skipped,helpers.table_to_json(validation))
        report.gui_checks=report.gui_checks+validation.summary.probe_count
    end
    local keys={"transponder_alpha","selector_a","coordinator_b","uplink_a"}
    for index,key in ipairs(keys) do
        local tick=600+(index-1)*60
        if elapsed==tick then
            local entity=assert(get_gui_probe_target(state,get_force(),key))
            close_qc_gui(player,nil,event.tick)
            player.teleport(entity.position,entity.surface)
            player.opened=entity
            remote.call("esir-orbital-gui-qc","opened",{player_index=player.index,tick=event.tick,entity=entity,gui_type=defines.gui_type.entity})
            assert(get_qc_gui_root(player),"Console did not open: "..key)
        elseif elapsed==tick+10 then
            local root=assert(get_qc_gui_root(player))
            if root.type=="frame" and root.parent==player.gui.screen then root.bring_to_front() end
            game.take_screenshot{player=player.index,position=player.position,surface=player.surface,resolution=player.display_resolution,show_gui=true,path="orbital-"..key..".png"}
        end
    end
    if elapsed==900 then
        assert(report and report.actions==16 and report.gui_checks>0,"Incomplete native orbital cohort")
        report.entity_units={}
        for key,unit in pairs(state.entity_units) do report.entity_units[key]=unit end
        report.done=true
        game.auto_save("orbital-client")
        helpers.write_file("orbital-client.json",helpers.table_to_json{passed=true,actions=report.actions,gui_checks=report.gui_checks,entity_units=report.entity_units},false)
    end
end)
