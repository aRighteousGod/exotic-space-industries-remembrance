-- Logic-only multiple-viewer coverage; this does not represent native multiplayer.
local model={}
local function element(parent,definition)
    local root={valid=true,children={},style={},tags={},location={x=0,y=0}}
    for key,value in pairs(definition or {}) do if key~="style" then root[key]=value end end
    root.add=function(spec)
        local child=element(root,spec);root.children[#root.children+1]=child
        if child.name then root[child.name]=child end
        return child
    end
    root.destroy=function()
        root.valid=false
        if parent then
            if root.name then parent[root.name]=nil end
            for i,child in ipairs(parent.children) do if child==root then table.remove(parent.children,i);break end end
        end
    end
    return root
end
function model.run(scheduler,monitor)
    local saved_game,saved_ei=game,storage.ei
    local checks={}
    local function check(name,ok) checks[#checks+1]={name=name,ok=not not ok};assert(ok,name) end
    local ok,err=pcall(function()
        local players={}
        for i=1,16 do players[i]={index=i,valid=true,connected=i<=8,display_scale=1,display_resolution={width=1280,height=720},
            gui={top=element(),screen=element()},opened="machine"} end
        game={connected_players={},get_player=function(index)return players[index]end}
        storage.ei={};monitor.configure{}
        for i=1,8 do game.connected_players[i]=players[i] end
        local id=scheduler.begin_rebuild("beacon-overload","fixture","all",{phase="machines",completed=0,total=100},0)
        for tick=0,121 do
            if tick==90 then for i=9,16 do players[i].connected=true;game.connected_players[i]=players[i];monitor.watch_player(i,tick) end end
            if monitor.has_tick_work(tick) then monitor.updater{tick=tick} end
            if tick==120 then
                local count=0;for _,entry in pairs(storage.ei.rebuild_monitor.players) do if entry.root then count=count+1 end end
                check("virtual eight-viewer popup budget",count==8)
            end
        end
        local root=storage.ei.rebuild_monitor
        for i=1,16 do check("virtual viewer auto-open "..i,root.players[i].root and players[i].opened=="machine") end
        monitor.on_gui_click{element=root.players[1].button,player_index=1,tick=122}
        check("virtual independent dismissal",not root.players[1].root and root.players[2].root~=nil)
        local joined=scheduler.begin_rebuild("water-turret","fixture","all",{total=20},123)
        for tick=123,185 do if monitor.has_tick_work(tick) then monitor.updater{tick=tick} end end
        check("virtual added job respects dismissal",not root.players[1].root and root.players[2].root~=nil)
        scheduler.finish_rebuild(id,"completed",186);scheduler.finish_rebuild(joined,"completed",186)
        for tick=186,250 do if monitor.has_tick_work(tick) then monitor.updater{tick=tick} end end
        check("virtual completion while dismissed reaches idle",not monitor.has_tick_work(251) and not root.players[1].button and not root.players[2].root)
    end)
    game=saved_game;storage.ei=saved_ei
    if not ok then error(err) end
    return checks
end
return model
