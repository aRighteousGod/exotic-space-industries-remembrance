--==============================================================================
-- ESIR FILE MAP
-- owns: storage.ei.sweeping_radar; chassis/helpers, paid scan jobs, contact reports
-- loaded_by: control.lua (sole dispatcher); sweeping-radar-gui reads this model
-- cadence: globally bounded independent stages, fair cursors, no elapsed-time debt
-- forwarded_events: build/remove/clone/blueprint/paste/teleport/force/research, repair_runtime_state
-- rebuild_on: init/configuration change; ordinary loads resume persisted cursors
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local model = {}
local config=require("lib/sweeping-radar-config")
local geometry=require("lib/sweeping-radar-geometry")
local contacts=require("lib/sweeping-radar-contacts")
local timers=require("lib/sweeping-radar-timers")
local visuals=require("scripts/control/sweeping-radar-visuals")
local scheduler=require("lib/runtime-scheduler")
local valid=ei_lib.entity_check
local RED=defines.wire_connector_id.circuit_red
local GREEN=defines.wire_connector_id.circuit_green

---@class ESIRRadarRecord
---@field id integer
---@field entity LuaEntity
---@field power LuaEntity?
---@field output LuaEntity?
---@field settings ESIRRadarSettings
---@field effective table?
---@field geometry table?
---@field batch table?
---@field job table?
---@field generation_pending boolean?
---@field work ESIRRadarContactSet
---@field report ESIRRadarContactSet
---@field retired ESIRRadarContactSet?
---@field epoch integer
---@field heading number
---@field visual ESIRRadarVisual?
---@field status string
---@field next_poll integer
---@field next_scan integer
---@field maximum number
---@field rate number
---@field cost number
---@field capability_revision integer?
---@field power_revision integer?
---@field quality_level number?
---@field quality_range integer?
---@field quality_rate number?
---@field quality_energy number?
---@field ready boolean
---@field running boolean?
---@field observations integer
---@field passes integer

local function state()
    storage.ei=storage.ei or {}
    local root=storage.ei.sweeping_radar
    if not root then
        root={version=config.version,records={},order={},indices={},registrations={},cursors={},
            jobs=0,generation_jobs=0,generation_tick=0,force_epoch=1,transfers={},transfer_order={},transfer_indices={},transfer_cursor=0,
            counters={observations=0,queries=0,samples=0,generated=0,paid_joules=0,passes=0},last={}}
        storage.ei.sweeping_radar=root
    end
    if not root.lanes or root.lane_schema~=3 then
        -- Old development saves used dense arrays. Records/jobs stay intact;
        -- normal bounded control service repopulates eligibility after conversion.
        root.lanes={}
        root.lane_schema=3
        for _,stage in ipairs{"geometry","observation","generation","aggregate","maintenance"} do
            root.lanes[stage]={nodes={},count=0}
        end
    end
    root.timers=root.timers or timers.new()
    return root
end

function model.get_state() return state() end
function model.get_record(entity)
    local root=storage.ei and storage.ei.sweeping_radar
    return root and valid(entity) and root.records[entity.unit_number] or nil
end

local function next_record(root,stage)
    local lane=root.lanes and root.lanes[stage]
    if lane then
        local id=lane.cursor
        if not id then return nil end
        lane.cursor=lane.nodes[id].next
        return root.records[id]
    end
    local order=root.order
    local count=#order
    if count==0 then return nil end
    local index=((root.cursors[stage] or 0)%count)+1
    root.cursors[stage]=index
    return root.records[order[index]]
end

-- Preserve waiting order across removals and cooldown re-entry. Swap-removing a
-- dense array lets a newly appended tail repeatedly jump ahead of old waiters.
-- Linked lanes keep O(1) mutations with no accumulated queue history.
local function lane_set(lane,id,enabled)
    local node=lane.nodes[id]
    if enabled and not node then
        if lane.cursor then
            local first=lane.nodes[lane.cursor]
            node={previous=first.previous,next=lane.cursor}
            lane.nodes[first.previous].next=id;first.previous=id
        else
            node={previous=id,next=id};lane.cursor=id
        end
        lane.nodes[id]=node
        lane.count=lane.count+1
    elseif not enabled and node then
        if node.next==id then lane.cursor=nil
        else
            lane.nodes[node.previous].next=node.next
            lane.nodes[node.next].previous=node.previous
            if lane.cursor==id then lane.cursor=node.next end
        end
        lane.nodes[id]=nil;lane.count=lane.count-1
    end
end

