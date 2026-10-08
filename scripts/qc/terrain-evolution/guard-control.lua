-- Standalone disposable helper controller. Do not combine with another destructive fixture.
script.on_init(function() storage.guard_start=game.tick end)
script.on_configuration_changed(function() storage.guard_start=game.tick;storage.guard_done=nil end)
script.on_event(defines.events.on_tick,function(event)
    if storage.guard_done or event.tick-(storage.guard_start or 0)<100 then return end
    if storage.guard_pending and event.tick<storage.guard_pending+2 then return end
    if storage.guard_pending then
        local result=remote.call("ei-terrain-guard-qc","finish")
        helpers.write_file("terrain-qc.json",helpers.table_to_json(result),false)
        if result.pending then storage.guard_pending=event.tick else storage.guard_done=true end
        return
    end
    local result=remote.call("ei-terrain-guard-qc","run")
    helpers.write_file("terrain-qc.json",helpers.table_to_json(result),false)
    if result.pending then storage.guard_pending=event.tick else storage.guard_done=true end
end)
