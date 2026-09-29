local config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local current_tick
local function call(name,...) return remote.call("esir_radar_qc",name,current_tick,...) end
script.on_init(function() storage.pending=true end)
script.on_event(defines.events.on_tick,function(event)
    current_tick=event.tick
    if storage.pending then
        storage.pending=nil;storage.started=event.tick
        local player=assert(game.connected_players[1],"GUI review requires connected player")
        storage.player=player
        player.set_controller{type=defines.controllers.god}
        local surface=game.create_surface("radar-visual",{autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
        surface.daytime=0;surface.freeze_daytime=true
        player.teleport({16,22},surface)
        player.force.research_all_technologies()
        storage.radar=surface.create_entity{name="ei-phased-array-radar",quality="legendary",position={16,16},force=player.force,raise_built=true}
        surface.create_entity{name="substation",position={20,16},force=player.force}
        surface.create_entity{name="ei-radar-qc-source",position={20,20},force=player.force}
        storage.tests={}
        return
    end
    local t=event.tick-storage.started
    local player=storage.player
    if t>=30 and t<=350 and (t-30)%80==0 then
        local mode=1+math.floor((t-30)/80)
        local settings=config.defaults();settings.mode=mode
        for _,m in pairs(settings.modes) do m.radius=4;m.near=mode==3 and 2 or 0 end
        if mode==2 then settings.overrides.radius={enabled=true,signal={type="virtual",name="signal-R"}} end
        call("settings",storage.radar,settings)
        player.opened=storage.radar
        -- Radars have no native GUI outside editor mode. Exercise the linked
        -- open-gui input handler used by a normal in-game click.
        call("input",player.index,storage.radar)
    elseif t>=60 and t<=380 and (t-60)%80==0 then
        local mode=1+math.floor((t-60)/80)
        assert(player.gui.screen.ei_sweeping_radar_gui,"linked entity open failed")
        game.take_screenshot{player=player,path="radar-gui/mode-"..mode..".png",show_gui=true,
            position={16,16},resolution=player.display_resolution,zoom=0.3}
        game.take_screenshot{player=player,path="radar-gui/coverage-"..mode..".png",show_gui=false,
            position={16,16},resolution={1280,720},zoom=0.065}
        storage.tests[#storage.tests+1]={name="linked-open-mode-"..mode,pass=true}
        if mode==4 then call("trigger",storage.radar) end
    elseif t==410 then
        call("close",player.index)
        player.set_controller{type=defines.controllers.remote,position={16,16},surface=storage.radar.surface}
        player.zoom_limits={furthest_game_view={zoom=4}}
        player.zoom=0.2
        call("open",player.index,storage.radar)
    elseif t==430 then
        game.take_screenshot{player=player,path="radar-gui/map.png",show_gui=true,resolution=player.display_resolution,zoom=0.2}
    elseif t==450 then
        helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=true,tests=storage.tests,connected=player.connected,
            resolution=player.display_resolution,scale=player.display_scale}),false)
    end
end)
