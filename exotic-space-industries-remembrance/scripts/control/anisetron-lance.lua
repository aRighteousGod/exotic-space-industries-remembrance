--==============================================================================
-- ESIR FILE MAP
-- owns: cathedral Lance capability snapshots, live meters and committed pulses
-- loaded_by: scripts/control/anisetron.lua
-- cadence: charge/contact calls; committed delayed buckets and finite core cues
-- forwarded_events: has_tick_work, update, research, force, surface, build/removal and configuration routes
-- storage_roots: storage.ei.runtime_scheduler.modules.anisetron.lance
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: reconcile live meters and rebuild cues; preserve paid snapshots/deadlines
--==============================================================================
-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#inheritance
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("lib/anisetron-config")
local c = require("lib/singularity-lance-config")
local lance = require("scripts/control/singularity-lance")
local factory = require("lib/singularity-lance-payload")
local module = {}
local function count(runtime, key, amount) runtime.counters[key] = (runtime.counters[key] or 0) + (amount or 1) end
local function unprofiled() end
local payload = factory.new(count, unprofiled, unprofiled)
local relevant = {["ei-singularity-lance"] = true}
for _, upgrade in ipairs(c.upgrades) do relevant["ei-singularity-lance-" .. upgrade.key] = true end

---@class AnisetronLanceMemory
---@field entity LuaEntity
---@field force_index integer
---@field surface_index integer
---@field level integer
---@field counter integer Reserved prepaid pulse phase, retained between charges.
---@field context LanceWoundContext
---@field mark LuaRenderObject?
---@field band integer?

local function state()
    local root = scheduler.ensure_module_state("anisetron")
    root.lance = root.lance or {memories = {}, marks = {}, registrations = {},
        buckets = scheduler.ensure_delayed_buckets(), pending = 0, counters = {}}
    return root.lance
end
local function raw_state()
    local root = storage.ei and storage.ei.runtime_scheduler and storage.ei.runtime_scheduler.modules.anisetron
    return root and root.lance
end
local function remove(handle) if handle and handle.valid then handle.destroy() end end
local function clear_mark(record)
    remove(record.mark); record.mark, record.band = nil, nil
end
local function detach(record)
    clear_mark(record)
    record.context, record.counter = {stacks = 0}, 0
end
local function remember(runtime, source, level)
    local id = source.unit_number
    local record = runtime.memories[id]
    if not record then
        record = {entity = source, force_index = source.force.index, surface_index = source.surface.index,
            level = level, counter = 0, context = {stacks = 0}}
        runtime.memories[id] = record
        runtime.registrations[script.register_on_object_destroyed(source)] = id
    elseif record.force_index ~= source.force.index or record.surface_index ~= source.surface.index then
        detach(record)
        record.force_index, record.surface_index = source.force.index, source.surface.index
    end
    if level < record.level then
        if level < 2 then clear_mark(record); record.context = {stacks = 0} end
        if level < 4 then record.counter = 0 end
    end
    record.level = level
    return record
end

-- Coefficients, quality, research and meter reservations are paid once. Context
-- references may be detached from live memory without rewriting paid contracts.
---@param burst AnisetronBurst
---@param multiplier number Ammo quality times ANISETRON research, applied once.
function module.admit(burst, multiplier)
    local source = burst.entity
    local level = lance.get_force_snapshot(source.force).level
    local record = remember(state(), source, level)
    local axial = table.deepcopy(c.axial)
    axial.cos, axial.sin = math.cos(math.rad(axial.branch.angle)), math.sin(math.rad(axial.branch.angle))
    burst.crown_range = config.crown_range * source.quality.range_multiplier
    burst.facade_range, burst.contact_ticks = config.range, config.contact_ticks
    burst.lance = {level = level, multiplier = multiplier * config.crown_damage / c.direct_damage,
        axial = axial, context = record.context, phase = record.counter, pulse_index = 0,
        wound_step = c.wound.step, wound_cap = c.wound.cap, wound_timeout = c.wound.timeout,
        wound_first_hit_stacks = c.wound.first_hit_stacks,
        collapse = table.deepcopy(c.collapse), testament = table.deepcopy(c.testament)}
    if level >= 4 then
        record.counter = (record.counter + math.ceil(burst.duration / burst.contact_ticks)) % c.testament.interval
    end
