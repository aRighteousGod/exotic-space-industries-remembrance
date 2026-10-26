-- Host must verify asynchronous checkpoint completion before terminating phase 1.
local first_tick=true
local checkpoint,checkpoint_tick
script.on_event(defines.events.on_tick,function(event)
    if checkpoint then
        if event.tick-checkpoint_tick>=120 then
            checkpoint.phase="checkpoint-ready"
            helpers.write_file("checkpoint-ready.json",helpers.table_to_json(checkpoint),false)
            checkpoint=nil
        end
        return
    end
    if storage.icon_sets_finished and not first_tick then return end
    local player=game.connected_players[1];if not player then return end
    storage.icon_sets_finished=false
    local ok,result=pcall(remote.call,"ei-icon-sets-qc","step",player.index,event.tick,first_tick)
    first_tick=false
    if not ok then
        local failure=helpers.table_to_json{complete=true,all_pass=false,error=result}
        helpers.write_file("terrain-admin-qc.json",failure,false)
        helpers.write_file("checkpoint-ready.json",failure,false)
        storage.icon_sets_finished=true;error(result)
    elseif result then
        game.set_wait_for_screenshots_to_finish()
        if result.phase=="checkpoint-requested" then
            -- This is deliberately nonterminal. The host waits for a fresh,
            -- readable _autosave-style-provider.zip and the save-finished log.
            helpers.write_file("icon-sets-checkpoint-requested.json",helpers.table_to_json(result),false)
            storage.icon_sets_finished=true
            checkpoint=result;checkpoint_tick=event.tick
            game.auto_save("style-provider")
        else
            helpers.write_file("terrain-admin-qc.json",helpers.table_to_json(result),false)
            storage.icon_sets_finished=true
        end
    end
end)
