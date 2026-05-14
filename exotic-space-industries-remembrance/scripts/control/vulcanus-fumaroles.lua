--==============================================================================
-- ESIR FILE MAP
-- owns: auric fumarole runtime generation, depletion, and afterglow cleanup
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init, configuration-changed, chunk generation, resource depletion, and gated cleanup/probe ticks
-- forwarded_events: check_global, has_tick_work, is_vulcanus_surface, on_chunk_generated, on_configuration_changed, on_init, on_resource_depleted, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, configuration change, Vulcanus resource prototype changes
--==============================================================================
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local model = {}
local clamp = ei_lib.clamp

local RESOURCE_NAME = "ei-auric-fumarole"
local AFTERGLOW_ANIMATION = "ei-auric-fumarole-afterglow"
local VULCANUS_SURFACE_NAME = "vulcanus"
local FUMAROLE_RUNTIME_VERSION = 1
local ELIGIBILITY_VERSION = 3
local CHUNK_SIZE = 32
local DISTANCE_ZERO_CHUNKS = 3
local DISTANCE_FULL_CHUNKS = 32
local DISTANCE_WEIGHT_POWER = 1.25
local BACKFILL_REBUILD_HASH_SALT = 9501
local BACKFILL_REBUILD_SECTOR_COUNT = 8

local IMMEDIATE_SPAWN_CHANCE = 0.025
local DORMANT_BASE_CHANCE = 0.0025

local DORMANT_PULSE_TICKS = 1800
local DORMANT_GLOBAL_CHECKS_PER_PULSE = 6
local DORMANT_MISS_DELAY = 54000
local DORMANT_BLOCKED_DELAY = 108000
local DORMANT_DELAY_JITTER = 18000
local KEEPALIVE_TARGET_ACTIVE = 2
local KEEPALIVE_BELOW_FLOOR_GRACE_TICKS = 5 * 60 * 60
local KEEPALIVE_ATTEMPTS_PER_PULSE = 2
local KEEPALIVE_SHORTLIST_LIMIT = 8
local BAND_RECOVERY_FILL_THRESHOLD = 0.70
local BAND_RECOVERY_LOW_TOTAL_RATIO = 0.50
local BAND_RECOVERY_BASE_ATTEMPTS_PER_PULSE = 4
local BAND_RECOVERY_LOW_TOTAL_ATTEMPTS_PER_PULSE = 6
local BAND_RECOVERY_LOCAL_MIN_MODIFIER = 0.35
local REENTRY_DELAY_TICKS = 60 * 60 * 60

local ACTIVE_AUDIT_TICKS = 600
local BACKFILL_PROCESS_TICKS = 30
local SURFACE_PROBE_RETRY_TICKS = 600
local BACKFILL_CHUNKS_PER_PASS = 4
local UNTOUCHED_LIFETIME_MIN_TICKS = 35 * 60 * 60
local UNTOUCHED_LIFETIME_MAX_TICKS = 65 * 60 * 60
local UNTOUCHED_LIFETIME_HASH_SALT = 11801
local AFTERGLOW_TICKS = 3600
local BREACH_FIRE_LIFETIME_TICKS = 15 * 60
local BREACH_FIRE_CLEANUP_TICKS = 60
local MIN_FUMAROLE_AMOUNT = 4000
local MAX_FUMAROLE_AMOUNT = 8000
local AURIC_SPACING_RADIUS = 64
local HARD_SULFURIC_EXCLUSION_RADIUS = 16
local SOFT_SULFURIC_NEAR_RADIUS = 32
local SOFT_SULFURIC_FAR_RADIUS = 64
local LOCAL_SATURATION_RADIUS = 6
local LOCAL_SATURATION_CLOSE_RADIUS = 2
local LOCAL_SATURATION_MID_RADIUS = 4
local LOCAL_SATURATION_CLOSE_PENALTY = 0.45
local LOCAL_SATURATION_MID_PENALTY = 0.25
local LOCAL_SATURATION_FAR_PENALTY = 0.10
local LOCAL_SATURATION_MIN_MODIFIER = 0.15
local PLACEMENT_CANDIDATE_COUNT = 24
local RANDOM_PLACEMENT_CANDIDATE_COUNT = PLACEMENT_CANDIDATE_COUNT - 1
local PLACEMENT_INSET = 4

local BREACH_DISCARD_CHANCE = 0.98

local FUMAROLE_BANDS = {
    {name = "3-6", min_distance = DISTANCE_ZERO_CHUNKS, max_distance = 6, density = 0.0025},
    {name = "6-16", min_distance = 6, max_distance = 16, density = 0.0080},
    {name = "16-24", min_distance = 16, max_distance = 24, density = 0.0130},
    {name = "24-32", min_distance = 24, max_distance = 32, density = 0.0180},
    {name = "32+", min_distance = 32, max_distance = nil, density = 0.0100},
}

local FUMAROLE_BAND_ORDER = {}
local FUMAROLE_BAND_INDEX = {}
local FUMAROLE_BAND_DENSITY = {}

for index, band in ipairs(FUMAROLE_BANDS) do
    FUMAROLE_BAND_ORDER[index] = band.name
    FUMAROLE_BAND_INDEX[band.name] = index
    FUMAROLE_BAND_DENSITY[band.name] = band.density
end

local EXEMPT_BREACH_TYPES = {
    ["character"] = true,
    ["car"] = true,
    ["spider-vehicle"] = true,
    ["locomotive"] = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true,
    ["artillery-wagon"] = true,
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
    ["cliff"] = true,
}

local VULCANUS_SCAR_TILES = {
    ["volcanic-cracks-warm"] = "volcanic-cracks-hot",
    ["volcanic-cracks"] = "volcanic-cracks-warm",
    ["volcanic-smooth-stone-warm"] = "volcanic-cracks-warm",
    ["volcanic-smooth-stone"] = "volcanic-smooth-stone-warm",
    ["volcanic-folds"] = "volcanic-folds-flat",
    ["volcanic-folds-flat"] = "volcanic-ash-cracks",
    ["volcanic-jagged-ground"] = "volcanic-soil-light",
    ["volcanic-soil-light"] = "volcanic-soil-dark",
    ["volcanic-pumice-stones"] = "volcanic-ash-flats",
    ["volcanic-ash-flats"] = "volcanic-ash-light",
    ["volcanic-ash-light"] = "volcanic-ash-dark",
    ["volcanic-ash-soil"] = "volcanic-soil-light",
    ["volcanic-ash-cracks"] = "volcanic-pumice-stones",
}

local function new_queue_state()
    return ei_runtime_scheduler.ensure_queue({
        head = 1,
        tail = 0,
        items = {},
    })
end

local function new_band_count_state()
    local counts = {}
    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        counts[band_name] = 0
    end
    return counts
end

local function new_band_queue_state()
    local queues = {}
    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        queues[band_name] = new_queue_state()
    end
    return queues
end

local rebuild_generated_band_counts_for_surface
local rebuild_active_band_counts

local function new_state()
    return {
        runtime_version = FUMAROLE_RUNTIME_VERSION,
        eligibility_version = ELIGIBILITY_VERSION,
        pending_eligibility_refresh = false,
        backfill_bootstrapped = false,
        next_surface_probe_tick = 0,
        processed_chunks = {},
        history_chunks = {},
        cooldown_chunks = {},
        backfill_queue = new_queue_state(),
        active = {},
        active_chunk_buckets = {},
        generated_band_counts = {},
        active_band_counts = {},
        dormant_chunks = {},
        dormant_delayed_buckets = {},
        dormant_surface_queues = {},
        dormant_surface_counts = {},
        dormant_band_queues = {},
        dormant_band_counts = {},
        dormant_active_surfaces = {},
        dormant_active_surface_positions = {},
        dormant_active_surface_cursor = 0,
        band_recovery_stats = {
            attempts = 0,
            successes = 0,
            soft_misses = 0,
            blocked = 0,
        },
        breach_fires = {},
        zero_active_since_tick = nil,
        below_floor_since_tick = nil,
    }
end

local function get_state()
    storage.ei = storage.ei or {}
    storage.ei.vulcanus_fumaroles = storage.ei.vulcanus_fumaroles or new_state()
    return storage.ei.vulcanus_fumaroles
end

local function resolve_tick(current_tick)
    if current_tick ~= nil then
        return current_tick
    end

    return game and game.tick or 0
end

local function raw_queue_has_items(queue)
    if type(queue) ~= "table" or type(queue.items) ~= "table" then
        return false
    end

    local head = queue.head or 1
    local tail = queue.tail or #queue.items
    for index = head, tail do
        if queue.items[index] ~= nil then
            return true
        end
    end

    return false
end

local function raw_delayed_buckets_have_items(buckets)
    if type(buckets) ~= "table" then
        return false
    end

    for _, bucket in pairs(buckets) do
        if type(bucket) == "table" and next(bucket) ~= nil then
            return true
        end
    end

    return false
end

local function raw_surface_queues_have_items(queues)
    if type(queues) ~= "table" then
        return false
    end

    for _, queue in pairs(queues) do
        if raw_queue_has_items(queue) then
            return true
        end
    end

    return false
end

local function raw_band_queues_have_items(surface_queues)
    if type(surface_queues) ~= "table" then
        return false
    end

    for _, queues in pairs(surface_queues) do
        if type(queues) == "table" then
            for _, queue in pairs(queues) do
                if raw_queue_has_items(queue) then
                    return true
                end
            end
        end
    end

    return false
end

local function state_has_runtime_evidence(state)
    if next(state.processed_chunks or {}) ~= nil then
        return true
    end

    if next(state.history_chunks or {}) ~= nil then
        return true
    end

    if next(state.cooldown_chunks or {}) ~= nil then
        return true
    end

    if next(state.active or {}) ~= nil then
        return true
    end

    if next(state.dormant_chunks or {}) ~= nil then
        return true
    end

    if ei_runtime_scheduler.queue_item_count(state.backfill_queue) > 0 then
        return true
    end

    if ei_runtime_scheduler.delayed_item_count(state.dormant_delayed_buckets) > 0 then
        return true
    end

    return false
