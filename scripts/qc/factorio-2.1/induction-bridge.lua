-- Checkpoint/capture adapter around the unchanged established acceptance suite.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local captured=false
    local pending
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        local q=storage.induction_circuit_qc
        local player=game.connected_players[1]
        if not captured and player and q and q.complete and q.saved then
            captured=true
            local configuration=script.active_mods["zzz-esir-induction-circuit-qc"]=="0.0.2"
            local phase=configuration and "configuration" or (q.upgrade_capture and "reload" or "initial")
            q.upgrade_capture=true
            player.teleport({0,8},q.surface)
            pending={tick=event.tick+120,close_tick=event.tick+30,reopen_tick=event.tick+60,phase=phase,report={
                passed=true,engine=script.active_mods.base,checks=q.checks,cases=q.cases,
                phase=phase,secondary_viewers=q.secondary_viewers,locale=player.locale,
                display_resolution=player.display_resolution,display_scale=player.display_scale}}
            game.auto_save("induction-"..phase)
        end
        if pending and pending.close_tick and event.tick>=pending.close_tick then
            pending.close_tick=nil
            ei_induction_matrix.close_gui(player)
            player.opened=nil
        end
        if pending and pending.reopen_tick and event.tick>=pending.reopen_tick then
            pending.reopen_tick=nil
            ei_induction_matrix.open_gui(player,q.a.unit_number)
        end
        if pending and event.tick>=pending.tick then
            game.take_screenshot{player=player,surface=q.surface,position={0,0},resolution=player.display_resolution,
                zoom=1,path="induction-"..pending.phase..".png",show_gui=true}
            helpers.write_file("induction-"..pending.phase..".json",helpers.table_to_json(pending.report),false)
            pending=nil
        end
    end)
end
