--==============================================================================
-- ESIR FILE MAP
-- owns: shared runtime queue, delayed bucket, telemetry, and status helpers
-- loaded_by: control.lua and runtime control modules on demand
-- cadence: helper calls only; no top-level events
-- forwarded_events: audit_queue, bump_counter, clear_queue, compact_queue, delayed_bucket_count, delayed_item_count, delayed_schedule, delayed_take_due, delayed_take_due_through, ensure_delayed_buckets, ensure_module_state, ensure_queue, get_module_status, log_snapshot, queue_item_count, queue_length, queue_peek, queue_peek_last, queue_pop, queue_pop_matching, queue_pop_queued, queue_push, queue_push_unique, queue_remove_value, set_module_status, status_snapshot, table_count, telemetry_enabled, write_telemetry
--   begin_rebuild, update_rebuild, finish_rebuild, report_rebuild, peek_rebuilds, peek_rebuild_state
-- storage_roots: storage.ei.runtime_scheduler and caller-owned queue tables
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime scheduler schema changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-scheduler.md#contract

local scheduler = {}

local RUNTIME_STATE_VERSION = 1
local TELEMETRY_FILE = "ei-runtime-scheduler.jsonl"
local MAX_COMPACT_HEAD = 256

-- blueprint-ref: .codex/esir/blueprints/runtime-scheduler.md#tick-flow
-- Explicit observation timestamps follow the caller's event; omitted arguments
-- retain the legacy game-available boundary fallback, including tick zero.
local function now_tick(current_tick)
    if type(current_tick) == "number" then
        return current_tick
    end
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

---@param module_name string
---@param counter_name string
---@param delta number|nil
---@param current_tick MapTick|nil Supplied callback tick; omission retains clock fallback.
---@return number
function scheduler.bump_counter(module_name, counter_name, delta, current_tick)
    local module_state = scheduler.ensure_module_state(module_name)
    local counters = module_state.counters
    delta = delta or 1
    counters[counter_name] = (counters[counter_name] or 0) + delta
    module_state.last_tick = now_tick(current_tick)
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

---Read the last non-nil FIFO value without removing it or changing uniqueness state.
---Membership and domain liveness remain the caller's responsibility.
---Use for lifecycle repair; hot-path owners can cache their last pushed payload.
---@param queue table?
---@return any
function scheduler.queue_peek_last(queue)
    if not queue or not queue.items then return nil end
    for index = queue.tail or 0, queue.head or 1, -1 do
        local value = queue.items[index]
        if value ~= nil then return value end
    end
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

-- blueprint-ref: .codex/esir/blueprints/runtime-scheduler.md#contract
-- This variant treats the caller's queued membership table as the live set.
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

-- blueprint-ref: .codex/esir/blueprints/runtime-scheduler.md#tick-flow
-- Catch up skipped service ticks without substituting another clock source.
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

---Earliest nonempty delayed bucket; false represents a known empty set.
---@param buckets table<number,any>
---@return number|false
function scheduler.delayed_next_due_tick(buckets)
    local earliest = false
    for tick, bucket in pairs(buckets) do
        if type(bucket) == "table" and next(bucket) ~= nil and (not earliest or tick < earliest) then
            earliest = tick
        end
    end
    return earliest
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

---@param module_name string
---@param status table|nil
---@param current_tick MapTick|nil
---@return table
function scheduler.set_module_status(module_name, status, current_tick)
    local module_state = scheduler.ensure_module_state(module_name)
    module_state.status = status or {}
    module_state.last_tick = now_tick(current_tick)
    return module_state.status
end

function scheduler.get_module_status(module_name)
    local module_state = scheduler.ensure_module_state(module_name)
    return module_state.status or {}
end

function scheduler.table_count(tbl)
    return count_pairs(tbl)
end

