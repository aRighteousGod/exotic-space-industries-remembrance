--==============================================================================
-- ESIR FILE MAP
-- owns: all ESIR native alert delivery, recipients, anchors and retirement
-- loaded_by: control.lua and alert-producing runtime modules
-- cadence: operational 32 steps/tick; ecology 2 recipient checks/32 ticks
-- forwarded_events: player, setting, force and surface lifecycle
-- storage_roots: storage.ei.alerts
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: versioned initialization and configuration change
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-alerts.md#contract
local catalog = require("lib/alert-catalog")
local icon_sets = require("lib/alert-icon-sets")
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local model = {}
local channels, channel_order = {}, {}
local VERSION = 1
local PRESENTATION_VERSION = 1 -- Independent of the completed legacy ecology adoption.

---@class EsirAlertContext
---@field entity LuaEntity? Persistent condition target; positional incidents capture it before destruction.
---@field source_id integer|string?
---@field force LuaForce?
---@field surface LuaSurface?
---@field position MapPosition?
---@field message LocalisedString?
---@field count integer?
---@field category string?
---@field owner table? Ecology receipt owner; identity is significant.
---@field generation integer?

---@class EsirAlertPolicy
---@field interval integer
---@field steps integer
---@field additions integer
---@field creations integer
---@field duration integer
---@field coalesce_ticks integer
---@field once boolean?
---@field max_incidents integer?
---@field max_anchors integer?
---@field max_per_player integer?

---@class EsirAlertHooks
---@field valid fun(record: table): boolean
---@field eligible fun(player: LuaPlayer, preferences: table, record: table): boolean
---@field retain fun(record: table)?
---@field release fun(record: table)?
---@field message fun(record: table): LocalisedString?

---@class EsirAlertRecord: EsirAlertContext
---@field id integer
---@field slot integer Dense removal index, unrelated to stable identity.
---@field key string
---@field alert_id string
---@field mode "condition"|"retained"|"once"
---@field tick MapTick
---@field expires MapTick?
---@field audience_epoch integer?
---@field recipients PlayerIndex[] Currently owned native alerts.
---@field delivered table<PlayerIndex, MapTick|boolean> Once-only history survives recipient cleanup; legacy values are booleans.
---@field anchor LuaEntity?
---@field cancelled boolean?
---@field legacy_icon SignalID?
---@field recipient_icons table<PlayerIndex, SignalID>? Actual native presentation, never inferred from current preferences.
---@field recipient_messages table<PlayerIndex, LocalisedString>?
---@field presentation_checked table<PlayerIndex, string>? Includes absent native alerts so dismissed incidents stay absent.

---@class EsirAlertChannelState
---@field items EsirAlertRecord[]
---@field by_id table<integer, EsirAlertRecord>
---@field coalesced table<string, integer>
---@field sources table<integer|string, table<integer, boolean>>
---@field players table<PlayerIndex, table>
---@field next_tick MapTick
---@field roster_epoch integer

local function peek()
    return storage.ei and storage.ei.alerts
end

local function ensure()
    storage.ei = storage.ei or {}
    storage.ei.alerts = storage.ei.alerts or {version=VERSION, channels={}}
    return storage.ei.alerts
end

