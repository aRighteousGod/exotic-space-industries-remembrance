--==============================================================================
-- ESIR FILE MAP
-- owns: administration Options drafts and native runtime-global setting controls
-- loaded_by: scripts/control/admin-tools.lua
-- cadence: explicit visible-page events; no closed-page refresh
-- forwarded_events: on_gui_change, on_gui_click
-- storage_roots: storage.ei.admin_tools.sessions
-- gui_ids: ei-admin-console
-- remote_interfaces: none
-- rebuild_on: structural GUI migration or changed field schema
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-options.md#contract
local common=require("scripts/control/admin/common")
local admin_config=require("lib/admin-tools-config")
local catalog=require("lib/runtime-options-config")
local lib=require("lib/lib")
local model={}
local context

---@class EiAdminOptionsDraft
---@field baseline table<string,boolean|number|string>
---@field changes table<string,boolean|number|string>

local function caption(key) return {"ei-runtime-options."..key} end
local function tags(action,id) return {parent_gui=admin_config.gui,action="options-"..action,field_id=id} end
local function draft_value(draft,id)
    if draft.changes[id]~=nil then return draft.changes[id] end
    return draft.baseline[id]
end
local function show_value(row,value)
    if row.field.type=="boolean" then
        if row.value.state~=(value==true) then row.value.state=value==true end
    elseif row.field.type=="enum" then
        local selected=0
        for index,allowed in ipairs(row.field.values) do if value==allowed then selected=index;break end end
        if row.value.selected_index~=selected then row.value.selected_index=selected end
    else
        local text=type(value)=="number" and string.format("%.17g",value) or tostring(value or "")
        if row.value.text~=text then row.value.text=text end
    end
end
local function update_visibility(session)
    local ui=session.options
    for group,pane in pairs(ui.groups) do pane.visible=not session.options_group or session.options_group==group end
    local ecology=not session.options_group or session.options_group:find("^ecology%-")~=nil
    local master=settings.startup["ei-terrain-evolution-enabled"]
    ui.ecology_note.visible=ecology and master and master.value==false or false
    ui.custom_note.visible=ecology and (catalog.get("ei-terrain-intensity","restrained")~="custom"
        or catalog.get("ei-terrain-performance","lean")~="custom")
end
local function update_pending(session)
    local count=0
    for _ in pairs(session.options_draft.changes) do count=count+1 end
    session.options.pending.caption={"ei-runtime-options.pending-count",count}
    session.options.apply.enabled=count>0
end

---@param ctx table Runtime setting owner and authorized administration execute callback.
function model.configure(ctx) context=ctx end

---@param session table
function model.reconcile_drafts(session)
    local old=session.map_settings_drafts and session.map_settings_drafts.global
    if not old then return end
    local snapshot=context.runtime.snapshot()
    for _,field in ipairs(snapshot.fields) do
        local id=field.id
        if old.baseline[id]~=nil or old.changes[id]~=nil then
            local draft=session.options_draft
            if not draft then draft={baseline=snapshot.values,changes={}};session.options_draft=draft end
            if draft.changes[id]==nil and old.changes[id]~=nil then
                draft.baseline[id]=old.baseline[id];draft.changes[id]=old.changes[id]
            end
            old.baseline[id]=nil;old.changes[id]=nil
            if session.map_settings then session.map_settings.signature=nil end
        end
    end
end