local function refresh_lanes(root,record,tick)
    tick=tick or root.tick or 0
    local id=record.id or record.entity.unit_number
    local g=record.geometry
    local active=record.running and not record.reset_pending
    local prepaid=record.job and record.job.paid and record.status=="power" and valid(record.power)
    lane_set(root.lanes.geometry,id,active and g and g.phase~="ready")
    local observes=(active or prepaid) and g and g.phase=="ready" and not record.batch
        and (record.effective.mode~=4 or record.pulse or record.pass_complete)
    local cooldown=observes and not record.job and not record.pass_complete and record.next_scan>tick
    lane_set(root.lanes.observation,id,observes and not cooldown and not record.generation_pending)
    lane_set(root.lanes.generation,id,observes and not cooldown and record.generation_pending)
    timers.set(root.timers,id,"scan",cooldown and record.next_scan or nil)
    lane_set(root.lanes.aggregate,id,record.batch~=nil)
    local expires
    if record.effective and record.effective.contacts==1 then
        expires=record.work.expiry[1] and record.work.expiry[1].expires
        if record.work.incomplete_until then expires=math.min(expires or record.work.incomplete_until,record.work.incomplete_until) end
    end
    timers.set(root.timers,id,"expiry",expires and expires>tick and expires or nil)
    lane_set(root.lanes.maintenance,id,(record.retired and record.retired.count>0) or record.reset_second or (expires and expires<=tick))
end

local function clear_output(record)
    if valid(record.output) then
        local behavior=record.output.get_control_behavior()
        if behavior then behavior.enabled=false end
    end
    record.output_values=nil
end

local function cancel_job(root,record,completed)
    record.generation_pending=nil
    if not completed and record.batch and record.batch.cursor>1 and record.effective and record.effective.contacts==1 then
        record.work.valid=false;record.work.incomplete=true
        record.work.incomplete_until=record.batch.tick+record.effective.expiry*60
    end
    if not completed and record.batch and record.effective and record.effective.contacts==3
        and record.work~=record.report then
        record.retired=record.work;record.work=record.report
    end
    if record.job then
        if record.job.generation_wait then root.generation_jobs=math.max(0,(root.generation_jobs or 0)-1) end
        root.jobs=math.max(0,root.jobs-1);record.job=nil
    end
    record.batch=nil
end

-- Never collect an unbounded trail of discarded sets. A reset waits for the
-- previous retired generation to drain; only the newest request is retained.
local function request_reset(root,record,tick)
    visuals.hold(record)
    record.epoch=record.epoch+1
    cancel_job(root,record)
    record.reset_pending=true
    record.geometry=nil
    record.pulse=false
    record.pulse_ack_pending=false
    record.pass_complete=false
    record.next_scan=tick
    record.status="preparing"
    clear_output(record)
end

local function finish_reset(record)
    if record.reset_second or (record.retired and record.retired.count>0) then return false end
    record.retired=record.work
    if record.report~=record.work and record.report.count>0 then
        -- The double-buffered last-pass report is retired before the working set.
        record.retired=record.report
        record.reset_second=record.work
    end
    record.work=contacts.new()
    record.report=record.effective and record.effective.contacts==2 and contacts.new() or record.work
    record.reset_pending=false
    return true
end

local function make_helper(root,record,kind)
    local entity=record.entity
    local name=kind=="power" and entity.name.."-power" or config.output
    local helper=entity.surface.create_entity{name=name,position=entity.position,force=entity.force,
        quality="normal",create_build_effect_smoke=false}
    if not helper then return false end
    helper.destructible=false;helper.minable=false;helper.operable=false
    record[kind]=helper
    local registration=script.register_on_object_destroyed(helper)
    record[kind.."_registration"]=registration
    root.registrations[registration]={id=entity.unit_number,kind=kind}
    if kind=="power" then helper.energy=0;record.power_revision=config.capability_revision
    else
        local behavior=helper.get_or_create_control_behavior()
        behavior.enabled=false
        local section=behavior.get_section(1) or behavior.add_section()
        section.group=""
        section.active=true
        local source=helper.get_wire_connector(GREEN,true)
        local target=entity.get_wire_connector(GREEN,true)
        source.connect_to(target,false,defines.wire_origin.script)
    end
    return true
end

local function destroy_helper(root,record,kind)
    local registration=record[kind.."_registration"]
    if registration then root.registrations[registration]=nil end
    if valid(record[kind]) then record[kind].destroy() end
    record[kind]=nil;record[kind.."_registration"]=nil
end

local function sync_helpers(root,record,tick)
    local entity=record.entity
    for _,kind in ipairs{"power","output"} do
        local helper=record[kind]
        if valid(helper) then
            local a,b=helper.position,entity.position
            if helper.surface~=entity.surface or a.x~=b.x or a.y~=b.y then
                -- Also recover from a script teleport that did not raise its
                -- optional lifecycle event; cached coverage belongs to the origin.
                if record.geometry then request_reset(root,record,tick) end
                destroy_helper(root,record,kind);helper=nil
            elseif helper.force~=entity.force then helper.force=entity.force end
            if kind=="power" and valid(helper) and record.power_revision~=config.capability_revision then
                -- Electric interfaces retain saved electrical properties across
                -- prototype changes. Recreate once in bounded control service,
                -- preserving joules rather than granting expanded capacity.
                local energy=helper.energy
                destroy_helper(root,record,kind)
                if not make_helper(root,record,kind) then return false end
                helper=record.power
                helper.energy=math.min(energy,config.hardware[entity.name].buffer)
            end
        end
        if not valid(helper) and not make_helper(root,record,kind) then return false end
    end
    return true
