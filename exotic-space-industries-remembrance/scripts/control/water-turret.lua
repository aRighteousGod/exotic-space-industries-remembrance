--==============================================================================
-- ESIR FILE MAP
-- owns: water turret registry, electrical interlock, event-fed hot/cold service and modes
-- loaded_by: control.lua (sole dispatcher)
-- cadence: 15-tick power guards; 32 hot jobs, 8 cold slices, 32 wakes, 1 seed query/tick
-- forwarded_events: build/remove/clone/teleport/force/surface/blueprint/GUI/rebuild, repair_runtime_state
-- storage_roots: storage.ei.water_turret
-- gui_ids: ei-water-turret-console (relative turret GUI)
-- remote_interfaces: none
-- rebuild_on: init/configuration change; no storage mutation during on_load
--==============================================================================
-- blueprint: .codex/esir/blueprints/firefighting-and-water-turret.md#contract
-- blueprint-ref: .codex/esir/blueprints/firefighting-and-water-turret.md#rebuild-reporting
local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("lib/firefighting-config")
local firefighting = require("scripts/control/firefighting")
local fire_index = require("scripts/control/water-turret-fire-index")
local model = {}
local GUI = "ei-water-turret-console"
local nearest = settings.startup[config.targeting_setting].value=="nearest"
model.created_effect=config.created_effect

---@class ESIRWaterRecord
---@field id integer
---@field entity LuaEntity
---@field power LuaEntity?
---@field registration integer
---@field power_registration integer?
---@field mode integer
---@field weapon_fires boolean
---@field powered boolean
---@field owns_inhibit boolean
---@field fire LuaEntity?
---@field phase string
---@field generation integer
---@field next_hot MapTick?
---@field aim_checkpoint MapTick?
---@field available boolean?
---@field cold_queued boolean?
---@field wake_again boolean?
---@field search table?
---@field coverage table[]?
---@field range number
---@field position MapPosition
---@field surface integer
---@field next_pulse integer
---@field status string?
---@class ESIRWaterState
---@field records table<integer,ESIRWaterRecord>
---@field registrations table<integer,integer>
---@field count integer
---@field power_due table
---@field schema integer
---@field hot_due table
---@field hot_batches table
---@field cold_queue table
---@field index ESIRWaterFireIndex
---@field counters table<string,number>

---@return ESIRWaterState
local function state()
    storage.ei = storage.ei or {}
    local root = storage.ei.water_turret
    if not root then
        root = {schema=2,records={},registrations={},count=0,power_due={},hot_due={},
            hot_batches=scheduler.ensure_queue(),cold_queue=scheduler.ensure_queue(),index=fire_index.new(),
            counters={searches=0,pulses=0,power_checks=0,fire_admissions=0,candidate_visits=0,
                maintenance_visits=0,compactions=0,wake_visits=0,hot_services=0,cold_slices=0,acquisitions=0}}
        storage.ei.water_turret = root
    end
    return root
end

---@param entity LuaEntity?
---@return ESIRWaterRecord?
local function record_for(entity)
    local root = storage.ei and storage.ei.water_turret
    local unit = ei_lib.get_entity_unit_number(entity)
    return root and unit and root.records[unit]
end

---@param record ESIRWaterRecord
---@param tick integer
local function schedule_hot(record,tick)
    if record.next_hot and record.next_hot<=tick then return end
    record.phase="hot";record.next_hot=tick
    scheduler.delayed_schedule(state().hot_due,tick,{id=record.id,generation=record.generation,due=tick})
end

---@param record ESIRWaterRecord
local function cancel_work(record)
    record.generation=(record.generation or 0)+1
    record.phase="sleep";record.next_hot=nil;record.aim_checkpoint=nil
    record.search=nil;record.cold_queued=false;record.wake_again=false
end

