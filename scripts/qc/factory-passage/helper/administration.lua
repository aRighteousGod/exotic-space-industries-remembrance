local module={}
local checkpoint_loaded=false
function module.on_load() checkpoint_loaded=storage.admin_finished==true end
function module.tick(event,check,receipt,loaded)
    if checkpoint_loaded then
        if not storage.admin_reload_checked then
            local result=remote.call("ei_factory_passage_qc","reload")
            for _,row in ipairs(result.checks) do check(row.passed,row.name) end
            storage.admin_reload_checked=true;receipt("administration-reload")
        end
        return
    end
    if storage.admin_finished then return end
    local player=game.connected_players[1]
    if not player then return end
    local result=remote.call("ei_factory_passage_qc","tick",player.index,storage.surface)
    if result and result.finished then
        for _,row in ipairs(result.checks) do check(row.passed,row.name) end
        storage.admin_finished=true
        game.set_wait_for_screenshots_to_finish()
        receipt("administration",{frames=result.frames})
        game.auto_save("factory-passage-administration")
    end
end
return module
