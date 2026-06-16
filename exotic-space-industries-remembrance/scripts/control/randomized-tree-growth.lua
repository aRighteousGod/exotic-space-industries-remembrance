--==============================================================================
-- ESIR FILE MAP
-- owns: agricultural tower planted-plant growth jitter
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: on_tower_planted_seed
-- forwarded_events: check_global, on_destroyed_entity, on_tower_planted_seed
-- storage_roots: storage.ei.randomized_tree_growth
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: planted plant event behavior changes
--==============================================================================
local ei_lib = require("lib/lib")

local model = {}

local MAX_OFFSET_TICKS = 30 * 60
local OFFSET_RATIO = 0.10

local function read_prototype_growth_ticks(plant)
    local ok_prototype, prototype = pcall(function()
        return plant.prototype
    end)
    if not (ok_prototype and prototype) then
        return nil
    end

    local ok_growth_ticks, growth_ticks = pcall(function()
        return prototype.growth_ticks
    end)
    if not ok_growth_ticks then
        return nil
    end

    growth_ticks = tonumber(growth_ticks)
    if growth_ticks and growth_ticks > 0 then
        return growth_ticks
    end
    return nil
end

local function get_growth_duration_ticks(plant, current_tick_grown, event_tick)
    current_tick_grown = tonumber(current_tick_grown)
    event_tick = tonumber(event_tick)

    if current_tick_grown and event_tick then
        local scheduled_duration = current_tick_grown - event_tick
        if scheduled_duration > 0 then
            return scheduled_duration
        end
    end

    return read_prototype_growth_ticks(plant)
end

local function get_max_offset_ticks(plant, current_tick_grown, event_tick)
    local growth_duration_ticks = get_growth_duration_ticks(plant, current_tick_grown, event_tick)
    if not growth_duration_ticks then
        return nil
    end

    return math.min(MAX_OFFSET_TICKS, math.floor(growth_duration_ticks * OFFSET_RATIO))
end

local function get_event_entity(event_or_entity)
    if ei_lib.entity_check(event_or_entity) then
        return event_or_entity
    end
    if type(event_or_entity) == "table" then
        return event_or_entity.entity
    end
    return nil
end

local function get_tower_unit_number(tower)
    if not ei_lib.entity_check(tower) then
        return nil
    end
    return ei_lib.get_entity_unit_number(tower)
end

local function get_stream_key(plant, max_offset_ticks)
    return tostring(plant.name or "unknown") .. ":" .. tostring(max_offset_ticks)
end

function model.check_global()
    storage.ei = storage.ei or {}
    if type(storage.ei.randomized_tree_growth) ~= "table" then
        storage.ei.randomized_tree_growth = {}
    end

    local runtime = storage.ei.randomized_tree_growth
    if type(runtime.pending_offsets_by_tower) ~= "table" then
        runtime.pending_offsets_by_tower = {}
    end

    return runtime
end

local function get_balanced_offset(tower, plant, max_offset_ticks)
    local tower_unit_number = get_tower_unit_number(tower)
    if not tower_unit_number then
        return math.random(-max_offset_ticks, max_offset_ticks)
    end

    local runtime = model.check_global()
    local pending_offsets_by_tower = runtime.pending_offsets_by_tower
    local tower_offsets = pending_offsets_by_tower[tower_unit_number]
    if type(tower_offsets) ~= "table" then
        tower_offsets = {}
        pending_offsets_by_tower[tower_unit_number] = tower_offsets
    end

    local stream_key = get_stream_key(plant, max_offset_ticks)
    local pending_offset = tower_offsets[stream_key]
    if pending_offset ~= nil then
        tower_offsets[stream_key] = nil
        return pending_offset
    end

    local offset = math.random(-max_offset_ticks, max_offset_ticks)
    tower_offsets[stream_key] = -offset
    return offset
end

local function randomize_growth(tower, plant, event_tick)
    if not ei_lib.entity_check(plant) then
        return
    end

    local current_tick_grown = plant.tick_grown
    if not current_tick_grown then
        return
    end

    local max_offset_ticks = get_max_offset_ticks(plant, current_tick_grown, event_tick)
    if not max_offset_ticks or max_offset_ticks < 1 then
        return
    end

    -- Pair each tower/plant stream with its inverse offset so throughput does not drift.
    local offset = get_balanced_offset(tower, plant, max_offset_ticks)

    plant.tick_grown = math.max((event_tick or 0) + 1, current_tick_grown + offset)
end

function model.on_tower_planted_seed(event)
    if not event then
        return
    end

    randomize_growth(event.tower, event.plant, event.tick)
end

function model.on_destroyed_entity(event_or_entity)
    local entity = get_event_entity(event_or_entity)
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    local runtime = storage and storage.ei and storage.ei.randomized_tree_growth
    local pending_offsets_by_tower = runtime and runtime.pending_offsets_by_tower
    if pending_offsets_by_tower then
        pending_offsets_by_tower[unit_number] = nil
    end
end

return model
