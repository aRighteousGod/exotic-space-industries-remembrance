--==============================================================================
-- ESIR FILE MAP
-- owns: spider progression, safe replacements, weapon controls/selection, reactive smoke
-- loaded_by: control.lua; all event registration remains in that dispatcher
-- cadence: exact lifecycle/research events; two queued replacements per tick;
--          unsafe retries after 120 ticks; six delayed smoke pulses;
--          optional active shot bookkeeping, 15/60-tick local target refreshes (8/tick)
-- forwarded_events: on_built_entity, on_entity_cloned, on_object_destroyed,
--   on_research_finished, on_scripted_research_burst, on_configuration_changed,
--   on_forces_merged, on_external_replaced, refresh_vehicle, on_entity_damaged,
--   on_mined_entity, on_gui_opened, on_gui_closed, on_gui_changed, updater
--   on_script_trigger_effect (optional launch/impact reservations)
-- storage_roots: storage.ei.spider_vehicles
-- gui_ids: ei-spider-weapon-console
-- remote_interfaces: exotic-industries-spider-vehicles (registered by control.lua)
-- rebuild_on: init/configuration change; force research changes invalidate targets
--==============================================================================
local catalog = require("lib/spider-vehicles")
local scheduler = require("lib/runtime-scheduler")
local ei_lib = require("lib/lib")
local util = require("util")
local model = {}
local transaction = false
local SMART = settings.startup["ei-spider-range-aware-cycling"].value
-- Build immutable exact-ID routing once per control load. Disabled startup mode
-- installs no observation hooks and no spider handlers in the shared dispatcher.
---@type table<string, {launch:boolean, name:string}>
model.script_effects = {}
if SMART then
    for id in pairs(prototypes.mod_data[catalog.overkill.profiles.."-effects"].data) do
        local launch=id:sub(1,#catalog.overkill.launch)==catalog.overkill.launch
        model.script_effects[id]={launch=launch,name=id:sub(#(launch and catalog.overkill.launch or catalog.overkill.impact)+1)}
    end
end
local GUI_NAME = "ei-spider-weapon-console"
local reset_selection,refresh_gui,ammunition,release_overkill
-- Immutable prototype facts are filled lazily and rebuilt when control loads.
-- Fetching full attack/ammo action tables on every target refresh is expensive.
local gun_profiles,ammo_profiles={},{}
local impact_profiles
local selector_tick,hostility_cache,target_cache
-- Generated events must be recreated when control.lua loads, including save loads.
local replacement_event = script.generate_event_name()

---@class ESIRSpiderRecord
---@field id integer Stable identity across prototype replacements.
---@field entity LuaEntity
---@field force_index integer
---@field family string
---@field smoke_ready integer
---@field retry_tick integer?
---@field pending_reason string?
---@field suspended boolean Boarding proxy owned by Spidertron Enhancements.
---@field preferences ESIRSpiderPreferences
---@field stowed_ammo {name:string?,quality:string?,filter:table?}?
---@field selection table? Cached slots/targets, current group and firing-turn counters.
---@field search_tick integer?
---@field overkill_state ESIRSpiderOverkillState?

---@class ESIRSpiderOverkillState
---@field shots table<integer, table> Native shots, never synthetic projectiles.
---@field targets table<any, table> Per-vehicle damage totals and reservation revisions.
---@field blocked table<string, table> Failed native aiming probes, by weapon group.
---@field next_id integer
---@field targeting table? Requested native settings while effective settings are suppressed.

---@class ESIRSpiderState
---@field vehicles table<integer, ESIRSpiderRecord>
---@field units table<integer, integer>
---@field registrations table<integer, integer>
---@field forces table<integer, table>
---@field queue table
---@field retries table
---@field pulses table
---@field next_id integer
---@field replacements integer
---@field failures integer
---@field items table<integer, table> Mined-item preferences, keyed by item_number.
---@field item_registrations table<integer, integer>
---@field selector table Active records, scheduled searches and diagnostics.
---@field gui table<integer, integer> Player index to stable vehicle identity.
---@field overkill table Active reservation records, expiry buckets and counters.

---@return ESIRSpiderState
local function state()
    storage.ei=storage.ei or {}
    storage.ei.spider_vehicles=storage.ei.spider_vehicles or {
        vehicles={},units={},registrations={},forces={},queue=scheduler.ensure_queue(),
        retries={},pulses={},next_id=0,replacements=0,failures=0,
    }
    local root=storage.ei.spider_vehicles
    root.items=root.items or {}
    root.item_registrations=root.item_registrations or {}
    root.selector=root.selector or {active={},due={},queue=scheduler.ensure_queue(),searches=0,samples=0,max_searches=0,turns=0}
    root.gui=root.gui or {}
    root.overkill=root.overkill or {active={},due={},launches=0,reserved=0,retired=0,expired=0,holds=0,samples=0,unsupported=0}
    return root
end

---@param record ESIRSpiderRecord
---@return ESIRSpiderPreferences
local function preferences(record)
    record.preferences=record.preferences or {cycling=true,special=true}
    if record.preferences.overkill==nil then record.preferences.overkill=false end
    return record.preferences
end

---@param record ESIRSpiderRecord
---@return string
local function desired_name(record)
    local force=record.entity.force
    local researched=state().forces[force.index] or catalog.researched_state(force)
    state().forces[force.index]=researched
    return catalog.configured_name(record.family,researched,preferences(record),SMART)
end

---@param record ESIRSpiderRecord
local function enqueue(record)
    if record.suspended then return end
    scheduler.queue_push_unique(state().queue,record.id)
end

---@param entity LuaEntity?
---@return ESIRSpiderRecord?
local function register(entity)
    if transaction or not ei_lib.entity_check(entity) or entity.type~="spider-vehicle" then return end
    local family=catalog.family(entity.name)
    if not family then return end
    local root=state()
    local id=root.units[entity.unit_number]
    local record=id and root.vehicles[id]
    if record then preferences(record);return record end
    root.next_id=root.next_id+1
    record={id=root.next_id,entity=entity,family=family,force_index=entity.force.index,smoke_ready=0,suspended=catalog.is_proxy(entity.name)}
    root.vehicles[record.id]=record
    root.units[entity.unit_number]=record.id
    root.registrations[script.register_on_object_destroyed(entity)]=entity.unit_number
    preferences(record)
    return record
end

---@param force LuaForce
function model.refresh_force(force)
    if not force or not force.valid then return end
    local root=state()
    root.forces[force.index]=catalog.researched_state(force)
    for _,record in pairs(root.vehicles) do
        if ei_lib.entity_check(record.entity) and record.entity.force==force then
            record.force_index=force.index
            enqueue(record)
        end
    end
end

---@param name string
---@return boolean
function model.is_relevant_research(name)
    return name==catalog.smoke.technology or name=="ei-assault-spidertron" or name=="spidertron" or name:find("ei-spider-",1,true)==1
end

---@param event EventData.on_research_finished|EventData.on_research_reversed
function model.on_research_finished(event)
    if event.research and model.is_relevant_research(event.research.name) then model.refresh_force(event.research.force) end
end

---@param force LuaForce
---@param relevant boolean
function model.on_scripted_research_burst(force,relevant)
    if relevant then model.refresh_force(force) end
end

function model.on_built_entity(event)
    local record=register(event.entity or event.created_entity)
    if not record then return end
    local function restore(stack)
        if not stack or not stack.valid_for_read then return end
        local saved=stack.item_number and state().items[stack.item_number]
        if saved and saved.family==record.family then
            record.preferences=table.deepcopy(saved.preferences)
            record.stowed_ammo=table.deepcopy(saved.stowed_ammo)
            if saved.targeting then record.entity.vehicle_automatic_targeting_parameters=table.deepcopy(saved.targeting) end
            state().items[stack.item_number]=nil
        end
    end
    if event.consumed_items then
        for index=1,#event.consumed_items do restore(event.consumed_items[index]) end
    else restore(event.stack) end
    enqueue(record)
end

---@param event EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_space_platform_mined_entity
function model.on_mined_entity(event)
    if transaction then return end
    local unit=ei_lib.get_entity_unit_number(event.entity)
    local record=unit and state().vehicles[state().units[unit]]
    if not record or not event.buffer then return end
    -- Native mining may already have serialized the temporarily suppressed
    -- flags into the item. Carry the requested values with its stable identity.
    local targeting=record.overkill_state and record.overkill_state.targeting
    release_overkill(record,true)
    for index=1,#event.buffer do
        local stack=event.buffer[index]
        if stack.valid_for_read and stack.type=="item-with-entity-data" and stack.item_number then
            local place=stack.prototype.place_result
            if place and catalog.family(place.name)==record.family then
                local saved=table.deepcopy(preferences(record))
                saved.selected_slot=event.entity.selected_gun_index
                state().items[stack.item_number]={family=record.family,preferences=saved,stowed_ammo=table.deepcopy(record.stowed_ammo),targeting=table.deepcopy(targeting)}
                if stack.item then state().item_registrations[script.register_on_object_destroyed(stack.item)]=stack.item_number end
                break
            end
        end
    end
end

function model.on_entity_cloned(event)
    local record=register(event.destination)
    if not record then return end
    local source_id=ei_lib.get_entity_unit_number(event.source)
    local original=source_id and state().vehicles[state().units[source_id]]
    if original then
        -- A clone must not inherit a transient automatic-fire suppression.
        if original.overkill_state and original.overkill_state.targeting then
            record.entity.vehicle_automatic_targeting_parameters=table.deepcopy(original.overkill_state.targeting)
        end
        record.smoke_ready=original.smoke_ready
        record.preferences=table.deepcopy(preferences(original))
        record.stowed_ammo=table.deepcopy(original.stowed_ammo)
    end
    enqueue(record)
end

-- Enhancements owns boarding/deserialisation. Follow its stable identity across
-- the temporary proxy, and apply queued research only after disembarking.
function model.on_external_replaced(event)
    if transaction then return end
    local source,destination=event.old_spidertron,event.new_spidertron
    local old_unit=ei_lib.get_entity_unit_number(source)
    if not old_unit or not ei_lib.entity_check(destination) then return end
    local root=state()
    local original=root.vehicles[root.units[old_unit]]
    local replacement=register(destination)
    if not original or not replacement then return end
    release_overkill(original,false,destination)
    if original.id~=replacement.id then
        root.vehicles[replacement.id]=nil
        root.queue.queued[replacement.id]=nil
        root.selector.active[replacement.id]=nil
    end
    root.units[old_unit]=nil
    root.units[destination.unit_number]=original.id
    original.entity=destination
    original.family=replacement.family
    original.force_index=destination.force.index
    original.suspended=catalog.is_proxy(destination.name)
    original.pending_reason=nil
    reset_selection(original,event.tick)
    enqueue(original)
end

function model.on_object_destroyed(event)
    local root=state()
    local item=root.item_registrations[event.registration_number]
    if item then root.items[item]=nil;root.item_registrations[event.registration_number]=nil;return end
    local unit=root.registrations[event.registration_number]
    root.registrations[event.registration_number]=nil
    if not unit then return end
    local id=root.units[unit]
    root.units[unit]=nil
    if id then
        root.overkill.active[id]=nil
        root.vehicles[id]=nil;root.queue.queued[id]=nil
        root.selector.active[id]=nil;root.selector.queue.queued[id]=nil
        for player_index,vehicle_id in pairs(root.gui) do
            if vehicle_id==id then model.on_gui_closed{player_index=player_index} end
        end
    end
end

-- Factorio 2.0.77 has no entity-force-changed event. Integrations that assign
-- entity.force directly can notify this hook; native force merges have an event.
function model.refresh_vehicle(entity)
    local record=register(entity)
    if record then
        release_overkill(record,true)
        record.force_index=record.entity.force.index
        state().forces[record.force_index]=nil
        enqueue(record)
    end
end

function model.on_forces_merged(event)
    state().forces[event.source_index]=nil
    model.refresh_force(event.destination)
end

function model.on_configuration_changed()
    local root=state()
    for _,record in pairs(root.vehicles) do release_overkill(record,true) end
    root.overkill={active={},due={},launches=0,reserved=0,retired=0,expired=0,holds=0,samples=0,unsupported=0}
    root.selector={active={},due={},queue=scheduler.ensure_queue(),searches=0,samples=0,max_searches=0,turns=0}
    -- Grandfather existing unlocks, without granting upgrades or unrelated ages.
    for _,force in pairs(game.forces) do
        local legacy=force.technologies.assault_spidertron_tech
        local rocket=force.technologies.spidertron
        if (legacy and legacy.researched) or (rocket and rocket.researched) then force.technologies["ei-spider-vehicles"].researched=true end
        if legacy and legacy.researched then force.technologies["ei-assault-spidertron"].researched=true end
        if force.recipes.assault_spidertron then force.recipes.assault_spidertron.enabled=false end
        model.refresh_force(force)
    end
    -- Discovery happens only on init/configuration change, never in idle ticks.
    for _,surface in pairs(game.surfaces) do
        for _,entity in ipairs(surface.find_entities_filtered{type="spider-vehicle"}) do
            local record=register(entity)
            if record then enqueue(record) end
        end
    end
    for id,record in pairs(root.vehicles) do
        if not ei_lib.entity_check(record.entity) then root.vehicles[id]=nil
        else record.selection=nil;record.search_tick=nil end
    end
    for _,player in pairs(game.players) do model.on_gui_opened{player_index=player.index,entity=ei_lib.get_valid_entity(player.opened)} end
end

local inventory_ids={defines.inventory.spider_trunk,defines.inventory.spider_trash,defines.inventory.spider_ammo,defines.inventory.fuel,defines.inventory.burnt_result}
local legacy_assault_slots={[1]=4,[3]=1,[4]=2,[5]=3}

---@param source LuaInventory?
---@param destination LuaInventory?
local function copy_inventory(source,destination)
    if not source then return end
    for index=1,#source do
        local filter=source.supports_filters() and source.get_filter(index)
        if source[index].valid_for_read or filter then
            assert(destination and index<=#destination,"inventory-capacity")
            if filter then assert(destination.set_filter(index,filter),"inventory-filter") end
            if source[index].valid_for_read then
                assert(destination[index].set_stack(source[index]),"inventory-stack")
            end
        end
    end
    if destination and source.supports_bar() and destination.supports_bar() then
        local bar=source.get_bar()
        if bar>#source then destination.set_bar()
        else destination.set_bar(math.min(bar,#destination+1)) end
    end
end

---@param source LuaBurner?
---@param destination LuaBurner?
local function copy_burner(source,destination)
    if not source then return end
    assert(destination,"burner-missing")
    copy_inventory(source.inventory,destination.inventory)
    copy_inventory(source.burnt_result_inventory,destination.burnt_result_inventory)
    destination.currently_burning=source.currently_burning
    destination.remaining_burning_fuel=source.remaining_burning_fuel
    destination.heat=source.heat
end

-- The upstream five-slot layout differs from ESIR's three/four-slot layout.
-- Preserve obsolete rockets/unmounted artillery in empty trunk slots, including
-- partial magazines and quality; if the trunk is full, leave the original intact.
---@param source LuaEntity
---@param destination LuaEntity
local function copy_legacy_ammo(source,destination)
    local ammo=destination.get_inventory(defines.inventory.spider_ammo)
    local trunk=destination.get_inventory(defines.inventory.spider_trunk)
    local original=source.get_inventory(defines.inventory.spider_ammo)
    for index=1,#original do
        local stack=original[index]
        if stack.valid_for_read then
            local slot=legacy_assault_slots[index]
            local target=slot and slot<=#ammo and ammo[slot] or nil
            if not target then
                for cargo=1,#trunk do
                    if not trunk[cargo].valid_for_read and trunk[cargo].can_set_stack(stack) then target=trunk[cargo];break end
                end
            end
            assert(target,"legacy-ammo-space")
            assert(target.set_stack(stack),"legacy-ammo-stack")
        end
    end
end

-- Mount switches remove only the final slot. Work on the candidate's inventories;
-- the original and its remembered ammunition remain untouched until commit.
---@param source LuaEntity
---@param destination LuaEntity
---@param remembered table?
---@return table?
local function copy_spider_ammo(source,destination,remembered)
    local original=source.get_inventory(defines.inventory.spider_ammo)
    local ammo=destination.get_inventory(defines.inventory.spider_ammo)
    if not original then return remembered end
    local trunk=destination.get_inventory(defines.inventory.spider_trunk)
    local saved=table.deepcopy(remembered)
    for index=1,#original do
        local stack=original[index]
        local filter=original.supports_filters() and original.get_filter(index)
        if index<=#ammo then
            if filter then assert(ammo.set_filter(index,filter),"inventory-filter") end
            if stack.valid_for_read then assert(ammo[index].set_stack(stack),"inventory-stack") end
        else
            saved=filter and {filter=filter} or nil
            if stack.valid_for_read then
                -- Native insertion also uses compatible partial cargo stacks.
                -- Passing the LuaItemStack preserves quality and magazine state;
                -- a partial insertion only changes the disposable candidate.
                assert(trunk.insert(stack)==stack.count,"mount-ammo-space")
                saved=saved or {}
                saved.name=stack.name;saved.quality=stack.quality.name
            end
        end
    end
    if #ammo>#original and saved then
        local slot=#ammo
        if saved.filter and ammo.supports_filters() then assert(ammo.set_filter(slot,saved.filter),"inventory-filter") end
        if saved.name and not ammo[slot].valid_for_read then
            for cargo=1,#trunk do
                local stack=trunk[cargo]
                if stack.valid_for_read and stack.name==saved.name and stack.quality.name==saved.quality and ammo[slot].can_set_stack(stack) then
                    assert(ammo[slot].transfer_stack(stack),"mount-ammo-restore")
                    break
                end
            end
        end
    end
    return saved
end

-- Engine cloning/mining retains item-with-entity-data equipment and logistic
-- metadata. A temporary clone is mined; the real vehicle survives until commit.
-- Generic fast replacement was engine-tested and discards the equipment grid.
---@param source LuaEntity
---@param target string
---@param record ESIRSpiderRecord
---@return LuaEntity
---@return LuaInventory
---@return table? stowed_ammo
local function prepare_replacement(source,target,record)
    local prototype=prototypes.entity[target]
    assert(prototype,"missing-variant")
    local grid=prototype.grid_prototype
    for _,equipment in ipairs(source.grid.equipment) do
        assert(equipment.position.x+equipment.shape.width<=grid.width and equipment.position.y+equipment.shape.height<=grid.height,"grid-capacity")
        -- Native mining resolves removal orders; keep the source until that work ends.
        assert(not equipment.to_be_removed,"equipment-removal")
    end
    local clone,temporary,candidate
    local stowed=record.stowed_ammo
    local ok,err=pcall(function()
        temporary=game.create_inventory(1)
        clone=source.clone{position=source.position,surface=source.surface,create_build_effect_smoke=false}
        assert(clone,"clone-failed")
        -- Contents are copied from the real vehicle later. Empty the snapshot's
        -- inventories so a spider carried as cargo cannot be mistaken for it.
        for _,inventory_id in ipairs(inventory_ids) do
            local inventory=clone.get_inventory(inventory_id)
            if inventory then inventory.clear() end
        end
        assert(clone.mine{inventory=temporary,force=false,ignore_minable=true,raise_destroyed=true},"snapshot-mine")
        clone=nil
        local item
        for index=1,#temporary do
            local stack=temporary[index]
            if stack.valid_for_read and stack.type=="item-with-entity-data" then item=stack;break end
        end
        assert(item,"snapshot-item")
        candidate=source.surface.create_entity{name=target,position=source.position,force=source.force,quality=source.quality,item=item,create_build_effect_smoke=false}
        assert(candidate,"create-failed")
        -- Native item placement restores equipment only when the grid prototype
        -- matches. Rebuild missing equipment before cargo (inventory bonuses).
        for _,equipment in ipairs(source.grid.equipment) do
            local ghost=equipment.type=="equipment-ghost"
            local restored=candidate.grid.get(equipment.position)
            if not restored then
                restored=candidate.grid.put{name=ghost and equipment.ghost_name or equipment.name,position=equipment.position,quality=equipment.quality,ghost=ghost}
            end
            assert(restored and restored.name==equipment.name and restored.quality==equipment.quality,"equipment-state")
            if ghost then assert(restored.ghost_name==equipment.ghost_name,"equipment-ghost")
            else
                restored.energy=equipment.energy
                if equipment.max_shield>0 then restored.shield=equipment.shield end
                copy_burner(equipment.burner,restored.burner)
            end
        end
        assert(#source.grid.equipment==#candidate.grid.equipment,"equipment-count")
        for _,inventory_id in ipairs(inventory_ids) do
            if inventory_id~=defines.inventory.spider_ammo then
                copy_inventory(source.get_inventory(inventory_id),candidate.get_inventory(inventory_id))
            end
        end
        if source.name=="assault_spidertron" then copy_legacy_ammo(source,candidate)
        else stowed=copy_spider_ammo(source,candidate,record.stowed_ammo) end
        copy_burner(source.burner,candidate.burner)
        candidate.grid.inhibit_movement_bonus=source.grid.inhibit_movement_bonus
        local sections=source.get_logistic_sections()
        local restored_sections=candidate.get_logistic_sections()
        assert(not sections or (restored_sections and sections.sections_count==restored_sections.sections_count),"logistic-sections")
        for index,section in pairs(sections and sections.sections or {}) do
            local restored=restored_sections.sections[index]
            assert(restored and section.group==restored.group and section.active==restored.active and section.multiplier==restored.multiplier and util.table.compare(section.filters,restored.filters),"logistic-filters")
        end
        for _,point in pairs(source.get_logistic_point() or {}) do
            local restored=candidate.get_logistic_point(point.logistic_member_index)
            assert(restored,"logistic-point")
            restored.enabled=point.enabled
            restored.trash_not_requested=point.trash_not_requested
        end
        for _,property in ipairs({"orientation","torso_orientation","color","entity_label","driver_is_gunner","enable_logistics_while_moving","vehicle_automatic_targeting_parameters","destructible","minable","operable","rotatable","active","last_user"}) do
            candidate[property]=source[property]
        end
        if source.selected_gun_index then
            local selected=source.name=="assault_spidertron" and (legacy_assault_slots[source.selected_gun_index] or 1) or source.selected_gun_index
            if not preferences(record).cycling and record.preferences.selected_slot then selected=record.preferences.selected_slot end
            candidate.selected_gun_index=math.min(selected,#candidate.get_inventory(defines.inventory.spider_ammo))
        end
        candidate.health=source.health/source.max_health*candidate.max_health
        candidate.custom_status=source.custom_status
        for _,destination in ipairs(source.autopilot_destinations or {}) do candidate.add_autopilot_destination(destination) end
        if ei_lib.entity_check(source.follow_target) then
            candidate.follow_target=source.follow_target
            candidate.follow_offset=source.follow_offset
        end
    end)
    if not ok then
        if ei_lib.entity_check(candidate) then candidate.destroy{raise_destroy=true} end
        if ei_lib.entity_check(clone) then clone.destroy{raise_destroy=true} end
        if temporary and temporary.valid then temporary.destroy() end
        error(err)
    end
    return candidate,temporary,stowed
end

---@param source LuaEntity
---@return string? reason
local function unsafe_reason(source)
    if math.abs(source.speed or 0)>0.00001 then return "moving" end
    if source.stickers and next(source.stickers) then return "temporary-effects" end
    if source.to_be_deconstructed() or source.to_be_upgraded() then return "construction-order" end
    local network=source.logistic_cell and source.logistic_cell.logistic_network
    if network and next(network.robots) then return "active-robots" end
    for _,point in pairs(source.get_logistic_point() or {}) do
        if next(point.targeted_items_deliver) or next(point.targeted_items_pickup) then return "logistic-delivery" end
    end
end

---@param record ESIRSpiderRecord
---@param target string
---@return boolean
---@return string?
---@param tick MapTick
local function replace(record,target,tick)
    -- Copy requested targeting, never the temporary overkill hold, into refits.
    release_overkill(record,false)
    local source=record.entity
    local reason=unsafe_reason(source)
    if reason then return false,reason end
    local links={players={},followers={}}
    for _,player in pairs(game.players) do
        local selection=player.spidertron_remote_selection
        local selected=false
        for _,entity in pairs(selection or {}) do if entity==source then selected=true end end
        if selected or player.opened==source then
            links.players[#links.players+1]={player=player,selection=selected and selection or nil,opened=player.opened==source}
        end
    end
    -- Factorio has no follow-target-changed event. Audit incoming native follower
    -- links only at a replacement boundary, including non-ESIR spider vehicles.
    for _,follower in ipairs(source.surface.find_entities_filtered{type="spider-vehicle"}) do
        if follower.follow_target==source then links.followers[#links.followers+1]={entity=follower,offset=follower.follow_offset} end
    end
    local driver,passenger=source.get_driver(),source.get_passenger()
    transaction=true
    local candidate,temporary,stowed
    local ok,err=pcall(function()
        candidate,temporary,stowed=prepare_replacement(source,target,record)
        if driver then candidate.set_driver(driver) end
        if passenger then candidate.set_passenger(passenger) end
        assert(candidate.get_driver()==driver and candidate.get_passenger()==passenger,"occupant-state")
    end)
    if not ok then
        if ei_lib.entity_check(source) then
            if driver and driver.valid then source.set_driver(driver) end
            if passenger and passenger.valid then source.set_passenger(passenger) end
        end
        if ei_lib.entity_check(candidate) then candidate.destroy{raise_destroy=true} end
        if temporary and temporary.valid then temporary.destroy() end
        transaction=false
        local reason=tostring(err)
        local expected=reason:match("(grid%-capacity)$") or reason:match("(inventory%-capacity)$") or reason:match("(equipment%-removal)$") or reason:match("(legacy%-ammo%-space)$") or reason:match("(mount%-ammo%-space)$")
        return false,expected or reason,not expected
    end
    local old_unit=source.unit_number
    local root=state()
    -- Resolve identity comparisons while the old LuaEntity is still valid.
    for _,link in ipairs(links.players) do
        for index,entity in pairs(link.selection or {}) do
            if entity==source then link.selection[index]=candidate end
        end
    end
    -- Spidertron Enhancements/Patrols share this pre-destruction contract. Their
    -- patrols, dock links, and rendering references need both entities live.
    if prototypes.custom_event["on_spidertron_replaced"] then
        script.raise_event("on_spidertron_replaced",{old_spidertron=source,new_spidertron=candidate})
    end
    -- Commit only after all storage and occupant restoration succeeded.
    assert(source.destroy{raise_destroy=true},"Spider replacement could not commit")
    temporary.destroy()
    root.units[old_unit]=nil
    record.entity=candidate
    record.force_index=candidate.force.index
    record.pending_reason=nil
    record.stowed_ammo=stowed
    root.units[candidate.unit_number]=record.id
    root.registrations[script.register_on_object_destroyed(candidate)]=candidate.unit_number
    for _,link in ipairs(links.followers) do
        if ei_lib.entity_check(link.entity) then link.entity.follow_target=candidate;link.entity.follow_offset=link.offset end
    end
    for _,link in ipairs(links.players) do
        if link.selection then
            local selection={}
            for _,entity in pairs(link.selection) do if ei_lib.entity_check(entity) then selection[#selection+1]=entity end end
            link.player.spidertron_remote_selection=selection
        end
        if link.opened then link.player.opened=candidate end
    end
    transaction=false
    root.replacements=root.replacements+1
    reset_selection(record,tick)
    -- Moving occupants and destroying the source can close its native window.
    -- Rebind the relative panel explicitly after the new identity is committed;
    -- assigning player.opened does not guarantee an on_gui_opened callback.
    for _,link in ipairs(links.players) do
        if link.opened then model.on_gui_opened{player_index=link.player.index,entity=candidate,tick=tick} end
    end
    refresh_gui(record)
    script.raise_script_built{entity=candidate}
    script.raise_event(replacement_event,{old_unit_number=old_unit,entity=candidate,vehicle_id=record.id})
    return true
end

local function smoke_pulse(pulse,tick)
    local surface=game.surfaces[pulse.surface]
    local force=game.forces[pulse.force]
    if not surface or not force then return end
    local hostile={}
    for _,other in pairs(game.forces) do
        if other~=force and not force.get_friend(other) and not force.get_cease_fire(other) then hostile[#hostile+1]=other end
    end
    if #hostile>0 then
        for _,unit in ipairs(surface.find_entities_filtered{position=pulse.position,radius=catalog.smoke.radius,type="unit",force=hostile,limit=catalog.smoke.limit}) do
            for _,sticker in pairs(unit.stickers or {}) do
                if sticker.valid and sticker.name=="ei-assault-smoke-slow" then sticker.destroy() end
            end
            surface.create_entity{name="ei-assault-smoke-slow",position=unit.position,target=unit,force=force}
        end
    end
    pulse.remaining=pulse.remaining-1
    if pulse.remaining>0 then scheduler.delayed_schedule(state().pulses,tick+catalog.smoke.interval,pulse) end
end

---@param event EventData.on_entity_damaged
function model.on_entity_damaged(event)
    if transaction then return end
    local entity=event.entity
    if not ei_lib.entity_check(entity) or entity.type~="spider-vehicle" then return end
    local root=storage.ei and storage.ei.spider_vehicles
    local record=root and root.vehicles[root.units[entity.unit_number]] or register(entity)
    if not record or record.family~="assault" or record.suspended or event.tick<record.smoke_ready then return end
    root=root or state()
    local force=entity.force
    local researched=root.forces[force.index]
    if not researched then researched=catalog.researched_state(force);root.forces[force.index]=researched end
    if not researched.smoke then return end
    local health=entity.health
    if health<=0 or (event.final_damage_amount<entity.max_health*0.05 and health>=entity.max_health*0.5) then return end
    local hostile=event.force or (ei_lib.entity_check(event.cause) and event.cause.force)
    if not hostile or hostile==force or force.get_friend(hostile) or force.get_cease_fire(hostile) then return end
    if entity.get_inventory(defines.inventory.spider_trunk).remove{name=catalog.smoke.charge,count=1}~=1 then return end
    record.smoke_ready=event.tick+catalog.smoke.cooldown
    entity.surface.create_entity{name="ei-assault-smoke-cloud",position=entity.position,force=entity.force}
    smoke_pulse({surface=entity.surface.index,force=entity.force.index,position=entity.position,remaining=6},event.tick)
end

-- The selector never replaces entities between shots. Native weapons own aiming,
-- ammunition use and the shared cooldown; we only choose their selected slot.
---@param record ESIRSpiderRecord
---@return boolean
local function selector_vehicle(record)
    if not SMART or record.suspended or record.family=="scout" or not preferences(record).cycling or not ei_lib.entity_check(record.entity) then return false end
    local mode=catalog.mode(record.entity.name)
    return record.family=="assault" and mode=="hold" or record.family=="rocket" and mode=="smart"
end

---@param record ESIRSpiderRecord
---@param tick integer
local function schedule_search(record,tick)
    if not selector_vehicle(record) or record.search_tick then return end
    record.search_tick=tick
    scheduler.delayed_schedule(state().selector.due,tick,record.id)
end

reset_selection=function(record,tick)
    release_overkill(record,false)
    local root=state()
    root.selector.active[record.id]=nil
    record.selection=nil;record.search_tick=nil
    if selector_vehicle(record) then
        local initial={}
        local inventory=record.entity.get_inventory(defines.inventory.spider_ammo)
        for index=1,#inventory do
            local total,identity=ammunition(inventory[index])
            initial[index]={total=total,identity=identity}
        end
        record.selection={initial=initial}
        scheduler.queue_push_unique(root.selector.queue,record.id)
    end
end

---@param entity LuaEntity
---@return boolean enabled
---@return boolean manual
local function automatic_targeting(entity,record)
    local gunner
    if entity.driver_is_gunner then gunner=entity.get_driver() else gunner=entity.get_passenger() end
    local targeting=entity.vehicle_automatic_targeting_parameters
    local held=record and record.overkill_state and record.overkill_state.targeting
    if held then
        -- Honor observable native control changes made while the overlay is up.
        if targeting.auto_target_with_gunner or targeting.auto_target_without_gunner then
            record.overkill_state.targeting=table.deepcopy(targeting)
            entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        else targeting=held end
    end
    if gunner and gunner.valid then
        local player=gunner.object_name=="LuaPlayer" and gunner or gunner.player
        local manual=player and player.shooting_state.state~=defines.shooting.not_shooting or false
        return targeting.auto_target_with_gunner and not manual,manual
    end
    return targeting.auto_target_without_gunner,false
end

---@param stack LuaItemStack
---@return number total
---@return string? identity
ammunition=function(stack)
    if not stack or not stack.valid_for_read then return 0 end
    return (stack.count-1)*stack.prototype.magazine_size+stack.ammo,stack.name.."/"..stack.quality.name
end

---@param target LuaEntity?
---@return table|false|nil
local function observe_target(target)
    -- These references come only from native entity queries. Cache immutable
    -- observations for this single updater call; selected-slot writes cannot
    -- move/damage enemies or change diplomacy in the middle of that call.
    if not target or not target.valid then return end
    local key=target.unit_number or target
    local facts=target_cache[key]
    if facts==nil then
        facts=false
        local health=target.health
        if health and health>0 and target.destructible and target.is_military_target then
            facts={surface=target.surface,force=target.force,position=target.position}
        end
        target_cache[key]=facts
    end
    return facts
end

---@param entity LuaEntity
---@param target LuaEntity?
---@param slot table
---@return boolean
local function target_in_range(entity,target,slot)
    local facts=observe_target(target)
    if not facts or facts.surface~=entity.surface then return false end
    local force=entity.force
    local force_index,target_force_index=force.index,facts.force.index
    local relations=hostility_cache[force_index]
    if not relations then relations={};hostility_cache[force_index]=relations end
    local hostile=relations[target_force_index]
    if hostile==nil then
        hostile=facts.force~=force and not force.get_friend(facts.force) and not force.get_cease_fire(facts.force)
        relations[target_force_index]=hostile
    end
    if not hostile then return false end
    if slot.filter and not slot.filter[target.name] then return false end
    local position=entity.position
    local dx,dy=facts.position.x-position.x,facts.position.y-position.y
    if slot.range_mode=="center-to-bounding-box" then
        facts.box=facts.box or target.bounding_box
        local box=facts.box
        dx=math.max(box.left_top.x-position.x,0,position.x-box.right_bottom.x)
        dy=math.max(box.left_top.y-position.y,0,position.y-box.right_bottom.y)
    end
    local distance=dx*dx+dy*dy
    return distance>=slot.minimum*slot.minimum and distance<=slot.maximum*slot.maximum
end

-- Overkill reservations exist only for opted-in scripted vehicles. Launch and
-- impact observations own damage totals; the scheduler expires lost impacts.
-- Cached selector targets are reused, never searched independently here.
---@param record ESIRSpiderRecord
---@return boolean
local function overkill_enabled(record)
    return SMART and preferences(record).overkill and selector_vehicle(record)
end

---@param record ESIRSpiderRecord
---@param clear boolean?
---@param destination LuaEntity? External boarding may already have copied settings.
release_overkill=function(record,clear,destination)
    local pending=record.overkill_state
    if not pending then return end
    if pending.targeting then
        local entity=destination or record.entity
        if ei_lib.entity_check(entity) then
            local current=entity.vehicle_automatic_targeting_parameters
            if not current.auto_target_with_gunner and not current.auto_target_without_gunner then
                entity.vehicle_automatic_targeting_parameters=pending.targeting
            end
        end
        pending.targeting=nil
        if refresh_gui and not transaction and not destination then refresh_gui(record) end
    end
    if clear then
        record.overkill_state=nil
        local runtime=state().overkill
        runtime.active[record.id]=nil
        if not next(runtime.active) then runtime.due={} end
    end
end

---@param record ESIRSpiderRecord
local function hold_overkill(record)
    local pending=record.overkill_state
    if not pending or pending.targeting or not overkill_enabled(record) then return end
    pending.targeting=table.deepcopy(record.entity.vehicle_automatic_targeting_parameters)
    record.entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
    state().overkill.holds=state().overkill.holds+1
    refresh_gui(record)
end

---@param record ESIRSpiderRecord
---@param target LuaEntity?
---@return boolean
local function overkill_covered(record,target)
    local pending=record.overkill_state
    if not pending or not ei_lib.entity_check(target) or not target.health then return false end
    local reservation=pending.targets[target.unit_number or target]
    return reservation~=nil and reservation.damage>=catalog.overkill.budget*target.health
end

---@param record ESIRSpiderRecord
---@param group string
---@return boolean
local function overkill_blocked(record,group)
    local pending=record.overkill_state
    local blocked=pending and pending.blocked[group]
    if not blocked then return false end
    local target=pending.targets[blocked.key]
    if target and target.revision==blocked.revision and overkill_covered(record,target.entity) then return true end
    pending.blocked[group]=nil
    return false
end

---@param record ESIRSpiderRecord
---@param id integer
---@param expired boolean?
local function retire_shot(record,id,expired)
    local pending=record.overkill_state
    local shot=pending and pending.shots[id]
    if not shot then return end
    pending.shots[id]=nil
    local target=pending.targets[shot.key]
    if target then
        target.damage=target.damage-shot.damage;target.shots[id]=nil
        target.revision=target.revision+1
        if not next(target.shots) then pending.targets[shot.key]=nil end
    end
    local counts=state().overkill
    counts.retired=counts.retired+1
    if expired then counts.expired=counts.expired+1 end
end

---@param amount number
---@param resistance table?
---@return number
local function resisted_damage(amount,resistance)
    local decrease=resistance and resistance.decrease or 0
    local percent=resistance and resistance.percent or 0
    if amount>decrease+1 then amount=amount-decrease
    elseif amount>1 then amount=1/(decrease-amount+2)
    else amount=1/(decrease+1) end
    return math.max(0,amount*(1-percent))
end

---@param profile table
---@param distance number
---@return number
local function flight_bound(profile,distance)
    local speed,travel=profile.speed,0
    for ticks=1,catalog.overkill.expiry-30 do
        travel=travel+speed
        if travel>=distance+2 then return ticks end
        speed=speed+profile.acceleration
        if profile.max_speed>0 then speed=math.min(speed,profile.max_speed) end
    end
    return catalog.overkill.expiry+1
end

---@param event EventData.on_script_trigger_effect
function model.on_script_trigger_effect(event)
    local effect=model.script_effects[event.effect_id]
    if not effect then return end
    local source=ei_lib.get_valid_entity(event.cause_entity) or ei_lib.get_valid_entity(event.source_entity)
    if not source or source.type~="spider-vehicle" then return end
    local unit=ei_lib.get_entity_unit_number(source)
    local root=storage.ei and storage.ei.spider_vehicles
    local record=root and unit and root.vehicles[root.units[unit]]
    if not record or not overkill_enabled(record) then return end
    if not effect.launch then
        local pending=record.overkill_state
        if not pending then return end
        local payload=effect.name
        local position=event.target_position or (ei_lib.entity_check(event.target_entity) and event.target_entity.position)
        local candidate,ambiguous
        for id,shot in pairs(pending.shots) do
            if shot.payload==payload and event.tick>=shot.earliest then
                local exact=event.target_entity and pending.targets[shot.key] and pending.targets[shot.key].entity==event.target_entity
                local dx=position and position.x-shot.position.x or math.huge
                local dy=position and position.y-shot.position.y or math.huge
                if exact or dx*dx+dy*dy<=shot.tolerance*shot.tolerance then
                    local previous=candidate and pending.shots[candidate]
                    if previous and (previous.key~=shot.key or previous.damage~=shot.damage) then ambiguous=true end
                    if not candidate or id<candidate then candidate=id end
                end
            end
        end
        -- Equal shots at the same target are interchangeable. Mixed damage or
        -- overlapping target reservations need the safety expiry, not a guess.
        if candidate and not ambiguous then retire_shot(record,candidate) end
        return
    end
    local automatic,manual=automatic_targeting(record.entity,record)
    if not automatic or manual then return end
    local group=catalog.slot_group(record.family,record.entity.selected_gun_index)
    if not catalog.overkill.groups[group] then
        -- Instant bullets and flame streams contribute no predicted damage,
        -- but native aiming can waste these alternative turns on covered targets.
        local target=ei_lib.get_valid_entity(event.target_entity)
        if (group=="mg" or group=="flamer") and overkill_covered(record,target) then
            local pending=record.overkill_state
            local key=target.unit_number or target
            pending.blocked[group]={key=key,revision=pending.targets[key].revision}
            if record.selection and record.selection.slots then
                record.selection.overkill_dirty=true;root.selector.active[record.id]=true
            end
        end
        return
    end
    root.overkill.launches=root.overkill.launches+1
    local ammo_name=effect.name
    local slot_index=record.entity.selected_gun_index
    local loaded=record.entity.get_inventory(defines.inventory.spider_ammo)[slot_index]
    local observed=record.selection and ((record.selection.slots and record.selection.slots[slot_index]) or
        (record.selection.initial and record.selection.initial[slot_index]))
    local observed_name=loaded.valid_for_read and loaded.name or (observed and observed.identity and observed.identity:match("^(.-)/"))
    -- A later mod can clone an instrumented ammo prototype. Its inherited hook
    -- must not silently assign the original ammunition's damage to the clone.
    if observed_name~=ammo_name then root.overkill.unsupported=root.overkill.unsupported+1;return end
    impact_profiles=impact_profiles or prototypes.mod_data[catalog.overkill.profiles].data
    local profile=impact_profiles[ammo_name]
    local target=ei_lib.get_valid_entity(event.target_entity)
    if not target and event.target_position and record.selection then
        for _,candidate in ipairs(record.selection.targets or {}) do
            if ei_lib.entity_check(candidate) then
                local box=candidate.bounding_box
                local p=event.target_position
                if p.x>=box.left_top.x and p.x<=box.right_bottom.x and p.y>=box.left_top.y and p.y<=box.right_bottom.y then
                    if target then target=nil;break end
                    target=candidate
                end
            end
        end
    end
    if not profile or not target or not target.health or target.health<=0 or not target.destructible or not target.is_military_target or
        target.force==source.force or source.force.get_friend(target.force) or source.force.get_cease_fire(target.force) or target.grid then
        root.overkill.unsupported=root.overkill.unsupported+1;return
    end
    local p,q=source.position,target.position
    local dx,dy=q.x-p.x,q.y-p.y
    local distance=math.sqrt(dx*dx+dy*dy)
    local travel=flight_bound(profile,distance+profile.scatter*math.sqrt(2))
    if travel>catalog.overkill.expiry then root.overkill.unsupported=root.overkill.unsupported+1;return end
    local damage_modifier=1
    for name,gun in pairs(source.prototype.guns or {}) do
        if name:match("^ei%-spider%-gun%-(%a+)%-")==group then damage_modifier=gun.attack_parameters.damage_modifier or 1;break end
    end
    local quality=prototypes.quality[event.quality or "normal"]
    local multiplier=(quality and quality.default_multiplier or 1)*(1+source.force.get_ammo_damage_modifier(profile.category))*damage_modifier
    local resistance=target.prototype.resistances or {}
    local damage=0
    for _,part in ipairs(profile.parts) do
        -- Credit only splash whose core reaches the intended point throughout
        -- the configured scatter. Peripheral/secondary damage stays unreserved.
        if not part.radius or part.radius>=profile.scatter*math.sqrt(2) then
            local amount=part.amount*(part.ignore_modifiers and 1 or multiplier)
            if amount>0 then damage=damage+resisted_damage(amount,resistance[part.type])*(part.count or 1) end
        end
    end
    if damage<=0 then root.overkill.unsupported=root.overkill.unsupported+1;return end
    local pending=record.overkill_state
    if not pending then pending={shots={},targets={},blocked={},next_id=0};record.overkill_state=pending end
    local key=target.unit_number or target
    local reservation=pending.targets[key]
    if reservation and overkill_covered(record,target) then pending.blocked[group]={key=key,revision=reservation.revision} end
    if not reservation then reservation={entity=target,damage=0,shots={},revision=0};pending.targets[key]=reservation end
    pending.next_id=pending.next_id+1
    local id=pending.next_id
    local tolerance=math.max(1,profile.scatter*math.sqrt(2)+distance*profile.direction_deviation/2+1)
    pending.shots[id]={key=key,damage=damage,payload=profile.payload,position={x=q.x,y=q.y},tolerance=tolerance,
        fixed=profile.target_type~="entity",earliest=event.tick+math.max(1,math.floor(travel*0.5))}
    reservation.damage=reservation.damage+damage;reservation.shots[id]=true
    root.overkill.active[record.id]=true;root.overkill.reserved=root.overkill.reserved+1
    scheduler.delayed_schedule(root.overkill.due,event.tick+catalog.overkill.expiry,{vehicle=record.id,shot=id,pending=pending})
    if record.selection and record.selection.slots then
        record.selection.overkill_dirty=true;root.selector.active[record.id]=true
    elseif overkill_covered(record,target) then
        -- Native targeting can fire before the vehicle's first budgeted search.
        -- Hold that already-covered shot while the normal search queue catches up.
        hold_overkill(record)
    end
end

---@param tick integer
local function update_overkill(tick)
    if not SMART then return end
    local root=state()
    for _,entry in ipairs(scheduler.delayed_take_due(root.overkill.due,tick)) do
        local record=root.vehicles[entry.vehicle]
        if record and record.overkill_state==entry.pending then retire_shot(record,entry.shot,true) end
    end
    for id in pairs(root.overkill.active) do
        local record=root.vehicles[id]
        if not record then root.overkill.active[id]=nil
        elseif not overkill_enabled(record) then release_overkill(record,true)
        else
            root.overkill.samples=root.overkill.samples+1
            local pending=record.overkill_state
            local automatic,manual=automatic_targeting(record.entity,record)
            if manual or not automatic then release_overkill(record,true)
            elseif pending then
                for _,target in pairs(pending.targets) do
                    local entity=target.entity
                    if not ei_lib.entity_check(entity) or not entity.health or entity.health<=0 or entity.surface~=record.entity.surface or
                        entity.force==record.entity.force or record.entity.force.get_friend(entity.force) or record.entity.force.get_cease_fire(entity.force) then
                        for shot in pairs(target.shots) do retire_shot(record,shot) end
                    else
                        local position=entity.position
                        for id in pairs(target.shots) do
                            local shot=pending.shots[id]
                            if shot.fixed then
                                local dx,dy=position.x-shot.position.x,position.y-shot.position.y
                                if dx*dx+dy*dy>shot.tolerance*shot.tolerance then retire_shot(record,id) end
                            end
                        end
                    end
                end
                if not next(pending.shots) then release_overkill(record,true) end
            end
        end
    end
end

---@param record ESIRSpiderRecord
---@param slot table
---@return boolean
local function slot_eligible(record,slot)
    if not slot then return false end
    if overkill_blocked(record,slot.group) then return false end
    local selection=record.selection
    local total,identity
    if selection.observed_tick==selector_tick and selection.observed_index==slot.index then
        total,identity=selection.observed_total,selection.observed_identity
    else
        total,identity=ammunition(record.entity.get_inventory(defines.inventory.spider_ammo)[slot.index])
    end
    if total<=0 or identity~=slot.identity then return false end
    if target_in_range(record.entity,slot.target,slot) and not overkill_covered(record,slot.target) then return true end
    -- Reuse other cached enemies when the original target dies or moves. A slot
    -- found empty at the last search waits for the next bounded refresh.
    if slot.target or slot.overkill_filtered then
        slot.overkill_filtered=record.preferences.overkill
        slot.target=nil
        for _,target in ipairs(record.selection.targets or {}) do
            if target_in_range(record.entity,target,slot) and not overkill_covered(record,target) then slot.target=target;return true end
        end
    end
    return false
end

---@param record ESIRSpiderRecord
---@param group string
---@param after integer?
---@return table?
local function eligible_slot(record,group,after)
    local slots=record.selection.slots
    local count=#record.entity.get_inventory(defines.inventory.spider_ammo)
    for offset=1,count do
        local index=((after or 0)+offset-1)%count+1
        local slot=slots[index]
        if slot and slot.group==group and slot_eligible(record,slot) then return slot end
    end
end

---@param record ESIRSpiderRecord
---@param slot table
local function select_slot(record,slot)
    release_overkill(record,false)
    record.entity.selected_gun_index=slot.index
    local total,identity=ammunition(record.entity.get_inventory(defines.inventory.spider_ammo)[slot.index])
    record.selection.sample={index=slot.index,total=total,identity=identity,cost=slot.cost}
end

---@param record ESIRSpiderRecord
---@param after string?
---@param tick integer
---@return boolean
local function next_turn(record,after,tick)
    local groups=catalog.groups[record.family]
    local start=0
    for index,group in ipairs(groups) do if group==after then start=index end end
    for offset=1,#groups do
        local group=groups[(start+offset-1)%#groups+1]
        local slot=eligible_slot(record,group)
        if slot then
            record.selection.turn={group=group,shots=0,selected=tick}
            state().selector.turns=state().selector.turns+1
            select_slot(record,slot)
            return true
        end
    end
    record.selection.turn=nil;record.selection.sample=nil
    local pending=record.overkill_state
    if pending then
        local covered=false
        for _,target in pairs(pending.targets) do
            if overkill_covered(record,target.entity) then covered=true;break end
        end
        if covered then hold_overkill(record) else release_overkill(record,false) end
    end
    return false
end

---@param record ESIRSpiderRecord
---@param tick integer
local function sample_turn(record,tick)
    local selector=state().selector
    -- Active membership is established by reset/search and cleared on every
    -- replacement or preference change; no prototype-name parsing is needed here.
    if not record.entity.valid or record.suspended or not record.preferences.cycling then selector.active[record.id]=nil;return end
    local automatic,manual=automatic_targeting(record.entity,record)
    if not automatic then
        selector.active[record.id]=nil;record.selection=nil
        schedule_search(record,tick+(manual and 15 or 60))
        return
    end
    local selection=record.selection
    if not selection or not selection.slots then selector.active[record.id]=nil;return end
    selector.samples=selector.samples+1
    local turn,sample=selection.turn,selection.sample
    if selection.overkill_dirty then
        selection.overkill_dirty=nil
        -- Re-evaluate before another fast native attack. The launch callback
        -- owns reservations; ordinary turn accounting still observes real ammo.
        local slot=selection.slots[record.entity.selected_gun_index]
        if slot and not slot_eligible(record,slot) then next_turn(record,turn and turn.group,tick);return end
    end
    if turn and sample then
        local total,identity=ammunition(record.entity.get_inventory(defines.inventory.spider_ammo)[sample.index])
        selection.observed_tick=tick;selection.observed_index=sample.index
        selection.observed_total=total;selection.observed_identity=identity
        -- Refills and changes of ammo identity reset the baseline, not the turn.
        -- An emptied stack can be the last fired magazine; consumption is capped
        -- at one native attack so inventory removal cannot fabricate a salvo.
        local consumed=(identity==sample.identity or not identity) and math.max(0,sample.total-total) or 0
        if consumed>0 then
            local shots=math.min(1,consumed/math.max(sample.cost,0.00001))
            turn.shots=turn.shots+shots
            if not turn.started then turn.started=tick end
            selection.ready_tick=tick+(selection.slots[sample.index] and selection.slots[sample.index].cooldown or 0)
            turn.last_shot=tick
            local spec=catalog.turns[turn.group]
            if spec.shots and turn.shots>=spec.shots-0.00001 then
                next_turn(record,turn.group,tick)
                return
            elseif turn.group=="rocket" then
                local slot=eligible_slot(record,"rocket",sample.index)
                if slot then select_slot(record,slot);return end
            end
        end
        sample.total=total;sample.identity=identity
        local spec=catalog.turns[turn.group]
        if spec.ticks and turn.started and tick-turn.started>=spec.ticks then next_turn(record,turn.group,tick);return end
        local slot=selection.slots[record.entity.selected_gun_index]
        -- Spidertrons can keep aiming at a nearer enemy inside this gun's
        -- minimum range even when our search finds a valid farther target. The
        -- engine exposes no spider shooting-target setter. Yield a stalled gun
        -- after any observed shared cooldown plus acquisition grace; aiming/damage
        -- and the shared firing delay remain untouched. A sole eligible group
        -- is immediately selected again without an artificial idle period.
        local waiting=turn.last_shot or turn.selected or tick
        if slot and tick>math.max(selection.ready_tick or 0,waiting)+30 then
            next_turn(record,turn.group,tick);return
        end
        if slot and slot.group==turn.group and slot_eligible(record,slot) then return end
        slot=eligible_slot(record,turn.group)
        if slot then select_slot(record,slot);return end
    end
    if not next_turn(record,turn and turn.group,tick) then
        selector.active[record.id]=record.overkill_state and record.overkill_state.targeting and true or nil
        schedule_search(record,tick+catalog.selection.idle_interval)
    end
end

---@param record ESIRSpiderRecord
---@param tick integer
---@return boolean searched
local function search_targets(record,tick)
    if not selector_vehicle(record) then return false end
    local automatic,manual=automatic_targeting(record.entity,record)
    if not automatic then
        state().selector.active[record.id]=nil;record.selection=nil
        schedule_search(record,tick+(manual and 15 or 60));return false
    end
    local entity=record.entity
    local guns=gun_profiles[entity.name]
    if not guns then
        guns={};gun_profiles[entity.name]=guns
        for name,gun in pairs(entity.prototype.guns or {}) do
            local group=name:match("^ei%-spider%-gun%-(%a+)%-")
            if group then
                local attack=gun.attack_parameters
                guns[group]={min_range=attack.min_range,range=attack.range,range_mode=attack.range_mode,ammo_consumption_modifier=attack.ammo_consumption_modifier,cooldown=attack.cooldown}
            end
        end
    end
    local selection=record.selection or {}
    record.selection=selection
    selection.slots={}
    local ammo=entity.get_inventory(defines.inventory.spider_ammo)
    local radius=0
    for index=1,#ammo do
        local stack=ammo[index]
        local group=catalog.slot_group(record.family,index)
        local attack=guns[group]
        if attack and stack.valid_for_read and (preferences(record).special or (group~="artillery" and group~="doeworks")) then
            local kind=ammo_profiles[stack.name]
            if kind==nil then
                local source=stack.prototype.get_ammo_type("vehicle")
                kind=false
                if source then
                    kind={range_modifier=source.range_modifier or 1}
                    if source.target_filter then
                        kind.filter={}
                        for _,name in ipairs(source.target_filter) do kind.filter[name]=true end
                    end
                end
                ammo_profiles[stack.name]=kind
            end
            if kind then
                local total,identity=ammunition(stack)
                local slot={index=index,group=group,identity=identity,minimum=attack.min_range,maximum=attack.range*(kind.range_modifier or 1),range_mode=attack.range_mode,cost=attack.ammo_consumption_modifier,cooldown=attack.cooldown}
                slot.filter=kind.filter
                if total>0 then selection.slots[index]=slot;radius=math.max(radius,slot.maximum) end
            end
        end
    end
    local hostile={}
    for _,force in pairs(game.forces) do
        if force~=entity.force and not entity.force.get_friend(force) and not entity.force.get_cease_fire(force) then hostile[#hostile+1]=force end
    end
    local searched=radius>0 and #hostile>0
    -- No entity limit: close enemies must not hide a farther target outside a
    -- long-range weapon's minimum range. The global budget caps local searches.
    local position=entity.position
    selection.targets=searched and entity.surface.find_entities_filtered{area={{position.x-radius,position.y-radius},{position.x+radius,position.y+radius}},force=hostile,is_military_target=true} or {}
    -- Query filters already establish surface, military status and hostility.
    -- Read each candidate's LuaEntity properties once, then compare all loaded
    -- slots numerically. Repeating the full validity/force check per slot was
    -- costly for fleets with several hundred overlapping search areas.
    local unresolved=0
    local needs_box=false
    for _,slot in pairs(selection.slots) do
        unresolved=unresolved+1
        needs_box=needs_box or slot.range_mode=="center-to-bounding-box"
    end
    for _,target in ipairs(selection.targets) do
        if unresolved==0 then break end
        local facts=observe_target(target)
        if facts then
            local target_position=facts.position
            local dx,dy=target_position.x-position.x,target_position.y-position.y
            local center_distance=dx*dx+dy*dy
            local box_distance=center_distance
            if needs_box then
                facts.box=facts.box or target.bounding_box
                local box=facts.box
                dx=math.max(box.left_top.x-position.x,0,position.x-box.right_bottom.x)
                dy=math.max(box.left_top.y-position.y,0,position.y-box.right_bottom.y)
                box_distance=dx*dx+dy*dy
            end
            for _,slot in pairs(selection.slots) do
                if not slot.target then
                    local distance=slot.range_mode=="center-to-bounding-box" and box_distance or center_distance
                    if distance>=slot.minimum*slot.minimum and distance<=slot.maximum*slot.maximum and (not slot.filter or slot.filter[target.name]) then
                        slot.target=target;unresolved=unresolved-1
                    end
                end
            end
        end
    end
    if not selection.turn then
        local current=selection.slots[entity.selected_gun_index]
        if current and slot_eligible(record,current) then
            selection.turn={group=current.group,shots=0,selected=tick};select_slot(record,current)
        else next_turn(record,nil,tick) end
    end
    -- A restored, loaded vehicle may fire before its first scheduled target
    -- search. Include that shot using the snapshot taken at replacement/control
    -- activation, so the first cannon/battery turn has its intended shot count.
    if selection.initial and selection.turn then
        local index=entity.selected_gun_index
        local before=selection.initial[index]
        local slot=selection.slots[index]
        local total,identity=ammunition(ammo[index])
        if before and slot and before.identity==identity and before.total>total then
            selection.turn.shots=math.min(1,(before.total-total)/math.max(slot.cost,0.00001))
            selection.turn.started=tick
            selection.ready_tick=tick+slot.cooldown
            if selection.turn.group=="rocket" then
                local next_slot=eligible_slot(record,"rocket",index)
                if next_slot then select_slot(record,next_slot) end
            end
        end
    end
    selection.initial=nil
    local active=selection.turn~=nil or (record.overkill_state and record.overkill_state.targeting~=nil)
    state().selector.active[record.id]=active and true or nil
    schedule_search(record,tick+(active and catalog.selection.active_interval or catalog.selection.idle_interval))
    return searched
end

---@param tick integer
local function update_selector(tick)
    if not SMART then return end
    selector_tick=tick;hostility_cache={};target_cache={}
    local root=state()
    for id in pairs(root.selector.active) do
        local record=root.vehicles[id]
        if record then sample_turn(record,tick) else root.selector.active[id]=nil end
    end
    for _,id in ipairs(scheduler.delayed_take_due(root.selector.due,tick)) do
        local record=root.vehicles[id]
        if record and record.search_tick==tick then
            record.search_tick=nil;scheduler.queue_push_unique(root.selector.queue,id)
        end
    end
    local searches=0
    for attempt=1,catalog.selection.searches_per_tick do
        local id=scheduler.queue_pop(root.selector.queue)
        if not id then break end
        local record=root.vehicles[id]
        if record and search_targets(record,tick) then searches=searches+1 end
    end
    root.selector.searches=root.selector.searches+searches
    root.selector.max_searches=math.max(root.selector.max_searches,searches)
end

---@param entity LuaEntity
---@return table? controls
function model.get_weapon_controls(entity)
    local record=register(entity)
    if not record or record.family=="scout" then return end
    local prefs=preferences(record)
    local force=entity.force
    local researched=state().forces[force.index] or catalog.researched_state(force)
    local special=record.family=="assault" and "artillery" or "doeworks"
    local count=#entity.get_inventory(defines.inventory.spider_ammo)
    local mode=catalog.mode(entity.name)
    local native=mode=="native"
    local effective=native and "native" or (selector_vehicle(record) and "smart" or "hold")
    local pending=record.suspended or entity.name~=desired_name(record)
    return {vehicle_id=record.id,cycling=prefs.cycling,special=prefs.special,selected_slot=entity.selected_gun_index,
        overkill=prefs.overkill,effective_overkill=overkill_enabled(record),
        holding_fire=record.overkill_state~=nil and record.overkill_state.targeting~=nil,
        overkill_reason=prefs.overkill and ((not SMART or not prefs.cycling) and "requires-scripted-cycling" or
            (not overkill_enabled(record) and "pending-mode" or (record.overkill_state and record.overkill_state.targeting and "damage-in-flight" or nil))) or nil,
        effective_mode=effective,effective_special=count>(record.family=="assault" and 3 or 4),
        requested_mode=prefs.cycling and (SMART and "smart" or "native") or "hold",smart_setting=SMART,
        special_unlocked=(researched[special] or 0)>0,pending=pending,
        pending_reason=record.suspended and "boarding" or (pending and (record.pending_reason or "queued") or nil)}
end

---@param entity LuaEntity
---@param changes {cycling:boolean?,special:boolean?,selected_slot:integer?,overkill:boolean?}
---@return table? controls
---@return string? error
---@param tick MapTick|nil Current GUI event tick; remote callers may omit it.
function model.set_weapon_controls(entity,changes,tick)
    if type(changes)~="table" then return nil,"invalid-controls" end
    local record=register(entity)
    if not record or record.family=="scout" then return nil,"unsupported-vehicle" end
    for key,value in pairs(changes) do
        if key=="cycling" or key=="special" or key=="overkill" then
            if type(value)~="boolean" then return nil,"invalid-boolean" end
        elseif key=="selected_slot" then
            if type(value)~="number" or value%1~=0 or value<1 or value>#entity.get_inventory(defines.inventory.spider_ammo) then return nil,"invalid-slot" end
        else return nil,"unknown-control" end
    end
    local prefs=preferences(record)
    local cycling=changes.cycling
    if cycling==nil then cycling=prefs.cycling end
    if changes.selected_slot and cycling then return nil,"cycling-enabled" end
    if changes.cycling~=nil then
        if prefs.cycling and not changes.cycling then prefs.selected_slot=entity.selected_gun_index end
        prefs.cycling=changes.cycling
    end
    if changes.special~=nil then prefs.special=changes.special end
    if changes.overkill~=nil then prefs.overkill=changes.overkill end
    if not SMART or not prefs.cycling or not prefs.overkill then release_overkill(record,true) end
    if changes.selected_slot then
        prefs.selected_slot=changes.selected_slot
        entity.selected_gun_index=changes.selected_slot
    end
    enqueue(record);reset_selection(record,tick or game.tick);refresh_gui(record)
    return model.get_weapon_controls(entity)
end

---@param player LuaPlayer
---@param record ESIRSpiderRecord
local function build_gui(player,record)
    local previous=player.gui.relative[GUI_NAME]
    if previous then previous.destroy() end
    local controls=model.get_weapon_controls(record.entity)
    local root=player.gui.relative.add{type="frame",name=GUI_NAME,direction="vertical",
        anchor={gui=defines.relative_gui_type.spider_vehicle_gui,position=defines.relative_gui_position.right}}
    local title=root.add{type="flow",direction="horizontal"}
    title.add{type="label",style="frame_title",caption={"spider-vehicles.controls-title"}}
    title.add{type="empty-widget",style="ei_titlebar_nondraggable_spacer"}
    local content=root.add{type="frame",direction="vertical",style="inside_shallow_frame"}.add{type="flow",name="content",direction="vertical",style="ei_inner_content_flow"}
    local function tags(action) return {parent_gui=GUI_NAME,action=action,vehicle_id=record.id} end
    content.add{type="checkbox",name="cycling",caption={"spider-vehicles.control-cycling"},state=controls.cycling,
        tooltip={"spider-vehicles.control-cycling-"..(SMART and "smart" or "native")},tags=tags("cycling")}
    content.add{type="checkbox",name="overkill",caption={"spider-vehicles.control-overkill"},state=controls.overkill,
        tooltip={"spider-vehicles.control-overkill-help"},tags=tags("overkill")}
    if controls.overkill_reason then
        local label=content.add{type="label",name="overkill_status",caption={"spider-vehicles.overkill-"..controls.overkill_reason}}
        label.style.single_line=false;label.style.maximal_width=350
    end
    content.add{type="checkbox",name="special",caption={"spider-vehicles.control-"..(record.family=="assault" and "artillery" or "doeworks")},state=controls.special,
        enabled=controls.special_unlocked,tooltip={"spider-vehicles.control-mount-help"},tags=tags("special")}
    if not controls.special_unlocked then content.add{type="label",caption={"spider-vehicles.control-locked"}} end
    local choices={}
    for slot=1,#record.entity.get_inventory(defines.inventory.spider_ammo) do
        choices[slot]={"spider-vehicles.control-slot",tostring(slot),{"spider-vehicles.weapon-"..catalog.slot_group(record.family,slot)}}
    end
    content.add{type="drop-down",name="weapon",items=choices,selected_index=controls.selected_slot or 1,visible=not controls.cycling,enabled=not controls.cycling,tags=tags("selected_slot")}
    content.add{type="label",caption={"spider-vehicles.control-effective",{"spider-vehicles.mode-"..controls.effective_mode},{"spider-vehicles.state-"..(controls.effective_special and "on" or "off")}}}
    if controls.pending then
        local reason=controls.pending_reason
        if reason~="moving" and reason~="active-robots" and reason~="logistic-delivery" and reason~="mount-ammo-space" and reason~="boarding" then reason="other" end
        local label=content.add{type="label",caption={"spider-vehicles.control-pending",{"spider-vehicles.pending-"..reason}}}
        label.style.single_line=false;label.style.maximal_width=350
    end
    state().gui[player.index]=record.id
end

refresh_gui=function(record)
    for index,id in pairs(state().gui) do
        if id==record.id then
            local player=game.get_player(index)
            if player and player.opened==record.entity and player.force==record.entity.force then build_gui(player,record)
            else model.on_gui_closed{player_index=index} end
        end
    end
end

function model.on_gui_opened(event)
    if transaction then return end
    local player=game.get_player(event.player_index)
    if not player then return end
    model.on_gui_closed(event)
    local entity=ei_lib.get_valid_entity(event.entity or player.opened)
    if not entity or entity.force~=player.force then return end
    local record=register(entity)
    if record and record.family~="scout" and not record.suspended then build_gui(player,record) end
end

function model.on_gui_closed(event)
    if transaction then return end
    local player=game.get_player(event.player_index)
    if player and player.gui.relative[GUI_NAME] then player.gui.relative[GUI_NAME].destroy() end
    state().gui[event.player_index]=nil
end

function model.on_gui_changed(event)
    local element=event.element
    if not element or not element.valid or element.tags.parent_gui~=GUI_NAME then return end
    local record=state().vehicles[element.tags.vehicle_id]
    local player=game.get_player(event.player_index)
    if not record or not ei_lib.entity_check(record.entity) or not player or player.opened~=record.entity or player.force~=record.entity.force then return end
    local action=element.tags.action
    if action=="selected_slot" then model.set_weapon_controls(record.entity,{selected_slot=element.selected_index},event.tick)
    elseif action=="cycling" or action=="special" or action=="overkill" then model.set_weapon_controls(record.entity,{[action]=element.state},event.tick) end
end

---@param event EventData.on_tick
---@return boolean
function model.has_tick_work(event)
    local root=storage.ei and storage.ei.spider_vehicles
    -- Future buckets must not wake the updater between retries, smoke pulses or
    -- idle target refreshes. Buckets are consumed at their exact scheduled tick.
    return root and (scheduler.queue_length(root.queue)>0 or root.retries[event.tick]~=nil or root.pulses[event.tick]~=nil or
        (SMART and root.overkill and (next(root.overkill.active)~=nil or root.overkill.due[event.tick]~=nil)) or
        (SMART and root.selector and (next(root.selector.active)~=nil or root.selector.due[event.tick]~=nil or scheduler.queue_length(root.selector.queue)>0))) or false
end

function model.updater(event)
    local root=state()
    for _,id in ipairs(scheduler.delayed_take_due(root.retries,event.tick)) do
        local record=root.vehicles[id]
        if record and record.retry_tick==event.tick then record.retry_tick=nil;enqueue(record) end
    end
    for _,pulse in ipairs(scheduler.delayed_take_due(root.pulses,event.tick)) do smoke_pulse(pulse,event.tick) end
    for attempt=1,2 do
        local id=scheduler.queue_pop(root.queue)
        if not id then break end
        local record=root.vehicles[id]
        if record and not record.suspended and ei_lib.entity_check(record.entity) then
            local target=desired_name(record)
            if record.entity.name~=target then
                local ok,reason,unexpected=replace(record,target,event.tick)
                if not ok then
                    if reason~=record.pending_reason then
                        log("ESIR spider upgrade deferred ("..record.entity.unit_number.."): "..tostring(reason))
                        if unexpected then root.failures=root.failures+1 end
                    end
                    record.pending_reason=reason
                    refresh_gui(record)
                    if not record.retry_tick then
                        record.retry_tick=event.tick+120
                        scheduler.delayed_schedule(root.retries,record.retry_tick,id)
                    end
                end
            else
                record.pending_reason=nil
                if not record.selection and not record.search_tick then reset_selection(record,event.tick) end
                refresh_gui(record)
            end
        end
    end
    if SMART then
        update_overkill(event.tick)
        update_selector(event.tick)
    end
end

function model.is_internal_transaction() return transaction end
function model.get_replacement_event() return replacement_event end
function model.get_vehicle_id(entity)
    local unit=ei_lib.get_entity_unit_number(entity)
    return unit and state().units[unit] or nil
end
function model.get_runtime_status()
    local root=state()
    local pending={}
    for _,record in pairs(root.vehicles) do if record.pending_reason then pending[record.id]=record.pending_reason end end
    return {vehicles=scheduler.table_count(root.vehicles),queued=scheduler.queue_length(root.queue),replacements=root.replacements,failures=root.failures,pending=pending,
        smart_setting=SMART,selector_searches=root.selector.searches,selector_samples=root.selector.samples,selector_turns=root.selector.turns,
        selector_max_searches_per_tick=root.selector.max_searches,selector_active=scheduler.table_count(root.selector.active),stored_preferences=scheduler.table_count(root.items),
        overkill={active=scheduler.table_count(root.overkill.active),launches=root.overkill.launches,reserved=root.overkill.reserved,
            retired=root.overkill.retired,expired=root.overkill.expired,holds=root.overkill.holds,samples=root.overkill.samples,unsupported=root.overkill.unsupported}}
end

return model
