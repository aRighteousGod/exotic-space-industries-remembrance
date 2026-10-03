-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- blueprint-ref: .codex/esir/blueprints/admin-tools.md#interaction-restrictions
-- Per-player native permission overlays, bounded attribution census and area-order guards.
-- Natural entities retain native actions. No entity's global operable/minable flags change.
local common=require("scripts/control/admin/common")
local config=require("lib/admin-tools-config")
local lib=require("lib/lib")
local scheduler=require("lib/runtime-scheduler")
local model={}
local TARGET={open_gui=true,open_train_gui=true,open_train_station_gui=true,open_current_vehicle_gui=true,
    fast_entity_transfer=true,fast_entity_split=true,rotate_entity=true,flip_entity=true,begin_mining=true,
    paste_entity_settings=true,toggle_driving=true,start_repair=true,build=true,build_rail=true,
    toggle_selected_entity=true,copy_entity_settings=true,change_shooting_state=true,use_item=true,
    remove_cables=true,wire_dragging=true,send_spidertron=true,remote_view_entity=true,
    connect_rolling_stock=true,disconnect_rolling_stock=true}
local AREA={deconstruct=true,upgrade=true,undo=true,redo=true}
local RECORD_BUDGET=64
local WATCH_INTERVAL=30
local restoring=false
local assigning={}

local function assign_group(player,group)
    -- Native membership changes synchronously raise removal/addition callbacks.
    -- Do not adopt the temporary no-group state as an external policy change.
    assigning[player.index]=true
    local ok,failure=pcall(function()player.permission_group=group end)
    assigning[player.index]=nil
    if not ok then error(failure) end
end

local function entries() local s=common.peek();return s and s.restrictions end
local function tracking() local s=common.peek();return s and s.restriction_tracking end
local function candidate(entity)
    if not lib.entity_check(entity) then return false end
    if entity.type=="resource" or entity.type=="tree" or entity.type=="cliff" then return false end
    return entity.force.name~="enemy" and entity.force.name~="neutral"
end
local function record_for(state,entity)
    local unit=entity.unit_number
    local record=unit and state.records[unit]
    return record and record.entity==entity and record or nil
end
local function observe(entity,built)
    local state=tracking()
    if not (state and candidate(entity)) then return end
    local unit=entity.unit_number
    if not unit then return end
    local record=record_for(state,entity)
    local last=entity.last_user
    -- A placeable prototype alone is not evidence that this instance was player-built.
    -- Legacy last_user is the only native attribution available without a build event.
    if not (record or built or last) then return end
    if not record then
        local registration=script.register_on_object_destroyed(entity)
        record={entity=entity,unit=unit,registration=registration}
        state.records[unit]=record;state.registrations[registration]=unit
        state.tracked_count=state.tracked_count+1
    end
    record.built=record.built or built or last~=nil
    record.owner_index=last and last.valid and last.index or nil
end
local function protected(entity,player)
    if not candidate(entity) then return false end
    local state=tracking()
    local record=state and record_for(state,entity)
    local last=entity.last_user
    return (record and record.built or last~=nil) and (not (last and last.valid) or last.index~=player.index) or false
