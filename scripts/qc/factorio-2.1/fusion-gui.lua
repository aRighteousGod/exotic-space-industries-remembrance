-- Actual connected-client widgets/callbacks and a saved, open console.
local loaded=false
local pending_capture
local reload_reopen_at
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true) end
end)
script.on_load(function() loaded=true end)
local function check(condition,label)
    storage.report.checks=storage.report.checks+1
    assert(condition,label)
end
local function gui(action,value,tick)
    return remote.call("esir-fusion-qc","gui",storage.player,action,value,tick)
end
local function entry()
    return remote.call("esir-fusion-qc","record",storage.reactor)
end
local function capture(name,tick)
    local player=game.get_player(storage.player)
    storage.report.display_resolution=player.display_resolution
    storage.report.display_scale=player.display_scale
    storage.report.console=gui("inspect",nil,tick)
    game.take_screenshot{player=storage.player,surface=storage.reactor.surface,position=storage.reactor.position,
        resolution=player.display_resolution,zoom=1,path=name,show_gui=true}
end

script.on_event(defines.events.on_tick,function(event)
    local player=game.connected_players[1]
    if not player then return end
    if pending_capture and pending_capture.close_tick and event.tick>=pending_capture.close_tick then
        pending_capture.close_tick=nil
        gui("close",nil,event.tick)
    end
    if pending_capture and pending_capture.reopen_tick and event.tick>=pending_capture.reopen_tick then
        pending_capture.reopen_tick=nil
        check(gui("open",storage.reactor,event.tick).valid,"Console reopens after native save dialog")
    end
    if pending_capture and event.tick>=pending_capture.tick then
        capture(pending_capture.image,event.tick)
        if not pending_capture.scrolled then
            pending_capture.scrolled=true
            gui("scroll-options",nil,event.tick)
            pending_capture.tick=event.tick+60
            pending_capture.image="fusion-console-options.png"
        else
            storage.report.native_scroll_to_options=true
            helpers.write_file(pending_capture.marker,helpers.table_to_json(storage.report),false)
            pending_capture=nil
        end
    end
    if not storage.ready then
        local surface=game.create_surface("fusion-gui-qc",{width=128,height=128,peaceful_mode=true})
        surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        player.teleport({0,8},surface)
        storage.player=player.index
        storage.reactor=surface.create_entity{name="ei-fusion-reactor",position={0,0},force="player",quality="rare",raise_built=true}
        storage.reactor.disabled_by_script=true
        storage.report={passed=false,engine=script.active_mods.base,checks=0}
        check(gui("open",storage.reactor,event.tick).valid,"Fusion relative console did not open")
        gui("click",{action="preset",preset="power"},event.tick)
        local state=entry()
        check(state.manual_selection.fuel_1=="ei-heated-tritium" and state.manual_selection.fuel_2=="ei-heated-helium-3","Power preset fuels")
        check(state.manual_selection.temperature=="high" and state.manual_selection.injection_rate=="high","Power preset modes")
        gui("slider",{name="temperature-slider",value=1},event.tick)
        gui("slider",{name="injection-rate-slider",value=2},event.tick)
        state=entry()
        check(state.manual_selection.temperature=="low" and state.manual_selection.injection_rate=="medium","Native sliders update owner")
        gui("click",{action="set-control-source",control_source="circuit"},event.tick)
        check(entry().control_source=="circuit","Native circuit button")
        check(entry().effective_selection.fuel_1=="ei-heated-tritium","Unwired circuit falls back to manual selection")
        local before=entry().wire_proxy.unit_number
        remote.call("esir-fusion-qc","configuration")
        check(entry().wire_proxy.unit_number==before and entry().control_source=="circuit","Configuration retains open-console state")
        check(gui("reconcile",nil,event.tick).valid,"Configuration console reconciliation")
        loaded=false
        storage.ready=true;storage.save_at=event.tick+30
    elseif storage.save_at and event.tick>=storage.save_at then
        storage.save_at=nil;storage.accepted=true
        storage.report.passed=true
        game.auto_save("fusion-client")
        pending_capture={tick=event.tick+120,close_tick=event.tick+30,reopen_tick=event.tick+60,
            image="fusion-console.png",marker="fusion-client.json"}
    elseif loaded and storage.accepted then
        loaded=false
        check(entry().control_source=="circuit","Reload retained circuit mode")
        check(entry().manual_selection.fuel_1=="ei-heated-tritium" and entry().manual_selection.fuel_2=="ei-heated-helium-3","Reload retained manual fuels")
        check(entry().manual_selection.temperature=="low" and entry().manual_selection.injection_rate=="medium","Reload retained manual modes")
        check(gui("reconcile",nil,event.tick).valid,"Saved native console resumes ownership")
        check(gui("close",nil,event.tick).valid==false,"Native close tears down console")
        reload_reopen_at=event.tick+30
    elseif reload_reopen_at and event.tick>=reload_reopen_at then
        reload_reopen_at=nil
        check(gui("open",storage.reactor,event.tick).valid,"Reopen after reload")
        local mode=gui("inspect",nil,event.tick).gui_mode
        check(mode==(player.display_resolution.width/player.display_scale<1600 and "screen" or "relative"),"Console uses fitting GUI surface")
        if mode=="screen" then
            gui("click",{action="close"},event.tick)
            check(not gui("inspect",nil,event.tick).valid and player.opened==storage.reactor,"Fallback close preserves opened native reactor")
            check(gui("open",storage.reactor,event.tick).valid,"Fallback reopens after explicit close")
        end
        gui("click",{action="set-control-source",control_source="manual"},event.tick)
        check(entry().control_source=="manual","Manual control restored")
        gui("click",{action="preset",preset="power"},event.tick)
        check(entry().manual_selection.temperature=="high" and entry().manual_selection.fuel_1=="ei-heated-tritium","Power option through dispatcher")
        gui("click",{action="preset",preset="balanced"},event.tick)
        check(entry().manual_selection.temperature=="medium" and entry().manual_selection.injection_rate=="medium","Balanced option through dispatcher")
        gui("click",{action="preset",preset="flux"},event.tick)
        check(entry().manual_selection.fuel_1=="ei-heated-deuterium" and entry().manual_selection.temperature=="low","Flux preset")
        gui("click",{action="reset-defaults"},event.tick)
        check(entry().manual_selection.temperature=="medium" and entry().manual_selection.injection_rate=="medium","Reset defaults")
        local recipe=storage.reactor.get_recipe().name
        gui("click",{action="refresh-collectors"},event.tick)
        check(storage.reactor.get_recipe().name==recipe and gui("inspect",nil,event.tick).valid,"Refresh collectors option preserves reactor and console")
        storage.report.passed=true;storage.report.reload=true
        game.auto_save("fusion-client-reload")
        pending_capture={tick=event.tick+120,close_tick=event.tick+30,reopen_tick=event.tick+60,
            image="fusion-console-reload.png",marker="fusion-client-reload.json"}
    end
end)