end

---@param burst AnisetronBurst
---@return boolean
function module.pulse(burst)
    local paid = burst.lance
    if not paid then return false end
    paid.pulse_index = paid.pulse_index + 1
    local empowered = paid.level >= 4 and (paid.phase + paid.pulse_index) % paid.testament.interval == 0
    if empowered then count(state(), "testament_opportunities") end
    return empowered
end

local function animation(key, surface, position, ttl, radius, offset)
    if ttl <= 0 then return end
    return rendering.draw_animation{animation = "ei-anisetron-lance-" .. key,
        surface = surface, target = position, time_to_live = ttl,
        x_scale = radius and radius / c.presentation.collapse_reference_radius or 1,
        y_scale = radius and radius / c.presentation.collapse_reference_radius or 1,
        animation_offset = offset or 0, render_layer = "light-effect"}
end
local function warning(packet, tick)
    local surface = game.surfaces[packet.surface_index]
    if not surface or packet.due <= tick then return end
    local key = packet.phase == "echo" and "echo-warning"
        or (packet.testament and "testament-concentrated-warning" or "collapse-concentrated-warning")
    packet.warning = animation(key, surface, packet.position, packet.due - tick, packet.radius,
        math.max(0, tick - (packet.warning_start_tick or packet.committed_tick)))
end
local function schedule(runtime, packet, tick)
    scheduler.delayed_schedule(runtime.buckets, packet.due, packet)
    runtime.pending = runtime.pending + 1
    runtime.next_due = math.min(runtime.next_due or packet.due, packet.due)
    packet.committed_tick = tick
end

function module.clear_channel(channel)
    for _, beam in pairs(channel.extensions or {}) do remove(beam) end
    channel.extensions = nil
end
local function present_incisions(channel, contact, tick)
    module.clear_channel(channel)
    channel.extensions = {}
    local shape = contact.testament and "testament" or "axial"
    for index, ray in ipairs(contact.rays) do
        local origin = index == 1 and contact.position or ray.origin
        -- The crown core already draws to contact. Only draw the continuation
        -- beyond it, never an overlapping ground-origin copy through the hull.
        if index ~= 1 or ray.length > ((origin.x-contact.origin.x)^2+(origin.y-contact.origin.y)^2)^.5 then
            local beam = channel.entity.surface.create_entity{
                name = "ei-anisetron-crown-beam-" .. shape .. (index > 1 and "-branch" or "")
                    .. "-light-" .. channel.beam_light_index,
                position = origin, source = origin, target = ray.endpoint,
                force = channel.entity.force, duration = config.contact_ticks}
            channel.extensions[index] = beam
        end
    end
end