---@param parent LuaGuiElement
---@param session table
---@param player LuaPlayer
---@param tick MapTick
function model.build(parent,session,player,tick)
    model.reconcile_drafts(session)
    local ui={rows={},groups={}};session.options=ui
    local note=parent.add{type="label",caption=caption("note"),style="ei_admin_muted"};note.style.single_line=false
    local top=parent.add{type="flow",direction="horizontal"}
    top.add{type="label",caption=caption("category"),style="ei_admin_caption"}
    local items={caption("all")};ui.group_ids={}
    local selected=1
    for _,group in ipairs(catalog.groups) do
        items[#items+1]=caption("group-"..group);ui.group_ids[#items]=group
        if session.options_group==group then selected=#items end
    end
    ui.category=top.add{type="drop-down",items=items,selected_index=selected,tags=tags("category")}
    ui.ecology_note=parent.add{type="label",caption=caption("ecology-disabled"),style="ei_admin_muted"}
    ui.ecology_note.style.single_line=false
    ui.custom_note=parent.add{type="label",caption=caption("custom-inactive"),style="ei_admin_muted"}
    ui.custom_note.style.single_line=false
    ui.pending=parent.add{type="label",caption="",style="ei_admin_caption"}
    local buttons=parent.add{type="flow",direction="horizontal"}
    for _,action in ipairs({"apply","reload","discard"}) do
        ui[action]=buttons.add{type="button",caption=caption(action),tags=tags(action)}
    end
    ui.body=parent.add{type="flow",direction="vertical"}
    model.refresh(session,player,tick)
end

---@param session table
---@param player LuaPlayer
---@param tick MapTick
function model.refresh(session,player,tick)
    local ui=session.options
    if not ui or not ui.body.valid then return end
    local snapshot=context.runtime.snapshot()
    local selected=1
    for index,group in pairs(ui.group_ids) do if group==session.options_group then selected=index;break end end
    if ui.category.selected_index~=selected then ui.category.selected_index=selected end
    local draft=session.options_draft
    if not draft then draft={baseline=snapshot.values,changes={}};session.options_draft=draft end
    local signature={}
    for _,field in ipairs(snapshot.fields) do
        signature[#signature+1]={field.id,field.type,field.values}
        if draft.changes[field.id]==nil then draft.baseline[field.id]=snapshot.values[field.id] end
    end
    signature=serpent.line(signature)
    if ui.signature~=signature then
        ui.signature=signature;ui.body.clear();ui.rows={};ui.groups={}
        for _,group in ipairs(catalog.groups) do
            local pane=ui.body.add{type="flow",direction="vertical"};ui.groups[group]=pane
            pane.add{type="label",caption=caption("group-"..group),style="ei_admin_heading"}
        end
        for _,field in ipairs(snapshot.fields) do
            local flow=ui.groups[field.group].add{type="flow",direction="horizontal",tags={admin_layout="field"}}
            local label=flow.add{type="label",caption=field.label,tooltip=field.description,style="ei_admin_caption"}
            label.style.width=300;label.style.single_line=false
            local row={field=field};ui.rows[field.id]=row
            if field.type=="boolean" then
                row.value=flow.add{type="checkbox",caption="",state=false,tags=tags("value",field.id)}
            elseif field.type=="enum" then
                local items={}
                for _,value in ipairs(field.values) do
                    items[#items+1]={"?",{"string-mod-setting."..(field.locale_name or field.legacy or field.id).."-"..tostring(value)},tostring(value)}
                end
                row.value=flow.add{type="drop-down",items=items,selected_index=0,tags=tags("value",field.id)}
                row.value.style.width=180
            else
                row.value=flow.add{type="textfield",text="",style="ei_admin_field",tags=tags("value",field.id)}
            end
            row.value.tooltip=field.description
            show_value(row,draft_value(draft,field.id))
        end
    else
        -- Preserve edited text and its baseline; untouched controls follow native edits.
        for id,row in pairs(ui.rows) do if draft.changes[id]==nil then show_value(row,draft.baseline[id]) end end
    end
    update_visibility(session);update_pending(session)
end

---@param event table Native GUI change event with element, player_index and tick.
---@param session table
---@return boolean
function model.on_gui_change(event,session)
    local element=event.element
    local ui=session.options
    if not ui then return false end
    if element.tags.action=="options-category" then
        if element~=ui.category then return true end
        session.options_group=ui.group_ids[element.selected_index]
        update_visibility(session);return true
    end
    if element.tags.action~="options-value" then return false end
    local row=ui.rows[element.tags.field_id]
    local draft=session.options_draft
    if not row or row.value~=element or not draft then return true end
    local value
    if row.field.type=="boolean" then value=element.state
    elseif row.field.type=="enum" then value=row.field.values[element.selected_index];if value==nil then return true end
    elseif row.field.type=="string" then value=element.text
    else
        value=tonumber(element.text)
        if not lib.is_valid_number(value) then value=element.text end
    end
    if value==draft.baseline[row.field.id] then draft.changes[row.field.id]=nil else draft.changes[row.field.id]=value end
    update_pending(session)
    return true
end

---@param event EventData.on_gui_click
---@param session table
---@return boolean
function model.on_gui_click(event,session)
    local action=event.element.tags.action
    if action~="options-apply" and action~="options-reload" and action~="options-discard" then return false end
    local ui=session.options
    local draft=session.options_draft
    local operation=action:sub(9)
    if not ui or not draft or event.element~=ui[operation] then return true end
    if operation=="apply" then
        local ok=context.execute(game.get_player(event.player_index),"options_apply",
            {baseline=draft.baseline,changes=draft.changes},event.tick)
        if not ok then return true end
    end
    -- Applying the Administration switch may have destroyed this page already.
    session.options_draft=nil
    return true
end

---@param actor LuaPlayer
---@param args table
---@param tick MapTick
---@return boolean,LocalisedString
function model.execute(actor,args,tick)
    local allowed,message=common.authorize(actor)
    if not allowed then return false,message end
    if type(args.baseline)~="table" or type(args.changes)~="table" then return false,caption("invalid-request") end
    local ok,result,readback=context.runtime.apply(args.baseline,args.changes,tick)
    args.options_readback=readback
    return ok,result
end
return model
