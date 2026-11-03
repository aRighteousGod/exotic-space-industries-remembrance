--==============================================================================
-- ESIR FILE MAP
-- owns: Visible orbital logistics details and native hub/silo relative panels.
-- loaded_by: scripts/control/orbital-logistics.lua
-- cadence: visible sessions only, one viewer per dispatcher slice, 30 tick refresh
-- forwarded_events: mount, open, close, refresh, handle, update, pending
-- storage_roots: storage.ei.orbital_logistics.native_gui
-- gui_ids: ei-orbital-native-console, native-details
-- rebuild_on: runtime rebuild and entity-open lifecycle
-- remote_interfaces: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/orbital-logistics.md#contract
-- blueprint-ref: .codex/esir/blueprints/orbital-logistics.md#native-panels
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
---@class OrbitalPanelSession
---@field entity LuaEntity Validated before each visible refresh.
---@field parent LuaGuiElement
---@field body LuaGuiElement
---@field page integer
---@field tab "platforms"|"lanes"
---@field search string
---@field all_locations boolean
---@field advanced boolean|nil
---@field action_error string|nil
---@field platform_values uint[]|nil
---@field row_entities table<integer,LuaEntity>|nil
---@class OrbitalPanelTags
---@field parent_gui string
---@field orbital_native boolean
---@field action string
---@field value string|integer|nil
---@class OrbitalNativePanels
---@type OrbitalNativePanels
local ui = {}
local NAME = "ei-orbital-native-console"
local PARENT = "ei-orbital-logistics-console"
local PAGE_SIZE = 10

local function text(key, ...)
  return {"exotic-industries.orbital-native-" .. key, ...}
end

local function state()
  local root = storage.ei.orbital_logistics
  root.native_gui = root.native_gui or {sessions={}, queue=scheduler.ensure_queue(nil), next_tick=0}
  return root.native_gui
end

local function tags(action, value)
  return {parent_gui=PARENT, orbital_native=true, action=action, value=value}
end

local function native_anchor(player, entity)
  local hub = entity.type == "space-platform-hub"
  -- Native hub/silo windows have several fixed-width columns. Attach below on
  -- compact displays instead of pushing their details beyond the screen edge.
  local fits_beside = player.display_resolution.width / player.display_scale >= (hub and 2300 or 1900)
  return {gui=hub and defines.relative_gui_type.space_platform_hub_gui or defines.relative_gui_type.rocket_silo_gui,
    position=fits_beside and defines.relative_gui_position.right or defines.relative_gui_position.bottom}
end

local function label(parent, name)
  local element = parent.add{type="label", name=name, caption=""}
  element.style.single_line = false
  element.style.maximal_width = 480
  return element
end

