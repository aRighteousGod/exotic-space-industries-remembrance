local test=require("test-config")
local dependencies=require("__exotic-space-industries-remembrance__/lib/combat-doctrines-dependencies")
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    storage.report={phase=test.phase,pyric=test["pyric-radiance-enabled"],ballistic=test["ballistic-divergence-enabled"],
        counterparts_present=script.active_mods[dependencies.pyric_radiance]~=nil
            and script.active_mods[dependencies.ballistic_divergence]~=nil}
end)
script.on_event(defines.events.on_singleplayer_init,function()
    storage.report.singleplayer_init=true
end)
script.on_event(defines.events.on_tick,function(event)
    if event.tick~=60 then return end
    local player=game.get_player(1)
    storage.report.connected_player=player and player.valid and player.connected or false
    storage.report.all_pass=storage.report.counterparts_present and storage.report.singleplayer_init and storage.report.connected_player
    helpers.write_file("combat-doctrines-overlap.json",helpers.table_to_json(storage.report),false)
    assert(storage.report.all_pass,"Coexistence fixture must enter through native singleplayer init")
    game.take_screenshot{player=player,show_gui=true,resolution={1440,1080},path="combat-doctrines/"..test.phase.."-warning.png"}
end)
