--==============================================================================
-- ESIR FILE MAP
-- owns: auric fumarole runtime generation, depletion, and afterglow cleanup
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init, configuration-changed, chunk generation, resource depletion, and every-tick cleanup
-- forwarded_events: check_global, is_vulcanus_surface, on_chunk_generated, on_configuration_changed, on_init, on_resource_depleted, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init, configuration change, Vulcanus resource prototype changes
--==============================================================================
local ei_lib = require("lib/lib")
local ei_runtime_scheduler = require("lib/runtime-scheduler")

local model = {}

local RESOURCE_NAME = "ei-auric-fumarole"
local SOUND_PROXY_NAME = "ei-auric-fumarole-sound-proxy"
local AFTERGLOW_ANIMATION = "ei-auric-fumarole-afterglow"
local VULCANUS_SURFACE_NAME = "vulcanus"

local IMMEDIATE_SPAWN_CHANCE = 0.12
local DORMANT_BASE_CHANCE = 0.0025

local DORMANT_PULSE_TICKS = 1800
local DORMANT_GLOBAL_CHECKS_PER_PULSE = 6
local DORMANT_MISS_DELAY = 54000
local DORMANT_BLOCKED_DELAY = 108000
local DORMANT_DELAY_JITTER = 18000
local KEEPALIVE_GRACE_TICKS = 10 * 60 * 60
local KEEPALIVE_ATTEMPTS_PER_PULSE = 2
local REENTRY_DELAY_TICKS = 60 * 60 * 60

local ACTIVE_AUDIT_TICKS = 600
local BACKFILL_PROCESS_TICKS = 30
local BACKFILL_CHUNKS_PER_PASS = 4
local UNTOUCHED_LIFETIME_TICKS = 45 * 60 * 60
local AFTERGLOW_TICKS = 3600
local MIN_FUMAROLE_AMOUNT = 4000
local MAX_FUMAROLE_AMOUNT = 8000
local AURIC_SPACING_RADIUS = 64
local SULFURIC_SPACING_RADIUS = 32
local LOCAL_SATURATION_RADIUS = 6

local BREACH_DISCARD_CHANCE = 0.98

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

