--==============================================================================
-- ESIR FILE MAP
-- owns: ANISETRON native movement recovery under compounded hostile slows
-- loaded_by: scripts/control/anisetron.lua
-- cadence: exact lifecycle registry; four-tick native modifier checks via shared scheduler
-- forwarded_events: on_entity_damaged, on_built_entity, on_destroyed_entity, on_teleported, has_tick_work, update, rebuild
-- storage_roots: storage.ei.runtime_scheduler.modules.anisetron.mobility
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: initialization/configuration; serialized cohorts resume on load
--==============================================================================
-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#mobility
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("lib/anisetron-mobility-config")
local module = {}
local owned_names = {}
for _, name in ipairs(config.names) do owned_names[name] = true end

---@class AnisetronMobilityRecord
---@field entity LuaEntity
---@field next_tick integer?
---@field compensator LuaEntity?
---@field tier integer?
---@field factor number?
---@field raw_modifier number?

---@class AnisetronMobilityState
---@field tracked table<integer, AnisetronMobilityRecord>
---@field due table<integer, integer[]>
---@field count integer
---@field next_tick integer|false|nil

---@return AnisetronMobilityState?
local function raw_state()
    local root = storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    return root and root.mobility
end

---@return AnisetronMobilityState
local function state()
    local root = scheduler.ensure_module_state("anisetron")
    root.mobility = root.mobility or {tracked = {}, due = {}, count = 0}
    return root.mobility
end

---@param record AnisetronMobilityRecord
local function clear_compensation(record)
    local handle = lib.get_valid_entity(record.compensator)
    if handle then handle.destroy() end
    record.compensator, record.tier, record.factor = nil, nil, nil
end

---@param runtime AnisetronMobilityState
---@param id integer
---@param record AnisetronMobilityRecord
local function retire(runtime, id, record)
    clear_compensation(record)
    runtime.tracked[id] = nil
    runtime.count = runtime.count - 1
    if runtime.count == 0 then runtime.due, runtime.next_tick = {}, nil end
end

---@param runtime AnisetronMobilityState
---@param id integer
---@param record AnisetronMobilityRecord
---@param due_tick integer
local function schedule(runtime, id, record, due_tick)
    if record.next_tick and record.next_tick <= due_tick then return end
    record.next_tick = due_tick
    scheduler.delayed_schedule(runtime.due, due_tick, id)
    runtime.next_tick = math.min(runtime.next_tick or due_tick, due_tick)
end

---@param entity LuaEntity?
---@param tick integer
local function admit(entity, tick)
    local source = lib.get_valid_entity(entity)
    if not source or source.name ~= config.vehicle then return end
    local runtime = raw_state() or state()
    local id = source.unit_number
    local record = runtime.tracked[id]
    if not record then
        record = {entity = source}
        runtime.tracked[id], runtime.count = record, runtime.count + 1
    end
    -- Native hit actions can attach their sticker after the damage callback.
    schedule(runtime, id, record, tick + 1)
end

---@param event EventData.on_entity_damaged
function module.on_entity_damaged(event) admit(event.entity, event.tick) end

---@param event table
function module.on_built_entity(event)
    admit(event.destination or event.entity or event.created_entity, event.tick)
end

---@param event EventData.script_raised_teleported
function module.on_teleported(event)
    -- A native teleport retains native hostile stickers. Entity targets carry
    -- the compensator as well; the scheduled service validates the new source.
    admit(event.entity, event.tick)
end

---@param event table
function module.on_destroyed_entity(event)
    local runtime = raw_state()
    local id = lib.get_entity_unit_number(event.entity)
    local record = runtime and id and runtime.tracked[id]
    if record then retire(runtime, id, record) end
end

