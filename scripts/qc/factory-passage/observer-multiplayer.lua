-- Private fixture for two actual connected clients; native GUI actions are scripted.
local passage=require("scripts/control/factory-passage")
local function check(value,name)
    storage.checks[#storage.checks+1]={name=name,passed=not not value}
    assert(value,"Passage multiplayer QC: "..name)
end
local function report(name)
    local result={passed=true,engine=script.active_mods.base,tick=game.tick,checks=storage.checks,
        status=passage.status(),connected=#game.connected_players,events=storage.events}
    local text=helpers.table_to_json(result)
    helpers.write_file("factory-passage/"..name..".json",text,false,0)
    for _,player in pairs(game.connected_players) do helpers.write_file("factory-passage/"..name..".json",text,false,player.index) end
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    settings.global["ei-factory-passage-update-budget"]={value=256}
    storage.checks={};storage.events={};storage.phase=0
    local s=game.create_surface("observer-multiplayer",{width=128,height=128,water="none"})
    s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
    for _,entity in pairs(s.find_entities()) do entity.destroy() end
    storage.machine=assert(s.create_entity{name="ei-passage-qc-crafter",position={.5,.5},force="player",snap_to_grid=false})
    storage.machine.set_recipe("ei-passage-qc-fluid-recipe")
    assert(s.create_entity{name="pipe",position={-.5,-1.5},force="player",snap_to_grid=false})
    passage.rebuild_runtime_state("multiplayer-fixture",game.tick)
end)
script.on_event(defines.events.on_gui_opened,function(e)
    storage.events[#storage.events+1]={kind="open",player=e.player_index,tick=e.tick,gui_type=e.gui_type}
    passage.on_gui_opened(e)
end)
script.on_event(defines.events.on_gui_closed,function(e)
    storage.events[#storage.events+1]={kind="close",player=e.player_index,tick=e.tick,gui_type=e.gui_type}
    passage.on_gui_closed(e)
end)
script.on_event({defines.events.on_pre_player_left_game,defines.events.on_player_left_game,defines.events.on_player_died},passage.on_player_left)
script.on_event(defines.events.on_player_joined_game,function(e)
    local p=game.get_player(e.player_index);p.teleport({3,3},storage.machine.surface)
    passage.on_gui_opened(e)
end)
script.on_event(defines.events.on_multiplayer_init,passage.reconcile_gui_sessions)
script.on_event(defines.events.on_object_destroyed,passage.on_object_destroyed)
script.on_event(defines.events.on_tick,function(e)
    if passage.has_work(e.tick) then passage.updater(passage.update_budget(),e) end
    local s=passage.status();local phase=storage.phase
    if phase==0 and #game.connected_players==2 then
        storage.players={game.connected_players[1].index,game.connected_players[2].index}
        check(s.watchers==0 and s.helpers==1,"settled manual coupling has no observer")
        for _,index in ipairs(storage.players) do game.get_player(index).opened=storage.machine end
        storage.phase=1;storage.due=e.tick+8
    elseif phase==1 and e.tick>=storage.due then
        check(s.watchers==1 and s.gui_watchers==1 and s.gui_sessions==2,"two native clients share one watcher and two sessions")
        storage.machine.set_recipe(nil);storage.phase=2;storage.due=e.tick+8
    elseif phase==2 and e.tick>=storage.due then
        check(s.helpers==0 and s.watchers==1,"open native GUIs observe cleared recipe on every peer")
        game.get_player(storage.players[1]).opened=nil;storage.phase=3;storage.due=e.tick+8
    elseif phase==3 and e.tick>=storage.due then
        check(s.watchers==1 and s.gui_sessions==1,"closing first viewer preserves second")
        game.get_player(storage.players[1]).opened=storage.machine
        storage.machine.set_recipe("ei-passage-qc-fluid-recipe")
        storage.phase=4;storage.due=e.tick+8
    elseif phase==4 and e.tick>=storage.due then
        check(s.watchers==1 and s.gui_sessions==2 and s.helpers==1,"reopened viewers restore joint")
        storage.phase=5;report("observer-multiplayer-both")
    elseif phase==5 and #game.connected_players==1 then
        storage.phase=6;storage.due=e.tick+8
    elseif phase==6 and e.tick>=storage.due then
        check(s.watchers==1 and s.gui_sessions==1,"disconnect cleans only departed client session")
        game.connected_players[1].opened=nil;storage.phase=7;storage.due=e.tick+8
    elseif phase==7 and e.tick>=storage.due then
        check(s.watchers==0 and s.gui_sessions==0 and s.helpers==1,"last close retires watcher without changing joint")
        storage.phase=8;report("observer-multiplayer-left")
    end
end)
