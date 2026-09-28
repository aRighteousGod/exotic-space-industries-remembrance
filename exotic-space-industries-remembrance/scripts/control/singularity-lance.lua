--==============================================================================
-- ESIR FILE MAP
-- owns: paid lance transactions, force capabilities, registered lances, core cues
-- loaded_by: control.lua; Informatron reads the force snapshot
-- cadence: exact shot/lifecycle events; shared delayed buckets serviced by control
-- storage_roots: storage.ei.singularity_lance (schema 11)
-- forwarded_events: shot, build/clone, destruction, research/reset, diplomacy, force/surface lifecycle
-- gui_ids: none (native custom status; Informatron owns the page)
-- remote_interfaces: none (control.lua owns diagnostics)
-- rebuild_on: initialization and configuration change; force caches on relevant research
-- invariants: damage never follows visual budgets; no idle queries or wound sweeps
--==============================================================================
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local c = require("lib/singularity-lance-config")
local lance = {script_trigger_effect_id = "ei-singularity-lance-shot"}
local NAME, VERSION = "ei-singularity-lance", 11
local art = c.presentation
local relevant_research = {[NAME] = true, ["laser-weapons-damage-6"] = true, ["laser-weapons-damage-7"] = true}
for _, upgrade in ipairs(c.upgrades) do relevant_research[NAME .. "-" .. upgrade.key] = true end

---@class LanceCapabilities
---@field level integer
---@field multiplier number
---@field direct_damage number
---@field direct_sustained_dps number
---@field direct_burst_dps number
---@field laser_damage_multiplier number Compatibility diagnostic alias for multiplier.
---@field ammo_category string
---@class LanceRecord
---@field entity LuaEntity
---@field force_index integer
---@field surface_index integer
---@field counter integer Paid-shot meter, independent of victims.
---@field stacks integer
---@field target LuaEntity?
---@field wound_tick integer?
---@field mark LuaRenderObject?
---@field beam LuaEntity|LuaRenderObject? Old Sprite handle until presentation migration.
---@field effective_range number? Immutable prototype/quality value; refreshed on configuration change.
---@field wound_band integer?
---@field beam_shape string?
---@field beam_origin MapPosition?
---@field beam_endpoint MapPosition?
---@field testament_hold_until integer?
---@field last_decoration_tick integer?
---@class LanceCollapse
---@field force_index integer
---@field surface_index integer
---@field position MapPosition
---@field primary LuaEntity?
---@field source LuaEntity?
---@field damage number
---@field radius number
---@field cap integer
---@field testament boolean
---@field warning LuaRenderObject?
---@class LanceRuntime
---@field version integer
---@field presentation_revision integer?
---@field lances table<integer,LanceRecord>
---@field registrations table<integer,integer>
---@field force_cache table<integer,LanceCapabilities>
---@field buckets table<integer,LanceCollapse[]>
---@field pending integer
---@field next_due integer?
---@field counters table<string,number>
---@field visual_config table Resolved startup presentation preset; never controls damage.
---@field qc_enabled boolean
---@field profiling_enabled boolean
---@field decoration_tick integer?
---@field decorations integer?

local function destroy_cue(object)
    if object and object.valid then object.destroy() end
end

local function reset_wound(record)
    destroy_cue(record.mark)
    record.mark, record.target, record.wound_tick, record.stacks, record.wound_band = nil, nil, nil, 0, nil
end

local function count(runtime, key, amount)
    if runtime.qc_enabled then runtime.counters[key] = (runtime.counters[key] or 0) + (amount or 1) end
end

local function profile_start(runtime)
    return runtime.profiling_enabled and game.create_profiler() or nil
end

-- Transient QC timers never enter storage or affect mechanical decisions. Emit
-- once per phase/tick, outside measured callbacks, rather than once per victim/shot.
local profile_tick, phase_profiles
local function profile_flush(tick)
    if phase_profiles and profile_tick ~= tick then
        for _, phase in ipairs({"shot-core", "shot", "mechanics", "impact-core", "decoration", "update-total"}) do
            local profiler = phase_profiles[phase]
            if profiler then log({"", "SINGULARITY_LANCE_PHASE phase=", phase, " tick=", profile_tick, " elapsed=", profiler}) end
        end
        phase_profiles, profile_tick = nil, nil
    end
