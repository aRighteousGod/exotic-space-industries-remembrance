if script.active_mods["exotic-space-industries-remembrance"] then
    script.on_event(defines.events.on_tick,function(event)
        storage.start=storage.start or event.tick
        if event.tick==storage.start then remote.call("esir-rebuild-qc","start",event.tick) end
        if event.tick==storage.start+6000 then remote.call("esir-rebuild-qc","finish",event.tick) end
    end)
    return
end
local scheduler=require("lib/runtime-scheduler")
local monitor=require("scripts/control/rebuild-monitor")
local core=require("core")
local virtual=require("virtual")
local persistence=require("reload")
local loaded=false
script.on_load(function() loaded=true end)
local function report(state,done)
    helpers.write_file("rebuild-qc.json",helpers.table_to_json{all_pass=done,checks=state.checks,version=script.active_mods.base,
        native_players=1,multiplayer_native=false,resolution=state.resolution,scale=state.scale,tick=game.tick,profiling=state.profiling},false)
end
local function check(state,name,ok)
    state.checks[#state.checks+1]={name=name,ok=not not ok}
    if not ok then report(state,false);error("Rebuild QC: "..name) end
end
local function action(root,name)
    for _,element in ipairs(root.children) do
        if element.tags.action==name then return element end
        local found=action(element,name);if found then return found end
    end
end
local function service(tick) if monitor.has_tick_work(tick) then monitor.updater{tick=tick} end end
local monitor_options={admin_viewer=function(index)return storage.test and storage.test.admin and index==storage.test.player or false end,
    admin_refresh=function(index,tick,snapshot) storage.test.admin_snapshot=snapshot;return true end}
monitor.configure(monitor_options)
script.on_event(defines.events.on_tick,function(event)
    local tick=event.tick;local state=storage.test
    if not state then
        local player=game.connected_players[1];if not player then return end
        if player.controller_type==defines.controllers.editor then player.toggle_map_editor() end
        state={player=player.index,start=tick+5,checks=core.run(scheduler,tick),resolution=player.display_resolution,scale=player.display_scale}
        for _,entry in ipairs(virtual.run(scheduler,monitor)) do state.checks[#state.checks+1]=entry end
        monitor.configure(monitor_options)
        storage.test=state;player.admin=false
        local top=#player.gui.top.children
        monitor.watch_player(player.index,tick);service(tick)
        check(state,"idle wake does not create mod_gui containers",#player.gui.top.children==top)
        check(state,"idle wake drains",not monitor.has_tick_work(tick+1))
        return
    end
    if state.done or tick<state.start then return end
    local player=game.get_player(state.player);assert(player and player.connected)
    if state.awaiting_reload then
        if not loaded then return end
        loaded=false
        local current=scheduler.peek_rebuilds(tick)
        local entry=storage.ei.rebuild_monitor.players[player.index]
        check(state,"reload retains generation and progress "..state.awaiting_reload,current.active[1].id==state.id and current.active[1].completed==40)
        check(state,"reload retains episode "..state.awaiting_reload,current.episode==state.saved_episode)
        if state.awaiting_reload=="open" then
            check(state,"reload retains native dragged frame",entry.root and entry.root.valid and entry.root.location.x==state.saved_x and entry.root.location.y==state.saved_y)
        else
            check(state,"reload retains dismissal",not entry.root and entry.dismissed==current.episode)
        end
        state.start=tick-state.save_checkpoint-1;state.awaiting_reload=nil
    end
    local n=tick-state.start
    if n==0 then
        state.chest=player.surface.create_entity{name="iron-chest",position=player.surface.find_non_colliding_position("iron-chest",player.position,24,1) or player.position,force=player.force}
        check(state,"native chest fixture",state.chest and state.chest.valid);player.opened=state.chest
        player.cursor_stack.set_stack{name="copper-plate",count=7}
        state.id=scheduler.begin_rebuild("beacon-overload","fixture","global",{phase="machines",completed=0,total=100,unit="entities",reason="fixture"},tick)
        state.extra={}
        for _,owner in ipairs({"teslas-legacy","water-turret","sweeping-radar","spider-vehicles"}) do
            state.extra[#state.extra+1]=scheduler.begin_rebuild(owner,"fixture","global",{phase="discovering",completed=0,total=false,unit="entities",reason="fixture"},tick)
        end
    elseif n==60 or n==120 then scheduler.update_rebuild(state.id,{completed=n/3},tick)
    elseif n==180 then
        scheduler.finish_rebuild(state.id,"completed",tick)
        for _,id in ipairs(state.extra) do scheduler.finish_rebuild(id,"completed",tick) end
    elseif n==181 then state.id=scheduler.begin_rebuild("beacon-overload","fixture","global",{phase="machines",completed=40,total=100,unit="entities",reason="fixture"},tick)
    elseif n==302 then scheduler.update_rebuild(state.id,{total=false},tick)
    elseif n==362 then scheduler.update_rebuild(state.id,{state="waiting",waiting_reason="external"},tick)
    elseif n==363 then scheduler.update_rebuild(state.id,{completed=77},tick)
    elseif n==422 then state.admin=true;monitor.watch_player(player.index,tick)
    elseif n==423 then scheduler.finish_rebuild(state.id,"completed",tick)
    elseif n==484 then state.admin=false;monitor.watch_player(player.index,tick) end
    service(tick)
    local entry=storage.ei.rebuild_monitor.players[player.index]
    if n==0 then
        check(state,"nonadmin activity launcher",not player.admin and entry.button and entry.button.valid)
        check(state,"two-second grace",not entry.root)
    elseif n==119 then check(state,"no premature popup",not entry.root)
    elseif n==125 and persistence then
        entry.root.location={x=37,y=85}
        state.saved_x=entry.root.location.x;state.saved_y=entry.root.location.y
        state.saved_episode=scheduler.peek_rebuilds(tick).episode;state.save_checkpoint=n;state.awaiting_reload="open"
        game.auto_save("rebuild-monitor-open")
    elseif n==121 then
        game.take_screenshot{player=player,path="rebuild-monitor/active.png",show_gui=true,show_entity_info=false,resolution=player.display_resolution}
    elseif n==130 then
        check(state,"automatic popup",entry.root and entry.root.valid)
        check(state,"nonmodal automatic popup",player.opened==state.chest)
        check(state,"automatic popup preserves held cursor",player.cursor_stack.valid_for_read and player.cursor_stack.name=="copper-plate" and player.cursor_stack.count==7)
        monitor.on_gui_click{element=entry.root,player_index=player.index,tick=tick}
        check(state,"window background click does not dismiss",entry.root and entry.root.valid)
        check(state,"determinate progress",entry.rows[state.id].progress.visible and math.abs(entry.rows[state.id].progress.value-0.4)<0.001)
        entry.root.location={x=9999,y=9999};monitor.on_display_changed{player_index=player.index,tick=tick}
        check(state,"native frame clipped to viewport",entry.root.location.x+entry.root.style.minimal_width*player.display_scale<=player.display_resolution.width+1 and entry.root.location.y>=0)
        entry.root.location={x=29,y=90};monitor.on_display_changed{player_index=player.index,tick=tick};state.location=entry.root.location
        monitor.on_gui_click{element=action(entry.root,"close"),player_index=player.index,tick=tick}
        check(state,"close retains launcher",not entry.root and entry.button.valid)
    elseif n==131 then
        monitor.on_gui_click{element=entry.button,player_index=player.index,tick=tick}
        check(state,"reopen preserves position",entry.root.location.x==state.location.x and entry.root.location.y==state.location.y)
        check(state,"reopen preserves opened entity",player.opened==state.chest)
        monitor.on_gui_click{element=action(entry.root,"close"),player_index=player.index,tick=tick}
    elseif n==132 and persistence then
        state.saved_episode=scheduler.peek_rebuilds(tick).episode;state.save_checkpoint=n;state.awaiting_reload="closed"
        game.auto_save("rebuild-monitor-closed")
    elseif n==179 then check(state,"dismissal retained",not entry.root)
    elseif n==180 then
        check(state,"completion removes public UI",not entry.root and not entry.button)
        check(state,"completion idle",not monitor.has_tick_work(tick+1))
    elseif n==181 then check(state,"same-owner new launcher tooltip",entry.button and entry.button.tooltip~=nil and entry.button.tooltip~="")
    elseif n==311 then check(state,"next episode auto-opens",entry.root and entry.root.valid)
    elseif n==361 then check(state,"unknown total hides percentage",entry.root and not entry.rows[state.id].progress.visible)
    elseif n==362 then
        check(state,"waiting hides public UI",not entry.root and not entry.button)
        check(state,"waiting without viewer is idle",not monitor.has_tick_work(tick+1))
    elseif n==422 then
        check(state,"new admin snapshot fresh",state.admin_snapshot and state.admin_snapshot.snapshot_tick==tick and state.admin_snapshot.active[1].completed==77)
        check(state,"admin wait does not show public UI",not entry.root and not entry.button)
    elseif n==483 then
        check(state,"admin terminal history refresh",state.admin_snapshot and #state.admin_snapshot.active==0 and state.admin_snapshot.history[1].outcome=="completed")
    elseif n==545 then
        check(state,"closed admin idle",not monitor.has_tick_work(tick))
        local id=scheduler.begin_rebuild("admin-tools","failed","global",{synchronous=true,total=1},tick)
        scheduler.finish_rebuild(id,"failed",tick)
        check(state,"synchronous failure visible",serpent.line(monitor.activity_caption(scheduler.peek_rebuilds(tick),true)):find("outcome%-failed")~=nil)
        local many={active={},history={},snapshot_tick=tick}
        for i=1,300 do many.active[i]={id=i,owner="beacon-overload",phase="machines",state="running",completed=i,total=1000,unit="entities",reason="fixture",start_tick=tick-120} end
        local label=player.gui.screen.add{type="label",caption=monitor.activity_caption(many,true)}
        check(state,"native large localized caption",label.valid);label.destroy()
        -- Explicit QC profiling only; these values never feed persistent ETA.
        local function measure(count,callback)
            local profiler=game.create_profiler()
            for i=1,count do callback(i) end
            profiler.stop();helpers.write_file("rebuild-profiling.txt",{"",profiler,"\n"},true);return "See rebuild-profiling.txt (native formatted timer)."
        end
        service(tick)
        check(state,"profiled idle state has no work",not monitor.has_tick_work(tick))
        state.profiling={iterations=100000,empty_callback=measure(100000,function()end),
            idle_predicate=measure(100000,function()monitor.has_tick_work(tick)end)}
        local ids={};for i=1,10 do ids[i]=scheduler.begin_rebuild("perf","fixture",i,{phase="items",total=100000},tick) end
        state.profiling.scalar_updates_100000=measure(100000,function(i)scheduler.update_rebuild(ids[i%10+1],{completed=i},tick+i)end)
        state.profiling.ten_job_snapshots_10000=measure(10000,function()scheduler.peek_rebuilds(tick+100000)end)
        for _,id in ipairs(ids) do scheduler.finish_rebuild(id,"completed",tick) end
        player.opened=nil;state.chest.destroy();state.done=true;report(state,true)
    end
end)