---@param burst AnisetronBurst
---@param channel AnisetronBeamState
---@param target LuaEntity
---@param tick integer
---@param empowered boolean
function module.contact(burst, channel, target, tick, empowered)
    local paid, source, runtime = burst.lance, burst.entity, state()
    local force, surface, origin = source.force, source.surface, source.position
    local record = runtime.memories[source.unit_number]
    if not record then record = remember(runtime, source, lance.get_force_snapshot(force).level) end
    local contact = {phase = "contact", due = tick, force_index = force.index, surface_index = surface.index,
        source = source, primary = target, position = channel.contact_tip,
        origin = {x = origin.x, y = origin.y}, range = burst.crown_range,
        context = paid.context, level = paid.level, multiplier = paid.multiplier,
        direct_damage = burst.crown_damage, wound_step = paid.wound_step, wound_cap = paid.wound_cap,
        wound_timeout = paid.wound_timeout, wound_first_hit_stacks = paid.wound_first_hit_stacks,
        primary_multiplier = empowered and paid.testament.primary_multiplier or 1,
        testament = empowered, axial = paid.axial,
        axial_cap = empowered and paid.testament.axial_cap or paid.axial.cap,
        branch_cap = empowered and paid.testament.branch_cap or paid.axial.branch.cap}
    -- Freeze geometry and commit every delayed packet before synchronous damage
    -- callbacks can destroy, teleport or change the source/target/research.
    contact.rays = paid.level >= 1 and payload.incision_rays(origin, contact.position, contact.range, paid.axial) or {}
    if paid.level >= 3 then
        local packet = factory.collapse_packet(contact, empowered and paid.testament or paid.collapse,
            paid.collapse.delay, empowered and paid.testament.echo or nil)
        packet.warning_start_tick = tick
        schedule(runtime, packet, tick); warning(packet, tick)
        count(runtime, "collapses_scheduled")
        if packet.echo then
            packet.echo.warning_start_tick = packet.due
            schedule(runtime, packet.echo, tick); count(runtime, "echoes_scheduled")
        end
    end
    local attribution, applied = payload.resolve_primary(runtime, contact, target, force)
    if paid.level >= 1 then
        payload.penetrate(runtime, surface, attribution, force, target, contact.rays, paid.multiplier, contact, tick)
    end
    if lib.entity_check(source) and source.surface == surface and source.force == force then
        channel.testament_until = empowered and tick + config.contact_ticks or nil
        if paid.level >= 1 then present_incisions(channel, contact, tick) end
        if applied > 0 and paid.level >= 2 and runtime.memories[source.unit_number] == record
            and record.context == paid.context and lib.entity_check(target)
            and target.surface == surface and payload.hostile(target, force) then
            paid.context.timeout = paid.wound_timeout
            local band = math.min(3, math.ceil(paid.context.stacks / 2))
            if band ~= record.band or not (record.mark and record.mark.valid) then
                clear_mark(record)
                record.mark = animation("wound-" .. band, surface, {entity = target}, paid.wound_timeout)
                record.band = band
            end
            if record.mark and record.mark.valid then record.mark.target = {entity = target}; record.mark.time_to_live = paid.wound_timeout end
            runtime.marks[source.unit_number] = record
        end
    end
    count(runtime, "contacts_applied")
end

function module.target_changed(channel, target)
    local context = channel.wound_context
    if channel.emitter ~= "crown" or not context or channel.target == target or context.target == target then return end
    context.target, context.tick, context.stacks = nil, nil, 0
    local runtime = raw_state()
    local record = runtime and runtime.memories[lib.get_entity_unit_number(channel.entity)]
    if record and record.context == context then clear_mark(record) end
end

---@param tick integer
---@return boolean
function module.has_tick_work(tick)
    local runtime = raw_state()
    if not runtime then return false end
    return next(runtime.marks) ~= nil
        or (runtime.next_due ~= nil and runtime.next_due ~= false and runtime.next_due <= tick)
end

---@param tick integer
function module.update(tick)
    local runtime = raw_state()
    if not runtime then return end
    for id, record in pairs(runtime.marks) do
        local source, target = lib.get_valid_entity(record.entity), lib.get_valid_entity(record.context.target)
        if not source or source.force.index ~= record.force_index or source.surface.index ~= record.surface_index
            or not target or not payload.hostile(target, source.force) or target.surface ~= source.surface
            or tick - (record.context.tick or 0) >= (record.context.timeout or c.wound.timeout) then
            record.context.target, record.context.tick, record.context.stacks = nil, nil, 0
            clear_mark(record); runtime.marks[id] = nil
        end
    end
    if not runtime.next_due or runtime.next_due > tick then return end
    local due = scheduler.delayed_take_due_through(runtime.buckets, tick)
    for _, packet in ipairs(due) do
        remove(packet.warning); packet.warning = nil
        runtime.pending = runtime.pending - 1
        local surface, force = game.surfaces[packet.surface_index], game.forces[packet.force_index]
        if surface and force then
            payload.area_damage(runtime, surface, force, packet.position, packet.primary, packet.source,
                packet.damage, packet.radius, packet.cap, packet)
            count(runtime, packet.phase == "echo" and "echoes_applied" or "collapses_applied")
            animation(packet.phase == "echo" and "echo-impact" or
                (packet.testament and "testament-concentrated-impact" or "collapse-concentrated-impact"),
                surface, packet.position, c.presentation.impact_ticks, packet.radius)
            if packet.echo and not packet.echo.resolved then warning(packet.echo, tick) end
        end
        packet.resolved = true
    end
    runtime.next_due = scheduler.delayed_next_due_tick(runtime.buckets)
