--==============================================================================
-- ESIR FILE MAP
-- owns: native-first pipe joint collision and bounded endpoint reconciliation
-- loaded_by: control.lua
-- cadence: events; independent runtime-global maintenance and due circuit-scan budgets
-- forwarded_events: build, removal, clone, rotate, flip, paste, teleport, surfaces, settings, GUI/player lifecycle
-- storage_roots: storage.ei.factory_passage
-- gui_ids: none
-- remote_interfaces: ei_factory_passage.refresh_entity
-- rebuild_on: init, configuration change, surface import
--==============================================================================
-- blueprint: .codex/esir/blueprints/factory-passage.md#contract
local config = require("lib/factory-passage-config")
local scheduler = require("lib/runtime-scheduler")
local ei_lib = require("lib/lib")
---@class FactoryPassageEndpoint
---@field id uint
---@field entity LuaEntity
---@field name string
---@field surface uint
---@field position MapPosition
---@field box BoundingBox
---@field registration uint64
---@field joints table<string, boolean>
---@field due uint?
---@field recipe string?
---@field observed_tick MapTick? Prevent a compacted watcher queue revisiting this crafter.
---@field nearby boolean? Cached pipe proximity, updated only by reconciliation.
---@field watch_classified boolean? Nil denotes an unclassified legacy observer.
---@field watch_circuit boolean?
---@field watch_gui boolean?
---@field watch_revision integer?
---@field watch_service "shared"|"circuit"|nil One service location for both observation reasons.
---@field last_signature_tick MapTick?
---@field last_reconciled_tick MapTick?
---@class FactoryPassageGuiSession
---@field entity LuaEntity
---@field id uint
---@field surface uint
---@class FactoryPassageJoint
---@field key string
---@field a uint
---@field b uint
---@field surface uint
---@field position MapPosition
---@field horizontal boolean
---@field p MapPosition
---@field q MapPosition
---@field helper LuaEntity?
---@field registration uint64?
---@field native boolean?
---@field blocked boolean? Last occupancy query found an admitted grounded character.
---@field attempted_tick MapTick? At most one occupancy attempt per tick.
---@class FactoryPassageRebuild
---@field id integer?
---@field active boolean
---@field phase string
---@field completed integer Retired reconciliation operations; excludes occupancy retries and observers.
---@field reason string
---@class FactoryPassageState
---@field endpoints table<uint, FactoryPassageEndpoint>
---@field joints table<string, FactoryPassageJoint>
---@field registrations table<uint64, table>
---@field dirty table Shared scheduler FIFO of endpoint unit numbers.
---@field pending table Shared scheduler FIFO of canonical joint keys.
---@field watchers table Shared scheduler FIFO of crafter unit numbers.
---@field shared_watch_count integer GUI or not-yet-classified observer population.
---@field circuit_deadlines RuntimeDeadlineQueue
---@field circuit_candidate_count integer
---@field service_cursor integer Persistent next slot in the 6:1:1 class rotation.
---@field blocked_count integer Known character-occupied joints, excluding stale queue tokens.
---@field rebuild FactoryPassageRebuild?
---@field gui_sessions table<uint, FactoryPassageGuiSession> Player-indexed native entity windows.
---@field gui_viewers table<uint, table<uint, boolean>> Unit-indexed viewer sets, including machines without pipes.
---@field circuit_watch_count integer
---@field gui_watch_count integer
---@field gui_session_count integer
---@field legacy_watch_count integer
---@field gui_restore_pending boolean? Game-available restoration after adopting old state.
local module = {}
local selected = config.resolve()
local catalog
local helper_names = config.helper_names()
local epsilon = 1/256
local service_classes={"dirty","dirty","dirty","dirty","dirty","dirty","pending","watchers"}

local function data_catalog()
    if not catalog then catalog=prototypes.mod_data[config.catalog].data end
    return catalog
end

local function state()
    return storage.ei and storage.ei.factory_passage
end

local function fresh_state()
    return {endpoints={},joints={},registrations={},dirty=scheduler.ensure_queue(),pending=scheduler.ensure_queue(),
        watchers=scheduler.ensure_queue(),dirty_count=0,pending_count=0,blocked_count=0,watch_count=0,joint_count=0,helper_count=0,
        version=3,gui_sessions={},gui_viewers={},circuit_watch_count=0,gui_watch_count=0,gui_session_count=0,legacy_watch_count=0,
        shared_watch_count=0,circuit_deadlines=scheduler.ensure_deadline_queue(),circuit_candidate_count=0,
        service_cursor=1,enabled=selected.pipe_mode=="esir",configured_mode=selected.configured_mode,
        effective_mode=selected.pipe_mode,inactive_reason=selected.inactive_reason,
        counters={topology=0,processed=0,max_processed=0,created=0,destroyed=0,native=0,unsupported=0}}
end

