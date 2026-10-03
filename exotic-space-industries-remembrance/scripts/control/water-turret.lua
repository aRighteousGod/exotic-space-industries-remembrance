--==============================================================================
-- ESIR FILE MAP
-- owns: water turret registry, electrical interlock, local fire discovery and modes
-- loaded_by: control.lua (sole dispatcher)
-- cadence: exact 15-tick power guards; staggered fire searches, max 32 jobs/tick
-- forwarded_events: build/remove/clone/teleport/force/surface/blueprint/GUI/rebuild, repair_runtime_state
-- storage_roots: storage.ei.water_turret
-- gui_ids: ei-water-turret-console (relative turret GUI)
-- remote_interfaces: none
-- rebuild_on: init/configuration change; no storage mutation during on_load
--==============================================================================
-- blueprint: .codex/esir/blueprints/firefighting-and-water-turret.md#contract
local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("lib/firefighting-config")
local firefighting = require("scripts/control/firefighting")
local model = {}
local GUI = "ei-water-turret-console"
local interval = settings.startup[config.check_setting].value * 60

---@class ESIRWaterRecord
---@field entity LuaEntity
---@field power LuaEntity?
---@field registration integer
---@field power_registration integer?
---@field mode integer
---@field weapon_fires boolean
---@field powered boolean
---@field owns_inhibit boolean
---@field fire LuaEntity?
---@field next_fire integer
---@field next_pulse integer
---@field status string?
---@class ESIRWaterState
---@field records table<integer,ESIRWaterRecord>
---@field registrations table<integer,integer>
---@field count integer
---@field power_due table
---@field fire_due table
---@field fire_queue table
---@field counters table<string,number>

---@return ESIRWaterState
local function state()
    storage.ei = storage.ei or {}
    local root = storage.ei.water_turret
    if not root then
        root = {records={},registrations={},count=0,power_due={},fire_due={},
            fire_queue=scheduler.ensure_queue(),counters={searches=0,pulses=0,power_checks=0}}
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
local function schedule_fire(record,tick)
    record.next_fire = tick
    scheduler.delayed_schedule(state().fire_due,tick,record.entity.unit_number)
end

---@param record ESIRWaterRecord
---@return boolean
local function fire_in_range(record)
    local fire,entity = record.fire,record.entity
    if not firefighting.eligible(fire,record.weapon_fires) or fire.surface~=entity.surface then return false end
    local a,b = entity.position,fire.position
    local range = entity.prototype.attack_parameters.range * entity.quality.range_multiplier
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
local function make_power(record)
    local entity = record.entity
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
    root.records[id]=nil
    root.registrations[record.registration]=nil
    if record.power_registration then root.registrations[record.power_registration]=nil end
    if ei_lib.entity_check(record.power) then record.power.destroy() end
    root.count=root.count-1
    -- Queue tombstones are consumed within the same fixed budget as live entries.
    if root.count==0 then
        root.power_due={};root.fire_due={};scheduler.clear_queue(root.fire_queue)
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
    local record={entity=entity,mode=mode,weapon_fires=preferences and preferences.weapon_fires==true or false,
        powered=false,owns_inhibit=false,next_pulse=tick,next_fire=0,
        registration=script.register_on_object_destroyed(entity)}
    root.records[id]=record;root.registrations[record.registration]=id;root.count=root.count+1
    make_power(record)
    scheduler.delayed_schedule(root.power_due,tick+1+(id%config.power_ticks),id)
    schedule_fire(record,tick+1+(id%interval))
end

---@param event table
function model.on_built_entity(event)
    local entity=ei_lib.get_valid_entity(event.destination or event.entity)
    if not entity then return end
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
    local id=root and root.registrations[event.registration_number]
    local record=id and root.records[id]
    if not record then return end
    if event.registration_number==record.registration then unregister(root,id)
    elseif event.registration_number==record.power_registration then
        root.registrations[event.registration_number]=nil
        record.power_registration=nil;record.power=nil;record.powered=false
        if ei_lib.entity_check(record.entity) then inhibit(record) end
    end
end

---@param record ESIRWaterRecord
local function sync_power(record)
    local helper,entity=record.power,record.entity
    if not ei_lib.entity_check(helper) then make_power(record);return end
    local helper_position,position=helper.position,entity.position
    if helper.surface~=entity.surface or helper_position.x~=position.x or helper_position.y~=position.y then
        -- EEIs cannot use the cross-surface teleport API. Recreate also prevents
        -- carrying electrical charge to a disconnected destination.
        helper.destroy();make_power(record);return
    end
    if helper.force~=entity.force then helper.force=entity.force end
    if record.powered then record.powered=helper.energy>=config.power_stop
    else record.powered=helper.energy>=config.power_start end
    if not fire_in_range(record) then record.fire=nil end
    inhibit(record)
end

---@param event table
function model.on_teleported(event)
    local record=record_for(event.entity)
    if record then record.fire=nil;sync_power(record);schedule_fire(record,event.tick+1) end
end