end

local function profile_end(profiler, phase, tick)
    if profiler then
        profiler.stop()
        phase_profiles, profile_tick = phase_profiles or {}, tick
        if phase_profiles[phase] then phase_profiles[phase].add(profiler) else phase_profiles[phase] = profiler end
    end
end

-- Diplomacy is read at every packet, never cached across ticks.
---@param entity LuaEntity? Engine query results or already validated event/queued references.
---@param force LuaForce?
---@param selection_forces table<integer,boolean>?
local function hostile(entity, force, selection_forces)
    if not entity or not entity.valid or not force or not force.valid then return false end
    local health = entity.health
    if not health or health <= 0 or not entity.destructible then return false end
    local other = entity.force
    local index = other.index
    -- Selection runs without damage callbacks: diplomacy is stable within this
    -- single query. Actual damage always rechecks it without this scratch cache.
    if selection_forces and selection_forces[index] ~= nil then return selection_forces[index] end
    local allowed = index ~= force.index and other.name ~= "neutral" and force.name ~= "neutral"
        and not force.get_friend(other) and not other.get_friend(force)
        and not force.get_cease_fire(other) and not other.get_cease_fire(force)
    if selection_forces then selection_forces[index] = allowed end
    return allowed
end

local function damage(runtime, target, amount, force, source, primary)
    if amount <= 0 or not hostile(target, force) then return 0 end
    -- Internal packet references are LuaEntity-or-nil; generic event inputs are
    -- validated with ei_lib at entry, avoiding repeated protected calls per victim.
    if source and not source.valid then source = nil end
    if source and source.surface ~= target.surface then source = nil end
    local applied = target.damage(amount, force, c.damage_type, source)
    count(runtime, primary and "direct_damage_amount" or "secondary_damage_amount", applied)
    count(runtime, primary and "direct_damage_applied" or "secondary_packets")
    return applied
end

---@return LanceRuntime
local function new_runtime()
    return {version = VERSION, presentation_revision = art.revision, lances = {}, registrations = {}, force_cache = {},
        buckets = scheduler.ensure_delayed_buckets(nil), pending = 0, counters = {},
        visual_config = c.resolve(), qc_enabled = false, profiling_enabled = false}
end

-- Settle legacy pending primaries once, preserving separate resistance applications.
-- Active jobs are also indexed by a second table; visit each payload only once.
local function settle_legacy(old, runtime)
    if not old then return end
    local seen = {}
    local function settle(job, payload)
        if not payload or seen[payload] then return end
        seen[payload] = true
        local source = job.source_unit_number and game.get_entity_by_unit_number(job.source_unit_number)
        local force = source and source.valid and source.force or game.forces[job.force_index or 0]
        local target = lib.get_valid_entity(payload.direct_target)
            or (payload.direct_target_unit_number and game.get_entity_by_unit_number(payload.direct_target_unit_number))
        if force and force.valid then
            local amount = c.direct_damage * math.max(0, 1 + force.get_ammo_damage_modifier(c.ammo_damage_category))
            for _ = 1, payload.damage_count or 1 do damage(runtime, target, amount, force, source, true) end
        end
    end
    for _, job in pairs(old.visual_queue and old.visual_queue.items or {}) do settle(job, job.pending_impact) end
    for _, job in pairs(old.active_visual_by_unit or {}) do settle(job, job.pending_impact) end
    for _, bucket in pairs(old.impact_buckets or {}) do
        for _, payload in pairs(bucket) do settle(payload, payload) end
    end
end

---@return LanceRuntime
local function state()
    storage.ei = storage.ei or {}
    local runtime = storage.ei.singularity_lance
    if not runtime or runtime.version ~= VERSION then
        local old = runtime
        runtime = new_runtime()
        storage.ei.singularity_lance = runtime
        settle_legacy(old, runtime)
    end
    return runtime
end

