--==============================================================================
-- ESIR FILE MAP
-- owns: personal ecology preferences and bounded native alert delivery
-- loaded_by: control.lua, terrain-gui.lua
-- cadence: event admission; due service every 32 ticks while incidents exist
-- forwarded_events: settings, player and surface lifecycle
-- storage_roots: storage.ei.ecology_alerts
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration changes and surface rename
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local config=require("lib/terrain-alert-config")
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
---@field delivered table<PlayerIndex, boolean>
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
---@field items EsirEcologyIncident[]
---@field by_id table<integer, EsirEcologyIncident>
---@field coalesced table<string, integer>
---@field next_id integer
---@field next_tick MapTick
---@field cursor integer
---@field cleanup_cursor integer
---@field anchors integer
---@field dropped integer
---@field delivered integer
---@field rename_epoch integer?
---@field roster_epoch integer? Incremented by online membership transitions.
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
    return storage.ei.ecology_alerts
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
    local root=ensure();local old=root.players[player.index] or {live={}}
    if (old.online==true)~=player.connected then root.roster_epoch=(root.roster_epoch or 0)+1 end
    local connection_epoch=old.connection_epoch or 0
    if player.connected and not old.online then connection_epoch=root.roster_epoch or 0 end
    if not root.player_members[player.index] then root.player_order[#root.player_order+1]=player.index;root.player_members[player.index]=#root.player_order end
    root.interested=root.interested or {}
    for _,category in ipairs(config.categories) do if old.online and old.enabled and old[category] then root.interested[category]=math.max(0,(root.interested[category] or 0)-1) end end
    local result={live=old.live or {},online=player.connected,connection_epoch=connection_epoch,rename_epoch=old.rename_epoch or root.rename_epoch or 0}
    for _,row in ipairs(config.schema) do
        local setting=player.mod_settings[row.name];result[row.key]=setting and setting.value or row.default
        if setting and setting.value==false then result[row.key]=false end
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
    player.mod_settings[row.name]={value=value};model.refresh_preferences(player)
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
        if old and old.online then root.roster_epoch=(root.roster_epoch or 0)+1 end
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
    local p=receipt.position
    local key=receipt.surface.index..":"..math.floor(p.x/32)..":"..math.floor(p.y/32)..":"..receipt.category
    local previous=root.by_id[root.coalesced[key]]
    if previous and previous.owner==receipt.owner and owners.valid(previous) and receipt.tick-previous.tick<=600 then previous.count=previous.count+receipt.count;return true end
    if #root.items>=64 then root.dropped=root.dropped+1;return false end
    root.next_id=root.next_id+1
    local incident={id=root.next_id,category=receipt.category,surface=receipt.surface,owner=receipt.owner,generation=receipt.generation,
        position={x=p.x,y=p.y},tick=receipt.tick,count=receipt.count,expires=receipt.tick+3600,recipients={},delivered={},recipient_cursor=0,key=key,
        audience_epoch=root.roster_epoch or 0,scan_epoch=root.roster_epoch or 0}
    owners.retain(incident)
    root.items[#root.items+1]=incident;root.by_id[incident.id]=incident;root.coalesced[key]=incident.id
    return true
end
local function eligible(player,prefs,r)
    return player and player.valid and player.connected and prefs and prefs.enabled and prefs[r.category]
        and (prefs.connection_epoch or 0)<=(r.audience_epoch or 0)
        and (prefs.surfaces=="all" or prefs.selected[r.surface.name])
        and (not prefs["current-surface-only"] or player.surface==r.surface)
        and ((player.admin and prefs["allow-unrevealed"]) or player.force.is_chunk_visible(r.surface,{math.floor(r.position.x/32),math.floor(r.position.y/32)}))
end
local function remove_live(prefs,id)
    if not prefs then return end
    for i=#prefs.live,1,-1 do if prefs.live[i]==id then table.remove(prefs.live,i);return end end
end
local function cleanup(root,tick,budget)
    if #root.items==0 then return end
    root.cleanup_cursor=root.cleanup_cursor%#root.items+1
    local r=root.items[root.cleanup_cursor]
    local expired=tick>=r.expires or not owners.valid(r) or (r.anchor and not r.anchor.valid) or (r.delivery_complete and #r.recipients==0)
    -- One native removal OR one helper retirement per opportunity.
    if #r.recipients>0 then
        budget.checks=budget.checks-1;budget.used_checks=budget.used_checks+1
        r.cleanup_recipient=(r.cleanup_recipient or 0)%#r.recipients+1
        local index=r.recipients[r.cleanup_recipient];local player=game.get_player(index);local prefs=root.players[index]
        if expired or not eligible(player,prefs,r) then
            if player and player.valid and r.anchor and r.anchor.valid then player.remove_alert{entity=r.anchor,type=defines.alert_type.custom} end
            remove_live(prefs,r.id);r.delivered[index]=nil;r.recipients[r.cleanup_recipient]=r.recipients[#r.recipients];r.recipients[#r.recipients]=nil
            return
        end
    end
    if expired and #r.recipients==0 then
        if r.anchor and r.anchor.valid then r.anchor.destroy() end
        if r.anchor_counted then root.anchors=math.max(0,root.anchors-1);r.anchor_counted=nil end
        owners.release(r)
        root.by_id[r.id]=nil;if root.coalesced[r.key]==r.id then root.coalesced[r.key]=nil end
        local last=root.items[#root.items];root.items[root.cleanup_cursor]=last;root.items[#root.items]=nil
    end
end
---@param tick MapTick
---@return boolean
function model.has_tick_work(tick)
    local root=peek();return root and (#root.items>0 or root.rename~=nil or root.rename_pending) and tick>=root.next_tick or false
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
    local tick=event.tick;root.next_tick=tick+32
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
    local budget={checks=2,used_checks=0}
    cleanup(root,tick,budget)
    local added,created=false,false
    for _=1,budget.checks do
        if #root.items==0 then break end
        root.cursor=root.cursor%#root.items+1
        local r=root.items[root.cursor]
        if tick<r.expires and owners.valid(r) and not r.delivery_complete then
            -- Restart only incomplete traversals after dense roster changes.
            -- Prior recipients are deduplicated; later connections cannot receive backlog.
            if r.scan_epoch~=(root.roster_epoch or 0) then r.scan_epoch=root.roster_epoch or 0;r.recipient_cursor=0 end
            local players=game.connected_players
            r.recipient_cursor=r.recipient_cursor+1
            local player=players[r.recipient_cursor]
            if not player then r.delivery_complete=true
            else
                budget.used_checks=budget.used_checks+1
                local prefs=root.players[player.index]
                if not r.delivered[player.index] and eligible(player,prefs,r) and #prefs.live<4 then
                    if not r.anchor and not created and root.anchors<32 and prototypes.entity["ei-ecology-alert-anchor"] then
                        created=true
                        r.anchor=r.surface.create_entity{name="ei-ecology-alert-anchor",position=r.position,force="neutral"}
                        if r.anchor then r.anchor.destructible=false;root.anchors=root.anchors+1;r.anchor_counted=true end
                    end
                    if r.anchor and r.anchor.valid and not added then
                        player.add_custom_alert(r.anchor,{type="virtual",name=r.category=="wildfire" and "signal-fire" or "signal-info"},
                            {"ei-ecology.alert-message",{"ei-ecology.category-"..r.category},r.surface.name,r.count},true)
                        prefs.live[#prefs.live+1]=r.id;r.recipients[#r.recipients+1]=player.index;r.delivered[player.index]=true
                        root.delivered=root.delivered+1;added=true
                    else r.recipient_cursor=r.recipient_cursor-1 end
                end
            end
        end
    end
    root.last_service={tick=tick,recipient_checks=budget.used_checks,additions=added and 1 or 0,creations=created and 1 or 0}
end
function model.snapshot(player)
    local root=peek();local prefs=root and root.players[player.index]
    return {pending=root and #root.items or 0,anchors=root and root.anchors or 0,dropped=root and root.dropped or 0,live=prefs and #prefs.live or 0}
end
return model
