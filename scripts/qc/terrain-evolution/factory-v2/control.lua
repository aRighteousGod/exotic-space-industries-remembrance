local profile=require("profile")
script.on_event(defines.events.on_tick,function(event)
    if storage.saved then return end
    if not storage.prepared then
        storage.result=remote.call("ei-ecology-factory-qc","prepare",profile.enabled,event.tick)
        storage.prepared=event.tick
    elseif event.tick>=storage.prepared+120 then
        storage.saved=true
        helpers.write_file("terrain-persistence-seed.json",helpers.table_to_json(storage.result),false)
        game.server_save("terrain-lifecycle-checkpoint")
    end
end)
