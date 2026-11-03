-- Appended only to the private ESIR QC copy. Runs setting writes in their owner.
-- Keep the historical map-settings.png artifact key; its current scene is Options.
local passage=require("scripts/control/factory-passage")
local admin=require("scripts/control/admin-tools")
local gui=require("scripts/control/admin/gui")
local options=require("scripts/control/runtime-options")
local scheduler=require("lib/runtime-scheduler")
local key="ei-factory-passage-update-budget"
local scanner="ei-factory-passage-circuit-scanner-enabled"
local scan_budget="ei-factory-passage-circuit-scan-budget"
local budgets={1,2,7,8,31,32,63,64,65,256,1024}
local function root() return storage.ei.passage_qc end
local function check(value,name)
    local q=root();q.checks[#q.checks+1]={name=name,passed=not not value};assert(value,"Passage administration QC: "..name)
end
local function set(value) settings.global[key]={value=value} end
local function click(player,element)
    admin.on_gui_click{player_index=player.index,element=element,tick=game.tick}
end
local function edit(player,value)
    local session=storage.ei.admin_tools.sessions[player.index]
    local row=session.options.rows[key];row.value.text=tostring(value)
    admin.on_gui_change{player_index=player.index,element=row.value,tick=game.tick}
end
local function reload_editor(player)
    local session=storage.ei.admin_tools.sessions[player.index]
    click(player,session.options.reload)
end
local function capture(player,name)
    local q=root();local path="factory-passage/admin/"..name..".png"
    local session=storage.ei.admin_tools.sessions[player.index]
    if name=="active-rebuild" then session.root.visible=false
    else
        admin.open(player,name=="map-settings" and "options" or "diagnostics",game.tick)
        session=storage.ei.admin_tools.sessions[player.index]
        session.root.location={x=110,y=12};session.root.bring_to_front()
        if name=="map-settings" then
            check(session.options.rows[key].value.text==tostring(settings.global[key].value),"rendered Options editor shows authoritative budget")
            local pane=session.options.body.parent
            while pane and pane.type~="scroll-pane" do pane=pane.parent end
            assert(pane,"Options has no scroll pane")
            pane.scroll_to_element(session.options.rows[key].value)
            -- Newly built native GUI geometry is calculated after this callback.
            q.map_capture_due=game.tick+2
            return
        else
            session.module_id="factory-passage";gui.refresh(player.index,game.tick)
            session.diagnostics.detail.scroll_to_element(session.diagnostics.rebuild_detail,"top-third")
        end
    end
    game.take_screenshot{player=player,resolution={1280,720},path=path,show_gui=true,force_render=true}
    q.frames[#q.frames+1]={path=path,tick=game.tick,scene=name}
end
local function setup(player,surface)
    storage.ei.passage_qc={started=game.tick,checks={},frames={},pipes={}}
    local q=root();player.admin=true;player.teleport({20,74},surface)
    for i=1,800 do
        q.pipes[i]=assert(surface.create_entity{name="pipe",position={(i-1)%40,80+math.floor((i-1)/40)},force=player.force,raise_built=true,snap_to_grid=false})
    end
    q.pipes[1].insert_fluid{name="water",amount=100,temperature=80}
    q.a=assert(surface.create_entity{name="pipe",position={60,80},force=player.force,raise_built=true,snap_to_grid=false})
    q.actor=assert(surface.create_entity{name="character",position={60.5,80},force=player.force,snap_to_grid=false})
    q.actor.walking_state={walking=false,direction=defines.direction.north}
    q.b=assert(surface.create_entity{name="pipe",position={61,80},force=player.force,raise_built=true,snap_to_grid=false})
    q.crafter=assert(surface.create_entity{name="ei-passage-qc-crafter",position={80.5,80.5},force=player.force,raise_built=true,snap_to_grid=false})
    q.crafter.set_recipe("ei-passage-qc-fluid-recipe")
    q.crafter.get_or_create_control_behavior().circuit_set_recipe=true
    q.port=assert(surface.create_entity{name="pipe",position={79.5,78.5},force=player.force,raise_built=true,snap_to_grid=false})
    set(256)
end
local function gui_checks(player)
    local q=root();local before=passage.status()
    check(q.a.position.x==60 and q.a.position.y==80 and q.b.position.x==61,"fixture pipe positions remain exact")
    local linked=false
    for _,connection in pairs(q.a.get_fluid_box_pipe_connections(1)) do if connection.target==q.b then linked=true end end
    check(linked,"occupied fixture has a native pipe joint")
    local coupling=false
    for _,connection in pairs(q.port.get_fluid_box_pipe_connections(1)) do if connection.target==q.crafter then coupling=true end end
    check(coupling,"recipe watcher has a native machine coupling")
    check(before.pending>0 and before.blocked>0,"fixture begins with a character-occupied joint")
    local prototype=prototypes.mod_setting[key]
    check(prototype.setting_type=="runtime-global" and prototype.default_value==256
        and prototype.minimum_value==1 and prototype.maximum_value==1024,"native setting type/default/bounds")
    check(prototypes.mod_setting[scanner].default_value==false,"native scanner defaults Off")
    local scan=prototypes.mod_setting[scan_budget]
    check(scan.setting_type=="runtime-global" and scan.default_value==1 and scan.minimum_value==1 and scan.maximum_value==1024,"native additional scanner budget defaults and bounds")
    local state_before=serpent.line(storage.ei.factory_passage)
    for _=1,3 do admin.registry.peek("factory-passage",game.tick) end
    check(state_before==serpent.line(storage.ei.factory_passage),"diagnostic summary is pure")
    local saved=storage.ei.factory_passage;storage.ei.factory_passage=nil
    local absent=admin.registry.peek("factory-passage",game.tick)
    check(absent.state=="not-initialized" and storage.ei.factory_passage==nil,"summary does not initialize absent state")
    storage.ei.factory_passage=saved
    local owners=0;for _,owner in ipairs(admin.registry.list()) do if owner.id=="factory-passage" then owners=owners+1;check(owner.repair=="rebuild_runtime_state","repair registered") end end
    check(owners==1,"one administration owner")
    admin.open(player,"options",game.tick)
    local session=storage.ei.admin_tools.sessions[player.index]
    check(session.options.rows[key]~=nil,"Options contains native budget setting")
    check(session.options.rows[scanner]~=nil and session.options.rows[scan_budget]~=nil,"Options contains both scanner controls")
    session.options.rows[scanner].value.state=false
    admin.on_gui_change{player_index=player.index,element=session.options.rows[scanner].value,tick=game.tick}
    click(player,session.options.apply)
    check(settings.global[scanner].value==false and options.snapshot().values[scanner]==false,"native false checkbox survives apply and snapshot")
    settings.global[scanner]={value=true};gui.refresh(player.index,game.tick)
    check(session.options.rows[scanner].value.state==true,"untouched checkbox follows native edit")
    local baseline=options.snapshot().values
    check(options.apply(baseline,{[scan_budget]=1024},game.tick),"native separate circuit budget apply")
    settings.global[scan_budget]={value=1}
    edit(player,1024);click(player,session.options.apply)
    check(settings.global[key].value==1024 and passage.status().update_budget==1024,"administration writes authoritative native value")
    for _,value in ipairs{"0","1025","1.5","bad"} do
        edit(player,value);click(player,session.options.apply)
        check(settings.global[key].value==1024,"invalid editor value rejected: "..value)
        reload_editor(player)
    end
    set(256);gui.refresh(player.index,game.tick)
    check(session.options.rows[key].value.text=="256","untouched editor follows native setting change")
    edit(player,1024);set(512);click(player,session.options.apply)
    check(settings.global[key].value==512 and session.options_draft.changes[key]==1024,"stale native-setting draft conflicts without loss")
    reload_editor(player)
    player.admin=false
    check(not admin.registry.repair(player.index,"factory-passage",game.tick),"non-admin repair denied")
    local snapshot=options.snapshot()
    check(not admin.execute(player,"options_apply",{baseline=snapshot.values,changes={[key]=1}},game.tick),"non-admin setting edit denied")
    player.admin=true
    set(256)
    check(passage.status().helpers==before.helpers and passage.status().counters.created==before.counters.created,"setting edits cause no helper churn")
    local inspected,notice=admin.registry.start_inspection(player.index,"factory-passage",game.tick)
    check(inspected,"inspection starts")
    check(type(notice)=="table" and notice[1]=="ei-factory-passage.inspection-started","inspection notice is localized")
    local examined=storage.ei.admin_tools.inspection.examined
    admin.registry.updater{tick=game.tick}
    check(storage.ei.admin_tools.inspection.examined-examined<=64,"inspection bounded to64")
    check(admin.registry.cancel_inspection(player.index),"inspection cancels")
    admin.open(player,"options",game.tick)
    gui.refresh(player.index,game.tick)
    capture(player,"map-settings")
    -- Capture the settings editor before opening the native machine window.
    q.matrix_ready=true
end
local function tick(player_index,surface_index)
    local player=game.get_player(player_index);local surface=game.surfaces[surface_index]
    if not root() then setup(player,surface);return end
    local q=root();local age=game.tick-q.started
    if q.map_capture_due and game.tick>=q.map_capture_due then
        local session=storage.ei.admin_tools.sessions[player.index]
        local pane=session.options.body.parent
        while pane and pane.type~="scroll-pane" do pane=pane.parent end
        pane.scroll_to_element(session.options.rows[key].value)
        session.root.bring_to_front()
        local path="factory-passage/admin/map-settings.png"
        game.take_screenshot{player=player,resolution={1280,720},path=path,show_gui=true,force_render=true}
        q.frames[#q.frames+1]={path=path,tick=game.tick,scene="map-settings"}
        q.map_capture_due=nil
        if q.matrix_ready then q.matrix_due=game.tick+2;q.matrix_ready=nil end
    end
    if q.finished then return {checks=q.checks,frames=q.frames,finished=true} end
    if age==10 then gui_checks(player) end
    if q.matrix_due and game.tick>=q.matrix_due then
        q.matrix_due=nil;q.matrix=1;q.matrix_tick=game.tick;q.matrix_before=passage.status().counters
        player.teleport({80,84},q.crafter.surface)
        player.opened=q.crafter;passage.on_gui_opened{player_index=player.index,tick=game.tick}
        check(passage.status().gui_watchers==1,"GUI admission does not wait behind dirty work")
        set(budgets[1])
    end
    if q.matrix then
        local budget=budgets[q.matrix];local now=passage.status()
        if q.last_processed then check(now.counters.processed-q.last_processed<=q.last_budget,"native combined per-tick allowance") end
        q.last_processed=now.counters.processed;q.last_budget=budget
        if game.tick-q.matrix_tick>=8 then
            local before=q.matrix_before
            check(player.opened==q.crafter,"native GUI remains open within player reach")
            check((now.counters.dirty_attempts or 0)>(before.dirty_attempts or 0),"native dirty progress at "..budget)
            check((now.counters.pending_attempts or 0)>(before.pending_attempts or 0),"native occupied-joint progress at "..budget)
            check((now.counters.watchers_attempts or 0)>(before.watchers_attempts or 0),"native recipe-check progress at "..budget)
            q.matrix=q.matrix+1
            if budgets[q.matrix] then
                set(budgets[q.matrix]);q.matrix_tick=game.tick;q.matrix_before=now.counters;q.last_budget=budgets[q.matrix]
            else
                q.matrix=nil;q.last_processed=nil;set(1)
                player.opened=nil;passage.on_gui_closed{player_index=player.index,entity=q.crafter,tick=game.tick}
                q.real_ids={};for i,entity in ipairs(q.pipes) do q.real_ids[i]=entity.unit_number end
                q.fluid=q.pipes[1].get_fluid(1)
                check(admin.registry.repair(player.index,"factory-passage",game.tick),"manual repair admitted")
                local receipt=admin.registry.peek("factory-passage",game.tick).last_repair_message
                check(type(receipt)=="table" and receipt[1]=="ei-factory-passage.repair-requested","repair receipt is localized")
                receipt[2][1]="changed-in-detached-snapshot"
                check(admin.registry.peek("factory-passage",game.tick).last_repair_message[2][1]=="ei-factory-passage.owner","localized repair receipt is detached")
                q.repair_id=storage.ei.factory_passage.rebuild.id;q.repair_started=game.tick
                admin.open(player,"diagnostics",game.tick)
                storage.ei.admin_tools.sessions[player.index].module_id="factory-passage";gui.refresh(player.index,game.tick)
            end
        end
        if q.matrix then for _,entity in ipairs(q.pipes) do passage.refresh_entity(entity,game.tick) end end
    elseif q.repair_started then
        local now=passage.status();local elapsed=game.tick-q.repair_started
        if elapsed==130 then
            check(now.rebuild.active and now.dirty>0,"slow repair remains observable")
            capture(player,"active-rebuild")
            local completed=now.rebuild.completed;set(1024)
            check(passage.status().rebuild.id==q.repair_id and passage.status().rebuild.completed==completed,"pace change preserves report identity and progress")
        elseif elapsed==210 then
            check(now.counters.max_processed>256,"native fast setting exceeds old256 cap")
            check(now.dirty==0 and now.blocked>0 and now.rebuild.phase=="character-clearance","occupied-only repair reports waiting")
            local report=scheduler.peek_rebuilds(game.tick,"factory-passage")
            local waiting=false
            for _,row in ipairs(report.active) do
                if row.id==q.repair_id then waiting=row.state=="waiting" and row.waiting_reason=="character-clearance" and row.eta_ticks==nil end
            end
            check(waiting,"shared monitor retains exact waiting report without ETA")
            gui.refresh(player.index,game.tick);capture(player,"waiting-rebuild")
            q.actor.walking_state={walking=true,direction=defines.direction.north}
        elseif elapsed==245 then
            check(not now.rebuild.active and now.dirty==0 and now.pending==0 and now.watchers>0,"repair completes despite permanent recipe checks")
            local activity=scheduler.peek_rebuilds(game.tick,"factory-passage")
            local completed=false
            for _,row in ipairs(activity.history) do if row.id==q.repair_id and row.outcome=="completed" then completed=true end end
            check(completed,"completed repair enters scheduler history")
            check(q.actor.position.y<79.5,"occupied character leaves by native walking")
            for i,entity in ipairs(q.pipes) do check(entity.valid and entity.unit_number==q.real_ids[i],"repair preserves pipe identity "..i) end
            local fluid=q.pipes[1].get_fluid(1)
            check(fluid.name==q.fluid.name and math.abs(fluid.amount-q.fluid.amount)<0.001 and fluid.temperature==q.fluid.temperature,"repair preserves native fluid state")
            set(1);check(admin.registry.repair(player.index,"factory-passage",game.tick),"second repair admitted")
            local old=storage.ei.factory_passage.rebuild.id
            check(admin.registry.repair(player.index,"factory-passage",game.tick),"third repair supersedes second")
            check(old~=storage.ei.factory_passage.rebuild.id,"superseded report gets fresh identity")
            activity=scheduler.peek_rebuilds(game.tick,"factory-passage")
            local superseded=false
            for _,row in ipairs(activity.active) do check(row.id~=old,"superseded report no longer active") end
            for _,row in ipairs(activity.history) do if row.id==old and row.outcome=="superseded" then superseded=true end end
            check(superseded,"supersession retained in scheduler history")
            q.save_due=game.tick+3
        elseif q.save_due and game.tick>=q.save_due then
            local s=storage.ei.factory_passage
            q.checkpoint={cursor=s.service_cursor,dirty=s.dirty_count,report=s.rebuild.id,completed=s.rebuild.completed,processed=s.counters.processed}
            check(q.checkpoint.cursor~=1,"checkpoint retains a non-default fairness cursor")
            q.finished=true
            return {checks=q.checks,frames=q.frames,finished=true}
        end
    end
end
remote.add_interface("ei_factory_passage_qc",{
    tick=tick,
    reload=function()
        local q=root();local s=storage.ei.factory_passage
        check(q and q.checkpoint,"populated administration checkpoint retained")
        -- Production's dispatcher services one dirty item before this helper.
        check(s.counters.processed==q.checkpoint.processed+1 and s.service_cursor==q.checkpoint.cursor%8+1,"ordinary reload preserves fairness cursor before its first service")
        check(s.rebuild.id==q.checkpoint.report and s.rebuild.completed>=q.checkpoint.completed,"ordinary reload retains active report")
        check(s.dirty_count==q.checkpoint.dirty-1,"ordinary reload retains bounded backlog")
        check(settings.global[key].value==1,"ordinary reload retains runtime budget")
        return {checks=q.checks,finished=true}
    end,
})