---@param record ESIRWaterRecord
local function schedule_cold(record)
    if record.cold_queued then record.wake_again=true;return end
    record.phase="cold";record.cold_queued=true
    scheduler.queue_push(state().cold_queue,{kind="acquire",id=record.id,generation=record.generation})
end

---@param record ESIRWaterRecord
---@return boolean
local function fire_in_range(record)
    local fire,entity = record.fire,record.entity
    if not firefighting.eligible(fire,record.weapon_fires) or fire.surface~=entity.surface then return false end
    local a,b = entity.position,fire.position
    local range = record.range
    return (a.x-b.x)^2+(a.y-b.y)^2 <= range*range
end

---@param record ESIRWaterRecord
local function inhibit(record)
    local entity = record.entity
    local wanted = not record.powered or record.mode==3
        or (record.mode==2 and fire_in_range(record) and entity.get_fluid_count("water")>=config.pulse_water)
    if wanted then
        -- A disable already present when we take over belongs to another script.
        if not entity.disabled_by_script then entity.disabled_by_script=true;record.owns_inhibit=true end
    elseif record.owns_inhibit then
        entity.disabled_by_script=false
        record.owns_inhibit=false
    end
    local status
    if not record.powered then status="no-power"
    elseif not entity.disabled_by_control_behavior and not entity.frozen then
        if entity.get_fluid_count("water")<(record.mode==3 and config.pulse_water or 2) then status="no-water"
        elseif record.mode==3 or (record.mode==2 and wanted) then status="firefighting" end
    end
    if record.status~=status then
        record.status=status
        entity.custom_status=status and {diode=status=="no-power" and defines.entity_status_diode.red
            or defines.entity_status_diode.yellow,label={"water-turret."..status}} or nil
    end
end

---@param record ESIRWaterRecord
---@return boolean
local function ready(record)
    local entity = record.entity
    return record.powered and ei_lib.entity_check(record.power) and record.power.energy>=config.power_stop
        and not entity.disabled_by_control_behavior and not entity.disabled_by_recipe
        and not entity.frozen and not entity.to_be_deconstructed()
        and (not entity.disabled_by_script or record.owns_inhibit)
end

---@param record ESIRWaterRecord
---@return boolean
local function available(record)
    return record.entity.get_fluid_count("water")>=config.pulse_water and ready(record)
        and not (record.mode==1 and ei_lib.get_valid_entity(record.entity.shooting_target))
end

---@param record ESIRWaterRecord
---@param tick MapTick
local function wake_record(record,tick)
    if not ei_lib.entity_check(record.entity) then return end
    if record.fire and not fire_in_range(record) then record.fire=nil;cancel_work(record) end
    if not available(record) then
        if record.phase~="sleep" or record.aim_checkpoint then cancel_work(record) end
        record.available=false;return
    end
    record.available=true
    if record.fire then
        record.aim_checkpoint=record.aim_checkpoint or math.max(tick,record.next_pulse)
        schedule_hot(record,math.max(tick+1,record.next_pulse))
    else schedule_cold(record) end
end

---@param record ESIRWaterRecord
local function make_power(record)
    local entity = record.entity
    cancel_work(record);record.available=false
    if record.power_registration then state().registrations[record.power_registration]=nil end
    local helper = entity.surface.create_entity{name=config.power,position=entity.position,
        force=entity.force,quality="normal",create_build_effect_smoke=false}
    record.power = helper
    record.powered = false
    if helper then
        helper.energy = 0
        helper.destructible = false
        helper.minable = false
        helper.operable = false
        record.power_registration = script.register_on_object_destroyed(helper)
        state().registrations[record.power_registration] = entity.unit_number
    end
    inhibit(record)
end