end
local function begin_tracking(tick)
    local root=common.state()
    if root.restriction_tracking then return root.restriction_tracking end
    local surfaces={}
    for _,surface in pairs(game.surfaces) do surfaces[#surfaces+1]=surface end
    table.sort(surfaces,function(a,b)return a.index<b.index end)
    local forces={}
    for name in pairs(game.forces) do if name~="enemy" and name~="neutral" then forces[#forces+1]=name end end
    table.sort(forces)
    local state={records={},registrations={},tracked_count=0,watch=scheduler.ensure_queue(),watchers={},
        census={surfaces=surfaces,forces=forces,surface_index=1,examined=0,chunks=0,started_tick=tick}}
    root.restriction_tracking=state
    return state
end
local function enqueue_watch(state,index,tick)
    local watcher=state.watchers[index]
    if not watcher then watcher={};state.watchers[index]=watcher end
    if not watcher.due_tick then
        watcher.due_tick=tick+WATCH_INTERVAL
        scheduler.queue_push_unique(state.watch,index,index)
        if not state.watch_due_tick or watcher.due_tick<state.watch_due_tick then state.watch_due_tick=watcher.due_tick end
    end
end
local function watch_handles(player,tick)
    local state=tracking()
    if not state then return end
    local opened=player.opened
    local entity=opened and opened.object_name=="LuaEntity" and opened or nil
    if candidate(player.selected) or candidate(entity) then enqueue_watch(state,player.index,tick) end
end
local function owned_group(player,entry)
    local group=entry.group
    if not (group and group.valid) then
        group=game.permissions.get_group("ei-admin-interaction-"..player.index) or game.permissions.create_group("ei-admin-interaction-"..player.index)
        entry.group=group;entry.signature=nil
    end
    return group
end

function model.refresh(player,tick)
    if not (player and player.valid and player.connected) or assigning[player.index] then return end
    tick=tick or game.tick
    local root=common.peek();local entry=root and root.restrictions[player.index]
    local state=tracking()
    if not state then return end
    local selected=player.selected
    local opened=player.opened
    local entity=opened and opened.object_name=="LuaEntity" and opened or nil
    observe(selected);observe(entity)
    watch_handles(player,tick)
    if not entry or root.jails[player.index] then return end
    local current_group=player.permission_group
    local deleted_fallback=entry.group and not entry.group.valid
        and current_group and current_group.valid and current_group.group_id==0
    local group=owned_group(player,entry)
    if player.permission_group~=group then
        -- Deleting our overlay moves its members to native Default. That fallback
        -- must not replace the saved policy; a distinct external assignment does.
        if not deleted_fallback then entry.previous=player.permission_group end
        entry.signature=nil;assign_group(player,group)
    end
    local blocked=protected(selected,player)
    if entity and protected(entity,player) then player.opened=nil;blocked=true end
    if blocked then
        -- Denying a new input must also end an already-held mining/shooting action.
        local controller=player.controller_type
        if (controller==defines.controllers.character or controller==defines.controllers.god or controller==defines.controllers.editor)
            and player.mining_state.mining then player.mining_state={mining=false} end
        local shooting=player.shooting_state
        if shooting.state~=defines.shooting.not_shooting then player.shooting_state={state=defines.shooting.not_shooting,position=shooting.position} end
    end
    local pending=state.census~=nil
    local signature=tostring(blocked)..":"..tostring(pending)..":"..tostring(entry.previous and entry.previous.valid and entry.previous.group_id or 0)
    if entry.signature==signature then return end
    local previous=entry.previous
    if not (previous and previous.valid) then previous=game.permissions.get_group(0) end
    for name,input in pairs(defines.input_action) do
        local allowed=(not previous or previous.allows_action(input)) and not (pending and AREA[name]) and not (blocked and TARGET[name])
        if group.allows_action(input)~=allowed then group.set_allows_action(input,allowed) end
    end
    entry.signature=signature
end

function model.set(player,enabled,tick)
    if not (player and player.valid) then return false,"Player no longer exists." end
    tick=tick or game.tick
    local root=common.state();local entry=root.restrictions[player.index]
    if enabled then
        if root.jails[player.index] then return false,"Release this player before changing interaction restrictions." end
        local state=begin_tracking(tick)
        if not entry then entry={previous=player.permission_group};root.restrictions[player.index]=entry end
        model.refresh(player,tick)
        if state.census then return true,"Interaction restriction: On. Attribution scan is pending; area tools and undo/redo are temporarily unavailable." end
    elseif entry then
        local group=entry.group
        local current_group=player.permission_group
        local deleted_fallback=group and not group.valid
            and current_group and current_group.valid and current_group.group_id==0
        if current_group==group or deleted_fallback then
            local previous=entry.previous
            if not (previous and previous.valid) then previous=game.permissions.get_group(0) end
            assign_group(player,previous)
        end
        local jail=root.jails[player.index]
        if jail and group and group.valid and jail.permission_group_id==group.group_id then
            jail.permission_group_id=entry.previous and entry.previous.valid and entry.previous.group_id or nil
        end
        root.restrictions[player.index]=nil
        if group and group.valid then group.destroy() end
        if not next(root.restrictions) then root.restriction_tracking=nil end
    end
    return true,enabled and "Interaction restriction: On (player-built entities only)." or "Interaction restriction: Off."
end

function model.on_player_event(event)
    local player=game.get_player(event.player_index);if not player then return end
    if common.enabled() and event.name==defines.events.on_player_created
        and settings.global[config.restricted_setting].value then model.set(player,true,event.tick)
    elseif entries() and entries()[player.index] and not common.enabled() then model.set(player,false,event.tick)
    elseif common.enabled() then model.refresh(player,event.tick) end
end

function model.on_gui_opened(event)
    model.on_player_event(event)
    local player=game.get_player(event.player_index)
    if player and entries() and entries()[player.index] and protected(event.entity,player) then
        player.opened=nil;player.print({"ei-admin.interaction-denied"})
        return true -- control.lua must stop before another owner opens its companion panel.
    end
    observe(event.entity)
    return false
end
function model.on_gui_closed(event)
    -- Native settings editors can change last_user without a dedicated settings event.
    observe(event.entity)
    model.on_player_event(event)
end
function model.on_built_entity(event)
    local entity=event.entity
    local actual=event.name==defines.events.on_built_entity or event.name==defines.events.on_robot_built_entity
        or event.name==defines.events.on_space_platform_built_entity
    observe(entity,actual)
end
function model.on_entity_interaction(event)
    -- Only a real unrestricted/allowed action may update the pre-order attribution cache.
    local entity=event.entity or event.destination
    local player=event.player_index and game.get_player(event.player_index)
    if not player or not (entries() and entries()[player.index]) or not protected(entity,player) then observe(entity) end
end
function model.on_object_destroyed(event)
    local state=tracking();local unit=state and state.registrations[event.registration_number]
    if not unit then return end
    local record=state.records[unit]
    if record and record.registration==event.registration_number then state.records[unit]=nil;state.tracked_count=state.tracked_count-1 end
    state.registrations[event.registration_number]=nil
end
local function notify_denied(player,tick)
    local entry=entries()[player.index]
    if entry.denied_tick~=tick then player.print({"ei-admin.interaction-denied"});entry.denied_tick=tick end
end
function model.on_area_order(event)
    if restoring then return false end
    local state=tracking();local entity=event.entity
    if not (state and candidate(entity)) then return false end
    local player=event.player_index and game.get_player(event.player_index)
    local entry=player and entries()[player.index]
    local record=record_for(state,entity)
    -- All four native order events have already replaced last_user. Use the prior cache.
    if not (entry and record and record.built and record.owner_index~=player.index) then
        if record then observe(entity) end
        return false
    end
    restoring=true
    local owner=record.owner_index and game.get_player(record.owner_index) or nil
    local id=event.name
    if id==defines.events.on_marked_for_deconstruction then entity.cancel_deconstruction(player.force)
    elseif id==defines.events.on_cancelled_deconstruction then entity.order_deconstruction(player.force)
    elseif id==defines.events.on_marked_for_upgrade then
        entity.cancel_upgrade(player.force)
        if event.previous_target then entity.order_upgrade{force=player.force,target={name=event.previous_target.name,quality=event.previous_quality and event.previous_quality.name or "normal"}} end
    elseif id==defines.events.on_cancelled_upgrade then
        entity.order_upgrade{force=player.force,target={name=event.target.name,quality=event.quality.name}}
    end
    if lib.entity_check(entity) then entity.last_user=owner end
    restoring=false
    notify_denied(player,event.tick)
    return true
end

local function census_step(state,budget,tick)
    local job=state.census
    if not job then return end
    -- Query at most one generated chunk this tick, and never replace an undrained result.
    if not job.batch then
        -- Native chunk lists include generated void outside finite maps. Skip at most64
        -- such coordinates/surface boundaries without spending an entity query on them.
        for _=1,RECORD_BUDGET do
            local surface=job.surfaces[job.surface_index]
            if not surface then
                state.completed_tick=tick;state.examined=job.examined;state.chunks=job.chunks;state.census=nil
                for index in pairs(entries() or {}) do
                    local player=game.get_player(index)
                    if player then model.refresh(player,tick);player.print("Interaction attribution scan complete; area tools are available.") end
                end
                return
            end
            if not surface.valid then job.surface_index=job.surface_index+1;job.iterator=nil
            else
                if not job.iterator then
                    job.iterator=surface.get_chunks()
                    local settings=surface.map_gen_settings
                    job.width=settings.width or 0;job.height=settings.height or 0
                end
                local chunk=job.iterator.valid and job.iterator() or nil
                if not chunk then job.surface_index=job.surface_index+1;job.iterator=nil
                elseif (job.width==0 or (chunk.x*32<job.width/2 and chunk.x*32+32>-job.width/2))
                    and (job.height==0 or (chunk.y*32<job.height/2 and chunk.y*32+32>-job.height/2)) then
                    job.batch=surface.find_entities_filtered{area={{chunk.x*32,chunk.y*32},{chunk.x*32+32,chunk.y*32+32}},force=job.forces}
                    job.cursor=1;job.chunks=job.chunks+1
                    break
                end
            end
        end
        if not job.batch then return end
    end
    for _=1,budget do
        local entity=job.batch[job.cursor]
        if not entity then job.batch=nil;job.cursor=nil;return end
        job.cursor=job.cursor+1;job.examined=job.examined+1
        observe(entity)
    end
end
function model.has_tick_work(tick)
    local state=tracking()
    return state and (state.census~=nil or (state.watch_due_tick and tick>=state.watch_due_tick)) or false
end
function model.updater(tick)
    local state=tracking();if not state then return end
    local budget=RECORD_BUDGET
    -- At most 16 active players (two exact handles each) before the census's remaining budget.
    for _=1,16 do
        local index=scheduler.queue_peek(state.watch)
        if not index then state.watch_due_tick=nil;break end
        local watcher=state.watchers[index]
        if watcher and watcher.due_tick and watcher.due_tick>tick then state.watch_due_tick=watcher.due_tick;break end
        scheduler.queue_pop(state.watch,index)
        if watcher then watcher.due_tick=nil end
        local player=game.get_player(index)
        if player and player.valid and player.connected then model.refresh(player,tick) else state.watchers[index]=nil end
        budget=budget-2
    end
    local index=scheduler.queue_peek(state.watch)
    local first=index and state.watchers[index]
    state.watch_due_tick=first and first.due_tick or nil
    census_step(state,budget,tick)
end
function model.peek_summary()
    local state=tracking();local job=state and state.census
    return {active=state~=nil,pending=job~=nil,tracked=state and state.tracked_count or 0,
        examined=job and job.examined or state and state.examined or 0,chunks=job and job.chunks or state and state.chunks or 0,
        completed_tick=state and state.completed_tick or nil}
end
function model.on_player_left(event)
    local state=tracking();if state then state.watchers[event.player_index]=nil end
end
function model.on_configuration_changed(enabled,tick)
    if enabled and next(entries() or {}) then begin_tracking(tick or game.tick) end
    for index in pairs(entries() or {}) do
        local player=game.get_player(index)
        if player then if enabled then model.refresh(player,tick) else model.set(player,false,tick) end end
    end
end
function model.on_permission_group_edited(event)
    local root=common.peek();if not root then return end
    for index,entry in pairs(root.restrictions) do
        local inherited=entry.previous
        if not (inherited and inherited.valid) then inherited=game.permissions.get_group(0) end
        if event.group==inherited or (event.other_player_index==index and event.group~=entry.group) then
            entry.signature=nil
            local player=game.get_player(index)
            if player then model.refresh(player,event.tick) end
        end
    end
end
function model.on_permission_group_deleted(event)
    local root=common.peek();if not root then return end
    for index,entry in pairs(root.restrictions) do
        if not (entry.group and entry.group.valid) or (entry.previous and not entry.previous.valid) then
            entry.signature=nil
            local player=game.get_player(index)
            if player then model.refresh(player,event.tick) end
        end
    end
end
function model.on_player_removed(event)
    model.on_player_left(event)
    local root=common.peek();local entry=root and root.restrictions[event.player_index]
    if not entry then return end
    local player=game.get_player(event.player_index)
    if player then model.set(player,false,event.tick)
    else
        root.restrictions[event.player_index]=nil
        if entry.group and entry.group.valid then entry.group.destroy() end
        if not next(root.restrictions) then root.restriction_tracking=nil end
    end
end
model.is_protected=protected
return model