---@param id string
---@param policy EsirAlertPolicy
---@param hooks EsirAlertHooks
function model.register_channel(id, policy, hooks)
    assert(not channels[id], "Duplicate ESIR alert channel: "..id)
    assert(policy.interval > 0 and policy.steps > 0 and hooks.valid and hooks.eligible)
    channels[id] = {policy=policy, hooks=hooks}
    channel_order[#channel_order + 1] = id
end

---@param id string
---@return EsirAlertChannelState
function model.channel_state(id)
    assert(channels[id], "Unregistered ESIR alert channel: "..tostring(id))
    local root = ensure()
    local state = root.channels[id]
    if not state then
        state = {items={},by_id={},coalesced={},sources={},players={},next_id=0,next_tick=0,cursor=0,cleanup_cursor=0,
            anchors=0,dropped=0,delivered=0,roster_epoch=0}
        root.channels[id] = state
    end
    state.roster_epoch = state.roster_epoch or 0
    return state
end

---@param player LuaPlayer
---@param alert_id string
---@return boolean
function model.player_allows(player, alert_id)
    local definition = catalog.by_id[alert_id]
    if not definition or not player or not player.valid then return false end
    local values = player.mod_settings
    if not values then return false end
    local setting = values[definition.setting_name]
    if not setting or setting.value ~= true then return false end
    local master = definition.master and values[definition.master]
    return not definition.master or (master ~= nil and master.value == true)
end

---@param id string
---@param player LuaPlayer
function model.refresh_player(id, player)
    local state = model.channel_state(id)
    local prefs = state.players[player.index] or {live={},setting_epochs={}}
    if (prefs.online == true) ~= player.connected then
        state.roster_epoch = state.roster_epoch + 1
        if player.connected then prefs.connection_epoch = state.roster_epoch end
    end
    local force_index = player.force.index
    if prefs.force_index and prefs.force_index ~= force_index then
        state.roster_epoch = state.roster_epoch + 1
        prefs.connection_epoch = state.roster_epoch
    end
    prefs.online, prefs.force_index = player.connected, force_index
    prefs.connection_epoch = prefs.connection_epoch or 0
    prefs.live, prefs.setting_epochs = prefs.live or {}, prefs.setting_epochs or {}
    state.players[player.index] = prefs
    return prefs
end

---@param event table
function model.on_player_event(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    icon_sets.normalize_map_default()
    icon_sets.normalize_player(player)
    for _, id in ipairs(channel_order) do model.refresh_player(id, player) end
end

---@param player LuaPlayer
---@param value string Registered set or the one-time startup-default action.
---@param tick MapTick
---@return string
function model.set_icon_set(player, value, tick)
    player.mod_settings[icon_sets.setting_name] = {value=value}
    model.on_settings_changed{player_index=player.index,setting_type="runtime-per-user",setting=icon_sets.setting_name,tick=tick}
    return icon_sets.player_set(player)
end

---@param event EventData.on_runtime_mod_setting_changed
function model.on_settings_changed(event)
    if event.setting_type ~= "runtime-per-user" then return end
    local player = event.player_index and game.get_player(event.player_index)
    if event.setting == icon_sets.setting_name then
        -- Cosmetic changes neither advance audience epochs nor reopen once-only delivery.
        -- Existing live records already have bounded maintenance; idle channels stay idle.
        -- A nil player index edits this map's defaults for future players.
        icon_sets.normalize_map_default()
        if player then icon_sets.normalize_player(player) end
        return
    end
    if not player then return end
    for _, id in ipairs(channel_order) do
        local state = model.channel_state(id)
        local prefs = model.refresh_player(id, player)
        -- A type/master enabled later never replays missed incidents. Surface and
        -- visibility changes retain ecology's existing eligibility-window policy.
        local relevant = false
        for _, definition in ipairs(catalog.entries) do
            if definition.channel == id and (definition.setting_name == event.setting or definition.master == event.setting) then relevant = true; break end
        end
        if relevant then
            state.roster_epoch = state.roster_epoch + 1
            prefs.setting_epochs[event.setting] = state.roster_epoch
        end
    end
end

function model.on_player_removed(event)
    local root = peek(); if not root then return end
    for _, state in pairs(root.channels) do
        state.players[event.player_index] = nil
        state.roster_epoch = state.roster_epoch + 1
    end
end

-- blueprint-ref: .codex/esir/blueprints/runtime-alerts.md#migration
---@param id string
---@param legacy table Ecology root; arrays and receipt objects are moved, never copied/retained again.
function model.adopt_legacy(id, legacy)
    local state = model.channel_state(id)
    if legacy.alert_delivery_version == VERSION then return state end
    assert(#state.items == 0, "Cannot overwrite a populated ESIR alert channel")
    for _, key in ipairs{"items","by_id","coalesced","next_id","next_tick","cursor","cleanup_cursor","anchors","dropped","delivered","roster_epoch"} do
        if legacy[key] ~= nil then state[key] = legacy[key] end
        legacy[key] = nil
    end
    state.players = legacy.players or {}
    for index, record in ipairs(state.items) do
        record.slot = index
        record.alert_id = record.alert_id or "ecology-"..record.category
        record.mode = "once"
        record.legacy_icon = record.anchor and {type="virtual",name=record.category == "wildfire" and "signal-fire" or "signal-info"} or nil
    end
    legacy.alert_delivery_version = VERSION
    return state
end

---@param tick MapTick
function model.initialize(tick)
    local root=ensure()
    root.presentation_version=PRESENTATION_VERSION
    icon_sets.refresh_runtime()
    icon_sets.normalize_map_default()
    for _, player in pairs(game.players) do icon_sets.normalize_player(player) end
    for _, id in ipairs(channel_order) do
        model.channel_state(id)
        for _, player in pairs(game.players) do model.refresh_player(id, player) end
    end
end

local function definition_for(channel, alert_id, tick)
    local definition = catalog.by_id[alert_id]
    if definition and definition.channel == channel and channels[channel] then return definition end
    scheduler.bump_counter("alerts", "undeclared", 1, tick)
    return nil
end

local function context_snapshot(context)
    local entity = lib.get_valid_entity(context.entity)
    local surface = context.surface or (entity and entity.surface)
    local position = context.position or (entity and entity.position)
    if not surface or not surface.valid or not position then return nil end
    return {surface=surface, position={x=position.x or position[1],y=position.y or position[2]},
        force=context.force or (entity and entity.force), source_id=context.source_id or (entity and entity.unit_number),
        message=context.message, count=context.count or 1, category=context.category, owner=context.owner,
        generation=context.generation}
end

local function insert_record(state, record, tick)
    state.next_id = state.next_id + 1
    record.id, record.slot = state.next_id, #state.items + 1
    record.tick, record.audience_epoch = tick, state.roster_epoch
    record.recipients, record.delivered, record.delivered_counts, record.recipient_cursor = {}, {}, {}, 0
    state.items[record.slot], state.by_id[record.id], state.coalesced[record.key] = record, record, record.id
    if record.source_id then
        local source = state.sources[record.source_id] or {}
        state.sources[record.source_id] = source; source[record.id] = true
    end
end

---@param channel string
---@param alert_id string
---@param context EsirAlertContext
---@param tick MapTick
---@return boolean
function model.record_incident(channel, alert_id, context, tick)
    local definition = definition_for(channel, alert_id, tick)
    if not definition then return false end
    local record = context_snapshot(context); if not record then return false end
    local state, registration = model.channel_state(channel), channels[channel]
    local policy, hooks = registration.policy, registration.hooks
    if channel == "operational" and (not record.force or not record.force.valid) then return false end
    local force_key = channel == "operational" and record.force.index..":" or ""
    -- Ecology retains its legacy category key so post-upgrade reports coalesce
    -- with adopted records without re-retaining or delivering duplicates.
    local key = force_key..record.surface.index..":"..math.floor(record.position.x/32)..":"..math.floor(record.position.y/32)..":"..(policy.once and definition.category or alert_id)
    local previous = state.by_id[state.coalesced[key]]
    if previous and not previous.cancelled and hooks.valid(previous) and tick < previous.expires
        and (not policy.once or (previous.owner == record.owner and previous.generation == record.generation and tick-previous.tick <= policy.coalesce_ticks)) then
        previous.count = previous.count + record.count
        if not policy.once then
            previous.expires = tick + policy.duration
            -- A genuinely new report can notify the current audience. Enabling
            -- a setting or reconnecting alone never replays the retained record.
            previous.audience_epoch = state.roster_epoch
            previous.next_delivery_tick = tick
        end
        return true
    end
    if policy.max_incidents and #state.items >= policy.max_incidents then state.dropped=state.dropped+1; return false end
    record.key, record.alert_id = key, alert_id
    record.mode, record.expires = policy.once and "once" or "retained", tick + policy.duration
    if hooks.retain then hooks.retain(record) end
    insert_record(state, record, tick)
    return true
end

local function remove_live(prefs, id)
    if not prefs then return end
    for i=#prefs.live,1,-1 do if prefs.live[i] == id then table.remove(prefs.live,i); return end end
end

local function delivered_icon(record, index)
    local saved=record.recipient_icons and record.recipient_icons[index]
    if saved then return saved end
    -- Old unified deliveries used Original, regardless of the newly selected default.
    if record.legacy_icon and type(record.delivered[index])=="boolean" then return record.legacy_icon end
    return {type="virtual",name=catalog.by_id[record.alert_id].icon_signal}
end

local function find_native(player, record, entity, icon)
    local messages=record.recipient_messages
    local previous=messages and messages[player.index]
    local missing=not prototypes.virtual_signal[icon.name]
    local expected=missing and previous and helpers.table_to_json(previous)
    local alerts=player.get_alerts{entity=entity,type=defines.alert_type.custom,surface=record.surface}
    for _,types in pairs(alerts) do
        for _,rows in pairs(types) do
            for _,native in pairs(rows) do
                if (native.icon and native.icon.type==icon.type and native.icon.name==icon.name)
                    or (missing and expected and native.message and helpers.table_to_json(native.message)==expected) then
                    return native
                end
            end
        end
    end
end

local function remember_presentation(record, index, icon, message, selected)
    record.recipient_icons=record.recipient_icons or {}
    record.recipient_messages=record.recipient_messages or {}
    record.presentation_checked=record.presentation_checked or {}
    record.recipient_icons[index]=icon
    record.recipient_messages[index]=lib.copy_localised_string(message)
    record.presentation_checked[index]=selected
end

local function remove_native(player, record, native)
    local entity = lib.get_valid_entity(record.anchor or record.entity)
    if not player or not player.valid or not entity then return end
    local definition = catalog.by_id[record.alert_id]
    if definition then
        local icon=delivered_icon(record,player.index)
        if prototypes.virtual_signal[icon.name] then
            player.remove_alert{entity=entity,type=defines.alert_type.custom,icon=icon}
        else
            -- Removed providers can leave a saved signal that is no longer a valid API argument.
            native=native or find_native(player,record,entity,icon)
            if native and native.message then
                player.remove_alert{entity=native.target or entity,surface=record.surface,type=defines.alert_type.custom,message=native.message}
            end
        end
    end
end

local function retire(state, record, hooks)
    if record.anchor and record.anchor.valid then record.anchor.destroy() end
    if record.anchor_counted then state.anchors=math.max(0,state.anchors-1) end
    if hooks.release then hooks.release(record) end
    state.by_id[record.id] = nil
    if state.coalesced[record.key] == record.id then state.coalesced[record.key] = nil end
    local source = record.source_id and state.sources[record.source_id]
    if source then source[record.id]=nil; if not next(source) then state.sources[record.source_id]=nil end end
    local last = state.items[#state.items]
    state.items[record.slot] = last; last.slot = record.slot; state.items[#state.items] = nil
end

local function cancel_record(state, record)
    record.cancelled = true
    for _, index in ipairs(record.recipients) do
        remove_native(game.get_player(index),record)
        remove_live(state.players[index],record.id)
    end
    record.recipients, record.delivered, record.delivered_counts = {}, {}, {}
    record.recipient_icons,record.recipient_messages,record.presentation_checked={},{},{}
end

---@param channel string
---@param source_id integer|string
---@param tick MapTick
function model.clear_source(channel, source_id, tick)
    local root = peek(); local state = root and root.channels[channel]
    local source = state and state.sources[source_id]
    if not source then return end
    -- Explicit UI/source removal is immediate; background retirement remains bounded.
    for id in pairs(source) do
        local record = state.by_id[id]
        if record then cancel_record(state,record) end
    end
end

---@param channel string
---@param key integer|string
---@param alert_id string
---@param active boolean
---@param context EsirAlertContext
---@param tick MapTick
function model.set_condition(channel, key, alert_id, active, context, tick)
    if not definition_for(channel, alert_id, tick) then return false end
    local state = model.channel_state(channel)
    local identity = "condition:"..alert_id..":"..tostring(key)
    local old = state.by_id[state.coalesced[identity]]
    if not active then
        if old and not old.cancelled then cancel_record(state,old) end
        return true
    end
    local entity = lib.get_valid_entity(context.entity)
    if not entity then return false end
    if old and not old.cancelled and old.entity ~= entity then cancel_record(state,old) end
    if old and not old.cancelled then
        old.entity,old.force,old.surface,old.position = entity,entity.force,entity.surface,{x=entity.position.x,y=entity.position.y}
        old.message = context.message
        return true
    end
    local record = context_snapshot(context); if not record then return false end
    record.entity,record.key,record.alert_id,record.mode = entity,identity,alert_id,"condition"
    record.source_id = context.source_id or key
    insert_record(state,record,tick)
    return true
end

local function eligible(state, player, record, hooks)
    local prefs = player and state.players[player.index]
    if not player or not player.valid or not player.connected or not prefs or not model.player_allows(player,record.alert_id) then return false end
    if record.mode ~= "condition" and (prefs.connection_epoch or 0) > (record.audience_epoch or 0) then return false end
    if record.mode ~= "condition" then
        local definition = catalog.by_id[record.alert_id]
        local epochs = prefs.setting_epochs or {}
        if (epochs[definition.setting_name] or 0) > (record.audience_epoch or 0) or (definition.master and (epochs[definition.master] or 0) > (record.audience_epoch or 0)) then return false end
    end
    return hooks.eligible(player,prefs,record)
end

local function expired(record, tick, hooks)
    return record.cancelled or not record.surface.valid or (record.expires and tick >= record.expires)
        or (record.anchor and not record.anchor.valid) or not hooks.valid(record)
end

local function cleanup_one(state, tick, hooks, budget)
    if #state.items == 0 then return end
    state.cleanup_cursor = state.cleanup_cursor % #state.items + 1
    local record = state.items[state.cleanup_cursor]
    budget.steps = budget.steps - 1
    local dead = expired(record,tick,hooks) or (record.mode == "once" and record.delivery_complete and #record.recipients == 0)
    if #record.recipients > 0 then
        budget.checks=budget.checks+1
        record.cleanup_recipient=(record.cleanup_recipient or 0)%#record.recipients+1
        local index=record.recipients[record.cleanup_recipient]
        local player=game.get_player(index)
        if dead or not eligible(state,player,record,hooks) then
            remove_native(player,record);remove_live(state.players[index],record.id)
            if record.mode ~= "once" then
                record.delivered[index]=nil
                if record.delivered_counts then record.delivered_counts[index]=nil end
            end
            record.recipients[record.cleanup_recipient]=record.recipients[#record.recipients];record.recipients[#record.recipients]=nil
            if record.recipient_icons then record.recipient_icons[index]=nil end
            if record.recipient_messages then record.recipient_messages[index]=nil end
            if record.presentation_checked then record.presentation_checked[index]=nil end
            return
        end
        local selected=icon_sets.player_set(player)
        record.presentation_checked=record.presentation_checked or {}
        if record.presentation_checked[index]~=selected then
            if delivered_icon(record,index).name==icon_sets.signal_name(selected,record.alert_id) then
                record.presentation_checked[index]=selected
            else
                return {record=record,player=player,selected=selected}
            end
        end
    end
    if dead and #record.recipients == 0 then retire(state,record,hooks) end
end

-- Uses the already admitted cleanup recipient check. First deliveries spend the
-- channel's addition allowance before this cosmetic candidate gets an opportunity.
local function refresh_presentation(state, candidate, registration, tick, budget)
    if not candidate or budget.additions>=registration.policy.additions then return end
    local record,player,selected=candidate.record,candidate.player,candidate.selected
    if state.by_id[record.id]~=record or expired(record,tick,registration.hooks)
        or record.presentation_checked[player.index]==selected then return end
    local target=lib.get_valid_entity(record.entity or record.anchor)
    if not target then return end
    local native=find_native(player,record,target,delivered_icon(record,player.index))
    record.presentation_checked[player.index]=selected
    if not native then return end -- Logical ownership does not imply a still-visible native alert.
    local icon={type="virtual",name=icon_sets.signal_name(selected,record.alert_id)}
    remove_native(player,record,native)
    player.add_custom_alert(target,icon,native.message,true)
    remember_presentation(record,player.index,icon,native.message,selected)
    budget.additions=budget.additions+1
    state.presentation_updates=(state.presentation_updates or 0)+1
end

local function deliver_one(state, record, registration, tick, budget)
    local policy,hooks = registration.policy,registration.hooks
    if expired(record,tick,hooks) then return end
    if record.delivery_complete then
        if record.mode == "once" or tick < (record.next_delivery_tick or 0) then return end
        record.delivery_complete=false;record.recipient_cursor=0
    end
    if record.scan_epoch ~= state.roster_epoch then record.scan_epoch=state.roster_epoch;record.recipient_cursor=0 end
    record.recipient_cursor=record.recipient_cursor+1
    local player=game.connected_players[record.recipient_cursor]
    if not player then record.delivery_complete=true;record.next_delivery_tick=tick+120;return end
    budget.checks=budget.checks+1
    local delivered=record.delivered[player.index]
    if delivered and (record.mode == "once" or tick-(type(delivered)=="number" and delivered or record.tick)<120) then return end
    local prefs=state.players[player.index]
    if not eligible(state,player,record,hooks) or (not delivered and policy.max_per_player and #prefs.live>=policy.max_per_player) then return end
    local target=lib.get_valid_entity(record.entity or record.anchor)
    if not target and not record.entity then
        if budget.creations>=policy.creations or (policy.max_anchors and state.anchors>=policy.max_anchors) then
            record.recipient_cursor=record.recipient_cursor-1;return
        end
        budget.creations=budget.creations+1
        record.anchor=record.surface.create_entity{name="ei-alert-anchor",position=record.position,force="neutral"}
        target=lib.get_valid_entity(record.anchor)
        if target then target.destructible=false;state.anchors=state.anchors+1;record.anchor_counted=true end
    end
    if not target or budget.additions>=policy.additions then record.recipient_cursor=record.recipient_cursor-1;return end
    local definition=catalog.by_id[record.alert_id]
    local message=hooks.message and hooks.message(record) or {"ei-alerts.incident",record.message or definition.localised_name,record.surface.name,record.count}
    record.delivered_counts=record.delivered_counts or {}
    -- Coalesced text changes must replace the previous native message rather
    -- than leave two matching targets visible until the old message expires.
    local selected=icon_sets.player_set(player)
    local icon={type="virtual",name=icon_sets.signal_name(selected,record.alert_id)}
    if delivered and (record.delivered_counts[player.index] ~= record.count or delivered_icon(record,player.index).name~=icon.name) then remove_native(player,record) end
    player.add_custom_alert(target,icon,message,true)
    remember_presentation(record,player.index,icon,message,selected)
    if not delivered then prefs.live[#prefs.live+1]=record.id;record.recipients[#record.recipients+1]=player.index end
    record.delivered[player.index]=tick;record.delivered_counts[player.index]=record.count
    state.delivered=state.delivered+1;budget.additions=budget.additions+1
end

---@param channel string
---@param tick MapTick
function model.service_channel(channel,tick)
    local root=peek();local state=root and root.channels[channel]
    if not state or #state.items==0 or tick<state.next_tick then return end
    local registration=channels[channel];local policy=registration.policy
    state.next_tick=tick+policy.interval
    local budget={steps=policy.steps,checks=0,additions=0,creations=0}
    local cosmetic=cleanup_one(state,tick,registration.hooks,budget)
    -- Ecology budgets recipient checks, including cleanup; empty retirement does not spend a recipient check.
    if policy.once then budget.steps=policy.steps-budget.checks end
    local visits=math.min(budget.steps,math.max(1,#state.items))
    if policy.once then visits=budget.steps end
    for _=1,visits do
        if #state.items==0 then break end
        state.cursor=state.cursor%#state.items+1
        deliver_one(state,state.items[state.cursor],registration,tick,budget)
    end
    refresh_presentation(state,cosmetic,registration,tick,budget)
    state.last_service={tick=tick,recipient_checks=budget.checks,additions=budget.additions,creations=budget.creations,
        steps=policy.once and budget.checks or policy.steps-budget.steps+visits}
end

---@param tick MapTick
function model.has_tick_work(tick)
    local root=peek();if not root then return false end
    for _,id in ipairs(channel_order) do
        local state=root.channels[id]
        if state and #state.items>0 and tick>=state.next_tick then return true end
    end
    return false
end

function model.updater(event)
    for _,id in ipairs(channel_order) do model.service_channel(id,event.tick) end
end

function model.on_surface_removed(event)
    local root=peek();if not root then return end
    for _,state in pairs(root.channels) do
        for _,record in ipairs(state.items) do
            if not record.surface.valid or record.surface.index==event.surface_index then record.cancelled=true end
        end
    end
end

function model.on_forces_merged(event)
    local root=peek();if not root then return end
    local state=root.channels.operational
    if state then
        for _,record in ipairs(state.items) do
            if not record.force.valid or record.force.index==event.source_index then record.force=event.destination end
        end
    end
    for _,player in pairs(game.players) do model.on_player_event{player_index=player.index} end
end

model.register_channel("operational",{interval=1,steps=32,additions=32,creations=32,duration=3600,coalesce_ticks=3600},{
    valid=function(record)
        if not record.force or not record.force.valid then return false end
        if record.mode~="condition" then return true end
        local entity=lib.get_valid_entity(record.entity)
        if not entity then return false end
        record.force = entity.force
        return true
    end,
    eligible=function(player,_,record) return record.force.valid and player.force==record.force end,
    message=function(record)
        if record.mode=="condition" then return record.message end
        return {"ei-alerts.incident",record.message or catalog.by_id[record.alert_id].localised_name,record.surface.name,record.count}
    end,
})
return model