end

local function unregister(root,id)
    local record=root.records[id]
    if not record then return end
    visuals.destroy(record)
    cancel_job(root,record)
    clear_output(record)
    root.registrations[record.registration]=nil
    destroy_helper(root,record,"power");destroy_helper(root,record,"output")
    local index=root.indices[id]
    local last=root.order[#root.order]
    root.order[index]=last;root.indices[last]=index
    root.order[#root.order]=nil;root.indices[id]=nil;root.records[id]=nil
    for _,lane in pairs(root.lanes or {}) do lane_set(lane,id,false) end
    timers.cancel(root.timers,id..":scan");timers.cancel(root.timers,id..":expiry")
end

local function register(entity,tick,preferences,energy)
    local root,id=state(),entity.unit_number
    if root.records[id] then return root.records[id] end
    entity.disabled_by_script=true
    local work=contacts.new()
    local record={entity=entity,id=id,settings=config.copy_settings(preferences),epoch=1,
        work=work,report=work,heading=0,status="preparing",next_poll=tick,next_scan=tick,
        last_power_tick=tick,ready=false,observations=0,passes=0,created_tick=tick,
        registration=script.register_on_object_destroyed(entity),force_epoch=0,
        pass_started=tick,last_publish=tick,pulse=false,last_trigger=false}
    root.records[id]=record
    root.order[#root.order+1]=id;root.indices[id]=#root.order
    root.registrations[record.registration]={id=id,kind="entity"}
    sync_helpers(root,record,tick)
    if energy and valid(record.power) then record.power.energy=math.min(energy,config.hardware[entity.name].buffer) end
    return record
end

local function transfer_key(entity)
    local p=entity.position
    return entity.surface.index..":"..entity.force.index..":"..p.x..":"..p.y
end

local function remove_transfer(root,key)
    local index=root.transfer_indices[key]
    if index then
        local last=root.transfer_order[#root.transfer_order]
        root.transfer_order[index]=last;root.transfer_indices[last]=index
        root.transfer_order[#root.transfer_order]=nil;root.transfer_indices[key]=nil
    end
    root.transfers[key]=nil
end

function model.on_built_entity(event)
    local entity=ei_lib.get_valid_entity(event.destination or event.entity)
    if not entity then return end
    local placement=entity.name:match("^(ei%-.-radar)%-placement$")
    if placement and config.hardware[placement] then
        local health=entity.health
        local replacement=entity.surface.create_entity{name=placement,position=entity.position,
            force=entity.force,quality=entity.quality,direction=entity.direction,
            fast_replace=true,spill=false,create_build_effect_smoke=false}
        if not replacement then return end
        replacement.health=health
        entity=replacement
        if event.destination then event.destination=entity else event.entity=entity end
    end
    if event.destination and config.art[entity.name:match("^(ei%-.-radar)%-visual%-") or ""] then
        entity.destroy();return
    end
    if entity.type=="entity-ghost" then
        if config.art[entity.ghost_name] then visuals.ghost(state(),entity) end
        return
    end
    if event.destination and (entity.name==config.output or entity.name==config.names[1].."-power" or entity.name==config.names[2].."-power") then
        entity.destroy();return
    end
    if not config.hardware[entity.name] then return end
    local root=state()
    local source=model.get_record(event.source)
    local preferences=source and source.settings or event.tags and event.tags[config.tag]
    local key=transfer_key(entity)
    local transfer=root.transfers[key]
    local energy
    if not preferences and transfer and transfer.expires>=event.tick and transfer.name==entity.name
        and transfer.quality==entity.quality.name then
        preferences,energy=transfer.settings,transfer.energy
    end
    remove_transfer(root,key)
    register(entity,event.tick,preferences,energy)
end

function model.on_pre_build(event)
    local player=game.get_player(event.player_index)
    local stack=player and player.cursor_stack
    if not(stack and stack.valid_for_read and config.hardware[stack.name]) then return end
    local entities=player.surface.find_entities_filtered{position=event.position,name=config.names,limit=1}
    local record=entities[1] and model.get_record(entities[1])
    if record then record.replacement={name=stack.name,quality=stack.quality.name,expires=event.tick+2} end
end

function model.on_marked_for_upgrade(event)
    local record=model.get_record(event.entity)
    if record then
        local target,quality=event.entity.get_upgrade_target()
        record.upgrade=target and config.hardware[target.name] and {name=target.name,quality=quality.name} or nil
    end
end
function model.on_cancelled_upgrade(event)
    local record=model.get_record(event.entity)
    if record then record.upgrade=nil end
end

function model.on_destroyed_entity(event)
    local record=model.get_record(event.entity)
    if not record then return end
    local root=state()
    local replacement=record.upgrade or (record.replacement and record.replacement.expires>=event.tick and record.replacement)
    local mined=event.name==defines.events.on_player_mined_entity or event.name==defines.events.on_robot_mined_entity
    if replacement and mined then
        local key=transfer_key(record.entity)
        root.transfers[key]={settings=config.copy_settings(record.settings),name=replacement.name,
            quality=replacement.quality,expires=event.tick+600,
            energy=valid(record.power) and record.power.energy or 0}
        if not root.transfer_indices[key] then
            root.transfer_order[#root.transfer_order+1]=key
            root.transfer_indices[key]=#root.transfer_order
        end
    end
    unregister(root,record.entity.unit_number)
end

function model.on_object_destroyed(event)
    local root=storage.ei and storage.ei.sweeping_radar
    local registration=root and root.registrations[event.registration_number]
    if not registration then return end
    if registration.kind=="ghost-art" then
        local ghost=root.ghost_art and root.ghost_art[registration.id]
        if ghost and ghost.object.valid then ghost.object.destroy() end
        if root.ghost_art then root.ghost_art[registration.id]=nil end
        root.registrations[event.registration_number]=nil
        return
    end
    local record=root.records[registration.id]
    root.registrations[event.registration_number]=nil
    if not record then return end
    if registration.kind=="entity" then unregister(root,registration.id)
    elseif record[registration.kind.."_registration"]==event.registration_number then
        -- A bounded repair may already have replaced this invalid helper before
        -- the engine delivers its delayed destruction notification.
        record[registration.kind]=nil;record.ready=false;clear_output(record)
    end
end

---@param record ESIRRadarRecord
---@param settings ESIRRadarSettings
---@param tick integer
function model.set_settings(record,settings,tick)
    record.settings=config.copy_settings(settings)
    record.next_poll=tick
end

function model.on_settings_pasted(event)
    local source,destination=model.get_record(event.source),model.get_record(event.destination)
    if source and destination then model.set_settings(destination,source.settings,event.tick) end
end

function model.on_blueprint(event)
    local player=game.get_player(event.player_index)
    if not player then return end
    local stack=event.record
    if not stack then
        stack=event.stack or player.blueprint_to_setup
        if not(stack and stack.valid_for_read and stack.is_blueprint) then stack=player.cursor_stack end
        if not(stack and stack.valid_for_read and stack.is_blueprint) then return end
    end
    for index,entity in pairs(event.mapping.get()) do
        local record=model.get_record(entity)
        if record then stack.set_blueprint_entity_tag(index,config.tag,config.copy_settings(record.settings)) end
    end
end

function model.on_teleported(event)
    local record=model.get_record(event.entity)
    if record then request_reset(state(),record,event.tick);record.next_poll=event.tick end
end

function model.on_surface_deleted(event)
    -- Destruction registrations do the per-entity teardown; invalid handles are
    -- also consumed by the normal four-record service, without a surface scan.
    state().force_epoch=state().force_epoch+1
end
function model.on_force_changed()
    local root=state();root.force_epoch=root.force_epoch+1
end
model.on_forces_merged=model.on_force_changed
function model.on_research_finished(event)
    if event.research and event.research.name:match("^ei%-radar%-") then model.on_force_changed() end
end
model.on_scripted_research_burst=model.on_force_changed

function model.rebuild(tick)
    local root=state()
    root.force_epoch=root.force_epoch+1
    -- Discovery is configuration/init only, never steady-state scanning.
    for _,surface in pairs(game.surfaces) do
        for _,entity in pairs(surface.find_entities_filtered{name=config.names}) do register(entity,tick) end
        for _,entity in pairs(surface.find_entities_filtered{type="entity-ghost",ghost_name=config.names}) do visuals.ghost(root,entity) end
    end
end

local function research(record,root)
    local force=record.entity.force
    local previous=record.research_signature
    local levels={}
    for _,branch in ipairs(config.branches) do
        local level=0
        for candidate=1,3 do
            local technology=force.technologies["ei-radar-"..branch.."-"..candidate]
            if technology and technology.researched then level=candidate end
        end
        levels[branch]=level
    end
    local hardware=config.hardware[record.entity.name]
    record.quality_level=record.entity.quality.level
    record.quality_range,record.quality_rate,record.quality_energy=config.quality_effects(record.quality_level)
    record.maximum=hardware.range+config.range_bonus[levels.range+1]+record.quality_range
    record.rate=hardware.rate*config.rate_bonus[levels.capacity+1]*record.quality_rate
    record.cost=hardware.joules*config.energy_bonus[levels.efficiency+1]*record.quality_energy
    record.capability_revision=config.capability_revision
    record.hostiles={}
    for _,other in pairs(game.forces) do
        if other~=force and other.name~="neutral" and force.name~="neutral"
            and not force.get_friend(other) and not other.get_friend(force)
            and not force.get_cease_fire(other) and not other.get_cease_fire(force) then
            record.hostiles[#record.hostiles+1]=other.name
        end
    end
    record.research_signature=force.index..":"..record.maximum..":"..record.rate..":"..record.cost..":"..table.concat(record.hostiles,",")
    record.force_index=force.index;record.force_epoch=root.force_epoch
    return previous~=record.research_signature
end

function model.valid_signal(signal)
    if type(signal)~="table" or type(signal.name)~="string" then return false end
    local kind=signal.type or "item"
    local catalog=kind=="item" and prototypes.item or kind=="fluid" and prototypes.fluid or kind=="virtual" and prototypes.virtual_signal
    return catalog and catalog[signal.name]~=nil and (not signal.quality or prototypes.quality[signal.quality]~=nil) or false
end

local function read_settings(record)
    local manual=record.settings
    local result={}
    local invalid=false
    local function input(field,fallback)
        local override=manual.overrides[field.key]
        if override and override.enabled then
            local signal=override.signal or {type="virtual",name="signal-"..field.signal}
            if not model.valid_signal(signal) then invalid=true;return 0 end
            return record.entity.get_signal(signal,RED)
        end
        return fallback
    end
    result.mode=input(config.fields[1],manual.mode)
    if result.mode~=math.floor(result.mode) or result.mode<1 or result.mode>5 then return nil,"invalid" end
    local mode=manual.modes[result.mode]
    for _,field in ipairs(config.fields) do
        if field.key~="mode" then result[field.key]=input(field,mode[field.key] or manual[field.key] or 0) end
        local value=result[field.key]
        if field.angle then result[field.key]=value%360
        elseif field.key=="radius" then result.radius=math.min(record.maximum,math.floor(value))
        elseif field.min and (value<field.min or value>field.max or value~=math.floor(value)) then return nil,"invalid" end
    end
    if invalid or result.radius<1 or result.near>=result.radius then return nil,"invalid" end
    if result.direction==0 and result.mode~=2 and result.mode~=5 then return nil,"invalid" end
    return result
end

local function changed(a,b)
    if not a then return true end
    for _,key in ipairs{"mode","radius","near","start","stop","bearing","direction","policy","contacts","expiry"} do
        if a[key]~=b[key] then return true end
    end
    return false
end

local function service_control(root,record,tick)
    if not valid(record.entity) then unregister(root,record.entity.unit_number);return end
    if tick<record.next_poll then return end
    record.next_poll=tick+config.poll_ticks
    record.entity.disabled_by_script=true
    if not sync_helpers(root,record,tick) then record.ready=false;record.status="helper";return end
    if record.force_epoch~=root.force_epoch or record.force_index~=record.entity.force.index
        or record.capability_revision~=config.capability_revision or record.quality_level~=record.entity.quality.level then
        if research(record,root) then request_reset(root,record,tick) end
    end
    record.last_power_tick=tick
    -- Standby is a native fixed load on this same consumer; only observations
    -- are debited in Lua. Delayed service must not invent an unpayable idle debt.
    local idle=config.hardware[record.entity.name].idle/60
    local power=record.power
    record.ready=power.energy>=idle
    local effective,error=read_settings(record)
    if not effective then
        record.status=error;record.running=false;cancel_job(root,record);clear_output(record);return
    end
    if changed(record.effective,effective) then request_reset(root,record,tick) end
    record.effective=effective
    if record.reset_pending and not finish_reset(record) then record.status="maintenance";record.running=false;return end
    if not record.geometry then
        record.geometry=geometry.new(effective,record.entity.position)
        local limits=record.entity.surface.map_gen_settings
        record.geometry.map_width=limits.width;record.geometry.map_height=limits.height
        record.cursor=effective.direction==-1 and -1 or 1
        record.reverse=effective.direction==-1
        record.pass_started=tick;record.pass_observations=0;record.pass_visited=0
    end
    local trigger=effective.trigger>0
    if record.last_trigger~=nil and trigger and not record.last_trigger and not record.pulse and effective.mode==4 then
        record.pulse=true;record.pulse_ack_pending=true;record.pass_started=tick
    end
    record.last_trigger=trigger
    record.running=record.ready and effective.run>0 and effective.speed>0 and not record.entity.frozen
        and not record.entity.to_be_deconstructed()
    if not record.running then
        record.status=not record.ready and "power" or record.entity.frozen and "frozen" or "paused"
        if effective.run<=0 or effective.speed<=0 or record.entity.frozen or record.entity.to_be_deconstructed() then
            -- Explicit suspension cancels unfinished work; accepted energy is spent.
            -- The cursor remains on that cell, with no elapsed-time catch-up.
            cancel_job(root,record)
        end
        record.next_scan=tick;clear_output(record)
    elseif record.geometry.phase~="ready" then record.status="preparing"
    elseif effective.mode==4 and not record.pulse then record.status="armed"
    elseif record.generation_pending or (record.job and record.job.generation_wait) then record.status="generation"
    else record.status="scanning" end
end

---@param record ESIRRadarRecord
---@param tick integer
function model.trigger(record,tick)
    if record.effective and record.effective.mode==4 and not record.pulse then
        record.pulse=true;record.pulse_ack_pending=true;record.pass_started=tick;record.next_scan=tick
        refresh_lanes(state(),record,tick)
    end
end

local function finish_pass(root,record,tick)
    if record.effective.contacts==2 and record.retired and record.retired.count>0 then return false end
    record.passes=record.passes+1;root.counters.passes=root.counters.passes+1
    record.last_pass_tick=tick
    record.pass_ticks=tick-record.pass_started
    record.pass_started=tick
    if record.effective.contacts==2 then
        record.retired=record.report~=record.work and record.report or nil
        record.report=record.work;record.report.valid=true;record.report.published_tick=tick
        record.work=contacts.new()
    end
    if record.effective.mode==2 and record.effective.direction==0 then record.reverse=not record.reverse end
    record.cursor=record.reverse and record.geometry.count or 1
    record.pass_visited=0;record.pass_observations=0
    if record.effective.mode==4 then record.pulse=false end
    return true
end

local function advance(root,record,tick,observed)
    if observed then
        record.heading=record.job.cell.angle
        visuals.completed(record,tick)
        record.observations=record.observations+1
        record.pass_observations=record.pass_observations+1
        root.counters.observations=root.counters.observations+1
        record.last_observation=tick
    end
    record.pass_visited=record.pass_visited+1
    record.cursor=record.cursor+(record.reverse and -1 or 1)
    cancel_job(root,record,true)
    if record.effective.speed<=0 then
        record.interval_fraction=0;record.next_scan=tick
    else
        local interval=60/(record.rate*record.effective.speed/100)+(record.interval_fraction or 0)
        local whole=math.max(1,math.floor(interval))
        record.interval_fraction=interval-whole
        record.next_scan=tick+whole
    end
    if record.cursor<1 or record.cursor>record.geometry.count then record.pass_complete=true end
end

local function begin_job(root,record,tick,generation_turn)
    local g=record.geometry
    if not valid(record.power) or not valid(record.output) then return end
    local prepaid=record.job and record.job.paid and record.status=="power" and valid(record.power)
    if (not record.running and not prepaid) or record.reset_pending or not g or g.phase~="ready" or record.batch then return end
    if record.pass_complete then
        if finish_pass(root,record,tick) then record.pass_complete=false end
        return
    end
    if record.effective.mode==4 and not record.pulse then return end
    if record.cursor==-1 then record.cursor=g.count end
    if g.count==0 then record.status="empty";return end
    if not record.job then
        if tick<record.next_scan then return end
        if not valid(record.power) or record.power.energy<record.cost then
            record.status="power";record.ready=false;clear_output(record);return
        end
        if root.jobs>=config.budget.jobs then record.status="capacity";return end
        local cell=g.cells[record.cursor]
        if not cell then record.pass_complete=true;return end
        record.job={cell=cell,epoch=record.epoch,paid=false}
        root.jobs=root.jobs+1
        record.wait_started=tick
    end
    local job=record.job
    if job.epoch~=record.epoch then cancel_job(root,record);return end
    local surface,force=record.entity.surface,record.entity.force
    local cell=job.cell
    local generated=surface.is_chunk_generated({cell.x,cell.y})
    if generated then record.generation_pending=nil end
    local width,height=g.map_width or 0,g.map_height or 0
    local outside=(width>0 and (cell.x*32>=width/2 or cell.x*32+32<=-width/2))
        or (height>0 and (cell.y*32>=height/2 or cell.y*32+32<=-height/2))
    if outside then
        if root.last.geometry>=config.budget.geometry then return end
        root.last.geometry=root.last.geometry+1
        advance(root,record,tick,false);record.next_scan=tick;return
    end
    if record.effective.policy==0 and (not generated or not force.is_chunk_charted(surface,{cell.x,cell.y})) then
        if root.last.geometry>=config.budget.geometry then return end
        root.last.geometry=root.last.geometry+1
        advance(root,record,tick,false);record.next_scan=tick;return
    end
    if not generated and not job.requested and not generation_turn then
        -- Fair observation visits alone can phase-lock with the 30-tick gate.
        -- Every new request joins the separate admission lane, behind waiters.
        cancel_job(root,record);record.generation_pending=true;record.status="generation";return
    end
    if not job.paid then
        if not valid(record.power) or record.power.energy<record.cost then
            record.status="power";record.ready=false;clear_output(record);return
        end
        record.power.energy=record.power.energy-record.cost
        root.counters.paid_joules=root.counters.paid_joules+record.cost
        job.paid=true
    end
    if not generated then
        record.status="generation"
        if not job.requested and tick>=root.generation_tick then
            surface.request_to_generate_chunks({cell.x*32+16,cell.y*32+16},0)
            job.requested=true
            job.requested_tick=tick
            job.generation_wait=true
            record.generation_pending=nil
            root.generation_jobs=(root.generation_jobs or 0)+1
            root.generation_tick=tick+config.budget.generation_interval
            root.counters.generated=root.counters.generated+1
            root.last.generation=root.last.generation+1
        end
        if job.requested_tick and tick-job.requested_tick>config.budget.generation_timeout then
            -- A finite/unsupported surface may never fulfill a request. Release
            -- the shared slot and mark incomplete coverage, without retry debt.
            record.work.incomplete=true
            advance(root,record,tick,false)
        end
        return
    end
    force.chart(surface,{{cell.x*32,cell.y*32},{cell.x*32+31.99,cell.y*32+31.99}})
    root.last.chart=root.last.chart+1
    local samples={}
    local found={}
    if #record.hostiles>0 then
        found=surface.find_entities_filtered{area={{cell.x*32,cell.y*32},{cell.x*32+32,cell.y*32+32}},
            force=record.hostiles,is_military_target=true,limit=config.query_limit}
        root.last.query=root.last.query+1;root.counters.queries=root.counters.queries+1
    end
    for index=1,math.min(config.query_limit-1,#found) do
        local target=found[index]
        if valid(target) and target.destructible and target.health and target.health>0 then
            local p=target.position
            local x,y=p.x-g.position.x,p.y-g.position.y
            if math.floor(p.x/32)==cell.x and math.floor(p.y/32)==cell.y and geometry.contains(g,x,y) then
                samples[#samples+1]={id=tostring(target.unit_number or (target.name..":"..p.x..":"..p.y)),
                    x=p.x,y=p.y,tick=tick,distance2=x*x+y*y,bearing=geometry.angle(x,y)}
            end
        end
    end
    record.batch={samples=samples,cursor=1,tick=tick,incomplete=#found>=config.query_limit,epoch=record.epoch}
    root.last.snapshot=root.last.snapshot+#found
    if record.effective.contacts==3 then
        if record.retired and record.retired.count>0 then record.batch.wait_reset=true
        else record.work=contacts.new() end
    end
end

local function aggregate(root,record,tick)
    local batch=record.batch
    if not batch then return false end
    if batch.epoch~=record.epoch then cancel_job(root,record);return true end
    if record.effective.contacts==1 and contacts.has_expired(record.work,tick) then return false end
    if batch.wait_reset then
        if record.retired and record.retired.count>0 then return false end
        record.work=contacts.new();batch.wait_reset=nil
    end
    local sample=batch.samples[batch.cursor]
    if sample then
        local expires=record.effective.contacts==1 and sample.tick+record.effective.expiry*60 or 1e30
        if expires>tick then contacts.observe(record.work,sample,expires) end
        batch.cursor=batch.cursor+1;root.counters.samples=root.counters.samples+1
    else
        record.work.valid=true;record.work.tick=batch.tick;record.work.published_tick=tick
        record.work.incomplete=record.work.incomplete or batch.incomplete
        if record.effective.contacts==1 and (batch.incomplete or record.work.count>=config.contact_limit) then
            record.work.incomplete_until=batch.tick+record.effective.expiry*60
        end
        if record.effective.contacts==3 then record.retired=record.report;record.report=record.work end
        advance(root,record,tick,true)
    end
    return true
end

local function maintain(record,tick)
    if record.retired and contacts.retire_one(record.retired) then return true end
    if record.reset_second then record.retired=record.reset_second;record.reset_second=nil;return true end
    if record.effective and record.effective.contacts==1 then
        if record.work.incomplete_until and tick>=record.work.incomplete_until then
            record.work.incomplete=false;record.work.incomplete_until=nil
        end
        return contacts.expire_one(record.work,tick)
    end
    return false
end

---@param record ESIRRadarRecord
---@param tick integer
---@return table
function model.report_snapshot(record,tick)
    local root=state()
    local usable=record.running and record.ready and not record.reset_pending and record.force_epoch==root.force_epoch
        and record.effective and not contacts.has_expired(record.report,tick)
        and not (record.batch and record.effective.contacts==1)
    local report=contacts.snapshot(record.report,tick)
    report.valid=usable and report.valid or false
    return report
end

local function publish(root,record,tick)
    if not valid(record.output) or not valid(record.entity) then return end
    local behavior=record.output.get_control_behavior()
    if not behavior then return end
    local section=behavior.get_section(1) or behavior.add_section()
    local report=model.report_snapshot(record,tick)
    local live=report.valid
    -- A short pulse can finish between publication turns. Acknowledge acceptance
    -- for at least one publication so a held circuit trigger cannot miss it.
    local values={record.ready and 1 or 0,record.running and record.ready and (record.status=="scanning" or record.pulse_ack_pending) and 1 or 0,
        live and 1 or 0,live and report.count or 0,live and report.bearing or 0,live and report.distance or 0,
        report.age,live and report.contact_age or 0,live and report.incomplete and 1 or 0,math.floor(record.heading+0.5)%360,
        live and report.sample_age or 0}
    for index,key in ipairs(config.outputs) do
        if not record.output_values or record.output_values[index]~=values[index] then
            if values[index]==0 then section.clear_slot(index)
            else section.set_slot(index,{value={type="virtual",name="ei-radar-"..key,quality="normal"},min=values[index]}) end
        end
    end
    behavior.enabled=true
    if record.pulse_ack_pending and values[2]==1 then record.pulse_ack_pending=false end
    record.output_values=values;record.last_publish=tick
    record.entity.custom_status={diode=record.running and defines.entity_status_diode.green or defines.entity_status_diode.yellow,
        label={"sweeping-radar.status-"..record.status}}
end

function model.has_tick_work()
    local root=storage.ei and storage.ei.sweeping_radar
    return root and (#root.order>0 or #root.transfer_order>0) or false
end

---@param event EventData.on_tick
function model.updater(event)
    local root=state()
    local tick=event.tick
    root.tick=tick
    root.last={control=0,visual=0,geometry=0,chart=0,query=0,snapshot=0,aggregate=0,maintenance=0,publish=0,generation=0}
    for _=1,config.budget.control do
        local record=next_record(root,"control")
        if not record then break end
        if valid(record.entity) then
            service_control(root,record,tick);refresh_lanes(root,record)
            if visuals.service(record,tick) then root.last.visual=root.last.visual+1 end
        else unregister(root,root.order[root.cursors.control]) end
        root.last.control=root.last.control+1
    end
    -- Wakeups share the maintenance allowance. No population scan is required
    -- for cooldowns or expiry, and no profiler value influences eligibility.
    for _=1,config.budget.maintenance do
        local deadline=timers.take_due(root.timers,tick)
        if not deadline then break end
        local record=root.records[deadline.id]
        if record and valid(record.entity) then refresh_lanes(root,record,tick) end
        root.last.maintenance=root.last.maintenance+1
    end
    for _=1,config.budget.geometry do
        local record=next_record(root,"geometry")
        if not record then break end
        if record.geometry and not record.reset_pending and geometry.step(record.geometry) then root.last.geometry=root.last.geometry+1 end
        refresh_lanes(root,record)
    end
    for _=1,config.budget.observation do
        -- At most one admission turn, charged to the same observation allowance.
        -- Rotate this cursor only when admission is possible, never while gated.
        local generation_turn=_==1 and tick>=root.generation_tick
            and root.jobs<config.budget.jobs and (root.generation_jobs or 0)<config.budget.generation_jobs
        local record=generation_turn and next_record(root,"generation") or nil
        generation_turn=record~=nil
        record=record or next_record(root,"observation")
        if not record then break end
        if valid(record.entity) and record.force_epoch==root.force_epoch then begin_job(root,record,tick,generation_turn) end
        if valid(record.entity) then refresh_lanes(root,record) end
    end
    for _=1,config.budget.aggregate do
        local record=next_record(root,"aggregate")
        if not record then break end
        if aggregate(root,record,tick) then root.last.aggregate=root.last.aggregate+1 end
        if valid(record.entity) then refresh_lanes(root,record) end
    end
    for _=1,config.budget.maintenance-root.last.maintenance do
        local record=next_record(root,"maintenance")
        if not record then break end
        if maintain(record,tick) then root.last.maintenance=root.last.maintenance+1 end
        if valid(record.entity) then refresh_lanes(root,record) end
    end
    for _=1,config.budget.publish do
        local record=next_record(root,"publish")
        if not record then break end
        publish(root,record,tick);root.last.publish=root.last.publish+1
    end
    if #root.transfer_order>0 then
        root.transfer_cursor=(root.transfer_cursor%#root.transfer_order)+1
        local key=root.transfer_order[root.transfer_cursor]
        local transfer=root.transfers[key]
        if not transfer or transfer.expires<tick then remove_transfer(root,key) end
    end
    scheduler.set_module_status("sweeping-radar",{radars=#root.order,jobs=root.jobs,
        observations=root.counters.observations,generated=root.counters.generated})
end
-- blueprint-ref: .codex/esir/blueprints/sweeping-radar.md#admin-repair
-- Discovery preserves paid jobs, report buffers, geometry and helper joules.
---@param reason string
---@param tick MapTick
function model.repair_runtime_state(reason,tick)
    local root=state()
    for id,record in pairs(root.records) do
        if not valid(record.entity) then unregister(root,id)
        else sync_helpers(root,record,tick) end
    end
    model.rebuild(tick)
    return true
end

return model
