--==============================================================================
-- ESIR FILE MAP
-- owns: paid lance transactions, force capabilities, registered lances, core cues
-- loaded_by: control.lua; Informatron reads the force snapshot
-- cadence: exact shot/lifecycle events; shared delayed buckets serviced by control
-- storage_roots: storage.ei.singularity_lance (schema 14)
-- forwarded_events: shot, build/clone, destruction, research/reset, diplomacy, force/surface lifecycle
-- gui_ids: none (native custom status; Informatron owns the page)
-- remote_interfaces: none (control.lua owns diagnostics)
-- rebuild_on: initialization and configuration change; force caches on relevant research
-- invariants: damage never follows visual budgets; no idle queries or wound sweeps
-- reference: docs/singularity-lance.md at repository root (mechanics and maintenance)
--==============================================================================
-- blueprint: .codex/esir/blueprints/singularity-lance.md#contract
-- Mechanical authority is the paid native callback, not the beam trace. Admission
-- snapshots one transaction and all of its deadlines. Contact resolves primary
-- and incision; Collapse replaces baseline splash, and Testament prepays one echo.
-- The target may move until contact; subsequent pulse positions are immutable.
--
-- Two kinds of sharing are intentional. A lance FIFO owns visual waypoints in
-- paid order, while contacts share a Wound context for one ownership/research
-- period. Detaching that context resets live state without changing paid damage.
-- Beam/light refreshes may coalesce, but damage calls must never coalesce: each
-- paid shot and pulse has independent resistance, death and Wound consequences.
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local c = require("lib/singularity-lance-config")
local lance = {script_trigger_effect_id = "ei-singularity-lance-shot"}
local NAME, VERSION = "ei-singularity-lance", 14
local art = c.presentation
local acquisition = table.deepcopy(c.acquisition)
assert(acquisition.degrees_per_tick > 0 and acquisition.minimum_ticks >= 1
    and acquisition.first_ticks >= acquisition.minimum_ticks
    and acquisition.maximum_wait_ticks >= acquisition.first_ticks, "Invalid lance acquisition tuning")
assert(acquisition.easing == "smoothstep" or acquisition.easing == "linear", "Unknown lance acquisition curve")
for _, ticks in ipairs({acquisition.minimum_ticks, acquisition.first_ticks, acquisition.maximum_wait_ticks}) do
    assert(ticks % 1 == 0, "Lance acquisition deadlines require integer tick tuning")
end
local branch_angle = math.rad(c.axial.branch.angle)
local branch_cos, branch_sin = math.cos(branch_angle), math.sin(branch_angle)
-- Immutable shared snapshot: stored paid contacts retain it across code/config reloads.
local axial_snapshot = table.deepcopy(c.axial)
axial_snapshot.cos, axial_snapshot.sin = branch_cos, branch_sin
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
---@field wound_first_damage number
---@field wound_max_damage number
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
---@field beam_light_index integer? Palette choice retained for this native beam's lifetime.
---@field beam_origin MapPosition?
---@field beam_endpoint MapPosition?
---@field extensions LanceBeamSegment[]? Forward incision and two branches; no stacking.
---@field testament_hold_until integer?
---@field last_decoration_tick integer?
---@field wound_context LanceWoundContext?
---@field contacts table? Shared-scheduler FIFO; only its head is animated.
---@field latest_target LuaEntity?
---@field sweep_from MapPosition?
---@field sweep_start integer?
---@field flash LuaEntity?
---@field afterglow LuaEntity?
---@field last_contact_visual LanceContact? Latest arrival eligible for a coalesced beam/light refresh.
---@field logical_aim LanceAim? Authoritative contact point; independent of beam success or cosmetic rebuilds.
---@field contact_tail LanceContact? Last paid FIFO reservation; O(1) admission, including reentrant shots.
---@class LanceAim
---@field position MapPosition
---@field primary LuaEntity?
---@field force_index integer
---@field surface_index integer
---@class LanceAngularMotion
---@field from_angle number
---@field from_radius number
---@field goal_angle number Unwrapped against the previous goal, preventing opposite-bearing flips.
---@class LanceAcquisitionPolicy
---@field degrees_per_tick number Nominal average, not a hard instantaneous cap.
---@field minimum_ticks integer
---@field first_ticks integer
---@field maximum_wait_ticks integer
---@field easing "smoothstep"|"linear"
---@class LanceWoundContext
---@field target LuaEntity?
---@field stacks integer
---@field tick integer?
---@class LanceAxialSnapshot
---@field width number
---@field reach number
---@field damage number
---@field cap integer
---@field cos number Precomputed branch-angle cosine.
---@field sin number Precomputed branch-angle sine.
---@field branch {angle: number, width: number, reach: number, damage: number, cap: integer}
---@class LanceContact
---@field phase "contact"
---@field due integer
---@field force_index integer
---@field surface_index integer
---@field source LuaEntity?
---@field primary LuaEntity?
---@field position MapPosition Last observed same-surface aim, then immutable contact.
---@field origin MapPosition Firing origin; secondary range never follows a moved source.
---@field range number
---@field record LanceRecord Paid context can outlive the registered source.
---@field context LanceWoundContext
---@field level integer
---@field multiplier number
---@field direct_damage number
---@field wound_step number
---@field wound_cap integer
---@field wound_first_hit_stacks integer? Missing on older paid contacts, which retain their first-hit bonus.
---@field wound_timeout integer
---@field testament boolean
---@field primary_multiplier number
---@field axial LanceAxialSnapshot Immutable shared geometry/damage snapshot retained by paid contacts.
---@field axial_cap integer
---@field branch_cap integer
---@field splash_damage number
---@field splash_radius number
---@field splash_cap integer
---@field wound_updated boolean?
---@field collapse LanceCollapse?
---@field rays LanceRay[]?
---@field resolved boolean?
---@field fired_tick integer? Absent on legacy schema-13 contacts.
---@field planned_position MapPosition? Immutable firing aim until contact is finalized before callbacks.
---@field policy LanceAcquisitionPolicy? Nil preserves legacy Cartesian acquisition and paid timing.
---@field pivot MapPosition? Snapshotted crystal position, independent of presentation configuration.
---@field nominal_turn_ticks integer?
---@field angular_motion LanceAngularMotion?
---@field same_target boolean?
---@field first_acquisition boolean?
---@field compressed_turn boolean?
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
---@field core_damage number? Absent on schema-11 packets and flat echoes.
---@field core_radius number?
---@field include_primary boolean? Nil/false preserves pre-hybrid exclusion.
---@field phase "legacy"|"first"|"echo"?
---@field due integer?
---@field echo LanceCollapse? Shared reference to the already queued paid echo.
---@field resolved boolean?
---@class LanceBeamSegment
---@field beam LuaEntity?
---@field beam_shape string?
---@field beam_light_index integer?
---@field beam_origin MapPosition?
---@field beam_endpoint MapPosition?
---@field testament_hold_until integer?
---@class LanceRay
---@field origin MapPosition
---@field endpoint MapPosition
---@field ux number
---@field uy number
---@field length number
---@field half_width number
---@class LanceRuntime
---@field version integer
---@field presentation_revision integer?
---@field light_random LuaRandomGenerator? Saved cosmetic stream, independent of gameplay RNG.
---@field lances table<integer,LanceRecord>
---@field registrations table<integer,integer>
---@field force_cache table<integer,LanceCapabilities>
---@field buckets table<integer,(LanceCollapse|LanceContact)[]>
---@field pending integer
---@field pending_contacts integer
---@field active_sweeps table<integer,LanceRecord>
---@field sweep_count integer
---@field visual_next_due integer?
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
    -- Paid contacts retain the detached table; they cannot revive this live meter.
    record.wound_context = nil
