local complete=false
local started
local pending
local finish_tick
script.on_event(defines.events.on_tick,function(event)
    if complete then return end
    local player=game.connected_players[1];if not player then return end
    started=started or event.tick
    if event.tick-started<120 then return end
    if not pending then
        local ok,result=pcall(remote.call,"ei-menu-controls-qc","step",player.index,event.tick)
        if not ok then result={complete=true,all_pass=false,error=tostring(result)} end
        if result.complete then pending=result;finish_tick=event.tick+120 end
    end
    -- Allow the requested native autosave to finish before the driver exits.
    if pending and event.tick>=finish_tick then
        complete=true
        game.set_wait_for_screenshots_to_finish()
        helpers.write_file("terrain-admin-qc.json",helpers.table_to_json(pending),false)
        log("MENU_CONTROLS_QC complete pass="..tostring(pending.all_pass))
    end
end)
