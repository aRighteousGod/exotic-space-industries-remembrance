--==============================================================================
-- ESIR FILE MAP
-- owns: all-player rebuild activity presentation and per-player dismissal
-- loaded_by: control.lua, scripts/control/admin/gui.lua
-- cadence: due-guarded from control.lua; eight viewers/tick, captions once/60 ticks
-- forwarded_events: configure, activity_caption, watch_player, on_player_event, on_configuration_changed, on_player_left_game, on_player_removed, on_display_changed, on_gui_click, has_tick_work, updater
-- storage_roots: storage.ei.rebuild_monitor
-- gui_ids: ei-rebuild-monitor, ei-rebuild-monitor-button
-- remote_interfaces: none
-- rebuild_on: configuration change reconciles presentation only
--==============================================================================
-- blueprint: .codex/esir/blueprints/rebuild-monitor.md#contract
local scheduler=require("lib/runtime-scheduler")
local mod_gui=require("__core__.lualib.mod-gui")
local model={}
local GUI="ei-rebuild-monitor"
local BUTTON="ei-rebuild-monitor-button"
local callbacks={}

---@class EiRebuildCallbacks
---@field admin_viewer? fun(index:uint):boolean
---@field admin_viewers? fun():boolean
---@field admin_refresh? fun(index:uint,tick:MapTick,snapshot:EiRebuildSnapshot):boolean

---@class EiRebuildViewer
---@field root LuaGuiElement|nil
---@field button LuaGuiElement|nil
---@field scroll LuaGuiElement|nil
---@field rows table<integer, table>|nil
---@field location GuiLocation|nil
---@field dismissed integer|nil
---@field auto_episode integer|nil
---@field last_tick MapTick|nil
---@field last_transition integer|nil
---@field tooltip_signature string|nil
---@class EiRebuildPresentation
---@field players table<uint, EiRebuildViewer>
---@field queue table
---@field transition integer
---@field snapshot EiRebuildSnapshot|nil
---@field next_cycle MapTick|nil
---@field next_due MapTick|nil
---@field auto_episode integer|nil
---@field auto_tick MapTick|nil

---@return EiRebuildPresentation|nil
local function peek() return storage.ei and storage.ei.rebuild_monitor end
---@return EiRebuildPresentation
local function state()
    storage.ei=storage.ei or {}
    storage.ei.rebuild_monitor=storage.ei.rebuild_monitor or {players={},queue=scheduler.ensure_queue(),transition=-1}
    return storage.ei.rebuild_monitor
end
local function public(record) return not record.synchronous and (record.state=="running" or record.state=="queued") end
local function text(key,...) return {"ei-rebuild."..key,...} end
local function token(kind,value) return {"?",text(kind.."-"..tostring(value)),tostring(value or "")} end
local function duration(ticks) return text("duration",math.ceil(math.max(0,ticks or 0)/60)) end
local function remaining(record)
    if record.outcome then
        return record.synchronous and {"",token("outcome",record.outcome)," · ",text("synchronous")} or token("outcome",record.outcome)
    end
    if record.synchronous then return text("synchronous") end
    if record.state=="waiting" then return text("waiting",token("reason",record.waiting_reason or "external")) end
    if record.eta_ticks then return text("eta",duration(record.eta_ticks)) end
    if not record.total and (record.phase=="world" or record.phase=="discovering" or record.phase=="attribution") then return text("discovering") end
    return text("estimating")
end
local function work(record)
    if record.total then return text("work-total",record.completed,record.total,token("unit",record.unit or "items")) end
    return text("work",record.completed,token("unit",record.unit or "items"))
