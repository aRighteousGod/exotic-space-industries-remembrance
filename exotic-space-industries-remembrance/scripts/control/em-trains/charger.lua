--==============================================================================
-- ESIR FILE MAP
-- owns: EM train and charger runtime, buffs, rebuilds, and research hooks
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init/config rebuild, build/destroy, research-finished, and scheduled tick steps 8 and 9
-- forwarded_events: activate_surface, adjust_surface_count, allocate_surface_budgets, animate_range, apply_buffs, build_charger_entry, build_train_entry, cast_beam, charger_updater, check_buffs, check_global, clear_legacy_runtime_fields, compact_queue, deactivate_surface, dequeue_surface_unit, deregister_all_chargers, deregister_all_trains, enqueue_surface_unit, ensure_runtime_ready, ensure_surface_queue, ensure_train_grace_reserve, entity_check, find_charger, fix_toggle_range, get_charger_power_usage, get_charger_transfer_factor, get_charger_upkeep_factor, get_chunk_bucket, get_entity_name_list, get_existing_entity_name_list, get_item_fuel_value, get_locomotive_demand_factor, get_locomotive_grace_ticks, get_normalized_quality_factor, get_rail_count, get_selected_em_fuel_prototype, get_surface_charger_set, get_surface_scheduler_state, get_train_fuel_fraction, has_enough_energy, index_charger, invalidate_runtime_state, is_em_train, on_built_entity, on_destroyed_entity, on_research_finished, on_scripted_research_burst, printBuffStatus, process_surface_quota, process_surface_scheduler, que_charger, que_train, rebuild_runtime_state, register_charger, register_que_charger, register_que_train, register_train, reinitialize_chargers, reinitialize_trains, remove_charger_entry, remove_train_entry, render_status_rings, requeue_surface_unit, reset_surface_scheduler, return_buffs, set_burner, toggle_range_highlight, train_updater, unindex_charger, unregister_charger, unregister_train, update_charger, update_charger_from_rail, update_chargers, update_rail_counts, update_train, update_trains
-- storage_roots: storage.ei, storage.ei_emt
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, configuration change, entity topology changes, research changes
--==============================================================================
local model = {}
ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")
local get_entity_unit_number = ei_lib.get_entity_unit_number
--ei_rng = require("lib/rng")
-- DOC

-- Charger gets registered when placed
-- Charger properties: Has x-tiles range, consumes energy proportional to rails in range
-- charger range can be increased by research
-- trains in range get charged with fuel that has certain acc and max speed buffs
-- those buffs can be increased by research
-- clicking on a charger shows a gui that displays the current stats and rails it charges

--====================================================================================================
--MAIN
--====================================================================================================

model.chargers = {
    ["ei_charger"] = true,
    ["uncommon-ei_charger"] = true,
    ["rare-ei_charger"] = true,
    ["epic-ei_charger"] = true,
    ["legendary-ei_charger"] = true,
}
model.trains = {
    ["ei_em-locomotive"] = true,
    ["uncommon-ei_em-locomotive"] = true,
    ["rare-ei_em-locomotive"] = true,
    ["epic-ei_em-locomotive"] = true,
    ["legendary-ei_em-locomotive"] = true,
    ["ei_em-locomotive-mu"] = true, --multiple unit consist mod
    ["uncommon-ei_em-locomotive-mu"] = true,
    ["rare-ei_em-locomotive-mu"] = true,
    ["epic-ei_em-locomotive-mu"] = true,
    ["legendary-ei_em-locomotive-mu"] = true,
}

model.wagons = {
    ["ei_em-cargo-wagon"] = true,
    ["ei_em-fluid-wagon"] = true,
    ["uncommon-ei_em-cargo-wagon"] = true,
    ["uncommon-ei_em-fluid-wagon"] = true,
    ["rare-ei_em-cargo-wagon"] = true,
    ["rare-ei_em-fluid-wagon"] = true,
    ["epic-ei_em-cargo-wagon"] = true,
    ["epic-ei_em-fluid-wagon"] = true,
    ["legendary-ei_em-cargo-wagon"] = true,
    ["legendary-ei_em-fluid-wagon"] = true,
}

model.techs = {
    ["ei_eff"] = "eff",
    ["ei_acc"] = "acc",
    ["ei_spd"] = "spd"
}

local EM_CHUNK_SIZE = 32
local EM_RESEARCH_ROLLOUT_BONUS_BUDGET = 16
local EM_RUNTIME_VERSION = 1
local EM_TICKS_PER_SECOND = 60
local EM_LOCO_GRACE_DRAIN_WATTS = 1000000
local QUALITY_CHARGER_UPKEEP_MAX_REDUCTION = 0.20
local QUALITY_CHARGER_TRANSFER_MAX_REDUCTION = 0.12
local QUALITY_LOCO_DEMAND_MAX_REDUCTION = 0.16
local QUALITY_LOCO_MAX_GRACE_TICKS = 480
local EM_CHARGER_RAIL_AUDIT_TICKS = 3600
local EM_CHARGER_RAIL_AUDIT_BUDGET = 4
--UTIL
------------------------------------------------------------------------------------------------------

local function normalize_research_rollout_state(research_rollout_state)
    research_rollout_state = type(research_rollout_state) == "table" and research_rollout_state or {}

    for _, kind in ipairs({"charger", "train"}) do
        local rollout_state = research_rollout_state[kind]
        if type(rollout_state) ~= "table" then
            rollout_state = {}
            research_rollout_state[kind] = rollout_state
        end

        if rollout_state.rescan_pending == nil then
            rollout_state.rescan_pending = false
        end

        rollout_state.target_generation = math.max(
            0,
            math.floor(tonumber(rollout_state.target_generation) or 0)
        )
    end

    return research_rollout_state
end

local function get_research_rollout_entry_generation(entry)
    return math.max(0, math.floor(tonumber(entry and entry.research_rollout_generation) or 0))
end

local function entry_needs_research_rollout(entry, target_generation)
    return get_research_rollout_entry_generation(entry) < math.max(0, tonumber(target_generation) or 0)
end

-- checks if the given name is an em loco
-- might be good to detect if non-standard qualities are in use and use this, or maybe build a list at startup
function model.is_em_train(name)
    return string.find(name, "ei_em%-locomotive") ~= nil
end

function model.entity_check(entity)
    return ei_lib.entity_check(entity)
end


function model.check_global()
    local runtime_was_missing = false
    local runtime_components_missing = false

    if not storage.ei_emt then
        storage.ei_emt = {}
        runtime_was_missing = true
    end

    -- [charger_id] = {entity, rail_count, surface}
    if not storage.ei_emt.chargers then
        storage.ei_emt.chargers = {}
    end
    -- [train_id] = {entity, surface}
    if not storage.ei_emt.trains then
        storage.ei_emt.trains = {}
    end

    if not storage.ei_emt.charger_surfaces then
        storage.ei_emt.charger_surfaces = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.charger_chunks then
        storage.ei_emt.charger_chunks = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.charger_surface_queues then
        storage.ei_emt.charger_surface_queues = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.charger_surface_counts then
        storage.ei_emt.charger_surface_counts = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.charger_active_surfaces then
        storage.ei_emt.charger_active_surfaces = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.charger_active_surface_positions then
        storage.ei_emt.charger_active_surface_positions = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.charger_active_surface_cursor then
        storage.ei_emt.charger_active_surface_cursor = 1
        runtime_components_missing = true
    end

    if storage.ei_emt.charger_rail_audit_cursor == nil then
        storage.ei_emt.charger_rail_audit_cursor = nil
    end

    if storage.ei_emt.charger_rail_audit_requested == nil then
        storage.ei_emt.charger_rail_audit_requested = false
    end

    if storage.ei_emt.charger_rail_audit_last_tick == nil then
        storage.ei_emt.charger_rail_audit_last_tick = 0
    end

    if not storage.ei_emt.train_surface_queues then
        storage.ei_emt.train_surface_queues = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.train_surface_counts then
        storage.ei_emt.train_surface_counts = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.train_active_surfaces then
        storage.ei_emt.train_active_surfaces = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.train_active_surface_positions then
        storage.ei_emt.train_active_surface_positions = {}
        runtime_components_missing = true
    end

    if not storage.ei_emt.train_active_surface_cursor then
        storage.ei_emt.train_active_surface_cursor = 1
        runtime_components_missing = true
    end

    if not storage.ei_emt.research_rollout_chargers then
        storage.ei_emt.research_rollout_chargers = {}
    end

    if not storage.ei_emt.research_rollout_trains then
        storage.ei_emt.research_rollout_trains = {}
    end

    storage.ei_emt.research_rollout_state = normalize_research_rollout_state(
        storage.ei_emt.research_rollout_state
    )

    if not storage.ei_emt.gui then
        storage.ei_emt.gui = {}
    end

    if not storage.ei_emt.buffs then
        storage.ei_emt.buffs = {
            charger_range = 96, -- max: 512
            charger_efficiency = 0, -- max: 0.9
            
            acc_level = 0,
            speed_level = 0
        }
    end

    -- here the power draw for each rail in charger range is calculated
    -- from ~eff*(acc_level + max_speed_level)

    local chargers_exist = next(storage.ei_emt.chargers) ~= nil
    local trains_exist = next(storage.ei_emt.trains) ~= nil
    local charger_scheduler_empty = #storage.ei_emt.charger_active_surfaces == 0
        or next(storage.ei_emt.charger_surface_queues) == nil
        or next(storage.ei_emt.charger_surface_counts) == nil
    local train_scheduler_empty = #storage.ei_emt.train_active_surfaces == 0
        or next(storage.ei_emt.train_surface_queues) == nil
        or next(storage.ei_emt.train_surface_counts) == nil

    if storage.ei_emt.runtime_version ~= EM_RUNTIME_VERSION then
        storage.ei_emt.needs_runtime_rebuild = true
    elseif runtime_components_missing and (chargers_exist or trains_exist) then
        storage.ei_emt.needs_runtime_rebuild = true
    elseif chargers_exist and (next(storage.ei_emt.charger_surfaces) == nil
        or next(storage.ei_emt.charger_chunks) == nil
        or charger_scheduler_empty) then
        storage.ei_emt.needs_runtime_rebuild = true
    elseif trains_exist and train_scheduler_empty then
        storage.ei_emt.needs_runtime_rebuild = true
    elseif storage.ei_emt.needs_runtime_rebuild == nil then
        storage.ei_emt.needs_runtime_rebuild = false
    end

    if runtime_was_missing and next(storage.ei_emt.chargers) == nil and next(storage.ei_emt.trains) == nil then
        storage.ei_emt.runtime_version = EM_RUNTIME_VERSION
        storage.ei_emt.needs_runtime_rebuild = false
    end