local function manifest(filters)
  local caption = {""}
  for index, filter in ipairs(filters or {}) do
    if index > 12 then caption[#caption + 1] = " …"; break end
    local value = filter.value or filter
    caption[#caption + 1] = "[item=" .. value.name .. ",quality=" .. (value.quality or "normal") .. "] "
      .. tostring(filter.min or filter.count or 0) .. "  "
  end
  if #caption == 1 then return text("empty") end
  return caption
end

---@param player LuaPlayer
function ui.close(player)
  if not player then return end
  local root = player.gui.relative[NAME]
  if root then root.destroy() end
  local saved = storage.ei and storage.ei.orbital_logistics and storage.ei.orbital_logistics.native_gui
  if saved then saved.sessions[player.index] = nil end
end

---@param player_index uint
---@return boolean
function ui.has_session(player_index)
  local saved = storage.ei and storage.ei.orbital_logistics and storage.ei.orbital_logistics.native_gui
  return saved and saved.sessions[player_index] ~= nil or false
end

local function advanced(session)
  if not session.parent.valid then return end
  for _, child in pairs(session.parent.children) do
    if child.name ~= "native-details" then child.visible = session.advanced == true end
  end
end

---@param player LuaPlayer
---@param entity LuaEntity
---@param parent LuaGuiElement
---@param owner table Orbital controller; passed in to avoid cyclic module loading.
---@param tick MapTick
function ui.mount(player, entity, parent, owner, tick)
  local saved = state()
  if parent["native-details"] then parent["native-details"].destroy() end
  local body = parent.add{type="flow", name="native-details", direction="vertical"}
  -- Keep primary details above the legacy controls when Advanced expands.
  for index=#parent.children,2,-1 do parent.swap_children(index,index-1) end
  body.style.minimal_width = 456
  local session = {entity=entity, parent=parent, body=body, page=1, tab="platforms", search="", all_locations=false}
  saved.sessions[player.index] = session
  label(body, "summary")
  label(body, "target")
  label(body, "cargo")
  label(body, "incoming")
  label(body, "requests")
  label(body, "need")
  label(body, "sources")
  label(body, "blocker")
  if entity.name == "ei-orbital-selector" then
    local modes = body.add{type="flow", name="modes"}
    for _, mode in ipairs({"policy", "manual", "circuit"}) do
      modes.add{type="button", name=mode, caption={"exotic-industries.orbital-logistics-gui-selector-mode-" .. mode}, tags=tags("selector-mode", mode)}
    end
    body.add{type="drop-down", name="platform", items={}, tags=tags("selector-target")}
  end
  if entity.name == "ei-orbital-dispatch-uplink" then
    local modes = body.add{type="flow", name="owners"}
    for _, mode in ipairs({"native", "cohort"}) do
      modes.add{type="button", name=mode, caption=text("owner-" .. mode), tags=tags("owner", mode)}
    end
  end
  if entity.type == "space-platform-hub" or entity.name == "ei-platform-transponder" then
    label(body, "radar").caption = text("radar-guidance")
    body.add{type="button", caption=text("radar-examples"), tags=tags("radar-help")}
  end
  if entity.name == "ei-orbital-coordinator" then
    local tabs = body.add{type="flow", name="overview-tabs"}
    for _, tab in ipairs({"platforms", "lanes"}) do
      tabs.add{type="button", name=tab, caption=text(tab), tags=tags("tab", tab)}
    end
    local filters = body.add{type="flow", name="filters"}
    filters.add{type="textfield", name="search", text="", tooltip=text("search"), tags=tags("search")}
    filters.add{type="button", name="location-filter", caption=text("this-location"), tags=tags("location")}
    body.add{type="flow", direction="vertical", name="rows"}
    local pages = body.add{type="flow", name="pages"}
    pages.add{type="button", caption="◀", tags=tags("page", -1)}
    pages.add{type="label", name="count", caption=""}
    pages.add{type="button", caption="▶", tags=tags("page", 1)}
  end
  if entity.type ~= "rocket-silo" and entity.type ~= "space-platform-hub" then
    body.add{type="button", caption=text("advanced"), tags=tags("advanced")}
    advanced(session)
  end
  ui.refresh(player, owner, tick)
end

---@param player LuaPlayer
---@param entity LuaEntity
---@param owner table
---@param tick MapTick
function ui.open(player, entity, owner, tick)
  ui.close(player)
  local root = player.gui.relative.add{type="frame", name=NAME, direction="vertical",
    anchor=native_anchor(player, entity)}
  root.add{type="label", caption=text("title"), style="frame_title"}
  local parent = root.add{type="scroll-pane", name="body", direction="vertical",
    horizontal_scroll_policy="never", vertical_scroll_policy="auto"}
  ui.mount(player, entity, parent, owner, tick)
end

---@param player_index uint
---@return boolean
function ui.is_advanced(player_index)
  local session = state().sessions[player_index]
  return session and session.advanced == true
end

---@param player LuaPlayer
---@param owner table
---@param tick MapTick
function ui.refresh(player, owner, tick)
  local session = state().sessions[player.index]
  if not session then return end
  local entity, body = session.entity, session.body
  if not lib.entity_check(entity) or entity.force ~= player.force or not body.valid then owner.close_gui(player); return end
  local relative = session.parent.parent
  if relative and relative.name == NAME then
    local anchor = native_anchor(player, entity)
    if relative.anchor.position ~= anchor.position then relative.anchor = anchor end
    session.parent.style.maximal_height = math.floor(math.max(120, math.min(360, player.display_resolution.height / player.display_scale - 600)))
  end
  local data = owner.get_panel_snapshot(entity, tick)
  if not data then owner.close_gui(player); return end
  for _, name in ipairs({"summary", "target", "cargo", "incoming", "requests", "need", "sources", "blocker"}) do body[name].caption = "" end
  if data.silo then
    local silo = data.silo
    local rocket_state = silo.rocket_state == "building_rocket" and "building"
      or silo.rocket_state == "rocket_ready" and "ready"
      or silo.rocket_state == "unknown" and "unknown"
      or silo.launching and "launching" or "preparing"
    body.summary.caption = text("silo-status", text("owner-" .. (silo.dispatch_owner or silo.dispatch_mode)), text("rocket-" .. rocket_state))
    body.target.caption = text("target", (silo.dispatch_owner == "native" and silo.native_target_name
      or silo.dispatch_owner ~= "native" and silo.target_name) or text("no-target"))
    body.cargo.caption = text("payload", math.floor((silo.payload_weight or 0)/1000), math.floor((silo.payload_capacity or 0)/1000), manifest(silo.payload))
    body.incoming.caption = text("incoming", manifest(silo.incoming))
    local blocker = session.action_error or silo.configuration_error
      or (silo.dispatch_mode == "native" and not silo.automatic and "enable-native" or nil) or silo.blocker
    if blocker then body.blocker.caption = text("blocker-" .. blocker, manifest(silo.mismatches)) end
    if body.owners then
      -- Keep native action available when recorded native ownership has not yet
      -- been explicitly adopted into the engine's automatic request setting.
      body.owners.native.enabled = silo.dispatch_mode ~= "native" or not silo.automatic
      body.owners.cohort.enabled = silo.dispatch_mode ~= "cohort" or silo.automatic
    end
  elseif data.platform then
    body.summary.caption = text("platform-status", data.platform.name, data.providing and text("providing-on") or text("providing-off"))
    body.cargo.caption = text("stock", manifest(data.payload.stock))
    body.requests.caption = text("requests", manifest(data.payload.requests))
    body.incoming.caption = text("incoming", manifest(data.payload.incoming))
    body.need.caption = text("need", manifest(data.payload.filters))
    body.sources.caption = text("sources", manifest(data.payload.source_requests and data.payload.source_requests.planet),
      manifest(data.payload.source_requests and data.payload.source_requests.platforms))
  elseif data.selector then
    body.summary.caption = text("selector-status", data.target_name or text("no-target"))
    if data.blocker then body.blocker.caption = text("blocker-" .. data.blocker) end
    for _, mode in ipairs({"policy", "manual", "circuit"}) do body.modes[mode].enabled = mode ~= data.selector.mode end
    local items, values, selected = {text("no-target")}, {0}, 1
    for _, choice in ipairs(data.choices) do
      items[#items + 1] = choice.name .. " (#" .. choice.id .. ")"
      values[#values + 1] = choice.id
      if choice.id == data.selector.manual_platform_id then selected = #items end
    end
    -- Populate the native list before assigning an index into it.
    body.platform.items = items
    body.platform.selected_index = selected
    session.platform_values = values
    body.platform.enabled = data.selector.mode == "manual"
  end
  if body.rows then
    local rows = owner.get_overview_rows(entity, session.tab, session.all_locations, session.search)
    local pages = math.max(1, math.ceil(#rows/PAGE_SIZE))
    session.page = math.max(1, math.min(session.page, pages))
    body.rows.clear()
    session.row_entities = {}
    for index=(session.page-1)*PAGE_SIZE+1, math.min(#rows, session.page*PAGE_SIZE) do
      local row = rows[index]
      session.row_entities[index] = row.entity
      body.rows.add{type="button", caption=row.caption, tags=tags("open-entity", index)}
    end
    body.pages.count.caption = tostring(session.page) .. " / " .. tostring(pages)
    body.filters["location-filter"].caption = text(session.all_locations and "all-locations" or "this-location")
    body["overview-tabs"].platforms.enabled, body["overview-tabs"].lanes.enabled = session.tab ~= "platforms", session.tab ~= "lanes"
  end
  for _, name in ipairs({"summary", "target", "cargo", "incoming", "requests", "need", "sources", "blocker"}) do
    body[name].visible = body[name].caption ~= ""
  end
end

---@param tick MapTick
---@return integer
function ui.pending(tick)
  local saved = storage.ei and storage.ei.orbital_logistics and storage.ei.orbital_logistics.native_gui
  if not saved or not next(saved.sessions) then return 0 end
  return tick >= saved.next_tick and 1 or scheduler.queue_item_count(saved.queue)
end

---@param owner table
---@param tick MapTick
---@return boolean
function ui.update(owner, tick)
  local saved = state()
  if tick >= saved.next_tick then
    for index in pairs(saved.sessions) do scheduler.queue_push_unique(saved.queue, index, index) end
    saved.next_tick = tick + 30
  end
  local index = scheduler.queue_peek(saved.queue)
  if not index then return false end
  scheduler.queue_pop(saved.queue, index)
  local player = game.get_player(index)
  if player and player.connected then ui.refresh(player, owner, tick)
  elseif player then owner.close_gui(player) else saved.sessions[index] = nil end
  return true
end

---@param event EventData.on_gui_click|EventData.on_gui_text_changed|EventData.on_gui_selection_state_changed
function ui.handle(event, owner)
  local element = event.element
  if not element or not element.valid or not element.tags.orbital_native then return false end
  local player = game.get_player(event.player_index)
  local session = player and state().sessions[player.index]
  if not session or not lib.entity_check(session.entity) or session.entity.force ~= player.force then return true end
  local action, value = element.tags.action, element.tags.value
  if action == "selector-target" and event.name ~= defines.events.on_gui_selection_state_changed then return true end
  if action == "search" and event.name ~= defines.events.on_gui_text_changed then return true end
  session.action_error = nil
  if action == "advanced" then
    session.advanced = not session.advanced; advanced(session)
    if session.advanced then owner.refresh_player_gui(player, session.entity, nil, event.tick) end
  elseif action == "owner" then
    local ok, problem = owner.set_dispatch_mode(session.entity.unit_number, value, event.tick)
    session.action_error = not ok and problem or nil
  elseif action == "selector-mode" then owner.set_selector_configuration(session.entity, value, nil, event.tick)
  elseif action == "selector-target" then owner.set_selector_configuration(session.entity, "manual", session.platform_values[element.selected_index], event.tick)
  elseif action == "tab" then session.tab, session.page = value, 1
  elseif action == "location" then session.all_locations, session.page = not session.all_locations, 1
  elseif action == "page" then session.page = math.max(1, session.page + value)
  elseif action == "search" then session.search, session.page = element.text:lower(), 1
  elseif action == "open-entity" then
    local target = session.row_entities[value]
    if lib.entity_check(target) and target.force == player.force then
      -- Native remote view admits distant/cross-surface entity windows without
      -- moving the player's character. Opening alone can silently fail at range.
      player.centered_on = target
      player.opened = target
    end
    return true
  elseif action == "radar-help" then
    remote.call("informatron", "informatron_open_to_page", {player_index=player.index, interface="exotic-industries-informatron", page_name="orbital_scanner"})
    return true
  end
  ui.refresh(player, owner, event.tick)
  return true
end

return ui
