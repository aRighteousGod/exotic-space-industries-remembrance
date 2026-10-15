--==============================================================================
-- ESIR FILE MAP
-- owns: current-surface Simple, Advanced and Alerts ecology window
-- loaded_by: control.lua
-- cadence: lifecycle/season buttons; one open viewer per 16 ticks, eight rows per refresh
-- forwarded_events: GUI and player lifecycle through control.lua
-- storage_roots: storage.ei.ecology_gui
-- gui_ids: ei-ecology
-- remote_interfaces: none
-- rebuild_on: configuration and player lifecycle
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local mod_gui=require("__core__/lualib/mod-gui")
local preferences=require("lib/terrain-alert-config")
local terrain_config=require("lib/terrain-evolution-config")
local model={}
---@alias EsirEcologyGuiAction "window"|"open"|"close"|"admin"|"page"|"tab"|"preference"|"all-surfaces"|"surface"
---@class EsirEcologyGuiTags
---@field parent_gui "ei-ecology"
---@field action EsirEcologyGuiAction
---@field key string?
---@field surface string? Exact surface name in the personal selection.
---@field delta integer?

---@class EsirEcologyGuiRow
---@field element LuaGuiElement
---@field key string
---@field signature string?

---@class EsirEcologyGuiSession
---@field tab integer 1=Simple, 2=Advanced, 3=Alerts.
---@field location GuiLocation?
---@field frame LuaGuiElement? Nil after close.
---@field pane LuaGuiElement?
---@field loading LuaGuiElement?
---@field bodies LuaGuiElement[]? Handles can become invalid after close.
---@field rows table<integer, EsirEcologyGuiRow[]>? Simple/Advanced rows; nil after close.
---@field checks table<string, LuaGuiElement>?
---@field all_surfaces LuaGuiElement?
---@field surface_body LuaGuiElement?
---@field surface_page integer?
---@field surface_epoch integer?
---@field surface_selection string? Canonical preference used by the visible surface page.
---@field surface LuaSurface?
---@field pending_surface LuaSurface?
---@field row_cursor integer?
---@field next_tick MapTick?
---@field clearing boolean?
---@field clear_tab integer?
---@field clear_row integer?
---@field button LuaGuiElement?
---@field button_season integer? Zero denotes an unavailable calendar.

---@class EsirEcologyGuiState
---@field players table<PlayerIndex, EsirEcologyGuiSession>
---@field viewers PlayerIndex[]
---@field indexes table<PlayerIndex, integer> Dense viewer indices.
---@field cursor integer
---@field next_tick MapTick
---@field surface_names string[]? Rebuilt by lifecycle events.
---@field surface_known table<string, boolean>?
---@field surface_epoch integer?
---@field launchers PlayerIndex[]? Connected players with an enabled launcher.
---@field launcher_indexes table<PlayerIndex, integer>?
---@field launcher_cursor integer?
---@field launcher_next_tick MapTick?

---@class EsirEcologyAlertPreferencesApi
---@field preferences fun(player: LuaPlayer): EsirEcologyPreferences
---@field set_preference fun(player: LuaPlayer, key: string, value: boolean|string): boolean
---@class EsirEcologyReportApi
---@field public_snapshot fun(surface: LuaSurface, tick: MapTick): SurfaceEcologyReport
---@field season_index fun(surface: LuaSurface, tick: MapTick): integer
---@class EsirEcologyGuiContext
---@field alerts EsirEcologyAlertPreferencesApi
---@field terrain EsirEcologyReportApi
---@field open_admin fun(player: LuaPlayer, tick: MapTick)
---@type EsirEcologyGuiContext
local owners={}
local GUI="ei-ecology"
local BUTTON="ei-ecology-button"
---@return EsirEcologyGuiState?
local function peek() return storage.ei and storage.ei.ecology_gui end
---@return EsirEcologyGuiState
local function state()
    storage.ei=storage.ei or {};storage.ei.ecology_gui=storage.ei.ecology_gui or {players={},viewers={},indexes={},cursor=0,next_tick=0}
    return storage.ei.ecology_gui
end
---@param context EsirEcologyGuiContext
function model.configure(context) owners=context end
---@param action EsirEcologyGuiAction
---@param extra table?
---@return EsirEcologyGuiTags
local function tags(action,extra)
    local t={parent_gui=GUI,action=action};for k,v in pairs(extra or {}) do t[k]=v end;return t