local function new_state()
    return {
        backfill_bootstrapped = false,
        processed_chunks = {},
        history_chunks = {},
        cooldown_chunks = {},
        backfill_queue = new_queue_state(),
        active = {},
        active_chunk_buckets = {},
        dormant_chunks = {},
        dormant_delayed_buckets = {},
        dormant_surface_queues = {},
        dormant_surface_counts = {},
        dormant_active_surfaces = {},
        dormant_active_surface_positions = {},
        dormant_active_surface_cursor = 0,
        zero_active_since_tick = nil,
        sound_proxies = {},
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

    if next(state.sound_proxies or {}) ~= nil then
        return true
    end

    return false
end

function model.check_global()
    local state = get_state()

    if state.backfill_bootstrapped == nil then
        state.backfill_bootstrapped = false
    end
    state.processed_chunks = state.processed_chunks or {}
    state.history_chunks = state.history_chunks or {}
    state.cooldown_chunks = state.cooldown_chunks or {}
    state.backfill_queue = ei_runtime_scheduler.ensure_queue(state.backfill_queue or new_queue_state())
    state.active = state.active or {}
    state.active_chunk_buckets = state.active_chunk_buckets or {}
    state.dormant_chunks = state.dormant_chunks or {}
    state.dormant_delayed_buckets = ei_runtime_scheduler.ensure_delayed_buckets(state.dormant_delayed_buckets)
    state.dormant_surface_queues = state.dormant_surface_queues or {}
    state.dormant_surface_counts = state.dormant_surface_counts or {}
    state.dormant_active_surfaces = state.dormant_active_surfaces or {}
    state.dormant_active_surface_positions = state.dormant_active_surface_positions or {}
    state.dormant_active_surface_cursor = state.dormant_active_surface_cursor or 0
    state.sound_proxies = state.sound_proxies or {}

    for surface_index, queue in pairs(state.dormant_surface_queues) do
        state.dormant_surface_queues[surface_index] = ei_runtime_scheduler.ensure_queue(queue)
    end

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

local function quantize_due_tick(raw_due_tick)
    return math.ceil(raw_due_tick / DORMANT_PULSE_TICKS) * DORMANT_PULSE_TICKS
end

local function get_chunk_center(chunk_x, chunk_y)
    return {
        x = chunk_x * 32 + 16,
        y = chunk_y * 32 + 16,
    }
end

local function get_ready_queue(state, surface_index)
    local queue = state.dormant_surface_queues[surface_index]
    if not queue then
        queue = new_queue_state()
        state.dormant_surface_queues[surface_index] = queue
    end
    return queue
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

local function enqueue_ready_chunk(state, surface_index, key)
    local queue = get_ready_queue(state, surface_index)
    queue_push(queue, key)
    state.dormant_surface_counts[surface_index] = (state.dormant_surface_counts[surface_index] or 0) + 1
    add_active_surface(state, surface_index)
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
    if remaining == 0 or queue_length(queue) == 0 then
        state.dormant_surface_counts[surface_index] = 0
        clear_queue(queue)
        remove_active_surface(state, surface_index)
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

local function destroy_sound_proxy(state, key)
    local proxy = state.sound_proxies[key]
    if proxy and proxy.valid then
        proxy.destroy()
    end
    state.sound_proxies[key] = nil
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

local function count_nearby_active_fumaroles(state, surface_index, chunk_x, chunk_y)
    local surface_bucket = state.active_chunk_buckets[surface_index]
    if not surface_bucket then
        return 0
    end

    local count = 0
    for x = chunk_x - LOCAL_SATURATION_RADIUS, chunk_x + LOCAL_SATURATION_RADIUS do
        local x_bucket = surface_bucket[x]
        if x_bucket then
            for y = chunk_y - LOCAL_SATURATION_RADIUS, chunk_y + LOCAL_SATURATION_RADIUS do
                if x_bucket[y] ~= nil then
                    count = count + 1
                    if count >= 2 then
                        return count
                    end
                end
            end
        end
    end

    return count
end

local function refresh_zero_active_since_tick(state, current_tick)
    current_tick = resolve_tick(current_tick)
    if next(state.active) ~= nil then
        state.zero_active_since_tick = nil
    elseif state.zero_active_since_tick == nil then
        state.zero_active_since_tick = current_tick
    end
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

local function get_territory_name(surface, chunk_position)
    if not surface or not surface.valid or not surface.get_territory_for_chunk then
        return nil
    end

    local ok, territory = pcall(surface.get_territory_for_chunk, surface, chunk_position)
    if not ok or territory == nil then
        return nil
    end

    if type(territory) == "string" then
        return territory
    end

    if type(territory) == "table" then
        return territory.name or territory.territory or territory.id or territory[1]
    end

    return tostring(territory)
end

local function is_danger_territory(surface, chunk_position)
    local territory_name = get_territory_name(surface, chunk_position)
    if not territory_name then
        return false
    end

    territory_name = string.lower(territory_name)
    if string.find(territory_name, "danger", 1, true) or string.find(territory_name, "outer", 1, true) then
        return true
    end

    if string.find(territory_name, "safe", 1, true) or string.find(territory_name, "start", 1, true) then
        return false
    end

    return false
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

local function spacing_is_clear(surface, position)
    local nearby_auric = surface.find_entities_filtered{
        position = position,
        radius = AURIC_SPACING_RADIUS,
        name = RESOURCE_NAME,
    }

    if #nearby_auric > 0 then
        return false, "auric-spacing"
    end

    local nearby_sulfuric = surface.find_entities_filtered{
        position = position,
        radius = SULFURIC_SPACING_RADIUS,
        name = "sulfuric-acid-geyser",
    }

    if #nearby_sulfuric > 0 then
        return false, "sulfuric-spacing"
    end

    return true, nil
end

local function collect_center_obstacles(surface, position)
    local area = {
        {position.x - 2.4, position.y - 2.4},
        {position.x + 2.4, position.y + 2.4},
    }

    local entities = surface.find_entities_filtered{area = area}
    local blockers = {}
    local non_breachable = false

    for _, entity in pairs(entities) do
        if entity.valid and entity.name ~= RESOURCE_NAME and entity.name ~= SOUND_PROXY_NAME then
            if entity.type == "resource" then
                non_breachable = true
            elseif EXEMPT_BREACH_TYPES[entity.type] then
                non_breachable = true
            elseif entity.force and entity.force.valid and entity.force.name ~= "neutral" and entity.force.name ~= "enemy" then
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

local function create_breach_fires(surface, position)
    local seed = get_surface_seed(surface)
    local fire_count = 1 + math.floor(hash01(seed, math.floor(position.x), math.floor(position.y), 7711) * 3)

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
            fire.time_to_live = math.min(fire.time_to_live or 60 * 60, 15 * 60)
        end
    end
end

local function make_sound_proxy(surface, position)
    if not model.is_vulcanus_surface(surface) then
        return nil
    end

    return surface.create_entity{
        name = SOUND_PROXY_NAME,
        position = position,
        force = "neutral",
    }
end

local function create_fumarole_entity(surface, position, amount)
    local entity = surface.create_entity{
        name = RESOURCE_NAME,
        position = position,
        amount = amount,
    }

    if entity and entity.valid then
        entity.amount = amount
    end

    return entity
end

local function find_existing_fumarole_entity(surface, chunk_x, chunk_y)
    local area = {
        {chunk_x * 32, chunk_y * 32},
        {chunk_x * 32 + 32, chunk_y * 32 + 32},
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

local function adopt_existing_fumarole(state, surface, chunk_x, chunk_y, current_tick)
    local entity = find_existing_fumarole_entity(surface, chunk_x, chunk_y)
    if not entity then
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
        record.position = {x = entity.position.x, y = entity.position.y}
        record.entity = entity
        record.initial_amount = record.initial_amount or entity.amount
        record.untouched_deadline_tick = record.untouched_deadline_tick or (current_tick + UNTOUCHED_LIFETIME_TICKS)
        add_active_bucket_entry(state, surface.index, chunk_x, chunk_y, key)
        if not (state.sound_proxies[key] and state.sound_proxies[key].valid) then
            local proxy = make_sound_proxy(surface, record.position)
            if proxy and proxy.valid then
                state.sound_proxies[key] = proxy
            end
        end
        return true
    end

    register_active_fumarole(state, surface, chunk_x, chunk_y, entity, entity.amount, current_tick)
    return true
end

local function get_spawn_amount(surface, chunk_x, chunk_y)
    local seed = get_surface_seed(surface)
    local span = MAX_FUMAROLE_AMOUNT - MIN_FUMAROLE_AMOUNT + 1
    return MIN_FUMAROLE_AMOUNT + math.floor(hash01(seed, chunk_x, chunk_y, 901) * span)
end

local function immediate_spawn_roll(surface, chunk_x, chunk_y)
    local seed = get_surface_seed(surface)
    return hash01(seed, chunk_x, chunk_y, 101) < IMMEDIATE_SPAWN_CHANCE
end

local function breach_roll(surface, chunk_x, chunk_y, salt)
    local seed = get_surface_seed(surface)
    return hash01(seed, chunk_x, chunk_y, salt) >= BREACH_DISCARD_CHANCE
end

local function jitter_ticks(surface, chunk_x, chunk_y, salt)
    local seed = get_surface_seed(surface)
    return math.floor(hash01(seed, chunk_x, chunk_y, salt) * (DORMANT_DELAY_JITTER + 1))
end

local function remove_dormant_from_ready_queues(state, key, surface_index)
    local queue = state.dormant_surface_queues[surface_index]
    if not queue then
        return
    end

    local items = queue.items
    local removed = false
    for i = queue.head or 1, #items do
        if items[i] == key then
            items[i] = false
            removed = true
            break
        end
    end

    if removed then
        local remaining = math.max(0, (state.dormant_surface_counts[surface_index] or 0) - 1)
        state.dormant_surface_counts[surface_index] = remaining
        if remaining == 0 then
            clear_queue(queue)
            remove_active_surface(state, surface_index)
        end
    end
end

local function clear_dormant_chunk(state, key)
    local dormant = state.dormant_chunks[key]
    if not dormant then
        return
    end

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

    local record = state.dormant_chunks[key] or {
        surface_index = surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
    }
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

    destroy_sound_proxy(state, record.key)
    remove_active_bucket_entry(state, record.surface_index, record.chunk_x, record.chunk_y)

    if record.entity and record.entity.valid then
        record.entity.destroy()
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
    refresh_zero_active_since_tick(state, current_tick)
end

local function register_active_fumarole(state, surface, chunk_x, chunk_y, entity, amount, current_tick)
    current_tick = resolve_tick(current_tick)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    local position = entity.position
    local record = {
        key = key,
        surface_index = surface.index,
        chunk_x = chunk_x,
        chunk_y = chunk_y,
        position = {x = position.x, y = position.y},
        entity = entity,
        initial_amount = amount,
        touched = false,
        spawn_tick = current_tick,
        untouched_deadline_tick = current_tick + UNTOUCHED_LIFETIME_TICKS,
    }

    state.active[key] = record
    add_active_bucket_entry(state, surface.index, chunk_x, chunk_y, key)
    destroy_sound_proxy(state, key)

    local proxy = make_sound_proxy(surface, position)
    if proxy and proxy.valid then
        state.sound_proxies[key] = proxy
    end

    refresh_zero_active_since_tick(state, current_tick)

    return record
end

local function attempt_spawn_fumarole(surface, chunk_x, chunk_y, context, current_tick)
    local state = get_state()
    current_tick = resolve_tick(current_tick)
    local key = chunk_key(surface.index, chunk_x, chunk_y)
    if state.active[key] then
        return false, "active"
    end

    if get_chunk_cooldown_until_tick(state, key, current_tick) then
        return false, "cooldown"
    end

    local position = get_chunk_center(chunk_x, chunk_y)
    local tile = surface.get_tile(position)
    if not is_valid_vulcanus_tile(tile) then
        return false, "invalid-tile"
    end

    local spacing_clear, spacing_reason = spacing_is_clear(surface, position)
    if not spacing_clear then
        return false, spacing_reason or "spacing"
    end

    if context == "backfill" or context == "dormant" then
        local blockers, non_breachable = collect_center_obstacles(surface, position)
        if non_breachable then
            return false, "blocked"
        end

        if #blockers > 0 then
            if not breach_roll(surface, chunk_x, chunk_y, context == "backfill" and 1301 or 1302) then
                return false, "occupied"
            end

            for _, blocker in pairs(blockers) do
                if blocker.valid then
                    if blocker.destructible then
                        blocker.die("neutral")
                    else
                        blocker.destroy()
                    end
                end
            end
            create_breach_fires(surface, position)
            play_surface_sound(surface, "utility/cannot_build", position, 1.1)
        end
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

    if not was_processed then
        register_processed_chunk(state, surface, chunk_position.x, chunk_position.y)
    end

    if not is_danger_territory(surface, chunk_position) then
        return
    end

    if was_processed and context == "backfill" then
        if not state.active[key] then
            register_dormant_candidate(state, surface, chunk_position.x, chunk_position.y, current_tick)
        end
        return
    end

    local spawned = false
    if immediate_spawn_roll(surface, chunk_position.x, chunk_position.y) then
        spawned = select(1, attempt_spawn_fumarole(surface, chunk_position.x, chunk_position.y, context, current_tick))
    end

    if not spawned then
        register_dormant_candidate(state, surface, chunk_position.x, chunk_position.y, current_tick)
    end
end

local function migrate_due_dormant_buckets(state, current_tick)
    current_tick = resolve_tick(current_tick)
    local bucket = ei_runtime_scheduler.delayed_take_due(state.dormant_delayed_buckets, current_tick)
    if #bucket == 0 then
        return
    end

    for _, key in pairs(bucket) do
        local record = state.dormant_chunks[key]
        if record and record.due_tick == current_tick then
            enqueue_ready_chunk(state, record.surface_index, key)
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

    local chunk_position = {x = dormant.chunk_x, y = dormant.chunk_y}
    if not is_danger_territory(surface, chunk_position) then
        schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 502, current_tick)
        return
    end

    if state.active[key] then
        clear_dormant_chunk(state, key)
        return
    end

    local nearby_active = count_nearby_active_fumaroles(state, dormant.surface_index, dormant.chunk_x, dormant.chunk_y)
    if nearby_active >= 2 then
        schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 503, current_tick)
        return
    end

    local modifier = 1
    if nearby_active == 1 then
        modifier = 0.35
    end

    local seed = get_surface_seed(surface)
    local roll = hash01(seed, dormant.chunk_x, dormant.chunk_y, 2401 + math.floor(current_tick / DORMANT_PULSE_TICKS))
    if roll >= (DORMANT_BASE_CHANCE * modifier) then
        schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_MISS_DELAY, 504, current_tick)
        return
    end

    local spawned, reason = attempt_spawn_fumarole(surface, dormant.chunk_x, dormant.chunk_y, "dormant", current_tick)
    if not spawned then
        if reason == "invalid-tile" or reason == "auric-spacing" or reason == "sulfuric-spacing" or reason == "spacing" or reason == "blocked" or reason == "occupied" or reason == "placement" or reason == "cooldown" then
            schedule_dormant_chunk(state, surface, dormant.chunk_x, dormant.chunk_y, DORMANT_BLOCKED_DELAY, 505, current_tick)
        else
            clear_dormant_chunk(state, key)
        end
    end
