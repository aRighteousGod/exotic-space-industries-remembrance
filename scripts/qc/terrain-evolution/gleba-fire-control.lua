script.on_init(function() storage.gleba_fire_start=game.tick end)
script.on_configuration_changed(function() storage.gleba_fire_start=game.tick;storage.gleba_fire_done=nil end)
script.on_event(defines.events.on_tick,function(event)
    if storage.gleba_fire_done or event.tick-(storage.gleba_fire_start or 0)<100 then return end
    local result=remote.call("ei-terrain-gleba-fire-qc","run")
    helpers.write_file("terrain-qc.json",helpers.table_to_json(result),false)
    storage.gleba_fire_done=true
end)
