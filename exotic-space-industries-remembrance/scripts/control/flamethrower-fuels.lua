--==============================================================================
-- ESIR FILE MAP
-- owns: fuel-specific turret replacement, bounded polling and fire overlap cleanup
-- loaded_by: control.lua
-- cadence: dispatcher step 16; at most B checks and B queue visits/service
--   overlap cleanup runs only on supported creation events, in either startup mode
-- forwarded_events: rebuild, on_built_entity, on_destroyed_entity, on_object_destroyed,
--   on_blueprint, sync_force, has_tick_work, updater, on_trigger_created_entity
-- storage_roots: storage.ei.flamethrower_fuels (records, units, registrations, queues)
-- gui_ids: none; replacements defer while the entity GUI is open
-- remote_interfaces: none
-- rebuild_on: init/configuration change; never mutate storage during on_load
--==============================================================================
local ei_lib=require("lib/lib")
local scheduler=require("lib/runtime-scheduler")
local catalog=require("lib/flamethrower-fuels")
local util=require("util")
local model={}
local enabled=settings.startup[catalog.setting].value
local budget=settings.startup["ei-max_updates_per_tick"].value
local replacement_budget=budget
local transaction=false

-- Creation order defines newest, including same-tick impacts. This requires no
-- saved state or scans between impacts. Native refueling does not create a new
-- entity/event, so it retains the surviving patch's heat and growing lifetime.
-- Ground patches of the same prototype coexist; only different types compete.
---@param event EventData.on_trigger_created_entity
function model.on_trigger_created_entity(event)
    local incoming=ei_lib.get_valid_entity(event.entity)
    if not incoming then return end
    if catalog.fire_stickers[incoming.name] then
        local target=ei_lib.get_valid_entity(incoming.sticked_to)
        if not target then return end
        for _,old in pairs(target.stickers or {}) do
            if old~=incoming and ei_lib.entity_check(old) and catalog.fire_stickers[old.name] then old.destroy() end
        end
    elseif catalog.ground_fires[incoming.name] then
        local position=incoming.position
        for _,old in pairs(incoming.surface.find_entities_filtered{
            position=position,radius=1,name=catalog.ground_fire_names,type="fire"
        }) do
            if old~=incoming and ei_lib.entity_check(old) and old.name~=incoming.name then
                local other=old.position
                local dx,dy=other.x-position.x,other.y-position.y
                if dx*dx+dy*dy<=1 then old.destroy() end
            end
        end
    end
end

---@class ESIRFlameRecord
---@field id integer Stable registry key, retained across internal replacements.
---@field entity LuaEntity
---@field registration integer
---@field next_check integer
---@field retry_tick integer
---@field pending_reason string?
---@class ESIRFlameState
---@field records table<integer,ESIRFlameRecord>
---@field units table<integer,integer>
---@field registrations table<integer,integer>
---@field count integer
---@field scans table
---@field replacements table
---@field retries table<integer,integer[]>
---@field counters table<string,number>

---@return ESIRFlameState
local function state()
    storage.ei=storage.ei or {}
    local root=storage.ei.flamethrower_fuels
    if not root then
        root={records={},units={},registrations={},count=0,scans=scheduler.ensure_queue(),replacements=scheduler.ensure_queue(),retries=scheduler.ensure_delayed_buckets(),counters={checks=0,attempts=0,replaced=0,failed=0}}
        storage.ei.flamethrower_fuels=root
    end
    return root
end

---@param entity LuaEntity?
---@return boolean
local function owned(entity)
    return ei_lib.entity_check(entity) and (entity.name==catalog.base_turret or catalog.by_turret[entity.name]~=nil)
end

---@param root ESIRFlameState
---@param id integer
local function unregister(root,id)
    local record=root.records[id]
    if not record then return end
    local unit=ei_lib.get_entity_unit_number(record.entity)
    if unit then root.units[unit]=nil end
    root.registrations[record.registration]=nil
    root.records[id]=nil
    root.count=root.count-1
    -- Leave queue tombstones for bounded consumption; never scan a queue on removal.
    if root.count==0 then
        root.units={}
        scheduler.clear_queue(root.scans)
        scheduler.clear_queue(root.replacements)
        root.retries={}
    end
end