---@param extra table|nil
---@param current_tick MapTick|nil
---@return table Shared records are referenced, not deep copied.
function scheduler.status_snapshot(extra, current_tick)
    local root = scheduler.ensure_root()
    local snapshot = {
        tick = now_tick(current_tick),
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

---@param tag string
---@param payload any
---@param force boolean|nil Explicit diagnostics may bypass the enable flag.
---@param current_tick MapTick|nil
---@return boolean
function scheduler.write_telemetry(tag, payload, force, current_tick)
    local root = scheduler.ensure_root()
    if not force and not (root.telemetry and root.telemetry.enabled) then
        return false
    end

    local record = {
        tick = now_tick(current_tick),
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

---@param tag string|nil
---@param extra table|nil
---@param current_tick MapTick|nil
---@return table
function scheduler.log_snapshot(tag, extra, current_tick)
    current_tick = now_tick(current_tick)
    local snapshot = scheduler.status_snapshot(extra, current_tick)
    if serpent and serpent.block then
        log("[ESIR runtime-scheduler] " .. tostring(tag or "snapshot") .. " " .. serpent.block(snapshot, {sortkeys = true}))
    else
        log("[ESIR runtime-scheduler] snapshot requested, serpent unavailable")
    end

    scheduler.write_telemetry(tag or "snapshot", snapshot, true, current_tick)
    return snapshot
end

-- blueprint-ref: .codex/esir/blueprints/runtime-scheduler.md#rebuild-reporting
-- Observation only: owners retain their work, membership, budgets and deadlines.
---@class EiRebuildDetails
---@field reason string|nil
---@field phase string|nil
---@field state 'queued'|'running'|'waiting'|nil
---@field completed number|nil
---@field total number|false|nil False explicitly clears an unknown denominator.
---@field unit string|nil
---@field waiting_reason string|false|nil
---@field force_index uint|nil
---@field surface_index uint|nil
---@field synchronous boolean|nil
---@field eta_blocked boolean|nil Suppress rate estimates while any member is externally blocked.
---@class EiRebuildRecord: EiRebuildDetails
---@field state 'queued'|'running'|'waiting'|'finished'
---@field total number|nil
---@field waiting_reason string|nil
---@field id integer
---@field generation integer
---@field owner string
---@field operation string
---@field scope string|number
---@field start_tick MapTick
---@field updated_tick MapTick
---@field end_tick MapTick|nil
---@field outcome string|nil
---@field eta_ticks number|nil
---@field progress_tick MapTick
---@field key string|nil Internal active-key identity, omitted from public snapshots.
---@field samples {tick:MapTick,completed:number}[]|nil
---@class EiRebuildSnapshot
---@field active EiRebuildRecord[]
---@field history EiRebuildRecord[]
---@field revision integer
---@field public_count integer
---@field episode integer
---@field episode_started_tick MapTick|nil
---@field snapshot_tick MapTick
---@class EiRebuildRegistry
---@field active table<integer,EiRebuildRecord>
---@field keys table<string,integer>
---@field history EiRebuildRecord[]
---@field history_cursor integer
---@field history_count integer
---@field next_id integer
---@field revision integer
---@field transition_revision integer
---@field public_count integer
---@field episode integer
---@field episode_started_tick MapTick|nil
---@field episode_ended_tick MapTick|nil
---@field previous_episode_started_tick MapTick|nil

local REBUILD_FIELDS={"reason","phase","state","completed","total","unit","waiting_reason","force_index","surface_index","synchronous","eta_blocked"}
local function rebuild_state()
    local root=scheduler.ensure_root()
    root.rebuilds=root.rebuilds or {active={},keys={},history={},history_cursor=0,history_count=0,
        next_id=0,revision=0,transition_revision=0,public_count=0,episode=0}
    return root.rebuilds
end

---Pure admission read; never initializes storage (including during on_load).
---@return EiRebuildRegistry|nil
function scheduler.peek_rebuild_state()
    local root=storage.ei and storage.ei.runtime_scheduler
    return root and root.rebuilds
end

local function public_rebuild(record)
    return not record.synchronous and (record.state=="queued" or record.state=="running")
end

local function rebuild_transition(root,before,after,tick)
    if before==after then return end
    root.public_count=root.public_count+(after and 1 or -1)
    if after and root.public_count==1 then
        if root.episode_ended_tick==tick then root.episode_started_tick=root.previous_episode_started_tick
        else root.episode=root.episode+1;root.episode_started_tick=tick end
    elseif root.public_count==0 then
        root.episode_ended_tick=tick;root.previous_episode_started_tick=root.episode_started_tick;root.episode_started_tick=nil
    end
    root.transition_revision=root.transition_revision+1
end

local function rebuild_sample(record,tick,reset)
    if reset or not record.samples then record.samples={{tick=tick,completed=record.completed}};return end
    local samples=record.samples
    if tick-samples[#samples].tick>=60 then
        samples[#samples+1]={tick=tick,completed=record.completed}
    end
    while #samples>1 and tick-samples[1].tick>300 do table.remove(samples,1) end
end

---@param id integer|nil
---@param changes EiRebuildDetails
---@param tick MapTick
---@return boolean
function scheduler.update_rebuild(id,changes,tick)
    local root=scheduler.peek_rebuild_state();local record=root and root.active[id]
    if not record then return false end
    local before=public_rebuild(record)
    local phase,total,state,completed,eta_blocked=record.phase,record.total,record.state,record.completed,record.eta_blocked
    for _,field in ipairs(REBUILD_FIELDS) do
        local value=changes[field]
        if value~=nil then
            if value==false and (field=="total" or field=="waiting_reason") then record[field]=nil
            else record[field]=value end
        end
    end
    record.completed=math.max(0,record.completed or 0)
    if record.total then record.total=math.max(record.completed,record.total) end
    record.updated_tick=tick
    if record.completed~=completed then record.progress_tick=tick end
    rebuild_sample(record,tick,phase~=record.phase or total~=record.total or state~=record.state or eta_blocked~=record.eta_blocked or record.completed<completed)
    rebuild_transition(root,before,public_rebuild(record),tick)
    root.revision=root.revision+1
    return true
end

---@param id integer|nil
---@param outcome string|nil
---@param tick MapTick
---@return boolean
function scheduler.finish_rebuild(id,outcome,tick)
    local root=scheduler.peek_rebuild_state();local record=root and root.active[id]
    if not record then return false end
    rebuild_transition(root,public_rebuild(record),false,tick)
    root.active[id]=nil
    if root.keys[record.key]==id then root.keys[record.key]=nil end
    record.outcome=outcome or "completed";record.end_tick=tick;record.updated_tick=tick
    if record.outcome=="completed" and record.total then record.completed=record.total end
    record.state="finished";record.samples=nil
    root.history_cursor=root.history_cursor%32+1
    root.history[root.history_cursor]=record;root.history_count=math.min(32,root.history_count+1)
    root.revision=root.revision+1;root.transition_revision=root.transition_revision+1
    return true
end

---@param owner string
---@param operation string
---@param scope string|number|nil
---@param details EiRebuildDetails
---@param tick MapTick
---@return integer
function scheduler.begin_rebuild(owner,operation,scope,details,tick)
    local root=rebuild_state();scope=scope or "global"
    local key=owner.."|"..operation.."|"..tostring(scope)
    if root.keys[key] then scheduler.finish_rebuild(root.keys[key],"superseded",tick) end
    root.next_id=root.next_id+1
    local id=root.next_id
    local record={id=id,generation=id,key=key,owner=owner,operation=operation,scope=scope,
        state="waiting",phase="preparing",completed=0,start_tick=tick,updated_tick=tick,progress_tick=tick}
    root.active[id]=record;root.keys[key]=id
    local initial={state="running"}
    for _,field in ipairs(REBUILD_FIELDS) do if details[field]~=nil then initial[field]=details[field] end end
    scheduler.update_rebuild(id,initial,tick)
    root.transition_revision=root.transition_revision+1
    return id
end

---Owner convenience for legacy-save adoption at an existing batch boundary.
---@param owner string
---@param operation string
---@param scope string|number|nil
---@param id integer|nil
---@param details EiRebuildDetails|nil
---@param tick MapTick
---@return integer|nil
function scheduler.report_rebuild(owner,operation,scope,id,details,tick)
    if not details then scheduler.finish_rebuild(id,"completed",tick);return nil end
    if scheduler.update_rebuild(id,details,tick) then return id end
    -- A retained retired ID is a stale publisher, not a new admission. In
    -- particular it must never supersede the replacement under the same key.
    if id~=nil and scheduler.peek_rebuild_state() then return id end
    return scheduler.begin_rebuild(owner,operation,scope,details,tick)
end

local function rebuild_copy(record,tick)
    local copy={}
    for key,value in pairs(record) do if key~="samples" and key~="key" then copy[key]=value end end
    if record.total and record.total>record.completed and public_rebuild(record) and not record.eta_blocked
        and tick-record.progress_tick<300 and record.samples then
        local samples=record.samples;local first,last=samples[1],samples[#samples]
        if first and last and tick-first.tick<=300 and last.tick-first.tick>=60 and last.completed>first.completed then
            copy.eta_ticks=math.ceil((record.total-record.completed)*(last.tick-first.tick)/(last.completed-first.completed))
        end
    end
    return copy
end

---Pure detached scalar snapshots; never invokes owners or audits their queues.
---@param tick MapTick
---@param owner string|nil
---@return EiRebuildSnapshot
function scheduler.peek_rebuilds(tick,owner)
    local root=scheduler.peek_rebuild_state()
    local result={active={},history={},revision=root and root.revision or 0,public_count=root and root.public_count or 0,
        episode=root and root.episode or 0,episode_started_tick=root and root.episode_started_tick,snapshot_tick=tick}
    if not root then return result end
    for _,record in pairs(root.active) do
        if not owner or record.owner==owner then result.active[#result.active+1]=rebuild_copy(record,tick) end
    end
    table.sort(result.active,function(a,b)return a.id<b.id end)
    for offset=0,root.history_count-1 do
        local record=root.history[(root.history_cursor-offset-1)%32+1]
        if not owner or record.owner==owner then result.history[#result.history+1]=rebuild_copy(record,tick) end
    end
    return result
end

return scheduler
