--==============================================================================
-- ESIR FILE MAP
-- owns: ecology page drafts, inheritance and authorized owner actions
-- loaded_by: scripts/control/admin-tools.lua
-- cadence: open-page actions; no closed-panel refresh
-- forwarded_events: owner-routed callbacks only
-- storage_roots: storage.ei.admin_tools.sessions
-- gui_ids: ei_admin_gui
-- remote_interfaces: none
-- rebuild_on: owner lifecycle and configuration changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- Administrator widgets own drafts only; the ecology owner validates all changes.
local common=require("scripts/control/admin/common")
local admin_config=require("lib/admin-tools-config")
local model={}
local context,fields,by_key
local function caption(key) return {"ei-admin.ecology-"..key} end
local function tags(action) return {parent_gui=admin_config.gui,action="ecology-"..action} end
local function surface_for(session)
    if session.surface_index then return game.get_surface(session.surface_index) end
    return context.resolve_surface(session.drafts.planet,false)
end
local function choices(field)
    if field.type=="boolean" then return {false,true} end
    return field.values
end
local function value_caption(field,value)
    if type(value)=="boolean" then return {"ei-admin."..(value and "on" or "off")} end
    if field.type=="enum" then return {"string-mod-setting."..field.setting_name.."-"..value} end
    return tostring(value)