---@param event table
function model.on_built_entity(event)
    if transaction then return end
    local entity=event.entity or event.destination
    if ei_lib.entity_check(entity) and entity.type=="entity-ghost" and catalog.by_turret[entity.ghost_name] then
        -- Blueprint normalization normally handles this. Also cover ghosts raised
        -- by scripts/old blueprints, retaining settings, tags and circuit links.
        if next(entity.item_requests or {}) then return end
        local ghost=entity.surface.create_entity{name="entity-ghost",inner_name=catalog.base_turret,
            position=entity.position,direction=entity.direction,force=entity.force,quality=entity.quality,
            tags=entity.tags,create_build_effect_smoke=false}
        if not ghost then return end
        local ok=pcall(function()
            ghost.copy_settings(entity)
            for id,connector in pairs(entity.get_wire_connectors(false) or {}) do
                for _,connection in pairs(connector.connections) do
                    assert(ghost.get_wire_connector(id,true).connect_to(connection.target,false,connection.origin),"ghost-wire")
                end
            end
        end)
        if not ok then ghost.destroy();return end
        entity.destroy()
        event.entity=ghost
        if event.destination then event.destination=ghost end
        return
    end
    if not owned(entity) then return end
    if not enabled and entity.name==catalog.base_turret then return end
    local root=state()
    local id=entity.unit_number
    if root.units[id] then return end
    local registration=script.register_on_object_destroyed(entity)
    root.records[id]={id=id,entity=entity,registration=registration,next_check=event.tick or game.tick,retry_tick=0}
    root.units[id]=id
    root.registrations[registration]=id
    root.count=root.count+1
    if enabled then scheduler.queue_push(root.scans,id)
    else scheduler.queue_push_unique(root.replacements,id) end
end

---@param event table
function model.on_destroyed_entity(event)
    if transaction then return end
    local root=storage.ei and storage.ei.flamethrower_fuels
    if not root then return end
    local unit=ei_lib.get_entity_unit_number(event.entity)
    local id=unit and root.units[unit]
    if id then unregister(root,id) end
end

---@param event EventData.on_object_destroyed
function model.on_object_destroyed(event)
    local root=storage.ei and storage.ei.flamethrower_fuels
    local id=root and root.registrations[event.registration_number]
    if id then
        root.units[event.useful_id]=nil
        unregister(root,id)
    end
end

---@param entity LuaEntity
---@return string
local function desired(entity)
    if not enabled then return catalog.base_turret end
    -- Proven in 2.0.77: ordinary fluidbox(es) precede the private firing buffer.
    -- The supply pipe can contain a different fuel while old ammunition is burning.
    for index=#entity.fluidbox+1,entity.fluids_count do
        local fluid=entity.get_fluid(index)
        if fluid and fluid.amount>0 then
            local fuel=catalog.by_fluid[fluid.name]
            return fuel and fuel.turret or entity.name
        end
    end
    for index=1,#entity.fluidbox do
        local fluid=entity.get_fluid(index)
        if fluid and fluid.amount>0 then
            local fuel=catalog.by_fluid[fluid.name]
            return fuel and fuel.turret or entity.name
        end
    end
    return entity.name
end

local entity_fields={"health","orientation","kills","damage_dealt","disabled_by_script","destructible","minable","operable","rotatable","last_user","custom_status","ignore_unprioritised_targets"}
local behavior_fields={"read_ammo","circuit_enable_disable","circuit_condition","connect_to_logistic_network","logistic_condition","set_priority_list","set_ignore_unlisted_targets","ignore_unlisted_targets_condition"}

---@param source LuaEntity
---@return string?
local function unsafe_reason(source)
    if source.to_be_deconstructed() or source.to_be_upgraded() then return "construction-order" end
    if source.stickers and next(source.stickers) then return "temporary-effects" end
    if source.item_request_proxy then return "item-requests" end
    for _,player in pairs(game.connected_players) do
        if player.opened==source then return "gui-open" end
    end
end

