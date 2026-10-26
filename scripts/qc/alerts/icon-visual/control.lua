script.on_event(defines.events.on_tick,function(event)
    if storage.icon_visual_complete then return end
    local player=game.connected_players[1];if not player then return end
    local ok,result=pcall(remote.call,'ei-icons-qc','step',player.index,event.tick)
    if not ok then
        helpers.write_file('terrain-admin-qc.json',helpers.table_to_json{complete=true,all_pass=false,error=result},false)
        storage.icon_visual_complete=true;error(result)
    elseif result then
        game.set_wait_for_screenshots_to_finish()
        helpers.write_file('terrain-admin-qc.json',helpers.table_to_json(result),false)
        storage.icon_visual_complete=true
    end
end)