end

local function find_keepalive_candidate(state, current_tick)
    local best_key = nil
    local best_record = nil
    local best_due_tick = math.huge

    for key, record in pairs(state.dormant_chunks) do
        if not state.active[key] and not get_chunk_cooldown_until_tick(state, key, current_tick) then
            local surface = game.surfaces[record.surface_index]
            if model.is_vulcanus_surface(surface) then
                local due_tick = record.due_tick or math.huge
                if due_tick < best_due_tick then
                    best_key = key
                    best_record = record
                    best_due_tick = due_tick
                end
            end
        end
    end

    return best_key, best_record
end

local function handle_failed_keepalive_spawn(state, key, surface, record, reason, salt, current_tick)
    if reason == "invalid-tile" or reason == "auric-spacing" or reason == "sulfuric-spacing" or reason == "spacing" or reason == "blocked" or reason == "occupied" or reason == "placement" or reason == "cooldown" then
        schedule_dormant_chunk(state, surface, record.chunk_x, record.chunk_y, DORMANT_BLOCKED_DELAY, salt, current_tick)
    else
        clear_dormant_chunk(state, key)
    end
end

local function process_keepalive_spawn(state, current_tick)
    current_tick = resolve_tick(current_tick)
    refresh_zero_active_since_tick(state, current_tick)
    if next(state.active) ~= nil then
        return
    end

    local zero_active_since_tick = state.zero_active_since_tick
    if not zero_active_since_tick or (current_tick - zero_active_since_tick) < KEEPALIVE_GRACE_TICKS then
        return
    end

    for attempt = 1, KEEPALIVE_ATTEMPTS_PER_PULSE do
        local key, record = find_keepalive_candidate(state, current_tick)
        if not key or not record then
            return
        end

        local surface = game.surfaces[record.surface_index]
        if not model.is_vulcanus_surface(surface) then
            clear_dormant_chunk(state, key)
        else
            local spawned, reason = attempt_spawn_fumarole(surface, record.chunk_x, record.chunk_y, "dormant", current_tick)
            if spawned then
                return
            end

            handle_failed_keepalive_spawn(state, key, surface, record, reason, 5600 + attempt, current_tick)
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
            if not entity or not entity.valid then
                finalize_closure(state, record, "missing", current_tick)
            else
                if not record.touched and entity.amount < (record.initial_amount or entity.amount) then
                    record.touched = true
                end

                if not record.touched and current_tick >= (record.untouched_deadline_tick or 0) then
                    finalize_closure(state, record, "self-seal", current_tick)
                end
            end
        end
    end

    refresh_zero_active_since_tick(state, current_tick)
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
    local queued = 0
    for chunk in surface.get_chunks() do
        local key = chunk_key(surface.index, chunk.x, chunk.y)
        if force_refresh or not state.processed_chunks[key] then
            queue_push(state.backfill_queue, {
                surface_index = surface.index,
                chunk_x = chunk.x,
                chunk_y = chunk.y,
            })
            queued = queued + 1
        end
    end

    return queued
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

