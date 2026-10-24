-- Isolated portal scenes and evidence. Production ESIR owns feature simulation.
-- Cadence: task-owned on_tick; helper-local storage.portal. Never ships in the mod.
local cfg=require("capture-config")
if cfg.scene~="smoke" then require("capture");return end
script.on_init(function() storage.portal={pending=true} end)
script.on_configuration_changed(function() storage.portal={pending=true} end)
script.on_event(defines.events.on_tick,function(event)
    local state=storage.portal
    if not state then state={pending=true};storage.portal=state end
    if state.done then return end
    local player=game.connected_players[1]
    if not player then return end
    if state.pending then
        state.pending=nil;state.started=event.tick
        player.set_controller{type=defines.controllers.god};game.tick_paused=false
    end
    if event.tick-state.started==60 then
        game.take_screenshot{player=player,path="portal/smoke.jpg",resolution={1280,720},show_gui=false,force_render=true}
        helpers.write_file("portal/report.json",helpers.table_to_json({complete=true,connected=player.connected,
            resolution=player.display_resolution,scale=player.display_scale,tick=event.tick}),false)
        state.done=true;log("PORTAL_CAPTURE_COMPLETE")
    end
end)