-- A schema-only upgrade never rebuilds helpers or replaces queues/reports. Legacy
-- observers are classified as their already-budgeted queue entries are serviced.
local function ensure_observers()
    local s=state()
    if s and s.version~=3 then
        if s.version~=2 then
            s.gui_sessions={};s.gui_viewers={};s.gui_session_count=0
            s.circuit_watch_count=0;s.gui_watch_count=0;s.gui_restore_pending=true
        end
        s.legacy_watch_count=s.watch_count;s.shared_watch_count=s.watch_count
        s.circuit_deadlines=scheduler.ensure_deadline_queue();s.circuit_candidate_count=0
        s.version=3
    end
    return s
end

module.update_budget=config.update_budget

local function publish_status(tick)
    scheduler.set_module_status("factory-passage",module.status(),tick)
end

-- blueprint-ref: .codex/esir/blueprints/factory-passage.md#rebuild-reporting
local function finish_rebuild(outcome,tick)
    local s=state();local report=s and s.rebuild
    if report and report.active then
        scheduler.finish_rebuild(report.id,outcome,tick)
        report.id=nil;report.active=false;report.phase=outcome
    end
end

local function publish_rebuild(tick)
    local s=state();local report=s and s.rebuild
    if not report or not report.active then return end
    if s.dirty_count==0 and s.pending_count==0 then finish_rebuild("completed",tick);return end
    local waiting=s.dirty_count==0 and s.pending_count==s.blocked_count
    report.phase=waiting and "character-clearance" or "joint-reconciliation"
    scheduler.update_rebuild(report.id,{phase=report.phase,state=waiting and "waiting" or "running",
        completed=report.completed,total=false,unit="operations",synchronous=false,
        waiting_reason=waiting and "character-clearance" or false,eta_blocked=s.pending_count>0},tick)
end

local function begin_discovery(reason,tick)
    finish_rebuild("superseded",tick)
    return scheduler.begin_rebuild("factory-passage","world-discovery","global",
        {reason=reason,phase="discovering",completed=0,total=false,unit="operations",synchronous=true},tick)
end

local function finish_discovery(id,reason,tick)
    scheduler.finish_rebuild(id,"completed",tick)
    local s=state()
    s.rebuild={active=false,phase="completed",completed=0,reason=reason}
    if s.dirty_count>0 or s.pending_count>0 then
        s.rebuild.id=scheduler.begin_rebuild("factory-passage","joint-reconciliation","global",
            {reason=reason,phase="joint-reconciliation",completed=0,total=false,unit="operations"},tick)
        s.rebuild.active=true
        publish_rebuild(tick)
    end
    publish_status(tick)
end

---@param event EventData.on_runtime_mod_setting_changed
function module.on_settings_changed(event)
    if event.setting_type=="runtime-global" and (event.setting==config.budget_setting
        or event.setting==config.circuit_enabled_setting or event.setting==config.circuit_budget_setting) then publish_status(event.tick) end
end

