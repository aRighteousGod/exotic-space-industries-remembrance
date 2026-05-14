--==============================================================================
-- ESIR FILE MAP
-- owns: shared runtime queue, delayed bucket, telemetry, and status helpers
-- loaded_by: control.lua and runtime control modules on demand
-- cadence: helper calls only; no top-level events
-- forwarded_events: audit_queue, bump_counter, clear_queue, compact_queue, delayed_bucket_count, delayed_item_count, delayed_schedule, delayed_take_due, delayed_take_due_through, ensure_delayed_buckets, ensure_module_state, ensure_queue, get_module_status, log_snapshot, queue_item_count, queue_length, queue_peek, queue_pop, queue_pop_matching, queue_pop_queued, queue_push, queue_push_unique, queue_remove_value, set_module_status, status_snapshot, table_count, telemetry_enabled, write_telemetry
-- storage_roots: storage.ei.runtime_scheduler and caller-owned queue tables
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime scheduler schema changes
--==============================================================================

local scheduler = {}

local RUNTIME_STATE_VERSION = 1
local TELEMETRY_FILE = "ei-runtime-scheduler.jsonl"
local MAX_COMPACT_HEAD = 256

local function now_tick()
    return game and game.tick or 0
end

local function count_pairs(tbl)
    local count = 0
    if not tbl then
        return 0
    end

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

local function count_bucket_items(bucket)
    if type(bucket) ~= "table" then
        return 0
    end

    if #bucket > 0 then
        return #bucket
    end

    return count_pairs(bucket)
end

local function encode_record(record)
    if helpers and helpers.table_to_json then
        local ok, encoded = pcall(helpers.table_to_json, record)
        if ok and encoded then
            return encoded
        end
    end

    if game and game.table_to_json then
        local ok, encoded = pcall(game.table_to_json, record)
        if ok and encoded then
            return encoded
        end
    end

    if serpent and serpent.line then
        return serpent.line(record, {sortkeys = true})
    end

    return nil
end

local function write_line(path, line)
    if not line then
        return false
    end

    if helpers and helpers.write_file then
        helpers.write_file(path, line .. "\n", true)
        return true
    end

    if game and game.write_file then
        game.write_file(path, line .. "\n", true)
        return true
    end

    return false
end

local function safe_table(value)
    if type(value) == "table" then
        return value
    end

    return {}
end

function scheduler.ensure_root()
    storage.ei = storage.ei or {}
    storage.ei.runtime_scheduler = storage.ei.runtime_scheduler or {}

    local state = storage.ei.runtime_scheduler
    if state.version ~= RUNTIME_STATE_VERSION then
        state.version = RUNTIME_STATE_VERSION
    end

    state.modules = state.modules or {}
    state.counters = state.counters or {}
    state.telemetry = state.telemetry or {}
    if state.telemetry.enabled == nil then
        state.telemetry.enabled = false
    end
    state.telemetry.file = state.telemetry.file or TELEMETRY_FILE
    state.telemetry.last_snapshot_tick = state.telemetry.last_snapshot_tick or 0

    return state
end

function scheduler.telemetry_enabled()
    local root = scheduler.ensure_root()
    return root.telemetry and root.telemetry.enabled == true
end

function scheduler.ensure_module_state(module_name)
    local root = scheduler.ensure_root()
    root.modules[module_name] = root.modules[module_name] or {
        counters = {},
        last_tick = 0,
        status = {},
        warnings = {},
    }

    return root.modules[module_name]
end

function scheduler.bump_counter(module_name, counter_name, delta)
    local module_state = scheduler.ensure_module_state(module_name)
    local counters = module_state.counters
    delta = delta or 1
    counters[counter_name] = (counters[counter_name] or 0) + delta
    module_state.last_tick = now_tick()
    return counters[counter_name]
end

