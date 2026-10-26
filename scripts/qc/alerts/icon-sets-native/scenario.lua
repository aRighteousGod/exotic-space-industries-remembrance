local model={}
local PROVIDER="esir-icon-sets-provider-qc__partial"
local function check(s,name,value) assert(value,name);s.checks[#s.checks+1]=name end
local function screenshot(player,name)
    game.take_screenshot{player=player,path="icon-sets-"..name..".png",resolution={1280,720},show_gui=true}
end
local function close_monitor(ctx,player,tick)
    local frame=player.gui.screen["ei-rebuild-monitor"]
    if not frame or not frame.valid then return end
    local function find(element)
        if element.tags.parent_gui=="ei-rebuild-monitor" and element.tags.action=="close" then return element end
        for _,child in pairs(element.children) do local match=find(child);if match then return match end end
    end
    local button=find(frame)
    if button then ctx.click{name=defines.events.on_gui_click,player_index=player.index,element=button,tick=tick} end
end
local function begin_capture(s,p,label,next_phase,tick)
    s.phase="capture";s.capture={label=label,next_phase=next_phase,tick=tick}
    if s.ecology then p.frame.visible=true;p.bodies[3].scroll_to_top() end
end
local function native(player,record)
    local target=record.entity or record.anchor;local result={}
    if not target or not target.valid then return result end
    for _,types in pairs(player.get_alerts{type=defines.alert_type.custom,entity=target}) do
        for _,rows in pairs(types) do for _,row in pairs(rows) do result[#result+1]=row end end
    end
    return result
end
local function shown(ctx,player,record,set_id)
    local rows=native(player,record)
    return #rows==1 and rows[1].icon and rows[1].icon.name==ctx.sets.signal_name(set_id,record.alert_id)
end
local function personal(ctx,player,name,value,tick)
    player.mod_settings[name]={value=value}
    local event={player_index=player.index,setting=name,setting_type="runtime-per-user",tick=tick}
    ctx.ecology.on_settings_changed(event);ctx.alerts.on_settings_changed(event);ctx.gui.on_settings_changed(event)
end
local function select(ctx,player,s,value,tick)
    local p=storage.ei.ecology_gui.players[player.index]
    if s.ecology then
        local selected
        for i,id in ipairs(p.icon_choices) do if id==value then selected=i;break end end
        check(s,"GUI offers "..value,selected~=nil)
        local before={};for i,row in ipairs(p.icon_rows) do before[i]=row.set_id end
        p.icon_selector.selected_index=selected
        ctx.selection{name=defines.events.on_gui_selection_state_changed,player_index=player.index,element=p.icon_selector,tick=tick}
        for i,row in ipairs(p.icon_rows) do check(s,"selection defers caption "..i,row.set_id==before[i]) end
    else ctx.alerts.set_icon_set(player,value,tick) end
    local resolved=value==ctx.sets.sentinel and s.startup or value
    check(s,"personal choice normalized "..value,player.mod_settings[ctx.sets.setting_name].value==resolved)
    s.target=resolved;s.phase_tick=tick
end
local function condition(ctx,player,s,key,position,tick)
    position={s.origin.x+position[1],s.origin.y+position[2]}
    local entity=assert(s.surface.create_entity{name="steel-chest",position=position,force=player.force})
    local channel=ctx.alerts.channel_state("operational");local next_id=channel.next_id+1
    check(s,"condition admitted "..key,ctx.alerts.set_condition("operational",key,"gate-low-power",true,
        {entity=entity,source_id=key,message={"ei-alerts.name-gate-low-power"}},tick))
    return assert(channel.by_id[next_id])
end
local function ecology(ctx,s,category,position,tick)
    local owner=assert(storage.ei.terrain_evolution.surfaces[s.surface.index])
    local channel=ctx.alerts.channel_state("ecology");local next_id=channel.next_id+1
    position={s.origin.x+position[1],s.origin.y+position[2]}
    check(s,"ecology receipt admitted "..category,ctx.ecology.record_effect{category=category,surface=s.surface,
        owner=owner,position=position,tick=tick,count=1})
    return assert(channel.by_id[next_id])
end
local function report(s,phase,complete)
    return {complete=complete,all_pass=true,phase=phase,count=#s.checks,checks=s.checks,engine=script.active_mods.base,
        scale=s.scale,ecology=s.ecology,provider=script.active_mods["esir-icon-sets-provider-qc"]~=nil,
        max_gui_writes=s.max_gui_writes or 0,
        visible_once_survived_provider_removal=s.visible_survived_reload,
        scope="Native signals, registered selection dispatcher, bounded GUI captions, actual custom-alert replacement and provider serialization; no two-client multiplayer."}
end
local function remember(ctx,s,record,channel)
    local item={record=record,channel=channel,id=record.id,expires=record.expires,tick=record.tick,
        anchor=record.anchor,owner=record.owner,token=record.chunk_token,
        references=record.chunk_token and record.chunk_token.references,
        recipients=#record.recipients,delivered=record.delivered[s.player_index]}
    s.saved.records[#s.saved.records+1]=item
end
local function prepare_checkpoint(ctx,player,s,tick)
    s.pending_condition=condition(ctx,player,s,"icon-set-pending",{10,10},tick)
    s.pending_ecology=ecology(ctx,s,"drought",{64,0},tick)
    local operational=ctx.alerts.channel_state("operational");local eco=ctx.alerts.channel_state("ecology")
    -- Keep newly admitted records pending until after the asynchronous save. No
    -- fake delivery or receipt reconstruction is used by this fixture.
    operational.next_tick=tick+96;eco.next_tick=tick+96
    s.saved={records={},version=storage.ei.alerts.version,presentation_version=storage.ei.alerts.presentation_version,
        legacy_version=storage.ei.ecology_alerts.alert_delivery_version,ecology_delivered=eco.delivered,
        ecology_next_id=eco.next_id,ecology_anchors=eco.anchors,provider=PROVIDER,selected=player.mod_settings[ctx.sets.setting_name].value}
    for _,pair in ipairs{{s.condition,"operational"},{s.pending_condition,"operational"},
        {s.visible,"ecology"},{s.dismissed,"ecology"},{s.pending_ecology,"ecology"}} do remember(ctx,s,pair[1],pair[2]) end
    check(s,"checkpoint has pending condition",#s.pending_condition.recipients==0)
    check(s,"checkpoint has pending receipt",#s.pending_ecology.recipients==0 and not s.pending_ecology.anchor)
    check(s,"checkpoint has visible provider condition",shown(ctx,player,s.condition,PROVIDER))
    check(s,"checkpoint has visible provider once alert",shown(ctx,player,s.visible,PROVIDER))
    check(s,"checkpoint dismissed once alert remains absent",#native(player,s.dismissed)==0)
    local p=storage.ei.ecology_gui.players[player.index]
    if p.launcher then ctx.gui.on_gui_click{player_index=player.index,element=p.launcher_toggle,tick=tick} end
    p.frame.location={x=48,y=48};p.bodies[3].scroll_to_element(p.checks.blood,"top-third")
    s.saved.frame=p.frame;s.saved.pane=p.bodies[3];s.saved.location=p.frame.location;s.saved.tab=p.tab
    screenshot(player,"provider-checkpoint")
    s.phase="checkpoint";s.save_tick=tick
    local result=report(s,"checkpoint-requested",false)
    result.save_name="_autosave-style-provider.zip";result.save_tick=tick
    return result
end
local function resume(ctx,player,s,tick)
    check(s,"provider disabled on reload",not script.active_mods["esir-icon-sets-provider-qc"])
    check(s,"saved explicit provider choice",s.saved.selected==PROVIDER)
    s.startup=settings.startup[ctx.sets.default_setting_name].value
    local resolved=ctx.sets.player_set(player)
    check(s,"removed provider freezes valid startup fallback",player.mod_settings[ctx.sets.setting_name].value==resolved and resolved~=PROVIDER and resolved~=ctx.sets.sentinel)
    check(s,"reload preserves future-player startup sentinel",settings.player_default[ctx.sets.setting_name].value==ctx.sets.sentinel)
    s.visible_survived_reload=#native(player,s.visible)>0
    check(s,"reload runtime family excludes provider",#ctx.sets.available_sets()==#ctx.sets.builtin_ids)
    check(s,"alert migration version preserved",storage.ei.alerts.version==s.saved.version and storage.ei.alerts.presentation_version==s.saved.presentation_version)
    check(s,"ecology legacy adoption version preserved",storage.ei.ecology_alerts.alert_delivery_version==s.saved.legacy_version)
    local eco=ctx.alerts.channel_state("ecology")
    check(s,"pending receipt IDs and native counters survive reload",eco.next_id==s.saved.ecology_next_id and eco.delivered==s.saved.ecology_delivered and eco.anchors==s.saved.ecology_anchors)
    for _,item in ipairs(s.saved.records) do
        local record=ctx.alerts.channel_state(item.channel).by_id[item.id]
        check(s,"record identity/deadline survives "..item.channel..item.id,record==item.record and record.expires==item.expires and record.tick==item.tick)
        check(s,"recipient state survives "..item.channel..item.id,#record.recipients==item.recipients and record.delivered[player.index]==item.delivered)
        if item.token then
            check(s,"receipt identity/reference survives "..item.id,record.chunk_token==item.token and record.owner==item.owner and item.token.references==item.references)
        end
        if item.anchor then check(s,"native marker survives "..item.id,record.anchor==item.anchor and item.anchor.valid) end
    end
    local p=storage.ei.ecology_gui.players[player.index]
    check(s,"configuration retains native frame and scroll pane",p.frame==s.saved.frame and p.bodies[3]==s.saved.pane)
    check(s,"configuration retains tab location hidden launcher",p.tab==s.saved.tab and not p.launcher and p.frame.location.x==s.saved.location.x and p.frame.location.y==s.saved.location.y)
    s.target=resolved;s.phase="reload-wait";s.phase_tick=tick
end
function model.step(ctx,player,tick,first)
    storage.icon_sets_fixture=storage.icon_sets_fixture or {checks={},phase="init",start=tick}
    local s=storage.icon_sets_fixture
    if s.phase=="checkpoint" then
        if first then resume(ctx,player,s,tick) end
        return
    end
    local p=storage.ei.ecology_gui and storage.ei.ecology_gui.players[player.index]
    close_monitor(ctx,player,tick)
    if p and p.frame and p.frame.valid and p.last_update_writes then
        s.max_gui_writes=math.max(s.max_gui_writes or 0,p.last_update_writes)
        assert(p.last_update_writes<=8,"native GUI viewer exceeded eight writes")
    end
    if s.phase=="capture" then
        local capture=s.capture;local elapsed=tick-capture.tick
        if elapsed==4 and s.ecology then screenshot(player,capture.label.."-top")
        elseif elapsed==12 and s.ecology then p.bodies[3].scroll_to_element(p.checks.blood,"top-third")
        elseif elapsed==16 and s.ecology then screenshot(player,capture.label.."-bottom")
        elseif elapsed==24 and s.ecology then p.frame.visible=false
        elseif elapsed==28 or elapsed==43 or elapsed==58 then screenshot(player,capture.label.."-toolbar-"..(elapsed-28))
        elseif elapsed>=64 then
            if s.ecology then p.frame.visible=true;p.bodies[3].scroll_to_top() end
            s.capture=nil
            if capture.next_phase=="retire" then
                for _,r in ipairs{s.visible,s.dismissed,s.pending_ecology} do r.cancelled=true end
                ctx.alerts.clear_source("operational","icon-set-visible",tick);ctx.alerts.clear_source("operational","icon-set-pending",tick)
                s.phase="retire";s.phase_tick=tick
            else
                s.transition=s.transition+1
                if s.transitions[s.transition] then s.phase="transition";select(ctx,player,s,s.transitions[s.transition],tick)
                elseif s.ecology and script.active_mods["esir-icon-sets-provider-qc"] then
                    check(s,"provider is selected before save",s.target==PROVIDER)
                    return prepare_checkpoint(ctx,player,s,tick)
                else return report(s,"complete",true) end
            end
        end
    elseif s.phase=="init" then
        s.player_index=player.index;s.scale=player.display_scale;s.ecology=settings.startup["ei-terrain-evolution-enabled"].value
        s.startup=settings.startup[ctx.sets.default_setting_name].value
        check(s,"Factorio evidence baseline",script.active_mods.base=="2.0.77")
        check(s,"default or enlarged UI scale",math.abs(s.scale-1)<0.01 or math.abs(s.scale-1.5)<0.01)
        check(s,"startup selection initialized into concrete personal choice",player.mod_settings[ctx.sets.setting_name].value==s.startup)
        check(s,"native map default retains future-player startup sentinel",settings.player_default[ctx.sets.setting_name].value==ctx.sets.sentinel)
        local saved_personal=player.mod_settings[ctx.sets.setting_name].value
        settings.player_default[ctx.sets.setting_name]={value="original"}
        ctx.alerts.on_settings_changed{setting_type="runtime-per-user",setting=ctx.sets.setting_name,tick=tick}
        check(s,"nil-player setting event restores future-player sentinel",settings.player_default[ctx.sets.setting_name].value==ctx.sets.sentinel)
        check(s,"future-player default edit preserves personal choice",player.mod_settings[ctx.sets.setting_name].value==saved_personal)
        for _,set_id in ipairs(ctx.sets.builtin_ids) do
            for _,entry in ipairs(ctx.catalog.entries) do check(s,"native signal "..set_id.."/"..entry.id,prototypes.virtual_signal[ctx.sets.signal_name(set_id,entry.id)]~=nil) end
        end
        check(s,"visible native personal selector prototype",prototypes.mod_setting[ctx.sets.setting_name]~=nil)
        for _,entry in ipairs(ctx.catalog.entries) do
            personal(ctx,player,entry.setting_name,true,tick)
            if entry.master then personal(ctx,player,entry.master,true,tick) end
        end
        player.admin=true;player.game_view_settings.show_alert_gui=true;player.enable_alert(defines.alert_type.custom)
        -- Ecology owners require a real planetary surface, not an unassociated
        -- scratch surface. Use remote fresh chunks away from the seed's factory.
        s.surface=game.surfaces.nauvis;s.origin={x=1024,y=1024}
        s.surface.request_to_generate_chunks(s.origin,2);s.surface.force_generate_chunk_requests();player.teleport(s.origin,s.surface)
        if player.controller_type==defines.controllers.editor then player.toggle_map_editor() end
        if s.ecology then
            ctx.ecology.set_preference(player,"allow-unrevealed",true)
            p=storage.ei.ecology_gui.players[player.index]
            if p and p.frame and p.frame.valid then ctx.gui.on_toggle_menu{player_index=player.index,tick=tick} end
            ctx.gui.on_toggle_menu{player_index=player.index,tick=tick};p=storage.ei.ecology_gui.players[player.index]
            p.pane.selected_tab_index=3;ctx.tabs{name=defines.events.on_gui_selected_tab_changed,player_index=player.index,element=p.pane,tick=tick}
            check(s,"new selector above alert preferences",p.icon_selector.valid and #p.icon_rows==17)
            p.frame.location={x=16,y=12}
        end
        select(ctx,player,s,"original",tick);s.phase="admit";s.phase_tick=tick
    elseif s.phase=="admit" and tick-s.phase_tick>=32 then
        s.condition=condition(ctx,player,s,"icon-set-visible",{6,6},tick)
        if s.ecology then s.visible=ecology(ctx,s,"wildfire",{0,0},tick);s.dismissed=ecology(ctx,s,"flood",{32,0},tick) end
        s.phase="delivery-wait";s.phase_tick=tick
    elseif s.phase=="delivery-wait" then
        assert(tick-s.phase_tick<640,"initial native deliveries did not converge")
        if shown(ctx,player,s.condition,"original") and (not s.ecology or (shown(ctx,player,s.visible,"original") and shown(ctx,player,s.dismissed,"original"))) then
            if s.ecology then
                local row=native(player,s.dismissed)[1]
                player.remove_alert{entity=s.dismissed.anchor,type=defines.alert_type.custom,icon=row.icon,message=row.message}
                s.once_delivered=ctx.alerts.channel_state("ecology").delivered
                -- Reconstruct only the preceding GUI layout, retaining actual
                -- native widgets/scroll. This exercises the real configuration
                -- upgrade path without replacing gameplay or alert storage.
                p.bodies[3].scroll_to_element(p.checks.blood,"top-third")
                local frame,pane,tab,launcher=p.frame,p.bodies[3],p.tab,p.launcher
                screenshot(player,"layout4-before")
                p.icon_selector.parent.destroy();p.icon_selector=nil;p.icon_choices=nil;p.icon_rows=nil;p.layout_version=4
                ctx.gui.initialize(tick)
                check(s,"native layout4 frame and scroll pane adopted",p.frame==frame and p.bodies[3]==pane and p.layout_version==5)
                check(s,"native layout4 tab and launcher preserved",p.tab==tab and p.launcher==launcher)
                check(s,"layout4 caption work remains queued",p.icon_cursor==1)
                screenshot(player,"layout5-after")
            end
            s.transitions={"svg","rendered","vanilla","original"}
            if script.active_mods["esir-icon-sets-provider-qc"] then s.transitions[#s.transitions+1]=PROVIDER end
            s.transitions[#s.transitions+1]=ctx.sets.sentinel
            s.transition=0;begin_capture(s,p,"original","advance",tick)
        end
    elseif s.phase=="transition" and tick-s.phase_tick>=192 then
        check(s,"native condition uses "..s.target,shown(ctx,player,s.condition,s.target))
        if s.ecology then
            check(s,"native once alert uses "..s.target,shown(ctx,player,s.visible,s.target))
            check(s,"dismissed once alert stays absent "..s.target,#native(player,s.dismissed)==0)
            check(s,"style never replays once delivery "..s.target,ctx.alerts.channel_state("ecology").delivered==s.once_delivered)
            for _,row in ipairs(p.icon_rows) do check(s,"GUI caption uses "..s.target.."/"..row.definition.id,row.set_id==s.target) end
            check(s,"GUI shows concrete selection "..s.target,p.icon_choices[p.icon_selector.selected_index]==s.target)
        end
        begin_capture(s,p,"selection-"..s.transition,"advance",tick)
    elseif s.phase=="reload-wait" then
        assert(tick-s.phase_tick<640,"provider removal did not converge")
        if tick-s.phase_tick>=256 then
            check(s,"visible condition reicons after provider removal",shown(ctx,player,s.condition,s.target))
            check(s,"pending condition delivers fallback",shown(ctx,player,s.pending_condition,s.target))
            if s.visible_survived_reload then check(s,"surviving once reicons after provider removal",shown(ctx,player,s.visible,s.target))
            else check(s,"engine-removed once stays absent without replay",#native(player,s.visible)==0) end
            check(s,"pending receipt delivers fallback",shown(ctx,player,s.pending_ecology,s.target))
            check(s,"dismissed once remains absent after reload",#native(player,s.dismissed)==0)
            check(s,"exactly one pending ecology first delivery",ctx.alerts.channel_state("ecology").delivered==s.saved.ecology_delivered+1)
            for _,row in ipairs(p.icon_rows) do check(s,"fallback GUI "..row.definition.id,row.set_id==s.target) end
            begin_capture(s,p,"provider-removed","retire",tick)
        end
    elseif s.phase=="retire" and tick-s.phase_tick>=256 then
        for _,item in ipairs(s.saved.records) do
            check(s,"record retired "..item.channel..item.id,not ctx.alerts.channel_state(item.channel).by_id[item.id])
            if item.token then check(s,"receipt released once "..item.id,item.record.chunk_token==nil and item.token.references==item.references-1) end
            if item.anchor then check(s,"marker removed "..item.id,not item.anchor.valid) end
        end
        check(s,"pending-created marker also removed",not s.pending_ecology.anchor.valid)
        return report(s,"provider-removed-and-retired",true)
    end
end
return model