---@param entity LuaEntity
---@return boolean
function module.is_helper(entity)
    return ei_lib.entity_check(entity) and entity.name:sub(1,#config.helper_prefix)==config.helper_prefix
end

local function enqueue(record, tick, defer)
    local s=state()
    if not record or not s then return end
    local added=scheduler.queue_push_unique(s.dirty,record.id)
    if added then s.dirty_count=s.dirty_count+1 end
    if added or defer then record.due=tick+1 end
end

local function recipe_signature(entity)
    local recipe,quality=entity.get_recipe()
    return (recipe and recipe.name or "")..":"..(quality and quality.name or "")..":"..entity.fluids_count
end

local function register(entity)
    local s=state()
    if not ei_lib.entity_check(entity) or not entity.unit_number then return end
    local id=entity.unit_number
    local record=s.endpoints[id]
    if not record then
        record={id=id,entity=entity,name=entity.name,surface=entity.surface.index,position=entity.position,box=entity.bounding_box,joints={}}
        record.registration=script.register_on_object_destroyed(entity)
        s.registrations[record.registration]={endpoint=id}
        s.endpoints[id]=record
    end
    return record
end

local function watch(record,circuit,gui,tick,popped)
    local s=ensure_observers()
    local previous=record.watch_service or (record.recipe and "shared" or nil)
    if record.watch_revision~=3 then
        if record.recipe then s.legacy_watch_count=s.legacy_watch_count-1 end
        record.watch_classified=true;record.watch_revision=3
        record.last_signature_tick=record.last_signature_tick or record.observed_tick
    end
    if not not record.watch_circuit~=not not circuit then s.circuit_watch_count=s.circuit_watch_count+(circuit and 1 or -1) end
    if not not record.watch_gui~=not not gui then s.gui_watch_count=s.gui_watch_count+(gui and 1 or -1) end
    record.watch_circuit=not not circuit;record.watch_gui=not not gui
    local admit=circuit or gui
    if admit and not record.recipe then
        record.recipe=recipe_signature(record.entity)
        record.last_signature_tick=tick
        s.watch_count=s.watch_count+1
    elseif not admit and record.recipe then
        record.recipe=nil
        s.watch_count=s.watch_count-1
    end
    local service=gui and "shared" or circuit and "circuit" or nil
    if previous~=service then
        if previous=="shared" then
            s.shared_watch_count=s.shared_watch_count-1
            if popped~="shared" then scheduler.queue_remove_value(s.watchers,record.id) end
        elseif previous=="circuit" then scheduler.deadline_remove(s.circuit_deadlines,record.id) end
        if service=="shared" then s.shared_watch_count=s.shared_watch_count+1 end
    end
    record.watch_service=service
    if service=="shared" then scheduler.queue_push_unique(s.watchers,record.id)
    elseif service=="circuit" then
        local fresh=math.max(record.last_signature_tick or -config.circuit_cooldown,record.last_reconciled_tick or -config.circuit_cooldown)
        scheduler.deadline_put(s.circuit_deadlines,record.id,fresh+config.circuit_cooldown)
    end
    s.circuit_candidate_count=scheduler.deadline_count(s.circuit_deadlines)
end

local function nearby_pipes(entity)
    if #data_catalog().pipe_names==0 then return {} end
    local box=entity.bounding_box
    return entity.surface.find_entities_filtered{area={{box.left_top.x-2,box.left_top.y-2},{box.right_bottom.x+2,box.right_bottom.y+2}},name=data_catalog().pipe_names}
end

local function is_crafter(entity)
    return (entity.type=="assembling-machine" or entity.type=="rocket-silo") and entity.prototype.fluidbox_prototypes[1]~=nil
end

local function circuit_recipe(entity)
    if entity.type~="assembling-machine" then return false end
    local behavior=entity.get_control_behavior()
    return behavior and behavior.valid and behavior.type==defines.control_behavior.type.assembling_machine
        and behavior.circuit_set_recipe==true or false
end

local function drop_session(index)
    local s=state();local session=s.gui_sessions[index]
    if not session then return end
    s.gui_sessions[index]=nil;s.gui_session_count=s.gui_session_count-1
    local viewers=s.gui_viewers[session.id]
    if viewers then
        viewers[index]=nil
        if not next(viewers) then s.gui_viewers[session.id]=nil end
    end
    return session
end

local function has_viewers(record)
    local s=state();local viewers=s.gui_viewers[record.id]
    if not viewers then return false end
    -- Bounded by recorded viewers of this machine, never all players or entities.
    for index in pairs(viewers) do
        local player=game.get_player(index)
        if not (player and player.valid and player.connected and player.opened==record.entity) then drop_session(index) end
    end
    return s.gui_viewers[record.id]~=nil
end

local function classify_observer(record,tick,popped)
    local valid=ei_lib.entity_check(record.entity)
    -- Old observers were admitted only near pipes. Their next real lifecycle
    -- reconciliation replaces this inherited proximity with a current query.
    if not record.watch_classified and record.recipe and record.nearby==nil then record.nearby=true end
    local eligible=valid and record.nearby and is_crafter(record.entity)
    watch(record,eligible and circuit_recipe(record.entity),eligible and has_viewers(record),tick,popped)
end

local function destroy_helper(joint)
    local s=state()
    if joint.registration then s.registrations[joint.registration]=nil;joint.registration=nil end
    if ei_lib.entity_check(joint.helper) then joint.helper.destroy();s.counters.destroyed=s.counters.destroyed+1 end
    if joint.helper then s.helper_count=s.helper_count-1;joint.helper=nil end
end

local function remove_joint(key)
    local s=state()
    local joint=s.joints[key]
    if not joint then return end
    if joint.blocked then s.blocked_count=s.blocked_count-1 end
    destroy_helper(joint)
    for _,id in ipairs{joint.a,joint.b} do
        local record=s.endpoints[id]
        if record then record.joints[key]=nil end
    end
    s.joints[key]=nil
    s.joint_count=s.joint_count-1
end

local function remove_endpoint(id,tick)
    local s=state()
    local record=s and s.endpoints[id]
    if not record then return end
    -- Destruction registrations have no entity. Notify potential recipe ports
    -- using retained placement as well as active joint ownership.
    local surface=game.surfaces[record.surface]
    if surface and data_catalog().pipes[record.name] then
        local box=record.box
        for _,other in pairs(surface.find_entities_filtered{area={{box.left_top.x-2,box.left_top.y-2},{box.right_bottom.x+2,box.right_bottom.y+2}},type={"assembling-machine","rocket-silo"}}) do
            if is_crafter(other) then enqueue(register(other),tick,true) end
        end
    end
    for key in pairs(record.joints) do
        local joint=s.joints[key]
        if joint then enqueue(s.endpoints[joint.a==id and joint.b or joint.a],tick,true);remove_joint(key) end
    end
    s.registrations[record.registration]=nil
    watch(record,false,false,tick)
    local viewers=s.gui_viewers[id]
    if viewers then for index in pairs(viewers) do drop_session(index) end end
    s.endpoints[id]=nil
end

local function point_key(point)
    return math.floor(point.x*256+0.5)..","..math.floor(point.y*256+0.5)
end

local function describe(a,b,p,q,direction)
    local dx,dy=q.x-p.x,q.y-p.y
    local horizontal=math.abs(dy)<=epsilon and math.abs(dx)>epsilon and math.abs(dx)<=1+epsilon
    local vertical=math.abs(dx)<=epsilon and math.abs(dy)>epsilon and math.abs(dy)<=1+epsilon
    if math.abs(dx)<=epsilon and math.abs(dy)<=epsilon and direction then
        horizontal=direction==4 or direction==12
        vertical=not horizontal
    end
    if not horizontal and not vertical then return end
    local left,right=a.unit_number..":"..point_key(p),b.unit_number..":"..point_key(q)
    if left>right then left,right=right,left end
    return {key=left.."/"..right,a=a.unit_number,b=b.unit_number,surface=a.surface.index,
        position={x=(p.x+q.x)/2,y=(p.y+q.y)/2},p=p,q=q,horizontal=horizontal}
end

local function heat_ports(entity)
    local prototype=entity.prototype
    local heat=prototype.heat_buffer_prototype or prototype.heat_energy_source_prototype
    local ports={}
    if not heat then return ports end
    local rotation=entity.direction/4
    if rotation%1~=0 then return ports end
    for _,connection in pairs(heat.connections) do
        local x,y=connection.position.x or connection.position[1],connection.position.y or connection.position[2]
        local direction=connection.direction
        if entity.mirroring then x=-x;direction=(-direction)%16 end
        for _=1,rotation do x,y=-y,x end
        ports[#ports+1]={x=entity.position.x+x,y=entity.position.y+y,direction=(direction+entity.direction)%16}
    end
    return ports
end

local function connected_joints(entity)
    local found={}
    local pipes=data_catalog().pipes
    local function add(target,p,q,direction)
        if not ei_lib.entity_check(target) or not target.unit_number or not (pipes[entity.name] or pipes[target.name]) then return end
        if config.excluded_receivers[entity.type] or config.excluded_receivers[target.type] then return end
        local descriptor=describe(entity,target,p,q,direction)
        if descriptor then register(target);found[descriptor.key]=descriptor
        else state().counters.unsupported=state().counters.unsupported+1 end
    end
    for index=1,entity.fluids_count do
        for _,connection in pairs(entity.get_fluid_box_pipe_connections(index) or {}) do
            if connection.connection_type=="normal" and connection.target then add(connection.target,connection.position,connection.target_position) end
        end
    end
    local ports=heat_ports(entity)
    if #ports>0 then
        for _,other in pairs(entity.heat_neighbours) do
            if pipes[entity.name] or pipes[other.name] then
                for _,p in ipairs(ports) do for _,q in ipairs(heat_ports(other)) do
                    local dx,dy=q.x-p.x,q.y-p.y
                    local forward=(p.direction==0 and -dy or p.direction==4 and dx or p.direction==8 and dy or -dx)
                    local transverse=(p.direction==0 or p.direction==8) and math.abs(dx) or math.abs(dy)
                    if (p.direction+8)%16==q.direction and forward>=-epsilon and forward<=1+epsilon and transverse<=epsilon then add(other,p,q,p.direction) end
                end end
            end
        end
    end
    return found
end

-- blueprint-ref: .codex/esir/blueprints/factory-passage.md#native-first
local function native_barrier(joint,a,b)
    -- Only ordinary pipe connections have passed the native movement fixture.
    -- Other entities may report a conservative box around a nonrectangular body.
    if a.type~="pipe" or b.type~="pipe" then return false end
    if data_catalog().walkable[a.name] or data_catalog().walkable[b.name] then return false end
    local aa,bb=a.bounding_box,b.bounding_box
    local gap
    if joint.horizontal then
        if aa.left_top.x>bb.left_top.x then aa,bb=bb,aa end
        gap=bb.left_top.x-aa.right_bottom.x
        return gap<data_catalog().character_width-epsilon and math.max(aa.left_top.y,bb.left_top.y)<=joint.position.y and math.min(aa.right_bottom.y,bb.right_bottom.y)>=joint.position.y
    end
    if aa.left_top.y>bb.left_top.y then aa,bb=bb,aa end
    gap=bb.left_top.y-aa.right_bottom.y
    return gap<data_catalog().character_height-epsilon and math.max(aa.left_top.x,bb.left_top.x)<=joint.position.x and math.min(aa.right_bottom.x,bb.right_bottom.x)>=joint.position.x
end

local function solid_box(entity,port)
    -- Walkable receivers (notably vanilla underground entrances) do not supply
    -- a solid body edge. Close the physical joint up to its connection point.
    if data_catalog().walkable[entity.name] then return {left_top=port,right_bottom=port} end
    if not config.native_pipe_types[entity.type] then
        local box=entity.bounding_box
        if not box.orientation or box.orientation==0 then return box end
        -- Diagonal bodies return an oriented rectangle, not an enclosing AABB.
        -- This square lies inside it, so every attachment has actual overlap.
        local centre={x=(box.left_top.x+box.right_bottom.x)/2,y=(box.left_top.y+box.right_bottom.y)/2}
        local angle=box.orientation*2*math.pi
        local radius=math.min(box.right_bottom.x-box.left_top.x,box.right_bottom.y-box.left_top.y)/2/(math.abs(math.cos(angle))+math.abs(math.sin(angle)))
        return {left_top={x=centre.x-radius,y=centre.y-radius},right_bottom={x=centre.x+radius,y=centre.y+radius}}
    end
    -- A native pipe bounding box encloses connector extensions and empty corners.
    -- Attach to the authored solid core, not that conservative enclosing box.
    local x1,y1,x2,y2=config.coordinates(entity.prototype.collision_box)
    local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
    for _,point in ipairs{{x1,y1},{x1,y2},{x2,y1},{x2,y2}} do
        local x,y=point[1],point[2]
        if entity.mirroring then x=-x end
        for _=1,entity.direction/4 do x,y=-y,x end
        left,top,right,bottom=math.min(left,x),math.min(top,y),math.max(right,x),math.max(bottom,y)
    end
    local p=entity.position
    return {left_top={x=p.x+left,y=p.y+top},right_bottom={x=p.x+right,y=p.y+bottom}}
end

local function set_blocked(joint,value)
    if (joint.blocked or false)~=value then
        local s=state();s.blocked_count=(s.blocked_count or 0)+(value and 1 or -1)
        joint.blocked=value
    end
end

local function install(joint,tick)
    local s=state()
    if joint.attempted_tick~=tick then set_blocked(joint,false) end
    local a,b=s.endpoints[joint.a],s.endpoints[joint.b]
    if not a or not b or not ei_lib.entity_check(a.entity) or not ei_lib.entity_check(b.entity) then set_blocked(joint,false);return true end
    if native_barrier(joint,a.entity,b.entity) then
        destroy_helper(joint)
        joint.native=true
        set_blocked(joint,false)
        return true
    end
    joint.native=false
    local surface=game.surfaces[joint.surface]
    local aa,bb=solid_box(a.entity,joint.p),solid_box(b.entity,joint.q)
    local horizontal=joint.horizontal
    local axis=horizontal and "x" or "y"
    if aa.left_top[axis]>bb.left_top[axis] then aa,bb=bb,aa end
    local from,to=aa.right_bottom[axis]-config.overlap,bb.left_top[axis]+config.overlap
    local steps=math.max(1,math.ceil((to-from)/config.helper_quantum))
    if steps>config.helper_steps then destroy_helper(joint);set_blocked(joint,false);s.counters.unsupported=s.counters.unsupported+1;return true end
    local x,y=joint.position.x,joint.position.y
    local cross=horizontal and "y" or "x"
    local middle=joint.position[cross]
    if math.max(aa.left_top[cross],bb.left_top[cross])>=middle+0.2-epsilon or math.min(aa.right_bottom[cross],bb.right_bottom[cross])<=middle-0.2+epsilon then
        destroy_helper(joint);set_blocked(joint,false);s.counters.unsupported=s.counters.unsupported+1;return true
    end
    if horizontal then x=(from+to)/2 else y=(from+to)/2 end
    local half=steps*config.helper_quantum/2
    local hx,hy=horizontal and half or 0.2,horizontal and 0.2 or half
    local helper_name=config.helper_prefix..(horizontal and "horizontal" or "vertical").."-"..steps
    if ei_lib.entity_check(joint.helper) then
        local position=joint.helper.position
        if joint.helper.name==helper_name and math.abs(position.x-x)<epsilon and math.abs(position.y-y)<epsilon then set_blocked(joint,false);return true end
        destroy_helper(joint)
    end
    if joint.attempted_tick==tick then return false end
    joint.attempted_tick=tick
    for _,character in pairs(surface.find_entities_filtered{type="character",area={{x-hx,y-hy},{x+hx,y+hy}}}) do
        if not character.is_flying and data_catalog().characters[character.name] then set_blocked(joint,true);return false end
    end
    joint.helper=surface.create_entity{name=helper_name,position={x,y},force=a.entity.force,raise_built=false,snap_to_grid=false}
    assert(joint.helper,"Factory passage joint creation failed")
    joint.helper.destructible=false
    joint.registration=script.register_on_object_destroyed(joint.helper)
    s.registrations[joint.registration]={joint=joint.key}
    s.helper_count=s.helper_count+1
    s.counters.created=s.counters.created+1
    set_blocked(joint,false)
    return true
end

local function reconcile(record,tick)
    local s=state()
    if not ei_lib.entity_check(record.entity) then remove_endpoint(record.id,tick);return end
    record.position=record.entity.position
    record.box=record.entity.bounding_box
    record.surface=record.entity.surface.index
    if is_crafter(record.entity) then
        record.nearby=#nearby_pipes(record.entity)>0
        classify_observer(record,tick)
    end
    s.counters.topology=s.counters.topology+1
    local found=connected_joints(record.entity)
    for key in pairs(record.joints) do if not found[key] then remove_joint(key) end end
    for key,descriptor in pairs(found) do
        local joint=s.joints[key]
        if not joint then
            joint=descriptor;s.joints[key]=joint;s.joint_count=s.joint_count+1
            s.endpoints[joint.a].joints[key]=true;s.endpoints[joint.b].joints[key]=true
        end
        if not install(joint,tick) then
            local added=scheduler.queue_push_unique(s.pending,key)
            if added then s.pending_count=s.pending_count+1 end
        end
    end
    record.last_reconciled_tick=tick
    if record.recipe then
        record.recipe=recipe_signature(record.entity);record.last_signature_tick=tick
        watch(record,record.watch_circuit,record.watch_gui,tick)
    end
end

---@param entity LuaEntity
---@param tick uint
---@param defer boolean? Let the current native lifecycle event finish first.
function module.refresh_entity(entity,tick,defer)
    if selected.pipe_mode~="esir" or not state() or not ei_lib.entity_check(entity) then return end
    if module.is_helper(entity) then return end
    ensure_observers()
    if #data_catalog().pipe_names==0 or config.excluded_receivers[entity.type] then return end
    if not config.type_category[entity.type] and not data_catalog().pipes[entity.name]
        and entity.fluids_count==0 and not entity.prototype.heat_buffer_prototype and not entity.prototype.heat_energy_source_prototype then return end
    local pipes=data_catalog().pipes
    if pipes[entity.name] or state().endpoints[entity.unit_number] then enqueue(register(entity),tick,defer) end
    local nearby=nearby_pipes(entity)
    if is_crafter(entity) and #nearby>0 then enqueue(register(entity),tick,defer) end
    for _,other in pairs(nearby) do
        enqueue(register(other),tick,defer)
    end
    if pipes[entity.name] then
        local box=entity.bounding_box
        for _,other in pairs(entity.surface.find_entities_filtered{area={{box.left_top.x-2,box.left_top.y-2},{box.right_bottom.x+2,box.right_bottom.y+2}},type={"assembling-machine","rocket-silo"}}) do
            if is_crafter(other) then enqueue(register(other),tick,defer) end
        end
    end
end

-- blueprint-ref: .codex/esir/blueprints/factory-passage.md#observers
---@param event EventData.on_gui_opened|EventData.on_player_controller_changed|table
function module.on_gui_opened(event)
    if selected.pipe_mode~="esir" or not state() then return end
    local s=ensure_observers();local index=event.player_index
    local previous=drop_session(index)
    if previous then
        local record=s.endpoints[previous.id]
        if record then classify_observer(record,event.tick) end
        module.refresh_entity(previous.entity,event.tick,true)
    end
    local player=game.get_player(index)
    local entity=player and player.valid and player.connected and player.opened or nil
    if not ei_lib.entity_check(entity) or not is_crafter(entity) or not entity.unit_number then return end
    -- Even a pipe-less session needs destruction ownership: no observer will
    -- otherwise wake to notice an entity silently destroyed by another script.
    local record=register(entity)
    local id=entity.unit_number
    s.gui_sessions[index]={entity=entity,id=id,surface=entity.surface.index};s.gui_session_count=s.gui_session_count+1
    s.gui_viewers[id]=s.gui_viewers[id] or {};s.gui_viewers[id][index]=true
    -- Cached admission transfers service immediately, even behind a large dirty
    -- backlog. Unknown proximity still waits for ordinary local reconciliation.
    classify_observer(record,event.tick)
    module.refresh_entity(entity,event.tick,true)
end

---@param event EventData.on_gui_closed|table
function module.on_gui_closed(event)
    if selected.pipe_mode~="esir" or not state() then return end
    local s=ensure_observers();local session=drop_session(event.player_index)
    if session then
        local record=s.endpoints[session.id]
        if record then classify_observer(record,event.tick) end
        module.refresh_entity(session.entity,event.tick,true)
    end
    if ei_lib.entity_check(event.entity) then module.refresh_entity(event.entity,event.tick,true) end
end

---@param event EventData.on_player_left_game|EventData.on_player_removed|EventData.on_player_died|table
function module.on_player_left(event)
    module.on_gui_closed{player_index=event.player_index,tick=event.tick}
end

---@param event EventData.on_singleplayer_init|EventData.on_multiplayer_init|table
function module.reconcile_gui_sessions(event)
    if selected.pipe_mode~="esir" or not state() then return end
    local s=ensure_observers()
    s.gui_restore_pending=false
    for index in pairs(s.gui_sessions) do module.on_player_left{player_index=index,tick=event.tick} end
    for _,player in pairs(game.connected_players) do module.on_gui_opened{player_index=player.index,tick=event.tick} end
end

function module.on_built(entity,event)
    if module.is_helper(entity) then entity.destroy();return end
    module.refresh_entity(entity,event.tick,true)
end

function module.on_removed(entity,event)
    if not state() or not ei_lib.entity_check(entity) then return end
    module.refresh_entity(entity,event.tick,true)
    remove_endpoint(entity.unit_number,event.tick)
end

function module.on_changed(event)
    module.refresh_entity(event.entity or event.destination,event.tick,true)
end

function module.on_teleported(event)
    local viewers={}
    if state() and ei_lib.entity_check(event.entity) then
        local s=ensure_observers()
        for index in pairs(s.gui_viewers[event.entity.unit_number] or {}) do viewers[#viewers+1]=index end
        remove_endpoint(event.entity.unit_number,event.tick)
    end
    module.refresh_entity(event.entity,event.tick,true)
    for _,index in ipairs(viewers) do module.on_gui_opened{player_index=index,tick=event.tick} end
end

function module.on_object_destroyed(event)
    local s=state()
    local registration=s and s.registrations[event.registration_number]
    if not registration then return end
    s.registrations[event.registration_number]=nil
    if registration.endpoint then remove_endpoint(registration.endpoint,event.tick)
    elseif registration.joint then
        local joint=s.joints[registration.joint]
        if joint then joint.helper=nil;s.helper_count=s.helper_count-1;enqueue(s.endpoints[joint.a],event.tick) end
    end
end

---@param tick MapTick
function module.has_work(tick)
    local s=state()
    if selected.pipe_mode~="esir" or not s then return false end
    if s.version~=3 or s.gui_restore_pending or s.dirty_count>0 or s.pending_count>0 or s.shared_watch_count>0 then return true end
    local _,due=scheduler.deadline_peek(s.circuit_deadlines)
    return config.circuit_scanner_enabled() and due~=nil and tick~=nil and due<=tick
end

---@param budget integer
---@param event EventData.on_tick
function module.updater(budget,event)
    local s=state()
    if not s or selected.pipe_mode~="esir" then return end
    ensure_observers()
    if s.gui_restore_pending then module.reconcile_gui_sessions(event) end
    local processed,retired=0,0
    budget=math.max(config.budget_min,math.min(math.floor(budget),config.update_budget(),config.budget_max))
    -- blueprint-ref: .codex/esir/blueprints/factory-passage.md#tick-flow
    -- Class quotas count attempts, including tombstones and deferred entries.
    -- The cursor survives ticks/save-load so budget one cannot starve a class.
    local share=math.ceil(budget/8)
    local quota={dirty=s.dirty_count,pending=math.min(s.pending_count,share),watchers=math.min(s.shared_watch_count,share)}
    local changed=quota.dirty>0 or quota.pending>0
    while processed<budget do
        local kind
        for _=1,8 do
            local cursor=s.service_cursor or 1
            local candidate=service_classes[cursor]
            s.service_cursor=cursor%8+1
            if quota[candidate]>0 then kind=candidate;break end
        end
        if not kind then break end
        quota[kind]=quota[kind]-1
        processed=processed+1
        local counter=kind.."_attempts"
        s.counters[counter]=(s.counters[counter] or 0)+1
        local key=scheduler.queue_pop(s[kind])
        if kind=="dirty" then
            s.dirty_count=s.dirty_count-1
            local record=s.endpoints[key]
            if record and record.due>event.tick then
                scheduler.queue_push_unique(s.dirty,key);s.dirty_count=s.dirty_count+1
            else
                if record then reconcile(record,event.tick) end
                retired=retired+1
            end
        elseif kind=="pending" then
            s.pending_count=s.pending_count-1
            local joint=s.joints[key]
            if joint and not install(joint,event.tick) then
                scheduler.queue_push_unique(s.pending,key);s.pending_count=s.pending_count+1
            else retired=retired+1 end
        else
            -- Only circuit selection or a live native GUI needs observation.
            -- Eligibility and signature reads share the same once-per-tick guard.
            local record=s.endpoints[key]
            if record and record.recipe then
                if record.observed_tick~=event.tick then
                    record.observed_tick=event.tick
                    local before_circuit,before_gui=record.watch_circuit,record.watch_gui
                    local signature=ei_lib.entity_check(record.entity) and recipe_signature(record.entity)
                    if signature then record.last_signature_tick=event.tick end
                    if signature and signature~=record.recipe then record.recipe=signature;enqueue(record,event.tick);changed=true end
                    classify_observer(record,event.tick,"shared")
                    if before_circuit~=record.watch_circuit or before_gui~=record.watch_gui then changed=true end
                else
                    scheduler.queue_push_unique(s.watchers,key)
                end
            end
        end
    end
    -- blueprint-ref: .codex/esir/blueprints/factory-passage.md#circuit-scanner
    -- The additional allowance never consumes main maintenance capacity. Future
    -- deadlines admit no work, and GUI ownership removes the circuit deadline.
    local circuit_attempts=0
    if config.circuit_scanner_enabled() then
        local limit=math.min(config.circuit_scan_budget(),scheduler.deadline_count(s.circuit_deadlines))
        while circuit_attempts<limit do
            local id=scheduler.deadline_pop_due(s.circuit_deadlines,event.tick)
            if not id then break end
            circuit_attempts=circuit_attempts+1
            local record=s.endpoints[id]
            if record and record.watch_service=="circuit" and record.recipe then
                if record.observed_tick~=event.tick then
                    record.observed_tick=event.tick
                    local signature=ei_lib.entity_check(record.entity) and recipe_signature(record.entity)
                    if signature then
                        record.last_signature_tick=event.tick
                        s.counters.circuit_scans=(s.counters.circuit_scans or 0)+1
                        if signature~=record.recipe then record.recipe=signature;enqueue(record,event.tick);changed=true end
                    end
                    local previous_circuit,previous_gui=record.watch_circuit,record.watch_gui
                    classify_observer(record,event.tick,"circuit")
                    if previous_circuit~=record.watch_circuit or previous_gui~=record.watch_gui then changed=true end
                else watch(record,record.watch_circuit,record.watch_gui,event.tick,"circuit") end
            end
        end
    end
    s.circuit_candidate_count=scheduler.deadline_count(s.circuit_deadlines)
    s.counters.circuit_attempts=(s.counters.circuit_attempts or 0)+circuit_attempts
    s.counters.circuit_max_attempts=math.max(s.counters.circuit_max_attempts or 0,circuit_attempts)
    s.counters.processed=s.counters.processed+processed
    s.counters.max_processed=math.max(s.counters.max_processed,processed)
    if s.rebuild and s.rebuild.active then s.rebuild.completed=s.rebuild.completed+retired;publish_rebuild(event.tick) end
    if changed then publish_status(event.tick) end
end

function module.on_surface_removed(event)
    local s=state()
    if not s then return end
    ensure_observers()
    for index,session in pairs(s.gui_sessions) do if session.surface==event.surface_index then drop_session(index) end end
    local ids={}
    for id,record in pairs(s.endpoints) do if record.surface==event.surface_index then ids[#ids+1]=id end end
    for _,id in ipairs(ids) do remove_endpoint(id,event.tick) end
    publish_rebuild(event.tick)
    publish_status(event.tick)
end

function module.rebuild_surface(surface,tick)
    for _,helper in pairs(surface.find_entities_filtered{name=helper_names}) do helper.destroy() end
    if selected.pipe_mode~="esir" or #data_catalog().pipe_names==0 then return end
    for _,entity in pairs(surface.find_entities_filtered{name=data_catalog().pipe_names}) do module.refresh_entity(entity,tick) end
end

function module.on_surface_imported(event)
    local discovery=begin_discovery("surface-import",event.tick)
    module.on_surface_removed(event)
    module.rebuild_surface(game.surfaces[event.surface_index],event.tick)
    module.reconcile_gui_sessions(event)
    finish_discovery(discovery,"surface-import",event.tick)
end

function module.rebuild_runtime_state(reason,tick)
    local discovery=begin_discovery(reason,tick)
    storage.ei=storage.ei or {}
    storage.ei.factory_passage=fresh_state()
    catalog=nil
    for _,surface in pairs(game.surfaces) do module.rebuild_surface(surface,tick) end
    module.reconcile_gui_sessions{tick=tick}
    finish_discovery(discovery,reason,tick)
end

---@return table Detached scalar diagnostic snapshot; never initializes storage.
function module.status()
    local s=state()
    local counters={};for key,value in pairs(s and s.counters or {}) do counters[key]=value end
    local report={};for key,value in pairs(s and s.rebuild or {}) do report[key]=value end
    local _,next_circuit_tick=scheduler.deadline_peek(s and s.circuit_deadlines)
    return {mode=selected.pipe_mode,dirty=s and s.dirty_count or 0,pending=s and s.pending_count or 0,
        watchers=s and s.watch_count or 0,joints=s and s.joint_count or 0,helpers=s and s.helper_count or 0,blocked=s and s.blocked_count or 0,counters=counters,
        configured_mode=selected.configured_mode,effective_mode=selected.pipe_mode,inactive_reason=selected.inactive_reason,
        enabled=selected.pipe_mode=="esir",update_budget=config.update_budget(),rebuild=report,
        circuit_watchers=s and s.circuit_watch_count or 0,gui_watchers=s and s.gui_watch_count or 0,
        gui_sessions=s and s.gui_session_count or 0,legacy_watchers=s and (s.legacy_watch_count or s.watch_count) or 0,
        circuit_scanner_enabled=config.circuit_scanner_enabled(),circuit_scanner_active=selected.pipe_mode=="esir" and config.circuit_scanner_enabled(),
        circuit_scan_budget=config.circuit_scan_budget(),circuit_candidates=scheduler.deadline_count(s and s.circuit_deadlines),
        next_circuit_tick=next_circuit_tick or false,shared_watchers=s and s.shared_watch_count or 0}
end

return module
