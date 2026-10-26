--==============================================================================
-- ESIR FILE MAP
-- owns: current-surface ecology window and personal alert icon selector
-- loaded_by: control.lua
-- cadence: lifecycle/season buttons; one open viewer per 16 ticks, eight property writes
-- forwarded_events: GUI, menu custom input and player lifecycle through control.lua
-- storage_roots: storage.ei.ecology_gui
-- gui_ids: ei-ecology
-- remote_interfaces: none
-- rebuild_on: configuration and player lifecycle
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local mod_gui=require("__core__/lualib/mod-gui")
local preferences=require("lib/terrain-alert-config")
local alert_catalog=require("lib/alert-catalog")
local alert_icon_sets=require("lib/alert-icon-sets")
local native_alerts=require("lib/alerts")
local terrain_config=require("lib/terrain-evolution-config")
local field_report=require("scripts/control/terrain-field-report")
local model={}
---@alias EsirEcologyGuiAction "window"|"open"|"close"|"launcher"|"admin"|"page"|"tab"|"preference"|"all-surfaces"|"surface"|"guide"|"icon-set"
---@class EsirEcologyGuiTags
---@field parent_gui "ei-ecology"
---@field action EsirEcologyGuiAction
---@field key string?
---@field surface string? Exact surface name in the personal selection.
---@field delta integer?
---@field player_index PlayerIndex? Personal selector owner.
---@field frame_index integer? Current native frame identity.