function scheduler.ensure_queue(queue)
    queue = safe_table(queue)
    queue.items = queue.items or {}
    queue.head = queue.head or 1
    queue.tail = queue.tail or #queue.items
    queue.queued = queue.queued or {}
    return queue
end

function scheduler.queue_length(queue)
    if not queue then
        return 0
    end

    queue = scheduler.ensure_queue(queue)
    return math.max(0, (queue.tail or 0) - (queue.head or 1) + 1)
end

function scheduler.queue_item_count(queue)
    if not queue then
        return 0
    end

    queue = scheduler.ensure_queue(queue)

    local count = 0
    for index = queue.head, queue.tail do
        if queue.items[index] ~= nil then
            count = count + 1
        end
    end

    return count
end

function scheduler.compact_queue(queue, force)
    queue = scheduler.ensure_queue(queue)
    if not force and queue.head <= MAX_COMPACT_HEAD and queue.head <= (queue.tail / 2) then
        return queue
    end

    local new_items = {}
    local new_tail = 0
    for index = queue.head, queue.tail do
        local item = queue.items[index]
        if item ~= nil then
            new_tail = new_tail + 1
            new_items[new_tail] = item
        end
    end

    queue.items = new_items
    queue.head = 1
    queue.tail = new_tail
    return queue
end

function scheduler.queue_push(queue, value)
    queue = scheduler.ensure_queue(queue)
    queue.tail = queue.tail + 1
    queue.items[queue.tail] = value
    return queue
end

function scheduler.queue_push_unique(queue, key, value)
    queue = scheduler.ensure_queue(queue)
    if queue.queued[key] then
        return false, queue
    end

    queue.tail = queue.tail + 1
    queue.items[queue.tail] = value or key
    queue.queued[key] = true
    return true, queue
end

function scheduler.queue_peek(queue)
    queue = scheduler.ensure_queue(queue)

    while queue.head <= queue.tail do
        local value = queue.items[queue.head]
        if value ~= nil then
            return value
        end

        queue.head = queue.head + 1
    end

    queue.items = {}
    queue.head = 1
    queue.tail = 0
    return nil
end

function scheduler.queue_pop(queue, unique_key)
    queue = scheduler.ensure_queue(queue)

    while queue.head <= queue.tail do
        local head = queue.head
        local value = queue.items[head]
        queue.items[head] = nil
        queue.head = head + 1

        if value ~= nil then
            if unique_key ~= nil then
                queue.queued[unique_key] = nil
            elseif queue.queued[value] then
                queue.queued[value] = nil
            end

            scheduler.compact_queue(queue, false)
            return value
        end
    end

    queue.items = {}
    queue.head = 1
    queue.tail = 0
    return nil
end

function scheduler.queue_pop_matching(queue, predicate)
    queue = scheduler.ensure_queue(queue)

    while queue.head <= queue.tail do
        local head = queue.head
        local value = queue.items[head]
        queue.items[head] = nil
        queue.head = head + 1

        if value ~= nil then
            local accepted = not predicate or predicate(value, queue)
            if queue.queued[value] then
                queue.queued[value] = nil
            end
            if accepted then
                scheduler.compact_queue(queue, false)
                return value
            end
        end
    end

    queue.items = {}
    queue.head = 1
    queue.tail = 0
    return nil
end

function scheduler.queue_pop_queued(queue)
    queue = scheduler.ensure_queue(queue)
    return scheduler.queue_pop_matching(queue, function(value)
        return queue.queued[value] == true
    end)
end

function scheduler.queue_remove_value(queue, value)
    if not queue then
        return false
    end

    queue = scheduler.ensure_queue(queue)
    local removed = false
    for index = queue.head, queue.tail do
        if queue.items[index] == value then
            queue.items[index] = nil
            removed = true
        end
    end

    queue.queued[value] = nil
    if removed then
        scheduler.compact_queue(queue, false)
    end

    return removed
end

