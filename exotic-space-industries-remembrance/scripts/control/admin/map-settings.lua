--==============================================================================
-- ESIR FILE MAP
-- owns: map-settings page drafts and authorized Apply actions
-- loaded_by: scripts/control/admin-tools.lua
-- cadence: visible page events; no closed-panel refresh
-- storage_roots: storage.ei.admin_tools.sessions
-- gui_ids: ei-admin-console
--==============================================================================
-- blueprint: .codex/esir/blueprints/map-settings.md#contract
local common = require("scripts/control/admin/common")
local config = require("lib/admin-tools-config")
local lib = require("lib/lib")
local model = {}
local context
local function caption(id) return {"ei-map-settings."..id} end
local function tags(action,id) return {parent_gui=config.gui,action="map-settings-"..action,field_id=id} end
local function target(session)
    if session.map_settings_scope == "global" then return {scope="global"} end
    return {planet=session.drafts.planet,surface_index=session.surface_index}
end
local function draft_value(draft,id)
    if draft.changes[id] ~= nil then return draft.changes[id] end
    return draft.baseline[id]
end
local function display(field,value)
    if type(value) ~= "number" then return tostring(value) end
    if field.scale then return value > 0 and 1/value or 0 end
    return value*(field.factor or 1)
end
local function parse(field,value)
    local numeric = tonumber(value)
    if not lib.is_valid_number(numeric) then return value end
    if field.scale then return numeric > 0 and 1/numeric or numeric end
    return numeric/(field.factor or 1)
end
function model.configure(ctx) context=ctx end

function model.build(parent,session,player,tick)
    session.map_settings_drafts = session.map_settings_drafts or {}
    local ui = {};session.map_settings = ui
    local top = parent.add{type="flow",direction="horizontal"}
    ui.scope = top.add{type="drop-down",items={caption("selected"),caption("global")},
        selected_index=session.map_settings_scope == "global" and 2 or 1,tags=tags("scope")}
    ui.advanced = top.add{type="checkbox",caption=caption("advanced"),state=session.map_settings_advanced == true,tags=tags("advanced")}
    ui.status = parent.add{type="label",caption="",style="ei_admin_caption"};ui.status.style.single_line=false
    ui.note = parent.add{type="label",caption=caption("note"),style="ei_admin_muted"};ui.note.style.single_line=false
    ui.pending = parent.add{type="label",caption="",style="ei_admin_caption"};ui.pending.style.single_line=false
    local buttons = parent.add{type="flow",direction="horizontal"}
    ui.apply = buttons.add{type="button",caption=caption("apply"),tags=tags("apply")}
    buttons.add{type="button",caption=caption("reload"),tags=tags("reload")}
    buttons.add{type="button",caption=caption("discard"),tags=tags("discard")}
    ui.body = parent.add{type="flow",direction="vertical"}
    model.refresh(session,player,tick)
end

local function update_rows(ui,draft)
    local count = 0
    for _ in pairs(draft.changes) do count=count+1 end
    ui.pending.caption={"ei-map-settings.pending-count",count}
    ui.apply.enabled=count>0
    for id,row in pairs(ui.rows or {}) do
        local field=row.field
        local enabled=true
        if field.kind == "control" and field.key ~= "enabled" then
            enabled=draft_value(draft,"control/"..field.control.."/enabled") ~= false
        end
        if row.edit then enabled=enabled and draft.changes[id]~=nil;row.edit.state=draft.changes[id]~=nil end
        row.value.enabled=enabled
        if row.slider then row.slider.enabled=enabled end
    end
end

