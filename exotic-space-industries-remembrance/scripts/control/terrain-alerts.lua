--==============================================================================
-- ESIR FILE MAP
-- owns: personal ecology preferences and shared-alert eligibility adapter
-- loaded_by: control.lua, terrain-gui.lua
-- cadence: event admission; preference rename maintenance every 32 ticks
-- forwarded_events: settings, player and surface lifecycle
-- storage_roots: storage.ei.ecology_alerts
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration changes and surface rename
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local config=require("lib/terrain-alert-config")
local alerts=require("lib/alerts")
local model={}
---@type EsirEcologyAlertContext
local owners={}
---@alias EsirEcologyAlertCategory "wildfire"|"flood"|"drought"|"cliff"|"paving"|"pollution"|"restoration"|"depletion-scars"|"working-scars"|"mining-restoration"|"tree-stress"|"tree-recovery"|"regrowth"|"aging"|"rot"|"thermal"|"blood"
---@alias EsirEcologyPreferenceFlag EsirEcologyAlertCategory|"current-surface-only"|"allow-unrevealed"
---@class EsirEcologyPreferences
---@field enabled boolean
---@field surfaces string Canonical "all" or JSON array of exact names.
---@field selected table<string, boolean>? Nil only for "all".
---@field identities table<string, LuaSurface> Retains valid identities across pending rename reconciliation.
---@field live integer[] Owned incident IDs, at most four.
---@field online boolean
---@field rename_epoch integer Last completed or inherited preference generation.
---@field connection_epoch integer Admission epoch for this online session.
---@field [EsirEcologyPreferenceFlag] boolean

---@class EsirEcologyMaintenanceHandle
---@field name string
---@field total integer
---@field completed integer
---@field done boolean

---@class EsirEcologyRenameGeneration
---@field cursor integer
---@field total integer Frozen membership count; later players inherit the active epoch.
---@field remaining integer
---@field completed integer
---@field epoch integer
---@field report EsirEcologyMaintenanceHandle? Nil when terrain reporting is unavailable.

---@class EsirEcologyIncident: EffectReceipt
---@field id integer
---@field key string Surface/chunk/category coalescing key.
---@field anchor LuaEntity? Created lazily for delivery; validate before use.
---@field anchor_counted boolean? Tracks reserved capacity even if the entity becomes invalid.
---@field recipients PlayerIndex[]
---@field delivered table<PlayerIndex, MapTick|boolean>
---@field recipient_cursor integer
---@field audience_epoch integer? Frozen admission audience; absent legacy values mean epoch zero.
---@field scan_epoch integer? Most recent connected-roster traversal epoch.
---@field cleanup_recipient integer?
---@field delivery_complete boolean?
---@field expires MapTick Delivery-eligibility deadline; retirement is bounded separately.
---@field chunk_cell string? Added by retain_receipt.
---@field chunk_token EsirTerrainChunkToken? Cleared by release_receipt.

---@class EsirEcologyAlertState
---@field players table<PlayerIndex, EsirEcologyPreferences>
---@field player_order PlayerIndex[]
---@field player_members table<PlayerIndex, integer> Dense-order indices.
---@field interested table<EsirEcologyAlertCategory, integer> Connected enabled subscriber counts.
---@field alert_delivery_version integer? Completed shared-handler adoption version.
---@field preference_next_tick MapTick?
---@field rename_epoch integer?
---@field rename_pending boolean?
---@field rename EsirEcologyRenameGeneration?

---@class EsirEcologyAlertContext
---@field valid fun(receipt: EsirEcologyIncident): boolean
---@field retain fun(receipt: EsirEcologyIncident)
---@field release fun(receipt: EsirEcologyIncident)
---@field maintenance_begin fun(name: string, total: integer, tick: MapTick): EsirEcologyMaintenanceHandle?
---@field maintenance_update fun(handle: EsirEcologyMaintenanceHandle?, completed: integer, done: boolean, tick: MapTick)
---@return EsirEcologyAlertState?
local function peek() return storage.ei and storage.ei.ecology_alerts end
---@return EsirEcologyAlertState
local function ensure()
    storage.ei=storage.ei or {}
    storage.ei.ecology_alerts=storage.ei.ecology_alerts or {players={},player_order={},player_members={},interested={},items={},by_id={},coalesced={},next_id=0,next_tick=0,cursor=0,cleanup_cursor=0,anchors=0,dropped=0,delivered=0}
    local root=storage.ei.ecology_alerts
    alerts.adopt_legacy("ecology",root)
    return root
