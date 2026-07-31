--==============================================================================
-- ESIR FILE MAP
-- owns: event-started regeneration fallback for ei-hemocrystal-wall
-- loaded_by: control.lua
-- cadence: on_entity_damaged schedules delayed one-shots; on_tick only services due buckets
-- forwarded_events: check_global, get_runtime_status, has_tick_work, on_configuration_changed, on_entity_damaged, on_destroyed_entity, updater
-- storage_roots: storage.ei.hemocrystal_wall
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: wall regen cadence or storage schema changes
--==============================================================================

local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")

local model = {}

local RUNTIME_VERSION = 1
local WALL_NAME = "ei-hemocrystal-wall"
local HEAL_INTERVAL = 60
local HEAL_AMOUNT = 0.25 * HEAL_INTERVAL

local function new_runtime()
    return {
        version = RUNTIME_VERSION,
        records_by_key = {},
        due_buckets = {},
        next_due_tick = 0,
    }
end

local function recalculate_next_due_tick(runtime)
    local next_due_tick = 0

    for due_tick, bucket in pairs(runtime.due_buckets) do
        if bucket[1] ~= nil then
            if next_due_tick == 0 or due_tick < next_due_tick then
                next_due_tick = due_tick
            end
        end
    end

    runtime.next_due_tick = next_due_tick
    return next_due_tick
end

function model.check_global()
    storage.ei = storage.ei or {}

    local runtime = storage.ei.hemocrystal_wall
    if type(runtime) ~= "table" or runtime.version ~= RUNTIME_VERSION then
        runtime = new_runtime()
        storage.ei.hemocrystal_wall = runtime
        return runtime
    end

    runtime.records_by_key = type(runtime.records_by_key) == "table" and runtime.records_by_key or {}
    runtime.due_buckets = scheduler.ensure_delayed_buckets(runtime.due_buckets)
    if type(runtime.next_due_tick) ~= "number" then
        runtime.next_due_tick = 0
    end
    if runtime.next_due_tick <= 0 and next(runtime.due_buckets) ~= nil then
        recalculate_next_due_tick(runtime)
    end

    return runtime
end

local function is_hemocrystal_wall(entity)
    return ei_lib.entity_check(entity) and entity.name == WALL_NAME
end

local function get_entity_key(entity)
    return entity.unit_number
end

local function remove_record(runtime, key)
    runtime.records_by_key[key] = nil
end

local function schedule_record(runtime, record, due_tick)
    if record.due_tick then
        return false
    end

    record.due_tick = due_tick
    scheduler.delayed_schedule(runtime.due_buckets, due_tick, record.key)

    if runtime.next_due_tick == 0 or due_tick < runtime.next_due_tick then
        runtime.next_due_tick = due_tick
    end

    return true
end

local function service_record(runtime, record, current_tick)
    local entity = record.entity
    if not is_hemocrystal_wall(entity) then
        remove_record(runtime, record.key)
        return false
    end

    local health = entity.health or 0
    local max_health = entity.max_health
    if health <= 0 or health >= max_health then
        remove_record(runtime, record.key)
        return false
    end

    local new_health = math.min(max_health, health + HEAL_AMOUNT)
    entity.health = new_health

    if new_health < max_health then
        schedule_record(runtime, record, current_tick + HEAL_INTERVAL)
        return true
    end

    remove_record(runtime, record.key)
    return true
end

function model.on_entity_damaged(event)
    local entity = event.entity
    if not is_hemocrystal_wall(entity) then
        return
    end

    local health = event.final_health
    if health <= 0 or health >= entity.max_health then
        return
    end

    local key = get_entity_key(entity)
    if not key then
        return
    end

    local runtime = model.check_global()
    local record = runtime.records_by_key[key]
    if not record then
        record = {
            key = key,
            entity = entity,
        }
        runtime.records_by_key[key] = record
    else
        record.entity = entity
    end

    schedule_record(runtime, record, event.tick + HEAL_INTERVAL)
end

function model.on_destroyed_entity(event)
    local entity = event and event.entity or nil
    if not is_hemocrystal_wall(entity) then
        return
    end

    local key = get_entity_key(entity)
    if not key then
        return
    end

    local runtime = storage and storage.ei and storage.ei.hemocrystal_wall or nil
    if type(runtime) ~= "table" or type(runtime.records_by_key) ~= "table" then
        return
    end

    remove_record(runtime, key)
end

function model.has_tick_work(event)
    local runtime = storage and storage.ei and storage.ei.hemocrystal_wall or nil
    if type(runtime) ~= "table" then
        return false
    end

    local next_due_tick = runtime.next_due_tick or 0
    return next_due_tick > 0 and event.tick >= next_due_tick
end

function model.updater(event)
    local runtime = model.check_global()
    local current_tick = event.tick
    local due_tick = runtime.next_due_tick
    if due_tick <= 0 or current_tick < due_tick then
        return
    end

    local due_keys = scheduler.delayed_take_due(runtime.due_buckets, due_tick)

    for _, key in ipairs(due_keys) do
        local record = runtime.records_by_key[key]
        if record and record.due_tick and record.due_tick <= current_tick then
            record.due_tick = nil
            service_record(runtime, record, current_tick)
        end
    end

    recalculate_next_due_tick(runtime)
end

function model.on_configuration_changed()
    model.check_global()
end

function model.get_runtime_status(current_tick)
    local runtime = model.check_global()

    return {
        tick = current_tick or (game and game.tick or 0),
        record_count = scheduler.table_count(runtime.records_by_key),
        due_bucket_count = scheduler.delayed_bucket_count(runtime.due_buckets),
        due_item_count = scheduler.delayed_item_count(runtime.due_buckets),
        next_due_tick = runtime.next_due_tick or 0,
        heal_interval = HEAL_INTERVAL,
        heal_amount = HEAL_AMOUNT,
    }
end

return model
