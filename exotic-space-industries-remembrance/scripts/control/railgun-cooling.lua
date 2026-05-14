--==============================================================================
-- ESIR FILE MAP
-- owns: railgun fluoroketone cooling runtime, hidden coolant proxies, recovery queue,
--       hot-shot visuals, turret status, and railgun relative GUI
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy/rotate/script-trigger, scheduled tick step 11, and GUI hooks
-- forwarded_events: check_global, get_pending_work_count, get_runtime_status, get_qc_snapshot,
--                   on_built_entity, on_destroyed_entity, on_gui_click, on_object_destroyed,
--                   on_player_left_game, on_player_rotated_entity, on_script_trigger_effect,
--                   on_space_platform_changed_state, rebuild_runtime_state, update
-- storage_roots: storage.ei.railgun_cooling
-- gui_ids: ei-railgun-cooling-console
-- remote_interfaces: none; Informatron is called outward from the relative GUI shortcut
-- rebuild_on: configuration change, railgun build/destroy/rotation, platform state changes
--==============================================================================

local model = {}

local ei_lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")

--====================================================================================================
--CONSTANTS
--====================================================================================================

local MODULE_NAME = "railgun-cooling"
local GUI_NAME = "ei-railgun-cooling-console"
local RAILGUN_NAME = "railgun-turret"
local PROXY_NAME = "ei-railgun-cooling-proxy"
local DIAGONAL_PROXY_NAMES = {
    [defines.direction.northwest] = PROXY_NAME .. "-nw",
    [defines.direction.northeast] = PROXY_NAME .. "-ne",
    [defines.direction.southwest] = PROXY_NAME .. "-sw",
    [defines.direction.southeast] = PROXY_NAME .. "-se",
}
local ALL_PROXY_NAMES = {PROXY_NAME}
for _, proxy_name in pairs(DIAGONAL_PROXY_NAMES) do
    ALL_PROXY_NAMES[#ALL_PROXY_NAMES + 1] = proxy_name
end
local SHOT_EFFECT_ID = "ei-railgun-cooling-shot"
local COLD_FLUID = "fluoroketone-cold"
local HOT_FLUID = "fluoroketone-hot"
local COLD_TEMPERATURE = -150
local HOT_TEMPERATURE = 180
local COOLANT_PER_SHOT = 10
local BUFFER_SHOTS = 3
local BUFFER_CAPACITY = COOLANT_PER_SHOT * BUFFER_SHOTS
local MAX_HEAT_DEBT = 40
local PASSIVE_DELAY_TICKS = 300
local RECOVERY_INTERVAL_TICKS = 60
local SHOT_TRIGGER_DEBOUNCE_TICKS = 5
local SHORTFALL_TOLERANCE = 0.05
local RUNTIME_VERSION = 1
local STATUS_YELLOW = defines.entity_status_diode and defines.entity_status_diode.yellow or 2
local STATUS_RED = defines.entity_status_diode and defines.entity_status_diode.red or 3
local GLOW_SPRITE = "emt_charger_glow"
local HEAT_ANIMATION = "ei-overload-animation"

local SURFACE_PROFILES = {
    platform_vacuum = {passive_bleed = 0.08, steam_scale = 0.25, heat_wave_scale = 1.4, afterglow_ticks = 360},
    aquilo = {passive_bleed = 0.35, steam_scale = 1.25, heat_wave_scale = 0.8, afterglow_ticks = 120},
    vulcanus = {passive_bleed = 0.15, steam_scale = 0.55, heat_wave_scale = 1.35, afterglow_ticks = 300},
    default_atmospheric = {passive_bleed = 0.25, steam_scale = 1.0, heat_wave_scale = 1.0, afterglow_ticks = 180},
    default_thin_or_no_pollution = {passive_bleed = 0.18, steam_scale = 0.6, heat_wave_scale = 1.15, afterglow_ticks = 240},
}

local PROXY_OFFSETS = {
    [defines.direction.north] = {x = 0, y = 1},
    [defines.direction.northeast] = {x = -1, y = 1},
    [defines.direction.east] = {x = -1, y = 0},
    [defines.direction.southeast] = {x = -1, y = -1},
    [defines.direction.south] = {x = 0, y = -1},
    [defines.direction.southwest] = {x = 1, y = -1},
    [defines.direction.west] = {x = 1, y = 0},
    [defines.direction.northwest] = {x = 1, y = 1},
}

--====================================================================================================
--GENERAL HELPERS
--====================================================================================================

local function now_tick(event_or_tick)
    if type(event_or_tick) == "number" then
        return event_or_tick
    end
    return ei_lib.get_event_tick(event_or_tick) or (game and game.tick) or 0
end

local function destroy_render_object(render_object)
    if render_object and render_object.valid then
        render_object.destroy()
    end
end

local function round_amount(value)
    return math.floor(((tonumber(value) or 0) * 10) + 0.5) / 10
end

local function get_shot_shortfall(cooled_amount)
    local shortfall = COOLANT_PER_SHOT - (tonumber(cooled_amount) or 0)
    if shortfall <= SHORTFALL_TOLERANCE then
        return 0
    end
    return shortfall
end

local function ticks_to_seconds(value)
    return round_amount((tonumber(value) or 0) / 60)
end

--====================================================================================================
--RUNTIME STORAGE
--====================================================================================================

local function build_runtime()
    return {
        version = RUNTIME_VERSION,
        turrets_by_unit = {},
        registrations = {},
        units_by_surface = {},
        open_by_player = {},
        recovery_queue = scheduler.ensure_queue(nil),
        recovery_buckets = scheduler.ensure_delayed_buckets(nil),
        recovery_pending_by_unit = {},
        next_due_tick = 0,
        hot_visuals = {},
        surface_profiles = {},
    }
end

local function get_runtime()
    storage.ei = storage.ei or {}
    local runtime = storage.ei.railgun_cooling
    if type(runtime) ~= "table" or runtime.version ~= RUNTIME_VERSION then
        runtime = build_runtime()
        storage.ei.railgun_cooling = runtime
    end
    runtime.turrets_by_unit = type(runtime.turrets_by_unit) == "table" and runtime.turrets_by_unit or {}
    runtime.registrations = type(runtime.registrations) == "table" and runtime.registrations or {}
    runtime.units_by_surface = type(runtime.units_by_surface) == "table" and runtime.units_by_surface or {}
    runtime.open_by_player = type(runtime.open_by_player) == "table" and runtime.open_by_player or {}
    runtime.recovery_queue = scheduler.ensure_queue(runtime.recovery_queue)
    runtime.recovery_buckets = scheduler.ensure_delayed_buckets(runtime.recovery_buckets)
    runtime.recovery_pending_by_unit = type(runtime.recovery_pending_by_unit) == "table" and runtime.recovery_pending_by_unit or {}
    runtime.hot_visuals = type(runtime.hot_visuals) == "table" and runtime.hot_visuals or {}
    runtime.surface_profiles = type(runtime.surface_profiles) == "table" and runtime.surface_profiles or {}
    runtime.next_due_tick = tonumber(runtime.next_due_tick) or 0
    return runtime
end

--====================================================================================================
--GUI AND ENTITY LOOKUPS
--====================================================================================================

local function get_gui_root(player)
    local root = player and player.valid and player.gui and player.gui.relative and player.gui.relative[GUI_NAME] or nil
    return root and root.valid and root or nil
end

local function get_opened_railgun(player)
    local opened = ei_lib.get_valid_entity(player and player.opened)
    if opened and opened.name == RAILGUN_NAME then
        return opened
    end
    return nil
end

local function add_surface_membership(runtime, surface_index, unit_number)
    if not (surface_index and unit_number) then
        return
    end
    runtime.units_by_surface[surface_index] = runtime.units_by_surface[surface_index] or {}
    runtime.units_by_surface[surface_index][unit_number] = true
end

local function remove_surface_membership(runtime, surface_index, unit_number)
    local bucket = surface_index and runtime.units_by_surface[surface_index] or nil
    if not bucket then
        return
    end
    bucket[unit_number] = nil
    if next(bucket) == nil then
        runtime.units_by_surface[surface_index] = nil
    end
end

--====================================================================================================
--PROXY GEOMETRY AND SURFACE PROFILES
--====================================================================================================

local function register_destroy(runtime, entity, kind, unit_number)
    if not ei_lib.entity_check(entity) then
        return nil
    end
    local registration = script.register_on_object_destroyed(entity)
    runtime.registrations[registration] = {kind = kind, unit_number = unit_number}
    return registration
end

local function unregister_destroy(runtime, registration)
    if registration then
        runtime.registrations[registration] = nil
    end
end

local function normalize_proxy_direction(direction)
    if direction == defines.direction.east or direction == defines.direction.west then
        return direction
    end
    if direction == defines.direction.northeast or direction == defines.direction.northwest then
        return defines.direction.north
    end
    if direction == defines.direction.southeast or direction == defines.direction.southwest then
        return defines.direction.south
    end
    return direction or defines.direction.north
end

local function get_proxy_offset(direction)
    return PROXY_OFFSETS[direction or defines.direction.north] or PROXY_OFFSETS[defines.direction.north]
end

local function get_proxy_name(direction)
    return DIAGONAL_PROXY_NAMES[direction] or PROXY_NAME
end

local function get_proxy_position(entity)
    local offset = get_proxy_offset(entity and entity.direction)
    return {x = entity.position.x + offset.x, y = entity.position.y + offset.y}
end

local function get_surface_pollutant_type(surface)
    local ok, pollutant_type = pcall(function() return surface and surface.pollutant_type end)
    return ok and pollutant_type or nil
end

local function get_surface_profile(runtime, surface)
    -- Thermal profiles are cached per surface and invalidated by lifecycle/platform events instead of polling.
    if not (surface and surface.valid) then
        return "default_atmospheric", SURFACE_PROFILES.default_atmospheric
    end
    local cache = runtime.surface_profiles[surface.index]
    if cache and cache.surface_name == surface.name and cache.platform == (surface.platform ~= nil) then
        return cache.key, cache.profile
    end
    local lower_name = string.lower(surface.name or "")
    local key = "default_thin_or_no_pollution"
    if surface.platform then
        key = "platform_vacuum"
    elseif string.find(lower_name, "aquilo", 1, true) then
        key = "aquilo"
    elseif string.find(lower_name, "vulcanus", 1, true) then
        key = "vulcanus"
    elseif get_surface_pollutant_type(surface) ~= nil then
        key = "default_atmospheric"
    end
    runtime.surface_profiles[surface.index] = {key = key, profile = SURFACE_PROFILES[key], surface_name = surface.name, platform = surface.platform ~= nil}
    return key, SURFACE_PROFILES[key]
end

--====================================================================================================
--COOLANT ACCOUNTING
--====================================================================================================

local function get_fluidbox_contents(proxy, index)
    local ok, contents = pcall(function() return proxy and proxy.valid and proxy.fluidbox[index] or nil end)
    return ok and contents or nil
end

local function get_fluid_amount(proxy, index, fluid_name)
    local contents = get_fluidbox_contents(proxy, index)
    if contents and contents.name == fluid_name then
        return tonumber(contents.amount) or 0
    end
    return 0
end

local function get_fluid_capacity(proxy, index)
    local ok, capacity = pcall(function()
        return proxy and proxy.valid and proxy.fluidbox.get_capacity(index) or nil
    end)
    capacity = ok and tonumber(capacity) or nil
    if capacity and capacity > 0 then
        return capacity
    end
    local contents = get_fluidbox_contents(proxy, index)
    local amount = contents and tonumber(contents.amount) or 0
    return math.max(BUFFER_CAPACITY, amount)
end

local function get_hot_capacity(proxy)
    local capacity = get_fluid_capacity(proxy, 2)
    local contents = get_fluidbox_contents(proxy, 2)
    if not contents then
        return capacity
    end
    if contents.name ~= HOT_FLUID then
        return 0
    end
    return math.max(0, capacity - (tonumber(contents.amount) or 0))
end

local function set_fluid_amount(proxy, index, fluid_name, amount, temperature)
    if not (proxy and proxy.valid) then
        return
    end
    amount = tonumber(amount) or 0
    if amount <= 0.0001 then
        proxy.fluidbox[index] = nil
    else
        proxy.fluidbox[index] = {name = fluid_name, amount = amount, temperature = temperature}
    end
end

local function move_coolant(proxy, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then
        return 0
    end
    local cold_amount = get_fluid_amount(proxy, 1, COLD_FLUID)
    local hot_amount = get_fluid_amount(proxy, 2, HOT_FLUID)
    local hot_capacity = get_fluid_capacity(proxy, 2)
    local moved = math.min(amount, cold_amount, math.max(0, hot_capacity - hot_amount))
    if moved <= 0 then
        return 0
    end
    set_fluid_amount(proxy, 1, COLD_FLUID, cold_amount - moved, COLD_TEMPERATURE)
    set_fluid_amount(proxy, 2, HOT_FLUID, hot_amount + moved, HOT_TEMPERATURE)
    return moved
end

local function sanitize_proxy_buffers(proxy)
    -- Prototype changes or old saves can leave helper boxes over capacity; trim only the proxy buffers.
    if not (proxy and proxy.valid) then
        return
    end

    local cold_capacity = get_fluid_capacity(proxy, 1)
    local cold_contents = get_fluidbox_contents(proxy, 1)
    local cold_amount = cold_contents and tonumber(cold_contents.amount) or 0
    if cold_contents and cold_contents.name == COLD_FLUID and cold_amount > cold_capacity + 0.001 then
        set_fluid_amount(proxy, 1, COLD_FLUID, cold_capacity, cold_contents.temperature or COLD_TEMPERATURE)
    end

    local hot_capacity = get_fluid_capacity(proxy, 2)
    local hot_contents = get_fluidbox_contents(proxy, 2)
    local hot_amount = hot_contents and tonumber(hot_contents.amount) or 0
    if hot_contents and hot_contents.name == HOT_FLUID and hot_amount > hot_capacity + 0.001 then
        set_fluid_amount(proxy, 2, HOT_FLUID, hot_capacity, hot_contents.temperature or HOT_TEMPERATURE)
    end
end

--====================================================================================================
--STATUS AND RECOVERY QUEUES
--====================================================================================================

local function clear_visuals(record)
    destroy_render_object(record.afterglow_render)
    destroy_render_object(record.vent_render)
    destroy_render_object(record.muzzle_render)
    record.afterglow_render = nil
    record.vent_render = nil
    record.muzzle_render = nil
    record.hot_visual_until_tick = 0
end

local function prune_hot_visuals(runtime, current_tick)
    local count = 0
    for unit_number, expires_tick in pairs(runtime.hot_visuals) do
        if tonumber(expires_tick) and expires_tick > current_tick then
            count = count + 1
        else
            runtime.hot_visuals[unit_number] = nil
            local record = runtime.turrets_by_unit[unit_number]
            if record then
                record.hot_visual_until_tick = 0
            end
        end
    end
    return count
end

local function set_entity_disabled(entity, disabled)
    if ei_lib.entity_check(entity) then
        pcall(function() entity.disabled_by_script = disabled == true end)
    end
end

local function set_custom_status(entity, diode, label)
    if not ei_lib.entity_check(entity) then
        return
    end
    entity.custom_status = diode and label and {diode = diode, label = label} or nil
end

local function apply_status(record, current_tick)
    local turret = record.turret
    if not ei_lib.entity_check(turret) then
        return
    end
    if record.proxy_missing then
        set_custom_status(turret, STATUS_RED, {"exotic-industries.railgun-cooling-status-proxy-missing"})
    elseif record.blocked_reason == "overheated" and record.disabled_by_railgun_cooling then
        set_custom_status(turret, STATUS_RED, {"exotic-industries.railgun-cooling-status-overheated"})
    elseif record.blocked_reason == "output-blocked" and record.disabled_by_railgun_cooling then
        set_custom_status(turret, STATUS_YELLOW, {"exotic-industries.railgun-cooling-status-output-blocked"})
    elseif record.disabled_by_railgun_cooling or (record.heat_debt or 0) > 0.001 then
        set_custom_status(turret, STATUS_YELLOW, {"exotic-industries.railgun-cooling-status-recovering"})
    else
        set_custom_status(turret, nil, nil)
    end
end

local function schedule_recovery(runtime, unit_number, due_tick)
    due_tick = math.max(1, math.floor(tonumber(due_tick) or 0))
    local existing = tonumber(runtime.recovery_pending_by_unit[unit_number]) or 0
    if existing > 0 and existing <= due_tick then
        return existing
    end
    runtime.recovery_pending_by_unit[unit_number] = due_tick
    scheduler.delayed_schedule(runtime.recovery_buckets, due_tick, unit_number)
    if runtime.next_due_tick == 0 or due_tick < runtime.next_due_tick then
        runtime.next_due_tick = due_tick
    end
    return due_tick
end

local function recalculate_next_due_tick(runtime)
    local next_due_tick = 0
    for bucket_tick in pairs(runtime.recovery_buckets) do
        if bucket_tick > 0 and (next_due_tick == 0 or bucket_tick < next_due_tick) then
            next_due_tick = bucket_tick
        end
    end
    runtime.next_due_tick = next_due_tick
    return next_due_tick
end

local function activate_due_recovery(runtime, current_tick)
    -- Delayed buckets only wake blocked or indebted guns; healthy railguns stay out of steady-state work.
    if runtime.next_due_tick == 0 or current_tick < runtime.next_due_tick then
        return false
    end
    local due_ticks = {}
    for bucket_tick in pairs(runtime.recovery_buckets) do
        if bucket_tick > 0 and bucket_tick <= current_tick then
            due_ticks[#due_ticks + 1] = bucket_tick
        end
    end
    table.sort(due_ticks)
    local activated = false
    for _, due_tick in ipairs(due_ticks) do
        local bucket = scheduler.delayed_take_due(runtime.recovery_buckets, due_tick)
        for _, unit_number in ipairs(bucket) do
            if runtime.recovery_pending_by_unit[unit_number] == due_tick then
                runtime.recovery_pending_by_unit[unit_number] = nil
                scheduler.queue_push_unique(runtime.recovery_queue, unit_number, unit_number)
                activated = true
            end
        end
    end
    recalculate_next_due_tick(runtime)
    return activated
end

local function refresh_record(runtime, record)
    local turret = record and record.turret
    if not ei_lib.entity_check(turret) then
        return false
    end
    local previous_surface_index = record.surface_index
    record.surface_index = turret.surface.index
    record.surface_name = turret.surface.name
    record.force_index = turret.force.index
    record.direction = turret.direction
    record.profile_key, record.profile = get_surface_profile(runtime, turret.surface)
    if previous_surface_index ~= record.surface_index then
        remove_surface_membership(runtime, previous_surface_index, record.unit_number)
        add_surface_membership(runtime, record.surface_index, record.unit_number)
    end
    return true
end

--====================================================================================================
--PROXY LIFECYCLE
--====================================================================================================

local function destroy_proxy(runtime, record)
    local proxy = record and record.proxy
    if proxy and proxy.valid then
        unregister_destroy(runtime, record.proxy_registration)
        record.proxy_registration = nil
        record.proxy = nil
        proxy.destroy()
    else
        record.proxy_registration = nil
        record.proxy = nil
    end
end

local function ensure_proxy(runtime, record)
    -- The hidden helper owns the fluid interface while the railgun remains the player-facing entity.
    local turret = record.turret
    if not refresh_record(runtime, record) then
        return false
    end
    local desired_position = get_proxy_position(turret)
    local desired_direction = normalize_proxy_direction(turret.direction)
    local desired_name = get_proxy_name(turret.direction)
    local proxy = ei_lib.get_valid_entity(record.proxy)
    if proxy
        and proxy.name == desired_name
        and proxy.surface.index == turret.surface.index
        and proxy.direction == desired_direction
        and math.abs(proxy.position.x - desired_position.x) < 0.01
        and math.abs(proxy.position.y - desired_position.y) < 0.01
    then
        sanitize_proxy_buffers(proxy)
        record.proxy_missing = false
        return true
    end
    if proxy then
        destroy_proxy(runtime, record)
    end
    proxy = turret.surface.create_entity{name = desired_name, position = desired_position, direction = desired_direction, force = turret.force, create_build_effect_smoke = false}
    if not ei_lib.entity_check(proxy) then
        record.proxy_missing = true
        return false
    end
    pcall(function() proxy.destructible = false end)
    pcall(function() proxy.operable = false end)
    pcall(function() proxy.minable = false end)
    sanitize_proxy_buffers(proxy)
    record.proxy = proxy
    record.proxy_registration = register_destroy(runtime, proxy, "proxy", record.unit_number)
    record.proxy_missing = false
    return true
end

local function update_open_guis(record, current_tick)
    local runtime = get_runtime()
    local snapshot = model.get_gui_snapshot(record, current_tick)
    for player_index, unit_number in pairs(runtime.open_by_player) do
        if unit_number == record.unit_number then
            local player = game and game.get_player(player_index) or nil
            local opened = get_opened_railgun(player)
            if opened and opened.unit_number == unit_number then
                model.update_gui(player, snapshot)
            else
                runtime.open_by_player[player_index] = nil
                local root = get_gui_root(player)
                if root then root.destroy() end
            end
        end
    end
end

local function unregister_record(runtime, unit_number, keep_proxy)
    local record = runtime.turrets_by_unit[unit_number]
    if not record then
        return
    end
    if not keep_proxy then
        destroy_proxy(runtime, record)
    end
    clear_visuals(record)
    runtime.hot_visuals[unit_number] = nil
    runtime.recovery_pending_by_unit[unit_number] = nil
    scheduler.queue_remove_value(runtime.recovery_queue, unit_number)
    unregister_destroy(runtime, record.turret_registration)
    remove_surface_membership(runtime, record.surface_index, unit_number)
    for player_index, opened_unit_number in pairs(runtime.open_by_player) do
        if opened_unit_number == unit_number then
            runtime.open_by_player[player_index] = nil
            local player = game and game.get_player(player_index) or nil
            local root = get_gui_root(player)
            if root then root.destroy() end
        end
    end
    runtime.turrets_by_unit[unit_number] = nil
end

local function register_turret(runtime, entity, current_tick)
    if not (ei_lib.entity_check(entity) and entity.name == RAILGUN_NAME) then
        return nil
    end
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return nil
    end
    local record = runtime.turrets_by_unit[unit_number]
    if not record then
        record = {unit_number = unit_number, turret = entity, heat_debt = 0, last_shot_tick = 0, last_cooling_effect_tick = -SHOT_TRIGGER_DEBOUNCE_TICKS, hot_visual_until_tick = 0}
        runtime.turrets_by_unit[unit_number] = record
        record.turret_registration = register_destroy(runtime, entity, "turret", unit_number)
    else
        record.turret = entity
        record.last_cooling_effect_tick = tonumber(record.last_cooling_effect_tick) or -SHOT_TRIGGER_DEBOUNCE_TICKS
    end
    refresh_record(runtime, record)
    ensure_proxy(runtime, record)
    apply_status(record, current_tick)
    return record
end

--====================================================================================================
--SHOT HEAT AND VISUALS
--====================================================================================================

local function apply_heat_damage(turret, shortfall)
    local max_health = nil
    local ok, entity_max_health = pcall(function() return turret.max_health end)
    if ok and tonumber(entity_max_health) and entity_max_health > 0 then
        max_health = entity_max_health
    else
        max_health = tonumber(turret.health) or 100
    end
    local damage_amount = math.ceil(math.max(max_health * 0.1 * shortfall / COOLANT_PER_SHOT, 10))
    turret.health = math.max(0.01, (tonumber(turret.health) or max_health) - damage_amount)
end

local function emit_smoke(surface, name, position, count)
    for _ = 1, count do
        surface.create_trivial_smoke{name = name, position = {x = position.x + ((math.random() - 0.5) * 0.45), y = position.y + ((math.random() - 0.5) * 0.45)}, starting_frame_deviation = math.random(0, 60)}
    end
end

local function apply_shot_visuals(runtime, record, cooled_amount, shortfall, current_tick)
    local turret = record.turret
    clear_visuals(record)
    local rear_offset = get_proxy_offset(turret.direction)
    local muzzle_position = {x = turret.position.x - (rear_offset.x * 1.4), y = turret.position.y - (rear_offset.y * 1.4)}
    local vent_position = {x = turret.position.x + (rear_offset.x * 0.95), y = turret.position.y + (rear_offset.y * 0.95)}
    local profile = record.profile or SURFACE_PROFILES.default_atmospheric
    local shortfall_ratio = shortfall / COOLANT_PER_SHOT
    local cooled_ratio = cooled_amount / COOLANT_PER_SHOT
    emit_smoke(turret.surface, "smoke", vent_position, math.max(1, math.floor(profile.steam_scale * (1 + cooled_ratio * 2))))
    if shortfall > 0 then
        emit_smoke(turret.surface, "electric-smoke", vent_position, math.max(1, math.floor(profile.steam_scale * (2 + shortfall_ratio * 2))))
    end
    record.muzzle_render = rendering.draw_light{sprite = GLOW_SPRITE, scale = 1.6 + (profile.heat_wave_scale * (0.8 + shortfall_ratio)), intensity = 0.8 + shortfall_ratio * 0.65, color = shortfall > 0 and {r = 1.0, g = 0.45, b = 0.12} or {r = 1.0, g = 0.92, b = 0.76}, target = muzzle_position, surface = turret.surface, draw_as_glow = true, blend_mode = "additive", time_to_live = 18, forces = {turret.force}}
    record.vent_render = rendering.draw_light{sprite = GLOW_SPRITE, scale = 1.2 + (profile.heat_wave_scale * (0.5 + shortfall_ratio * 0.8)), intensity = 0.55 + shortfall_ratio * 0.5, color = shortfall > 0 and {r = 0.95, g = 0.42, b = 0.18} or {r = 0.84, g = 0.94, b = 1.0}, target = vent_position, surface = turret.surface, draw_as_glow = true, blend_mode = "additive", time_to_live = 36, forces = {turret.force}}
    rendering.draw_animation{animation = HEAT_ANIMATION, target = muzzle_position, surface = turret.surface, render_layer = 139, time_to_live = shortfall > 0 and 30 or 18, forces = {turret.force}}
    record.afterglow_render = rendering.draw_light{sprite = GLOW_SPRITE, scale = 2.0 + (profile.heat_wave_scale * 0.75), intensity = shortfall > 0 and 0.95 or 0.55, color = shortfall > 0 and {r = 1.0, g = 0.36, b = 0.08} or {r = 1.0, g = 0.66, b = 0.24}, target = turret, surface = turret.surface, draw_as_glow = true, blend_mode = "additive", time_to_live = profile.afterglow_ticks, forces = {turret.force}}
    record.hot_visual_until_tick = current_tick + profile.afterglow_ticks
    runtime.hot_visuals[record.unit_number] = record.hot_visual_until_tick
end

local function apply_shot(runtime, record, current_tick)
    local turret = record.turret
    local proxy_ready = ensure_proxy(runtime, record)
    local proxy = ei_lib.get_valid_entity(record.proxy)
    local cold_available = proxy_ready and get_fluid_amount(proxy, 1, COLD_FLUID) or 0
    local hot_capacity = proxy_ready and get_hot_capacity(proxy) or 0
    local cooled_amount = math.min(COOLANT_PER_SHOT, cold_available, hot_capacity)
    local shortfall = get_shot_shortfall(cooled_amount)
    if cooled_amount > 0 then
        move_coolant(proxy, cooled_amount)
    end
    record.last_shot_tick = current_tick
    record.last_cooling_effect_tick = current_tick
    if shortfall > 0 then
        record.heat_debt = math.min(MAX_HEAT_DEBT, (record.heat_debt or 0) + shortfall)
        record.disabled_by_railgun_cooling = true
        record.blocked_reason = record.proxy_missing and "proxy-missing" or (hot_capacity <= 0.001 and "output-blocked") or "overheated"
        set_entity_disabled(turret, true)
        apply_heat_damage(turret, shortfall)
        schedule_recovery(runtime, record.unit_number, current_tick + RECOVERY_INTERVAL_TICKS)
    elseif (record.heat_debt or 0) <= 0.001 and not record.proxy_missing then
        record.disabled_by_railgun_cooling = false
        record.blocked_reason = nil
        set_entity_disabled(turret, false)
    end
    apply_shot_visuals(runtime, record, cooled_amount, shortfall, current_tick)
    apply_status(record, current_tick)
    update_open_guis(record, current_tick)
end

local function recover_record(runtime, record, current_tick)
    if not refresh_record(runtime, record) then
        unregister_record(runtime, record.unit_number)
        return false
    end
    if not ensure_proxy(runtime, record) then
        record.disabled_by_railgun_cooling = true
        record.blocked_reason = "proxy-missing"
        set_entity_disabled(record.turret, true)
        schedule_recovery(runtime, record.unit_number, current_tick + RECOVERY_INTERVAL_TICKS)
        apply_status(record, current_tick)
        update_open_guis(record, current_tick)
        return true
    end
    local proxy = record.proxy
    if (record.heat_debt or 0) > 0.001 then
        record.heat_debt = math.max(0, record.heat_debt - move_coolant(proxy, math.min(record.heat_debt, COOLANT_PER_SHOT)))
    end
    if (record.heat_debt or 0) > 0.001 and (current_tick - (record.last_shot_tick or 0)) >= PASSIVE_DELAY_TICKS then
        record.heat_debt = math.max(0, record.heat_debt - ((record.profile and record.profile.passive_bleed) or 0))
    end
    local output_blocked = get_hot_capacity(proxy) <= 0.001
    if (record.heat_debt or 0) <= 0.001 and not output_blocked then
        record.heat_debt = 0
        record.disabled_by_railgun_cooling = false
        record.blocked_reason = nil
        set_entity_disabled(record.turret, false)
    else
        record.disabled_by_railgun_cooling = true
        record.blocked_reason = output_blocked and "output-blocked" or "recovering"
        set_entity_disabled(record.turret, true)
        schedule_recovery(runtime, record.unit_number, current_tick + RECOVERY_INTERVAL_TICKS)
    end
    apply_status(record, current_tick)
    update_open_guis(record, current_tick)
    return true
end

--====================================================================================================
--RELATIVE GUI
--====================================================================================================

local function get_state_caption(record)
    if not record then
        return {"exotic-industries.railgun-cooling-gui-state-healthy"}
    end
    if record.proxy_missing then return {"exotic-industries.railgun-cooling-gui-state-proxy-missing"} end
    if record.blocked_reason == "overheated" and record.disabled_by_railgun_cooling then return {"exotic-industries.railgun-cooling-gui-state-overheated"} end
    if record.blocked_reason == "output-blocked" and record.disabled_by_railgun_cooling then return {"exotic-industries.railgun-cooling-gui-state-output-blocked"} end
    if record.disabled_by_railgun_cooling or (record.heat_debt or 0) > 0.001 then return {"exotic-industries.railgun-cooling-gui-state-recovering"} end
    return {"exotic-industries.railgun-cooling-gui-state-healthy"}
end

function model.get_gui_snapshot(record, current_tick)
    current_tick = now_tick(current_tick)
    local proxy = ei_lib.get_valid_entity(record and record.proxy)
    local ticks_since_last_shot = record and record.last_shot_tick and record.last_shot_tick > 0 and (current_tick - record.last_shot_tick) or nil
    local afterglow_ticks = math.max(0, (record and record.hot_visual_until_tick or 0) - current_tick)
    return {
        state = get_state_caption(record),
        cold_buffer = proxy and get_fluid_amount(proxy, 1, COLD_FLUID) or 0,
        hot_buffer = proxy and get_fluid_amount(proxy, 2, HOT_FLUID) or 0,
        cold_buffer_capacity = BUFFER_CAPACITY,
        hot_buffer_capacity = BUFFER_CAPACITY,
        heat_debt = record and (record.heat_debt or 0) or 0,
        profile_key = record and record.profile_key or "default_atmospheric",
        seconds_since_last_shot = ticks_since_last_shot and ticks_to_seconds(ticks_since_last_shot) or nil,
        afterglow_seconds = ticks_to_seconds(afterglow_ticks),
    }
end

function model.build_gui(player)
    local root = player.gui.relative.add{type = "frame", name = GUI_NAME, anchor = {gui = defines.relative_gui_type.turret_gui, name = RAILGUN_NAME, position = defines.relative_gui_position.right}, direction = "vertical"}
    local titlebar = root.add{type = "flow", direction = "horizontal"}
    titlebar.add{type = "label", caption = {"exotic-industries.railgun-cooling-gui-title"}, style = "frame_title"}
    titlebar.add{type = "empty-widget", style = "ei_titlebar_nondraggable_spacer", ignored_by_interaction = true}
    titlebar.add{type = "sprite-button", sprite = "virtual-signal/informatron", tooltip = {"exotic-industries.gui-open-informatron"}, style = "frame_action_button", tags = {parent_gui = GUI_NAME, action = "goto-informatron", page = "railgun_cooling"}}
    local main = root.add{type = "frame", name = "main-container", direction = "vertical", style = "inside_shallow_frame"}
    main.add{type = "frame", style = "ei_subheader_frame"}.add{type = "label", caption = {"exotic-industries.railgun-cooling-gui-status-title"}, style = "subheader_caption_label"}
    local flow = main.add{type = "flow", name = "status-flow", direction = "vertical", style = "ei_inner_content_flow"}
    flow.add{type = "label", name = "state-label", caption = ""}
    flow.add{type = "label", name = "surface-profile-label", caption = ""}
    flow.add{type = "label", name = "last-shot-label", caption = ""}
    flow.add{type = "label", name = "afterglow-label", caption = ""}
    flow.add{type = "progressbar", name = "cold-buffer-bar", style = "ei_status_progressbar_cyan"}
    flow.add{type = "progressbar", name = "hot-buffer-bar", style = "ei_status_progressbar_grey"}
    flow.add{type = "progressbar", name = "heat-debt-bar", style = "ei_status_progressbar_red"}
    return root
end

function model.update_gui(player, snapshot)
    local root = get_gui_root(player) or model.build_gui(player)
    local flow = root and root["main-container"] and root["main-container"]["status-flow"] or nil
    if not flow then
        return
    end
    local cold_capacity = math.max(1, tonumber(snapshot.cold_buffer_capacity) or BUFFER_CAPACITY)
    local hot_capacity = math.max(1, tonumber(snapshot.hot_buffer_capacity) or BUFFER_CAPACITY)
    flow["state-label"].caption = {"exotic-industries.railgun-cooling-gui-block-state", snapshot.state}
    flow["surface-profile-label"].caption = {"exotic-industries.railgun-cooling-gui-surface-profile", {"exotic-industries.railgun-cooling-profile-" .. snapshot.profile_key}}
    flow["last-shot-label"].caption = snapshot.seconds_since_last_shot and {"exotic-industries.railgun-cooling-gui-last-shot", snapshot.seconds_since_last_shot} or {"exotic-industries.railgun-cooling-gui-last-shot-never"}
    flow["afterglow-label"].caption = {"exotic-industries.railgun-cooling-gui-afterglow", snapshot.afterglow_seconds or 0}
    flow["cold-buffer-bar"].value = ei_lib.clamp((snapshot.cold_buffer or 0) / cold_capacity, 0, 1)
    flow["cold-buffer-bar"].caption = {"exotic-industries.railgun-cooling-gui-cold-buffer", round_amount(snapshot.cold_buffer or 0), round_amount(cold_capacity)}
    flow["hot-buffer-bar"].value = ei_lib.clamp((snapshot.hot_buffer or 0) / hot_capacity, 0, 1)
    flow["hot-buffer-bar"].caption = {"exotic-industries.railgun-cooling-gui-hot-buffer", round_amount(snapshot.hot_buffer or 0), round_amount(hot_capacity)}
    flow["heat-debt-bar"].value = ei_lib.clamp((snapshot.heat_debt or 0) / MAX_HEAT_DEBT, 0, 1)
    flow["heat-debt-bar"].caption = {"exotic-industries.railgun-cooling-gui-heat-debt", round_amount(snapshot.heat_debt or 0)}
end

function model.open_gui(player, entity)
    if not (player and player.valid) then return end
    local runtime = get_runtime()
    local turret = ei_lib.get_valid_entity(entity) or get_opened_railgun(player)
    if not (turret and turret.name == RAILGUN_NAME) then model.close_gui(player) return end
    local record = register_turret(runtime, turret, game and game.tick or 0)
    if not record then model.close_gui(player) return end
    local root = get_gui_root(player)
    if root then root.destroy() end
    runtime.open_by_player[player.index] = record.unit_number
    model.update_gui(player, model.get_gui_snapshot(record, game and game.tick or 0))
end

function model.close_gui(player)
    if not (player and player.valid) then return end
    get_runtime().open_by_player[player.index] = nil
    local root = get_gui_root(player)
    if root then root.destroy() end
end

function model.on_gui_click(event)
    local element = event and event.element
    if element and element.valid and element.tags and element.tags.action == "goto-informatron" then
        remote.call("informatron", "informatron_open_to_page", {player_index = event.player_index, interface = "exotic-industries-informatron", page_name = element.tags.page or "railgun_cooling"})
    end
end

function model.on_player_left_game(player_index)
    local player = game and game.get_player(player_index) or nil
    if player then model.close_gui(player) end
end

--====================================================================================================
--EVENT ENTRYPOINTS
--====================================================================================================

function model.check_global()
    return get_runtime()
end

function model.rebuild_runtime_state(reason, current_tick)
    -- Rebuilds bind visible railguns back to fresh helpers and discard orphaned coolant proxies.
    local runtime = get_runtime()
    local existing_units = {}
    for unit_number in pairs(runtime.turrets_by_unit) do
        existing_units[#existing_units + 1] = unit_number
    end
    for _, unit_number in ipairs(existing_units) do
        unregister_record(runtime, unit_number)
    end
    runtime = build_runtime()
    storage.ei.railgun_cooling = runtime
    for _, surface in pairs(game and game.surfaces or {}) do
        for _, proxy in pairs(surface.find_entities_filtered{name = ALL_PROXY_NAMES}) do
            if ei_lib.entity_check(proxy) then
                proxy.destroy()
            end
        end
        for _, entity in pairs(surface.find_entities_filtered{name = RAILGUN_NAME}) do
            register_turret(runtime, entity, current_tick or (game and game.tick) or 0)
        end
    end
    local status = model.get_runtime_status(current_tick)
    status.rebuild_reason = reason
    scheduler.set_module_status(MODULE_NAME, status)
    return runtime
end

function model.on_built_entity(event)
    local entity = event and event.entity or event
    if not (ei_lib.entity_check(entity) and entity.name == RAILGUN_NAME) then return end
    local runtime = get_runtime()
    local record = register_turret(runtime, entity, now_tick(event))
    if record and ((record.heat_debt or 0) > 0.001 or record.proxy_missing) then
        schedule_recovery(runtime, record.unit_number, now_tick(event) + RECOVERY_INTERVAL_TICKS)
    end
end

function model.on_destroyed_entity(event)
    local entity = event and event.entity or event
    if not (ei_lib.entity_check(entity) and entity.name == RAILGUN_NAME) then return end
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if unit_number then unregister_record(get_runtime(), unit_number) end
end

function model.on_player_rotated_entity(event)
    local entity = event and event.entity or nil
    if not (ei_lib.entity_check(entity) and entity.name == RAILGUN_NAME) then return end
    local runtime = get_runtime()
    local record = register_turret(runtime, entity, now_tick(event))
    if record then ensure_proxy(runtime, record); apply_status(record, now_tick(event)); update_open_guis(record, now_tick(event)) end
end

function model.on_space_platform_changed_state(event)
    if not (event and event.platform and event.platform.valid) then return end
    local hub = event.platform.hub
    local surface = hub and hub.valid and hub.surface or nil
    if not (surface and surface.valid) then return end
    local runtime = get_runtime()
    runtime.surface_profiles[surface.index] = nil
    local current_tick = now_tick(event)
    for unit_number in pairs(runtime.units_by_surface[surface.index] or {}) do
        local record = runtime.turrets_by_unit[unit_number]
        if record then refresh_record(runtime, record); apply_status(record, current_tick); update_open_guis(record, current_tick) end
    end
end

function model.on_object_destroyed(event)
    local runtime = get_runtime()
    local payload = runtime.registrations[event and event.registration_number]
    if not payload then return end
    runtime.registrations[event.registration_number] = nil
    if payload.kind == "proxy" then
        local record = runtime.turrets_by_unit[payload.unit_number]
        if not record then return end
        record.proxy = nil
        record.proxy_registration = nil
        record.proxy_missing = true
        if ei_lib.entity_check(record.turret) then ensure_proxy(runtime, record); apply_status(record, now_tick(event)); update_open_guis(record, now_tick(event)) else unregister_record(runtime, payload.unit_number, true) end
    elseif payload.kind == "turret" then
        unregister_record(runtime, payload.unit_number, true)
    end
end

function model.on_script_trigger_effect(event)
    if not (event and event.effect_id == SHOT_EFFECT_ID) then return end
    local source = ei_lib.get_valid_entity(event.source_entity)
    if not (source and source.name == RAILGUN_NAME) then return end
    local runtime = get_runtime()
    local current_tick = now_tick(event)
    local record = register_turret(runtime, source, current_tick)
    if not record then return end
    -- Script trigger effects can cluster around one firing action; debounce before charging coolant.
    local last_effect_tick = tonumber(record.last_cooling_effect_tick) or -SHOT_TRIGGER_DEBOUNCE_TICKS
    if (current_tick - last_effect_tick) <= SHOT_TRIGGER_DEBOUNCE_TICKS then
        return
    end
    apply_shot(runtime, record, current_tick)
end

--====================================================================================================
--SCHEDULER SERVICE AND TELEMETRY
--====================================================================================================

function model.get_pending_work_count(event)
    local runtime = get_runtime()
    activate_due_recovery(runtime, now_tick(event))
    return scheduler.queue_item_count(runtime.recovery_queue)
end

function model.update(event)
    local runtime = get_runtime()
    local current_tick = now_tick(event)
    activate_due_recovery(runtime, current_tick)
    local unit_number = scheduler.queue_pop_queued(runtime.recovery_queue)
    if not unit_number then return false end
    local record = runtime.turrets_by_unit[unit_number]
    if record then recover_record(runtime, record, current_tick) end
    return true
end

function model.get_runtime_status(current_tick)
    local runtime = get_runtime()
    current_tick = now_tick(current_tick)
    local tracked, blocked, recovering, missing_proxy = 0, 0, 0, 0
    local stale_units = nil
    for unit_number, record in pairs(runtime.turrets_by_unit) do
        if ei_lib.entity_check(record.turret) then
            tracked = tracked + 1
            if record.proxy_missing then missing_proxy = missing_proxy + 1 end
            if record.disabled_by_railgun_cooling or (record.heat_debt or 0) > 0.001 then blocked = blocked + 1 end
            if record.blocked_reason == "recovering" or record.blocked_reason == "output-blocked" then recovering = recovering + 1 end
        else
            stale_units = stale_units or {}
            stale_units[#stale_units + 1] = unit_number
        end
    end
    if stale_units then
        for _, unit_number in ipairs(stale_units) do
            unregister_record(runtime, unit_number)
        end
    end
    local status = {
        tracked_railguns = tracked,
        blocked_count = blocked,
        recovering_count = recovering,
        missing_proxy_count = missing_proxy,
        recovery_queue_count = scheduler.queue_item_count(runtime.recovery_queue),
        recovery_bucket_count = scheduler.delayed_bucket_count(runtime.recovery_buckets),
        recovery_bucket_items = scheduler.delayed_item_count(runtime.recovery_buckets),
        active_hot_visual_tails = prune_hot_visuals(runtime, current_tick),
        open_gui_count = scheduler.table_count(runtime.open_by_player),
    }
    scheduler.set_module_status(MODULE_NAME, status)
    return status
end

function model.get_qc_snapshot(current_tick)
    return model.get_runtime_status(current_tick)
end

return model