---@param runtime AnisetronMobilityState
---@param id integer
---@param record AnisetronMobilityRecord
---@param tick integer
local function service(runtime, id, record, tick)
    local source = lib.get_valid_entity(record.entity)
    if not source or source.name ~= config.vehicle then retire(runtime, id, record); return end
    local handle = lib.get_valid_entity(record.compensator)
    local modifiers = source.sticker_vehicle_modifiers
    local raw = (modifiers and modifiers.speed_modifier or 1) / (handle and record.factor or 1)
    record.raw_modifier = raw
    -- Sticker attachment has no native event and need not deal damage. Retain
    -- the exact lifecycle registry even while healthy; polling a known source
    -- catches non-damaging slows without any recurring surface discovery.
    -- Removing only our multiplier restores the original native speed exactly.
    local tier = 0
    if raw > 0 and raw < config.minimum_modifier then
        tier = math.min(config.tiers, math.ceil(math.log(config.minimum_modifier / raw)
            / math.log(config.multiplier_step)))
    end
    if handle and record.tier ~= tier then clear_compensation(record); handle = nil end
    if tier > 0 then
        if not handle then
            handle = source.surface.create_entity{name = config.names[tier], position = source.position,
                target = source, force = source.force}
        end
        if handle then
            handle.time_to_live = config.safety_lifetime
            record.compensator, record.tier, record.factor = handle, tier, config.factors[tier]
        end
    else clear_compensation(record) end
    schedule(runtime, id, record, tick + config.service_interval)
end

---@param tick integer
---@return boolean
function module.has_tick_work(tick)
    local runtime = raw_state()
    return runtime ~= nil and runtime.count > 0 and runtime.next_tick ~= nil
        and runtime.next_tick ~= false and runtime.next_tick <= tick
end

---@param tick integer
function module.update(tick)
    local runtime = raw_state()
    -- Constant-time empty registry; no world scans or visual-preset dependency.
    if not runtime or runtime.count == 0 or not runtime.next_tick or tick < runtime.next_tick then return end
    -- Ordinary on-tick service already knows the exact earliest bucket. Take
    -- it directly; overdue lifecycle/QC calls retain ordered catch-up semantics.
    local due = runtime.next_tick == tick and scheduler.delayed_take_due(runtime.due, tick)
        or scheduler.delayed_take_due_through(runtime.due, tick)
    runtime.next_tick = nil
    -- One visit per due member; no artificial cap drops mechanical protection.
    for _, id in ipairs(due) do
        local record = runtime.tracked[id]
        if record and record.next_tick and record.next_tick <= tick then
            record.next_tick = nil
            service(runtime, id, record, tick)
        end
    end
    runtime.next_tick = scheduler.delayed_next_due_tick(runtime.due)
end

---@param tick integer
function module.rebuild(tick)
    local runtime = raw_state()
    if runtime then for _, record in pairs(runtime.tracked) do clear_compensation(record) end end
    runtime = state()
    runtime.tracked, runtime.due, runtime.count, runtime.next_tick = {}, {}, 0, nil
    -- Exact discovery is restricted to lifecycle rebuilds. Native hostile
    -- stickers, their source, timing, effects and damage are never modified.
    for _, surface in pairs(game.surfaces) do
        for _, source in pairs(surface.find_entities_filtered{name = config.vehicle}) do
            for _, sticker in pairs(source.stickers or {}) do
                if sticker.valid and owned_names[sticker.name] then sticker.destroy() end
            end
            admit(source, tick)
        end
    end
end

---@return table
function module.get_qc_snapshot()
    local runtime = raw_state()
    local result = {registered = runtime and runtime.count or 0, affected = 0, next_tick = runtime and runtime.next_tick,
        minimum_modifier = config.minimum_modifier, compensated = 0, per_vehicle = {}}
    for id, record in pairs(runtime and runtime.tracked or {}) do
        if record.raw_modifier and record.raw_modifier < 1 then result.affected = result.affected + 1 end
        local handle = lib.get_valid_entity(record.compensator)
        if handle then result.compensated = result.compensated + 1 end
        result.per_vehicle[id] = {raw_modifier = record.raw_modifier, factor = handle and record.factor or 1,
            tier = handle and record.tier, next_tick = record.next_tick}
    end
    return result
end
return module