local function bootstrap_generated_chunks(force_refresh)
    local state = get_state()
    if not force_refresh and state.backfill_bootstrapped then
        return 0
    end

    local found_vulcanus = false
    for _, surface in pairs(game.surfaces) do
        if model.is_vulcanus_surface(surface) then
            found_vulcanus = true
            break
        end
    end

    if not found_vulcanus then
        return 0
    end

    local queued = enqueue_all_vulcanus_backfill(force_refresh)
    state.backfill_bootstrapped = true
    return queued
end

function model.on_init(_event)
    model.check_global()
    bootstrap_generated_chunks(false)
end

function model.on_configuration_changed(event)
    model.check_global()
    if next(event.mod_changes or {}) ~= nil then
        bootstrap_generated_chunks(true)
    end
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
    local chunk_x = math.floor(entity.position.x / 32)
    local chunk_y = math.floor(entity.position.y / 32)
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

function model.updater(event)
    if not get_state().backfill_bootstrapped then
        bootstrap_generated_chunks(false)
    end

    local current_tick = event and event.tick
    if event.tick % BACKFILL_PROCESS_TICKS == 0 then
        process_backfill_queue(current_tick)
    end

    if event.tick % DORMANT_PULSE_TICKS == 0 then
        process_dormant_scheduler(current_tick)
    end

    if event.tick % ACTIVE_AUDIT_TICKS == 0 then
        audit_active_fumaroles(current_tick)
    end