end

local function reset_beams(record)
    destroy_cue(record.beam)
    for _, segment in pairs(record.extensions or {}) do destroy_cue(segment.beam) end
    record.beam, record.extensions = nil, nil
    record.beam_origin, record.beam_endpoint, record.beam_shape, record.testament_hold_until = nil, nil, nil, nil
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
        for _, phase in ipairs({"incision-selection", "incision-damage", "shot-core", "shot", "contact", "sweep", "turn-reservation",
            "sweep-turn", "sweep-compressed", "sweep-locked", "sweep-first", "sweep-legacy", "contact-light", "collapse-first",
            "collapse-echo", "mechanics", "impact-core", "decoration", "update-total"}) do
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
    if source and (source.surface ~= target.surface or source.force ~= force) then source = nil end
    local applied = target.damage(amount, force, c.damage_type, source)
    count(runtime, primary and "direct_damage_amount" or "secondary_damage_amount", applied)
    count(runtime, primary and "direct_damage_applied" or "secondary_packets")
    return applied
end

---@return LanceRuntime
local function new_runtime()
    return {version = VERSION, presentation_revision = art.revision, lances = {}, registrations = {}, force_cache = {},
        buckets = scheduler.ensure_delayed_buckets(nil), pending = 0, counters = {},
        pending_contacts = 0, active_sweeps = {}, sweep_count = 0,
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
    if runtime and runtime.version == 11 then
        -- Preserve paid snapshots and object registrations in place. A schema-11
        -- collapse must never gain primary damage, a stronger core, or an echo.
        for _, bucket in pairs(runtime.buckets) do
            for _, packet in ipairs(bucket) do packet.include_primary, packet.phase = false, "legacy" end
        end
        runtime.version, runtime.force_cache = 12, {}
    end
    if runtime and runtime.version == 12 then
        -- In-place migration: do not rewrite old paid collapse snapshots/deadlines.
        runtime.pending_contacts, runtime.active_sweeps, runtime.sweep_count = 0, {}, 0
        for _, record in pairs(runtime.lances) do
            record.wound_context = {target = record.target, stacks = record.stacks or 0, tick = record.wound_tick}
        end
        runtime.version = 13
    end
    if runtime and runtime.version == 13 then
        -- Existing contacts retain nil policy: the old Cartesian path and every
        -- paid deadline survive. Detached records also own paid work after death.
        local records = {}
        for _, record in pairs(runtime.lances) do records[record] = true end
        for _, bucket in pairs(runtime.buckets) do
            for _, packet in ipairs(bucket) do
                if packet.phase == "contact" then
                    records[packet.record] = true
                    packet.planned_position = {x = packet.position.x, y = packet.position.y}
                end
            end
        end
        for record in pairs(records) do
            record.contact_tail = scheduler.queue_peek_last(record.contacts)
            -- last_contact_visual is published by the mechanical pass, before
            -- presentation; beam_endpoint is deliberately not a timing fallback.
            local previous = record.last_contact_visual
            if previous then
                record.logical_aim = {position = previous.position, primary = previous.primary,
                    force_index = previous.force_index, surface_index = previous.surface_index}
            end
        end
        runtime.version = VERSION
    end
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
        direct_burst_dps = c.direct_burst_dps * multiplier,
        wound_first_damage = c.direct_damage * multiplier * (level >= 2 and 1 + c.wound.first_hit_stacks * c.wound.step or 1),
        wound_max_damage = c.direct_damage * multiplier * (level >= 2 and 1 + c.wound.step * c.wound.cap or 1)}
end

local function set_status(record, cache)
    if lib.entity_check(record.entity) then
        record.entity.custom_status = {diode = defines.entity_status_diode.green,
            label = {"lance-upgrades.status", c.format_status_number(cache.direct_sustained_dps)}}
    end
end

local function sync_force(runtime, force)
    if not force or not force.valid then return end
    local cache, old = build_capabilities(force), runtime.force_cache[force.index]
    if old and old.level == cache.level and old.multiplier == cache.multiplier
        and old.wound_first_damage == cache.wound_first_damage then return old end
    runtime.force_cache[force.index] = cache
    count(runtime, "force_cache_refreshes")
    for _, record in pairs(runtime.lances) do
        if record.force_index == force.index then
            if old and cache.level < old.level then reset_beams(record) end
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
        reset_beams(record)
        record.logical_aim = nil
        record.counter, record.force_index = 0, entity.force.index
        set_status(record, capabilities(runtime, entity.force))
    end
    if record.surface_index ~= entity.surface.index then record.logical_aim = nil end
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