end

function model.get_entity_name_list(entity_map)
    local names = {}
    for name in pairs(entity_map) do
        names[#names + 1] = name
    end
    return names
end

function model.get_existing_entity_name_list(entity_map)
    local names = {}
    local entity_prototypes = nil

    -- Factorio 2.0 moved runtime prototype access from `game` to `prototypes`.
    if prototypes and prototypes.entity then
        entity_prototypes = prototypes.entity
    elseif game and game.entity_prototypes then
        entity_prototypes = game.entity_prototypes
    end

    if not entity_prototypes then
        return model.get_entity_name_list(entity_map)
    end

    for name in pairs(entity_map) do
        if entity_prototypes[name] then
            names[#names + 1] = name
        end
    end

    return names
end

function model.get_charger_power_usage(rail_count, charger)
    rail_count = rail_count or 0
    local upkeep_factor = model.get_charger_upkeep_factor(charger)
    -- Research remains the global network scaler; charger quality trims the local
    -- upkeep cost for this specific field node.
    return (rail_count * 250 * 1000 + 10 * 1000 * 1000)
        * (1 - storage.ei_emt.buffs.charger_efficiency)
        * upkeep_factor
        / 60
end

function model.get_normalized_quality_factor(entity)
    if not entity or not entity.quality or not ei_lib.is_valid_number(entity.quality.level) then
        return 0
    end

    local min_level, max_level = ei_lib.get_quality_level_bounds()
    if not ei_lib.is_valid_number(min_level) or not ei_lib.is_valid_number(max_level) or max_level <= min_level then
        return 0
    end

    -- Collapse any quality ladder into 0..1 so our min/max bonuses stay stable
    -- even when other mods add more intermediate quality steps.
    return ei_lib.clamp((entity.quality.level - min_level) / (max_level - min_level), 0, 1)
end

local function unwrap_runtime_entity(entity_or_entry)
    if type(entity_or_entry) == "table" and entity_or_entry.entity then
        return entity_or_entry.entity
    end
    return entity_or_entry
end

function model.get_charger_upkeep_factor(charger)
    charger = unwrap_runtime_entity(charger)
    return 1 - QUALITY_CHARGER_UPKEEP_MAX_REDUCTION * model.get_normalized_quality_factor(charger)
end

function model.get_charger_transfer_factor(charger)
    charger = unwrap_runtime_entity(charger)
    return 1 - QUALITY_CHARGER_TRANSFER_MAX_REDUCTION * model.get_normalized_quality_factor(charger)
end

function model.get_locomotive_demand_factor(train)
    train = unwrap_runtime_entity(train)
    return 1 - QUALITY_LOCO_DEMAND_MAX_REDUCTION * model.get_normalized_quality_factor(train)
end

function model.get_locomotive_grace_ticks(train)
    train = unwrap_runtime_entity(train)
    return math.floor(QUALITY_LOCO_MAX_GRACE_TICKS * model.get_normalized_quality_factor(train) + 0.5)
end

function model.get_selected_em_fuel_prototype()
    local item_prototypes = ei_lib.get_item_prototypes()
    if not item_prototypes then
        return nil
    end

    local acc = storage.ei_emt and storage.ei_emt.buffs and storage.ei_emt.buffs.acc_level or 0
    local speed = storage.ei_emt and storage.ei_emt.buffs and storage.ei_emt.buffs.speed_level or 0
    return item_prototypes["ei_emt-fuel_" .. tostring(acc) .. "_" .. tostring(speed)]
end

function model.get_item_fuel_value(item_like)
    if not item_like then
        return nil
    end

    -- Runtime burner handles may expose either the numeric fuel value directly or
    -- only a prototype identity, so support both paths.
    if ei_lib.is_valid_number(item_like.fuel_value) then
        return item_like.fuel_value
    end

    if type(item_like.name) == "string" then
        local item_prototypes = ei_lib.get_item_prototypes()
        local item_prototype = item_prototypes and item_prototypes[item_like.name] or nil
        if item_prototype and ei_lib.is_valid_number(item_prototype.fuel_value) then
            return item_prototype.fuel_value
        end
    end

    return nil
end

function model.get_train_fuel_fraction(train)
    if not train or not train.burner then
        return 0, nil
    end

    local fuel_value = model.get_item_fuel_value(train.burner.currently_burning)
    if not fuel_value or fuel_value <= 0 then
        return 0, fuel_value
    end

    local remaining = train.burner.remaining_burning_fuel or 0
    return ei_lib.clamp(remaining / fuel_value, 0, 1), fuel_value
end

local function resolve_runtime_tick(current_tick)
    if current_tick ~= nil then
        return current_tick
    end

    return game and game.tick or 0
end

function model.ensure_train_grace_reserve(train, train_entry, current_tick)
    if not train_entry or not train or not train.burner then
        return false
    end

    current_tick = resolve_runtime_tick(current_tick)
    local grace_until_tick = train_entry.grace_until_tick or 0
    if grace_until_tick <= 0 or current_tick > grace_until_tick then
        return false
    end

    local fuel_prototype = model.get_selected_em_fuel_prototype()
    if not fuel_prototype then
        return false
    end

    local fuel_value = model.get_item_fuel_value(fuel_prototype)
    if not fuel_value or fuel_value <= 0 then
        return false
    end

    -- Grace uses the normal research-selected EM fuel and simply tops it up to the
    -- minimum reserve needed to survive until the grace window expires.
    train.burner.currently_burning = fuel_prototype

    local remaining_grace_ticks = math.max(0, grace_until_tick - current_tick)
    local required_reserve = EM_LOCO_GRACE_DRAIN_WATTS * remaining_grace_ticks / EM_TICKS_PER_SECOND
    required_reserve = math.min(required_reserve, fuel_value)
    local current_remaining = train.burner.remaining_burning_fuel or 0

    if current_remaining < required_reserve then
        train.burner.remaining_burning_fuel = required_reserve
    end

    ei_draw_train_glow(train)
    return true
end

function model.get_surface_scheduler_state(prefix)
    return storage.ei_emt[prefix .. "_surface_queues"],
        storage.ei_emt[prefix .. "_surface_counts"],
        storage.ei_emt[prefix .. "_active_surfaces"],
        storage.ei_emt[prefix .. "_active_surface_positions"],
        prefix .. "_active_surface_cursor"
end

function model.reset_surface_scheduler(prefix)
    storage.ei_emt[prefix .. "_surface_queues"] = {}
    storage.ei_emt[prefix .. "_surface_counts"] = {}
    storage.ei_emt[prefix .. "_active_surfaces"] = {}
    storage.ei_emt[prefix .. "_active_surface_positions"] = {}
    storage.ei_emt[prefix .. "_active_surface_cursor"] = 1
end

function model.ensure_surface_queue(prefix, surface_index)
    local queues = storage.ei_emt[prefix .. "_surface_queues"]
    local queue = ei_runtime_scheduler.ensure_queue(queues[surface_index])
    queues[surface_index] = queue
    return queue
end

function model.activate_surface(prefix, surface_index)
    if not surface_index then
        return
    end

    local _, _, active_surfaces, active_positions, cursor_key = model.get_surface_scheduler_state(prefix)
    if active_positions[surface_index] then
        return
    end

    active_surfaces[#active_surfaces + 1] = surface_index
    active_positions[surface_index] = #active_surfaces
    if not storage.ei_emt[cursor_key] or storage.ei_emt[cursor_key] < 1 then
        storage.ei_emt[cursor_key] = 1
    end
end

function model.deactivate_surface(prefix, surface_index)
    if not surface_index then
        return
    end

    local queues, _, active_surfaces, active_positions, cursor_key = model.get_surface_scheduler_state(prefix)
    local remove_index = active_positions[surface_index]
    queues[surface_index] = nil
    if not remove_index then
        return
    end

    table.remove(active_surfaces, remove_index)
    active_positions[surface_index] = nil
    for index = remove_index, #active_surfaces do
        active_positions[active_surfaces[index]] = index
    end

    if #active_surfaces == 0 then
        storage.ei_emt[cursor_key] = 1
        return
    end

    local cursor = storage.ei_emt[cursor_key] or 1
    if remove_index < cursor then
        cursor = cursor - 1
    end
    if cursor > #active_surfaces then
        cursor = 1
    end
    if cursor < 1 then
        cursor = 1
    end
    storage.ei_emt[cursor_key] = cursor
end

function model.adjust_surface_count(prefix, surface_index, delta)
    if not surface_index or not delta or delta == 0 then
        return
    end

    local _, counts = model.get_surface_scheduler_state(prefix)
    local new_count = (counts[surface_index] or 0) + delta
    if new_count <= 0 then
        counts[surface_index] = nil
        model.deactivate_surface(prefix, surface_index)
        return
    end

    counts[surface_index] = new_count
    model.activate_surface(prefix, surface_index)
end

function model.enqueue_surface_unit(prefix, surface_index, unit_number)
    if not unit_number then
        return false
    end

    local queue = model.ensure_surface_queue(prefix, surface_index)
    if queue.queued[unit_number] then
        return false
    end

    local added = ei_runtime_scheduler.queue_push_unique(queue, unit_number)
    return added
end

function model.dequeue_surface_unit(prefix, surface_index)
    local queues = storage.ei_emt[prefix .. "_surface_queues"]
    local queue = queues[surface_index]
    if not queue then
        return nil
    end

    queue = ei_runtime_scheduler.ensure_queue(queue)
    queues[surface_index] = queue

    return ei_runtime_scheduler.queue_pop(queue)
end

function model.requeue_surface_unit(prefix, surface_index, unit_number)
    return model.enqueue_surface_unit(prefix, surface_index, unit_number)
end

function model.allocate_surface_budgets(prefix, budget)
    local _, counts, active_surfaces, _, cursor_key = model.get_surface_scheduler_state(prefix)
    local allocations = {}
    local active_surface_count = #active_surfaces

    budget = math.max(0, math.floor(tonumber(budget) or 0))
    if budget <= 0 or active_surface_count == 0 then
        return allocations
    end

    local cursor = storage.ei_emt[cursor_key] or 1
    if cursor < 1 or cursor > active_surface_count then
        cursor = 1
    end

    local function get_surface_at_offset(offset)
        local position = ((cursor + offset - 2) % active_surface_count) + 1
        return active_surfaces[position]
    end

    if budget < active_surface_count then
        for offset = 1, budget do
            local surface_index = get_surface_at_offset(offset)
            allocations[surface_index] = 1
        end
        storage.ei_emt[cursor_key] = ((cursor + budget - 1) % active_surface_count) + 1
        return allocations
    end

    local remaining = budget
    local total_entities = 0
    for _, surface_index in ipairs(active_surfaces) do
        allocations[surface_index] = 1
        remaining = remaining - 1
        total_entities = total_entities + (counts[surface_index] or 0)
    end

    if remaining <= 0 or total_entities <= 0 then
        return allocations
    end

    local assigned = 0
    for _, surface_index in ipairs(active_surfaces) do
        local extra = math.floor(remaining * ((counts[surface_index] or 0) / total_entities))
        if extra > 0 then
            allocations[surface_index] = allocations[surface_index] + extra
        end
        assigned = assigned + extra
    end

    local leftover = remaining - assigned
    if leftover > 0 then
        for offset = 1, leftover do
            local surface_index = get_surface_at_offset(offset)
            allocations[surface_index] = allocations[surface_index] + 1
        end
        storage.ei_emt[cursor_key] = ((cursor + leftover - 1) % active_surface_count) + 1
    end

    return allocations
end

function model.process_surface_quota(prefix, surface_index, quota, registry_name, update_entity, remove_entry, current_tick)
    local processed = 0
    for _ = 1, quota do
        while true do
            local unit_number = model.dequeue_surface_unit(prefix, surface_index)
            if not unit_number then
                return processed
            end

            local entry = storage.ei_emt[registry_name][unit_number]
            local entity = entry and entry.entity or nil
            if entry and entry.surface_index == surface_index and model.entity_check(entity) then
                update_entity(entity, current_tick)
                if storage.ei_emt[registry_name][unit_number] then
                    model.requeue_surface_unit(prefix, surface_index, unit_number)
                end
                processed = processed + 1
                break
            end

            if entry then
                remove_entry(unit_number, entry)
            end
        end
    end

    return processed
end

function model.process_surface_scheduler(prefix, registry_name, budget, update_entity, remove_entry, current_tick)
    local active_surfaces = storage.ei_emt[prefix .. "_active_surfaces"]
    if not active_surfaces or #active_surfaces == 0 then
        return false
    end

    local surface_order = {}
    for index = 1, #active_surfaces do
        surface_order[index] = active_surfaces[index]
    end

    local allocations = model.allocate_surface_budgets(prefix, budget)
    local processed = 0
    for _, surface_index in ipairs(surface_order) do
        local quota = allocations[surface_index] or 0
        if quota > 0 then
            processed = processed + model.process_surface_quota(prefix, surface_index, quota, registry_name, update_entity, remove_entry, current_tick)
        end
    end

    return processed > 0
end

function model.clear_legacy_runtime_fields()
    storage.ei_emt.chargers_register = nil
    storage.ei_emt.chargers_que = nil
    storage.ei_emt.trains_register = nil
    storage.ei_emt.trains_que = nil
    storage.ei_emt.charger_queue = nil
    storage.ei_emt.train_queue = nil
end

function model.get_surface_charger_set(surface_index, create)
    local surface_set = storage.ei_emt.charger_surfaces[surface_index]
    if not surface_set and create then
        surface_set = {}
        storage.ei_emt.charger_surfaces[surface_index] = surface_set
    end
    return surface_set
end

function model.get_chunk_bucket(surface_index, chunk_x, chunk_y, create)
    local surface_chunks = storage.ei_emt.charger_chunks[surface_index]
    if not surface_chunks and create then
        surface_chunks = {}
        storage.ei_emt.charger_chunks[surface_index] = surface_chunks
    end

    if not surface_chunks then
        return nil
    end

    local x_bucket = surface_chunks[chunk_x]
    if not x_bucket and create then
        x_bucket = {}
        surface_chunks[chunk_x] = x_bucket
    end

    if not x_bucket then
        return nil
    end

    local chunk_bucket = x_bucket[chunk_y]
    if not chunk_bucket and create then
        chunk_bucket = {}
        x_bucket[chunk_y] = chunk_bucket
    end

    return chunk_bucket
end

function model.build_charger_entry(entity)
    local surface_index = ei_lib.get_surface_index(entity.surface)
    local chunk_x, chunk_y = ei_lib.get_chunk_coordinates(entity.position, EM_CHUNK_SIZE)
    local coverage_min_chunk_x, coverage_max_chunk_x, coverage_min_chunk_y, coverage_max_chunk_y =
        ei_lib.get_chunk_coverage(entity.position, storage.ei_emt.buffs.charger_range, EM_CHUNK_SIZE)

    return {
        entity = entity,
        rail_count = model.get_rail_count(entity),
        surface = entity.surface,
        surface_index = surface_index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        coverage_min_chunk_x = coverage_min_chunk_x,
        coverage_max_chunk_x = coverage_max_chunk_x,
        coverage_min_chunk_y = coverage_min_chunk_y,
        coverage_max_chunk_y = coverage_max_chunk_y,
        research_rollout_generation = 0,
    }
end

function model.build_train_entry(entity)
    return {
        entity = entity,
        surface = entity.surface,
        surface_index = ei_lib.get_surface_index(entity.surface),
        -- Explicit grace state lets quality locomotives bridge short coverage gaps
        -- without changing the broader EM fuel/progression system.
        grace_until_tick = 0,
        research_rollout_generation = 0,
    }
end

function model.index_charger(charger_id, charger_entry)
    if not charger_entry or not charger_entry.surface_index then
        return
    end

    local surface_set = model.get_surface_charger_set(charger_entry.surface_index, true)
    surface_set[charger_id] = true

    for chunk_x = charger_entry.coverage_min_chunk_x, charger_entry.coverage_max_chunk_x do
        for chunk_y = charger_entry.coverage_min_chunk_y, charger_entry.coverage_max_chunk_y do
            local chunk_bucket = model.get_chunk_bucket(charger_entry.surface_index, chunk_x, chunk_y, true)
            chunk_bucket[charger_id] = true
        end
    end
end

function model.unindex_charger(charger_id, charger_entry)
    if not charger_entry or not charger_entry.surface_index then
        return
    end

    local surface_index = charger_entry.surface_index
    local surface_set = model.get_surface_charger_set(surface_index, false)
    if surface_set then
        surface_set[charger_id] = nil
        if next(surface_set) == nil then
            storage.ei_emt.charger_surfaces[surface_index] = nil
        end
    end

    local surface_chunks = storage.ei_emt.charger_chunks[surface_index]
    if not surface_chunks then
        return
    end

    for chunk_x = charger_entry.coverage_min_chunk_x, charger_entry.coverage_max_chunk_x do
        local x_bucket = surface_chunks[chunk_x]
        if x_bucket then
            for chunk_y = charger_entry.coverage_min_chunk_y, charger_entry.coverage_max_chunk_y do
                local chunk_bucket = x_bucket[chunk_y]
                if chunk_bucket then
                    chunk_bucket[charger_id] = nil
                    if next(chunk_bucket) == nil then
                        x_bucket[chunk_y] = nil
                    end
                end
            end

            if next(x_bucket) == nil then
                surface_chunks[chunk_x] = nil
            end
        end
    end

    if next(surface_chunks) == nil then
        storage.ei_emt.charger_chunks[surface_index] = nil
    end
end

function model.remove_charger_entry(charger_id, charger_entry)
    charger_entry = charger_entry or storage.ei_emt.chargers[charger_id]
    if not charger_entry then
        return false
    end

    if storage.ei_emt.research_rollout_chargers then
        ei_runtime_scheduler.queue_remove_value(storage.ei_emt.research_rollout_chargers, charger_id)
    end

    model.unindex_charger(charger_id, charger_entry)
    model.adjust_surface_count("charger", charger_entry.surface_index, -1)
    storage.ei_emt.chargers[charger_id] = nil
    return true
end

function model.remove_train_entry(train_id, train_entry)
    train_entry = train_entry or storage.ei_emt.trains[train_id]
    if not train_entry then
        return false
    end

    if storage.ei_emt.research_rollout_trains then
        ei_runtime_scheduler.queue_remove_value(storage.ei_emt.research_rollout_trains, train_id)
    end

    model.adjust_surface_count("train", train_entry.surface_index, -1)
    storage.ei_emt.trains[train_id] = nil
    return true
end

function model.invalidate_runtime_state()
    storage.ei_emt.needs_runtime_rebuild = true
    storage.ei_emt.runtime_version = nil
end

function model.ensure_runtime_ready()
    model.check_global()
    if storage.ei_emt.runtime_rebuild_in_progress or not storage.ei_emt.needs_runtime_rebuild then
        return
    end

    model.rebuild_runtime_state("auto")
end
--formula is 1 - below gets multiplied by power_usage
model.effBuffMultipliers = {
    [1] = 0.25,
    [2] = 0.4,
    [3] = 0.55,
    [4] = 0.7,
    [5] = 0.9
    }

function model.printBuffStatus()
    -- ❂ Exotic Industries: Epiphany of the Crystalline Engine ❂
    -- Whispered by the Obsidian Choir of the 11th Harmonic Core
    -- Forbidden frequencies interpreted through thought-velum transduction

    local weight = em_trains.weight or 500
    local max_speed = em_trains.max_speed or 2
    local max_speed_wagon = em_trains.max_speed_wagon or 10
    local max_speed_sound_leveloff = em_trains.max_speed_sound_leveloff or 1.5
    local max_speed_sound_levelon = em_trains.max_speed_sound_levelon or 0.1
    local em_sound_minimum_speed = em_trains.em_sound_minimum_speed or 0.09
    local em_sound_maximum_speed = em_trains.em_sound_maximum_speed or 2
    local max_power = em_trains.max_power or "1MW"
    local braking_force = em_trains.braking_force or 35
    local braking_force_wagon = em_trains.braking_force_wagon or 10
    local friction_force = em_trains.friction_force or 0.01
    local air_resistance = em_trains.air_resistance or 0.0001

    local eff_level = storage.ei_emt.buffs.charger_efficiency or 1
    local speed_level = storage.ei_emt.buffs.speed_level or 0
    local acc_level = storage.ei_emt.buffs.acc_level or 0

    local acceleration_multiplier = 1 + (0.1 * acc_level)
    local top_speed_multiplier = 1 + (0.1 * speed_level)
    local power_consumption_modifier = 1 - (model.effBuffMultipliers[eff_level] or 0.25)

    -- ⟁ Liturgical Echo of the Luminous Spine ⟁
    local incantation = {
        "☲ EM-Train Diagnostic Invocation Initialized ☲",
        "Weight of the Outer Shell: "..weight.." quartzian masses",
        "Base Kinesis Velocity (Prime Engine): "..max_speed.." ∇tiles/s",
        "Secondary Pod Velocity Threshold: "..max_speed_wagon.." ∇tiles/s",
        "➣ Speed Amplifier Resonance: ×"..top_speed_multiplier.." (λ"..speed_level..")",
        "➣ Acceleration Spiral Gain: ×"..acceleration_multiplier.." (φ"..acc_level..")",
        "➣ Energy Bleed Correction (Null-Waste): ×"..power_consumption_modifier,
        "Divine Conduction Limit: "..max_power.." / ∂t",
        "Tether Brakes – Loco: "..braking_force.." force fragments",
        "Tether Brakes – Cart: "..braking_force_wagon.." force fragments",
        "Slip-Field Intensity: "..friction_force.." ψN",
        "Ambient Etheric Drag (Ω drift): "..air_resistance.." μR",
        "Auditory Phasegate - Entry: "..em_sound_minimum_speed.." Δν",
        "Auditory Phasegate - Severance: "..em_sound_maximum_speed.." Δν"
    }

    for _, line in ipairs(incantation) do
        if line == 1 then
            ei_lib.crystal_echo(line,"default-bold")
        else
            ei_lib.crystal_echo(line)
        end
    end
end

-- helper to get the highest researched tier for a given prefix
local function get_highest_tier(technologies, prefix, max_tier)
    for tier = max_tier, 1, -1 do
        local tech = technologies[prefix .. tier]
        if tech and tech.researched then
            return tier
        end
    end
    return 0
end
--returns actual buff tiers
function model.return_buffs(technologies)
    if not technologies then return false end

    local output = {
        acceleration = get_highest_tier(technologies, "ei_acc_", 20),
        speed        = get_highest_tier(technologies, "ei_spd_", 20),
        efficiency   = get_highest_tier(technologies, "ei_eff_", 5),
    }

    -- strip zero values
    for k,v in pairs(output) do
        if v == 0 then
            output[k] = nil
        end
    end

    if next(output) ~= nil then
        return output
    else
        return false
    end
end


--finds a technologies list to check for buffs
function model.check_buffs(event, force)
    local technologies
    local player
    local output
    if force and force.technologies then
        technologies = force.technologies
        output = model.return_buffs(technologies)
    end
    if not output and game.players and game.players[1] then
        player = game.players[1]
        if player and player.force and player.force.technologies then
            technologies = game.players[1].force.technologies
            output = model.return_buffs(technologies)
        end
    end
    if not output then
        if event and event.player_index then
            player = game.get_player(event.player_index)
            if player and player.force and player.force.technologies then
                technologies = player.force.technologies
                output = model.return_buffs(technologies)
            end
        end
    end
    if output then
        return output
    else
        return false
    end
end

function model.refresh_research_buffs(event, queue_rollout, force)
    model.check_global()

    local buffs = model.check_buffs(event, force)
    if not buffs then
        return false
    end

    local print = false
    local train_rollout = false
    local charger_rollout = false
    queue_rollout = queue_rollout ~= false

    local acceleration_level = buffs["acceleration"] or 0
    if acceleration_level ~= storage.ei_emt.buffs.acc_level then
        storage.ei_emt.buffs.acc_level = acceleration_level
        train_rollout = true
        print = true
    end

    local efficiency_tier = buffs["efficiency"] or 0
    local efficiency_level = model.effBuffMultipliers[efficiency_tier] or 0
    if efficiency_level ~= storage.ei_emt.buffs.charger_efficiency then
        storage.ei_emt.buffs.charger_efficiency = efficiency_level
        charger_rollout = true
        print = true
    end

    local speed_level = buffs["speed"] or 0
    if speed_level ~= storage.ei_emt.buffs.speed_level then
        storage.ei_emt.buffs.speed_level = speed_level
        train_rollout = true
        print = true
    end

    if print then
        model.printBuffStatus()
    end

    if train_rollout and queue_rollout then
        model.request_research_rollout("train")
    end

    if charger_rollout then
        storage.ei_emt.charger_rail_audit_requested = true
        if queue_rollout then
            model.request_research_rollout("charger")
        end
    end

    return train_rollout or charger_rollout
end

function model.ensure_research_rollout_queue(kind)
    model.check_global()

    local field_name
    if kind == "charger" then
        field_name = "research_rollout_chargers"
    elseif kind == "train" then
        field_name = "research_rollout_trains"
    else
        return nil
    end

    local queue = storage.ei_emt[field_name]
    queue = ei_runtime_scheduler.ensure_queue(queue)
    storage.ei_emt[field_name] = queue
    return queue
end

function model.clear_research_rollout_queue(kind)
    local queue = model.ensure_research_rollout_queue(kind)
    if queue then
        ei_runtime_scheduler.clear_queue(queue)
    end

    local rollout_state = model.ensure_research_rollout_state(kind)
    if rollout_state then
        rollout_state.rescan_pending = false
        rollout_state.target_generation = 0
    end
end

function model.get_research_rollout_live_count(kind)
    local counts
    local registry

    if kind == "charger" then
        counts = storage.ei_emt.charger_surface_counts
        registry = storage.ei_emt.chargers
    elseif kind == "train" then
        counts = storage.ei_emt.train_surface_counts
        registry = storage.ei_emt.trains
    else
        return 0
    end

    local total = 0
    if type(counts) == "table" then
        for _, count in pairs(counts) do
            total = total + math.max(0, math.floor(tonumber(count) or 0))
        end
    end

    if total > 0 then
        return total
    end

    total = 0
    for _, entry in pairs(registry or {}) do
        local entity = entry and entry.entity or nil
        if model.entity_check(entity) then
            total = total + 1
        end
    end

    return total
end

local function research_rollout_queue_has_pending_items(queue)
    return queue
        and type(queue.queued) == "table"
        and next(queue.queued) ~= nil
end

local function research_rollout_rescan_should_run(kind)
    local emt = storage and storage.ei_emt or nil
    if not emt then
        return false
    end

    local rollout_state = emt.research_rollout_state and emt.research_rollout_state[kind] or nil
    if not rollout_state or rollout_state.rescan_pending ~= true then
        return false
    end

    local queue
    if kind == "charger" then
        queue = emt.research_rollout_chargers
    elseif kind == "train" then
        queue = emt.research_rollout_trains
    end

    return not research_rollout_queue_has_pending_items(queue)
end

function model.queue_research_rollout(kind)
    local registry_name
    if kind == "charger" then
        registry_name = "chargers"
    elseif kind == "train" then
        registry_name = "trains"
    else
        return 0
    end

    local queue = model.ensure_research_rollout_queue(kind)
    local rollout_state = model.ensure_research_rollout_state(kind)
    local target_generation = rollout_state and rollout_state.target_generation or 0
    local live_count = model.get_research_rollout_live_count(kind)
    if live_count <= 0 or target_generation <= 0 then
        return 0
    end

    if research_rollout_queue_has_pending_items(queue) then
        return 0
    end

    local registry = storage.ei_emt[registry_name] or {}
    local queued = 0
    for unit_number, entry in pairs(registry) do
        local entity = entry and entry.entity or nil
        if model.entity_check(entity) and entry_needs_research_rollout(entry, target_generation) then
            local added = ei_runtime_scheduler.queue_push_unique(queue, unit_number)
            if added then
                queued = queued + 1
            end
        end
    end
    return queued
end

function model.ensure_research_rollout_state(kind)
    model.check_global()
    storage.ei_emt.research_rollout_state = normalize_research_rollout_state(
        storage.ei_emt.research_rollout_state
    )

    if kind == nil then
        return storage.ei_emt.research_rollout_state
    end

    return storage.ei_emt.research_rollout_state[kind]
end

function model.request_research_rollout(kind)
    local queue = model.ensure_research_rollout_queue(kind)
    local rollout_state = model.ensure_research_rollout_state(kind)
    if not queue or not rollout_state then
        return 0
    end

    rollout_state.target_generation = math.max(
        0,
        math.floor(tonumber(rollout_state.target_generation) or 0)
    ) + 1

    if research_rollout_queue_has_pending_items(queue) then
        rollout_state.rescan_pending = true
        return 0
    end

    rollout_state.rescan_pending = false
    return model.queue_research_rollout(kind)
end

function model.service_research_rollout_rescan(kind)
    local queue = model.ensure_research_rollout_queue(kind)
    local rollout_state = model.ensure_research_rollout_state(kind)
    if not queue or not rollout_state or rollout_state.rescan_pending ~= true then
        return 0
    end

    if research_rollout_queue_has_pending_items(queue) then
        return 0
    end

    rollout_state.rescan_pending = false
    return model.queue_research_rollout(kind)
end

function model.process_research_rollout_queue(kind, budget, update_entity, remove_entry, current_tick)
    local registry_name
    if kind == "charger" then
        registry_name = "chargers"
    elseif kind == "train" then
        registry_name = "trains"
    else
        return false
    end

    local queue = model.ensure_research_rollout_queue(kind)
    local rollout_state = model.ensure_research_rollout_state(kind)
    budget = math.max(0, math.floor(tonumber(budget) or 0))
    if budget <= 0 then
        return false
    end

    current_tick = resolve_runtime_tick(current_tick)
    local target_generation = rollout_state and rollout_state.target_generation or 0
    local processed = 0
    for _ = 1, budget do
        local unit_number = ei_runtime_scheduler.queue_pop_queued(queue)
        if not unit_number then
            break
        end

        local registry = storage.ei_emt[registry_name]
        local entry = registry and registry[unit_number] or nil
        local entity = entry and entry.entity or nil
        if entry and model.entity_check(entity) then
            update_entity(entity, current_tick)
            if registry and registry[unit_number] then
                registry[unit_number].research_rollout_tick = current_tick
                registry[unit_number].research_rollout_generation = target_generation
            end
            processed = processed + 1
        elseif entry then
            remove_entry(unit_number, entry)
        end
    end

    return processed > 0
end

--UPDATE
------------------------------------------------------------------------------------------------------

function model.apply_buffs(buff, level, single, entity)
    level = tonumber(level)
    -- game.print(buff .. " - " .. level)
    loop = single or false --all or just entity
    target = entity or nil
    -- level = 15 -- debug
    local status = "buff"
    local override = true --works while beam is enabled
    local radius = storage.ei_emt.buffs.charger_range or 10
    local time = 10
    if single then
        if buff == "eff" then
            local effBuff = model.effBuffMultipliers[level] or 0
            model.render_status_rings(target,status,radius,ei_ticksPerFullUpdate,override)
            --model.make_rings(target, storage.ei_emt.buffs.charger_range, 0.5)
            model.update_charger(target)
        end
        if buff == "acc" then
            radius = 8
            model.render_status_rings(target,status,radius+level,ei_ticksPerFullUpdate,override)
            --model.make_rings(target, 1+level, 0.75)
        end
        if buff == "spd" then
            radius = 8
            model.render_status_rings(target,status,radius+level,ei_ticksPerFullUpdate,override)
            --model.make_rings(v.entity, 1+level, 0.75)
        end
    elseif not single then
       if buff == "eff" then
            model.request_research_rollout("charger")
        elseif buff == "acc" or buff == "spd" then
            model.request_research_rollout("train")
        end
    end
end

function model.register_que_charger(charger)
    if not model.entity_check(charger) then
        return
    end

    model.check_global()
    model.enqueue_surface_unit("charger", ei_lib.get_surface_index(charger.surface), charger.unit_number)
end
function model.register_que_train(train)
    if not model.entity_check(train) then
        return
    end

    model.check_global()
    model.enqueue_surface_unit("train", ei_lib.get_surface_index(train.surface), train.unit_number)
end
function model.que_charger(charger)
    if not model.entity_check(charger) then
        log("que_charger entity check failed")
        return
    end

    model.check_global()
    model.enqueue_surface_unit("charger", ei_lib.get_surface_index(charger.surface), charger.unit_number)

end

function model.que_train(train)

    if not model.entity_check(train) then
        return
    end

    model.check_global()
    model.enqueue_surface_unit("train", ei_lib.get_surface_index(train.surface), train.unit_number)

end

function model.deregister_all_trains()
    model.check_global()
    storage.ei_emt.trains = {}
    model.clear_research_rollout_queue("train")
    model.reset_surface_scheduler("train")
    model.clear_legacy_runtime_fields()
end

function model.deregister_all_chargers()
    model.check_global()
    storage.ei_emt.chargers = {}
    model.clear_research_rollout_queue("charger")
    storage.ei_emt.charger_surfaces = {}
    storage.ei_emt.charger_chunks = {}
    storage.ei_emt.charger_rail_audit_cursor = nil
    storage.ei_emt.charger_rail_audit_requested = false
    storage.ei_emt.charger_rail_audit_last_tick = 0
    model.reset_surface_scheduler("charger")
    model.clear_legacy_runtime_fields()
end

function model.reinitialize_chargers()
    model.check_global()
    model.deregister_all_chargers()

    local charger_names = model.get_existing_entity_name_list(model.chargers)
    if next(charger_names) == nil then
        return
    end

    for _, surface in pairs(game.surfaces) do
		local entities = surface.find_entities_filtered({
			name = charger_names,
		})
        if entities and next(entities) ~= nil then
            for _, entity in pairs(entities) do
                if entity and entity.valid then
                    model.register_charger(entity)
                end
            end
        end
    end
end

function model.reinitialize_trains()
    model.check_global()
    model.deregister_all_trains()

    local train_names = model.get_existing_entity_name_list(model.trains)
    if next(train_names) == nil then
        return
    end

    for _, surface in pairs(game.surfaces) do
		local entities = surface.find_entities_filtered({
			name = train_names,
		})
        if entities and next(entities) ~= nil then
            for _, entity in pairs(entities) do
                if entity and entity.valid then
                    model.register_train(entity)
                end
            end
        end
    end
end

function model.rebuild_runtime_state(reason)
    model.check_global()
    if storage.ei_emt.runtime_rebuild_in_progress then
        return
    end

    storage.ei_emt.runtime_rebuild_in_progress = true
    model.refresh_research_buffs(nil, false)

    model.reinitialize_chargers()
    model.reinitialize_trains()

    storage.ei_emt.runtime_version = EM_RUNTIME_VERSION
    storage.ei_emt.needs_runtime_rebuild = false
    storage.ei_emt.runtime_rebuild_in_progress = false

    model.fix_toggle_range()
    em_trains_gui.mark_dirty()
end

function model.update_chargers(budget, current_tick)
    model.ensure_runtime_ready()
    local did_rollout = model.process_research_rollout_queue(
        "charger",
        EM_RESEARCH_ROLLOUT_BONUS_BUDGET,
        model.update_charger,
        model.remove_charger_entry,
        current_tick
    )
    local queued_rescan = research_rollout_rescan_should_run("charger")
        and model.service_research_rollout_rescan("charger") > 0
    if next(storage.ei_emt.chargers) == nil then
        return did_rollout or queued_rescan
    end

    budget = math.max(1, math.floor(tonumber(budget) or 1))
    local did_update = model.process_surface_scheduler("charger", "chargers", budget, model.update_charger, model.remove_charger_entry, current_tick)
    return did_rollout or queued_rescan or did_update
end

function model.update_trains(budget, current_tick)

    -- update logic: cycle through train updates
    -- EM locomotives nominally burn 1MW against a 1GJ fuel unit,
    -- but out-of-range shutdown is controlled by the script update path.

    model.ensure_runtime_ready()
    local did_rollout = model.process_research_rollout_queue(
        "train",
        EM_RESEARCH_ROLLOUT_BONUS_BUDGET,
        model.update_train,
        model.remove_train_entry,
        current_tick
    )
    local queued_rescan = research_rollout_rescan_should_run("train")
        and model.service_research_rollout_rescan("train") > 0
    if next(storage.ei_emt.trains) == nil then
        return did_rollout or queued_rescan
    end

    budget = math.max(1, math.floor(tonumber(budget) or 1))
    local did_update = model.process_surface_scheduler("train", "trains", budget, model.update_train, model.remove_train_entry, current_tick)
    return did_rollout or queued_rescan or did_update
end

function model.update_train(train, current_tick)

    if not model.entity_check(train) then
        return
    end

    current_tick = resolve_runtime_tick(current_tick)

    local train_entry = storage.ei_emt.trains[train.unit_number]
    if not train_entry then
        return
    end

    if not ei_lib.is_valid_number(train_entry.grace_until_tick) then
        train_entry.grace_until_tick = 0
    end

    if train_entry.research_rollout_tick ~= nil then
        if train_entry.research_rollout_tick == current_tick then
            train_entry.research_rollout_tick = nil
            return true
        end
        train_entry.research_rollout_tick = nil
    end

    local state = model.find_charger(train)
    local status

    if ei_lib.is_valid_number(state) and state > 0 then
        -- Successful coverage refreshes both the burner fill and the countdown for
        -- any future out-of-mesh grace window.
        local grace_ticks = model.get_locomotive_grace_ticks(train)
        if grace_ticks > 0 then
            train_entry.grace_until_tick = current_tick + grace_ticks
        else
            train_entry.grace_until_tick = 0
        end
        status = model.set_burner(train, state)
    elseif model.ensure_train_grace_reserve(train, train_entry, current_tick) then
        -- Grace keeps the train alive briefly, but it is still degraded operation
        -- rather than true charger-backed propulsion.
        status = "warning"
    else
        train_entry.grace_until_tick = 0
        status = model.set_burner(train, 0)
    end

    model.render_status_rings(train,status,8,10)
end

function model.render_status_rings(entity, status, width, timeUntilFade, override)
    if not (entity and entity.valid) then return end
    if not override and not (storage.ei.em_train_que == 2) then return end

    local surface = entity.surface
    local pos = entity
    width = math.min(storage.ei.que_width,width) or 1
    timeUntilFade = storage.ei.que_timetolive or timeUntilFade
    status = status or "default"
    local alpha = storage.ei.que_transparency
    -- Define colors per status
    local status_colors = {
        idle =    {r = 0.3, g = 0.3, b = 0.3, a = alpha},
        working = {r = 0.0, g = 0.8, b = 0.4, a = alpha},
        error =   {r = 1.0, g = 0.1, b = 0.1, a = alpha},
        warning = {r = 1.0, g = 0.5, b = 0.0, a = alpha},
        offline = {r = 0.9, g = 0.2, b = 0.2, a = alpha},
        default = {r = 0.3, g = 0.5, b = 0.9, a = alpha},
        buff =    {r = 0.6, g = 0.1, b = 0.9, a = alpha}, -- royal purple glory
    }

    local ring_color = status_colors[status] or status_colors["default"]

    local ttl = math.ceil(timeUntilFade * 2)


    -- 🔥 Render the status ring — a singular expression of machine-truth
    rendering.draw_circle {
        color = ring_color,
        radius = width,
        width = 1.5,
        filled = false,
        target = pos,
        surface = surface,
        time_to_live = ttl,
        draw_on_ground = false,
        players = game.connected_players,
    }
end

function model.cast_beam(charger, train)
    if not charger or not train or not charger.surface or not train.surface then return end
    if storage.ei.em_train_que == 1 then --mapped in global from settings
        -- create a beam between the charger and the target
        local beam = charger.surface.create_entity({
            name = "ei_charger-beam",
            position = charger.position,
            source_offset = {0, -1},
            source = charger,
            target = train,
            duration = ei_ticksPerFullUpdate/ei_update_functions_length,
            force = charger.force,
        })
    end
end

function ei_draw_train_glow(train, params)
	if not (train and train.valid) or not storage.ei.em_train_glow then return end

	local glow_params = {
	sprite = "emt_train_glow",
	scale_range = {1, 4},
	intensity_range = {40, 77},
	color_pool = {
        {r = 0.1, g = 0.9, b = 1.0},   -- Aetherglow Surge  
        {r = 0.2, g = 0.85, b = 0.95}, -- Ionstream Fade  
        {r = 0.5, g = 0.15, b = 0.8},  -- Null-Spin Iris  
        {r = 0.45, g = 0.1, b = 0.7},  -- Dimensional Vein  
        {r = 0.95, g = 0.1, b = 0.65}, -- Recursive Bloom  
        {r = 0.8, g = 0.05, b = 0.75}, -- Lovelace Wound  
        {r = 0.3, g = 0.7, b = 0.9},   -- Subsurface Whisper  
        {r = 0.6, g = 0.4, b = 0.95},  -- Signal Amaranth 
        {r = 0.9, g = 0.3, b = 0.6}, -- Radiant Pink Nova
        {r = 1.0, g = 0.2, b = 0.8}, -- Plasma Rose Echo
        {r = 0.6, g = 0.1, b = 0.9}, -- Void Orchid Singularity
        {r = 0.7, g = 0.2, b = 1.0}, -- Ultraviolet Pulse Bloom
        {r = 0.0, g = 0.7, b = 1.0}, -- Cryo-Arc Cascade
        {r = 0.1, g = 0.8, b = 0.9}, -- Frozen Signal Drift
        {r = 0.25, g = 0.0, b = 0.4},  -- Void Amethyst
        {r = 0.3,  g = 0.05, b = 0.45}, -- Abyssal Bloom
        {r = 0.35, g = 0.1,  b = 0.5},  -- Blood Orchid
        {r = 0.4,  g = 0.15, b = 0.55}, -- Mycoshard Veil
        {r = 0.22, g = 0.05, b = 0.35}, -- Deep Mnemonic
        {r = 0.28, g = 0.08, b = 0.42}, -- Spectral Resin
        {r = 0.18, g = 0.03, b = 0.3},  -- Eclipse Bloom
        {r = 0.33, g = 0.12, b = 0.48}, -- Cryptic Plum
	},
	blend_mode = "multiplicative",
	apply_runtime_tint = true,
	draw_as_glow = true,
	time_to_live = storage.ei.em_train_glow_timeToLive,
	count = 1
	}

	if params then
        for k, v in pairs(params) do
        glow_params[k] = v
        end
	end


	local color_index = math.random(1, #glow_params.color_pool)
	local color = glow_params.color_pool[color_index]
	local scale = math.random(glow_params.scale_range[1],glow_params.scale_range[2])
	local intensity = math.random(glow_params.intensity_range[1],glow_params.intensity_range[2])
    intensity = intensity/100

	rendering.draw_light {
	  sprite = glow_params.sprite,
	  scale = scale,
	  intensity = intensity,
	  color = color,
	  target = train,
	  surface = train.surface,
	  time_to_live = glow_params.time_to_live,
	  players = game.connected_players,
	  blend_mode = glow_params.blend_mode,
	  apply_runtime_tint = glow_params.apply_runtime_tint,
	  draw_as_glow = glow_params.draw_as_glow,
	}
  -- Apply the glow to each attached EM train car (wagon)
  if train.train and train.train.carriages then
	  for _, car in pairs(train.train.carriages) do
		if car and car.valid and model.wagons[car.name] then
		  rendering.draw_light {
			sprite = glow_params.sprite,
			scale = scale,
			intensity = intensity,
			color = color,
			target = car,
			surface = car.surface,
			time_to_live = glow_params.time_to_live,
			players = game.connected_players,
			blend_mode = glow_params.blend_mode,
			apply_runtime_tint = glow_params.apply_runtime_tint,
			draw_as_glow = glow_params.draw_as_glow,
		  }
		end
	  end
    end
end


function model.set_burner(train, state)
    if not train or not train.burner then return "error" end
    if not ei_lib.is_valid_number(state) or state <= 0 then
        train.burner.remaining_burning_fuel = 0
        return "offline"
    end

    local fuel_prototype = model.get_selected_em_fuel_prototype()
    local fuel_value = model.get_item_fuel_value(fuel_prototype)
    if not fuel_prototype or not fuel_value then
        return "offline"
    end

    train.burner.currently_burning = fuel_prototype
    train.burner.remaining_burning_fuel = fuel_value * state
    if not train.burner.remaining_burning_fuel then return "warning" end
    ei_draw_train_glow(train)
    return "working"
end

function ei_draw_charger_glow(charger, overrides)
    if not (charger and charger.valid) or not storage.ei.em_charger_glow then return end
     local glow_params = {
         sprite = "emt_charger_glow",
         time_to_live = storage.ei.em_charger_glow_timeToLive,
         surface = charger.surface,
         players = game.connected_players,
         blend_mode = "multiplicative-with-alpha",
         apply_runtime_tint = true,
         draw_as_glow = true,
 
         glow_sets = {
             {
                scale_min = 2,
                scale_max = 6,
                intensity_min = 20,
                intensity_max = 30,
                colors = {
                    {r = 0.1, g = 0.9, b = 1.0},   -- Aetherglow Surge  
                    {r = 0.2, g = 0.85, b = 0.95}, -- Ionstream Fade  
                    {r = 0.5, g = 0.15, b = 0.8},  -- Null-Spin Iris  
                    {r = 0.45, g = 0.1, b = 0.7},  -- Dimensional Vein  
                    {r = 0.95, g = 0.1, b = 0.65}, -- Recursive Bloom  
                    {r = 0.8, g = 0.05, b = 0.75}, -- Lovelace Wound  
                    {r = 0.3, g = 0.7, b = 0.9},   -- Subsurface Whisper  
                    {r = 0.6, g = 0.4, b = 0.95},  -- Signal Amaranth 
                    {r = 0.9, g = 0.3, b = 0.6}, -- Radiant Pink Nova
                    {r = 1.0, g = 0.2, b = 0.8}, -- Plasma Rose Echo
                    {r = 0.6, g = 0.1, b = 0.9}, -- Void Orchid Singularity
                    {r = 0.7, g = 0.2, b = 1.0}, -- Ultraviolet Pulse Bloom
                    {r = 0.0, g = 0.7, b = 1.0}, -- Cryo-Arc Cascade
                    {r = 0.1, g = 0.8, b = 0.9}, -- Frozen Signal Drift
                    {r = 0.25, g = 0.0, b = 0.4},  -- Void Amethyst
                    {r = 0.3,  g = 0.05, b = 0.45}, -- Abyssal Bloom
                    {r = 0.35, g = 0.1,  b = 0.5},  -- Blood Orchid
                    {r = 0.4,  g = 0.15, b = 0.55}, -- Mycoshard Veil
                    {r = 0.22, g = 0.05, b = 0.35}, -- Deep Mnemonic
                    {r = 0.28, g = 0.08, b = 0.42}, -- Spectral Resin
                    {r = 0.18, g = 0.03, b = 0.3},  -- Eclipse Bloom
                    {r = 0.33, g = 0.12, b = 0.48}, -- Cryptic Plum
                }
             },
             {
                scale_min = 6,
                scale_max = 18,
                intensity_min = 15,
                intensity_max = 25,
                colors = {
                    {r = 0.1, g = 0.9, b = 1.0},   -- Aetherglow Surge  
                    {r = 0.2, g = 0.85, b = 0.95}, -- Ionstream Fade  
                    {r = 0.5, g = 0.15, b = 0.8},  -- Null-Spin Iris  
                    {r = 0.45, g = 0.1, b = 0.7},  -- Dimensional Vein  
                    {r = 0.95, g = 0.1, b = 0.65}, -- Recursive Bloom  
                    {r = 0.8, g = 0.05, b = 0.75}, -- Lovelace Wound  
                    {r = 0.3, g = 0.7, b = 0.9},   -- Subsurface Whisper  
                    {r = 0.6, g = 0.4, b = 0.95},  -- Signal Amaranth 
                    {r = 0.9, g = 0.3, b = 0.6}, -- Radiant Pink Nova
                    {r = 1.0, g = 0.2, b = 0.8}, -- Plasma Rose Echo
                    {r = 0.6, g = 0.1, b = 0.9}, -- Void Orchid Singularity
                    {r = 0.7, g = 0.2, b = 1.0}, -- Ultraviolet Pulse Bloom
                    {r = 0.0, g = 0.7, b = 1.0}, -- Cryo-Arc Cascade
                    {r = 0.1, g = 0.8, b = 0.9}, -- Frozen Signal Drift
                    {r = 0.25, g = 0.0, b = 0.4},  -- Void Amethyst
                    {r = 0.3,  g = 0.05, b = 0.45}, -- Abyssal Bloom
                    {r = 0.35, g = 0.1,  b = 0.5},  -- Blood Orchid
                    {r = 0.4,  g = 0.15, b = 0.55}, -- Mycoshard Veil
                    {r = 0.22, g = 0.05, b = 0.35}, -- Deep Mnemonic
                    {r = 0.28, g = 0.08, b = 0.42}, -- Spectral Resin
                    {r = 0.18, g = 0.03, b = 0.3},  -- Eclipse Bloom
                    {r = 0.33, g = 0.12, b = 0.48}, -- Cryptic Plum
                }
             },
             {
                scale_min = 2,
                scale_max = 2,
                intensity_min = 65,
                intensity_max = 75,
                colors = {
                    {r = 0, g = 0.4, b = 1.0}, -- OG "always-on"
                    {r = 0.02, g = 0.42, b = 1.0},  -- Skywave Core
                    {r = 0.00, g = 0.38, b = 0.95}, -- Azure Drift
                    {r = 0.03, g = 0.41, b = 0.98}, -- Ghost Current
                    {r = 0.01, g = 0.43, b = 1.0},  -- Cryolux Bloom
                    {r = 0.00, g = 0.39, b = 0.92}, -- Ionosphere Thread
                    {r = 0.00, g = 0.40, b = 0.97}, -- Frozen Surge
                    {r = 0.01, g = 0.37, b = 1.0},  -- Luminous Tide
                    {r = 0.02, g = 0.44, b = 0.99}, -- Cascade Whispered
                    {r = 0.01, g = 0.41, b = 0.96}, -- Subzero Ember
                    {r = 0.00, g = 0.42, b = 0.98}, -- Permafrost Vein
                    {r = 0.02, g = 0.39, b = 1.00}, -- Glacial Spark
                    {r = 0.00, g = 0.43, b = 0.95}, -- Polar Drift
                    {r = 0.01, g = 0.38, b = 0.97}, -- Icepulse Current
                    {r = 0.00, g = 0.41, b = 0.94}, -- Cerulean Thread
                    {r = 0.02, g = 0.40, b = 0.99}, -- Static Flow
                    {r = 0.01, g = 0.39, b = 0.96}, -- Aurora Sliver
                    {r = 0.01, g = 0.42, b = 0.97}, -- Deep Current Shard  
                    {r = 0.00, g = 0.39, b = 0.98}, -- Cryo Pulse Flicker  
                    {r = 0.02, g = 0.40, b = 0.96}, -- Lumen Thread  
                    {r = 0.00, g = 0.41, b = 1.00}, -- Ionstream Channel  
                    {r = 0.01, g = 0.43, b = 0.98}, -- Prism Tide Line  
                }
             }
         }
     }
	if overrides then
		 -- override any top-level params if needed
		 for k, v in pairs(overrides or {}) do
			 glow_params[k] = v
		 end
	end

     --for set,glow_set in pairs(glow_params.glow_sets) do
    --game.print("set: "..set)

    -- randomize glow effects from first two glow sets
    local set = math.random(1, 2)
    local glow_set = glow_params.glow_sets[set]
    local color_index = math.random(1, #glow_set.colors)
    local color = glow_set.colors[color_index]
    local scale = math.random(glow_set.scale_min,glow_set.scale_max)
    local intensity = math.random(glow_set.intensity_min,glow_set.intensity_max)
    intensity = intensity/100
    --game.print("index: "..color_index.." color: "..tostring(color).." scale: "..scale.." intensity: "..intensity)
    rendering.draw_light {
        sprite = glow_params.sprite,
        scale = scale,
        intensity = intensity,
        color = color,
        target = charger,
        surface = glow_params.surface,
        time_to_live = storage.ei.em_charger_glow_timeToLive,
        players = glow_params.players,
        blend_mode = glow_params.blend_mode,
        apply_runtime_tint = glow_params.apply_runtime_tint,
        draw_as_glow = glow_params.draw_as_glow,
        }
    --Always a bit brighter closer to middle
    set = 3
    glow_set = glow_params.glow_sets[set]
    color_index = math.random(1, #glow_set.colors)
    color = glow_set.colors[color_index]
    scale = math.random(glow_set.scale_min,glow_set.scale_max)
    intensity = math.random(glow_set.intensity_min,glow_set.intensity_max)
    intensity = intensity/100
    --game.print("index: "..color_index.." color: "..tostring(color).." scale: "..scale.." intensity: "..intensity)
    rendering.draw_light {
        sprite = glow_params.sprite,
        scale = scale,
        intensity = intensity,
        color = color,
        target = charger,
        surface = glow_params.surface,
        time_to_live = storage.ei.em_charger_glow_timeToLive,
        players = glow_params.players,
        blend_mode = glow_params.blend_mode,
        apply_runtime_tint = glow_params.apply_runtime_tint,
        draw_as_glow = glow_params.draw_as_glow,
        }
 end

function model.has_enough_energy(charger, train)

    if not model.entity_check(charger) or not charger or not charger.energy  then
        return 0
    end

    local energy = charger.energy
    -- Effective charge cost keeps research as the main multiplier, then layers in
    -- local charger quality and local locomotive quality on top.
    local total_needed = (1 - storage.ei_emt.buffs.charger_efficiency)
        * model.get_charger_transfer_factor(charger)
        * model.get_locomotive_demand_factor(train)
        * (1 + 0.1*storage.ei_emt.buffs.acc_level)
        * (1 + 0.1*storage.ei_emt.buffs.speed_level)
        * 1000*1000*100 -- in MJ, up to 400 MJ
    --game.print(total_needed)
    local left = 0
    left = model.get_train_fuel_fraction(train)
    total_needed = total_needed*(1 - left)
    -- TODO only charge when is over 50% full

    if not energy or energy == 0 then return 0 end

    if energy >= total_needed then
        charger.energy = charger.energy - total_needed
        ei_draw_charger_glow(charger,false)
        --game.print("dec")
        return 1
    end

    -- only charge partially
    local dec = (energy/2)/total_needed
    charger.energy = dec
    return dec

end


function model.find_charger(train)
    if not train or not train.surface or not train.position.x or not train.position.y then return 0 end

    local surface_index = ei_lib.get_surface_index(train.surface)
    local chunk_x, chunk_y = ei_lib.get_chunk_coordinates(train.position, EM_CHUNK_SIZE)
    local candidates = model.get_chunk_bucket(surface_index, chunk_x, chunk_y, false)
    if not candidates then
        return 0
    end

    local max_range_sqr = storage.ei_emt.buffs.charger_range * storage.ei_emt.buffs.charger_range
    local parts = 0

    for charger_id in pairs(candidates) do
        local charger_entry = storage.ei_emt.chargers[charger_id]
        local charger = charger_entry and charger_entry.entity or nil
        if model.entity_check(charger) and charger_entry.surface_index == surface_index then
            if ei_lib.is_within_range_squared(train.position, charger.position, max_range_sqr) then
                parts = parts + model.has_enough_energy(charger, train)
                if parts >= 1 then
                    local status = "working"
                    model.cast_beam(charger, train)
                    model.render_status_rings(charger, status, 8, 10)
                    if ei_rng.int("trainglowscale", 1, 40) == 1 then
                        local offset_x = ei_rng.float("chargerbeamx") * 50
                        local offset_y = ei_rng.float("chargerbeamy") * 50
                        local target_position = {
                            x = charger.position.x + offset_x,
                            y = charger.position.y + offset_y
                        }
                        model.cast_beam(charger, target_position)
                    end
                    return 1
                end
            end
        end
    end

    if(ei_lib.is_valid_number(parts)) then
        return parts
    else
        log("parts is"..parts)
    end
end


function model.update_charger_from_rail(rail, sign)

    if not model.entity_check(rail) then
        return
    end

    model.ensure_runtime_ready()

    local surface_index = ei_lib.get_surface_index(rail.surface)
    local chunk_x, chunk_y = ei_lib.get_chunk_coordinates(rail.position, EM_CHUNK_SIZE)
    local chargers = model.get_chunk_bucket(surface_index, chunk_x, chunk_y, false)
    if not chargers then
        return
    end

    local max_range_sqr = storage.ei_emt.buffs.charger_range * storage.ei_emt.buffs.charger_range
    for charger_id in pairs(chargers) do
        local charger_entry = storage.ei_emt.chargers[charger_id]
        local charge = charger_entry and charger_entry.entity or nil
        if model.entity_check(charge) and charger_entry.surface_index == surface_index
            and ei_lib.is_within_range_squared(rail.position, charge.position, max_range_sqr) then
            charger_entry.rail_count = math.max(0, (charger_entry.rail_count or 0) + sign)
            charge.power_usage = model.get_charger_power_usage(charger_entry.rail_count, charge)
        end
    end
end

function model.update_rail_counts()
    if not storage.ei_emt.chargers then return end
    for charger in pairs(storage.ei_emt.chargers) do
        if storage.ei_emt.chargers[charger].entity then
            local charger_entry = storage.ei_emt.chargers[charger]
            charger_entry.rail_count = model.get_rail_count(charger_entry.entity)
            charger_entry.entity.power_usage = model.get_charger_power_usage(charger_entry.rail_count, charger_entry.entity)
        end
    end
end

function model.audit_charger_rail_counts(budget, current_tick)
    model.ensure_runtime_ready()
    current_tick = resolve_runtime_tick(current_tick)
    if not storage.ei_emt.chargers or next(storage.ei_emt.chargers) == nil then
        storage.ei_emt.charger_rail_audit_cursor = nil
        storage.ei_emt.charger_rail_audit_requested = false
        storage.ei_emt.charger_rail_audit_last_tick = current_tick
        return false
    end

    local tick = current_tick
    if not storage.ei_emt.charger_rail_audit_requested
        and tick - (storage.ei_emt.charger_rail_audit_last_tick or 0) < EM_CHARGER_RAIL_AUDIT_TICKS then
        return false
    end

    budget = math.max(1, math.floor(tonumber(budget) or EM_CHARGER_RAIL_AUDIT_BUDGET))
    local processed = 0
    local cursor = storage.ei_emt.charger_rail_audit_cursor
    if cursor == nil or storage.ei_emt.chargers[cursor] == nil then
        cursor = next(storage.ei_emt.chargers)
    end

    while cursor and processed < budget do
        local charger_id = cursor
        local charger_entry = storage.ei_emt.chargers[charger_id]
        cursor = next(storage.ei_emt.chargers, charger_id)

        if charger_entry and model.entity_check(charger_entry.entity) then
            charger_entry.rail_count = model.get_rail_count(charger_entry.entity)
            charger_entry.entity.power_usage = model.get_charger_power_usage(charger_entry.rail_count, charger_entry.entity)
            processed = processed + 1
        elseif charger_entry then
            model.remove_charger_entry(charger_id, charger_entry)
        end
    end

    storage.ei_emt.charger_rail_audit_cursor = cursor
    if cursor == nil then
        storage.ei_emt.charger_rail_audit_requested = false
        storage.ei_emt.charger_rail_audit_last_tick = tick
    end

    return processed > 0
end
ei_rail_types = {"straight-rail", "half-diagonal-rail","curved-rail-a","curved-rail-b","elevated-straight-rail",
"elevated-half-diagonal-rail","elevated-curved-rail-a","elevated-curved-rail-b","legacy-straight-rail",
"legacy-curved-rail","rail-ramp"}

function model.get_rail_count(charger)
    if not charger or not charger.surface then return 0 end
    local radius = storage.ei_emt.buffs.charger_range
    local rail_count = charger.surface.count_entities_filtered({
        position = charger.position,
        radius = radius,
        type = ei_rail_types
    })
    return rail_count
    end

function model.update_charger(charger, current_tick)
    -- charger stil exists/vaild?
    if not model.entity_check(charger) then return false end

    current_tick = resolve_runtime_tick(current_tick)

    local charger_id = charger.unit_number
    local charger_entry = storage.ei_emt.chargers[charger_id]
    if not charger_entry then
        return false
    end

    if charger_entry.research_rollout_tick ~= nil then
        if charger_entry.research_rollout_tick == current_tick then
            charger_entry.research_rollout_tick = nil
            return true
        end
        charger_entry.research_rollout_tick = nil
    end

    if not ei_lib.is_valid_number(charger_entry.rail_count) then
        charger_entry.rail_count = model.get_rail_count(charger)
    end
    local rail_count = charger_entry.rail_count or 1

    local radius = 6
    charger.power_usage = model.get_charger_power_usage(charger_entry.rail_count, charger)

    local status = "default"
    local has_power_usage = charger.power_usage ~= nil
    local has_rails = rail_count > 1
    local has_energy = charger.energy and charger.energy > 100000 -- 1MJ buffer sanity check
    if not has_power_usage and not has_energy then
        status = "error"
        radius = 10
    elseif has_rails and not has_energy then
        status = "offline"
        radius = 12
    elseif has_rails and has_energy then
        status = "working"
        radius = 8
    else
        status = "default"
        radius = 6
    end

    model.render_status_rings(charger, status, radius, 12)

    return true
end


function model.animate_range(charger, fade, player)

    fade = fade or false

    if not model.entity_check(charger) then
        return
    end

    local radius = storage.ei_emt.buffs.charger_range
    local status = "default"
    model.render_status_rings(charger,status,radius,10)

    local draw_parameters = {
        sprite = "ei_emt-radius_big",
        x_scale = radius / 16,
        y_scale = radius / 16,
        target = charger,
        surface = charger.surface,
        draw_on_ground = true,
        players = player and {player} or game.connected_players,
    }
    if fade then
        draw_parameters.time_to_live = ei_ticksPerFullUpdate
    end

    return rendering.draw_sprite(draw_parameters)

    -- 1 tile == 32 pixels
    -- make circles with 8 pixel width, and color fade
    -- {r = 0.1, g = 0.83, b = 0.87} -> r = 0.7

    --model.make_rings(charger, radius, 0.5)

end

--REGISTER
------------------------------------------------------------------------------------------------------

function model.register_charger(entity)
    local charger_id = get_entity_unit_number(entity)
    if not charger_id then return end
    model.check_global()
    local existing_entry = storage.ei_emt.chargers[charger_id]
    if existing_entry then
        model.remove_charger_entry(charger_id, existing_entry)
    end

    local charger_entry = model.build_charger_entry(entity)
    storage.ei_emt.chargers[charger_id] = charger_entry
    model.index_charger(charger_id, charger_entry)
    model.adjust_surface_count("charger", charger_entry.surface_index, 1)

    -- adjust its power usage
    entity.power_usage = model.get_charger_power_usage(charger_entry.rail_count, entity)
    --game.print("register_charger power usage "..entity.power_usage)
    -- set energy to max so that it does not need the full charge
    -- no free lunch
    --entity.energy = entity.prototype.electric_energy_source_prototype.buffer_capacity

    model.register_que_charger(entity)

end


function model.unregister_charger(entity)

    model.check_global()
    local charger_id = get_entity_unit_number(entity)
    if charger_id then
        model.remove_charger_entry(charger_id)
    else
        log("unregister_charger passed nil entity")
    end
end


function model.register_train(entity)

    model.check_global()

    local train_id = get_entity_unit_number(entity)
    if not train_id then
        return
    end
    local existing_entry = storage.ei_emt.trains[train_id]
    if existing_entry then
        model.remove_train_entry(train_id, existing_entry)
    end

    local train_entry = model.build_train_entry(entity)
    storage.ei_emt.trains[train_id] = train_entry
    model.adjust_surface_count("train", train_entry.surface_index, 1)

    model.register_que_train(entity)

end


function model.unregister_train(entity)

    model.check_global()

    local train_id = get_entity_unit_number(entity)
    if not train_id then
        return
    end
    model.remove_train_entry(train_id)
    --em_trails.remove_active_train(entity)
end


--GUI RELATED
------------------------------------------------------------------------------------------------------

local function destroy_range_render(render_object)
    if not render_object then
        return false
    end

    if type(render_object) == "number" then
        local object = rendering.get_object_by_id and rendering.get_object_by_id(render_object) or nil
        if object and object.valid ~= false and object.destroy then
            object.destroy()
            return true
        elseif rendering.destroy then
            rendering.destroy(render_object)
            return true
        end
        return false
    end

    if render_object.valid ~= false and render_object.destroy then
        render_object.destroy()
        return true
    end

    return false
end

local function range_render_is_live(render_object)
    if not render_object then
        return false
    end

    if type(render_object) == "number" then
        local object = rendering.get_object_by_id and rendering.get_object_by_id(render_object) or nil
        return object and object.valid ~= false or rendering.get_object_by_id == nil
    end

    return render_object.valid ~= false
end

local function clear_player_range_highlight(player_index)
    local player_range_state = storage.ei_emt.gui[player_index]
    if not player_range_state then
        return false
    end

    local had_live_render = false
    for key, value in pairs(player_range_state) do
        if key == "render_objects" and type(value) == "table" then
            for _, render_object in pairs(value) do
                had_live_render = range_render_is_live(render_object) or had_live_render
                destroy_range_render(render_object)
            end
        elseif value == true then
            had_live_render = range_render_is_live(key) or had_live_render
            destroy_range_render(key)
        else
            had_live_render = range_render_is_live(value) or had_live_render
            destroy_range_render(value)
        end
    end

    storage.ei_emt.gui[player_index] = nil
    return had_live_render
end

local function draw_player_range_highlight(player)
    if not (player and player.valid) then
        return false
    end

    local player_index = player.index
    local render_objects = {}
    storage.ei_emt.gui[player_index] = {
        render_objects = render_objects,
    }

    for _, charger in pairs(storage.ei_emt.chargers) do
        local render_object = model.animate_range(charger.entity, false, player)
        if render_object then
            render_objects[#render_objects + 1] = render_object
        end
    end

    if #render_objects == 0 then
        storage.ei_emt.gui[player_index] = nil
        return false
    end

    return true
end

function model.fix_toggle_range()

    for _, player in pairs(game.connected_players) do
        
        local player_index = player.index
        if storage.ei_emt.gui[player_index] then
            clear_player_range_highlight(player_index)
            draw_player_range_highlight(player)
        end

    end

end


function model.toggle_range_highlight(player)

    model.check_global()
    model.ensure_runtime_ready()

    local player_index = player.index

    if storage.ei_emt.gui[player_index] then
        if clear_player_range_highlight(player_index) then
            return
        end
    end

    draw_player_range_highlight(player)

end

--HANDLERS 
------------------------------------------------------------------------------------------------------

function model.train_updater(budget, current_tick)
   return model.update_trains(budget, current_tick)

end
function model.charger_updater(budget, current_tick)
    local did_update = model.update_chargers(budget, current_tick)
    model.audit_charger_rail_counts(math.min(EM_CHARGER_RAIL_AUDIT_BUDGET, math.max(1, math.floor(tonumber(budget) or 1))), current_tick)
    return did_update
end

---@param event EventData.on_research_finished
---@return boolean
function model.on_research_finished(event)
    local force = event and event.research and event.research.force or nil
    return model.refresh_research_buffs(event, true, force)
end

---@param force LuaForce|nil
---@return boolean
function model.on_scripted_research_burst(force)
    local player_force = game and game.forces and game.forces.player or nil
    if force and player_force and force.index ~= player_force.index then
        return false
    end

    return model.refresh_research_buffs(nil, true, force)
end
--this deprecated method of singularly checking the completed research
--is more efficient but inexplicably would fail to fire at times
--[[
    local name = event.research.name

    -- name starts with "ei_" and ends with a number
    if not string.match(name, "^ei_") then return end
    if not string.match(name, "%d$") then return end

    -- first always ei_xxx_ so 7 digits, where 7th is _, cut those
    local lenght = string.len(name)
    if lenght < 8 then return end

    -- only last digit is relevant
    local short_name = string.sub(name, 1, 6)

    tier = tonumber(string.sub(name, -2))
    
    if not tier then 
      tier = tonumber(string.sub(name, -1))
    end 

    if not tier then error("Can not get tier for tech "..name) end 

    if model.techs[short_name] then
      -- game.print(short_name .. " - " .. tier)
      model.apply_buffs(model.techs[short_name], tonumber(tier))
      model.printBuffStatus()
    
    end
    ]]



function model.on_built_entity(entity)

    if not model.entity_check(entity) then
        return
    end

    local is_charger = model.chargers[entity.name]
    local is_rail = ei_lib.table_contains_value(ei_rail_types, entity.name)
    local is_train = model.trains[entity.name]

    if is_charger or is_rail or is_train then
        model.ensure_runtime_ready()
    end

    if is_charger then
        model.register_charger(entity)
        model.animate_range(entity, true, nil)
        model.fix_toggle_range()
        em_trains_gui.mark_dirty()
    elseif is_rail then
        model.update_charger_from_rail(entity, 1)
        em_trains_gui.mark_dirty()
    elseif is_train then
        model.register_train(entity)
        em_trains_gui.mark_dirty()
    end
end


function model.on_destroyed_entity(entity)

    if not model.entity_check(entity) then
        return
    end

    local is_charger = model.chargers[entity.name]
    local is_rail = ei_lib.table_contains_value(ei_rail_types, entity.name)
    local is_train = model.trains[entity.name]

    if is_charger or is_rail or is_train then
        model.ensure_runtime_ready()
    end

    if is_charger then
        model.unregister_charger(entity)
        em_trains_gui.mark_dirty()
    elseif is_rail then
        model.update_charger_from_rail(entity, -1)
        em_trains_gui.mark_dirty()
    elseif is_train then
        model.unregister_train(entity)
        em_trains_gui.mark_dirty()
    end
end

commands.add_command("rescan_emt", "Rebuilds EM train chargers, train queues, and spatial indexes.", function(command)
    local player = command.player_index and game.get_player(command.player_index) or nil
    if not player or not player.admin then
        return
    end

    ei_lib.crystal_echo("EM train runtime rescan initiated.")
    model.rebuild_runtime_state("manual")
    ei_lib.crystal_echo("EM train runtime rescan complete.")
end)

function model.get_runtime_status()
    model.check_global()

    local charger_surface_queue_items = 0
    for _, queue in pairs(storage.ei_emt.charger_surface_queues or {}) do
        charger_surface_queue_items = charger_surface_queue_items + ei_runtime_scheduler.queue_item_count(queue)
    end

    local train_surface_queue_items = 0
    for _, queue in pairs(storage.ei_emt.train_surface_queues or {}) do
        train_surface_queue_items = train_surface_queue_items + ei_runtime_scheduler.queue_item_count(queue)
    end

    local research_rollout_charger_queue_items = ei_runtime_scheduler.queue_item_count(storage.ei_emt.research_rollout_chargers)
    local research_rollout_train_queue_items = ei_runtime_scheduler.queue_item_count(storage.ei_emt.research_rollout_trains)
    local research_rollout_state = model.ensure_research_rollout_state()

    local status = {
        charger_count = ei_runtime_scheduler.table_count(storage.ei_emt.chargers),
        train_count = ei_runtime_scheduler.table_count(storage.ei_emt.trains),
        charger_active_surface_count = #(storage.ei_emt.charger_active_surfaces or {}),
        train_active_surface_count = #(storage.ei_emt.train_active_surfaces or {}),
        charger_surface_queue_items = charger_surface_queue_items,
        train_surface_queue_items = train_surface_queue_items,
        research_rollout_charger_queue_items = research_rollout_charger_queue_items,
        research_rollout_train_queue_items = research_rollout_train_queue_items,
        research_rollout_charger_rescan_pending = research_rollout_state.charger.rescan_pending == true,
        research_rollout_train_rescan_pending = research_rollout_state.train.rescan_pending == true,
        research_rollout_charger_target_generation = research_rollout_state.charger.target_generation or 0,
        research_rollout_train_target_generation = research_rollout_state.train.target_generation or 0,
        needs_runtime_rebuild = storage.ei_emt.needs_runtime_rebuild == true,
        chargers = ei_runtime_scheduler.table_count(storage.ei_emt.chargers),
        trains = ei_runtime_scheduler.table_count(storage.ei_emt.trains),
        charger_active_surfaces = #(storage.ei_emt.charger_active_surfaces or {}),
        train_active_surfaces = #(storage.ei_emt.train_active_surfaces or {}),
    }

    ei_runtime_scheduler.set_module_status("em-trains", status)
    return status
end


return model