end

function model.get_runtime_status()
    model.check_global()

    local state = get_state()
    local ready_surface_queue_items = 0
    for _, queue in pairs(state.dormant_surface_queues or {}) do
        ready_surface_queue_items = ready_surface_queue_items + ei_runtime_scheduler.queue_item_count(queue)
    end

    local status = {
        processed_chunk_count = ei_runtime_scheduler.table_count(state.processed_chunks),
        history_chunk_count = ei_runtime_scheduler.table_count(state.history_chunks),
        cooldown_chunk_count = ei_runtime_scheduler.table_count(state.cooldown_chunks),
        backfill_queue = ei_runtime_scheduler.audit_queue(state.backfill_queue),
        active_fumarole_count = ei_runtime_scheduler.table_count(state.active),
        active_bucket_surface_count = ei_runtime_scheduler.table_count(state.active_chunk_buckets),
        dormant_chunk_count = ei_runtime_scheduler.table_count(state.dormant_chunks),
        dormant_bucket_count = ei_runtime_scheduler.delayed_bucket_count(state.dormant_delayed_buckets),
        dormant_item_count = ei_runtime_scheduler.delayed_item_count(state.dormant_delayed_buckets),
        dormant_active_surface_count = #(state.dormant_active_surfaces or {}),
        ready_surface_queue_items = ready_surface_queue_items,
        zero_active_since_tick = state.zero_active_since_tick,
        sound_proxy_count = ei_runtime_scheduler.table_count(state.sound_proxies),
        active = ei_runtime_scheduler.table_count(state.active),
        dormant_chunks = ei_runtime_scheduler.table_count(state.dormant_chunks),
        dormant_buckets = ei_runtime_scheduler.delayed_bucket_count(state.dormant_delayed_buckets),
        dormant_bucket_items = ei_runtime_scheduler.delayed_item_count(state.dormant_delayed_buckets),
        active_surfaces = #(state.dormant_active_surfaces or {}),
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
    "ei-auric-fumarole-rescan",
    "Rebuilds Vulcanus auric fumarole backfill state for generated chunks on Vulcanus.",
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

            enqueue_backfill_surface(player.surface, true)
            print_command_feedback(command, {"description.auric-fumarole-rescan-success"})
            return
        end

        for _, surface in pairs(game.surfaces) do
            if model.is_vulcanus_surface(surface) then
                enqueue_backfill_surface(surface, true)
            end
        end
        print_command_feedback(command, {"description.auric-fumarole-rescan-success"})
    end
)

return model