---@param runtime LanceRuntime
---@param surface LuaSurface
---@param force LuaForce
---@param position MapPosition
---@param primary LuaEntity?
---@param source LuaEntity?
---@param amount number
---@param radius number
---@param cap integer
---@param packet LanceCollapse? Nil is ordinary splash; absent fields retain legacy behavior.
local function area_damage(runtime, surface, force, position, primary, source, amount, radius, cap, packet)
    count(runtime, "area_queries")
    local selected, selection_forces, reserved = {}, {}, nil
    for _, entity in pairs(surface.find_entities_filtered{position = position, radius = radius, is_military_target = true}) do
        if hostile(entity, force, selection_forces) then
            local p = entity.position
            local entry = candidate(entity, (p.x - position.x)^2 + (p.y - position.y)^2)
            if entity ~= primary then selected[#selected + 1] = entry
            elseif packet and packet.include_primary then reserved = entry end
        end
    end
    table.sort(selected, nearer)
    -- Membership is from this pulse's current-position query. The primary has
    -- its own slot, while each victim receives exactly one core-or-shell packet.
    local core_squared = packet and packet.core_radius and packet.core_radius^2
    if reserved then damage(runtime, reserved.entity,
        core_squared and reserved.distance <= core_squared and packet.core_damage or amount, force, source) end
    for index = 1, math.min(cap, #selected) do
        local entry = selected[index]
        damage(runtime, entry.entity, core_squared and entry.distance <= core_squared and packet.core_damage or amount, force, source)
    end
end

-- Clip an oriented collision box to the incision strip. Its first surviving
-- point determines victim order; projecting the whole box can put an off-ray
-- corner ahead of a nearer enemy. The broad-phase query is never the final test.
local function corridor_entry(entity, origin, ux, uy, length, half_width)
    local box = entity.bounding_box
    local left, right = box.left_top, box.right_bottom
    local bx, by = (left.x + right.x) / 2 - origin.x, (left.y + right.y) / 2 - origin.y
    local hx, hy = (right.x - left.x) / 2, (right.y - left.y) / 2
    local angle = (box.orientation or 0) * 2 * math.pi
    local ex, ey = math.cos(angle), math.sin(angle)
    local vx, vy = -uy, ux
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

---@param origin MapPosition
---@param aim MapPosition
---@param range number
---@return LanceRay[]
local function incision_rays(origin, aim, range, axial)
    local dx, dy = aim.x - origin.x, aim.y - origin.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.00001 then return {} end
    local ux, uy = dx / length, dy / length
    local reach = math.min(length + axial.reach, range)
    local rays = {{origin = origin, endpoint = {x = origin.x + ux * reach, y = origin.y + uy * reach},
        ux = ux, uy = uy, length = reach, half_width = axial.width / 2}}
    -- Native targeting may approve a bounding-box hit beyond the center range.
    -- Keep that direct hit, but do not grow branches from outside the circle.
    if length <= range then
        for sign = -1, 1, 2 do
            local bx, by = ux * axial.cos - sign * uy * axial.sin, uy * axial.cos + sign * ux * axial.sin
            local projection = dx * bx + dy * by
            local exit = -projection + math.sqrt(math.max(0, projection^2 + range^2 - length^2))
            local branch_reach = math.min(axial.branch.reach, exit)
            if branch_reach > 0.00001 then rays[#rays + 1] = {origin = aim,
                endpoint = {x = aim.x + bx * branch_reach, y = aim.y + by * branch_reach},
                ux = bx, uy = by, length = branch_reach, half_width = axial.branch.width / 2} end
        end
    end
    return rays
end

---@param runtime LanceRuntime
---@param rays LanceRay[]
---@param multiplier number
---@param paid LanceContact Snapshotted axial coefficients and victim caps.
---@param tick integer
local function penetrate(runtime, surface, source, force, primary, rays, multiplier, paid, tick)
    if not rays[1] then return end
    local profiler = profile_start(runtime)
    local central, branches, selection_forces = {}, {}, {}
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for _, ray in ipairs(rays) do
        local a, b, half = ray.origin, ray.endpoint, ray.half_width
        min_x, min_y = math.min(min_x, a.x - half, b.x - half), math.min(min_y, a.y - half, b.y - half)
        max_x, max_y = math.max(max_x, a.x + half, b.x + half), math.max(max_y, a.y + half, b.y + half)
    end
    count(runtime, "penetration_queries")
    for _, entity in pairs(surface.find_entities_filtered{area = {{min_x, min_y}, {max_x, max_y}}, is_military_target = true}) do
        if entity ~= primary and hostile(entity, force, selection_forces) then
            local ray = rays[1]
            local distance = corridor_entry(entity, ray.origin, ray.ux, ray.uy, ray.length, ray.half_width)
            if distance then central[#central + 1] = candidate(entity, distance)
            else
                -- Classify before capping: central eligibility never falls back
                -- to weaker branch damage, even when the central cap is full.
                local shortest
                for index = 2, #rays do
                    ray = rays[index]
                    distance = corridor_entry(entity, ray.origin, ray.ux, ray.uy, ray.length, ray.half_width)
                    if distance then shortest = math.min(shortest or distance, distance) end
                end
                if shortest then branches[#branches + 1] = candidate(entity, shortest) end
            end
        end
    end
    table.sort(central, nearer)
    table.sort(branches, nearer)
    profile_end(profiler, "incision-selection", tick)
    profiler = profile_start(runtime)
    for index = 1, math.min(paid.axial_cap, #central) do
        damage(runtime, central[index].entity, paid.axial.damage * multiplier, force, source)
        count(runtime, "central_packets")
    end
    for index = 1, math.min(paid.branch_cap, #branches) do
        damage(runtime, branches[index].entity, paid.axial.branch.damage * multiplier, force, source)
        count(runtime, "branch_packets")
    end
    profile_end(profiler, "incision-damage", tick)
end

local function animation(runtime, name, surface, position, ttl, scale, offset)
    count(runtime, "core_cues")
    return rendering.draw_animation{animation = NAME .. "-" .. name, surface = surface, target = position,
        time_to_live = ttl, animation_speed = 1, animation_offset = offset or 0, x_scale = scale or 1, y_scale = scale or 1,
        render_layer = "light-effect"}
end

---@param runtime LanceRuntime
---@param record LanceRecord|LanceBeamSegment
---@param surface LuaSurface
---@param origin MapPosition
---@param endpoint MapPosition
---@param shape string
---@param testament boolean
---@param tick integer
local function beam_segment(runtime, record, surface, origin, endpoint, shape, testament, tick, remaining_ticks)
    local old_origin, old_endpoint = record.beam_origin, record.beam_endpoint
    local same_shape = record.beam_shape == shape or ((record.beam_shape == "testament" or record.beam_shape == "testament-branch")
        and tick < (record.testament_hold_until or 0) and old_endpoint and old_origin
        and old_endpoint.x == endpoint.x and old_endpoint.y == endpoint.y
        and old_origin.x == origin.x and old_origin.y == origin.y)
    if record.beam and record.beam.valid and same_shape and old_origin and old_endpoint then
        -- Endpoint setters preserve the native origin/body animation phase.
        if old_origin.x ~= origin.x or old_origin.y ~= origin.y then record.beam.set_beam_source(origin) end
        if old_endpoint.x ~= endpoint.x or old_endpoint.y ~= endpoint.y then record.beam.set_beam_target(endpoint) end
        record.beam_origin, record.beam_endpoint = origin, endpoint
        count(runtime, "core_cues_refreshed")
        return
    end
    destroy_cue(record.beam)
    local dx, dy = endpoint.x - origin.x, endpoint.y - origin.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.00001 then record.beam = nil; return end
    local duration = (remaining_ticks or acquisition.minimum_ticks)
        + math.max(runtime.visual_config.beam_duration_ticks, testament and art.testament_hold_ticks or 0)
    -- Sample only when a native beam needs creating, never during endpoint moves.
    -- A private saved stream keeps cosmetic variation out of gameplay randomness.
    runtime.light_random = runtime.light_random or game.create_random_generator()
    record.beam_light_index = runtime.light_random(#art.beam_light_palette)
    record.beam = surface.create_entity{name = NAME .. "-beam" .. (shape == "base" and "" or "-" .. shape)
        .. "-light-" .. record.beam_light_index,
        position = origin, source_position = origin, target_position = endpoint, duration = duration}
    record.beam_shape, record.beam_origin, record.beam_endpoint = shape, origin, endpoint
    record.testament_hold_until = testament and tick + art.testament_hold_ticks or nil
    count(runtime, "core_cues")
end

---@param runtime LanceRuntime
---@param record LanceRecord
---@param rays LanceRay[]
local function beam_cue(runtime, record, surface, origin, aim, rays, level, testament, tick, pivot)
    if not lib.entity_check(record.entity) then reset_beams(record); return end
    local shape = testament and "testament" or level >= 1 and "axial" or "base"
    -- Only this segment is raised. All forks meet at the actual ground aim.
    beam_segment(runtime, record, surface,
        pivot or {x = origin.x + c.crystal_offset.x, y = origin.y + c.crystal_offset.y}, aim, shape, testament, tick)
    if level == 0 and not record.extensions then return end
    local extensions = record.extensions or {}
    record.extensions = extensions
    for index = 1, 3 do
        local ray = rays[index]
        local visible = ray and (index ~= 1 or (ray.endpoint.x - aim.x) * ray.ux + (ray.endpoint.y - aim.y) * ray.uy > 0.00001)
        if visible then
            local segment = extensions[index] or {}
            extensions[index] = segment
            beam_segment(runtime, segment, surface, aim, ray.endpoint,
                shape .. (index > 1 and "-branch" or ""), testament, tick)
        elseif extensions[index] then destroy_cue(extensions[index].beam); extensions[index] = nil end
    end
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

-- The FIFO owns visual waypoints; delayed buckets own immutable paid deadlines.
local function schedule(runtime, packet)
    scheduler.delayed_schedule(runtime.buckets, packet.due, packet)
    runtime.pending = runtime.pending + 1
    runtime.next_due = math.min(runtime.next_due or packet.due, packet.due)
end

local function clear_extensions(record)
    for _, segment in pairs(record.extensions or {}) do destroy_cue(segment.beam) end
    record.extensions = nil
end

---@param contact LanceContact
local function observe_contact(runtime, contact)
    local target = contact.primary
    count(runtime, "contact_target_reads")
    -- Admission already established LuaEntity-or-nil. Recheck native validity,
    -- without repeating generic type probes for each acquisition step.
    if target and target.valid and target.surface.index == contact.surface_index then
        local p = target.position
        contact.position = {x = p.x, y = p.y}
        return target
    end
end

local function stop_sweep(runtime, id)
    if runtime.active_sweeps[id] then
        runtime.active_sweeps[id] = nil
        runtime.sweep_count = runtime.sweep_count - 1
    end
end

-- Acquisition geometry belongs to the lance, not the general vector library: the
-- same pivot determines its mechanical reservation and its native beam motion.
-- Numerical tolerances only avoid a spurious extra tick/ambiguous sign at exact
-- constructed angles; all gameplay tuning remains in the shared configuration.
local function bearing(pivot, point, fallback)
    local dx, dy = point.x - pivot.x, point.y - pivot.y
    local radius = math.sqrt(dx * dx + dy * dy)
    return radius > 1e-10 and math.atan2(dy, dx) or fallback or 0, radius
end

local function shortest_turn(from, to)
    local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
    -- Positive map-Y points downward: positive angular motion is clockwise.
    if math.abs(delta + math.pi) < 1e-10 then return math.pi end
    return delta
end

---@param record LanceRecord
---@param target LuaEntity?
---@param aim MapPosition
---@param pivot MapPosition
---@return integer due
---@return integer nominal_turn_ticks
---@return boolean same_target
---@return boolean first_acquisition
---@return boolean compressed
local function reserve_contact(record, target, aim, pivot, force_index, surface_index, tick)
    local tail = record.contact_tail
    local previous_due = tail and tail.due
    local anchor = tail or record.logical_aim
    if anchor and (anchor.surface_index ~= surface_index or anchor.force_index ~= force_index) then
        anchor = record.logical_aim
        if anchor and (anchor.surface_index ~= surface_index or anchor.force_index ~= force_index) then anchor = nil end
    end
    local first = not anchor
    local same = not first and target ~= nil and target.valid and anchor.primary == target
    local turn = acquisition.first_ticks
    if same then turn = 0
    elseif anchor then
        local goal = bearing(pivot, aim)
        local from = bearing(pivot, anchor.planned_position or anchor.position, goal)
        turn = math.max(acquisition.minimum_ticks,
            -- Factorio's deterministic atan2 differs by about 0.00000027 degrees
            -- at constructed 120-degree bearings. Ignore that sub-tick noise.
            math.ceil(math.abs(shortest_turn(from, goal)) * 180 / math.pi / acquisition.degrees_per_tick - 1e-7))
    end
    local desired = math.max(tick + acquisition.minimum_ticks, previous_due and previous_due + 1 or 0)
    if not same then desired = math.max(desired, math.max(tick, previous_due or tick) + turn) end
    local cap = tick + acquisition.maximum_wait_ticks
    -- A future smaller tuning cap cannot pull a new shot ahead of an older paid
    -- reservation. This exceptional backlog drains without rewriting old work.
    local due = previous_due and previous_due > cap and previous_due + 1 or math.min(cap, desired)
    return due, turn, same, first, not same and due < desired
end

---@param record LanceRecord
---@param contact LanceContact
---@param tick integer
---@param from MapPosition? Reached paid waypoint when promoting a successor.
local function start_waypoint(record, contact, tick, from)
    local logical = record.logical_aim
    local previous = logical and logical.force_index == contact.force_index
        and logical.surface_index == contact.surface_index and logical.position
    record.sweep_from = from or record.beam_endpoint or previous or contact.pivot or {
        x = contact.origin.x + c.crystal_offset.x, y = contact.origin.y + c.crystal_offset.y}
    record.sweep_start = tick
    if contact.policy then
        local goal = bearing(contact.pivot, contact.position)
        local from_angle, from_radius = bearing(contact.pivot, record.sweep_from, goal)
        if contact.first_acquisition then from_angle, from_radius = goal, 0 end
        contact.angular_motion = {from_angle = from_angle, from_radius = from_radius,
            goal_angle = from_angle + shortest_turn(from_angle, goal)}
    end
    clear_extensions(record)
end

local function activate_head(runtime, record, tick)
    local contact = scheduler.queue_peek(record.contacts)
    if not contact or not record.entity or not record.entity.valid then return end
    local id = record.entity.unit_number
    if runtime.lances[id] ~= record or record.entity.surface.index ~= contact.surface_index
        or record.entity.force.index ~= contact.force_index then return end
    if not runtime.active_sweeps[id] then
        runtime.active_sweeps[id] = record
        runtime.sweep_count = runtime.sweep_count + 1
    end
    runtime.visual_next_due = math.min(runtime.visual_next_due or tick + 1, tick + 1)
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
    local tick, force = event.tick, source.force
    local record = register(runtime, source)
    local cache = capabilities(runtime, force)
    count(runtime, "shots")
    local testament = false
    -- Count payment before target validation; a lost/protected eighth target
    -- consumes the discharge. Victims, kills and delayed pulses cannot recount it.
    if cache.level >= 4 then
        record.counter = (record.counter + 1) % c.testament.interval
        testament = record.counter == 0
        if testament then count(runtime, "testament_shots") end
    end
    local target = lib.get_valid_entity(event.target_entity)
    local aim = event.target_position or (target and target.position)
    if not aim then reset_wound(record); profile_end(profiler, "shot", tick); return end
    if record.latest_target ~= target then
        destroy_cue(record.mark)
        record.mark, record.wound_band = nil, nil
        record.target, record.wound_tick, record.stacks = nil, nil, 0
    end
    record.latest_target = target
    local context = record.wound_context or {stacks = 0}
    record.wound_context = context
    local origin = source.position
    local pivot = {x = origin.x + c.crystal_offset.x, y = origin.y + c.crystal_offset.y}
    local reservation_profiler = runtime.profiling_enabled and game.create_profiler()
    local due, turn, same, first_acquisition, compressed = reserve_contact(record, target, aim, pivot,
        force.index, source.surface.index, tick)
    if reservation_profiler then profile_end(reservation_profiler, "turn-reservation", tick) end
    local contact = {phase = "contact", due = due, fired_tick = tick, policy = acquisition, pivot = pivot,
        planned_position = {x = aim.x, y = aim.y}, nominal_turn_ticks = turn,
        same_target = same, first_acquisition = first_acquisition, compressed_turn = compressed,
        force_index = force.index, surface_index = source.surface.index, source = source, primary = target,
        position = {x = aim.x, y = aim.y}, origin = {x = origin.x, y = origin.y}, range = record.effective_range,
        record = record, context = context, level = cache.level, multiplier = cache.multiplier,
        direct_damage = cache.direct_damage, wound_step = c.wound.step, wound_cap = c.wound.cap,
        wound_first_hit_stacks = c.wound.first_hit_stacks,
        wound_timeout = c.wound.timeout, testament = testament,
        axial = axial_snapshot, axial_cap = testament and c.testament.axial_cap or c.axial.cap,
        branch_cap = testament and c.testament.branch_cap or c.axial.branch.cap,
        splash_damage = c.splash_damage * cache.multiplier, splash_radius = c.splash_radius, splash_cap = c.splash_cap,
        primary_multiplier = testament and c.testament.primary_multiplier or 1}
    schedule(runtime, contact)
    runtime.pending_contacts = runtime.pending_contacts + 1
    count(runtime, "contacts_scheduled")
    if not first_acquisition and not same then count(runtime, "angular_turns") end
    if compressed then count(runtime, "compressed_turns")
    elseif not first_acquisition and not same then count(runtime, "ordinary_turns") end
    count(runtime, "contact_latency_ticks", due - tick)
    if runtime.qc_enabled then runtime.counters.maximum_contact_latency = math.max(runtime.counters.maximum_contact_latency or 0, due - tick) end
    if cache.level >= 3 then
        -- Prepay both deadlines now. Contact only finalizes their position;
        -- source removal or research changes cannot cancel or reprice this work.
        local values = testament and c.testament or c.collapse
        local packet = {force_index = force.index, surface_index = contact.surface_index, position = contact.position,
            primary = target, source = source, damage = values.damage * cache.multiplier,
            radius = values.radius, cap = values.cap, testament = testament, include_primary = true,
            core_damage = values.core_damage * cache.multiplier, core_radius = values.core_radius,
            phase = "first", due = contact.due + c.collapse.delay}
        contact.collapse = packet
        schedule(runtime, packet)
        count(runtime, "collapses_scheduled")
        if testament then
            local values_echo = c.testament.echo
            packet.echo = {force_index = force.index, surface_index = contact.surface_index, position = contact.position,
                primary = target, source = source, damage = values_echo.damage * cache.multiplier,
                radius = values_echo.radius, cap = values_echo.cap, testament = true, include_primary = true,
                phase = "echo", due = contact.due + values_echo.delay}
            schedule(runtime, packet.echo)
            count(runtime, "echoes_scheduled")
        end
    end
    record.contacts = record.contacts or scheduler.ensure_queue(nil)
    local first = not scheduler.queue_peek(record.contacts)
    scheduler.queue_push(record.contacts, contact)
    record.contact_tail = contact
    if first then start_waypoint(record, contact, tick) end
    activate_head(runtime, record, tick)
    profile_end(profiler, "shot", tick)
end

---@param contact LanceContact
local function resolve_contact(runtime, contact, surface, force, tick)
    local target = observe_contact(runtime, contact)
    local record, context = contact.record, contact.context
    local entity = record.entity
    -- Detect script force changes even if the source has not fired again.
    if entity and entity.valid and entity.force.index ~= record.force_index then register(runtime, entity) end
    -- Publish the reached point before synchronous damage callbacks can admit a
    -- successor. Neither the displayed endpoint nor its creation success is truth.
    contact.planned_position = contact.position
    if record.force_index == contact.force_index and record.surface_index == contact.surface_index then
        record.logical_aim = {position = contact.position, primary = contact.primary,
            force_index = contact.force_index, surface_index = contact.surface_index}
    end
    local rays = contact.level >= 1 and incision_rays(contact.origin, contact.position, contact.range, contact.axial) or {}
    contact.rays = rays
    local collapse = contact.collapse
    if collapse then
        collapse.position = contact.position
        if collapse.echo then collapse.echo.position = contact.position end
    end
    if context.target ~= contact.primary or not context.tick or contact.due - context.tick >= contact.wound_timeout
        or not hostile(target, force) or contact.level < 2 then
        context.target, context.tick, context.stacks = nil, nil, 0
    end
    local stacks = contact.level >= 2 and math.min(context.stacks + 1, contact.wound_cap) or 0
    -- Damage consumes the previously earned bonus; a positive result banks the
    -- next stack. Old paid contacts lack this snapshot and retain their +20% start.
    local bonus_stacks = contact.level >= 2
        and math.min(context.stacks + (contact.wound_first_hit_stacks or 1), contact.wound_cap) or 0
    local amount = contact.direct_damage * (1 + bonus_stacks * contact.wound_step)
        * contact.primary_multiplier
    local source = lib.get_valid_entity(contact.source)
    if source and source.force ~= force then source = nil end
    local applied = damage(runtime, target, amount, force, source, true)
    if applied > 0 and contact.level >= 2 then
        context.target, context.tick, context.stacks = contact.primary, contact.due, stacks
        contact.wound_updated = true
    end
    if contact.level >= 1 then
        penetrate(runtime, surface, source, force, contact.primary, rays, contact.multiplier, contact, tick)
    end
    if not collapse then
        area_damage(runtime, surface, force, contact.position, contact.primary, source,
            contact.splash_damage, contact.splash_radius, contact.splash_cap)
    end
    -- Native damage callbacks may remove/change the source or reset research.
    local live = entity and entity.valid
    if live and entity.force.index ~= record.force_index then register(runtime, entity) end
    if record.wound_context == context and record.latest_target == contact.primary and live
        and runtime.lances[entity.unit_number] == record then
        record.target, record.wound_tick, record.stacks = context.target, context.tick, context.stacks
    end
    count(runtime, "contacts_applied")
end

local function contact_presentation(runtime, contact, surface, tick)
    local record, force = contact.record, game.forces[contact.force_index]
    local live = record.entity and record.entity.valid and runtime.lances[record.entity.unit_number] == record
        and record.entity.force == force and record.entity.surface == surface
    local visual = profile_start(runtime)
    if live and record.last_contact_visual == contact then
        beam_cue(runtime, record, surface, contact.origin, contact.position, contact.rays or {},
            contact.level, contact.testament, tick, contact.pivot)
        if contact.wound_updated and record.wound_context == contact.context and record.latest_target == contact.primary then
            if wound_cue(runtime, record, record.target, force) then wound_crown(runtime, record, tick) end
        end
    end
    local packet = contact.collapse
    if packet and not packet.resolved and packet.due > tick then
        local ttl = packet.due - tick
        packet.warning = animation(runtime, packet.testament and "testament-concentrated-warning" or "collapse-concentrated-warning",
            surface, packet.position, ttl, packet.radius / art.collapse_reference_radius, c.collapse.delay - ttl)
    end
    profile_end(visual, "shot-core", tick)
    if record.last_contact_visual == contact then
        local light = profile_start(runtime)
        destroy_cue(record.flash); destroy_cue(record.afterglow)
        -- Match the active main beam's endpoint color. Old saved beam handles may
        -- lack a palette index until their normal expiry; retain cyan for those.
        local palette = record.beam_light_index and "-" .. record.beam_light_index or ""
        record.flash = surface.create_entity{name = NAME .. "-contact-light" .. palette, position = contact.position}
        record.afterglow = surface.create_entity{name = NAME .. "-afterglow-light" .. palette, position = contact.position}
        count(runtime, "contact_lights", 2)
        profile_end(light, "contact-light", tick)
    end
end

-- Only active FIFO heads are visited. A later shot never changes an earlier deadline.
local function sweep(runtime, tick)
    local profiler = profile_start(runtime)
    for id, record in pairs(runtime.active_sweeps) do
        local contact = scheduler.queue_peek(record.contacts)
        if not contact or not record.entity or not record.entity.valid or record.entity.surface.index ~= contact.surface_index
            or record.entity.force.index ~= contact.force_index then
            stop_sweep(runtime, id)
            reset_beams(record)
        elseif tick < contact.due and tick > record.sweep_start then
            local turn_profiler = runtime.profiling_enabled and game.create_profiler()
            local target = observe_contact(runtime, contact)
            local from = record.sweep_from
            local duration = contact.due - record.sweep_start
            local previous = contact.policy and record.logical_aim or record.last_contact_visual
            -- Reacquiring the same living enemy stays locked, including movement.
            -- Damage still waits for its paid deadline. New targets must sweep.
            local locked = target and previous and previous.primary == target
                and previous.force_index == contact.force_index and previous.surface_index == contact.surface_index
            local fraction = locked and 1 or duration > 0
                and math.min(1, math.max(0, (tick - record.sweep_start) / duration)) or 1
            local endpoint
            if locked then endpoint = contact.position
            elseif contact.policy then
                local motion, pivot = contact.angular_motion, contact.pivot
                local goal, radius = bearing(pivot, contact.position, motion.goal_angle)
                -- Unwrap against the previous goal, not the original start. A
                -- moving enemy crossing +/-pi must not reverse the chosen arc.
                motion.goal_angle = motion.goal_angle + shortest_turn(motion.goal_angle, goal)
                if contact.policy.easing == "smoothstep" then fraction = fraction * fraction * (3 - 2 * fraction) end
                local angle = contact.first_acquisition and motion.goal_angle
                    or motion.from_angle + (motion.goal_angle - motion.from_angle) * fraction
                local length = motion.from_radius + (radius - motion.from_radius) * fraction
                endpoint = {x = pivot.x + math.cos(angle) * length, y = pivot.y + math.sin(angle) * length}
            else
                -- Grandfathered schema-13 contacts finish their old visual path.
                endpoint = {x = from.x + (contact.position.x - from.x) * fraction,
                    y = from.y + (contact.position.y - from.y) * fraction}
            end
            clear_extensions(record)
            local shape = contact.testament and "testament" or contact.level >= 1 and "axial" or "base"
            beam_segment(runtime, record, record.entity.surface,
                contact.pivot or {x = contact.origin.x + c.crystal_offset.x, y = contact.origin.y + c.crystal_offset.y},
                endpoint, shape, contact.testament, tick, contact.due - tick)
            count(runtime, "sweep_steps")
            if turn_profiler then
                local phase = not contact.policy and "sweep-legacy" or locked and "sweep-locked"
                    or contact.compressed_turn and "sweep-compressed"
                    or contact.first_acquisition and "sweep-first" or "sweep-turn"
                profile_end(turn_profiler, phase, tick)
            end
        end
    end
    runtime.visual_next_due = runtime.sweep_count > 0 and tick + 1 or nil
    profile_end(profiler, "sweep", tick)
end

function lance.has_tick_work(event)
    local runtime = storage.ei and storage.ei.singularity_lance
    if not runtime then return false end
    local tick = event and event.tick or game.tick
    return (runtime.next_due and runtime.next_due <= tick)
        or (runtime.visual_next_due and runtime.visual_next_due <= tick) or false
end

function lance.get_pending_work_count()
    local runtime = storage.ei and storage.ei.singularity_lance
    return runtime and runtime.pending + (runtime.sweep_count or 0) or 0
end

function lance.update(_limit, event)
    local runtime, tick = state(), event and event.tick or game.tick
    if (not runtime.next_due or runtime.next_due > tick)
        and (not runtime.visual_next_due or runtime.visual_next_due > tick) then return 0 end
    if runtime.profiling_enabled then profile_flush(tick) end
    local profiler, processed = profile_start(runtime), 0
    local total_profiler = profile_start(runtime)
    -- Normal exact-deadline service needs one bucket lookup. Keep the ordered
    -- catch-up helper for overdue work, including migration and fixture recovery.
    local due_packets = runtime.next_due == tick and scheduler.delayed_take_due(runtime.buckets, tick)
        or runtime.next_due and runtime.next_due < tick and scheduler.delayed_take_due_through(runtime.buckets, tick) or {}
    -- Paid deadlines are ordered before any optional presentation budget.
    for _, packet in ipairs(due_packets) do
        runtime.pending = runtime.pending - 1
        local surface, force = game.surfaces[packet.surface_index], game.forces[packet.force_index]
        local phase_profiler = profile_start(runtime)
        if packet.phase == "contact" then
            runtime.pending_contacts = runtime.pending_contacts - 1
            if surface and force then resolve_contact(runtime, packet, surface, force, tick) end
            local record = packet.record
            scheduler.queue_pop(record.contacts)
            -- A synchronous damage callback may have appended a newer tail.
            if record.contact_tail == packet then record.contact_tail = nil end
            record.last_contact_visual = packet
            local next_contact = scheduler.queue_peek(record.contacts)
            if next_contact then
                -- Its angular reservation is already paid. Promotion cannot add
                -- latency; start from the reached contact, even after catch-up.
                start_waypoint(record, next_contact, packet.due, packet.position)
                activate_head(runtime, record, tick)
            elseif record.entity and record.entity.valid then stop_sweep(runtime, record.entity.unit_number) end
            profile_end(phase_profiler, "contact", tick)
        else
            destroy_cue(packet.warning); packet.warning = nil
            if surface and force then
                area_damage(runtime, surface, force, packet.position, packet.primary, packet.source,
                    packet.damage, packet.radius, packet.cap, packet)
                count(runtime, "collapses_applied")
                count(runtime, packet.phase == "echo" and "echoes_applied" or "first_collapses_applied")
            end
            profile_end(phase_profiler, packet.phase == "echo" and "collapse-echo" or "collapse-first", tick)
        end
        packet.resolved = true
        processed = processed + 1
    end
    profile_end(profiler, "mechanics", tick)
    for _, packet in ipairs(due_packets) do
        local surface = game.surfaces[packet.surface_index]
        if surface then
            if packet.phase == "contact" then contact_presentation(runtime, packet, surface, tick)
            else
                local visual = profile_start(runtime)
                local impact = packet.phase == "echo" and "echo-impact" or packet.phase == "first"
                    and (packet.testament and "testament-concentrated-impact" or "collapse-concentrated-impact")
                    or (packet.testament and "testament-impact" or "collapse-impact")
                local echo = packet.echo
                if echo and not echo.resolved and echo.due > tick then
                    local ttl = echo.due - tick
                    echo.warning = animation(runtime, "echo-warning", surface, echo.position, ttl,
                        echo.radius / art.collapse_reference_radius, c.testament.echo.delay - c.collapse.delay - ttl)
                end
                animation(runtime, impact, surface, packet.position, art.impact_ticks, packet.radius / art.collapse_reference_radius)
                profile_end(visual, "impact-core", tick)
                local decoration = profile_start(runtime)
                decorate(runtime, surface, packet.position, tick, packet.testament, packet.source)
                profile_end(decoration, "decoration", tick)
            end
        end
    end
    runtime.next_due = scheduler.delayed_next_due_tick(runtime.buckets) or nil
    -- On a contact tick hold the beam at the reached waypoint; next tick starts
    -- its next transition. This also preserves the four-segment contact cue.
    if runtime.sweep_count > 0 then
        sweep(runtime, tick)
    else runtime.visual_next_due = nil end
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
    if record then
        reset_wound(record); reset_beams(record)
        destroy_cue(record.flash); destroy_cue(record.afterglow)
        stop_sweep(runtime, id)
        runtime.lances[id] = nil
    end
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
    local affected = {}
    for id, record in pairs(runtime.lances) do if record.surface_index == event.surface_index then remove(runtime, id) end end
    for due, bucket in pairs(runtime.buckets) do
        for index = #bucket, 1, -1 do
            if bucket[index].surface_index == event.surface_index then
                if bucket[index].phase == "contact" then
                    runtime.pending_contacts = runtime.pending_contacts - 1
                    local record = bucket[index].record
                    affected[record] = true
                    scheduler.queue_remove_value(record.contacts, bucket[index])
                end
                destroy_cue(bucket[index].warning); table.remove(bucket, index); runtime.pending = runtime.pending - 1
            end
        end
        if #bucket == 0 then runtime.buckets[due] = nil end
    end
    for record in pairs(affected) do
        record.contact_tail = scheduler.queue_peek_last(record.contacts)
        if record.logical_aim and record.logical_aim.surface_index == event.surface_index then record.logical_aim = nil end
        if lib.entity_check(record.entity) then
            local id = record.entity.unit_number
            stop_sweep(runtime, id)
            local contact = scheduler.queue_peek(record.contacts)
            if runtime.lances[id] == record and contact then
                start_waypoint(record, contact, event.tick); activate_head(runtime, record, event.tick)
            end
        end
    end
    runtime.next_due = scheduler.delayed_next_due_tick(runtime.buckets) or nil
    if runtime.sweep_count == 0 then runtime.visual_next_due = nil end
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
        if record.logical_aim and record.logical_aim.force_index == event.source_index then
            record.logical_aim.force_index = event.destination.index
        end
        if record.force_index == event.source_index then
            reset_wound(record); reset_beams(record); record.counter, record.force_index = 0, event.destination.index
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

---@param event ConfigurationChangedData|{tick: uint}|nil
function lance.check_global(event)
    -- Init/configuration callbacks may have no event tick. Capture that fallback
    -- once; event-owned rebuilds must use their supplied tick for every record.
    local runtime, tick = state(), event and event.tick or game.tick
    runtime.visual_config = c.resolve()
    for _, force in pairs(game.forces) do sync_force(runtime, force) end
    -- One discovery pass at initialization/configuration only; never on research.
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = NAME}) do register(runtime, entity) end
    end
    for id, record in pairs(runtime.lances) do
        if not lib.entity_check(record.entity) then remove(runtime, id)
        else
            record.effective_range = nil
            register(runtime, record.entity)
            set_status(record, capabilities(runtime, record.entity.force))
        end
    end
    if runtime.presentation_revision ~= art.revision then
        -- Upgrade only presentation. Saved meters, paid delayed buckets and
        -- due ticks must survive; never route this through legacy state replacement.
        for _, record in pairs(runtime.lances) do
            reset_beams(record); destroy_cue(record.mark)
            record.mark, record.wound_band = nil, nil
            local remaining = record.wound_tick and math.min(c.wound.timeout, c.wound.timeout - (tick - record.wound_tick)) or 0
            if record.stacks > 0 and remaining > 0 then
                wound_cue(runtime, record, record.target, record.entity.force, remaining)
            else
                -- A cosmetic rebuild must not detach a paid first acquisition:
                -- its shared context can legitimately have zero landed hits.
                -- Expiry is still evaluated at the next mechanical contact.
                record.target, record.wound_tick, record.stacks = nil, nil, 0
            end
        end
        -- Warning prototypes retain their name, frame count and speed. Existing
        -- Animation objects retain the correct phase, TTL and fixed aim point.
        runtime.presentation_revision = art.revision
    end
end
lance.on_configuration_changed = lance.check_global

---@param tick uint? Supplied by event-owned telemetry; omitted by eventless diagnostics.
function lance.get_runtime_status(tick)
    local runtime = state()
    return {module = "singularity-lance", version = VERSION, presentation_revision = runtime.presentation_revision, pending = runtime.pending,
        pending_due = runtime.next_due and runtime.next_due <= (tick or game.tick) and runtime.pending or 0, pending_damage = runtime.pending,
        impact_next_due_tick = runtime.next_due or 0, pending_visual_slices = 0, active_visual_jobs = runtime.sweep_count,
        pending_contacts = runtime.pending_contacts, visual_next_due_tick = runtime.visual_next_due or 0,
        visual_fidelity = runtime.visual_config.visual_fidelity, counters = runtime.counters,
        registered_lances = table_size(runtime.lances), profiling_enabled = runtime.profiling_enabled,
        qc_enabled = runtime.qc_enabled, target_update_ms = 0.5, hard_update_ms = 1}
end

---@param tick uint? Forward the diagnostic caller's clock when available.
function lance.get_qc_snapshot(tick)
    profile_flush(nil)
    local result, runtime = lance.get_runtime_status(tick), state()
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
