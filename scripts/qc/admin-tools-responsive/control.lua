local gui=require("scripts/control/admin/gui")
local common=require("scripts/control/admin/common")
local camera=require("lib/camera-window")
local config=require("lib/admin-tools-config")
local util=require("util")
local checks={}
local function check(name,ok,detail) checks[#checks+1]={name=name,ok=not not ok,detail=detail};assert(ok,name..": "..tostring(detail)) end
local function catalogs(kind)
    local result={}
    for _,p in pairs(prototypes.entity) do
        local include=kind=="fires" and p.type=="fire" or kind=="resources" and p.type=="resource"
            or (kind=="enemies" or kind=="advanced_enemies") and (p.type=="unit" or p.type=="unit-spawner" or p.type=="turret" or p.type=="segmented-unit")
        if include then result[#result+1]={name=p.name,caption=p.localised_name} end
    end
    table.sort(result,function(a,b)return a.name<b.name end)
    return result
end
---@class ResponsiveDiagnosticOwner
---@field id string
---@field label string
---@field repair boolean
---@field classification string
---@field state string
---@field schema integer
---@field enabled boolean
---@field fields table<string,number>
---@field cached table<string,number>
---@field counters table<string,number>
---@field sample_tick integer
---@field cache_updated_tick integer
---@field last_repair_tick integer|nil
---@field last_repair_ok boolean|nil
---@field last_repair_message string|nil
---@type ResponsiveDiagnosticOwner[]
local owners={}
for i=1,49 do owners[i]={id="runtime-owner-"..i,label="Runtime owner "..i,repair=true,classification="stateful",state="initialized",schema=2,enabled=true,
    fields={tracked_count=i*3,ready_queue_count=i},cached={tracked_count=i*3,pending=i},counters={registered=i*4,invalid_purges=0},sample_tick=0,cache_updated_tick=0} end
local reads={}
---@param id string|nil
---@param tick integer
---@return ResponsiveDiagnosticOwner|{owners: ResponsiveDiagnosticOwner[]}|nil
local function diagnostics(id,tick)
    reads[#reads+1]=id or "overview"
    if not id then return {owners=owners} end
    for _,owner in ipairs(owners) do if owner.id==id then
        local snapshot=table.deepcopy(owner);snapshot.sample_tick=tick
        -- Exercise long localized metric lists across the native 20-parameter limit.
        for n=1,28 do snapshot.fields["stored_metric_"..n]=n end
        snapshot.last_repair_tick=12;snapshot.last_repair_ok=true;snapshot.last_repair_message="Fixture repair succeeded."
        return snapshot
    end end
end
gui.configure{planets=function()local result={};for name,planet in pairs(game.planets)do result[#result+1]={name=name,localised_name=planet.prototype.localised_name}end;return result end,world={get_policy=function()return{}end,peek_summary=function()return{jobs={}}end,get_catalog=catalogs,peek_rupture_radius=function()return 10 end},
    registry={list=function()return owners end},diagnostics=diagnostics,
    cancel_target=function()end,begin_target=function()end,inspect=function()end,export=function()end,
    cancel_inspection=function()common.state().inspection=nil end,
    execute=function(player,action,args)storage.last_execution={action=action,args=args}end}
script.on_event({defines.events.on_player_display_resolution_changed,defines.events.on_player_display_scale_changed},function(e)gui.on_display_changed(e);camera.on_display_changed(e)end)
local function find(parent,action,operation)
    for _,e in ipairs(parent.children) do
        if e.tags.action==action and (not operation or e.tags.operation==operation) then return e end
        local hit=find(e,action,operation);if hit then return hit end
    end
end
script.on_event(defines.events.on_tick,function(e)
    storage.step=(storage.step or 0)+1
    local p=game.connected_players[1];if not p then return end
    if storage.step==1 then
        p.admin=true
        if p.controller_type==defines.controllers.editor then p.toggle_map_editor() end
        local native_modes={cheat=p.cheat_mode,controller=p.controller_type}
        local before=#p.gui.top.children
        gui.launcher(p)
        check("default hidden launcher creates no container",#p.gui.top.children==before)
        for _,page in ipairs(config.pages) do gui.open(p,page.id,e.tick);check("build "..page.id,true) end
        gui.open(p,"moderation",e.tick)
        local s=common.peek().sessions[p.index];local field=s.fields.reason;local page=s.pages.moderation
        field.text="preserved draft";field.focus();gui.on_gui_change{element=field,player_index=p.index,tick=e.tick}
        gui.on_display_changed{player_index=p.index,tick=e.tick}
        check("same input and page after display event",field==s.fields.reason and page==s.pages.moderation and field.text=="preserved draft" and s.drafts.reason=="preserved draft")
        check("singleplayer kick disabled",not find(page,"execute","kick").enabled)
        check("singleplayer ban disabled",not find(page,"execute","ban").enabled)
        local moved={x=16,y=18}
        s.root.location=moved
        gui.refresh(p.index,e.tick)
        check("manual position survives explicit refresh",s.root.location.x==moved.x and s.root.location.y==moved.y and not s.root.auto_center)
        gui.result(p.index,"Fixture feedback",e.tick)
        check("manual position survives result layout",s.root.location.x==moved.x and s.root.location.y==moved.y)
        gui.result(p.index,"",e.tick)
        gui.open(p,"players",e.tick)
        check("manual position survives navigation",s.root.location.x==moved.x and s.root.location.y==moved.y)
        local enable_cheat=find(s.pages.players,"execute","cheat")
        local disable_cheat=find(s.pages.players,"execute","cheat_off")
        check("mode buttons use explicit enable and disable actions",enable_cheat.caption[1]=="ei-admin.cheat" and disable_cheat.caption[1]=="ei-admin.cheat_off" and enable_cheat.tags.args.enabled==true and disable_cheat.tags.args.enabled==false)
        check("opening mode controls preserves native player modes",p.cheat_mode==native_modes.cheat and p.controller_type==native_modes.controller)
        local prior_root=s.root
        gui.close(p.index)
        gui.open(p,"moderation",e.tick)
        check("manual position survives close and reopen",s.root==prior_root and s.root.location.x==moved.x and s.root.location.y==moved.y)
        gui.close(p.index,true)
        gui.open(p,"moderation",e.tick)
        check("manual position survives root recreation",s.root~=prior_root and s.root.location.x==moved.x and s.root.location.y==moved.y)
        gui.on_display_changed{player_index=p.index,tick=e.tick}
        check("manual position survives unchanged native viewport",s.root.location.x==moved.x and s.root.location.y==moved.y and s.fields.reason.text=="preserved draft")
        local automatic=s.auto_refresh_button
        local interval=s.fields.auto_refresh_interval
        check("automatic refresh defaults off with no scheduled work",automatic.caption[1]=="ei-admin.auto-refresh-off" and not automatic.toggled and not s.auto_refresh and s.auto_due_tick==nil and common.peek().auto_refresh_due_tick==nil)
        check("automatic refresh offers six intervals with five second default",#s.choices.auto_refresh_interval==6 and s.drafts.auto_refresh_interval==5 and interval.selected_index==3)
        gui.on_gui_click{element=automatic,player_index=p.index,tick=e.tick}
        check("automatic refresh enable uses displayed five second interval",automatic.caption[1]=="ei-admin.auto-refresh-on" and automatic.toggled and s.auto_due_tick==e.tick+300)
        interval.selected_index=1
        gui.on_gui_change{element=interval,player_index=p.index,tick=e.tick}
        check("automatic refresh one second selection reschedules same control",interval==s.fields.auto_refresh_interval and s.drafts.auto_refresh_interval==1 and s.auto_due_tick==e.tick+60)
        interval.selected_index=6
        gui.on_gui_change{element=interval,player_index=p.index,tick=e.tick}
        check("automatic refresh sixty second selection preserves position",s.auto_due_tick==e.tick+3600 and s.root.location.x==moved.x and s.root.location.y==moved.y)
        gui.on_gui_click{element=automatic,player_index=p.index,tick=e.tick}
        check("automatic refresh disable removes scheduled work",automatic.caption[1]=="ei-admin.auto-refresh-off" and not automatic.toggled and not s.auto_refresh and s.auto_due_tick==nil and common.peek().auto_refresh_due_tick==nil)
        interval.selected_index=3
        gui.on_gui_change{element=interval,player_index=p.index,tick=e.tick}
        check("interval changes while off stay unscheduled",s.drafts.auto_refresh_interval==5 and s.auto_due_tick==nil)
        gui.open(p,"fluids",e.tick)
        gui.on_gui_click{element=find(s.pages.fluids,"execute","fill_fluid"),player_index=p.index,tick=e.tick}
        check("automatic fluid storage omits index",storage.last_execution.args.fluidbox_index==nil)
        check("resource filter",s.fields.resource.elem_filters[1].type=="resource")
        gui.open(p,"enemies",e.tick)
        check("enemy catalog populated",#s.fields.enemy.items>0)
        local mode=s.fields.enemy_catalog;mode.selected_index=2;gui.on_gui_change{element=mode,player_index=p.index,tick=e.tick}
        gui.on_gui_click{element=find(s.pages.enemies,"execute","spawn_enemies"),player_index=p.index,tick=e.tick}
        check("advanced catalog confirmation",s.confirm and s.confirm.args.advanced==true)
        check("enemy spawn confirmation uses enemy force",s.confirm.args.force_index==game.forces.enemy.index)
        gui.on_gui_click{element=find(s.confirm_frame,"cancel-confirm"),player_index=p.index,tick=e.tick}
        gui.open(p,"effects",e.tick)
        check("hidden native fires available",#s.fields.advanced_fire.items>1)
        gui.open(p,"diagnostics",e.tick)
        check("structured diagnostic panes exist",s.diagnostics~=nil)
        if s.diagnostics then
            gui.open(p,"diagnostics",e.tick)
            local diagnostic=s.diagnostics;local overview=diagnostic.overview;local detail=diagnostic.detail
            local selected=find(overview,"inspect")
            reads={};gui.on_gui_click{element=selected,player_index=p.index,tick=e.tick}
            check("diagnostic selection reads selected owner only",#reads==1 and reads[1]==selected.tags.module_id)
            check("diagnostic detail toggles persistent panes",not overview.visible and detail.visible and diagnostic==s.diagnostics)
            check("diagnostic detail contains human metrics",diagnostic.values.fields.caption[1]=="")
            local enabled_row=diagnostic.values.enabled
            check("diagnostic enabled uses localized On",enabled_row and enabled_row.caption[1]=="ei-admin.diag-enabled" and enabled_row.caption[2][1]=="ei-admin.on")
            local selected_owner
            for _,owner in ipairs(owners) do if owner.id==selected.tags.module_id then selected_owner=owner;break end end
            selected_owner.enabled=false;gui.refresh(p.index,e.tick)
            check("diagnostic enabled updates same row to Off",enabled_row==diagnostic.values.enabled and enabled_row.caption[2][1]=="ei-admin.off")
            selected_owner.enabled=true;gui.refresh(p.index,e.tick)
            check("diagnostic enabled restores On without rebuilding detail",enabled_row==diagnostic.values.enabled and detail==diagnostic.detail and enabled_row.caption[2][1]=="ei-admin.on")
            local prior=serpent.line(diagnostic.signatures)
            gui.refresh(p.index,e.tick)
            check("unchanged detail retains caption signatures",serpent.line(diagnostic.signatures)==prior)
            common.state().inspection={id=selected.tags.module_id,examined=19}
            gui.refresh(p.index,e.tick)
            check("diagnostic active inspection can be cancelled",diagnostic.cancel.enabled and not diagnostic.inspect.enabled)
            gui.on_gui_click{element=diagnostic.cancel,player_index=p.index,tick=e.tick}
            check("diagnostic cancel restores inspect control",common.peek().inspection==nil and diagnostic.inspect.enabled and not diagnostic.cancel.enabled)
            gui.on_gui_click{element=find(detail,"diagnostic-overview"),player_index=p.index,tick=e.tick}
            check("diagnostic back preserves both pane identities",overview==s.diagnostics.overview and detail==s.diagnostics.detail and overview.visible and not detail.visible)
            gui.on_display_changed{player_index=p.index,tick=e.tick}
            check("diagnostic display change preserves pane identities",overview==s.diagnostics.overview and detail==s.diagnostics.detail)
        end
        gui.open(p,"repairs",e.tick)
        gui.on_gui_click{element=find(s.pages.repairs,"execute","repair"),player_index=p.index,tick=e.tick}
        check("repair confirmation names runtime owner",s.confirm_caption.caption[3][1]=="ei-admin.diag-repair-target" and s.confirm_caption.caption[3][2]==s.confirm.args.module_id)
        gui.on_gui_click{element=find(s.confirm_frame,"cancel-confirm"),player_index=p.index,tick=e.tick}
        gui.on_gui_click{element=find(s.pages.repairs,"execute","gaia-reforge"),player_index=p.index,tick=e.tick}
        check("Gaia confirmation names requesting administrator",s.confirm_caption.caption[3][1]=="ei-admin.confirm-gaia-target" and s.confirm_caption.caption[3][2]==p.name)
        gui.on_gui_click{element=find(s.confirm_frame,"cancel-confirm"),player_index=p.index,tick=e.tick}
    end
    if storage.step%8==0 then
        local n=storage.step/8;local page=config.pages[n]
        if page then
            gui.open(p,page.id,e.tick)
            local s=common.peek().sessions[p.index]
            check("bounded "..page.id,s.root.style.minimal_width*p.display_scale<=p.display_resolution.width and s.root.style.minimal_height*p.display_scale<=p.display_resolution.height,
                {resolution=p.display_resolution,scale=p.display_scale,width=s.root.style.minimal_width,height=s.root.style.minimal_height,nav_height=s.navigation.style.minimal_height})
            if page.id=="cameras" then
                local frame=camera.open(p,{owner="fixture",id="test",player_index=p.index,title="Fixture camera"},e.tick)
                local cam=storage.ei_camera_windows.windows[p.index..":fixture:test"].camera
                local zoom=cam.zoom;camera.on_display_changed{player_index=p.index,tick=e.tick}
                check("same camera and zoom after resize",cam==storage.ei_camera_windows.windows[p.index..":fixture:test"].camera and cam.zoom==zoom)
                check("camera bounds",frame.style.minimal_width*p.display_scale<=p.display_resolution.width and frame.style.minimal_height*p.display_scale<=p.display_resolution.height)
            end
        end
    elseif storage.step%8==3 then
        local n=math.floor(storage.step/8);local page=config.pages[n]
        if page then game.take_screenshot{player=p,path="gui/"..page.id..".png",show_gui=true,resolution=p.display_resolution} end
    end
    if storage.step==100 and common.peek().sessions[p.index].diagnostics then
        camera.close_owner("fixture",p.index)
        gui.open(p,"diagnostics",e.tick)
        gui.on_gui_click{element=find(common.peek().sessions[p.index].diagnostics.overview,"inspect"),player_index=p.index,tick=e.tick}
    elseif storage.step==104 and common.peek().sessions[p.index].diagnostics then
        game.take_screenshot{player=p,path="gui/diagnostics-detail.png",show_gui=true,resolution=p.display_resolution}
    end
    if storage.step==110 then
        helpers.write_file("responsive.json",helpers.table_to_json{checks=checks,resolution=p.display_resolution,scale=p.display_scale,version=script.active_mods.base},false)
        log("RESPONSIVE_COMPLETE")
    end
end)