function model.refresh(session,player,tick)
    local ui=session.map_settings
    if not ui or not ui.body.valid then return end
    local snapshot,error=context.runtime.snapshot(target(session))
    if not snapshot then ui.status.caption=error;ui.apply.enabled=false;ui.body.visible=false;return end
    ui.body.visible=true
    local drafts=session.map_settings_drafts
    local draft=drafts[snapshot.id]
    if not draft then
        draft={target=snapshot.target,baseline=snapshot.values,changes={},pending=snapshot.pending}
        drafts[snapshot.id]=draft
    end
    ui.id=snapshot.id
    local stale=draft.target.surface_index and draft.target.surface_index~=snapshot.target.surface_index
    ui.status.caption={snapshot.pending and "ei-map-settings.target-pending" or "ei-map-settings.target",snapshot.id}
    if stale then ui.status.caption={"",ui.status.caption,"\n",caption("stale-target")}
    elseif draft.pending and not snapshot.pending then
        ui.status.caption={"",ui.status.caption,"\n",caption("created-draft")}
        draft.baseline["$evolution_revision"]=draft.baseline["$evolution_revision"] or snapshot.values["$evolution_revision"]
        draft.target=snapshot.target
    end
    if snapshot.suppressed then ui.status.caption={"",ui.status.caption,"\n",caption("suppressed")} end
    if snapshot.armoured_shared then ui.status.caption={"",ui.status.caption,"\n",caption("armoured-shared")} end
    local signature=snapshot.id..":"..tostring(snapshot.pending)..":"..tostring(snapshot.target.surface_index)..":"..tostring(session.map_settings_advanced == true)
    if ui.signature ~= signature then
        ui.signature=signature;ui.body.clear();ui.rows={}
        local groups={}
        for _,field in ipairs(snapshot.fields) do
            if not field.advanced or session.map_settings_advanced then
                local group=groups[field.group]
                if not group then
                    group=ui.body.add{type="flow",direction="vertical"};groups[field.group]=group
                    group.add{type="label",caption=caption("group-"..field.group),style="ei_admin_heading"}
                end
                local row=group.add{type="flow",direction="horizontal"}
                local label=field.label and {"",field.label," — ",caption(field.scale and "scale" or (field.group=="cliff" and field.key=="size" and "continuity" or field.key))}
                    or caption(field.id)
                local heading=row.add{type="label",caption=label,style="ei_admin_caption"}
                heading.style.width=260;heading.style.single_line=false
                heading.tooltip=field.description
                local value=draft_value(draft,field.id)
                if value == nil then value=snapshot.values[field.id];draft.baseline[field.id]=value end
                local entry={field=field};ui.rows[field.id]=entry
                if snapshot.pending then entry.edit=row.add{type="checkbox",caption=caption("edit"),state=draft.changes[field.id]~=nil,tags=tags("edit",field.id)} end
                if field.type == "boolean" then
                    entry.value=row.add{type="checkbox",caption="",state=value==true,tags=tags("value",field.id)}
                else
                    local shown=display(field,value)
                    entry.value=row.add{type="textfield",text=type(shown)=="number" and string.format("%.10g",shown) or shown,
                        style="ei_admin_field",tags=tags("value",field.id)}
                    entry.value.style.width=100
                    if field.slider then
                        local slider_value=tonumber(shown) or 1
                        entry.slider=row.add{type="slider",minimum_value=1/6,maximum_value=6,
                            value=math.max(1/6,math.min(6,slider_value)),value_step=0.01,tags=tags("slider",field.id)}
                        entry.slider.style.width=140
                    end
                end
            end
        end
    end
    update_rows(ui,draft)
    if stale then ui.apply.enabled=false end
end

function model.on_gui_change(event,session)
    local element=event.element
    local action=element.tags.action
    if action=="map-settings-scope" then session.map_settings_scope=element.selected_index==2 and "global" or "surface";return true end
    if action=="map-settings-advanced" then session.map_settings_advanced=element.state;return true end
    if action~="map-settings-value" and action~="map-settings-slider" and action~="map-settings-edit" then return false end
    local ui=session.map_settings
    local draft=ui and session.map_settings_drafts[ui.id]
    local row=ui and ui.rows[element.tags.field_id]
    if not draft or not row then return true end
    if action=="map-settings-edit" then
        if element.state then draft.changes[row.field.id]=draft.baseline[row.field.id] else draft.changes[row.field.id]=nil end
        local value=draft_value(draft,row.field.id)
        if row.field.type=="boolean" then row.value.state=value==true
        else
            local shown=display(row.field,value)
            row.value.text=type(shown)=="number" and string.format("%.10g",shown) or shown
            if row.slider and type(shown)=="number" then row.slider.slider_value=math.max(1/6,math.min(6,shown)) end
        end
        update_rows(ui,draft);return true
    end
    local value
    if row.field.type=="boolean" then value=element.state
    else
        local input=action=="map-settings-slider" and element.slider_value or element.text
        value=parse(row.field,input)
        if action=="map-settings-slider" then row.value.text=string.format("%.10g",input)
        elseif row.slider and tonumber(input) and tonumber(input)>=1/6 and tonumber(input)<=6 then row.slider.slider_value=tonumber(input) end
    end
    local id=row.field.id
    if value==draft.baseline[id] and not row.edit then draft.changes[id]=nil else draft.changes[id]=value end
    update_rows(ui,draft)
    return true
end

function model.on_gui_click(event,session)
    local action=event.element.tags.action
    if action~="map-settings-apply" and action~="map-settings-reload" and action~="map-settings-discard" then return false end
    local ui=session.map_settings
    local draft=ui and session.map_settings_drafts[ui.id]
    if not draft then return true end
    if action=="map-settings-apply" then
        local ok=context.execute(game.get_player(event.player_index),"map_settings_apply",
            {target=draft.target,baseline=draft.baseline,changes=draft.changes},event.tick)
        if not ok then return true end
    end
    session.map_settings_drafts[ui.id]=nil;ui.signature=nil
    return true
end

function model.execute(actor,action,args,tick)
    local allowed,message=common.authorize(actor)
    if not allowed then return false,message end
    if action~="map_settings_apply" or type(args.target)~="table" or type(args.baseline)~="table" or type(args.changes)~="table" then
        return false,caption("invalid-request")
    end
    local ok,result,readback=context.runtime.apply(args.target,args.baseline,args.changes,tick)
    args.map_settings_readback=readback
    if ok then context.changed("planet",args.target.surface_index) end
    return ok,result
end
return model