end

local function ensure_surface_band_counts(root, surface_index)
    local counts = root[surface_index]
    if not counts then
        counts = new_band_count_state()
        root[surface_index] = counts
        return counts
    end

    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        counts[band_name] = counts[band_name] or 0
    end

    return counts
end

local function ensure_surface_band_queues(root, surface_index)
    local queues = root[surface_index]
    if not queues then
        queues = new_band_queue_state()
        root[surface_index] = queues
        return queues
    end

    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        queues[band_name] = ei_runtime_scheduler.ensure_queue(queues[band_name] or new_queue_state())
    end

    return queues
end

function model.check_global()
    local state = get_state()

    if state.runtime_version ~= FUMAROLE_RUNTIME_VERSION then
        state.runtime_version = FUMAROLE_RUNTIME_VERSION
        state.pending_eligibility_refresh = true
    end

    if state.eligibility_version ~= ELIGIBILITY_VERSION then
        state.eligibility_version = ELIGIBILITY_VERSION
        state.pending_eligibility_refresh = true
        state.generated_band_counts = {}
        state.active_band_counts = {}
        state.dormant_chunks = {}
        state.dormant_delayed_buckets = {}
        state.dormant_surface_queues = {}
        state.dormant_surface_counts = {}
        state.dormant_band_queues = {}
        state.dormant_band_counts = {}
        state.dormant_active_surfaces = {}
        state.dormant_active_surface_positions = {}
        state.dormant_active_surface_cursor = 0
    end

    if state.backfill_bootstrapped == nil then
        state.backfill_bootstrapped = false
    end
    if state.runtime_version == nil then
        state.runtime_version = 0
    end
    if state.pending_eligibility_refresh == nil then
        state.pending_eligibility_refresh = false
    end
    state.next_surface_probe_tick = tonumber(state.next_surface_probe_tick) or 0
    state.processed_chunks = state.processed_chunks or {}
    state.history_chunks = state.history_chunks or {}
    state.cooldown_chunks = state.cooldown_chunks or {}
    state.backfill_queue = ei_runtime_scheduler.ensure_queue(state.backfill_queue or new_queue_state())
    state.active = state.active or {}
    state.active_chunk_buckets = state.active_chunk_buckets or {}
    state.generated_band_counts = state.generated_band_counts or {}
    state.active_band_counts = state.active_band_counts or {}
    state.dormant_chunks = state.dormant_chunks or {}
    state.dormant_delayed_buckets = ei_runtime_scheduler.ensure_delayed_buckets(state.dormant_delayed_buckets)
    state.dormant_surface_queues = state.dormant_surface_queues or {}
    state.dormant_surface_counts = state.dormant_surface_counts or {}
    state.dormant_band_queues = state.dormant_band_queues or {}
    state.dormant_band_counts = state.dormant_band_counts or {}
    state.dormant_active_surfaces = state.dormant_active_surfaces or {}
    state.dormant_active_surface_positions = state.dormant_active_surface_positions or {}
    state.dormant_active_surface_cursor = state.dormant_active_surface_cursor or 0
    state.band_recovery_stats = state.band_recovery_stats or {
        attempts = 0,
        successes = 0,
        soft_misses = 0,
        blocked = 0,
    }
    state.breach_fires = state.breach_fires or {}
    -- Legacy helper-entity ambience state is retired; the resource prototype now owns looping sound.
    state.sound_proxies = nil

    for surface_index, queue in pairs(state.dormant_surface_queues) do
        state.dormant_surface_queues[surface_index] = ei_runtime_scheduler.ensure_queue(queue)
    end

    for surface_index, _ in pairs(state.generated_band_counts) do
        ensure_surface_band_counts(state.generated_band_counts, surface_index)
    end

    for surface_index, _ in pairs(state.active_band_counts) do
        ensure_surface_band_counts(state.active_band_counts, surface_index)
    end

    for surface_index, _ in pairs(state.dormant_band_counts) do
        ensure_surface_band_counts(state.dormant_band_counts, surface_index)
    end

    for surface_index, _ in pairs(state.dormant_band_queues) do
        ensure_surface_band_queues(state.dormant_band_queues, surface_index)
    end

    rebuild_active_band_counts(state)

    if not state.backfill_bootstrapped and state_has_runtime_evidence(state) then
        state.backfill_bootstrapped = true
    end
end

function model.is_vulcanus_surface(surface)
    return surface and surface.valid and surface.name == VULCANUS_SURFACE_NAME
end

local function get_surface_seed(surface)
    local map_settings = surface and surface.valid and surface.map_gen_settings or nil
    return (map_settings and map_settings.seed) or 0
end

local function get_entity_force_name(entity)
    if not ei_lib.entity_check(entity) then
        return nil
    end

    local ok, force = pcall(function()
        return entity.force
    end)
    if ok and force and force.valid then
        return force.name
    end

    return nil
end

local function get_fumarole_resource_amount(entity)
    if not ei_lib.entity_check(entity) or entity.name ~= RESOURCE_NAME or entity.type ~= "resource" then
        return nil
    end

    local ok, amount = pcall(function()
        return entity.amount
    end)
    if ok and type(amount) == "number" then
        return amount
    end

    return nil
end

local function chunk_key(surface_index, chunk_x, chunk_y)
    return table.concat({surface_index, chunk_x, chunk_y}, ":")
end

local function hash01(seed, chunk_x, chunk_y, salt)
    local value = math.sin((seed + salt) * 12.9898 + chunk_x * 78.233 + chunk_y * 37.719 + salt * 0.12345) * 43758.5453
    return value - math.floor(value)
end

local function queue_push(queue, value)
    ei_runtime_scheduler.queue_push(queue, value)
end

local function queue_pop(queue)
    return ei_runtime_scheduler.queue_pop(queue)
end

local function queue_length(queue)
    return ei_runtime_scheduler.queue_item_count(queue)
end

local function clear_queue(queue)
    ei_runtime_scheduler.clear_queue(queue)
end

