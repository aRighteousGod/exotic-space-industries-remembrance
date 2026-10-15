local model={}
local function dispatch(name,p,element,tick,extra)
    local event={name=defines.events[name],player_index=p.index,element=element,tick=tick,button=defines.mouse_button_type.left}
    for k,v in pairs(extra or {}) do event[k]=v end
    return assert(script.get_event_handler(defines.events[name]))(event)
end
local function find(element,name)
    if element.name==name then return element end
    for _,child in pairs(element.children or {}) do local found=find(child,name);if found then return found end end
end
local function session(p) return storage.ei.ecology_gui.players[p.index] end
local function action(element,name)
    if element.tags.action==name then return element end
    for _,child in pairs(element.children or {}) do local found=action(child,name);if found then return found end end
end
local function shot(p,name)
    game.take_screenshot{player=p,path="ecology-v2/"..name..".png",show_gui=true,show_entity_info=false,force_render=true,resolution=p.display_resolution}
end
function model.step(ctx,p,phase,tick)
    local checks={};local function check(name,ok,detail) checks[#checks+1]={name=name,ok=not not ok,detail=detail} end
    local root=storage.ei.terrain_evolution
    local s=p.surface
    if phase==0 then
        check("real connected native player",p.connected)
        local far={x=12288,y=12288};storage.ecology_qc_far=far
        s.request_to_generate_chunks(far,0);s.force_generate_chunk_requests()
        p.force.chart(s,{{far.x,far.y},{far.x+1,far.y+1}})
        p.set_controller{type=defines.controllers.god}
        local monitor=storage.ei.rebuild_monitor and storage.ei.rebuild_monitor.players[p.index]
        if monitor and monitor.root and monitor.root.valid then
            for _,child in pairs(monitor.root.children[1].children) do
                if child.tags.action=="close" then dispatch("on_gui_click",p,child,tick);break end
            end
        end
        p.admin=false;ctx.alerts.on_player_event{player_index=p.index,tick=tick};ctx.gui.on_player_event{player_index=p.index,tick=tick}
        local count=0;for _ in pairs(game.surfaces) do count=count+1 end;storage.ecology_qc_surface_count=count
        local button=assert(find(p.gui.top,"ei-ecology-button"),"Ecology launcher missing")
        check("mechanical tree launcher uses native sprite-button",button.type=="sprite-button")
        local button_parent=button.parent;button.destroy()
        button_parent.add{type="button",name="ei-ecology-button",caption="Ecology"}
        ctx.gui.on_player_event{player_index=p.index,tick=tick}
        button=assert(find(p.gui.top,"ei-ecology-button"))
        check("legacy text launcher upgrades in place",button.type=="sprite-button" and button.tags.action=="open")
        local saved_phase=ctx.terrain.public_snapshot(s,tick).calendar.phase
        for i,season in ipairs{"spring","summer","autumn","winter"} do
            local sprite="ei-ecology-tree-"..season
            check("loaded seasonal sprite "..season,helpers.is_valid_sprite_path(sprite))
            ctx.terrain.set_season_phase(s,(i-1)/4+0.125,tick)
            ctx.gui.on_player_event{player_index=p.index,tick=tick}
            check("season selects "..season,button.sprite==sprite and session(p).button_season==i)
        end
        ctx.terrain.set_season_phase(s,saved_phase,tick);ctx.gui.on_player_event{player_index=p.index,tick=tick}
        dispatch("on_gui_click",p,button,tick)
        local view=session(p)
        check("nonadministrator opens Simple",view and view.frame.valid and view.tab==1)
        check("first open binds current view without clearing",view.surface==s and not view.clearing)
        check("administrator preference is disabled",not view.checks["allow-unrevealed"].enabled)
        check("personal defaults enable five hazards",ctx.alerts.preferences(p).wildfire and ctx.alerts.preferences(p).flood and ctx.alerts.preferences(p).drought and ctx.alerts.preferences(p).cliff and ctx.alerts.preferences(p).paving)
        local phase_root=root
        ctx.alerts.set_preference(p,"surfaces","all");ctx.alerts.set_preference(p,"enabled",true)
        check("personal changes preserve terrain owner",storage.ei.terrain_evolution==phase_root)
    elseif phase==1 then
        local view=session(p)
        check("Simple rows populated",view.rows[1][1].element.caption[1]=="ei-ecology.surface" and view.rows[1][2].element.caption[1]~="")
        view.pane.selected_tab_index=2;dispatch("on_gui_selected_tab_changed",p,view.pane,tick)
        check("Advanced tab remembers selection",view.tab==2)
        ctx.alerts.set_preference(p,"surfaces",'["missing-ecology-qc"]')
        p.mod_settings["ei-ecology-alert-surfaces"]={value="{invalid}"}
        dispatch("on_runtime_mod_setting_changed",p,nil,tick,{setting="ei-ecology-alert-surfaces",setting_type="runtime-per-user"})
        check("invalid JSON restores last valid preference",p.mod_settings["ei-ecology-alert-surfaces"].value=='["missing-ecology-qc"]')
        check("missing name retained",ctx.alerts.preferences(p).selected["missing-ecology-qc"])
        check("nonadministrator override denied",not ctx.alerts.set_preference(p,"allow-unrevealed",true))
        ctx.alerts.set_preference(p,"surfaces","all")
        local c=root.surfaces[s.index];assert(c,"Fixture player must view supported surface")
        local position={x=p.position.x+3,y=p.position.y+3}
        storage.ecology_qc_position=position;storage.ecology_qc_surface=s
        local visible=p.force.is_chunk_visible(s,{math.floor(position.x/32),math.floor(position.y/32)})
        check("positive incident chunk currently visible",visible)
        check("native alert API lane accepts receipt",ctx.alerts.record_effect{category="wildfire",surface=s,owner=c,position=position,tick=tick,count=1})
        ctx.alerts.record_effect{category="wildfire",surface=s,owner=c,position=position,tick=tick,count=2}
        check("ten second coalescing shares one incident",#storage.ei.ecology_alerts.items==1 and storage.ei.ecology_alerts.items[1].count==3)
    elseif phase==2 then
        local view=session(p)
        local alerts=storage.ei.ecology_alerts;local r=alerts.items[1]
        check("native helper created",r and r.anchor and r.anchor.valid and r.anchor.name=="ei-ecology-alert-anchor")
        check("native alert delivered",r and r.delivered[p.index] and #ctx.alerts.preferences(p).live==1)
        local native=r and r.anchor and p.get_alerts{entity=r.anchor,type=defines.alert_type.custom}
        check("vanilla alert window contains owned incident",native and next(native)~=nil)
        check("immutable alert target matches incident",r and r.anchor.position.x==r.position.x and r.anchor.surface==r.surface)
        view.pane.selected_tab_index=3;dispatch("on_gui_selected_tab_changed",p,view.pane,tick)
        view.checks.flood.state=false;dispatch("on_gui_checked_state_changed",p,view.checks.flood,tick)
        check("GUI changes canonical native preference",p.mod_settings["ei-ecology-alert-flood"].value==false)
        p.mod_settings["ei-ecology-alert-flood"]={value=true}
        dispatch("on_runtime_mod_setting_changed",p,nil,tick,{setting="ei-ecology-alert-flood",setting_type="runtime-per-user"})
        check("native settings changes synchronize checkbox",view.checks.flood.state)
        ctx.alerts.set_preference(p,"enabled",false)
        local unrelated=s.create_entity{name="iron-chest",position={p.position.x+5,p.position.y+5},force=p.force}
        if unrelated then p.add_custom_alert(unrelated,{type="virtual",name="signal-info"},"Unrelated fixture alert",true);storage.ecology_qc_unrelated=unrelated end
    elseif phase==3 then
        check("master disable retires owned native alert",#ctx.alerts.preferences(p).live==0)
        local unrelated=storage.ecology_qc_unrelated
        check("unrelated custom alert retained",unrelated and unrelated.valid and next(p.get_alerts{entity=unrelated,type=defines.alert_type.custom})~=nil)
        local view=session(p);dispatch("on_gui_closed",p,view.frame,tick)
        check("closed Ecology viewer performs no refresh",not ctx.gui.has_tick_work(tick+1000))
        local calendar_before=ctx.terrain.public_snapshot(s,tick).calendar.phase
        local daytime_before=helpers.table_to_json(s.daytime_parameters)
        ctx.terrain.set_season_phase(s,0.625,tick)
        storage.ei.ecology_gui.launcher_next_tick=tick
        ctx.gui.launcher_updater{tick=tick}
        check("closed report still admits seasonal launcher",session(p).button.sprite=="ei-ecology-tree-autumn"
            and not ctx.gui.has_tick_work(tick+1000) and not session(p).frame)
        check("launcher does not write daylight",helpers.table_to_json(s.daytime_parameters)==daytime_before)
        ctx.terrain.set_season_phase(s,calendar_before,tick)
        local before=0;for _ in pairs(game.surfaces) do before=before+1 end
        check("report viewing creates no surface",before==storage.ecology_qc_surface_count)
        ctx.alerts.set_preference(p,"enabled",true)
        local rename=game.create_surface("ecology-v2-rename-probe");storage.ecology_qc_rename_surface=rename
        ctx.alerts.set_preference(p,"surfaces",helpers.table_to_json({rename.name}))
        local old=rename.name
        dispatch("on_gui_click",p,assert(find(p.gui.top,"ei-ecology-button")),tick)
        local view=session(p);view.pane.selected_tab_index=3;dispatch("on_gui_selected_tab_changed",p,view.pane,tick)
        -- Force the catalog to refresh before this player's bounded rename pass.
        -- This reproduces delayed membership in a multi-player rename generation
        -- with one real player, without creating fake players or extra surfaces.
        storage.ei.ecology_alerts.next_tick=tick+64
        rename.name="ecology-v2-renamed";ctx.alerts.refresh_preferences(p)
        ctx.gui.on_surface_event()
        storage.ei.ecology_gui.next_tick=tick;ctx.gui.updater{tick=tick}
        check("rename catalog precedes canonical preference repair",
            view.surface_epoch==storage.ei.ecology_gui.surface_epoch
            and view.surface_selection==helpers.table_to_json({old})
            and not ctx.alerts.preferences(p).selected[rename.name])
        storage.ecology_qc_old_name=old
        check("intervening preference refresh preserves renamed identity",ctx.alerts.preferences(p).identities[old]==rename)
    elseif phase==4 then
        local rename=storage.ecology_qc_rename_surface
        check("rename maintenance updates exact-name selection",ctx.alerts.preferences(p).selected[rename.name])
        local renamed_view=session(p)
        check("open Alerts picker follows delayed canonical rename",
            renamed_view.surface_selection==ctx.alerts.preferences(p).surfaces
            and renamed_view.surface_selection==helpers.table_to_json({rename.name}))
        dispatch("on_gui_closed",p,renamed_view.frame,tick)
        rename.name=storage.ecology_qc_old_name
        local before=s.daytime_parameters
        local fulgora=game.planets.fulgora.surface
        if fulgora then check("Fulgora calendar does not own daylight",not ctx.terrain.public_snapshot(fulgora,tick).calendar.owns_daylight) end
        dispatch("on_player_display_scale_changed",p,nil,tick)
        dispatch("on_gui_click",p,assert(find(p.gui.top,"ei-ecology-button")),tick)
        local view=session(p);view.pane.selected_tab_index=1;dispatch("on_gui_selected_tab_changed",p,view.pane,tick)
    elseif phase==5 then
        local view=session(p);local frame=view.frame;local position=frame.location
        check("window within native horizontal viewport",position.x>=0 and position.x+frame.style.minimal_width*p.display_scale<=p.display_resolution.width+2)
        dispatch("on_gui_closed",p,frame,tick)
        check("closed viewer stays idle at changed scale",not ctx.gui.has_tick_work(tick+1000))
        local maintenance=root.work.jobs.maintenance
        check("preference maintenance has finite completion",not maintenance)
    elseif phase==6 then
        local a=storage.ei.ecology_alerts
        for _,r in ipairs(a.items) do r.expires=tick end
        ctx.alerts.updater{tick=tick+32}
        check("bounded alert state",#a.items<=64 and a.anchors<=32 and #ctx.alerts.preferences(p).live<=4)
        check("alert anchors excluded from occupancy",root.natural_exclusions and table_size(root.natural_exclusions)>0)
        for _,invalid in ipairs{'[null]','["nauvis",null]','[["nauvis"]]','["nauvis",]'} do
            check("invalid array rejected "..invalid,not ctx.alerts.set_preference(p,"surfaces",invalid))
        end
        local utility=storage.ecology_qc_rename_surface
        ctx.alerts.set_preference(p,"surfaces","all")
        p.set_controller{type=defines.controllers.remote,surface=utility,position={0,0}}
        dispatch("on_gui_click",p,assert(find(p.gui.top,"ei-ecology-button")),tick)
        local view=session(p);view.pane.selected_tab_index=2;dispatch("on_gui_selected_tab_changed",p,view.pane,tick)
    elseif phase==7 then
        local view=session(p)
        check("remote view binds utility surface",view.surface==storage.ecology_qc_rename_surface)
        check("remote unsupported surface uses steady fallback",view.button.sprite=="ei-ecology-tree-summer" and view.button_season==0)
        local setting;for _,row in ipairs(view.rows[2]) do if row.key:sub(1,8)=="setting:" then setting=row;break end end
        check("unsupported Advanced uses unknown settings",setting and type(setting.element.caption[4])=="table" and setting.element.caption[4][1]=="ei-ecology.unknown")
        dispatch("on_gui_closed",p,view.frame,tick)
        p.set_controller{type=defines.controllers.god};p.teleport(storage.ecology_qc_position,storage.ecology_qc_surface)
        ctx.alerts.set_preference(p,"surfaces","all");ctx.alerts.set_preference(p,"enabled",true)
        local owner=root.surfaces[p.surface.index]
        ctx.alerts.record_effect{category="wildfire",surface=p.surface,owner=owner,position=storage.ecology_qc_position,tick=tick,count=1}
    elseif phase==8 then
        local a=storage.ei.ecology_alerts
        check("recipient checks share cleanup allowance",a.last_service and a.last_service.recipient_checks<=2)
        check("native alert remains after GUI close",#ctx.alerts.preferences(p).live>0)
    elseif phase==9 then
        local far=storage.ecology_qc_far;local chunk={x=math.floor(far.x/32),y=math.floor(far.y/32)}
        check("negative chunk explored",p.force.is_chunk_charted(s,chunk))
        check("negative chunk not currently visible",not p.force.is_chunk_visible(s,chunk))
        ctx.alerts.record_effect{category="flood",surface=s,owner=root.surfaces[s.index],position=far,tick=tick,count=1}
        storage.ecology_qc_hidden_id=storage.ei.ecology_alerts.next_id
    elseif phase==10 then
        local a=storage.ei.ecology_alerts;local hidden=a.by_id[storage.ecology_qc_hidden_id]
        check("explored alone delivers no alert",not hidden or not hidden.delivered[p.index])
        p.admin=true;ctx.alerts.on_player_event{player_index=p.index,tick=tick}
        check("administrator may enable visibility override",ctx.alerts.set_preference(p,"allow-unrevealed",true))
        local far=storage.ecology_qc_far
        ctx.alerts.record_effect{category="drought",surface=s,owner=root.surfaces[s.index],position=far,tick=tick,count=1}
        storage.ecology_qc_admin_id=a.next_id
    elseif phase==11 then
        local a=storage.ei.ecology_alerts;local incident=a.by_id[storage.ecology_qc_admin_id]
        check("administrator override delivers hidden incident",incident and incident.delivered[p.index])
        dispatch("on_gui_click",p,assert(find(p.gui.top,"ei-ecology-button")),tick)
        local view=session(p);view.pane.selected_tab_index=3;dispatch("on_gui_selected_tab_changed",p,view.pane,tick)
        check("open administrator override starts checked",view.checks["allow-unrevealed"].state and view.checks["allow-unrevealed"].enabled)
        p.admin=false;dispatch("on_player_demoted",p,nil,tick)
        check("demotion immediately unchecks and disables open override",
            not view.checks["allow-unrevealed"].state and not view.checks["allow-unrevealed"].enabled)
    elseif phase==12 then
        local incident=storage.ei.ecology_alerts.by_id[storage.ecology_qc_admin_id]
        check("demotion retires hidden owned alert",not incident or not incident.delivered[p.index])
        check("demotion clears canonical visibility override",not p.mod_settings["ei-ecology-alert-allow-unrevealed"].value)
        dispatch("on_gui_closed",p,session(p).frame,tick)
        ctx.alerts.set_preference(p,"surfaces","[]")
        ctx.alerts.record_effect{category="cliff",surface=s,owner=root.surfaces[s.index],position=p.position,tick=tick,count=1}
        storage.ecology_qc_filtered_id=storage.ei.ecology_alerts.next_id
    elseif phase==13 then
        local incident=storage.ei.ecology_alerts.by_id[storage.ecology_qc_filtered_id]
        check("empty surface selection delivers nothing",not incident or not incident.delivered[p.index])
        ctx.alerts.set_preference(p,"surfaces","all");ctx.alerts.set_preference(p,"current-surface-only",true)
        local observed=storage.ecology_qc_surface
        p.set_controller{type=defines.controllers.remote,surface=storage.ecology_qc_rename_surface,position={0,0}}
        ctx.alerts.record_effect{category="paving",surface=observed,owner=root.surfaces[observed.index],position=storage.ecology_qc_position,tick=tick,count=1}
        storage.ecology_qc_current_id=storage.ei.ecology_alerts.next_id
    elseif phase==14 then
        local incident=storage.ei.ecology_alerts.by_id[storage.ecology_qc_current_id]
        check("current surface filter follows remote view",not incident or not incident.delivered[p.index])
        local a=storage.ei.ecology_alerts;for _,r in ipairs(a.items) do r.expires=tick end
    elseif phase==15 then
        local a=storage.ei.ecology_alerts
        check("expired incident helpers retire",#a.items==0 and a.anchors==0)
    end
    return checks
end
function model.capture(p,phase,tick)
    local monitor=storage.ei.rebuild_monitor and storage.ei.rebuild_monitor.players[p.index]
    if monitor and monitor.root and monitor.root.valid then local close=action(monitor.root,"close");if close then dispatch("on_gui_click",p,close,tick) end end
    local expected={[0]=1,[1]=2,[2]=3,[4]=1,[6]=2}
    if expected[phase] then assert(session(p).pane.selected_tab_index==expected[phase],"Unexpected capture tab") end
    local names={[0]="simple",[1]="advanced",[2]="alerts",[4]="reopened-simple",[6]="remote-unsupported",[7]="native-alerts"}
    if names[phase] then shot(p,names[phase]) end
end
return model