function model.on_forces_merged()
    local root=storage.ei and storage.ei.water_turret
    for _,record in pairs(root and root.records or {}) do
        if ei_lib.entity_check(record.entity) then sync_power(record) end
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
        record.fire=nil
        if ready(record) then
            state().counters.searches=state().counters.searches+1
            local best_distance
            local position=entity.position
            for _,fire in pairs(entity.surface.find_entities_filtered{
                position=position,radius=entity.prototype.attack_parameters.range*entity.quality.range_multiplier,type="fire"}) do
                if firefighting.eligible(fire,record.weapon_fires) then
                    local b=fire.position
                    local distance=(position.x-b.x)^2+(position.y-b.y)^2
                    if not best_distance or distance<best_distance then record.fire=fire;best_distance=distance end
                end
            end
        end
    end
    inhibit(record)
    local target=ei_lib.get_valid_entity(entity.shooting_target)
    if record.fire and ready(record) and not (record.mode==1 and target) and tick>=record.next_pulse
        and entity.get_fluid_count("water")>=config.pulse_water then
        local removed=entity.remove_fluid{name="water",amount=config.pulse_water}
        if removed>=config.pulse_water then
            local a,b=entity.position,record.fire.position
            -- Aim from the elevated pivot, matching native stream attack geometry.
            -- apply_projection maps screen direction onto the 45-degree render's
            -- elliptical tip path. Keep the physical muzzle even for close fires.
            local dx,dy=b.x-a.x,b.y-a.y+config.muzzle_height
            if dx==0 and dy==0 then
                local angle=entity.orientation*2*math.pi
                dx,dy=math.sin(angle),-math.cos(angle)
            else entity.orientation=(math.atan2(dy,dx)/(2*math.pi)+0.25)%1 end
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
    end
    schedule_fire(record,tick+(record.fire and config.pulse_ticks or interval))
end

---@param event EventData.on_tick
function model.updater(event)
    local root=storage.ei and storage.ei.water_turret
    if not root or root.count==0 then return end
    local tick=event.tick
    -- Electrical checks are never deferred by the spatial-query budget.
    -- Missing buckets need no disposable result array. Present (even empty)
    -- buckets and malformed legacy roots still take the scheduler repair path.
    if type(root.power_due)~="table" or root.power_due[tick]~=nil then
        for _,id in ipairs(scheduler.delayed_take_due(root.power_due,tick)) do
            local record=root.records[id]
            if record then
                if ei_lib.entity_check(record.entity) then
                    sync_power(record);root.counters.power_checks=root.counters.power_checks+1
                    scheduler.delayed_schedule(root.power_due,tick+config.power_ticks,id)
                else unregister(root,id) end
            end
        end
    end
    if type(root.fire_due)~="table" or root.fire_due[tick]~=nil then
        for _,id in ipairs(scheduler.delayed_take_due(root.fire_due,tick)) do
            local record=root.records[id]
            if record and record.next_fire==tick then scheduler.queue_push_unique(root.fire_queue,id) end
        end
    end
    local queue=root.fire_queue
    if type(queue)=="table" and queue.head==1 and queue.tail==0
        and type(queue.items)=="table" and next(queue.items)==nil
        and type(queue.queued)=="table" and next(queue.queued)==nil then
        return
    end
    for _=1,config.fire_budget do
        local id=scheduler.queue_pop(root.fire_queue)
        if not id then break end
        local record=root.records[id]
        if record then
            if ei_lib.entity_check(record.entity) then firefight(record,tick) else unregister(root,id) end
        end
    end
end

---@param tick integer?
function model.rebuild(tick)
    tick=tick or game.tick
    local old=storage.ei and storage.ei.water_turret
    for _,record in pairs(old and old.records or {}) do
        if ei_lib.entity_check(record.entity) and record.owns_inhibit then record.entity.disabled_by_script=false end
    end
    storage.ei=storage.ei or {};storage.ei.water_turret=nil
    for _,surface in pairs(game.surfaces) do
        for _,helper in pairs(surface.find_entities_filtered{name=config.power}) do helper.destroy() end
        for _,entity in pairs(surface.find_entities_filtered{name=config.turret}) do
            register(entity,tick,old and old.records[entity.unit_number])
        end
    end
    for _,player in pairs(game.players) do
        local gui=player.gui.relative[GUI]
        if gui then gui.destroy() end
    end
end

---@param record ESIRWaterRecord
---@param preferences table
---@param tick integer
local function set_preferences(record,preferences,tick)
    if preferences.mode==1 or preferences.mode==2 or preferences.mode==3 then record.mode=preferences.mode end
    record.weapon_fires=preferences.weapon_fires==true
    record.fire=nil
    inhibit(record)
    schedule_fire(record,tick+1)
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
    local root=state()
    for id,record in pairs(root.records) do
        if not ei_lib.entity_check(record.entity) then unregister(root,id) end
    end
    for _,surface in pairs(game.surfaces) do
        for _,entity in pairs(surface.find_entities_filtered{name=config.turret}) do register(entity,tick) end
    end
    root.power_due={}
    root.fire_due={}
    root.fire_queue=scheduler.clear_queue(root.fire_queue)
    root.count=0
    for id,record in pairs(root.records) do
        root.count=root.count+1
        sync_power(record)
        scheduler.delayed_schedule(root.power_due,tick+1+(id%config.power_ticks),id)
        schedule_fire(record,math.max(tick+1,tonumber(record.next_fire) or tick+1))
    end
    root.last_admin_repair_reason=reason
    root.last_admin_repair_tick=tick
    return true
end

return model