---@class EsirEcologyGuiRow
---@field element LuaGuiElement
---@field key string
---@field signature string?
---@field property string? Native property; style.width uses the element's style.
---@field generation integer? Viewed-surface generation last rendered.

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
---@field launcher boolean? Missing legacy preferences default to shown; false persists.
---@field launcher_toggle LuaGuiElement?
---@field title_icon LuaGuiElement?
---@field title_season integer?
---@field view_generation integer?
---@field tab_generations table<integer, integer>?
---@field strip_width integer?
---@field last_update_writes integer? Actual native property writes in the last admitted opportunity.
---@field invalidated boolean? Survives rapid A-B-A view changes between services.
---@field layout_version integer? Lazy first-use retirement of older saved GUI layouts.
---@field icon_selector LuaGuiElement?
---@field icon_choices string[]? Dense dropdown index to registered set ID.
---@field icon_rows {element: LuaGuiElement, definition: EsirAlertDefinition, set_id: string?}[]?
---@field icon_target string? Latest resolved personal set, never a queued obsolete choice.
---@field icon_cursor integer? Next checkbox caption to reconcile under the viewer write budget.

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
---@field fulgora EsirFulgoraDayReportApi
---@type EsirEcologyGuiContext
local owners={}
local GUI="ei-ecology"
local BUTTON="ei-ecology-button"
local LAYOUT_VERSION=5
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
    local frame=p and p.frame
    if frame and frame.valid then
        p.location=frame.location
        -- Clearing player.opened can synchronously dispatch on_gui_closed.
        -- Release ownership before that callback can enter this close path again.
        p.frame=nil;p.rows=nil;p.title_icon=nil;p.launcher_toggle=nil;p.icon_selector=nil;p.icon_rows=nil
        if player.opened==frame then player.opened=nil end
        if frame.valid then frame.destroy() end
    end
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
    local p=root.players[player.index] or {tab=1};root.players[player.index]=p
    if p.launcher==nil then p.launcher=true end
    local enabled=settings.startup["ei-terrain-evolution-enabled"].value
    -- Hidden launchers must not create mod-gui containers or close an open report.
    local existing=p.button
    if not existing or not existing.valid then
        local top=player.gui.top;local frame=top.mod_gui_top_frame
        local flow=top.mod_gui_button_flow or (frame and frame.mod_gui_inner_frame)
        existing=flow and flow[BUTTON]
    end
    if enabled and p.launcher then
        -- Replace the pre-season text button when adopting an existing save.
        if existing and existing.type~="sprite-button" then existing.destroy();existing=nil end
        if not existing then
            local flow=mod_gui.get_button_flow(player)
            existing=flow.add{type="sprite-button",name=BUTTON,sprite=seasonal_sprites[0],style=mod_gui.button_style,tags=tags("open")}
            p.button_season=nil
        end
        p.button=existing;refresh_button(player,p,tick)
        if player.connected and not root.launcher_indexes[player.index] then
            root.launchers[#root.launchers+1]=player.index;root.launcher_indexes[player.index]=#root.launchers
        end
    else
        remove_launcher(root,player.index)
        if existing then existing.destroy() end
        p.button=nil;p.button_season=nil
        if not enabled then close(player) end
    end
end
local function label(flow,key,width)
    local element=flow.add{type="label",caption=""};element.style.single_line=false;element.style.maximal_width=610
    if width then element.style.maximal_width=width end
    return {element=element,key=key}
end
local function field_text(key) return {"ei-ecology-field."..key} end
local function field_binding(rows,element,key,property)
    rows[#rows+1]={element=element,key=key,property=property or "caption"}
end
local function field_label(parent,rows,key,width,tooltip)
    local row=label(parent,key,width);rows[#rows+1]=row
    row.element.style.font_color={r=0.91,g=0.9,b=0.83}
    if tooltip then row.element.tooltip=field_text(tooltip) end
    return row.element
end
local function field_section(parent,title,width)
    local panel=parent.add{type="frame",direction="vertical",style="inside_shallow_frame"}
    panel.style.width=width;panel.style.padding=12
    local heading=panel.add{type="label",caption=field_text(title),style="heading_2_label"}
    heading.style.single_line=false;heading.style.maximal_width=width-24
    if title=="ground" or title=="woodland" then heading.style.font_color={r=0.55,g=0.88,b=0.79}
    elseif title=="mining" or title=="other" then heading.style.font_color={r=1,g=0.77,b=0.45} end
    return panel
end
local phase_colors={{r=0.93,g=0.79,b=0.4},{r=0.79,g=0.36,b=0.17},{r=0.16,g=0.25,b=0.38},{r=0.4,g=0.72,b=0.73}}
local season_colors={{r=0.62,g=0.87,b=0.25},{r=0.08,g=0.67,b=0.43},{r=0.9,g=0.42,b=0.16},{r=0.28,g=0.76,b=0.92}}
local function field_strip(parent,rows,key,width,colors,dynamic)
    parent=parent.add{type="flow",direction="vertical"}
    field_binding(rows,parent,key.."_available","visible")
    local strip=parent.add{type="flow",direction="horizontal"};strip.style.horizontal_spacing=0
    local partition=field_report.segment_widths({0.25,0.25,0.25,0.25},width)
    for i=1,4 do
        local bar=strip.add{type="progressbar",value=1,style="ei_ecology_strip"}
        bar.style.width=partition[i];bar.style.color=colors[i]
        bar.tooltip=dynamic and field_text(({"day","dusk","night","dawn"})[i]) or {"ei-ecology.season-"..i}
        if dynamic then
            field_binding(rows,bar,"day_width_"..i,"style.width")
            field_binding(rows,bar,"day_visible_"..i,"visible")
        end
    end
    local marker=parent.add{type="flow",direction="horizontal"};marker.style.horizontal_spacing=0
    local offset=marker.add{type="empty-widget"};offset.style.width=0;offset.style.height=12
    field_binding(rows,offset,key.."_marker","style.width")
    local point=marker.add{type="label",caption=field_text("phase-marker")}
    point.style.height=18;point.style.width=20;point.style.single_line=false
    local legend=parent.add{type="label",caption=field_text(dynamic and "legend-day" or "legend-season")}
    legend.style.single_line=false;legend.style.maximal_width=width
end
local function build_field_report(parent,p,width)
    local rows={};p.rows[1]=rows;p.strip_width=width-24
    local banner=parent.add{type="sprite",sprite="ei-ecology-banner-neutral",resize_to_sprite=false,tooltip=field_text("illustration")}
    banner.style.width=width;banner.style.height=math.floor(width/4);field_binding(rows,banner,"banner","sprite")
    field_binding(rows,banner,"banner_visible","visible")
    local compact=width<360
    local identity=parent.add{type="flow",direction=compact and "vertical" or "horizontal"};identity.style.vertical_align="center"
    local icon=identity.add{type="sprite",sprite="utility/clock"};icon.style.size=48;field_binding(rows,icon,"icon","sprite")
    local names=identity.add{type="flow",direction="vertical"}
    local name_width=compact and width or width-132
    local name=field_label(names,rows,"identity",name_width);name.style.font="default-large-bold"
    field_label(names,rows,"status",name_width)
    local tree=identity.add{type="sprite",sprite=seasonal_sprites[0],resize_to_sprite=false}
    tree.style.size=64;tree.style.stretch_image_to_widget_size=true;field_binding(rows,tree,"tree","sprite")
    local day=field_section(parent,"local-day",width)
    field_strip(day,rows,"day",p.strip_width,phase_colors,true)
    field_label(day,rows,"day",p.strip_width,"clock-help")
    local calendar=field_section(parent,"calendar",width)
    field_strip(calendar,rows,"season",p.strip_width,season_colors,false)
    local season=field_label(calendar,rows,"season",p.strip_width)
    field_binding(rows,season,"calendar_tip","tooltip")
    field_label(calendar,rows,"daylight",p.strip_width)
    local columns=width>=680 and 2 or 1
    local grid=parent.add{type="table",column_count=columns};grid.style.horizontal_spacing=8;grid.style.vertical_spacing=8
    grid.vertical_centering=false
    for column=1,columns do grid.style.column_alignments[column]="top-left" end
    local card_width=math.floor((width-(columns-1)*8)/columns)
    for _,key in ipairs({"ground","woodland","mining","other"}) do
        local card=field_section(grid,key,card_width)
        field_label(card,rows,key,card_width-24,"record-help")
        if key~="other" then field_label(card,rows,key.."_note",card_width-24)
        else
            local note=card.add{type="label",caption=field_text("other-help")};note.style.single_line=false;note.style.maximal_width=card_width-24
        end
        if key=="ground" then card.tooltip=field_text("ground-help") end
    end
    local footer=field_section(parent,"observations",width)
    field_label(footer,rows,"survey",width-24)
    local guide=footer.add{type="button",caption=field_text("guide"),tags=tags("guide")}
    guide.style.maximal_width=width-24
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
---@param definition EsirAlertDefinition
---@param set_id string
---@return LocalisedString
local function alert_caption(definition,set_id)
    return {"","[img=virtual-signal/"..alert_icon_sets.signal_name(set_id,definition.id).."] ",{"mod-setting-name."..definition.setting_name}}
end
---@param player LuaPlayer
---@param p EsirEcologyGuiSession
---@param body LuaGuiElement
local function build_icon_selector(player,p,body)
    local choices={alert_icon_sets.sentinel};local captions={alert_icon_sets.choice_caption(alert_icon_sets.sentinel)}
    local selected=1;local resolved=alert_icon_sets.player_set(player)
    for _,id in ipairs(alert_icon_sets.available_sets()) do
        choices[#choices+1]=id;captions[#captions+1]=alert_icon_sets.choice_caption(id)
        if id==resolved then selected=#choices end
    end
    if p.icon_selector and p.icon_selector.valid then
        -- Configuration changes may add/remove provider sets while this pane is open.
        p.icon_selector.items=captions;p.icon_selector.selected_index=selected
    else
        local row=body.add{type="flow",direction="vertical",index=1}
        local heading=row.add{type="label",caption={"mod-setting-name."..alert_icon_sets.setting_name}}
        heading.style.single_line=false;heading.style.maximal_width=600
        p.icon_selector=row.add{type="drop-down",items=captions,selected_index=selected,
            tooltip={"mod-setting-description."..alert_icon_sets.setting_name},
            tags=tags("icon-set",{player_index=player.index,frame_index=p.frame.index})}
        p.icon_selector.style.maximal_width=600
    end
    p.icon_choices=choices;p.icon_target=resolved
end
-- Keep the saved scroll panes alive: the native API cannot read their scroll
-- offsets. The v4-to-v5 insertion preserves tab, location, scroll and launcher.
---@param player LuaPlayer
---@param p EsirEcologyGuiSession
---@return boolean
local function adopt_layout(player,p)
    if p.layout_version==LAYOUT_VERSION then return true end
    if p.layout_version~=4 or not p.bodies or not p.bodies[3] or not p.bodies[3].valid or not p.checks then return false end
    build_icon_selector(player,p,p.bodies[3]);p.icon_rows={};p.icon_cursor=1
    for _,row in ipairs(preferences.schema) do
        local definition=alert_catalog.by_setting[row.name];local check=p.checks[row.key]
        if definition and check and check.valid then p.icon_rows[#p.icon_rows+1]={element=check,definition=definition} end
    end
    p.layout_version=LAYOUT_VERSION
    return true
end
---@param p EsirEcologyGuiSession
local function refresh_alert_icons(p)
    if not p.icon_cursor then return end
    for index,id in ipairs(p.icon_choices) do
        if id==p.icon_target then
            if p.icon_selector.selected_index~=index and p.last_update_writes<8 then
                p.icon_selector.selected_index=index;p.last_update_writes=p.last_update_writes+1
            end
            break
        end
    end
    while p.icon_cursor<=#p.icon_rows and p.last_update_writes<8 do
        local row=p.icon_rows[p.icon_cursor];p.icon_cursor=p.icon_cursor+1
        if row.element.valid and row.set_id~=p.icon_target then
            row.element.caption=alert_caption(row.definition,p.icon_target);row.set_id=p.icon_target
            p.last_update_writes=p.last_update_writes+1
        end
    end
    if p.icon_cursor>#p.icon_rows then p.icon_cursor=nil end
end
local function build_alerts(player,p,body)
    local prefs=owners.alerts.preferences(player)
    build_icon_selector(player,p,body);p.icon_rows={};p.icon_cursor=nil
    local note=body.add{type="label",caption={"ei-ecology.alert-note"}};note.style.single_line=false;note.style.maximal_width=600
    p.checks={}
    for _,row in ipairs(preferences.schema) do
        if row.type=="bool-setting" then
            local definition=alert_catalog.by_setting[row.name]
            local caption=definition and alert_caption(definition,p.icon_target) or {"mod-setting-name."..row.name}
            local check=body.add{type="checkbox",state=prefs[row.key],caption=caption,
                tooltip={"mod-setting-description."..row.name},tags=tags("preference",{key=row.key})}
            check.enabled=row.key~="allow-unrevealed" or player.admin;p.checks[row.key]=check
            if definition then p.icon_rows[#p.icon_rows+1]={element=check,definition=definition,set_id=p.icon_target} end
        end
    end
    body.add{type="line"}
    p.all_surfaces=body.add{type="checkbox",state=prefs.surfaces=="all",caption={"ei-ecology.all-surfaces"},tags=tags("all-surfaces")}
    p.surface_body=body.add{type="flow",direction="vertical"};surfaces_page(player,p)
end
local function open(player,tick)
    if not settings.startup["ei-terrain-evolution-enabled"].value then return end
    local root=state();local old=root.players[player.index] or {tab=1};close(player)
    root.players[player.index]=old;local p=old
    if p.launcher==nil then p.launcher=true end
    local frame=player.gui.screen.add{type="frame",name=GUI,direction="vertical",tags=tags("window")}
    p.frame=frame;p.rows={};p.bodies={};p.row_cursor=0;p.next_tick=tick;p.surface=player.surface;p.clearing=nil
    p.view_generation=(p.view_generation or 0)+1;p.tab_generations={};p.invalidated=nil;p.layout_version=LAYOUT_VERSION
    local width=math.max(160,math.min(800,math.floor(player.display_resolution.width/player.display_scale)-48))
    local height=math.max(180,math.min(780,math.floor(player.display_resolution.height/player.display_scale)-48))
    frame.style.width=width;frame.style.maximal_height=height
    local title=frame.add{type="flow",direction="horizontal"}
    title.style.vertical_align="center";title.drag_target=frame
    p.title_season=owners.terrain.season_index(player.surface,tick)
    local icon=title.add{type="sprite",sprite=seasonal_sprites[p.title_season]};p.title_icon=icon
    icon.resize_to_sprite=false;icon.style.size=48;icon.style.stretch_image_to_widget_size=true;icon.ignored_by_interaction=true
    title.add{type="label",caption={"ei-ecology.title"},style="frame_title",ignored_by_interaction=true}
    local spacer=title.add{type="empty-widget",style="ei_titlebar_draggable_spacer"};spacer.drag_target=frame;spacer.style.height=48
    title.add{type="sprite-button",sprite="utility/close",style="frame_action_button",tags=tags("close")}
    local toolbar=frame.add{type="flow",direction="horizontal"}
    p.launcher_toggle=toolbar.add{type="button",caption={"ei-ecology.show-launcher"},
        tooltip={"ei-ecology.show-launcher-tooltip"},toggled=p.launcher,tags=tags("launcher")}
    p.loading=frame.add{type="label",caption={"ei-ecology.updating"}};p.loading.visible=true
    local pane=frame.add{type="tabbed-pane",tags=tags("tab")};p.pane=pane
    for i,name in ipairs({"simple","advanced","alerts"}) do
        local tab=pane.add{type="tab",caption={"ei-ecology.tab-"..name}}
        local scroll=pane.add{type="scroll-pane",direction="vertical",horizontal_scroll_policy="never"};scroll.style.height=math.max(1,height-188);scroll.style.width=width-30;p.bodies[i]=scroll
        pane.add_tab(tab,scroll)
        if i==1 then
            build_field_report(scroll,p,width-56);scroll.visible=false
        elseif i==2 then
            p.rows[2]={}
            for _,key in ipairs({"surface","status","pollution","sample-age","coverage","drills","surface-work","exposure","protections","daylight","recent","latency","global","histories","observations","service","saturation","incomplete","maintenance"}) do p.rows[2][#p.rows[2]+1]=label(scroll,key,width-56) end
            for _,category in ipairs(preferences.categories) do p.rows[2][#p.rows[2]+1]=label(scroll,"effect:"..category,width-56) end
            for _,row in ipairs(terrain_config.schema) do p.rows[2][#p.rows[2]+1]=label(scroll,"setting:"..row.key,width-56) end
            scroll.visible=false
            if player.admin then scroll.add{type="button",caption={"ei-ecology.admin"},tags=tags("admin")} end
        else build_alerts(player,p,scroll) end
    end
    pane.selected_tab_index=p.tab or 1
    p.loading.visible=(p.tab or 1)~=3
    if p.location then frame.location={x=math.max(24*player.display_scale,math.min(p.location.x,player.display_resolution.width-(width+24)*player.display_scale)),y=math.max(24*player.display_scale,math.min(p.location.y,player.display_resolution.height-(height+24)*player.display_scale))}
    else frame.location={x=math.max(24*player.display_scale,(player.display_resolution.width-width*player.display_scale)/2),y=math.max(24*player.display_scale,(player.display_resolution.height-height*player.display_scale)/2)} end
    player.opened=frame
    root.viewers[#root.viewers+1]=player.index;root.indexes[player.index]=#root.viewers
end
---@param player LuaPlayer
---@param tick MapTick
local function toggle(player,tick)
    if not settings.startup["ei-terrain-evolution-enabled"].value then return end
    local root=peek();local p=root and root.players[player.index]
    if p and p.frame and p.frame.valid then close(player) else open(player,tick) end
end
---@param event EventData.CustomInputEvent
function model.on_toggle_menu(event)
    local player=game.get_player(event.player_index)
    if player then toggle(player,event.tick) end
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
        local keep_open=was_open and player.connected and settings.startup["ei-terrain-evolution-enabled"].value and adopt_layout(player,p)
        if was_open and not keep_open then close(player) end
        button(player,tick)
        if keep_open then build_icon_selector(player,p,p.bodies[3]);p.icon_cursor=1
        elseif was_open and player.connected and settings.startup["ei-terrain-evolution-enabled"].value then open(player,tick) end
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
            if p.surface~=player.surface then
                -- Constant lifecycle invalidation; never walk the inactive tab.
                p.bodies[1].visible=false;p.bodies[2].visible=false;p.loading.visible=p.tab~=3;p.next_tick=event.tick;p.invalidated=true
            end
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
    if action=="open" then toggle(player,event.tick)
    elseif action=="close" then close(player)
    elseif p and p.frame and p.frame.valid and not adopt_layout(player,p) then open(player,event.tick)
    elseif action=="launcher" and p then
        p.launcher=p.launcher==false;button(player,event.tick)
        if p.launcher_toggle and p.launcher_toggle.valid then p.launcher_toggle.toggled=p.launcher end
    elseif action=="admin" and player.admin then owners.open_admin(player,event.tick)
    elseif action=="guide" and remote.interfaces.informatron and remote.interfaces.informatron.informatron_open_to_page then
        close(player)
        remote.call("informatron","informatron_open_to_page",{player_index=player.index,interface="exotic-industries-informatron",page_name="terrain_evolution"})
    elseif action=="page" and p then p.surface_page=(p.surface_page or 1)+event.element.tags.delta;surfaces_page(player,p) end
    return true
end
---@param event EventData.on_gui_checked_state_changed|EventData.on_gui_selected_tab_changed|EventData.on_gui_selection_state_changed
---@return boolean
function model.on_gui_change(event)
    if not belongs(event) then return false end
    local player=game.get_player(event.player_index);if not player then return true end
    local element=event.element;local t=element.tags;local p=state().players[player.index]
    if not p or not p.frame or not p.frame.valid or element.player_index~=player.index then return true end
    if not adopt_layout(player,p) then open(player,event.tick);return true end
    if t.action=="icon-set" then
        if element~=p.icon_selector or t.player_index~=player.index or t.frame_index~=p.frame.index then return true end
        local choice=p.icon_choices[element.selected_index];if not choice then return true end
        native_alerts.set_icon_set(player,choice,event.tick)
        model.on_settings_changed{player_index=player.index,setting_type="runtime-per-user",setting=alert_icon_sets.setting_name,tick=event.tick}
    elseif t.action=="tab" then
        if element~=p.pane then return true end
        p.tab=element.selected_tab_index;p.row_cursor=0;p.next_tick=event.tick
        p.loading.visible=p.tab~=3 and p.tab_generations[p.tab]~=p.view_generation
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
    if not event.player_index or event.setting_type~="runtime-per-user" then return end
    local icons_changed=event.setting==alert_icon_sets.setting_name
    if not icons_changed and not preferences.by_name[event.setting] then return end
    local root=peek();local player=game.get_player(event.player_index);local p=root and root.players[event.player_index]
    if not player or not p or not p.frame or not p.frame.valid then return end
    if icons_changed then
        -- Setting events only invalidate; the existing viewer allowance owns
        -- every selector/caption update, including rapid successive choices.
        p.icon_target=alert_icon_sets.player_set(player);p.icon_cursor=1
        return
    end
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
    -- Saved GUI handles may outlive a same-version source update. Adopt compatible
    -- panes in place; only older layouts rebuild for this admitted viewer.
    if not adopt_layout(player,p) then open(player,tick);return end
    p.last_update_writes=0
    -- The title remains seasonal even with a hidden launcher or the Alerts tab.
    -- Charge its changed sprite to the same eight-write viewer allowance.
    local season=owners.terrain.season_index(player.surface,tick)
    if p.title_season~=season then
        if p.title_icon.sprite~=seasonal_sprites[season] then p.title_icon.sprite=seasonal_sprites[season];p.last_update_writes=1 end
        p.title_season=season
    end
    if p.tab==3 then
        refresh_alert_icons(p)
        if p.surface_epoch~=root.surface_epoch or p.surface_selection~=owners.alerts.preferences(player).surfaces then surfaces_page(player,p) end
        return
    end
    if tick<(p.next_tick or 0) then return end
    p.next_tick=tick+60
    local function visible(element,value)
        if element.visible~=value then element.visible=value;p.last_update_writes=p.last_update_writes+1 end
    end
    local surface=player.surface
    if p.invalidated or p.surface~=surface then
        p.surface=surface;p.view_generation=(p.view_generation or 0)+1;p.row_cursor=0;p.invalidated=nil
        visible(p.bodies[1],false);visible(p.bodies[2],false);visible(p.loading,true)
    end
    local tab=p.tab or 1
    local initializing=p.tab_generations[tab]~=p.view_generation
    local report=owners.terrain.public_snapshot(surface,tick)
    local values=tab==1 and field_report.compose(report,surface,tick,owners.fulgora,p.strip_width).values
    local rows=p.rows[tab]
    -- No queue of obsolete captions: inspect a fixed number of current bindings,
    -- rotate fairly, and charge every native property assignment (including reveal).
    local limit=initializing and 6 or 8
    for _=1,math.min(32,#rows) do
        if p.last_update_writes>=limit then break end
        p.row_cursor=p.row_cursor%#rows+1;local row=rows[p.row_cursor]
        local value,signature
        if values then
            value=values[row.key]
            signature=type(value)=="table" and helpers.table_to_json(value) or tostring(value)
        else value,signature=row_value(row.key,report,surface,false) end
        if row.signature~=signature or row.generation~=p.view_generation then
            if row.property=="style.width" then row.element.style.width=value
            else row.element[row.property or "caption"]=value end
            row.signature=signature;row.generation=p.view_generation
            p.last_update_writes=p.last_update_writes+1
        end
        if initializing and p.row_cursor==#rows then
            p.tab_generations[tab]=p.view_generation
            visible(p.bodies[tab],true);visible(p.loading,false)
            break
        end
    end
    if p.tab_generations[tab]~=p.view_generation then p.next_tick=tick+16 end
end
return model