end
local function belongs(event)
    return event.element and event.element.valid and event.element.tags.parent_gui==GUI
end
local function remove_viewer(root,index)
    local slot=root.indexes[index];if not slot then return end
    local last=root.viewers[#root.viewers];root.viewers[slot]=last;root.viewers[#root.viewers]=nil;root.indexes[index]=nil
    if last~=index then root.indexes[last]=slot end
end
local function close(player)
    local root=state();local p=root.players[player.index]
    if p and p.frame and p.frame.valid then p.location=p.frame.location;p.frame.destroy();p.frame=nil;p.rows=nil end
    remove_viewer(root,player.index)
end
local function remove_launcher(root,index)
    local slot=root.launcher_indexes and root.launcher_indexes[index];if not slot then return end
    local last=root.launchers[#root.launchers];root.launchers[slot]=last;root.launchers[#root.launchers]=nil;root.launcher_indexes[index]=nil
    if last~=index then root.launcher_indexes[last]=slot end
end
local seasonal_sprites={[0]="ei-ecology-tree-summer","ei-ecology-tree-spring","ei-ecology-tree-summer","ei-ecology-tree-autumn","ei-ecology-tree-winter"}
local function refresh_button(player,p,tick)
    local element=p.button;if not element or not element.valid then return end
    local season=owners.terrain.season_index(player.surface,tick)
    if p.button_season~=season then
        element.sprite=seasonal_sprites[season]
        element.tooltip={"",{"ei-ecology.title"}," — ",{"ei-ecology.season-"..season}}
        p.button_season=season
    end
end
local function button(player,tick)
    local root=state();root.launchers=root.launchers or {};root.launcher_indexes=root.launcher_indexes or {}
    local flow=mod_gui.get_button_flow(player);local existing=flow[BUTTON]
    if settings.startup["ei-terrain-evolution-enabled"].value then
        -- Replace the pre-season text button when adopting an existing save.
        if existing and existing.type~="sprite-button" then existing.destroy();existing=nil end
        local p=root.players[player.index] or {tab=1};root.players[player.index]=p
        if not existing then
            existing=flow.add{type="sprite-button",name=BUTTON,sprite=seasonal_sprites[0],style=mod_gui.button_style,tags=tags("open")}
            p.button_season=nil
        end
        p.button=existing;refresh_button(player,p,tick)
        if player.connected and not root.launcher_indexes[player.index] then
            root.launchers[#root.launchers+1]=player.index;root.launcher_indexes[player.index]=#root.launchers
        end
    else
        remove_launcher(root,player.index)
        if existing then existing.destroy();close(player) end
    end
end
local function label(flow,key)
    local element=flow.add{type="label",caption=""};element.style.single_line=false;element.style.maximal_width=610
    return {element=element,key=key}
end
function model.on_surface_event()
    local root=state();root.surface_names={};root.surface_known={}
    for _,surface in pairs(game.surfaces) do root.surface_names[#root.surface_names+1]=surface.name;root.surface_known[surface.name]=true end
    table.sort(root.surface_names);root.surface_epoch=(root.surface_epoch or 0)+1
end
local function surfaces_page(player,p)
    local body=p.surface_body;if not body or not body.valid then return end
    body.clear()
    local root=state();if not root.surface_names then model.on_surface_event() end
    local prefs=owners.alerts.preferences(player);local names,known=root.surface_names,root.surface_known
    local missing={};for name in pairs(prefs.selected or {}) do if not known[name] then missing[#missing+1]=name end end;table.sort(missing)
    local count=#names+#missing
    p.surface_page=math.max(1,math.min(p.surface_page or 1,math.max(1,math.ceil(count/8))));p.surface_epoch=root.surface_epoch
    p.surface_selection=prefs.surfaces
    for i=(p.surface_page-1)*8+1,math.min(count,p.surface_page*8) do
        local name=names[i] or missing[i-#names]
        body.add{type="checkbox",state=prefs.surfaces=="all" or prefs.selected[name]==true,
            caption=known[name] and name or {"ei-ecology.missing-surface",name},tags=tags("surface",{surface=name})}
    end
    local nav=body.add{type="flow",direction="horizontal"}
    nav.add{type="button",caption="<",tags=tags("page",{delta=-1})}
    nav.add{type="label",caption=p.surface_page.." / "..math.max(1,math.ceil(count/8))}
    nav.add{type="button",caption=">",tags=tags("page",{delta=1})}
end
local function build_alerts(player,p,body)
    local prefs=owners.alerts.preferences(player)
    local note=body.add{type="label",caption={"ei-ecology.alert-note"}};note.style.single_line=false;note.style.maximal_width=600
    p.checks={}
    for _,row in ipairs(preferences.schema) do
        if row.type=="bool-setting" then
            local check=body.add{type="checkbox",state=prefs[row.key],caption={"mod-setting-name."..row.name},
                tooltip={"mod-setting-description."..row.name},tags=tags("preference",{key=row.key})}
            check.enabled=row.key~="allow-unrevealed" or player.admin;p.checks[row.key]=check
        end
    end
    body.add{type="line"}
    p.all_surfaces=body.add{type="checkbox",state=prefs.surfaces=="all",caption={"ei-ecology.all-surfaces"},tags=tags("all-surfaces")}
    p.surface_body=body.add{type="flow",direction="vertical"};surfaces_page(player,p)
end
local function open(player,tick)
    local root=state();local old=root.players[player.index] or {tab=1};close(player)
    root.players[player.index]=old;local p=old
    local frame=player.gui.screen.add{type="frame",name=GUI,direction="vertical",tags=tags("window")}
    p.frame=frame;p.rows={};p.bodies={};p.row_cursor=0;p.next_tick=tick;p.surface=player.surface;p.clearing=nil
    local width=math.max(240,math.min(670,math.floor(player.display_resolution.width/player.display_scale)-24))
    local height=math.max(100,math.min(510,math.floor(player.display_resolution.height/player.display_scale)-140))
    frame.style.width=width
    local title=frame.add{type="flow",direction="horizontal"}
    title.add{type="label",caption={"ei-ecology.title"},style="frame_title",ignored_by_interaction=true}
    local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"};spacer.drag_target=frame
    title.add{type="sprite-button",sprite="utility/close",style="frame_action_button",tags=tags("close")}
    p.loading=frame.add{type="label",caption={"ei-ecology.updating"}};p.loading.visible=false
    local pane=frame.add{type="tabbed-pane",tags=tags("tab")};p.pane=pane
    for i,name in ipairs({"simple","advanced","alerts"}) do
        local tab=pane.add{type="tab",caption={"ei-ecology.tab-"..name}}
        local scroll=pane.add{type="scroll-pane",direction="vertical"};scroll.style.height=height;scroll.style.width=width-30;p.bodies[i]=scroll
        pane.add_tab(tab,scroll)
        if i==1 then
            p.rows[1]={}
            for _,key in ipairs({"surface","condition","damage","recovery","woodland","mining","season","survey"}) do p.rows[1][#p.rows[1]+1]=label(scroll,key) end
        elseif i==2 then
            p.rows[2]={}
            for _,key in ipairs({"surface","status","pollution","sample-age","coverage","drills","surface-work","exposure","protections","daylight","recent","latency","global","histories","observations","service","saturation","incomplete","maintenance"}) do p.rows[2][#p.rows[2]+1]=label(scroll,key) end
            for _,category in ipairs(preferences.categories) do p.rows[2][#p.rows[2]+1]=label(scroll,"effect:"..category) end
            for _,row in ipairs(terrain_config.schema) do p.rows[2][#p.rows[2]+1]=label(scroll,"setting:"..row.key) end
            if player.admin then scroll.add{type="button",caption={"ei-ecology.admin"},tags=tags("admin")} end
        else build_alerts(player,p,scroll) end
    end
    pane.selected_tab_index=p.tab or 1
    if p.location then frame.location={x=math.max(0,math.min(p.location.x,player.display_resolution.width-width*player.display_scale)),y=math.max(0,math.min(p.location.y,player.display_resolution.height-(height+120)*player.display_scale))}
    else frame.location={x=math.max(0,(player.display_resolution.width-width*player.display_scale)/2),y=math.max(0,(player.display_resolution.height-(height+120)*player.display_scale)/2)} end
    player.opened=frame
    root.viewers[#root.viewers+1]=player.index;root.indexes[player.index]=#root.viewers
end
local function row_value(key,report,surface,simple)
    local effects=report.effects or {};local g=report.global or {}
    if key=="surface" then return {"ei-ecology.surface",surface.name},surface.name end
    if simple then
        if key=="woodland" then
            local stressed,recovered,grown=effects["tree-stress"] or 0,effects["tree-recovery"] or 0,effects.regrowth or 0
            return {"ei-ecology.simple-woodland",stressed,recovered,grown},stressed..":"..recovered..":"..grown
        end
        local values={damage=(effects.pollution or 0)+(effects.thermal or 0),recovery=(effects.restoration or 0)+(effects["mining-restoration"] or 0),
            woodland=(effects.regrowth or 0),mining=(effects["depletion-scars"] or 0)+(effects["working-scars"] or 0)}
        if values[key] then return {"ei-ecology.simple-"..key,values[key]},tostring(values[key]) end
        if key=="condition" then local status=report.status=="disabled" and "paused" or report.sample_age and (report.sample_age>1200 and "outdated" or "observed") or "unknown";return {"ei-ecology.simple-"..status},status end
        if key=="season" then local phase=report.calendar and report.calendar.phase;local season=phase and math.floor(phase*4)+1 or 0;return {"ei-ecology.simple-season",{"ei-ecology.season-"..season}},tostring(season) end
        if key=="survey" then local value=report.sample_age and math.floor(report.sample_age/60);return value and {"ei-ecology.simple-survey",value} or {"ei-ecology.simple-unknown"},tostring(value) end
    else
        local cfg=report.effective or {}
        if key:sub(1,7)=="effect:" then local category=key:sub(8);return {"",{"ei-ecology.category-"..category},": ",effects[category] or 0},tostring(effects[category] or 0) end
        if key:sub(1,8)=="setting:" then
            local name=key:sub(9);local row=terrain_config.by_key[name];local value=cfg[name]
            if value==nil then return {"",row.label,": ",{"ei-ecology.unknown"}},"unavailable" end
            local display=row.type=="boolean" and {value and "ei-admin.on" or "ei-admin.off"} or row.type=="enum" and {"string-mod-setting."..row.setting_name.."-"..tostring(value)} or tostring(value)
            return {"",row.label,": ",display},tostring(value)
        end
        local counts=report.counts or {}
        local values={status={"ei-terrain.status-"..report.status},pollution=report.sample_age and (report.pollution_supported and tostring(report.pollution) or {"ei-ecology.unsupported-pollution"}) or {"ei-ecology.unknown"},
            ["sample-age"]=report.sample_age or "—",coverage={"ei-ecology.coverage-"..(report.coverage or "unknown")},drills=report.drills or 0,
            ["surface-work"]=(counts.active or 0).." / "..(counts.pending or 0).." / "..(counts.history or 0).." / "..(counts.trees or 0),
            exposure=(report.dirty_age or 0).." / "..(report.clean_age or 0),protections=report.protection_skips or 0,
            daylight={"ei-terrain.status-"..(report.calendar and report.calendar.status or "excluded")},
            recent=report.last_effect and {"ei-ecology.category-"..report.last_effect} or {"ei-ecology.none"},latency=report.last_pending_age or "—",
            global=(g.active or 0).." / "..(g.pending or 0).." / "..(g.drills or 0),
            histories=(g.history or 0).." / "..(cfg.tile_history_cap or 0).."; "..(g.tree_history or 0).." / "..(cfg.tree_history_cap or 0),observations=g.observations or 0}
        if key=="service" then local s=g.last_service or {};values[key]=(s.candidates or 0).." / "..(s.searches or 0).." / "..(s.writes or 0).." / "..(s.events or 0) end
        if key=="saturation" then local c=g.counters or {};values[key]=(c.saturated or 0).." / "..(c.history_full or 0).." / "..(c.protected or 0) end
        if key=="incomplete" then local c=g.counters or {};values[key]=(c.tree_replacement_failed or 0).." / "..(c.wildfire_creation_failed or 0).." / "..(c.occupancy_limited or 0) end
        if key=="maintenance" then
            local text={""};for _,job in ipairs(g.jobs or {}) do
                local phase=job.state=="waiting" and {"ei-rebuild.waiting",{"ei-rebuild.reason-surface-disabled"}} or {"ei-rebuild.phase-"..job.phase}
                text[#text+1]={"",{"ei-ecology.operation-"..job.operation},": ",phase," ",job.completed,"/",tostring(job.total or "?"),"  "}
            end
            values[key]=#text>1 and text or {"ei-ecology.none"}
        end
        local value=values[key] or "—"
        return {"ei-ecology.advanced-"..key,value},type(value)=="table" and helpers.table_to_json(value) or tostring(value)
    end
    return "",""
end
---@param tick MapTick
function model.initialize(tick)
    local root=state()
    root.launchers={};root.launcher_indexes={};root.launcher_cursor=0;root.launcher_next_tick=tick
    model.on_surface_event()
    for _,player in pairs(game.players) do
        local p=root.players[player.index];local was_open=p and p.frame and p.frame.valid
        if was_open then close(player) end
        button(player,tick)
        if was_open and player.connected and settings.startup["ei-terrain-evolution-enabled"].value then open(player,tick) end
    end
end
---@param event EventData.on_player_display_resolution_changed|EventData.on_player_display_scale_changed
function model.on_display_changed(event)
    local player=game.get_player(event.player_index);local root=peek();local p=root and root.players[event.player_index]
    if player and p and p.frame and p.frame.valid then open(player,event.tick) end
end
---@param event EsirEcologyPlayerEvent
function model.on_player_event(event)
    local player=game.get_player(event.player_index)
    if player then
        button(player,event.tick)
        local root=peek();local p=root and root.players[player.index]
        if p and p.frame and p.frame.valid then
            if p.checks and p.checks["allow-unrevealed"] then
                local check=p.checks["allow-unrevealed"]
                check.enabled=player.admin;check.state=owners.alerts.preferences(player)["allow-unrevealed"]
            end
            if p.surface~=player.surface then p.pending_surface=player.surface;p.row_cursor=0;p.clearing=true;p.clear_tab=1;p.clear_row=0;p.next_tick=event.tick end
        end
    end
end
---@param event EventData.on_player_left_game
function model.on_player_left(event)
    local player=game.get_player(event.player_index);if player then close(player) end
    local root=peek();if root then remove_launcher(root,event.player_index) end
end
---@param event EventData.on_player_removed
function model.on_player_removed(event)
    model.on_player_left(event);local root=peek();if root then remove_viewer(root,event.player_index);root.players[event.player_index]=nil end
end
---@param event EventData.on_gui_click
---@return boolean
function model.on_gui_click(event)
    if not belongs(event) then return false end
    local player=game.get_player(event.player_index);if not player then return true end
    local action=event.element.tags.action;local root=state();local p=root.players[player.index]
    if action=="open" then if p and p.frame and p.frame.valid then close(player) else open(player,event.tick) end
    elseif action=="close" then close(player)
    elseif action=="admin" and player.admin then owners.open_admin(player,event.tick)
    elseif action=="page" and p then p.surface_page=(p.surface_page or 1)+event.element.tags.delta;surfaces_page(player,p) end
    return true
end
---@param event EventData.on_gui_checked_state_changed|EventData.on_gui_selected_tab_changed
---@return boolean
function model.on_gui_change(event)
    if not belongs(event) then return false end
    local player=game.get_player(event.player_index);if not player then return true end
    local element=event.element;local t=element.tags;local p=state().players[player.index]
    if t.action=="tab" then p.tab=element.selected_tab_index;p.row_cursor=0;p.next_tick=event.tick
    elseif t.action=="preference" then owners.alerts.set_preference(player,t.key,element.state);element.state=owners.alerts.preferences(player)[t.key]
    elseif t.action=="all-surfaces" then owners.alerts.set_preference(player,"surfaces",element.state and "all" or "[]");surfaces_page(player,p)
    elseif t.action=="surface" then
        local prefs=owners.alerts.preferences(player);local selected={}
        if prefs.surfaces=="all" then for _,surface in pairs(game.surfaces) do selected[surface.name]=true end
        else for name in pairs(prefs.selected) do selected[name]=true end end
        selected[t.surface]=element.state or nil
        local names={};for name in pairs(selected) do names[#names+1]=name end;table.sort(names)
        owners.alerts.set_preference(player,"surfaces",#names==0 and "[]" or helpers.table_to_json(names))
        p.all_surfaces.state=owners.alerts.preferences(player).surfaces=="all";surfaces_page(player,p)
    end
    return true
end
---@param event EventData.on_gui_closed
---@return boolean
function model.on_gui_closed(event)
    if event.element and event.element.valid and event.element.name==GUI then local player=game.get_player(event.player_index);if player then close(player) end;return true end
    return false
end
---@param event EventData.on_runtime_mod_setting_changed
function model.on_settings_changed(event)
    if not event.player_index or event.setting_type~="runtime-per-user" or not preferences.by_name[event.setting] then return end
    local root=peek();local player=game.get_player(event.player_index);local p=root and root.players[event.player_index]
    if not player or not p or not p.frame or not p.frame.valid then return end
    local prefs=owners.alerts.preferences(player)
    for key,check in pairs(p.checks or {}) do if check.valid then check.state=prefs[key];check.enabled=key~="allow-unrevealed" or player.admin end end
    if p.all_surfaces and p.all_surfaces.valid then p.all_surfaces.state=prefs.surfaces=="all";surfaces_page(player,p) end
end
---@param tick MapTick
---@return boolean
function model.has_tick_work(tick)
    local root=peek();return root and #root.viewers>0 and tick>=root.next_tick or false
end
---@param tick MapTick
---@return boolean
function model.launcher_has_tick_work(tick)
    local root=peek();return root and root.launchers and #root.launchers>0 and tick>=(root.launcher_next_tick or 0) or false
end
-- A separate cached presentation allowance keeps closed report windows idle.
-- No report snapshots, searches, or daylight writes occur on this path.
---@param event EventData.on_tick
function model.launcher_updater(event)
    if not model.launcher_has_tick_work(event.tick) then return end
    local root=peek();local count=#root.launchers
    root.launcher_next_tick=event.tick+math.max(16,math.floor(600/count))
    root.launcher_cursor=(root.launcher_cursor or 0)%count+1
    local index=root.launchers[root.launcher_cursor];local player=game.get_player(index)
    if not player or not player.connected then remove_launcher(root,index);return end
    local p=root.players[index];if p then refresh_button(player,p,event.tick) end
end
-- blueprint-ref: .codex/esir/blueprints/terrain-evolution.md#v2-reporting
---@param event EventData.on_tick
function model.updater(event)
    local root=peek();if not model.has_tick_work(event.tick) then return end
    local tick=event.tick;root.next_tick=tick+16;root.cursor=root.cursor%#root.viewers+1
    local player=game.get_player(root.viewers[root.cursor]);local p=player and root.players[player.index]
    if not player or not player.connected or not p or not p.frame or not p.frame.valid then
        if player then close(player) else remove_viewer(root,root.viewers[root.cursor]) end
        return
    end
    if p.tab==3 then
        if p.surface_epoch~=root.surface_epoch or p.surface_selection~=owners.alerts.preferences(player).surfaces then surfaces_page(player,p) end
        return
    end
    if tick<(p.next_tick or 0) and not p.clearing then return end
    p.next_tick=tick+60
    local surface=player.surface
    if p.surface~=surface and not p.clearing then p.pending_surface=surface;p.clearing=true;p.clear_tab=1;p.clear_row=0 end
    if p.clearing then
        p.bodies[1].visible=false;p.bodies[2].visible=false;p.loading.visible=true
        for _=1,8 do
            local rows=p.rows[p.clear_tab]
            if not rows then p.clearing=nil;p.surface=surface;p.row_cursor=0;p.bodies[1].visible=true;p.bodies[2].visible=true;p.loading.visible=false;p.next_tick=tick;break end
            p.clear_row=p.clear_row+1;local row=rows[p.clear_row]
            if row then row.element.caption="";row.signature=nil
            else p.clear_tab=p.clear_tab+1;p.clear_row=0 end
        end
        return
    end
    local report=owners.terrain.public_snapshot(surface,tick);local rows=p.rows[p.tab or 1]
    for _=1,math.min(8,#rows) do
        p.row_cursor=p.row_cursor%#rows+1;local row=rows[p.row_cursor]
        local caption,signature=row_value(row.key,report,surface,(p.tab or 1)==1)
        if row.signature~=signature then row.element.caption=caption;row.signature=signature end
    end
end
return model