end

function module.remove(id)
    local runtime = raw_state()
    if not runtime or not id then return end
    local record = runtime.memories[id]
    if record then clear_mark(record); runtime.memories[id], runtime.marks[id] = nil, nil end
end
function module.on_object_destroyed(event)
    local runtime = raw_state()
    local id = runtime and runtime.registrations[event.registration_number]
    if id then module.remove(id); runtime.registrations[event.registration_number] = nil end
end
function module.refresh_force(force)
    local runtime = raw_state()
    if not runtime or not force or not force.valid then return end
    local level = lance.get_force_snapshot(force).level
    for _, record in pairs(runtime.memories) do
        if record.force_index == force.index and lib.entity_check(record.entity) then remember(runtime, record.entity, level) end
    end
end
function module.on_research_finished(event)
    if event.research and relevant[event.research.name] then module.refresh_force(event.research.force) end
end
function module.on_force_reset(event) module.refresh_force(event.force) end
function module.on_diplomacy_changed()
    local runtime = raw_state()
    if not runtime then return end
    for _, record in pairs(runtime.memories) do
        if record.context.target and (not lib.entity_check(record.entity)
            or not payload.hostile(record.context.target, record.entity.force)) then
            clear_mark(record)
            record.context.target, record.context.tick, record.context.stacks = nil, nil, 0
        end
    end
end
function module.on_forces_merged(event)
    local runtime = raw_state()
    if runtime then
        for id, record in pairs(runtime.memories) do if record.force_index == event.source_index then module.remove(id) end end
        for _, bucket in pairs(runtime.buckets) do
            for _, packet in ipairs(bucket) do
                if packet.force_index == event.source_index then packet.force_index = event.destination.index end
            end
        end
    end
    module.refresh_force(event.destination)
end
function module.on_surface_deleted(event)
    local runtime = raw_state()
    if not runtime then return end
    for id, record in pairs(runtime.memories) do if record.surface_index == event.surface_index then module.remove(id) end end
    local rebuilt = scheduler.ensure_delayed_buckets()
    for _, packet in ipairs(scheduler.delayed_take_due_through(runtime.buckets, math.huge)) do
        if packet.surface_index == event.surface_index then remove(packet.warning); runtime.pending = runtime.pending - 1
        else scheduler.delayed_schedule(rebuilt, packet.due, packet) end
    end
    runtime.buckets = rebuilt; runtime.next_due = scheduler.delayed_next_due_tick(rebuilt)
end
function module.rebuild(tick)
    local runtime = raw_state()
    if not runtime then return end
    for _, record in pairs(runtime.memories) do clear_mark(record) end
    runtime.marks = {}
    for _, force in pairs(game.forces) do module.refresh_force(force) end
    for id, record in pairs(runtime.memories) do
        local source, target = lib.get_valid_entity(record.entity), lib.get_valid_entity(record.context.target)
        local ttl = (record.context.timeout or c.wound.timeout) - (tick - (record.context.tick or 0))
        if source and target and source.surface == target.surface and payload.hostile(target, source.force)
            and record.context.stacks > 0 and ttl > 0 then
            record.band = math.min(3, math.ceil(record.context.stacks / 2))
            record.mark = animation("wound-" .. record.band, source.surface, {entity = target}, ttl)
            runtime.marks[id] = record
        end
    end
    -- Handles are derived; retained packets keep their original deadlines.
    for _, bucket in pairs(runtime.buckets) do
        for _, packet in ipairs(bucket) do
            remove(packet.warning); packet.warning = nil
            if packet.phase ~= "echo" or tick >= (packet.warning_start_tick or packet.due - (c.testament.echo.delay - c.collapse.delay)) then warning(packet, tick) end
        end
    end
end
function module.snapshot()
    local runtime = raw_state()
    return runtime and {pending = runtime.pending, counters = table.deepcopy(runtime.counters), memories = scheduler.table_count(runtime.memories)} or {}
end
return module