function scheduler.clear_queue(queue)
    queue = scheduler.ensure_queue(queue)
    queue.items = {}
    queue.head = 1
    queue.tail = 0
    queue.queued = {}
    return queue
end

function scheduler.ensure_delayed_buckets(buckets)
    return safe_table(buckets)
end

function scheduler.delayed_schedule(buckets, tick, value)
    buckets = scheduler.ensure_delayed_buckets(buckets)
    local bucket = buckets[tick]
    if not bucket then
        bucket = {}
        buckets[tick] = bucket
    end

    bucket[#bucket + 1] = value
    return buckets, bucket
end

function scheduler.delayed_take_due(buckets, tick)
    buckets = scheduler.ensure_delayed_buckets(buckets)
    local bucket = buckets[tick]
    buckets[tick] = nil
    return bucket or {}
end

function scheduler.delayed_take_due_through(buckets, current_tick)
    buckets = scheduler.ensure_delayed_buckets(buckets)
    local due_ticks = {}
    for due_tick, bucket in pairs(buckets) do
        if due_tick <= current_tick and type(bucket) == "table" and next(bucket) ~= nil then
            due_ticks[#due_ticks + 1] = due_tick
        end
    end

    if #due_ticks == 0 then
        return {}
    end

    table.sort(due_ticks)
    local due_values = {}
    for _, due_tick in ipairs(due_ticks) do
        local bucket = buckets[due_tick]
        buckets[due_tick] = nil
        for _, value in ipairs(bucket) do
            due_values[#due_values + 1] = value
        end
    end

    return due_values
end

function scheduler.delayed_bucket_count(buckets)
    return count_pairs(buckets)
end

function scheduler.delayed_item_count(buckets)
    local count = 0
    if not buckets then
        return 0
    end

    for _, bucket in pairs(buckets) do
        count = count + count_bucket_items(bucket)
    end

    return count
end

function scheduler.audit_queue(queue)
    queue = scheduler.ensure_queue(queue)
    local span = scheduler.queue_length(queue)
    local items = scheduler.queue_item_count(queue)
    return {
        length = items,
        head = queue.head,
        tail = queue.tail,
        unique = count_pairs(queue.queued),
        span = span,
        holes = math.max(0, span - items),
    }
end

function scheduler.set_module_status(module_name, status)
    local module_state = scheduler.ensure_module_state(module_name)
    module_state.status = status or {}
    module_state.last_tick = now_tick()
    return module_state.status
end

function scheduler.get_module_status(module_name)
    local module_state = scheduler.ensure_module_state(module_name)
    return module_state.status or {}
end

function scheduler.table_count(tbl)
    return count_pairs(tbl)
end

function scheduler.status_snapshot(extra)
    local root = scheduler.ensure_root()
    local snapshot = {
        tick = now_tick(),
        version = root.version,
        modules = root.modules,
        counters = root.counters,
        telemetry = root.telemetry,
    }

    if extra then
        snapshot.extra = extra
    end

    return snapshot
end

function scheduler.write_telemetry(tag, payload, force)
    local root = scheduler.ensure_root()
    if not force and not (root.telemetry and root.telemetry.enabled) then
        return false
    end

    local record = {
        tick = now_tick(),
        tag = tag,
        payload = payload,
    }

    local encoded = encode_record(record)
    if write_line(root.telemetry.file or TELEMETRY_FILE, encoded) then
        root.telemetry.last_snapshot_tick = record.tick
        return true
    end

    return false
end

function scheduler.log_snapshot(tag, extra)
    local snapshot = scheduler.status_snapshot(extra)
    if serpent and serpent.block then
        log("[ESIR runtime-scheduler] " .. tostring(tag or "snapshot") .. " " .. serpent.block(snapshot, {sortkeys = true}))
    else
        log("[ESIR runtime-scheduler] snapshot requested, serpent unavailable")
    end

    scheduler.write_telemetry(tag or "snapshot", snapshot, true)
    return snapshot
end

return scheduler