local function filter_backfill_queue(state, retain_predicate)
    local queue = ei_runtime_scheduler.ensure_queue(state.backfill_queue)
    local retained_entries = {}

    for index = queue.head, queue.tail do
        local entry = queue.items[index]
        if entry ~= nil and (not retain_predicate or retain_predicate(entry)) then
            retained_entries[#retained_entries + 1] = entry
        end
    end

    clear_queue(queue)
    for _, entry in ipairs(retained_entries) do
        queue_push(queue, entry)
    end
end

local function get_backfill_rebuild_sort_key(surface, chunk_x, chunk_y)
    return hash01(get_surface_seed(surface), chunk_x, chunk_y, BACKFILL_REBUILD_HASH_SALT)
end

local function get_backfill_rebuild_sector(chunk_x, chunk_y)
    local center_x = chunk_x * CHUNK_SIZE + (CHUNK_SIZE / 2)
    local center_y = chunk_y * CHUNK_SIZE + (CHUNK_SIZE / 2)
    local angle = math.atan(center_y, center_x)
    local normalized = (angle + math.pi) / (2 * math.pi)
    return (math.floor(normalized * BACKFILL_REBUILD_SECTOR_COUNT) % BACKFILL_REBUILD_SECTOR_COUNT) + 1
end

local function queue_backfill_entries(state, surface, force_refresh)
    local queued = 0
    local rebuild_buckets = force_refresh and {} or nil
    local rebuild_positions = force_refresh and {} or nil

    if force_refresh or state.generated_band_counts[surface.index] == nil then
        rebuild_generated_band_counts_for_surface(state, surface)
    end

    for chunk in surface.get_chunks() do
        local key = chunk_key(surface.index, chunk.x, chunk.y)
        if force_refresh or not state.processed_chunks[key] then
            if rebuild_buckets then
                local sector = get_backfill_rebuild_sector(chunk.x, chunk.y)
                local bucket = rebuild_buckets[sector]
                if not bucket then
                    bucket = {}
                    rebuild_buckets[sector] = bucket
                    rebuild_positions[sector] = 1
                end

                bucket[#bucket + 1] = {
                    chunk_x = chunk.x,
                    chunk_y = chunk.y,
                    sort_key = get_backfill_rebuild_sort_key(surface, chunk.x, chunk.y),
                }
            else
                queue_push(state.backfill_queue, {
                    surface_index = surface.index,
                    chunk_x = chunk.x,
                    chunk_y = chunk.y,
                })
                queued = queued + 1
            end
        end
    end

    if not rebuild_buckets then
        return queued
    end

    for sector = 1, BACKFILL_REBUILD_SECTOR_COUNT do
        local bucket = rebuild_buckets[sector]
        if bucket then
            table.sort(bucket, function(a, b)
                if a.sort_key ~= b.sort_key then
                    return a.sort_key < b.sort_key
                end
                if a.chunk_x ~= b.chunk_x then
                    return a.chunk_x < b.chunk_x
                end
                return a.chunk_y < b.chunk_y
            end)
        end
    end

    local start_sector = 1 + math.floor(hash01(get_surface_seed(surface), 0, 0, BACKFILL_REBUILD_HASH_SALT + 1) * BACKFILL_REBUILD_SECTOR_COUNT)
    local has_pending = true

    while has_pending do
        has_pending = false

        for offset = 0, BACKFILL_REBUILD_SECTOR_COUNT - 1 do
            local sector = ((start_sector - 1 + offset) % BACKFILL_REBUILD_SECTOR_COUNT) + 1
            local bucket = rebuild_buckets[sector]
            local position = rebuild_positions[sector]
            local entry = bucket and position and bucket[position] or nil

            if entry then
                queue_push(state.backfill_queue, {
                    surface_index = surface.index,
                    chunk_x = entry.chunk_x,
                    chunk_y = entry.chunk_y,
                })
                rebuild_positions[sector] = position + 1
                queued = queued + 1
                has_pending = true
            end
        end
    end

    return queued
end

local function quantize_due_tick(raw_due_tick)
    return math.ceil(raw_due_tick / DORMANT_PULSE_TICKS) * DORMANT_PULSE_TICKS
end

local function get_chunk_center(chunk_x, chunk_y)
    return {
        x = chunk_x * CHUNK_SIZE + (CHUNK_SIZE / 2),
        y = chunk_y * CHUNK_SIZE + (CHUNK_SIZE / 2),
    }
end

local function get_chunk_distance_chunks(chunk_x, chunk_y)
    local center = get_chunk_center(chunk_x, chunk_y)
    return math.sqrt(center.x * center.x + center.y * center.y) / CHUNK_SIZE
end

local function get_distance_band_name(distance_chunks)
    if distance_chunks <= DISTANCE_ZERO_CHUNKS then
        return nil
    end

    for _, band in ipairs(FUMAROLE_BANDS) do
        if distance_chunks > band.min_distance and (band.max_distance == nil or distance_chunks <= band.max_distance) then
            return band.name
        end
    end

    return nil
end

local function get_chunk_band_name(chunk_x, chunk_y)
    return get_distance_band_name(get_chunk_distance_chunks(chunk_x, chunk_y))
end

local function get_generated_band_counts(state, surface_index)
    return ensure_surface_band_counts(state.generated_band_counts, surface_index)
end

local function get_active_band_counts(state, surface_index)
    return ensure_surface_band_counts(state.active_band_counts, surface_index)
end

local function get_dormant_band_counts(state, surface_index)
    return ensure_surface_band_counts(state.dormant_band_counts, surface_index)
end

local function get_dormant_band_queues(state, surface_index)
    return ensure_surface_band_queues(state.dormant_band_queues, surface_index)
end

local function increment_generated_band_count(state, surface_index, band_name)
    if not band_name then
        return
    end

    local counts = get_generated_band_counts(state, surface_index)
    counts[band_name] = (counts[band_name] or 0) + 1
end

local function increment_active_band_count(state, surface_index, band_name)
    if not band_name then
        return
    end

    local counts = get_active_band_counts(state, surface_index)
    counts[band_name] = (counts[band_name] or 0) + 1
end

local function decrement_active_band_count(state, surface_index, band_name)
    if not band_name then
        return
    end

    local counts = get_active_band_counts(state, surface_index)
    counts[band_name] = math.max(0, (counts[band_name] or 0) - 1)
end

local function get_band_target_count(state, surface_index, band_name)
    local density = FUMAROLE_BAND_DENSITY[band_name]
    if not density then
        return 0
    end

    local counts = get_generated_band_counts(state, surface_index)
    local eligible_chunks = counts[band_name] or 0
    if eligible_chunks <= 0 then
        return 0
    end

    return math.ceil(eligible_chunks * density)
end

local function get_band_active_count(state, surface_index, band_name)
    return (get_active_band_counts(state, surface_index)[band_name] or 0)
end

local function get_band_fill_ratio(state, surface_index, band_name)
    local target = get_band_target_count(state, surface_index, band_name)
    if target <= 0 then
        return math.huge
    end

    return get_band_active_count(state, surface_index, band_name) / target
end

local function get_surface_total_band_target(state, surface_index)
    local total = 0
    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        total = total + get_band_target_count(state, surface_index, band_name)
    end
    return total
end

local function get_surface_total_band_active(state, surface_index)
    local total = 0
    local counts = get_active_band_counts(state, surface_index)
    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        total = total + (counts[band_name] or 0)
    end
    return total
end

local function get_band_fill_modifier(state, surface_index, band_name)
    local fill_ratio = get_band_fill_ratio(state, surface_index, band_name)
    if fill_ratio < 0.35 then
        return 3.0
    end
    if fill_ratio < 0.70 then
        return 2.0
    end
    if fill_ratio < 1.00 then
        return 1.0
    end
    if fill_ratio < 1.25 then
        return 0.40
    end
    return 0.15
end

rebuild_generated_band_counts_for_surface = function(state, surface)
    if not model.is_vulcanus_surface(surface) then
        return
    end

    local counts = new_band_count_state()
    for chunk in surface.get_chunks() do
        local band_name = get_chunk_band_name(chunk.x, chunk.y)
        if band_name then
            counts[band_name] = counts[band_name] + 1
        end
    end
    state.generated_band_counts[surface.index] = counts
end

rebuild_active_band_counts = function(state)
    state.active_band_counts = {}

    for _, record in pairs(state.active) do
        local surface = game and game.surfaces and game.surfaces[record.surface_index] or nil
        if model.is_vulcanus_surface(surface) then
            local band_name = record.band_name or get_chunk_band_name(record.chunk_x, record.chunk_y)
            record.band_name = band_name
            increment_active_band_count(state, record.surface_index, band_name)
        end
    end
end

local function get_ready_queue(state, surface_index)
    local queue = state.dormant_surface_queues[surface_index]
    if not queue then
        queue = new_queue_state()
        state.dormant_surface_queues[surface_index] = queue
    end
    return queue
end

local function get_ready_band_queue(state, surface_index, band_name)
    if not band_name then
        return nil
    end

    local queues = get_dormant_band_queues(state, surface_index)
    return queues[band_name]
end

local function add_active_surface(state, surface_index)
    if state.dormant_active_surface_positions[surface_index] then
        return
    end

    local surfaces = state.dormant_active_surfaces
    surfaces[#surfaces + 1] = surface_index
    state.dormant_active_surface_positions[surface_index] = #surfaces
end

local function remove_active_surface(state, surface_index)
    local position = state.dormant_active_surface_positions[surface_index]
    if not position then
        return
    end

    local surfaces = state.dormant_active_surfaces
    local last_surface = surfaces[#surfaces]
    surfaces[position] = last_surface
    surfaces[#surfaces] = nil
    state.dormant_active_surface_positions[surface_index] = nil

    if last_surface ~= nil and last_surface ~= surface_index then
        state.dormant_active_surface_positions[last_surface] = position
    end

    if state.dormant_active_surface_cursor > #surfaces then
        state.dormant_active_surface_cursor = 0
    end
end

local function enqueue_ready_chunk(state, surface_index, key, band_name)
    local queue = get_ready_queue(state, surface_index)
    queue_push(queue, key)
    state.dormant_surface_counts[surface_index] = (state.dormant_surface_counts[surface_index] or 0) + 1

    if band_name then
        local band_queue = get_ready_band_queue(state, surface_index, band_name)
        if band_queue then
            queue_push(band_queue, key)
            local band_counts = get_dormant_band_counts(state, surface_index)
            band_counts[band_name] = (band_counts[band_name] or 0) + 1
        end
    end

    add_active_surface(state, surface_index)
end

local function remove_queue_key(queue, key)
    if not queue then
        return false
    end

    local items = queue.items
    for index = queue.head or 1, queue.tail or 0 do
        if items[index] == key then
            items[index] = nil
            return true
        end
    end

    return false
end

local function detach_ready_surface_key(state, surface_index, key)
    local queue = state.dormant_surface_queues[surface_index]
    if not queue or not remove_queue_key(queue, key) then
        return false
    end

    local remaining = math.max(0, (state.dormant_surface_counts[surface_index] or 0) - 1)
    state.dormant_surface_counts[surface_index] = remaining
    if remaining == 0 then
        clear_queue(queue)
        remove_active_surface(state, surface_index)
    end

    return true
end

local function detach_ready_band_key(state, surface_index, band_name, key)
    local queue = get_ready_band_queue(state, surface_index, band_name)
    if not queue or not remove_queue_key(queue, key) then
        return false
    end

    local counts = get_dormant_band_counts(state, surface_index)
    counts[band_name] = math.max(0, (counts[band_name] or 0) - 1)
    if counts[band_name] == 0 then
        clear_queue(queue)
    end

    return true
end

local function dequeue_ready_chunk(state, surface_index)
    local queue = get_ready_queue(state, surface_index)
    local key = queue_pop(queue)
    if key == nil then
        state.dormant_surface_counts[surface_index] = 0
        remove_active_surface(state, surface_index)
        return nil
    end

    local remaining = math.max(0, (state.dormant_surface_counts[surface_index] or 0) - 1)
    state.dormant_surface_counts[surface_index] = remaining

    local dormant = state.dormant_chunks[key]
    if dormant and dormant.band_name then
        detach_ready_band_key(state, surface_index, dormant.band_name, key)
    end

    if remaining == 0 or queue_length(queue) == 0 then
        state.dormant_surface_counts[surface_index] = 0
        clear_queue(queue)
        remove_active_surface(state, surface_index)
    end

    return key
end

local function dequeue_ready_band_chunk(state, surface_index, band_name)
    local queue = get_ready_band_queue(state, surface_index, band_name)
    if not queue then
        return nil
    end

    local key = queue_pop(queue)
    if key == nil then
        get_dormant_band_counts(state, surface_index)[band_name] = 0
        return nil
    end

    local counts = get_dormant_band_counts(state, surface_index)
    counts[band_name] = math.max(0, (counts[band_name] or 0) - 1)
    detach_ready_surface_key(state, surface_index, key)
    if counts[band_name] == 0 or queue_length(queue) == 0 then
        counts[band_name] = 0
        clear_queue(queue)
    end

    return key
end

local function register_processed_chunk(state, surface, chunk_x, chunk_y)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    state.processed_chunks[key] = true
    return key
end

local function mark_history_chunk(state, surface, chunk_x, chunk_y)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    state.history_chunks[key] = true
    return key
end

local function remove_active_bucket_entry(state, surface_index, chunk_x, chunk_y)
    local surface_bucket = state.active_chunk_buckets[surface_index]
    if not surface_bucket then
        return
    end

    local x_bucket = surface_bucket[chunk_x]
    if not x_bucket then
        return
    end

    x_bucket[chunk_y] = nil
    if next(x_bucket) == nil then
        surface_bucket[chunk_x] = nil
    end
    if next(surface_bucket) == nil then
        state.active_chunk_buckets[surface_index] = nil
    end
end

local function add_active_bucket_entry(state, surface_index, chunk_x, chunk_y, key)
    local surface_bucket = state.active_chunk_buckets[surface_index]
    if not surface_bucket then
        surface_bucket = {}
        state.active_chunk_buckets[surface_index] = surface_bucket
    end

    local x_bucket = surface_bucket[chunk_x]
    if not x_bucket then
        x_bucket = {}
        surface_bucket[chunk_x] = x_bucket
    end

    x_bucket[chunk_y] = key
end

local function get_local_saturation_penalty(chunk_distance)
    if chunk_distance <= LOCAL_SATURATION_CLOSE_RADIUS then
        return LOCAL_SATURATION_CLOSE_PENALTY
    end
    if chunk_distance <= LOCAL_SATURATION_MID_RADIUS then
        return LOCAL_SATURATION_MID_PENALTY
    end
    if chunk_distance <= LOCAL_SATURATION_RADIUS then
        return LOCAL_SATURATION_FAR_PENALTY
    end
    return 0
end

-- Nearby active fumaroles should thin dormant re-eruptions without ever hard-locking them.
local function get_local_saturation_modifier(state, surface_index, chunk_x, chunk_y)
    local surface_bucket = state.active_chunk_buckets[surface_index]
    if not surface_bucket then
        return 1
    end

    local total_penalty = 0
    for x = chunk_x - LOCAL_SATURATION_RADIUS, chunk_x + LOCAL_SATURATION_RADIUS do
        local x_bucket = surface_bucket[x]
        if x_bucket then
            for y = chunk_y - LOCAL_SATURATION_RADIUS, chunk_y + LOCAL_SATURATION_RADIUS do
                if x_bucket[y] ~= nil then
                    local delta_x = x - chunk_x
                    local delta_y = y - chunk_y
                    local chunk_distance = math.sqrt((delta_x * delta_x) + (delta_y * delta_y))
                    total_penalty = total_penalty + get_local_saturation_penalty(chunk_distance)
                end
            end
        end
    end

    return clamp(1 - total_penalty, LOCAL_SATURATION_MIN_MODIFIER, 1)
end

local function refresh_active_floor_state(state, current_tick)
    current_tick = resolve_tick(current_tick)
    local active_count = ei_runtime_scheduler.table_count(state.active)

    if active_count == 0 then
        if state.zero_active_since_tick == nil then
            state.zero_active_since_tick = current_tick
        end
    else
        state.zero_active_since_tick = nil
    end

    if active_count < KEEPALIVE_TARGET_ACTIVE then
        if state.below_floor_since_tick == nil then
            state.below_floor_since_tick = current_tick
        end
    else
        state.below_floor_since_tick = nil
    end

    return active_count
end

local function get_chunk_cooldown_until_tick(state, key, current_tick)
    current_tick = resolve_tick(current_tick)
    local blocked_until_tick = state.cooldown_chunks[key]
    if blocked_until_tick and blocked_until_tick <= current_tick then
        state.cooldown_chunks[key] = nil
        return nil
    end

    return blocked_until_tick
end

local function set_chunk_cooldown(state, surface, chunk_x, chunk_y, blocked_until_tick)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    state.cooldown_chunks[key] = blocked_until_tick
end

local function get_fumarole_distance_weight(surface, chunk_x, chunk_y)
    if not model.is_vulcanus_surface(surface) then
        return 0
    end

    local distance_chunks = get_chunk_distance_chunks(chunk_x, chunk_y)
    if distance_chunks <= DISTANCE_ZERO_CHUNKS then
        return 0
    end

    if distance_chunks >= DISTANCE_FULL_CHUNKS then
        return 1
    end

    local normalized = clamp(
        (distance_chunks - DISTANCE_ZERO_CHUNKS) / (DISTANCE_FULL_CHUNKS - DISTANCE_ZERO_CHUNKS),
        0,
        1
    )
    return normalized ^ DISTANCE_WEIGHT_POWER
end

local function is_valid_vulcanus_tile(tile)
    if not tile or not tile.valid then
        return false
    end

    local name = tile.name or ""
    if not string.find(name, "volcanic", 1, true) then
        return false
    end

    if string.find(name, "lava", 1, true) then
        return false
    end

    if tile.hidden_tile or tile.collides_with("water_tile") then
        return false
    end

    return true
end

local function get_probe_positions(surface, chunk_x, chunk_y)
    local seed = get_surface_seed(surface)
    local center = get_chunk_center(chunk_x, chunk_y)
    local center_key = table.concat({center.x, center.y}, ":")
    local center_slot = math.floor(hash01(seed, chunk_x, chunk_y, 7101) * PLACEMENT_CANDIDATE_COUNT) + 1
    local min_x = chunk_x * CHUNK_SIZE + PLACEMENT_INSET
    local min_y = chunk_y * CHUNK_SIZE + PLACEMENT_INSET
    local span = CHUNK_SIZE - (PLACEMENT_INSET * 2)
    local random_positions = {}
    local seen = {[center_key] = true}
    local salt = 0

    while #random_positions < RANDOM_PLACEMENT_CANDIDATE_COUNT and salt < (RANDOM_PLACEMENT_CANDIDATE_COUNT * 8) do
        salt = salt + 1
        local x = min_x + math.floor(hash01(seed, chunk_x, chunk_y, 7200 + (salt * 2)) * span)
        local y = min_y + math.floor(hash01(seed, chunk_x, chunk_y, 7201 + (salt * 2)) * span)
        local key = table.concat({x, y}, ":")
        if not seen[key] then
            seen[key] = true
            random_positions[#random_positions + 1] = {x = x, y = y}
        end
    end

    local positions = {}
    local random_index = 1
    for slot = 1, PLACEMENT_CANDIDATE_COUNT do
        if slot == center_slot then
            positions[#positions + 1] = {x = center.x, y = center.y}
        else
            positions[#positions + 1] = random_positions[random_index] or {x = center.x, y = center.y}
            random_index = random_index + 1
        end
    end

    return positions
end

local function get_nearest_sulfuric_distance(surface, position)
    local nearby_sulfuric = surface.find_entities_filtered{
        position = position,
        radius = SOFT_SULFURIC_FAR_RADIUS,
        name = "sulfuric-acid-geyser",
    }

    local nearest_distance = nil
    for _, entity in pairs(nearby_sulfuric) do
        if entity and entity.valid then
            local dx = entity.position.x - position.x
            local dy = entity.position.y - position.y
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if nearest_distance == nil or distance < nearest_distance then
                nearest_distance = distance
            end
        end
    end

    return nearest_distance
end

local function get_sulfuric_probability_modifier(sulfuric_distance)
    if sulfuric_distance and sulfuric_distance <= SOFT_SULFURIC_NEAR_RADIUS then
        return 0.35
    end

    if sulfuric_distance and sulfuric_distance <= SOFT_SULFURIC_FAR_RADIUS then
        return 0.70
    end

    return 1
end

local function has_auric_spacing_conflict(surface, position)
    local nearby_auric = surface.find_entities_filtered{
        position = position,
        radius = AURIC_SPACING_RADIUS,
        name = RESOURCE_NAME,
    }

    return #nearby_auric > 0
end

local collect_center_obstacles

local function inspect_spawn_position(surface, position)
    local tile = surface.get_tile(position)
    if not is_valid_vulcanus_tile(tile) then
        return nil, "invalid-tile"
    end

    if has_auric_spacing_conflict(surface, position) then
        return nil, "auric-spacing"
    end

    local sulfuric_distance = get_nearest_sulfuric_distance(surface, position)
    if sulfuric_distance and sulfuric_distance < HARD_SULFURIC_EXCLUSION_RADIUS then
        return nil, "sulfuric-spacing"
    end

    local blockers, non_breachable = collect_center_obstacles(surface, position)
    if non_breachable then
        return nil, "blocked"
    end

    return {
        position = {x = position.x, y = position.y},
        blockers = blockers,
        sulfuric_distance = sulfuric_distance,
    }, (#blockers > 0 and "occupied" or nil)
end

local function context_allows_breach(context)
    return context == "backfill" or context == "dormant" or context == "recovery" or context == "keepalive"
end

local function select_spawn_candidate(surface, chunk_x, chunk_y, context)
    local allow_breach = context_allows_breach(context)
    local first_breach_candidate = nil
    local first_failure_reason = nil

    for _, position in ipairs(get_probe_positions(surface, chunk_x, chunk_y)) do
        local candidate, reason = inspect_spawn_position(surface, position)
        if candidate then
            if #candidate.blockers == 0 then
                return candidate, nil
            end

            if allow_breach and not first_breach_candidate then
                first_breach_candidate = candidate
            end

            first_failure_reason = first_failure_reason or reason or "occupied"
        else
            first_failure_reason = first_failure_reason or reason
        end
    end

    if first_breach_candidate then
        return first_breach_candidate, nil
    end

    return nil, first_failure_reason or "placement"
end

collect_center_obstacles = function(surface, position)
    local area = {
        {position.x - 2.4, position.y - 2.4},
        {position.x + 2.4, position.y + 2.4},
    }

    local entities = surface.find_entities_filtered{area = area}
    local blockers = {}
    local non_breachable = false

    for _, entity in pairs(entities) do
        if entity.valid and entity.name ~= RESOURCE_NAME then
            local force_name = get_entity_force_name(entity)
            if entity.type == "resource" then
                non_breachable = true
            elseif EXEMPT_BREACH_TYPES[entity.type] then
                non_breachable = true
            elseif force_name and force_name ~= "neutral" and force_name ~= "enemy" then
                blockers[#blockers + 1] = entity
            elseif entity.type ~= "corpse" and entity.type ~= "simple-entity" and entity.type ~= "simple-entity-with-owner" and entity.type ~= "simple-entity-with-force" then
                non_breachable = true
            end
        end
    end

    return blockers, non_breachable
end

local function apply_scar_tiles(surface, position)
    local tiles = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local target = {x = position.x + dx, y = position.y + dy}
            local tile = surface.get_tile(target)
            local replacement = tile and VULCANUS_SCAR_TILES[tile.name] or nil
            if replacement then
                tiles[#tiles + 1] = {name = replacement, position = target}
            end
        end
    end

    if #tiles > 0 then
        surface.set_tiles(tiles, true, false)
        for _, tile in pairs(tiles) do
            surface.destroy_decoratives{position = tile.position, exclude_soft = false}
        end
    end
end

local function play_surface_sound(surface, path, position, volume_modifier)
    if not surface or not surface.valid then
        return
    end

    pcall(function()
        surface.play_sound{
            path = path,
            position = position,
            volume_modifier = volume_modifier or 1,
        }
    end)
end

local function spawn_afterglow(surface, position)
    if not surface or not surface.valid then
        return
    end

    pcall(function()
        rendering.draw_animation{
            animation = AFTERGLOW_ANIMATION,
            target = position,
            surface = surface,
            render_layer = "object",
            animation_speed = 0.7,
            time_to_live = AFTERGLOW_TICKS,
        }
    end)
end

local function cleanup_breach_fires(state, current_tick)
    current_tick = resolve_tick(current_tick)
    state.breach_fires = state.breach_fires or {}
    local active_fires = state.breach_fires
    local write_index = 1

    for read_index = 1, #active_fires do
        local record = active_fires[read_index]
        local fire = record and record.entity or nil
        if ei_lib.entity_check(fire) and current_tick < (record.expires_tick or 0) then
            active_fires[write_index] = record
            write_index = write_index + 1
        elseif ei_lib.entity_check(fire) then
            pcall(function()
                fire.destroy()
            end)
        end
    end

    for index = write_index, #active_fires do
        active_fires[index] = nil
    end

    state.breach_fires = active_fires
end

local function create_breach_fires(state, surface, position, current_tick)
    local seed = get_surface_seed(surface)
    local fire_count = 1 + math.floor(hash01(seed, math.floor(position.x), math.floor(position.y), 7711) * 3)
    current_tick = resolve_tick(current_tick)
    state.breach_fires = state.breach_fires or {}

    for i = 1, fire_count do
        local angle = hash01(seed, math.floor(position.x), math.floor(position.y), 7711 + i) * math.pi * 2
        local radius = 1 + hash01(seed, math.floor(position.x), math.floor(position.y), 8800 + i) * 2
        local fire_position = {
            x = position.x + math.cos(angle) * radius,
            y = position.y + math.sin(angle) * radius,
        }
        local fire = surface.create_entity{
            name = "fire-flame",
            position = fire_position,
            force = "neutral",
        }
        if fire and fire.valid then
            -- Normal fire entities do not expose LuaEntity::time_to_live, so keep the
            -- breach flames short-lived through our own tiny cleanup list.
            table.insert(state.breach_fires, {
                entity = fire,
                expires_tick = current_tick + BREACH_FIRE_LIFETIME_TICKS,
            })
        end
    end
end

local function create_fumarole_entity(surface, position, amount)
    local entity = surface.create_entity{
        name = RESOURCE_NAME,
        position = position,
        amount = amount,
    }

    if entity and entity.valid then
        pcall(function()
            entity.amount = amount
        end)
    end

    return entity
end

local function find_existing_fumarole_entity(surface, chunk_x, chunk_y)
    local area = {
        {chunk_x * CHUNK_SIZE, chunk_y * CHUNK_SIZE},
        {chunk_x * CHUNK_SIZE + CHUNK_SIZE, chunk_y * CHUNK_SIZE + CHUNK_SIZE},
    }

    local matches = surface.find_entities_filtered{
        area = area,
        name = RESOURCE_NAME,
    }

    for _, entity in pairs(matches) do
        if entity and entity.valid then
            return entity
        end
    end

    return nil
end

local clear_dormant_chunk
local get_untouched_lifetime_ticks
local register_active_fumarole

local function destroy_breach_blocker(blocker)
    if not ei_lib.entity_check(blocker) then
        return
    end

    local ok_destructible, destructible = pcall(function()
        return blocker.destructible
    end)
    if ok_destructible and destructible then
        local died_ok = pcall(function()
            return blocker.die("neutral")
        end)
        if died_ok and not blocker.valid then
            return
        end
    end

    if blocker.valid then
        pcall(function()
            blocker.destroy()
        end)
    end
end

local function adopt_existing_fumarole(state, surface, chunk_x, chunk_y, current_tick)
    local entity = find_existing_fumarole_entity(surface, chunk_x, chunk_y)
    if not entity then
        return false
    end

    local amount = get_fumarole_resource_amount(entity)
    if not amount then
        return false
    end

    current_tick = resolve_tick(current_tick)

    local key = chunk_key(surface.index, chunk_x, chunk_y)
    register_processed_chunk(state, surface, chunk_x, chunk_y)
    mark_history_chunk(state, surface, chunk_x, chunk_y)
    clear_dormant_chunk(state, key)

    local record = state.active[key]
    if record then
        record.surface_index = surface.index
        record.chunk_x = chunk_x
        record.chunk_y = chunk_y
        record.band_name = record.band_name or get_chunk_band_name(chunk_x, chunk_y)
        record.position = {x = entity.position.x, y = entity.position.y}
        record.entity = entity
        record.initial_amount = record.initial_amount or amount
        record.untouched_deadline_tick = record.untouched_deadline_tick
            or (current_tick + get_untouched_lifetime_ticks(surface, chunk_x, chunk_y, current_tick))
        add_active_bucket_entry(state, surface.index, chunk_x, chunk_y, key)
        return true
    end

    register_active_fumarole(state, surface, chunk_x, chunk_y, entity, amount, current_tick)
    return true
end

local function get_spawn_amount(surface, chunk_x, chunk_y)
    local seed = get_surface_seed(surface)
    local span = MAX_FUMAROLE_AMOUNT - MIN_FUMAROLE_AMOUNT + 1
    return MIN_FUMAROLE_AMOUNT + math.floor(hash01(seed, chunk_x, chunk_y, 901) * span)
end

local function immediate_spawn_roll(surface, chunk_x, chunk_y, distance_weight)
    if distance_weight <= 0 then
        return false
    end

    local seed = get_surface_seed(surface)
    return hash01(seed, chunk_x, chunk_y, 101) < (IMMEDIATE_SPAWN_CHANCE * distance_weight)
end

local function breach_roll(surface, chunk_x, chunk_y, salt)
    local seed = get_surface_seed(surface)
    return hash01(seed, chunk_x, chunk_y, salt) >= BREACH_DISCARD_CHANCE
end

local function jitter_ticks(surface, chunk_x, chunk_y, salt)
    local seed = get_surface_seed(surface)
    return math.floor(hash01(seed, chunk_x, chunk_y, salt) * (DORMANT_DELAY_JITTER + 1))
end

get_untouched_lifetime_ticks = function(surface, chunk_x, chunk_y, current_tick)
    local cycle_salt = math.floor(resolve_tick(current_tick) / DORMANT_PULSE_TICKS)
    local seed = get_surface_seed(surface)
    local span = UNTOUCHED_LIFETIME_MAX_TICKS - UNTOUCHED_LIFETIME_MIN_TICKS + 1
    return UNTOUCHED_LIFETIME_MIN_TICKS
        + math.floor(hash01(seed, chunk_x, chunk_y, UNTOUCHED_LIFETIME_HASH_SALT + cycle_salt) * span)
end

local function remove_dormant_from_ready_queues(state, key, surface_index, band_name)
    detach_ready_surface_key(state, surface_index, key)
    if band_name then
        detach_ready_band_key(state, surface_index, band_name, key)
    end
end

clear_dormant_chunk = function(state, key)
    local dormant = state.dormant_chunks[key]
    if not dormant then
        return
    end

    remove_dormant_from_ready_queues(state, key, dormant.surface_index, dormant.band_name)
    state.dormant_chunks[key] = nil
end

local function schedule_dormant_chunk(state, surface, chunk_x, chunk_y, delay_ticks, salt, current_tick)
    if not model.is_vulcanus_surface(surface) then
        return
    end

    current_tick = resolve_tick(current_tick)
    local key = chunk_key(surface.index, chunk_x, chunk_y)

    local due_tick = quantize_due_tick(current_tick + delay_ticks + jitter_ticks(surface, chunk_x, chunk_y, salt))
    local blocked_until_tick = get_chunk_cooldown_until_tick(state, key, current_tick)
    if blocked_until_tick and due_tick < blocked_until_tick then
        due_tick = quantize_due_tick(blocked_until_tick)
    end

    local band_name = get_chunk_band_name(chunk_x, chunk_y)
    local record = state.dormant_chunks[key] or {
        surface_index = surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
    }
    remove_dormant_from_ready_queues(state, key, record.surface_index, record.band_name or band_name)
    record.band_name = band_name
    record.due_tick = due_tick
    state.dormant_chunks[key] = record

    ei_runtime_scheduler.delayed_schedule(state.dormant_delayed_buckets, due_tick, key)
end

local function register_dormant_candidate(state, surface, chunk_x, chunk_y, current_tick)
    schedule_dormant_chunk(state, surface, chunk_x, chunk_y, DORMANT_MISS_DELAY, 404, current_tick)
end

local function finalize_closure(state, record, reason, current_tick)
    if not record then
        return
    end

    current_tick = resolve_tick(current_tick)
    local surface = game.surfaces[record.surface_index]
    local position = record.position or get_chunk_center(record.chunk_x, record.chunk_y)
    local band_name = record.band_name or get_chunk_band_name(record.chunk_x, record.chunk_y)

    remove_active_bucket_entry(state, record.surface_index, record.chunk_x, record.chunk_y)
    decrement_active_band_count(state, record.surface_index, band_name)

    if ei_lib.entity_check(record.entity) then
        pcall(function()
            record.entity.destroy()
        end)
    end

    if surface and surface.valid and model.is_vulcanus_surface(surface) then
        apply_scar_tiles(surface, position)
        spawn_afterglow(surface, position)

        if reason == "breach" then
            play_surface_sound(surface, "utility/cannot_build", position, 1)
        else
            play_surface_sound(surface, "utility/list_box_click", position, 0.9)
        end

        set_chunk_cooldown(state, surface, record.chunk_x, record.chunk_y, current_tick + REENTRY_DELAY_TICKS + jitter_ticks(surface, record.chunk_x, record.chunk_y, 6401))
        register_dormant_candidate(state, surface, record.chunk_x, record.chunk_y, current_tick)
    end

    state.active[record.key] = nil
    refresh_active_floor_state(state, current_tick)
end

register_active_fumarole = function(state, surface, chunk_x, chunk_y, entity, amount, current_tick)
    current_tick = resolve_tick(current_tick)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    local position = entity.position
    local band_name = get_chunk_band_name(chunk_x, chunk_y)
    local record = {
        key = key,
        surface_index = surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        band_name = band_name,
        position = {x = position.x, y = position.y},
        entity = entity,
        initial_amount = amount,
        touched = false,
        spawn_tick = current_tick,
        untouched_deadline_tick = current_tick + get_untouched_lifetime_ticks(surface, chunk_x, chunk_y, current_tick),
    }

    state.active[key] = record
    add_active_bucket_entry(state, surface.index, chunk_x, chunk_y, key)
    increment_active_band_count(state, surface.index, band_name)

    refresh_active_floor_state(state, current_tick)

    return record
end

local function attempt_spawn_fumarole(surface, chunk_x, chunk_y, context, current_tick, placement_candidate)
    local state = get_state()
    current_tick = resolve_tick(current_tick)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    if state.active[key] then
        return false, "active"
    end

    if get_chunk_cooldown_until_tick(state, key, current_tick) then
        return false, "cooldown"
    end

    local candidate = placement_candidate
    if not candidate then
        local reason = nil
        candidate, reason = select_spawn_candidate(surface, chunk_x, chunk_y, context)
        if not candidate then
            return false, reason or "placement"
        end
    end

    local position = candidate.position
    if candidate.blockers and #candidate.blockers > 0 then
        if not context_allows_breach(context) then
            return false, "occupied"
        end

        local breach_salt = (context == "backfill" and 1301)
            or (context == "recovery" and 1304)
            or (context == "keepalive" and 1303)
            or 1302
        if not breach_roll(surface, chunk_x, chunk_y, breach_salt) then
            return false, "occupied"
        end

        for _, blocker in pairs(candidate.blockers) do
            destroy_breach_blocker(blocker)
        end
        create_breach_fires(state, surface, position, current_tick)
        play_surface_sound(surface, "utility/cannot_build", position, 1.1)
    end

    local amount = get_spawn_amount(surface, chunk_x, chunk_y)
    local entity = create_fumarole_entity(surface, position, amount)
    if not entity or not entity.valid then
        return false, "placement"
    end

    mark_history_chunk(state, surface, chunk_x, chunk_y)
    clear_dormant_chunk(state, key)
    register_active_fumarole(state, surface, chunk_x, chunk_y, entity, amount, current_tick)
    return true, "spawned"
end

local function evaluate_chunk_initial(surface, chunk_position, context, current_tick)
    if not model.is_vulcanus_surface(surface) then
        return
    end

    local state = get_state()
    current_tick = resolve_tick(current_tick)
    local key = chunk_key(surface.index, chunk_position.x, chunk_position.y)
    local was_processed = state.processed_chunks[key]
    if was_processed and context ~= "backfill" then
        return
    end

    if adopt_existing_fumarole(state, surface, chunk_position.x, chunk_position.y, current_tick) then
        return
    end

    if context == "backfill" and state.dormant_chunks[key] then
        return
    end

    if not was_processed then
        register_processed_chunk(state, surface, chunk_position.x, chunk_position.y)
    end

    local distance_weight = get_fumarole_distance_weight(surface, chunk_position.x, chunk_position.y)
    local band_name = get_chunk_band_name(chunk_position.x, chunk_position.y)
    if not was_processed and context ~= "backfill" and band_name then
        increment_generated_band_count(state, surface.index, band_name)
    end

    if distance_weight <= 0 then
        clear_dormant_chunk(state, key)
        return
    end

    if context == "backfill" then
        register_dormant_candidate(state, surface, chunk_position.x, chunk_position.y, current_tick)
        return
    end

    local spawned = false
    if immediate_spawn_roll(surface, chunk_position.x, chunk_position.y, distance_weight) then
        spawned = select(1, attempt_spawn_fumarole(surface, chunk_position.x, chunk_position.y, context, current_tick))
    end

    if not spawned then
        register_dormant_candidate(state, surface, chunk_position.x, chunk_position.y, current_tick)
    end
end

local function migrate_due_dormant_buckets(state, current_tick)
    current_tick = resolve_tick(current_tick)
    for due_tick, bucket in pairs(state.dormant_delayed_buckets or {}) do
        if due_tick <= current_tick then
            state.dormant_delayed_buckets[due_tick] = nil
            for _, key in pairs(bucket) do
                local record = state.dormant_chunks[key]
                if record and (record.due_tick or due_tick) <= current_tick then
                    enqueue_ready_chunk(state, record.surface_index, key, record.band_name)
                end
            end
        end
    end
end

local function process_one_dormant_chunk(state, key, current_tick)
    current_tick = resolve_tick(current_tick)
    local dormant = state.dormant_chunks[key]
    if not dormant then
        return
    end

    local surface = game.surfaces[dormant.surface_index]
    if not model.is_vulcanus_surface(surface) then
        clear_dormant_chunk(state, key)
        return
    end

    local distance_weight = get_fumarole_distance_weight(surface, dormant.chunk_x, dormant.chunk_y)
    if distance_weight <= 0 then
        clear_dormant_chunk(state, key)
        return
    end

    local band_name = dormant.band_name or get_chunk_band_name(dormant.chunk_x, dormant.chunk_y)
    dormant.band_name = band_name

    if state.active[key] then
        clear_dormant_chunk(state, key)
        return
    end

    local candidate, candidate_reason = select_spawn_candidate(surface, dormant.chunk_x, dormant.chunk_y, "dormant")
    if not candidate then
        if candidate_reason == "invalid-tile" or candidate_reason == "auric-spacing" or candidate_reason == "sulfuric-spacing" or candidate_reason == "spacing" or candidate_reason == "blocked" or candidate_reason == "occupied" or candidate_reason == "placement" then
            schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 505, current_tick)
        else
            clear_dormant_chunk(state, key)
        end
        return
    end

    local modifier = get_local_saturation_modifier(state, dormant.surface_index, dormant.chunk_x, dormant.chunk_y)
    modifier = modifier * get_sulfuric_probability_modifier(candidate.sulfuric_distance)
    modifier = modifier * get_band_fill_modifier(state, dormant.surface_index, band_name)
    local seed = get_surface_seed(surface)
    local roll = hash01(seed, dormant.chunk_x, dormant.chunk_y, 2401 + math.floor(current_tick / DORMANT_PULSE_TICKS))
    if roll >= (DORMANT_BASE_CHANCE * distance_weight * modifier) then
        schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_MISS_DELAY, 504, current_tick)
        return
    end

    local spawned, reason = attempt_spawn_fumarole(surface, dormant.chunk_x, dormant.chunk_y, "dormant", current_tick, candidate)
    if not spawned then
        if reason == "invalid-tile" or reason == "auric-spacing" or reason == "sulfuric-spacing" or reason == "spacing" or reason == "blocked" or reason == "occupied" or reason == "placement" or reason == "cooldown" then
            schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 505, current_tick)
        else
            clear_dormant_chunk(state, key)
        end
    end
end

local function is_retryable_spawn_reason(reason)
    return reason == "invalid-tile"
        or reason == "auric-spacing"
        or reason == "sulfuric-spacing"
        or reason == "spacing"
        or reason == "blocked"
        or reason == "occupied"
        or reason == "placement"
        or reason == "cooldown"
end

local function get_recovery_attempt_budget(state)
    for _, surface in pairs(game.surfaces) do
        if model.is_vulcanus_surface(surface) then
            local target_total = get_surface_total_band_target(state, surface.index)
            if target_total > 0 then
                local active_total = get_surface_total_band_active(state, surface.index)
                if (active_total / target_total) < BAND_RECOVERY_LOW_TOTAL_RATIO then
                    return BAND_RECOVERY_LOW_TOTAL_ATTEMPTS_PER_PULSE
                end
            end
        end
    end

    return BAND_RECOVERY_BASE_ATTEMPTS_PER_PULSE
end

local function get_recovery_band_candidates(state)
    local entries = {}

    for surface_index, band_counts in pairs(state.dormant_band_counts) do
        for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
            local ready_count = band_counts[band_name] or 0
            if ready_count > 0 then
                local target = get_band_target_count(state, surface_index, band_name)
                if target > 0 then
                    local active = get_band_active_count(state, surface_index, band_name)
                    local fill_ratio = active / target
                    if fill_ratio < BAND_RECOVERY_FILL_THRESHOLD then
                        entries[#entries + 1] = {
                            surface_index = surface_index,
                            band_name = band_name,
                            fill_ratio = fill_ratio,
                            deficit = math.max(0, target - active),
                            band_index = FUMAROLE_BAND_INDEX[band_name] or 0,
                        }
                    end
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.fill_ratio ~= b.fill_ratio then
            return a.fill_ratio < b.fill_ratio
        end
        if a.deficit ~= b.deficit then
            return a.deficit > b.deficit
        end
        if a.band_index ~= b.band_index then
            return a.band_index > b.band_index
        end
        if a.surface_index ~= b.surface_index then
            return a.surface_index < b.surface_index
        end
        return a.band_name < b.band_name
    end)

    return entries
end

local function process_band_recovery_spawn(state, current_tick)
    local budget = get_recovery_attempt_budget(state)
    if budget <= 0 then
        return
    end

    for attempt_index = 1, budget do
        local entries = get_recovery_band_candidates(state)
        local entry = entries[1]
        if not entry then
            return
        end

        local key = dequeue_ready_band_chunk(state, entry.surface_index, entry.band_name)
        if key then
            local dormant = state.dormant_chunks[key]
            if dormant then
                dormant.band_name = dormant.band_name or entry.band_name
            end

            state.band_recovery_stats.attempts = (state.band_recovery_stats.attempts or 0) + 1

            local surface = dormant and game.surfaces[dormant.surface_index] or nil
            if not dormant or not model.is_vulcanus_surface(surface) then
                clear_dormant_chunk(state, key)
            elseif state.active[key] then
                clear_dormant_chunk(state, key)
            elseif get_chunk_cooldown_until_tick(state, key, current_tick) then
                schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 6501 + attempt_index, current_tick)
                state.band_recovery_stats.blocked = (state.band_recovery_stats.blocked or 0) + 1
            else
                local distance_weight = get_fumarole_distance_weight(surface, dormant.chunk_x, dormant.chunk_y)
                if distance_weight <= 0 then
                    clear_dormant_chunk(state, key)
                else
                    local local_modifier = get_local_saturation_modifier(state, dormant.surface_index, dormant.chunk_x, dormant.chunk_y)
                    if local_modifier < BAND_RECOVERY_LOCAL_MIN_MODIFIER then
                        schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_MISS_DELAY, 6502 + attempt_index, current_tick)
                        state.band_recovery_stats.soft_misses = (state.band_recovery_stats.soft_misses or 0) + 1
                    else
                        local candidate, candidate_reason = select_spawn_candidate(surface, dormant.chunk_x, dormant.chunk_y, "recovery")
                        if not candidate then
                            if is_retryable_spawn_reason(candidate_reason) then
                                schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 6503 + attempt_index, current_tick)
                                state.band_recovery_stats.blocked = (state.band_recovery_stats.blocked or 0) + 1
                            else
                                clear_dormant_chunk(state, key)
                            end
                        else
                            local spawned, reason = attempt_spawn_fumarole(surface, dormant.chunk_x, dormant.chunk_y, "recovery", current_tick, candidate)
                            if spawned then
                                state.band_recovery_stats.successes = (state.band_recovery_stats.successes or 0) + 1
                                refresh_active_floor_state(state, current_tick)
                            elseif is_retryable_spawn_reason(reason) then
                                schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 6504 + attempt_index, current_tick)
                                state.band_recovery_stats.blocked = (state.band_recovery_stats.blocked or 0) + 1
                            else
                                clear_dormant_chunk(state, key)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function keepalive_entry_precedes(a, b)
    if a.score ~= b.score then
        return a.score > b.score
    end

    if a.due_tick ~= b.due_tick then
        return a.due_tick < b.due_tick
    end

    return a.key < b.key
end

local function add_keepalive_shortlist_entry(shortlist, entry)
    local inserted = false
    for index = 1, #shortlist do
        if keepalive_entry_precedes(entry, shortlist[index]) then
            table.insert(shortlist, index, entry)
            inserted = true
            break
        end
    end

    if not inserted and #shortlist < KEEPALIVE_SHORTLIST_LIMIT then
        shortlist[#shortlist + 1] = entry
        inserted = true
    end

    if inserted and #shortlist > KEEPALIVE_SHORTLIST_LIMIT then
        table.remove(shortlist)
    end
end

local function get_keepalive_shortlist(state, current_tick)
    local shortlist = {}

    for key, record in pairs(state.dormant_chunks) do
        if not state.active[key] and not get_chunk_cooldown_until_tick(state, key, current_tick) then
            local surface = game.surfaces[record.surface_index]
            if model.is_vulcanus_surface(surface) then
                local distance_weight = get_fumarole_distance_weight(surface, record.chunk_x, record.chunk_y)
                if distance_weight > 0 then
                    local local_modifier = get_local_saturation_modifier(state, record.surface_index, record.chunk_x, record.chunk_y)
                    add_keepalive_shortlist_entry(shortlist, {
                        key = key,
                        score = distance_weight * local_modifier,
                        due_tick = record.due_tick or math.huge,
                    })
                end
            end
        end
    end

    return shortlist
end

local function handle_failed_keepalive_spawn(state, key, surface, record, reason, salt, current_tick)
    if is_retryable_spawn_reason(reason) then
        schedule_dormant_chunk(state, surface, record.chunk_x, record.chunk_y, DORMANT_BLOCKED_DELAY, salt, current_tick)
    else
        clear_dormant_chunk(state, key)
    end
end

local function process_keepalive_spawn(state, current_tick)
    current_tick = resolve_tick(current_tick)
    local active_count = refresh_active_floor_state(state, current_tick)
    if active_count >= KEEPALIVE_TARGET_ACTIVE then
        return
    end

    local below_floor_since_tick = state.below_floor_since_tick
    if not below_floor_since_tick or (current_tick - below_floor_since_tick) < KEEPALIVE_BELOW_FLOOR_GRACE_TICKS then
        return
    end

    local max_attempts = math.min(KEEPALIVE_ATTEMPTS_PER_PULSE, KEEPALIVE_TARGET_ACTIVE - active_count)
    for attempt = 1, max_attempts do
        local shortlist = get_keepalive_shortlist(state, current_tick)
        if #shortlist == 0 then
            return
        end

        local spawned = false
        for shortlist_index, entry in ipairs(shortlist) do
            local key = entry.key
            local record = state.dormant_chunks[key]
            if record and not state.active[key] and not get_chunk_cooldown_until_tick(state, key, current_tick) then
                local surface = game.surfaces[record.surface_index]
                if not model.is_vulcanus_surface(surface) then
                    clear_dormant_chunk(state, key)
                else
                    local candidate, candidate_reason = select_spawn_candidate(surface, record.chunk_x, record.chunk_y, "keepalive")
                    if candidate then
                        local did_spawn, reason = attempt_spawn_fumarole(surface, record.chunk_x, record.chunk_y, "keepalive", current_tick, candidate)
                        if did_spawn then
                            active_count = refresh_active_floor_state(state, current_tick)
                            spawned = true
                            break
                        end

                        handle_failed_keepalive_spawn(state, key, surface, record, reason, 5600 + (attempt * 100) + shortlist_index, current_tick)
                    else
                        handle_failed_keepalive_spawn(state, key, surface, record, candidate_reason or "placement", 5600 + (attempt * 100) + shortlist_index, current_tick)
                    end
                end
            end
        end

        if active_count >= KEEPALIVE_TARGET_ACTIVE then
            return
        end

        if not spawned then
            active_count = refresh_active_floor_state(state, current_tick)
            if active_count >= KEEPALIVE_TARGET_ACTIVE then
                return
            end
        end
    end
end

local function process_dormant_scheduler(current_tick)
    local state = get_state()
    current_tick = resolve_tick(current_tick)
    migrate_due_dormant_buckets(state, current_tick)

    local surfaces = state.dormant_active_surfaces
    if #surfaces > 0 then
        for _ = 1, DORMANT_GLOBAL_CHECKS_PER_PULSE do
            local live_surface_count = #surfaces
            if live_surface_count == 0 then
                break
            end

            local cursor = (state.dormant_active_surface_cursor % live_surface_count) + 1
            state.dormant_active_surface_cursor = cursor
            local surface_index = surfaces[cursor]
            local key = dequeue_ready_chunk(state, surface_index)
            if key then
                process_one_dormant_chunk(state, key, current_tick)
            elseif #surfaces == 0 then
                break
            end
        end
    end

    process_band_recovery_spawn(state, current_tick)
    process_keepalive_spawn(state, current_tick)
end

local function audit_active_fumaroles(current_tick)
    local state = get_state()
    current_tick = resolve_tick(current_tick)
    for key, record in pairs(state.active) do
        local surface = game.surfaces[record.surface_index]
        if not model.is_vulcanus_surface(surface) then
            finalize_closure(state, record, "invalid-surface", current_tick)
        else
            local entity = record.entity
            local amount = get_fumarole_resource_amount(entity)
            if not amount then
                finalize_closure(state, record, "missing", current_tick)
            else
                if not record.touched and amount < (record.initial_amount or amount) then
                    record.touched = true
                end

                if not record.touched and current_tick >= (record.untouched_deadline_tick or 0) then
                    finalize_closure(state, record, "self-seal", current_tick)
                end
            end
        end
    end

    refresh_active_floor_state(state, current_tick)
end

local function process_backfill_queue(current_tick)
    local state = get_state()
    local queue = state.backfill_queue
    for _ = 1, BACKFILL_CHUNKS_PER_PASS do
        local entry = queue_pop(queue)
        if not entry then
            return
        end

        local surface = game.surfaces[entry.surface_index]
        if model.is_vulcanus_surface(surface) then
            evaluate_chunk_initial(surface, {x = entry.chunk_x, y = entry.chunk_y}, "backfill", current_tick)
        end
    end
end

local function enqueue_backfill_surface(surface, force_refresh)
    if not model.is_vulcanus_surface(surface) then
        return 0
    end

    local state = get_state()
    return queue_backfill_entries(state, surface, force_refresh)
end

local function enqueue_all_vulcanus_backfill(force_refresh)
    local queued = 0
    for _, surface in pairs(game.surfaces) do
        if model.is_vulcanus_surface(surface) then
            queued = queued + enqueue_backfill_surface(surface, force_refresh)
        end
    end

    return queued
end

local function rebuild_backfill_surface(surface)
    if not model.is_vulcanus_surface(surface) then
        return 0
    end

    local state = get_state()
    filter_backfill_queue(state, function(entry)
        return entry.surface_index ~= surface.index
    end)

    return queue_backfill_entries(state, surface, true)
end

local function rebuild_all_vulcanus_backfill()
    local surfaces = {}
    local target_surface_indexes = {}

    for _, surface in pairs(game.surfaces) do
        if model.is_vulcanus_surface(surface) then
            surfaces[#surfaces + 1] = surface
            target_surface_indexes[surface.index] = true
        end
    end

    if #surfaces == 0 then
        return 0
    end

    local state = get_state()
    filter_backfill_queue(state, function(entry)
        return not target_surface_indexes[entry.surface_index]
    end)

    local queued = 0
    for _, surface in ipairs(surfaces) do
        queued = queued + queue_backfill_entries(state, surface, true)
    end

    return queued
end

local function bootstrap_generated_chunks(force_refresh)
    local state = get_state()
    force_refresh = force_refresh or state.pending_eligibility_refresh == true
    if not force_refresh and state.backfill_bootstrapped then
        return 0
    end

    local current_tick = game and game.tick or 0
    local found_vulcanus = false
    for _, surface in pairs(game.surfaces) do
        if model.is_vulcanus_surface(surface) then
            found_vulcanus = true
            break
        end
    end

    if not found_vulcanus then
        state.next_surface_probe_tick = current_tick + SURFACE_PROBE_RETRY_TICKS
        return 0
    end

    local queued = force_refresh and rebuild_all_vulcanus_backfill() or enqueue_all_vulcanus_backfill(false)
    state.backfill_bootstrapped = true
    state.pending_eligibility_refresh = false
    state.next_surface_probe_tick = 0
    return queued
end

local function copy_band_counts(counts)
    local snapshot = {}
    for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
        snapshot[band_name] = counts and counts[band_name] or 0
    end
    return snapshot
end

local function build_band_status(state)
    local status = {}

    for _, surface in pairs(game.surfaces) do
        if model.is_vulcanus_surface(surface) then
            local surface_key = tostring(surface.index)
            local generated = get_generated_band_counts(state, surface.index)
            local active = get_active_band_counts(state, surface.index)
            local ready = get_dormant_band_counts(state, surface.index)
            local target = {}
            local fill = {}

            for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
                local target_count = get_band_target_count(state, surface.index, band_name)
                target[band_name] = target_count
                fill[band_name] = target_count > 0 and (active[band_name] or 0) / target_count or 0
            end

            status[surface_key] = {
                generated = copy_band_counts(generated),
                active = copy_band_counts(active),
                ready = copy_band_counts(ready),
                target = target,
                fill = fill,
                total_target = get_surface_total_band_target(state, surface.index),
                total_active = get_surface_total_band_active(state, surface.index),
            }
        end
    end

    return status
end

function model.on_init(_event)
    model.check_global()
    bootstrap_generated_chunks(false)
end

function model.on_configuration_changed(event)
    model.check_global()
    if next(event.mod_changes or {}) ~= nil then
        -- Real config changes should rebuild the pending queue even if the saved runtime sentinel matches.
        get_state().pending_eligibility_refresh = true
    end
    bootstrap_generated_chunks(false)
end

function model.on_chunk_generated(event)
    local surface = event and event.surface or nil
    if not model.is_vulcanus_surface(surface) then
        return
    end

    evaluate_chunk_initial(surface, event.position, "chunk-generated", event and event.tick)
end

function model.on_resource_depleted(event)
    local entity = event and event.entity or nil
    if not entity or not entity.valid or entity.name ~= RESOURCE_NAME then
        return
    end

    local surface = entity.surface
    if not model.is_vulcanus_surface(surface) then
        return
    end

    local state = get_state()
    local chunk_x = math.floor(entity.position.x / CHUNK_SIZE)
    local chunk_y = math.floor(entity.position.y / CHUNK_SIZE)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    local record = state.active[key]
    if not record then
        record = {
            key = key,
            surface_index = surface.index,
            chunk_x = chunk_x,
            chunk_y = chunk_y,
            position = {x = entity.position.x, y = entity.position.y},
            entity = entity,
        }
    end

    finalize_closure(state, record, "depleted", event and event.tick)
end

function model.has_tick_work(event)
    local state = storage and storage.ei and storage.ei.vulcanus_fumaroles or nil
    if type(state) ~= "table" then
        return false
    end

    local tick = event and event.tick or game and game.tick or 0
    if not state.backfill_bootstrapped or state.pending_eligibility_refresh == true then
        local next_surface_probe_tick = tonumber(state.next_surface_probe_tick) or 0
        return next_surface_probe_tick <= 0 or tick >= next_surface_probe_tick
    end

    if raw_queue_has_items(state.backfill_queue) then
        return tick % BACKFILL_PROCESS_TICKS == 0
    end

    if raw_delayed_buckets_have_items(state.dormant_delayed_buckets)
        or (type(state.dormant_chunks) == "table" and next(state.dormant_chunks) ~= nil)
        or raw_surface_queues_have_items(state.dormant_surface_queues)
        or raw_band_queues_have_items(state.dormant_band_queues)
    then
        return tick % DORMANT_PULSE_TICKS == 0
    end

    if type(state.active) == "table" and next(state.active) ~= nil then
        return tick % ACTIVE_AUDIT_TICKS == 0
    end

    if type(state.breach_fires) == "table" and next(state.breach_fires) ~= nil then
        return tick % BREACH_FIRE_CLEANUP_TICKS == 0
    end

    return false
end

function model.updater(event)
    local state = get_state()
    local current_tick = event and event.tick or game and game.tick or 0
    local next_surface_probe_tick = tonumber(state.next_surface_probe_tick) or 0
    if (not state.backfill_bootstrapped or state.pending_eligibility_refresh)
        and (next_surface_probe_tick <= 0 or current_tick >= next_surface_probe_tick)
    then
        bootstrap_generated_chunks(false)
    end

    if event.tick % BACKFILL_PROCESS_TICKS == 0 then
        process_backfill_queue(current_tick)
    end

    if event.tick % DORMANT_PULSE_TICKS == 0 then
        process_dormant_scheduler(current_tick)
    end

    if event.tick % ACTIVE_AUDIT_TICKS == 0 then
        audit_active_fumaroles(current_tick)
    end

    if event.tick % BREACH_FIRE_CLEANUP_TICKS == 0 then
        cleanup_breach_fires(state, current_tick)
    end
end

function model.get_runtime_status()
    model.check_global()

    local state = get_state()
    local active_count = refresh_active_floor_state(state)
    local ready_surface_queue_items = 0
    for _, queue in pairs(state.dormant_surface_queues or {}) do
        ready_surface_queue_items = ready_surface_queue_items + ei_runtime_scheduler.queue_item_count(queue)
    end

    local ready_band_queue_items = 0
    for _, queues in pairs(state.dormant_band_queues or {}) do
        for _, band_name in ipairs(FUMAROLE_BAND_ORDER) do
            ready_band_queue_items = ready_band_queue_items + ei_runtime_scheduler.queue_item_count(queues[band_name])
        end
    end

    local status = {
        processed_chunk_count = ei_runtime_scheduler.table_count(state.processed_chunks),
        history_chunk_count = ei_runtime_scheduler.table_count(state.history_chunks),
        cooldown_chunk_count = ei_runtime_scheduler.table_count(state.cooldown_chunks),
        backfill_queue = ei_runtime_scheduler.audit_queue(state.backfill_queue),
        active_fumarole_count = active_count,
        active_bucket_surface_count = ei_runtime_scheduler.table_count(state.active_chunk_buckets),
        dormant_chunk_count = ei_runtime_scheduler.table_count(state.dormant_chunks),
        dormant_bucket_count = ei_runtime_scheduler.delayed_bucket_count(state.dormant_delayed_buckets),
        dormant_item_count = ei_runtime_scheduler.delayed_item_count(state.dormant_delayed_buckets),
        dormant_active_surface_count = #(state.dormant_active_surfaces or {}),
        ready_surface_queue_items = ready_surface_queue_items,
        ready_band_queue_items = ready_band_queue_items,
        zero_active_since_tick = state.zero_active_since_tick,
        below_floor_since_tick = state.below_floor_since_tick,
        keepalive_target_active = KEEPALIVE_TARGET_ACTIVE,
        band_recovery_stats = {
            attempts = state.band_recovery_stats.attempts or 0,
            successes = state.band_recovery_stats.successes or 0,
            soft_misses = state.band_recovery_stats.soft_misses or 0,
            blocked = state.band_recovery_stats.blocked or 0,
        },
        band_status = build_band_status(state),
        active = active_count,
        dormant_chunks = ei_runtime_scheduler.table_count(state.dormant_chunks),
        dormant_buckets = ei_runtime_scheduler.delayed_bucket_count(state.dormant_delayed_buckets),
        dormant_bucket_items = ei_runtime_scheduler.delayed_item_count(state.dormant_delayed_buckets),
        active_surfaces = #(state.dormant_active_surfaces or {}),
        runtime_version = state.runtime_version or 0,
        eligibility_version = state.eligibility_version,
        pending_eligibility_refresh = state.pending_eligibility_refresh == true,
    }

    ei_runtime_scheduler.set_module_status("vulcanus-fumaroles", status)
    return status
end

local function print_command_feedback(command, message)
    if command.player_index then
        local player = game.get_player(command.player_index)
        if player and player.valid then
            player.print(message)
        end
    else
        game.print(message)
    end
end

commands.add_command(
    "rescan_auric_fumaroles",
    "Rebuilds the pending dormant auric fumarole eligibility queue for generated chunks on Vulcanus.",
    function(command)
        local player = command.player_index and game.get_player(command.player_index) or nil
        if command.player_index and (not player or not player.admin) then
            return
        end

        model.check_global()

        if player then
            if not model.is_vulcanus_surface(player.surface) then
                print_command_feedback(command, {"description.auric-fumarole-rescan-refusal"})
                return
            end

            local queued = rebuild_backfill_surface(player.surface)
            print_command_feedback(command, {"description.auric-fumarole-rescan-success", queued})
            return
        end

        local queued = rebuild_all_vulcanus_backfill()
        print_command_feedback(command, {"description.auric-fumarole-rescan-success", queued})
    end
)

return model