end
local function joined(lines)
    while #lines>16 do
        local groups={}
        for first=1,#lines,16 do
            local group={""}
            for i=first,math.min(#lines,first+15) do group[#group+1]=lines[i] end
            groups[#groups+1]=group
        end
        lines=groups
    end
    local result={""};for _,line in ipairs(lines) do result[#result+1]=line end
    return result
end

---Pure formatter shared with the administrator's scalar-only Diagnostics page.
---@param snapshot EiRebuildSnapshot
---@param include_history boolean
---@return LocalisedString
function model.activity_caption(snapshot,include_history)
    local lines={text("active-heading"),"\n"}
    local function append(record)
        lines[#lines+1]=text("admin-row",token("owner",record.owner),token("phase",record.phase),work(record),remaining(record),
            token("reason",record.reason),record.synchronous and text("synchronous") or duration((record.end_tick or snapshot.snapshot_tick)-record.start_tick),
            tostring(record.force_index or "-"),tostring(record.surface_index or "-"),tostring(record.scope),tostring(record.operation))
        lines[#lines+1]="\n"
    end
    for _,record in ipairs(snapshot.active) do append(record) end
    if #snapshot.active==0 then lines[#lines+1]=text("none");lines[#lines+1]="\n" end
    if include_history then
        lines[#lines+1]=text("history-heading");lines[#lines+1]="\n"
        for _,record in ipairs(snapshot.history) do append(record) end
        if #snapshot.history==0 then lines[#lines+1]=text("none") end
    end
    return joined(lines)
end

---@param options EiRebuildCallbacks
function model.configure(options) callbacks=options end

local function close(entry)
    if entry.root and entry.root.valid then entry.location=entry.root.location;entry.root.destroy() end
    entry.root=nil;entry.rows=nil
end
local function hide(entry)
    close(entry)
    if entry.button and entry.button.valid then entry.button.destroy() end
    entry.button=nil;entry.tooltip_signature=nil
end
local function resize(player,entry)
    if not(entry.root and entry.root.valid) then return end
    local scale=player.display_scale;local resolution=player.display_resolution
    local width=math.max(180,math.min(380,math.floor(resolution.width/scale)-16))
    local height=math.max(80,math.min(484,math.floor(resolution.height/scale)-100))
    entry.root.style.width=width
    entry.scroll.style.maximal_height=height-56
    local location=entry.root.location or entry.location or {x=12*scale,y=70*scale}
    entry.root.location={x=math.max(0,math.min(location.x,resolution.width-width*scale)),
        y=math.max(0,math.min(location.y,resolution.height-(height+16)*scale))}
    entry.location=entry.root.location
end
local function open(player,entry)
    if entry.root and entry.root.valid then return end
    local old=player.gui.screen[GUI];if old then old.destroy() end
    local frame=player.gui.screen.add{type="frame",name=GUI,direction="vertical",tags={parent_gui=GUI}}
    frame.style.padding=8
    local title=frame.add{type="flow",direction="horizontal"}
    title.add{type="label",caption=text("title"),style="frame_title"}
    local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"};spacer.drag_target=frame
    title.add{type="sprite-button",sprite="utility/close",style="frame_action_button",tooltip=text("close"),tags={parent_gui=GUI,action="close"}}
    entry.root=frame;entry.rows={}
    entry.scroll=frame.add{type="scroll-pane",direction="vertical"}
    entry.scroll.horizontal_scroll_policy="never";entry.scroll.vertical_scroll_policy="auto-and-reserve-space"
    frame.location=entry.location or {x=12*player.display_scale,y=70*player.display_scale}
    resize(player,entry)
    -- Intentionally never assign player.opened or focus: this window is passive.
end
local function refresh_rows(entry,snapshot)
    local seen={}
    for _,record in ipairs(snapshot.active) do if public(record) then
        seen[record.id]=true
        local row=entry.rows[record.id]
        if not row then
            local frame=entry.scroll.add{type="frame",direction="vertical",style="inside_shallow_frame"}
            frame.style.padding=6;frame.style.horizontally_stretchable=true
            frame.style.height=104
            local content=frame.add{type="flow",direction="vertical"}
            content.style.vertical_spacing=2;content.style.horizontally_stretchable=true
            local name=content.add{type="label"};name.style.single_line=false
            local status=content.add{type="label"};status.style.single_line=false
            local progress=content.add{type="progressbar",value=0};progress.style.horizontally_stretchable=true
            local eta=content.add{type="label",tooltip=text("time-tooltip")};eta.style.single_line=false
            row={root=frame,name=name,status=status,progress=progress,eta=eta};entry.rows[record.id]=row
        end
        local signature=table.concat({record.owner,record.phase,record.completed,record.total or "?",record.unit or "items",record.state,record.eta_ticks or "?"},"|")
        if row.signature~=signature then
            row.name.caption=token("owner",record.owner)
            row.status.caption=text("phase-work",token("phase",record.phase),work(record))
            row.progress.visible=record.total~=nil
            if record.total then row.progress.value=record.total>0 and math.min(1,record.completed/record.total) or 1 end
            row.eta.caption=remaining(record);row.signature=signature
        end
    end end
    for id,row in pairs(entry.rows) do if not seen[id] then row.root.destroy();entry.rows[id]=nil end end
end

local function viewer(player,root,snapshot,tick)
    local entry=root.players[player.index] or {};root.players[player.index]=entry
    local refresh_due=not entry.last_tick or tick-entry.last_tick>=60
    if snapshot.public_count>0 then
        if not(entry.button and entry.button.valid) then
            local flow=mod_gui.get_button_flow(player)
            entry.button=flow[BUTTON] or flow.add{type="sprite-button",name=BUTTON,sprite="utility/refresh",style=mod_gui.button_style,
                tags={parent_gui=GUI,action="toggle"}}
        end
        local names={text("title"),"\n"}
        for _,record in ipairs(snapshot.active) do if public(record) then names[#names+1]=token("owner",record.owner);names[#names+1]="\n" end end
        local tooltip=joined(names);local signature=serpent.line(tooltip)
        if entry.tooltip_signature~=signature then entry.button.tooltip=tooltip;entry.tooltip_signature=signature end
        local had_window=entry.root and entry.root.valid
        if tick-(snapshot.episode_started_tick or tick)>=120 then
            if entry.dismissed~=snapshot.episode then open(player,entry) end
            entry.auto_episode=snapshot.episode
        end
        if entry.root and entry.root.valid and (refresh_due or not had_window) then refresh_rows(entry,snapshot) end
    else hide(entry) end
    if refresh_due and callbacks.admin_viewer and callbacks.admin_viewer(player.index) then callbacks.admin_refresh(player.index,tick,snapshot) end
    if refresh_due then entry.last_tick=tick end
    entry.last_transition=root.transition
    if snapshot.public_count>0 or (callbacks.admin_viewer and callbacks.admin_viewer(player.index) and #snapshot.active>0) then
        root.next_cycle=math.min(root.next_cycle or tick+60,tick+60)
    end
end

---Event-owned wakeup; no connected-player enumeration on an idle tick.
function model.watch_player(index,tick)
    local root=state();scheduler.queue_push_unique(root.queue,index)
    root.snapshot=nil
    root.next_due=math.min(root.next_due or tick,tick)
end
function model.on_player_event(event) model.watch_player(event.player_index,event.tick or game.tick) end
function model.on_configuration_changed(tick)
    local root=state();root.transition=-1
    for _,player in pairs(game.connected_players) do model.watch_player(player.index,tick) end
end
function model.on_player_left_game(event)
    local root=peek();local entry=root and root.players[event.player_index]
    if entry then hide(entry) end
end
function model.on_player_removed(event)
    model.on_player_left_game(event)
    local root=peek();if root then root.players[event.player_index]=nil end
end
function model.on_display_changed(event)
    local root=peek();local entry=root and root.players[event.player_index]
    local player=game.get_player(event.player_index)
    if player and entry then resize(player,entry) end
end
function model.on_gui_click(event)
    local element=event.element
    if not(element and element.valid and element.tags.parent_gui==GUI) then return false end
    local action=element.tags.action
    if action~="close" and action~="toggle" then return false end
    local root=state();local entry=root.players[event.player_index]
    local player=game.get_player(event.player_index);local activity=scheduler.peek_rebuild_state()
    if not(entry and player and activity) then return true end
    if action=="close" or (entry.root and entry.root.valid) then
        entry.dismissed=activity.episode;close(entry)
    elseif activity.public_count>0 then
        open(player,entry);refresh_rows(entry,scheduler.peek_rebuilds(event.tick))
    end
    return true
end
function model.has_tick_work(tick)
    local root=peek();local activity=scheduler.peek_rebuild_state()
    return (activity and (not root or root.transition~=activity.transition_revision))
        or (root and root.next_due and tick>=root.next_due) or false
end
function model.updater(event)
    local tick=event.tick;local root=state();local activity=scheduler.peek_rebuild_state()
    local transition=activity and activity.transition_revision or 0
    if activity and activity.public_count>0 and root.auto_episode~=activity.episode then
        root.auto_episode=activity.episode;root.auto_tick=activity.episode_started_tick+120
    elseif not activity or activity.public_count==0 then root.auto_tick=nil end
    local auto_open_due=root.auto_tick and tick>=root.auto_tick
    if auto_open_due then root.auto_tick=nil end
    if root.transition~=transition or auto_open_due or (root.next_cycle and tick>=root.next_cycle) then
        root.transition=transition;root.snapshot=scheduler.peek_rebuilds(tick)
        local watch=false
        for _,player in pairs(game.connected_players) do
            local admin=callbacks.admin_viewer and callbacks.admin_viewer(player.index)
            if root.snapshot.public_count>0 or admin or (root.players[player.index] and root.players[player.index].button) then
                scheduler.queue_push_unique(root.queue,player.index)
            end
            if root.snapshot.public_count>0 or (admin and #root.snapshot.active>0) then watch=true end
        end
        root.next_cycle=watch and tick+60 or nil
    end
    local snapshot=root.snapshot
    if not snapshot or snapshot.snapshot_tick<tick then snapshot=scheduler.peek_rebuilds(tick);root.snapshot=snapshot end
    local served=0;local deferred={};local examined=0;local deferred_tick
    while examined<8 do
        local index=scheduler.queue_pop_queued(root.queue);if not index then break end
        examined=examined+1
        local player=game.get_player(index);local entry=root.players[index]
        if player and player.valid and player.connected then
            local popup_due=snapshot.public_count>0 and tick-(snapshot.episode_started_tick or tick)>=120
                and (not entry or entry.auto_episode~=snapshot.episode)
            if not popup_due and entry and entry.last_transition==root.transition and entry.last_tick and tick-entry.last_tick<60 then
                deferred[#deferred+1]=index;deferred_tick=math.min(deferred_tick or entry.last_tick+60,entry.last_tick+60)
            else
                viewer(player,root,snapshot,tick);served=served+1
                entry=root.players[index]
                if entry.last_tick~=tick and (snapshot.public_count>0 or (callbacks.admin_viewer and callbacks.admin_viewer(index))) then
                    deferred[#deferred+1]=index;deferred_tick=math.min(deferred_tick or entry.last_tick+60,entry.last_tick+60)
                end
            end
        end
    end
    local pending=scheduler.queue_length(root.queue)>0
    for _,index in ipairs(deferred) do scheduler.queue_push_unique(root.queue,index) end
    root.next_due=pending and tick+1 or deferred_tick
    if root.next_cycle then root.next_due=math.min(root.next_due or root.next_cycle,root.next_cycle) end
    if root.auto_tick then root.next_due=math.min(root.next_due or root.auto_tick,root.auto_tick) end
end

return model
