script.on_event(defines.events.on_tick,function(event)
    if storage.wildfire_done or event.tick<100 then return end
    local result=remote.call("ei-terrain-wildfire-qc","step",event.tick)
    if result then
        helpers.write_file("terrain-qc.json",helpers.table_to_json(result),false)
        storage.wildfire_done=true
    end
end)