---@param root ESIRWaterState
---@param id integer
local function unregister(root,id)
    local record = root.records[id]
    if not record then return end
    fire_index.uncover(root,record)
    root.records[id]=nil
    root.registrations[record.registration]=nil
    if record.power_registration then root.registrations[record.power_registration]=nil end
    if ei_lib.entity_check(record.power) then record.power.destroy() end
    root.count=root.count-1
    -- Queue tombstones are consumed within the same fixed budget as live entries.
    if root.count==0 then
        root.power_due={};root.hot_due={};root.index=fire_index.new()
        scheduler.clear_queue(root.hot_batches);scheduler.clear_queue(root.cold_queue)
    end
end

---@param entity LuaEntity
---@param tick integer
---@param preferences table?
local function register(entity,tick,preferences)
    local root,id=state(),entity.unit_number
    if root.records[id] then return end
    local mode=preferences and preferences.mode
    if mode~=1 and mode~=2 and mode~=3 then mode=1 end
    local record={id=id,entity=entity,mode=mode,weapon_fires=preferences and preferences.weapon_fires==true or false,
        powered=false,owns_inhibit=false,next_pulse=tick,phase="sleep",generation=0,
        registration=script.register_on_object_destroyed(entity)}
    root.records[id]=record;root.registrations[record.registration]=id;root.count=root.count+1
    make_power(record)
    fire_index.cover(root,record)
    scheduler.delayed_schedule(root.power_due,tick+1+(id%config.power_ticks),id)
    wake_record(record,tick)
end

---@param event table
function model.on_built_entity(event)
    local entity=ei_lib.get_valid_entity(event.destination or event.entity)
    if not entity then return end
    if entity.type=="fire" then
        local root=storage.ei and storage.ei.water_turret
        if root and root.count>0 then fire_index.admit(root,entity) end
        return
    end
    if event.destination and entity.name==config.power then entity.destroy();return end
    if entity.name~=config.turret then return end
    local source=event.source and record_for(event.source)
    local tags=event.tags or {}
    if source and source.owns_inhibit then entity.disabled_by_script=false end
    register(entity,event.tick,source or tags.ei_water_turret)
end

---@param event table
function model.on_destroyed_entity(event)
    local root=storage.ei and storage.ei.water_turret
    local id=ei_lib.get_entity_unit_number(event.entity)
    if root and id then unregister(root,id) end
end

---@param event EventData.on_object_destroyed
function model.on_object_destroyed(event)
    local root=storage.ei and storage.ei.water_turret
    if root and root.index and root.index.fires[event.registration_number] then
        fire_index.remove_fire(root,event.registration_number);return
    end
    local id=root and root.registrations[event.registration_number]
    local record=id and root.records[id]
    if not record then return end
    if event.registration_number==record.registration then unregister(root,id)
    elseif event.registration_number==record.power_registration then
        root.registrations[event.registration_number]=nil
        record.power_registration=nil;record.power=nil;record.powered=false
        cancel_work(record);record.available=false
        if ei_lib.entity_check(record.entity) then inhibit(record) end
    end
end

---@param record ESIRWaterRecord
---@param tick MapTick
local function sync_power(record,tick)
    local helper,entity=record.power,record.entity
    local position=entity.position
    -- Prototype/quality are immutable in runtime; coverage rebuilds refresh range.
    -- Reading attack_parameters here would materialize its full table every guard.
    if record.surface~=entity.surface.index or record.position.x~=position.x or record.position.y~=position.y then
        fire_index.uncover(state(),record);cancel_work(record);record.fire=nil
        fire_index.cover(state(),record);record.available=false
    end
    if not ei_lib.entity_check(helper) then make_power(record);return end
    local helper_position=helper.position
    if helper.surface~=entity.surface or helper_position.x~=position.x or helper_position.y~=position.y then
        -- EEIs cannot use the cross-surface teleport API. Recreate also prevents
        -- carrying electrical charge to a disconnected destination.
        helper.destroy();make_power(record);return
    end
    if helper.force~=entity.force then helper.force=entity.force end
    if record.powered then record.powered=helper.energy>=config.power_stop
    else record.powered=helper.energy>=config.power_start end
    local lost=record.fire and not fire_in_range(record)
    if lost then record.fire=nil;cancel_work(record) end
    inhibit(record)
    local now=available(record)
    if now~=record.available or lost then wake_record(record,tick) end