---@param force LuaForce
---@return LanceCapabilities
local function build_capabilities(force)
    local level = 0
    local root = force.technologies[NAME]
    if root and root.researched then
        for index, upgrade in ipairs(c.upgrades) do
            local tech = force.technologies[NAME .. "-" .. upgrade.key]
            if not tech or not tech.researched then break end
            level = index
        end
    end
    local multiplier = math.max(0, 1 + force.get_ammo_damage_modifier(c.ammo_damage_category))
    return {level = level, multiplier = multiplier, laser_damage_multiplier = multiplier,
        ammo_category = c.ammo_damage_category, direct_damage = c.direct_damage * multiplier,
        direct_sustained_dps = c.direct_sustained_dps * multiplier,
        direct_burst_dps = c.direct_burst_dps * multiplier}
end

local function set_status(record, cache)
    if lib.entity_check(record.entity) then
        record.entity.custom_status = {diode = defines.entity_status_diode.green,
            label = {"lance-upgrades.status", string.format("%.1f", cache.direct_sustained_dps),
                cache.level == 0 and {"lance-upgrades.baseline"}
                or {"technology-name." .. NAME .. "-" .. c.upgrades[cache.level].key}}}
    end
end

local function sync_force(runtime, force)
    if not force or not force.valid then return end
    local cache, old = build_capabilities(force), runtime.force_cache[force.index]
    if old and old.level == cache.level and old.multiplier == cache.multiplier then return old end
    runtime.force_cache[force.index] = cache
    count(runtime, "force_cache_refreshes")
    for _, record in pairs(runtime.lances) do
        if record.force_index == force.index then
            if cache.level < 2 then reset_wound(record) end
            if cache.level < 4 then record.counter = 0 end
            set_status(record, cache)
            count(runtime, "status_refreshes")
        end
    end
    return cache
end

local function capabilities(runtime, force)
    return runtime.force_cache[force.index] or sync_force(runtime, force)
end

---@param runtime LanceRuntime
---@param entity LuaEntity?
---@return LanceRecord?
local function register(runtime, entity)
    if not lib.entity_check(entity) or entity.name ~= NAME then return end
    local id = entity.unit_number
    local record = runtime.lances[id]
    if not record then
        record = {entity = entity, force_index = entity.force.index, surface_index = entity.surface.index,
            counter = 0, stacks = 0}
        runtime.lances[id] = record
        runtime.registrations[script.register_on_object_destroyed(entity)] = id
        set_status(record, capabilities(runtime, entity.force))
    elseif record.force_index ~= entity.force.index then
        -- LuaEntity.force assignment has no engine event. Reconcile on the next
        -- lance interaction; the mark expires natively even if the lance stays idle.
        reset_wound(record)
        record.counter, record.force_index = 0, entity.force.index
        set_status(record, capabilities(runtime, entity.force))
    end
    record.surface_index = entity.surface.index
    if not record.effective_range then
        record.effective_range = entity.prototype.attack_parameters.range * entity.quality.range_multiplier
    end
    return record
end

local function nearer(a, b)
    if a.distance ~= b.distance then return a.distance < b.distance end
    if a.id ~= b.id then return a.id < b.id end
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.name < b.name
end

local function candidate(entity, distance)
    local position = entity.position
    return {entity = entity, distance = distance, id = entity.unit_number or 0,
        x = position.x, y = position.y, name = entity.name}
end