end
---@param context EsirEcologyAlertContext
function model.configure(context) owners=context end
local function surfaces(value)
    if value=="all" then return "all",nil end
    if type(value)~="string" or #value>4096 or not value:match("^%s*%[") then return end
    -- Validate the shallow string-array shape before decoding; a decoder must
    -- never turn omitted null elements into a valid empty selection.
    local i=1
    local function whitespace() while i<=#value and value:sub(i,i):match("%s") do i=i+1 end end
    whitespace();i=i+1;whitespace()
    if value:sub(i,i)~="]" then
        while true do
            if value:sub(i,i)~='"' then return end
            i=i+1
            while i<=#value and value:sub(i,i)~='"' do i=i+(value:sub(i,i)=="\\" and 2 or 1) end
            if i>#value then return end
            i=i+1;whitespace()
            if value:sub(i,i)=="]" then break end
            if value:sub(i,i)~="," then return end
            i=i+1;whitespace()
        end
    end
    i=i+1;whitespace();if i<=#value then return end
    local parsed=helpers.json_to_table(value)
    if type(parsed)~="table" then return end
    local selected,names={},{}
    for key,name in pairs(parsed) do
        if type(key)~="number" or key<1 or key%1~=0 or type(name)~="string" or name=="" then return end
        if not selected[name] then selected[name]=true;names[#names+1]=name;if #names>128 then return end end
    end
    table.sort(names)
    return #names==0 and "[]" or helpers.table_to_json(names),selected
end
---@param player LuaPlayer
---@return EsirEcologyPreferences
function model.refresh_preferences(player)
    local root=ensure();local previous=root.players[player.index]
    local was_online=previous and previous.online
    local old=alerts.refresh_player("ecology",player)
    local connection_epoch=old.connection_epoch
    if not root.player_members[player.index] then root.player_order[#root.player_order+1]=player.index;root.player_members[player.index]=#root.player_order end
    root.interested=root.interested or {}
    for _,category in ipairs(config.categories) do if was_online and old.enabled and old[category] then root.interested[category]=math.max(0,(root.interested[category] or 0)-1) end end
    local result={live=old.live or {},online=player.connected,connection_epoch=connection_epoch,rename_epoch=old.rename_epoch or root.rename_epoch or 0,force_index=old.force_index,setting_epochs=old.setting_epochs}
    for _,row in ipairs(config.schema) do
        local setting=player.mod_settings[row.name]
        if row.type=="bool-setting" then result[row.key]=setting~=nil and setting.value==true
        else result[row.key]=setting and setting.value or row.default end
    end
    if result["allow-unrevealed"] and not player.admin then
        result["allow-unrevealed"]=false
        player.mod_settings["ei-ecology-alert-allow-unrevealed"]={value=false}
    end
    local canonical,selected=surfaces(result.surfaces)
    if not canonical then
        canonical,selected=surfaces(old.surfaces or "[]")
        player.mod_settings["ei-ecology-alert-surfaces"]={value=canonical}
        player.print{"ei-ecology.invalid-surfaces"}
    elseif canonical~=result.surfaces then player.mod_settings["ei-ecology-alert-surfaces"]={value=canonical} end
    result.surfaces=canonical;result.selected=selected;result.identities={}
    for name in pairs(selected or {}) do
        local previous=old.identities and old.identities[name]
        result.identities[name]=game.get_surface(name) or (previous and previous.valid and previous or nil)
    end
    root.players[player.index]=result
    for _,category in ipairs(config.categories) do if result.online and result.enabled and result[category] then root.interested[category]=(root.interested[category] or 0)+1 end end
    return result
end
---@param tick MapTick
function model.initialize(tick)
    ensure()
    for _,player in pairs(game.players) do model.refresh_preferences(player) end
end
---@param player LuaPlayer
---@return EsirEcologyPreferences
function model.preferences(player)
    local root=peek();return root and root.players[player.index] or model.refresh_preferences(player)
end
---@param player LuaPlayer
---@param key string
---@param value boolean|string
function model.set_preference(player,key,value)
    local row=config.by_name["ei-ecology-alert-"..key]
    if not row or (key=="allow-unrevealed" and not player.admin) then return false end
    if row.type=="bool-setting" and type(value)~="boolean" then return false end
    if row.type=="string-setting" and not surfaces(value) then player.print{"ei-ecology.invalid-surfaces"};return false end
    player.mod_settings[row.name]={value=value}
    local event={player_index=player.index,setting_type="runtime-per-user",setting=row.name}
    model.on_settings_changed(event)
    alerts.on_settings_changed(event)
    return true
end
---@param event EventData.on_runtime_mod_setting_changed
function model.on_settings_changed(event)
    if event.player_index and event.setting_type=="runtime-per-user" and config.by_name[event.setting] then
        local player=game.get_player(event.player_index);if player then model.refresh_preferences(player) end
    end
end
---@class EsirEcologyPlayerEvent
---@field player_index PlayerIndex
---@field tick MapTick
---@param event EsirEcologyPlayerEvent
function model.on_player_event(event)
    local player=game.get_player(event.player_index);if player then model.refresh_preferences(player) end
end
---@param event EventData.on_player_removed
function model.on_player_removed(event)
    local root=peek();if root then
        local old=root.players[event.player_index]
        for _,category in ipairs(config.categories) do if old and old.online and old.enabled and old[category] then root.interested[category]=math.max(0,(root.interested[category] or 0)-1) end end
        if old and root.rename and old.rename_epoch~=root.rename.epoch then root.rename.remaining=root.rename.remaining-1;root.rename.completed=root.rename.completed+1 end
        root.players[event.player_index]=nil
        local slot=root.player_members[event.player_index]
        if slot then local last=root.player_order[#root.player_order];root.player_order[slot]=last;root.player_order[#root.player_order]=nil;root.player_members[event.player_index]=nil;if last~=event.player_index then root.player_members[last]=slot end end
    end
end
---@param receipt EffectReceipt
---@return boolean
function model.record_effect(receipt)
    local root=peek();if not root or not receipt.surface.valid or (root.interested[receipt.category] or 0)==0 then return false end
    return alerts.record_incident("ecology","ecology-"..receipt.category,receipt,receipt.tick)
end

local function eligible(player,prefs,r)
    return player and player.valid and player.connected and prefs and prefs.enabled and prefs[r.category]
        and (prefs.connection_epoch or 0)<=(r.audience_epoch or 0)
        and (prefs.surfaces=="all" or prefs.selected[r.surface.name])
        and (not prefs["current-surface-only"] or player.surface==r.surface)
        and ((player.admin and prefs["allow-unrevealed"]) or player.force.is_chunk_visible(r.surface,{math.floor(r.position.x/32),math.floor(r.position.y/32)}))
end
---@param tick MapTick
---@return boolean
function model.has_tick_work(tick)
    local root=peek();return root and (root.rename~=nil or root.rename_pending) and tick>=(root.preference_next_tick or 0) or false
end
---@param event EventData.on_surface_renamed
function model.on_surface_renamed(event)
    local root=ensure();local surface=game.get_surface(event.surface_index);if not surface then return end
    root.rename_pending=true
end
-- blueprint-ref: .codex/esir/blueprints/terrain-evolution.md#v2-reporting
---@param event EventData.on_tick
function model.updater(event)
    local root=peek();if not model.has_tick_work(event.tick) then return end
    local tick=event.tick;root.preference_next_tick=tick+32
    if not root.rename and root.rename_pending then
        root.rename_pending=nil
        root.rename_epoch=(root.rename_epoch or 0)+1
        root.rename={cursor=0,total=#root.player_order,remaining=#root.player_order,completed=0,epoch=root.rename_epoch,report=owners.maintenance_begin("preferences",#root.player_order,tick)}
    end
    if root.rename then
        local rename=root.rename
        rename.cursor=#root.player_order>0 and rename.cursor%#root.player_order+1 or 0
        local index=root.player_order[rename.cursor];local prefs=index and root.players[index];local player=index and game.get_player(index)
        if prefs and prefs.rename_epoch~=rename.epoch then
        prefs.rename_epoch=rename.epoch;rename.remaining=rename.remaining-1;rename.completed=rename.completed+1
        if player and prefs.selected then
            local names,changed={},false
            for name in pairs(prefs.selected) do
                local identity=prefs.identities and prefs.identities[name]
                local current=identity and identity.valid and identity.name or name
                names[#names+1]=current;if current~=name then changed=true end
            end
            if changed then model.set_preference(player,"surfaces",helpers.table_to_json(names)) end
        end
        end
        local done=rename.remaining==0
        owners.maintenance_update(rename.report,rename.completed,done,tick)
        if done then root.rename=nil end
    end
end

function model.snapshot(player)
    local root=alerts.channel_state("ecology");local prefs=root.players[player.index]
    return {pending=#root.items,anchors=root.anchors,dropped=root.dropped,live=prefs and #prefs.live or 0}
end

-- Delivery, recipient epochs and native objects belong exclusively to lib/alerts.
-- Ecology supplies semantic eligibility and keeps terrain references alive until retirement.
alerts.register_channel("ecology",{interval=32,steps=2,additions=1,creations=1,duration=3600,coalesce_ticks=600,
    once=true,max_incidents=64,max_anchors=32,max_per_player=4},{
    valid=function(receipt) return owners.valid(receipt) end,
    retain=function(receipt) owners.retain(receipt) end,
    release=function(receipt) owners.release(receipt) end,
    eligible=eligible,
    message=function(receipt)
        return {"ei-ecology.alert-message",{"ei-ecology.category-"..receipt.category},receipt.surface.name,receipt.count}
    end,
})
return model