end

---@param event table
function model.on_teleported(event)
    local entity=ei_lib.get_valid_entity(event.entity)
    local root=storage.ei and storage.ei.water_turret
    if entity and entity.type=="fire" and root and root.count>0 then
        fire_index.remove_fire(root,script.register_on_object_destroyed(entity));fire_index.admit(root,entity);return
    end
    local record=record_for(event.entity)
    if record then
        fire_index.uncover(root,record);cancel_work(record);record.fire=nil
        fire_index.cover(root,record);sync_power(record,event.tick);wake_record(record,event.tick)
    end
end

---@param event EventData.on_forces_merged
function model.on_forces_merged(event)
    local root=storage.ei and storage.ei.water_turret
    for _,record in pairs(root and root.records or {}) do
        if ei_lib.entity_check(record.entity) then sync_power(record,event.tick) end
    end
end

---@param event table
function model.on_surface_deleted(event)
    local root=storage.ei and storage.ei.water_turret
    for id,record in pairs(root and root.records or {}) do
        if not ei_lib.entity_check(record.entity) or record.entity.surface.index==event.surface_index then unregister(root,id) end
    end
end

---@param record ESIRWaterRecord
---@param tick integer
local function firefight(record,tick)
    local entity=record.entity
    if not fire_in_range(record) then
        record.fire=nil;cancel_work(record);wake_record(record,tick);inhibit(record);return
    end
    if not available(record) then cancel_work(record);record.available=false;inhibit(record);return end
    if tick<record.next_pulse then schedule_hot(record,record.next_pulse);return end
    local a,b=entity.position,record.fire.position
    -- blueprint-ref: .codex/esir/blueprints/firefighting-and-water-turret.md#suppression-aim
    -- Credit starts before queue waiting, but never includes a cooldown or observed pause.
    local elapsed=math.max(0,tick-(record.aim_checkpoint or tick))
    record.aim_checkpoint=tick
    local dx,dy=b.x-a.x,b.y-a.y+config.muzzle_height
    if dx==0 and dy==0 then
        local angle=entity.orientation*2*math.pi
        dx,dy=math.sin(angle),-math.cos(angle)
    else
        local orientation=(math.atan2(dy,dx)/(2*math.pi)+0.25)%1
        local delta=(orientation-entity.orientation+0.5)%1-0.5
        local step=config.rotation_speed*elapsed
        if math.abs(delta)>step then
            entity.orientation=(entity.orientation+(delta>0 and step or -step))%1
            schedule_hot(record,tick+1);return
        end
        entity.orientation=orientation
    end
    local removed=entity.remove_fluid{name="water",amount=config.pulse_water}
    if removed>=config.pulse_water then
        local factor=config.muzzle_length/math.sqrt(dx*dx+2*dy*dy)
        local stream=entity.surface.create_entity{
            name=(record.weapon_fires and config.all_effect or config.protect_effect).."-stream",
            position=a,source_position={a.x+dx*factor,a.y+dy*factor-config.muzzle_height},target_position=b,
            force=entity.force}
        if stream then
            record.next_pulse=tick+config.pulse_ticks
            state().counters.pulses=state().counters.pulses+1
        else entity.insert_fluid{name="water",amount=removed} end
    elseif removed>0 then entity.insert_fluid{name="water",amount=removed} end
    record.aim_checkpoint=math.max(tick,record.next_pulse)
    schedule_hot(record,math.max(tick+1,record.next_pulse));inhibit(record)
end