end
function model.configure(ctx)
    context=ctx;fields={};by_key={}
    for _,field in ipairs(ctx.schema) do
        if field.surface then fields[#fields+1]=field;by_key[field.key]=field end
    end
end
function model.build(parent,session,player,tick)
    local ui={};session.ecology=ui;session.ecology_drafts=session.ecology_drafts or {}
    local note=parent.add{type="label",caption=caption("note"),style="ei_admin_muted"};note.style.single_line=false
    ui.status=parent.add{type="label",caption="",style="ei_admin_caption"};ui.status.style.single_line=false
    ui.diagnostics=parent.add{type="label",caption="",style="ei_admin_muted"};ui.diagnostics.style.single_line=false
    ui.legacy=parent.add{type="label",caption=caption("gaia-legacy"),style="ei_admin_muted"};ui.legacy.style.single_line=false
    local items,selected={},1
    for i,field in ipairs(fields) do items[i]=field.label;if field.key==session.drafts.ecology_key then selected=i end end
    session.drafts.ecology_key=fields[selected].key
    ui.setting=parent.add{type="drop-down",items=items,selected_index=selected,tags=tags("setting")}
    ui.effective=parent.add{type="label",caption="",style="ei_admin_caption"}
    ui.editor=parent.add{type="flow",direction="vertical"}
    local row=parent.add{type="flow",direction="horizontal"}
    for _,action in ipairs({"apply","inherit","reset"}) do ui[action]=row.add{type="button",caption=caption(action),tags=tags(action)} end
    ui.calendar=parent.add{type="label",caption="",style="ei_admin_caption"};ui.calendar.style.single_line=false
    parent.add{type="label",caption=caption("phase"),style="ei_admin_heading"}
    ui.phase=parent.add{type="textfield",text="0",style="ei_admin_field",tags=tags("phase-value")}
    ui.set_phase=parent.add{type="button",caption=caption("set-phase"),tags=tags("set-phase")}
    model.refresh(session,player,tick)
end
function model.refresh(session,player,tick)
    local ui=session.ecology;if not ui or not ui.status.valid then return end
    local surface=surface_for(session)
    local snapshot=surface and surface.valid and context.runtime.snapshot(surface,tick)
    local available=snapshot and snapshot.effective~=nil or false
    for _,name in ipairs({"apply","inherit","reset","set_phase","phase"}) do ui[name].enabled=available end
    if not available then ui.status.caption=caption("unavailable");ui.effective.caption="";ui.calendar.caption="";ui.diagnostics.caption="";ui.legacy.visible=false;return end
    local effective=snapshot.effective
    ui.diagnostics.caption={"ei-admin.ecology-diagnostics",math.floor(snapshot.sample_age/60),math.floor(snapshot.backlog_age/60),
        snapshot.counters.saturated or 0,snapshot.counters.protected or 0,snapshot.history,snapshot.history_limit}
    ui.legacy.visible=effective.planet=="gaia"
    ui.status.caption={"ei-admin.ecology-status",surface.name,{"ei-terrain.status-"..snapshot.status},snapshot.active,snapshot.pending,snapshot.history,snapshot.tree_history}
    local c=snapshot.calendar
    ui.calendar.caption={"ei-admin.ecology-calendar",{"ei-terrain.status-"..c.status},string.format("%.4f",c.phase or 0),
        string.format("%.1f",c.reference_days or 0),string.format("%.1f",c.local_days or 0),string.format("%.1f",c.hours or 0)}
    ui.set_phase.enabled=available and c.status~="excluded"
    if ui.phase_surface~=surface.index then ui.phase.text=tostring(c.phase or 0);ui.phase_surface=surface.index end
    local field=by_key[session.drafts.ecology_key]
    local overrides=context.runtime.get_overrides(surface)
    ui.effective.caption={"ei-admin.ecology-effective",value_caption(field,effective[field.key]),caption(overrides[field.key]~=nil and "overridden" or "inherited")}
    local id=surface.index..":"..field.key
    if ui.editor_key==id then return end
    ui.editor_key=id;ui.editor.clear()
    local value=session.ecology_drafts[id];if value==nil then value=effective[field.key];session.ecology_drafts[id]=value end
    ui.values=choices(field)
    if ui.values then
        local items,selected={},1
        for i,v in ipairs(ui.values) do items[i]=value_caption(field,v);if v==value then selected=i end end
        ui.value=ui.editor.add{type="drop-down",items=items,selected_index=selected,tags=tags("value")}
    else ui.value=ui.editor.add{type="textfield",text=tostring(value),style="ei_admin_field",tags=tags("value")} end
    ui.value.tooltip={"mod-setting-description."..field.setting_name}
end
function model.on_gui_change(event,session)
    local e=event.element;local action=e.tags.action
    if action=="ecology-setting" then
        session.drafts.ecology_key=fields[e.selected_index].key;session.ecology.editor_key=nil;return true
    end
    if action=="ecology-phase-value" then return true end
    if action~="ecology-value" then return false end
    local surface=surface_for(session);if not surface then return true end
    -- False is a meaningful boolean choice; do not use an and/or value selector.
    local value
    if e.type=="drop-down" then value=session.ecology.values[e.selected_index] else value=e.text end
    session.ecology_drafts[surface.index..":"..session.drafts.ecology_key]=value
    return true
end
function model.on_gui_click(event,session)
    local actions={["ecology-apply"]="ecology_override",["ecology-inherit"]="ecology_inherit",["ecology-reset"]="ecology_reset",["ecology-set-phase"]="ecology_phase"}
    local action=actions[event.element.tags.action];if not action then return false end
    local surface=surface_for(session);if not surface then return true end
    local key=session.drafts.ecology_key
    local ok=context.execute(game.get_player(event.player_index),action,{surface_index=surface.index,key=key,
        value=session.ecology_drafts[surface.index..":"..key],phase=session.ecology.phase.text},event.tick)
    if ok and action=="ecology_inherit" then session.ecology_drafts[surface.index..":"..key]=nil;session.ecology.editor_key=nil end
    if ok and action=="ecology_reset" then session.ecology_drafts={};session.ecology.editor_key=nil end
    return true
end
function model.execute(actor,action,args,tick)
    local allowed,message=common.authorize(actor);if not allowed then return false,message end
    local surface=game.get_surface(args.surface_index)
    if not surface or not surface.valid then return false,caption("unavailable") end
    local ok
    if action=="ecology_reset" then ok,message=context.runtime.reset_overrides(surface,tick)
    elseif action=="ecology_phase" then
        local value=common.number(args.phase,0,1);if not value then return false,caption("invalid-phase") end
        ok,message=context.runtime.set_season_phase(surface,value,tick)
    else
        local field=by_key[args.key];if not field then return false,caption("invalid-setting") end
        local value=args.value
        if action=="ecology_inherit" then value=nil
        elseif field.type=="number" or field.type=="integer" then value=tonumber(value);if not value then return false,caption("invalid-number") end end
        ok,message=context.runtime.set_override(surface,field.key,value,tick)
    end
    if ok then context.changed("ecology",surface.index) end
    return ok,message
end
return model
