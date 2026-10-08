-- Disposable native save fixture. Its control source stays identical across reloads.
local loaded_saved=false
script.on_init(function() storage.start=game.tick end)
script.on_load(function() loaded_saved=storage.persistence_saved==true end)
script.on_configuration_changed(function() storage.start=storage.start or game.tick end)
local function call(name,...) return remote.call("ei-terrain-persistence-qc",name,...) end
script.on_event(defines.events.on_tick,function(event)
    if storage.persistence_checked then return end
    if loaded_saved then
        local result=call("verify",event.tick)
        helpers.write_file("terrain-persistence-qc.json",helpers.table_to_json(result),false)
        storage.persistence_checked=true
        return
    end
    local t=event.tick-storage.start
    if t==100 then call("prepare",event.tick)
    elseif t==200 then call("scar",event.tick)
    elseif t==500 then
        local result=call("capture",event.tick)
        helpers.write_file("terrain-persistence-seed.json",helpers.table_to_json(result),false)
        storage.persistence_saved=true
        game.server_save("terrain-lifecycle-checkpoint")
    end
end)