---@param root ESIRWaterState
---@param job table
---@param tick MapTick
local function acquire(root,job,tick)
    local record=root.records[job.id]
    if not record or record.generation~=job.generation or record.phase~="cold" then return end
    record.cold_queued=false
    if not ei_lib.entity_check(record.entity) then unregister(root,job.id);return end
    if not available(record) then cancel_work(record);record.available=false;return end
    if not record.search then
        record.search=fire_index.search(record)
        if not record.search then record.phase="sleep";return end
        root.counters.acquisitions=root.counters.acquisitions+1
        record.wake_again=false
    end
    local done,target=fire_index.search_slice(root,record,config.slice_size,nearest)
    if not done then schedule_cold(record);return end
    record.search=nil;record.phase="sleep"
    if target then
        record.fire=target
        if fire_in_range(record) then
            record.aim_checkpoint=math.max(tick,record.next_pulse)
            record.available=true;inhibit(record)
            schedule_hot(record,math.max(tick+1,record.next_pulse));return
        end
        record.fire=nil
    end
    if record.wake_again then record.wake_again=false;schedule_cold(record) end
end

---@param root table
---@param tick MapTick
local function publish_rebuild(root,tick)
    local job=root.rebuild;if not job then return end
    if root.count==0 or job.completed>=job.total then
        scheduler.finish_rebuild(job.id,"completed",tick);root.rebuild=nil;return
    end
    job.id=scheduler.report_rebuild("water-turret","fire-index","all",job.id,
        {reason=job.reason,phase="seeding",state="running",completed=job.completed,total=job.total,unit="chunks"},tick)
end

