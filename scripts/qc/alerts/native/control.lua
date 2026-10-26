-- Isolated fixture only; no remote surface is shipped by the gameplay mod.
local first_tick=true
script.on_event(defines.events.on_tick,function(event)
    if storage.finished and not first_tick then return end
    local player=game.connected_players[1]
    if not player then return end
    storage.finished=false
    local ok,result=pcall(remote.call,"ei-alerts-qc","step",player.index,event.tick,first_tick)
    first_tick=false
    if not ok then
        helpers.write_file("terrain-admin-qc.json",helpers.table_to_json{complete=true,all_pass=false,error=result},false)
        storage.finished=true;error(result)
    elseif result then
        game.set_wait_for_screenshots_to_finish()
        helpers.write_file("terrain-admin-qc.json",helpers.table_to_json(result),false)
        storage.finished=true
    end
end)