---@param record ESIRFlameRecord
---@param target string
---@return boolean success
---@return string? reason
local function replace(record,target)
    local source=record.entity
    local unsafe=unsafe_reason(source)
    if unsafe then return false,unsafe end
    local root=state()
    -- get_fluid on a supply storage represents its connected segment. Creating
    -- an overlapping fluidbox can split that segment immediately, before a tick.
    local fluids={}
    for index=1,source.fluids_count do fluids[index]=source.get_fluid(index) end
    local pipe_connections={}
    for index=1,#source.fluidbox do pipe_connections[index]=source.fluidbox.get_pipe_connections(index) end
    local candidate
    transaction=true
    local ok,err=pcall(function()
        -- No engine tick occurs between copying fluids and committing. On rollback
        -- the candidate (including its copied fluids/wires) is simply destroyed.
        candidate=source.surface.create_entity{name=target,position=source.position,direction=source.direction,force=source.force,quality=source.quality,create_build_effect_smoke=false}
        assert(candidate,"create-failed")
        assert(#candidate.copy_settings(source)==0,"unexpected-items")
        for _,field in ipairs(entity_fields) do
            candidate[field]=source[field]
            assert(util.table.compare({candidate[field]},{source[field]}),"entity-state:"..field)
        end
        for index,prototype in pairs(source.priority_targets) do candidate.set_priority_target(index,prototype.name) end
        assert(util.table.compare(candidate.priority_targets,source.priority_targets),"priority-targets")
        local behavior=source.get_control_behavior()
        if behavior then
            local restored=candidate.get_or_create_control_behavior()
            for _,field in ipairs(behavior_fields) do
                assert(util.table.compare({restored[field]},{behavior[field]}),"circuit-state:"..field)
            end
        end
        assert(source.fluids_count==candidate.fluids_count,"fluid-storage-count")
        for index=1,source.fluids_count do
            candidate.set_fluid(index,fluids[index])
            assert(util.table.compare({candidate.get_fluid(index)},{fluids[index]}),"fluid-state:"..index)
        end
        for index,connections in ipairs(pipe_connections) do
            local restored=candidate.fluidbox.get_pipe_connections(index)
            for connection_index,connection in ipairs(connections) do
                assert(restored[connection_index].target==connection.target,"pipe-connection:"..index)
            end
        end
        for id,connector in pairs(source.get_wire_connectors(false) or {}) do
            for _,connection in pairs(connector.connections) do
                local target_connector=connection.target
                if target_connector.owner==source then target_connector=candidate.get_wire_connector(target_connector.wire_connector_id,true) end
                assert(candidate.get_wire_connector(id,true).connect_to(target_connector,false,connection.origin),"wire-state")
            end
        end
        if ei_lib.entity_check(source.shooting_target) then candidate.shooting_target=source.shooting_target end
    end)
    if not ok then
        if ei_lib.entity_check(candidate) then candidate.destroy() end
        -- The full mod set does not always reconnect the surviving overlapping
        -- fluidbox on destruction. Refresh its connections before restoring the
        -- segment snapshot; teleporting in place retains the original identity.
        source.teleport(source.position)
        for index=1,source.fluids_count do source.set_fluid(index,fluids[index]) end
        transaction=false
        return false,tostring(err)
    end
    local old_unit=source.unit_number
    if not source.destroy{raise_destroy=true} then
        candidate.destroy()
        source.teleport(source.position)
        for index=1,source.fluids_count do source.set_fluid(index,fluids[index]) end
        transaction=false
        return false,"commit-failed"
    end
    root.units[old_unit]=nil
    root.registrations[record.registration]=nil
    record.entity=candidate
    record.registration=script.register_on_object_destroyed(candidate)
    root.units[candidate.unit_number]=record.id
    root.registrations[record.registration]=record.id
    record.pending_reason=nil
    transaction=false
    script.raise_script_built{entity=candidate}
    return true
end

---@param force LuaForce
function model.sync_force(force)
    if not force or not force.valid then return end
    local modifier=force.get_turret_attack_modifier(catalog.base_turret)
    for _,fuel in ipairs(catalog.fuels) do
        force.set_turret_attack_modifier(fuel.turret,modifier)
        if force.technologies[fuel.technology] and force.technologies[fuel.technology].researched then
            force.recipes[fuel.ammo].enabled=true
        end
    end
end

function model.rebuild()
    storage.ei=storage.ei or {}
    storage.ei.flamethrower_fuels=nil
    state()
    local names={catalog.base_turret}
    for _,fuel in ipairs(catalog.fuels) do names[#names+1]=fuel.turret end
    for _,surface in pairs(game.surfaces) do
        for _,entity in pairs(surface.find_entities_filtered{name=names}) do model.on_built_entity{entity=entity,tick=game.tick} end
        for _,entity in pairs(surface.find_entities_filtered{type="entity-ghost",ghost_name=names}) do model.on_built_entity{entity=entity,tick=game.tick} end
    end
    for _,force in pairs(game.forces) do model.sync_force(force) end
end

---@param event EventData.on_player_setup_blueprint
function model.on_blueprint(event)
    local player=game.get_player(event.player_index)
    if not player then return end
    local stack=player.blueprint_to_setup
    if not (stack and stack.valid_for_read and stack.is_blueprint) then stack=player.cursor_stack end
    if not (stack and stack.valid_for_read and stack.is_blueprint) then return end
    local entities=stack.get_blueprint_entities()
    local changed=false
    for _,entity in pairs(entities or {}) do
        if catalog.by_turret[entity.name] then entity.name=catalog.base_turret;changed=true end
    end
    if changed then stack.set_blueprint_entities(entities) end
end

---@param event EventData.on_tick
---@return boolean
function model.has_tick_work(event)
    local root=storage.ei and storage.ei.flamethrower_fuels
    if not root or root.count==0 then return false end
    if not root.retries then return true end -- Upgrade earlier development saves on a writable tick.
    if scheduler.queue_length(root.replacements)>0 or next(root.retries) then return true end
    if not enabled then return false end
    local id=scheduler.queue_peek(root.scans)
    local record=id and root.records[id]
    return id~=nil and (not record or record.next_check<=event.tick)
end

---@param event EventData.on_tick
---@param service_interval integer? Ticks between dispatcher visits; defaults to one.
function model.updater(event,service_interval)
    local root=storage.ei and storage.ei.flamethrower_fuels
    if not root or root.count==0 then return end
    local tick=event.tick
    root.retries=scheduler.ensure_delayed_buckets(root.retries)
    local counters=root.counters
    counters.last_checks=0
    counters.last_attempts=0
    -- Service can skip the exact due tick. Drain overdue shared buckets so
    -- disabled-mode restoration also resumes on the next scheduled visit.
    for _,id in ipairs(scheduler.delayed_take_due_through(root.retries,tick)) do
        if root.records[id] then scheduler.queue_push_unique(root.replacements,id) end
    end
    if enabled then
        -- Reserve reads for queued work: its mandatory fresh fuel read counts
        -- against the same B cap as the regular fuel scans.
        local reserved=math.min(replacement_budget,scheduler.queue_length(root.replacements))
        for _=1,math.min(budget-reserved,math.ceil(root.count*(service_interval or 1)/60)) do
            local id=scheduler.queue_peek(root.scans)
            if not id then break end
            local record=root.records[id]
            if record and record.next_check>tick then break end
            scheduler.queue_pop(root.scans)
            if record then
                if not owned(record.entity) then unregister(root,id)
                else
                    counters.checks=counters.checks+1
                    counters.last_checks=counters.last_checks+1
                    if desired(record.entity)~=record.entity.name and record.retry_tick<=tick then scheduler.queue_push_unique(root.replacements,id) end
                    record.next_check=tick+60
                    scheduler.queue_push(root.scans,id)
                end
            end
        end
    end
    local visits=math.min(replacement_budget,scheduler.queue_length(root.replacements))
    for _=1,visits do
        local id=scheduler.queue_pop(root.replacements)
        local record=id and root.records[id]
        if record then
            if not owned(record.entity) then unregister(root,id)
            elseif record.retry_tick>tick then scheduler.delayed_schedule(root.retries,record.retry_tick,id)
            elseif enabled and counters.last_checks>=budget then scheduler.queue_push_unique(root.replacements,id)
            else
                if enabled then
                    counters.checks=counters.checks+1
                    counters.last_checks=counters.last_checks+1
                end
                local target=desired(record.entity)
                if target~=record.entity.name then
                    counters.attempts=counters.attempts+1
                    counters.last_attempts=counters.last_attempts+1
                    local ok,reason=replace(record,target)
                    if ok then
                        counters.replaced=counters.replaced+1
                        if not enabled then unregister(root,id) end
                    else
                        counters.failed=counters.failed+1
                        record.pending_reason=reason
                        record.retry_tick=tick+60
                        scheduler.delayed_schedule(root.retries,record.retry_tick,id)
                    end
                elseif not enabled then unregister(root,id) end
            end
        end
    end
end

function model.get_status()
    local root=storage.ei and storage.ei.flamethrower_fuels
    return {enabled=enabled,budget=budget,replacement_budget=replacement_budget,count=root and root.count or 0,
        pending=root and (scheduler.queue_length(root.replacements)+scheduler.delayed_item_count(root.retries)) or 0,counters=root and root.counters or {}}
end

return model