---@param event EventData.on_tick
function model.updater(event)
    local root=storage.ei and storage.ei.water_turret
    if not root then return end
    local tick=event.tick
    if root.count==0 then publish_rebuild(root,tick);return end
    if root.power_due[tick] then
        for _,id in ipairs(scheduler.delayed_take_due(root.power_due,tick)) do
            local record=root.records[id]
            if record then
                if ei_lib.entity_check(record.entity) then
                    sync_power(record,tick);root.counters.power_checks=root.counters.power_checks+1
                    scheduler.delayed_schedule(root.power_due,tick+config.power_ticks,id)
                else unregister(root,id) end
            end
        end
    end
    fire_index.bootstrap(root)
    fire_index.service_wakes(root,wake_record,tick)
    -- Detach one due bucket in O(1); overdue entries remain in FIFO batches.
    if root.hot_due[tick] then
        local entries=scheduler.delayed_take_due(root.hot_due,tick)
        scheduler.queue_push(root.hot_batches,{entries=entries,cursor=1,tail=#entries})
    end
    for _=1,config.hot_budget do
        local batch=scheduler.queue_peek(root.hot_batches)
        if not batch then break end
        local job=batch.entries[batch.cursor];batch.cursor=batch.cursor+1
        if batch.cursor>batch.tail then scheduler.queue_pop(root.hot_batches) end
        root.counters.hot_services=root.counters.hot_services+1
        local record=job and root.records[job.id]
        if record and record.generation==job.generation and record.phase=="hot" and record.next_hot==job.due then
            record.next_hot=nil
            if ei_lib.entity_check(record.entity) then firefight(record,tick) else unregister(root,job.id) end
        end
    end
    local slices=fire_index.maintain(root,config.slice_size) and 1 or 0
    while slices<config.cold_slices do
        local job=scheduler.queue_pop(root.cold_queue)
        if not job then break end
        slices=slices+1
        if job.kind=="acquire" then acquire(root,job,tick)
        elseif not fire_index.cold_slice(root,job,config.slice_size) then scheduler.queue_push(root.cold_queue,job) end
    end
    root.counters.cold_slices=root.counters.cold_slices+slices
    publish_rebuild(root,tick)
end

---@param event EventData.on_script_trigger_effect
function model.on_fire_created(event)
    local root=storage.ei and storage.ei.water_turret
    if root and root.count>0 then fire_index.admit(root,event.target_entity) end
end

---@param event EventData.on_chunk_deleted
function model.on_chunk_deleted(event)
    local root=storage.ei and storage.ei.water_turret
    if root and root.count>0 then fire_index.on_chunk_deleted(root,event) end
end

---@param event EventData.on_surface_imported
function model.on_surface_imported(event)
    local surface=game.get_surface(event.surface_index)
    if not surface then return end
    -- Imported helper entities have no record in this save. Keep only helpers
    -- already owned here, before registration creates one for each new turret.
    local root=storage.ei and storage.ei.water_turret
    local owned={}
    for _,record in pairs(root and root.records or {}) do
        if ei_lib.entity_check(record.power) then owned[record.power.unit_number]=true end
    end
    for _,helper in pairs(surface.find_entities_filtered{name=config.power}) do
        if not owned[helper.unit_number] then helper.destroy() end
    end
    for _,entity in pairs(surface.find_entities_filtered{name=config.turret}) do register(entity,event.tick) end
end

---@param tick MapTick?
function model.rebuild(tick)
    if tick==nil then tick=game.tick end
    model.repair_runtime_state("configuration",tick)
    for _,player in pairs(game.players) do
        local gui=player.gui.relative[GUI]
        if gui then gui.destroy() end
    end
end

---@param record ESIRWaterRecord
---@param preferences table
---@param tick integer
local function set_preferences(record,preferences,tick)
    fire_index.uncover(state(),record);cancel_work(record)
    if preferences.mode==1 or preferences.mode==2 or preferences.mode==3 then record.mode=preferences.mode end
    record.weapon_fires=preferences.weapon_fires==true
    fire_index.cover(state(),record)
    record.fire=nil
    inhibit(record)
    wake_record(record,tick)
    for _,player in pairs(game.connected_players) do
        if player.opened==record.entity then model.on_gui_opened{player_index=player.index,entity=record.entity} end
    end
end

---@param event EventData.on_entity_settings_pasted
function model.on_settings_pasted(event)
    local source,destination=record_for(event.source),record_for(event.destination)
    if source and destination then set_preferences(destination,source,event.tick) end
end

---@param event EventData.on_player_setup_blueprint
function model.on_blueprint(event)
    local player=game.get_player(event.player_index)
    if not player then return end
    local stack=event.record
    if not stack then
        stack=event.stack or player.blueprint_to_setup
        if not (stack and stack.valid_for_read and stack.is_blueprint) then stack=player.cursor_stack end
        if not (stack and stack.valid_for_read and stack.is_blueprint) then return end
    end
    for index,entity in pairs(event.mapping.get()) do
        local record=record_for(entity)
        if record then stack.set_blueprint_entity_tag(index,"ei_water_turret",{mode=record.mode,weapon_fires=record.weapon_fires}) end
    end
end

---@param player_index integer
---@return boolean
function model.has_open_gui_session(player_index)
    local player=game.get_player(player_index)
    local gui=player and player.gui.relative[GUI]
    return gui~=nil and gui.valid
end

---@param event table
function model.on_gui_closed(event)
    local player=game.get_player(event.player_index)
    local gui=player and player.gui.relative[GUI]
    if gui then gui.destroy() end
end

---@param event EventData.on_gui_opened
function model.on_gui_opened(event)
    local player=game.get_player(event.player_index)
    local record=record_for(event.entity)
    if not (player and record and player.force==record.entity.force) then model.on_gui_closed(event);return end
    -- blueprint-ref: .codex/esir/blueprints/firefighting-and-water-turret.md#gui-refresh-cost
    local previous=player.gui.relative[GUI]
    local content=previous and previous.body and previous.body.content
    if content and previous.tags.unit==record.entity.unit_number then
        if content.mode.selected_index~=record.mode then content.mode.selected_index=record.mode end
        if content.weapon_fires.state~=record.weapon_fires then content.weapon_fires.state=record.weapon_fires end
        return
    end
    model.on_gui_closed(event)
    local root=player.gui.relative.add{type="frame",name=GUI,direction="vertical",tags={unit=record.entity.unit_number},
        anchor={gui=defines.relative_gui_type.turret_gui,position=defines.relative_gui_position.right}}
    local title=root.add{type="flow",direction="horizontal"}
    title.add{type="label",caption={"entity-name.ei-water-turret"},style="frame_title"}
    title.add{type="empty-widget",style="ei_titlebar_nondraggable_spacer"}
    local body=root.add{type="frame",name="body",style="inside_shallow_frame",direction="vertical"}
    local flow=body.add{type="flow",name="content",style="ei_inner_content_flow",direction="vertical"}
    flow.add{type="label",caption={"water-turret.mode"}}
    flow.add{type="drop-down",name="mode",items={{"water-turret.enemy-first"},{"water-turret.fire-first"},{"water-turret.fire-only"}},
        selected_index=record.mode,tags={parent_gui=GUI,action="mode",unit=record.entity.unit_number}}
    flow.add{type="checkbox",name="weapon_fires",state=record.weapon_fires,caption={"water-turret.extinguish-weapon-fires"},
        tooltip={"water-turret.extinguish-weapon-fires-description"},
        tags={parent_gui=GUI,action="weapon-fires",unit=record.entity.unit_number}}
end

---@param event table
function model.on_gui_changed(event)
    local element=event.element
    if not (element and element.valid and element.tags.parent_gui==GUI) then return end
    local player=game.get_player(event.player_index)
    local record=record_for(player and player.opened)
    if not record or not ei_lib.entity_check(record.entity) or record.entity.unit_number~=element.tags.unit
        or player.force~=record.entity.force then
        model.on_gui_closed(event);return
    end
    local preferences={mode=record.mode,weapon_fires=record.weapon_fires}
    if element.tags.action=="mode" then preferences.mode=element.selected_index
    elseif element.tags.action=="weapon-fires" then preferences.weapon_fires=element.state end
    set_preferences(record,preferences,event.tick)
end
-- blueprint-ref: .codex/esir/blueprints/firefighting-and-water-turret.md#admin-repair
-- Live power helpers and fire-policy preferences are authoritative; never empty them for repair.
---@param reason string
---@param tick MapTick
function model.repair_runtime_state(reason,tick)
    local old=storage.ei and storage.ei.water_turret
    if old and old.rebuild then scheduler.finish_rebuild(old.rebuild.id,"superseded",tick) end
    local records=old and old.records or {}
    storage.ei=storage.ei or {};storage.ei.water_turret=nil
    local root=state()
    root.rebuild_generation=(old and old.rebuild_generation or 0)+1
    root.rebuild={generation=root.rebuild_generation,reason=reason,completed=0,total=0,accepting=true}
    for id,record in pairs(records) do
        if ei_lib.entity_check(record.entity) then
            record.id=id;record.fire=nil;record.available=false;cancel_work(record)
            record.coverage=nil;record.next_fire=nil
            root.records[id]=record;root.count=root.count+1
            record.registration=script.register_on_object_destroyed(record.entity)
            root.registrations[record.registration]=id
            if ei_lib.entity_check(record.power) then
                record.power_registration=script.register_on_object_destroyed(record.power)
                root.registrations[record.power_registration]=id
            else make_power(record) end
            fire_index.cover(root,record);sync_power(record,tick)
            scheduler.delayed_schedule(root.power_due,tick+1+(id%config.power_ticks),id)
        elseif ei_lib.entity_check(record.power) then record.power.destroy() end
    end
    for _,surface in pairs(game.surfaces) do
        for _,entity in pairs(surface.find_entities_filtered{name=config.turret}) do register(entity,tick) end
    end
    root.last_admin_repair_reason=reason;root.last_admin_repair_tick=tick
    root.rebuild.accepting=false;publish_rebuild(root,tick)
    return true
end

return model