local function area_damage(runtime, surface, force, position, primary, source, amount, radius, cap)
    count(runtime, "area_queries")
    local selected, selection_forces = {}, {}
    for _, entity in pairs(surface.find_entities_filtered{position = position, radius = radius, is_military_target = true}) do
        if entity ~= primary and hostile(entity, force, selection_forces) then
            local p = entity.position
            selected[#selected + 1] = candidate(entity, (p.x - position.x)^2 + (p.y - position.y)^2)
        end
    end
    table.sort(selected, nearer)
    for index = 1, math.min(cap, #selected) do damage(runtime, selected[index].entity, amount, force, source) end
end

-- Clip an oriented collision box to the incision strip. Its first surviving
-- point determines victim order; projecting the whole box can put an off-ray
-- corner ahead of a nearer enemy. The broad-phase query is never the final test.
local function corridor_entry(entity, origin, ux, uy, length)
    local box = entity.bounding_box
    local left, right = box.left_top, box.right_bottom
    local bx, by = (left.x + right.x) / 2 - origin.x, (left.y + right.y) / 2 - origin.y
    local hx, hy = (right.x - left.x) / 2, (right.y - left.y) / 2
    local angle = (box.orientation or 0) * 2 * math.pi
    local ex, ey = math.cos(angle), math.sin(angle)
    local vx, vy = -uy, ux
    local half_width = c.axial.width / 2
    local along, across = bx * ux + by * uy, bx * vx + by * vy
    local along_extent = hx * math.abs(ex * ux + ey * uy) + hy * math.abs(-ey * ux + ex * uy)
    local across_extent = hx * math.abs(ex * vx + ey * vy) + hy * math.abs(-ey * vx + ex * vy)
    if along + along_extent < 0 or along - along_extent > length or math.abs(across) > half_width + across_extent then return end
    if angle == 0 and (ux == 0 or uy == 0) then return math.max(0, along - along_extent) end
    local ax, ay = hx * (ex * ux + ey * uy), hx * (ex * vx + ey * vy)
    local cx, cy = hy * (-ey * ux + ex * uy), hy * (-ey * vx + ex * vy)
    -- Keep the original corner arithmetic and edge order without allocating
    -- two four-element tables for every secondary-target geometry check.
    local x1,y1 = along-ax-cx,across-ay-cy
    local x2,y2 = along+ax-cx,across+ay-cy
    local x3,y3 = along+ax+cx,across+ay+cy
    local x4,y4 = along-ax+cx,across-ay+cy
    local first, last = math.huge, -math.huge
    for i = 1, 4 do
        local x,y,next_x,next_y
        if i == 1 then x,y,next_x,next_y = x1,y1,x2,y2
        elseif i == 2 then x,y,next_x,next_y = x2,y2,x3,y3
        elseif i == 3 then x,y,next_x,next_y = x3,y3,x4,y4
        else x,y,next_x,next_y = x4,y4,x1,y1 end
        if math.abs(y) <= half_width then first, last = math.min(first, x), math.max(last, x) end
        if y ~= next_y then
            for sign = -1, 1, 2 do
                local fraction = (sign * half_width - y) / (next_y - y)
                if fraction >= 0 and fraction <= 1 then
                    local intersection = x + fraction * (next_x - x)
                    first, last = math.min(first, intersection), math.max(last, intersection)
                end
            end
        end
    end
    if first <= length and last >= 0 then return math.max(0, first) end
end

local function penetrate(runtime, surface, source, force, primary, origin, endpoint, amount, cap)
    local dx, dy = endpoint.x - origin.x, endpoint.y - origin.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.00001 then return end
    local ux, uy, half = dx / length, dy / length, c.axial.width / 2
    local selected, selection_forces = {}, {}
    count(runtime, "penetration_queries")
    for _, entity in pairs(surface.find_entities_filtered{area = {
        {math.min(origin.x, endpoint.x) - half, math.min(origin.y, endpoint.y) - half},
        {math.max(origin.x, endpoint.x) + half, math.max(origin.y, endpoint.y) + half}}, is_military_target = true}) do
        if entity ~= primary and hostile(entity, force, selection_forces) then
            local distance = corridor_entry(entity, origin, ux, uy, length)
            if distance then selected[#selected + 1] = candidate(entity, distance) end
        end
    end
    table.sort(selected, nearer)
    for index = 1, math.min(cap, #selected) do damage(runtime, selected[index].entity, amount, force, source) end
end

local function animation(runtime, name, surface, position, ttl, scale)
    count(runtime, "core_cues")
    return rendering.draw_animation{animation = NAME .. "-" .. name, surface = surface, target = position,
        time_to_live = ttl, animation_speed = 1, x_scale = scale or 1, y_scale = scale or 1,
        render_layer = "light-effect"}
end

local function beam_cue(runtime, record, surface, origin, endpoint, level, testament, tick)
    local shape = testament and "testament" or level >= 1 and "axial" or "base"
    local old_origin, old_endpoint = record.beam_origin, record.beam_endpoint
    local same_shape = record.beam_shape == shape or (record.beam_shape == "testament"
        and tick < (record.testament_hold_until or 0))
    if record.beam and record.beam.valid and same_shape and old_origin and old_endpoint
        and old_origin.x == origin.x and old_origin.y == origin.y
        and old_endpoint.x == endpoint.x and old_endpoint.y == endpoint.y then
        -- Native beams cannot refresh TTL. Reuse while alive so rapid fire does
        -- not restart the animation every tick; the next shot replaces expiry.
        count(runtime, "core_cues_refreshed")
        return
    end
    destroy_cue(record.beam)
    local dx, dy = endpoint.x - origin.x, endpoint.y - origin.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.00001 then record.beam = nil; return end
    local duration = math.max(runtime.visual_config.beam_duration_ticks, testament and art.testament_hold_ticks or 0)
    record.beam = surface.create_entity{name = NAME .. "-beam" .. (shape == "base" and "" or "-" .. shape),
        position = origin, source_position = origin, target_position = endpoint, duration = duration}
    record.beam_shape, record.beam_origin, record.beam_endpoint = shape, origin, endpoint
    record.testament_hold_until = testament and tick + art.testament_hold_ticks or nil
    count(runtime, "core_cues")
end

---@param ttl integer? Remaining lifetime during presentation migration.
local function wound_cue(runtime, record, target, force, ttl)
    -- Secondary damage can synchronously trigger death effects or other mods'
    -- damage handlers after the primary survived. Revalidate at presentation time.
    if not lib.entity_check(record.entity) or not hostile(target, force) then
        reset_wound(record)
        return
    end
    local band = record.stacks >= 5 and 3 or record.stacks >= 3 and 2 or 1
    local name = NAME .. "-wound-" .. band
    local stronger = record.wound_band and band > record.wound_band
    if record.mark and record.mark.valid then
        if record.wound_band ~= band then record.mark.animation = name end
        record.mark.time_to_live = ttl or c.wound.timeout
    else
        record.mark = rendering.draw_animation{animation = name, target = {entity = target}, surface = target.surface,
            time_to_live = ttl or c.wound.timeout, animation_speed = art.wound_speed, render_layer = "light-effect"}
    end
    record.wound_band = band
    count(runtime, "wound_cues")
    return stronger and not ttl
end

local function wound_crown(runtime, record, tick)
    -- The band itself is core. A bounded crown pulse is optional decoration.
    if runtime.visual_config.visual_fidelity ~= "lean" then
        local target = record.target
        if not lib.entity_check(target) then return end
        if runtime.decoration_tick ~= tick then runtime.decoration_tick, runtime.decorations = tick, 0 end
        local cap = runtime.visual_config.visual_fidelity == "standard" and 8 or 24
        if runtime.decorations < cap then
            runtime.decorations = runtime.decorations + 1
            rendering.draw_animation{animation = NAME .. "-wound-crown", target = {entity = target}, surface = target.surface,
                time_to_live = art.crown_ticks, animation_speed = 1, render_layer = "light-effect"}
            count(runtime, "wound_crowns")
        else count(runtime, "decorations_dropped") end
    end
end

local function decorate(runtime, surface, position, tick, testament, source)
    if runtime.visual_config.visual_fidelity == "lean" then return end
    local id = lib.get_entity_unit_number(source)
    local record = id and runtime.lances[id]
    if not record or tick - (record.last_decoration_tick or -1000) < 90 then return end
    if runtime.decoration_tick ~= tick then runtime.decoration_tick, runtime.decorations = tick, 0 end
    local cap = runtime.visual_config.visual_fidelity == "standard" and 8 or 24
    if runtime.decorations >= cap then count(runtime, "decorations_dropped"); return end
    runtime.decorations = runtime.decorations + 1
    record.last_decoration_tick = tick
    surface.create_entity{name = "ei-singularity-lance-scorchmark", position = position}
    if testament then surface.play_sound{path = NAME .. "-testament-sound", position = position, volume_modifier = 0.6} end
    count(runtime, "decorations")
end

---@param event EventData.on_script_trigger_effect
function lance.on_script_trigger_effect(event)
    if event.effect_id ~= lance.script_trigger_effect_id then return end
    local runtime = state()
    if runtime.profiling_enabled then profile_flush(event.tick) end
    local profiler = profile_start(runtime)
    local source = lib.get_valid_entity(event.source_entity)
    if not source or source.name ~= NAME then source = lib.get_valid_entity(event.cause_entity) end
    if not source or source.name ~= NAME then count(runtime, "invalid_events"); return end
    local tick, force, surface = event.tick, source.force, source.surface
    local record = register(runtime, source)
    local cache = capabilities(runtime, force)
    count(runtime, "shots")
    -- Consume the paid shot before checking its target. Victims never increment it.
    local testament = false
    if cache.level >= 4 then
        record.counter = (record.counter + 1) % c.testament.interval
        testament = record.counter == 0
        if testament then count(runtime, "testament_shots") end
    end
    local target = lib.get_valid_entity(event.target_entity)
    local aim = event.target_position or (target and target.position)
    if not aim then reset_wound(record); profile_end(profiler, "shot", tick); return end
    aim = {x = aim.x, y = aim.y}
    local origin = source.position
    local endpoint = {x = aim.x, y = aim.y}
    local visual_endpoint = endpoint
    if cache.level >= 1 then
        local dx, dy = aim.x - origin.x, aim.y - origin.y
        local length = math.sqrt(dx * dx + dy * dy)
        local range = record.effective_range
        if length > 0.00001 then
            local reach = math.min(length + c.axial.reach, range)
            endpoint = {x = origin.x + dx / length * reach, y = origin.y + dy / length * reach}
            -- A native bounding-box hit may aim beyond the nominal center range.
            -- Keep its direct beam intact while capping additional axial victims.
            visual_endpoint = length > range and aim or endpoint
        end
    end
    if record.target ~= target or not record.wound_tick or tick - record.wound_tick >= c.wound.timeout
        or not hostile(target, force) or cache.level < 2 then reset_wound(record) end
    local primary_amount = cache.direct_damage * (1 + record.stacks * c.wound.step)
        * (testament and c.testament.primary_multiplier or 1)
    local applied = damage(runtime, target, primary_amount, force, source, true)
    local wound_updated = false
    if cache.level >= 2 then
        if applied > 0 and hostile(target, force) then
            record.target, record.wound_tick = target, tick
            record.stacks = math.min(c.wound.cap, record.stacks + 1)
            wound_updated = true
        elseif not hostile(target, force) then reset_wound(record) end
    end
    if cache.level >= 1 then
        penetrate(runtime, surface, source, force, target, origin, endpoint, c.axial.damage * cache.multiplier,
            testament and c.testament.axial_cap or c.axial.cap)
    end
    local packet
    if cache.level >= 3 then
        local values = testament and c.testament or c.collapse
        packet = {force_index = force.index, surface_index = surface.index, position = aim,
            primary = target, source = source, damage = values.damage * cache.multiplier,
            radius = values.radius, cap = values.cap, testament = testament}
        local due = tick + c.collapse.delay
        scheduler.delayed_schedule(runtime.buckets, due, packet)
        runtime.pending = runtime.pending + 1
        runtime.next_due = math.min(runtime.next_due or due, due)
        count(runtime, "collapses_scheduled")
    else
        area_damage(runtime, surface, force, aim, target, source, c.splash_damage * cache.multiplier, c.splash_radius, c.splash_cap)
    end
    local visual_profiler = profile_start(runtime)
    beam_cue(runtime, record, surface, origin, visual_endpoint, cache.level, testament, tick)
    -- A zero-damage hit neither builds nor refreshes an existing wound. Its old
    -- timeout (and native mark TTL) still applies.
    local stronger = wound_updated and wound_cue(runtime, record, record.target, force)
    if packet then packet.warning = animation(runtime, testament and "testament-warning" or "collapse-warning",
        surface, aim, c.collapse.delay, packet.radius / art.collapse_reference_radius) end
    profile_end(visual_profiler, "shot-core", tick)
    if stronger then
        local decoration = profile_start(runtime)
        wound_crown(runtime, record, tick)
        profile_end(decoration, "decoration", tick)
    end
    profile_end(profiler, "shot", tick)
end

function lance.has_tick_work(event)
    local runtime = storage.ei and storage.ei.singularity_lance
    return runtime and runtime.next_due and runtime.next_due <= (event and event.tick or game.tick) or false
end

function lance.get_pending_work_count()
    local runtime = storage.ei and storage.ei.singularity_lance
    return runtime and runtime.pending or 0
end

function lance.update(_limit, event)
    local runtime, tick = state(), event and event.tick or game.tick
    if not runtime.next_due or runtime.next_due > tick then return 0 end
    if runtime.profiling_enabled then profile_flush(tick) end
    local profiler, processed = profile_start(runtime), 0
    local total_profiler = profile_start(runtime)
    local due_packets = scheduler.delayed_take_due_through(runtime.buckets, tick)
    -- Finish every paid packet before spending time on any presentation.
    for _, packet in ipairs(due_packets) do
        runtime.pending = runtime.pending - 1
        local surface, force = game.surfaces[packet.surface_index], game.forces[packet.force_index]
        destroy_cue(packet.warning)
        if surface and force then
            area_damage(runtime, surface, force, packet.position, packet.primary, packet.source, packet.damage, packet.radius, packet.cap)
            count(runtime, "collapses_applied")
        end
        processed = processed + 1
    end
    profile_end(profiler, "mechanics", tick)
    for _, packet in ipairs(due_packets) do
        local surface = game.surfaces[packet.surface_index]
        if surface then
            local visual = profile_start(runtime)
            animation(runtime, packet.testament and "testament-impact" or "collapse-impact", surface, packet.position,
                art.impact_ticks, packet.radius / art.collapse_reference_radius)
            profile_end(visual, "impact-core", tick)
            local decoration = profile_start(runtime)
            decorate(runtime, surface, packet.position, tick, packet.testament, packet.source)
            profile_end(decoration, "decoration", tick)
        end
    end
    runtime.next_due = nil
    for due in pairs(runtime.buckets) do runtime.next_due = math.min(runtime.next_due or due, due) end
    profile_end(total_profiler, "update-total", tick)
    return processed
end

---@param event table Build, revival, or normalized clone event from control.lua.
function lance.on_built_entity(event)
    local entity = event.entity or event.destination or event.created_entity
    if not entity or not entity.valid or entity.name ~= NAME then return end
    return register(state(), entity)
end

local function remove(runtime, id)
    local record = runtime.lances[id]
    if record then reset_wound(record); destroy_cue(record.beam); runtime.lances[id] = nil end
end

function lance.on_destroyed_entity(event)
    local entity = event.entity
    if lib.entity_check(entity) and entity.name == NAME then remove(state(), entity.unit_number) end
end

---@param event EventData.on_object_destroyed
function lance.on_object_destroyed(event)
    local runtime = state()
    local id = runtime.registrations[event.registration_number]
    if id then remove(runtime, id); runtime.registrations[event.registration_number] = nil end
end

---@param event EventData.on_pre_surface_deleted|EventData.on_pre_surface_cleared
function lance.on_surface_deleted(event)
    local runtime = state()
    for id, record in pairs(runtime.lances) do if record.surface_index == event.surface_index then remove(runtime, id) end end
    for due, bucket in pairs(runtime.buckets) do
        for index = #bucket, 1, -1 do
            if bucket[index].surface_index == event.surface_index then
                destroy_cue(bucket[index].warning); table.remove(bucket, index); runtime.pending = runtime.pending - 1
            end
        end
        if #bucket == 0 then runtime.buckets[due] = nil end
    end
    runtime.next_due = nil
    for due in pairs(runtime.buckets) do runtime.next_due = math.min(runtime.next_due or due, due) end
end

function lance.on_diplomacy_changed()
    local runtime = state()
    for _, record in pairs(runtime.lances) do
        if record.target and (not lib.entity_check(record.entity) or not hostile(record.target, record.entity.force)) then reset_wound(record) end
    end
end

---@param event EventData.on_forces_merged
function lance.on_forces_merged(event)
    local runtime = state()
    for _, bucket in pairs(runtime.buckets) do
        for _, packet in ipairs(bucket) do if packet.force_index == event.source_index then packet.force_index = event.destination.index end end
    end
    runtime.force_cache[event.source_index] = nil
    for _, record in pairs(runtime.lances) do
        if record.force_index == event.source_index then
            reset_wound(record); record.counter, record.force_index = 0, event.destination.index
            set_status(record, build_capabilities(event.destination))
        end
    end
    sync_force(runtime, event.destination)
    lance.on_diplomacy_changed()
end

---@param event EventData.on_force_reset|EventData.on_technology_effects_reset|EventData.on_force_created
function lance.on_force_reset(event)
    sync_force(state(), event.force)
end

---@param event EventData.on_research_finished|EventData.on_research_reversed
function lance.on_research_finished(event)
    local research = event.research
    if research and relevant_research[research.name] then sync_force(state(), research.force) end
end

---@param force LuaForce
function lance.on_scripted_research_burst(force)
    sync_force(state(), force)
end

function lance.get_force_snapshot(force)
    return table.deepcopy(sync_force(state(), force))
end

function lance.check_global()
    local runtime = state()
    runtime.visual_config = c.resolve()
    for _, force in pairs(game.forces) do sync_force(runtime, force) end
    -- One discovery pass at initialization/configuration only; never on research.
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = NAME}) do register(runtime, entity) end
    end
    for id, record in pairs(runtime.lances) do
        if not lib.entity_check(record.entity) then remove(runtime, id)
        else record.effective_range = nil; register(runtime, record.entity) end
    end
    if runtime.presentation_revision ~= art.revision then
        -- Upgrade only presentation. Schema 11 meters, paid delayed buckets and
        -- due ticks must survive; never route this through legacy state replacement.
        for _, record in pairs(runtime.lances) do
            destroy_cue(record.beam); destroy_cue(record.mark)
            record.beam, record.mark, record.beam_shape, record.wound_band = nil, nil, nil, nil
            record.beam_origin, record.beam_endpoint, record.testament_hold_until = nil, nil, nil
            local remaining = record.wound_tick and math.min(c.wound.timeout, c.wound.timeout - (game.tick - record.wound_tick)) or 0
            if record.stacks > 0 and remaining > 0 then
                wound_cue(runtime, record, record.target, record.entity.force, remaining)
            else reset_wound(record) end
        end
        -- Warning prototypes retain their name, frame count and speed. Existing
        -- Animation objects retain the correct phase, TTL and fixed aim point.
        runtime.presentation_revision = art.revision
    end
end
lance.on_configuration_changed = lance.check_global

function lance.get_runtime_status()
    local runtime = state()
    return {module = "singularity-lance", version = VERSION, presentation_revision = runtime.presentation_revision, pending = runtime.pending,
        pending_due = lance.has_tick_work() and runtime.pending or 0, pending_damage = runtime.pending,
        impact_next_due_tick = runtime.next_due or 0, pending_visual_slices = 0, active_visual_jobs = 0,
        visual_fidelity = runtime.visual_config.visual_fidelity, counters = runtime.counters,
        registered_lances = table_size(runtime.lances), profiling_enabled = runtime.profiling_enabled,
        qc_enabled = runtime.qc_enabled, target_update_ms = 0.5, hard_update_ms = 1}
end

function lance.get_qc_snapshot()
    profile_flush(nil)
    local result, runtime = lance.get_runtime_status(), state()
    result.force_cache = table.deepcopy(runtime.force_cache)
    result.ammo_damage_category, result.damage_type = c.ammo_damage_category, c.damage_type
    result.scripted_base_damage, result.spillover_victim_cap = c.direct_damage, c.splash_cap
    result.meters = {}
    for id, record in pairs(runtime.lances) do result.meters[id] = {counter = record.counter, stacks = record.stacks, wound_tick = record.wound_tick} end
    return result
end

function lance.configure_qc(options)
    local runtime = state()
    options = options or {}
    if options.reset then runtime.counters = {} end
    if options.qc_enabled ~= nil then runtime.qc_enabled = options.qc_enabled end
    if options.profiling_enabled ~= nil then runtime.profiling_enabled = options.profiling_enabled end
    return lance.get_qc_snapshot()
end

function lance.reset_runtime_state()
    -- QC reset affects telemetry/meters only: paid collapses are irrevocable.
    local runtime = state()
    runtime.counters = {}
    for _, record in pairs(runtime.lances) do reset_wound(record); record.counter = 0 end
    lance.check_global()
    return lance.get_runtime_status()
end
lance.service_for_qc = lance.update
lance.refresh_runtime_state = lance.check_global
return lance
