--==============================================================================
-- ESIR FILE MAP
-- owns: ANISETRON movement filaments and budgeted weapon decoration
-- loaded_by: scripts/control/anisetron.lua
-- cadence: startup preset movement service; core weapon presentation calls
-- forwarded_events: has_tick_work, update, on_built_entity, on_destroyed_entity, on_teleported, rebuild
-- storage_roots: storage.ei.runtime_scheduler.modules.anisetron.visuals
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: initialization and configuration changes; preserves paid work
--==============================================================================
-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#visuals
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("lib/anisetron-visual-config")
local art = require("lib/anisetron-graphics")
local beam_palette = require("lib/singularity-lance-config").presentation.beam_light_palette
local module = {}
local preset
local TAU = math.pi * 2
local VISUAL_REVISION = 6

---@class AnisetronMovementRecord
---@field entity LuaEntity
---@field last_position MapPosition
---@field last_tick integer
---@field surface_index integer
---@field moving boolean
---@field strands LuaRenderObject[]
---@field motion_light LuaRenderObject?
---@field trail_angle number? Last sampled screen-space trail orientation.
---@field trail_length number? Last admitted strand length in tiles.
---@field applied_index integer? Last geometry written to owned render handles.
---@field applied_angle number?
---@field applied_length number?
---@field applied_lift number?

local function tuning()
    preset = preset or config.resolve()
    return preset
end

local function raw_state()
    local runtime = storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    return runtime and runtime.visuals
end

local function state()
    local runtime = scheduler.ensure_module_state("anisetron")
    runtime.visuals = runtime.visuals or {tracked = {}, queue = scheduler.ensure_queue(),
        counters = {}, transients = {}, weapon_tick = -1, weapon_created = 0}
    runtime.visuals.attached = runtime.visuals.attached or {}
    return runtime.visuals
end

local function valid(handle) return handle and handle.valid end
local function remove(handle) if valid(handle) then handle.destroy() end end
local function clear_strands(record)
    record.strands = record.strands or {}
    for tip, handle in pairs(record.strands) do remove(handle); record.strands[tip] = nil end
    remove(record.motion_light); record.motion_light = nil
    record.applied_index, record.applied_angle, record.applied_length, record.applied_lift = nil, nil, nil, nil
end

local function transient(runtime, handle, kind)
    runtime.transients[#runtime.transients + 1] = {handle = handle, kind = kind}
end

local function budget(tick, count)
    local p = tuning()
    if not p.enabled then return false end
    local runtime = state()
    if runtime.weapon_tick ~= tick then runtime.weapon_tick, runtime.weapon_created = tick, 0 end
    if p.weapon_cap and runtime.weapon_created + count > p.weapon_cap then
        runtime.counters.weapon_capped = (runtime.counters.weapon_capped or 0) + count
        return false
    end
    runtime.weapon_created = runtime.weapon_created + count
    return true
end

local function light(source, target, color, ttl, intensity, scale)
    return rendering.draw_light{sprite = "utility/light_medium", surface = source.surface,
        target = target, color = color, intensity = intensity, scale = scale,
        minimum_darkness = 0, time_to_live = ttl}
end

local function attachment_lift(source)
    local curve = config.attachment_lift
    if curve.span == 0 then return curve.minimum end
    return curve.minimum + curve.span * lib.clamp(math.abs(source.speed) / curve.speed, 0, 1)
end

---@param channel AnisetronBeamState
function module.destroy_weapon(channel)
    for _, handle in pairs(channel.halos or {}) do remove(handle) end
    channel.halos = nil
end

---@param channel AnisetronBeamState
---@param tick integer
---@param index integer
---@param endpoint MapPosition
function module.present_weapon(channel, tick, index, endpoint)
    local p = tuning()
    if not p.enabled then module.destroy_weapon(channel); return end
    channel.halos = channel.halos or {}
    local source = channel.entity
    -- The native beam's start sprite supplies the origin flare and aligned
    -- glow. Script entity-target lights cannot follow the native torso heave.
    remove(channel.halos[1]); channel.halos[1] = nil
    local color = beam_palette[channel.beam_light_index or 1]
    local handle = channel.halos[2]
    if not valid(handle) and budget(tick, 1) then
        handle = light(source, endpoint, color, 12, p.halo_alpha, .12)
        channel.halos[2] = handle
    end
    if valid(handle) then
        handle.target = endpoint; handle.time_to_live = 12
        -- Intensity is fixed by the startup preset; palette only changes when
        -- a channel receives another saved color. Position/expiry stay per tick.
        if channel.halo_palette_index ~= channel.beam_light_index then handle.color = color end
        channel.halo_palette_index = channel.beam_light_index
    end
end

---@param source LuaEntity
---@param position MapPosition
---@param tick integer
---@param palette_index integer?
function module.contact(source, position, tick, palette_index)
    local p = tuning()
    if not p.enabled or not budget(tick, 2) then return end
    local runtime = state()
    local color = beam_palette[palette_index or 1]
    transient(runtime, rendering.draw_circle{surface = source.surface, target = position,
        color = {r = color.r, g = color.g, b = color.b, a = .65}, radius = .10, width = 1,
        filled = false, draw_on_ground = false,
        time_to_live = p.flash_ttl}, "flash")
    transient(runtime, light(source, position, color, p.flash_ttl, p.halo_alpha, .16), "light")
end

---@param event table
function module.on_built_entity(event)
    if not tuning().enabled then return end
    local entity = lib.get_valid_entity(event.entity or event.created_entity or event.destination)
    if not entity or entity.name ~= "ei-anisetron" then return end
    local runtime = state()
    local id = entity.unit_number
    if runtime.tracked[id] then return end
    local tick = event.tick
    if tick == nil then tick = game.tick end
    runtime.tracked[id] = {entity = entity, last_position = {x = entity.position.x, y = entity.position.y},
        last_tick = tick, surface_index = entity.surface.index, moving = false, strands = {}}
    scheduler.queue_push_unique(runtime.queue, id)
end

---@param event table
function module.on_destroyed_entity(event)
    local entity = event.entity
    local id = lib.get_entity_unit_number(entity)
    local runtime = raw_state()
    local record = runtime and id and runtime.tracked[id]
    if record then
        clear_strands(record); runtime.tracked[id] = nil
        scheduler.queue_remove_value(runtime.queue, id)
    end
end

---@param event EventData.script_raised_teleported
function module.on_teleported(event)
    local source = lib.get_valid_entity(event.entity)
    local runtime = raw_state()
    local id = lib.get_entity_unit_number(source)
    local record = runtime and id and runtime.tracked[id]
    if not record then return end
    clear_strands(record)
    record.last_position = {x = source.position.x, y = source.position.y}
    record.last_tick, record.surface_index = event.tick, source.surface.index
    record.moving = false
    record.visual_tick, record.visual_index, record.visual_torso = nil, nil, nil
    runtime.attached[id] = nil
end

-- Shared calibrated pose lookup for native beams and attached decorations.
-- Physics follows on_tick; lead only consecutive full native torso steps.
---@param entity LuaEntity
---@param history table
---@param tick integer
function module.direction_index(entity, history, tick)
    if history.visual_tick == tick and history.visual_index then return history.visual_index end
    local count = art.direction_count
    local torso, visual = entity.torso_orientation, entity.torso_orientation
    if history.visual_tick == tick - 1 and entity.active then
        local delta = (torso - history.visual_torso + .5) % 1 - .5
        local step = entity.prototype.torso_rotation_speed or 0
        if step > 0 and math.abs(math.abs(delta) - step) < .000001 then
            visual = (torso + lib.clamp(delta, -step, step)) % 1
        end
    end
    history.visual_torso, history.visual_tick = torso, tick
    history.visual_index = math.floor(visual * count + .5) % count + 1
    return history.visual_index
end

---@param tip integer
---@param index integer
---@param angle number?
---@param length number?
---@return boolean
local function strand_visible(tip, index, angle, length)
    if art.keel_visibility and not art.keel_visibility[tip][index] then return false end
    local row = art.keel_trail_clearance and art.keel_trail_clearance[tip][index]
    if not row then return true end
    -- Native animation orientation rotates clockwise in screen coordinates.
    local direction = math.floor((angle or 0) % 1 * #row) % #row + 1
    -- Both neighboring directions must clear the hull, including between bins.
    return math.min(row[direction], row[direction % #row + 1]) + .000001 >= (length or 1.4)
end

-- Script animation targets are centers. A prototype shift is not multiplied
-- with x_scale, so stretching a shifted sprite pulled its root into the hull.
---@param source LuaEntity
---@param offset number[]
---@param tail_x number
---@param tail_y number
---@param lift number
---@return ScriptRenderTarget
local function strand_target(source, offset, tail_x, tail_y, lift)
    return {entity = source, offset = {
        offset[1] + tail_x,
        offset[2] - lift + tail_y,
    }}
end

local function service_record(runtime, record, tick, pass)
    local source = lib.get_valid_entity(record.entity)
    if not source then clear_strands(record); return false end
    local position = source.position
    local dx, dy = position.x - record.last_position.x, position.y - record.last_position.y
    local elapsed = tick - record.last_tick
    local distance = math.sqrt(dx * dx + dy * dy)
    local speed = elapsed > 0 and distance / elapsed or 0
    local teleported = record.surface_index ~= source.surface.index or speed > 2
    local p = tuning()
    record.last_position, record.last_tick = {x = position.x, y = position.y}, tick
    record.surface_index = source.surface.index
    if teleported then speed = 0 end
    record.moving = speed >= (record.moving and p.movement_stop or p.movement_start)
    if not record.moving or not art.keel_tips then clear_strands(record); return true end
    local index = module.direction_index(source, record, tick)
    -- Project a downward fall with a smaller component opposite travel. The
    -- same screen-space angle drives both native rotation and hull clearance.
    local nx, ny = -.55 * dx / distance, .8 - .35 * dy / distance
    local length = lib.clamp(.7 + speed * 6, .7, 1.4)
    local angle = (math.atan2(ny, nx) / TAU) % 1
    record.trail_angle, record.trail_length = angle, length
    local lift = attachment_lift(source)
    local changed = record.applied_index ~= index or record.applied_angle ~= angle
        or record.applied_length ~= length or record.applied_lift ~= lift
    local tail_x, tail_y = math.cos(angle * TAU) * length * .5, math.sin(angle * TAU) * length * .5
    for tip = 1, #art.keel_tips do
        local offset = art.keel_tips[tip][index][2]
        local handle = record.strands[tip]
        if not valid(handle) and (not p.strand_cap or pass.strands_created < p.strand_cap) then
            handle = rendering.draw_animation{animation = "ei-anisetron-movement-strand",
                surface = source.surface, target = strand_target(source, offset, tail_x, tail_y, lift), orientation = angle,
                animation_speed = .5, animation_offset = (tip * 5) % 16,
                visible = strand_visible(tip, index, angle, length),
                x_scale = length / .5, y_scale = .65, render_layer = "light-effect",
                time_to_live = p.strand_ttl}
            record.strands[tip] = handle; pass.strands_created = pass.strands_created + 1
        elseif valid(handle) then
            if changed then
                handle.visible = strand_visible(tip, index, angle, length)
                handle.target = strand_target(source, offset, tail_x, tail_y, lift)
                handle.orientation = angle; handle.x_scale = length / .5
            end
            handle.time_to_live = p.strand_ttl
        end
    end
    runtime.attached[source.unit_number] = record
    -- In 2.0 the script animation remains subject to night lighting. One small
    -- shared native light makes the eight filaments readable without additional
    -- strand handles. Its creation shares the existing decoration budget.
    local center = art.keel_base_center[index][2]
    local light_target = {entity = source, offset = {center[1], center[2] - lift}}
    if not valid(record.motion_light) and budget(tick, 1) then
        record.motion_light = light(source, light_target, {r = .3, g = 1, b = .5},
            p.strand_ttl, math.min(1, .4 + p.halo_alpha), .38)
    end
    if valid(record.motion_light) then
        if changed then record.motion_light.target = light_target end
        record.motion_light.time_to_live = p.strand_ttl
    end
    record.applied_index, record.applied_angle, record.applied_length, record.applied_lift = index, angle, length, lift

    return true
end

-- Snapshot membership before any requeue, including Unbounded and QC overrides.
-- A self-replenishing while-loop would revisit one vehicle indefinitely.
---@param tick integer
---@param limit integer?
function module.service(tick, limit)
    local runtime = raw_state()
    if not runtime or not tuning().enabled then return 0 end
    local count = scheduler.table_count(runtime.queue.queued)
    local cap = limit or tuning().service_cap or count
    local ids = {}
    for _ = 1, math.min(count, math.max(0, cap)) do
        local id = scheduler.queue_pop_queued(runtime.queue)
        if not id then break end
        ids[#ids + 1] = id
    end
    local pass = {tick = tick, visited_units = {}, strands_created = 0}
    for _, id in ipairs(ids) do
        local record = runtime.tracked[id]
        if record then
            pass.visited_units[#pass.visited_units + 1] = id
            if service_record(runtime, record, tick, pass) then scheduler.queue_push_unique(runtime.queue, id)
            else runtime.tracked[id] = nil end
        end
    end
    runtime.last_pass = pass
    return #pass.visited_units
end

---@param tick integer
---@return boolean
function module.has_tick_work(tick)
    local runtime = raw_state()
    if not runtime then return false end
    -- Cold local configuration after load and old visual schemas are admitted
    -- to ordinary service. The predicate itself never resolves/repairs state.
    if runtime.revision ~= VISUAL_REVISION or not preset then return true end
    if runtime.attached and next(runtime.attached) ~= nil then return true end
    if runtime.transients and #runtime.transients > 0 then return true end
    return preset.enabled and tick % preset.update_interval == 0
        and next(runtime.queue.queued) ~= nil
end

---@param tick integer
function module.update(tick)
    local runtime = raw_state()
    if not runtime then return end
    -- New attachment metadata replaces the old three-root strands and motes.
    -- Rebuild presentation once; the separate paid weapon state is untouched.
    if runtime.revision ~= VISUAL_REVISION then module.rebuild(tick); runtime = raw_state() end
    local p = tuning()
    -- Compact the owned finite-effect list in place, including a zero-allocation
    -- empty path. This is an array of render handles, not a scheduler queue.
    local living = 0
    for _, entry in ipairs(runtime.transients) do
        if valid(entry.handle) then living = living + 1; runtime.transients[living] = entry end
    end
    for index = #runtime.transients, living + 1, -1 do runtime.transients[index] = nil end
    -- Sampling controls admission/density, while live roots follow the same
    -- per-tick body pose as the core beams. Only finite-lived handles are hot.
    for id, record in pairs(runtime.attached or {}) do
        local source = lib.get_valid_entity(record.entity)
        local any = false
        if source and art.keel_tips then
            local index = module.direction_index(source, record, tick)
            local lift = attachment_lift(source)
            -- Entity targets already follow translation natively. Rewrite only
            -- changed projected geometry; pose sampling, validity and finite
            -- expiry still run every tick, including between fleet visits.
            local changed = record.applied_index ~= index or record.applied_angle ~= record.trail_angle
                or record.applied_length ~= record.trail_length or record.applied_lift ~= lift
            local tail_x, tail_y
            if changed then
                tail_x = math.cos(record.trail_angle * TAU) * record.trail_length * .5
                tail_y = math.sin(record.trail_angle * TAU) * record.trail_length * .5
            end
            for tip, handle in pairs(record.strands) do
                if valid(handle) then
                    if changed then
                        handle.visible = strand_visible(tip, index, record.trail_angle, record.trail_length)
                        local offset = art.keel_tips[tip][index][2]
                        handle.target = strand_target(source, offset, tail_x, tail_y, lift)
                    end
                    -- Keep an admitted filament alive between bounded fleet visits.
                    -- Loss of its source/ownership still leaves only a 12-tick tail.
                    handle.time_to_live = p.strand_ttl
                    any = true
                end
            end
            if any and valid(record.motion_light) then
                if changed then
                    local offset = art.keel_base_center[index][2]
                    record.motion_light.target = {entity = source, offset = {offset[1], offset[2] - lift}}
                end
                record.motion_light.time_to_live = p.strand_ttl
            end
            record.applied_index, record.applied_angle, record.applied_length, record.applied_lift =
                index, record.trail_angle, record.trail_length, lift
        end
        if not any then runtime.attached[id] = nil end
    end
    if p.enabled and tick % p.update_interval == 0 then module.service(tick) end
end

---@param tick integer
function module.rebuild(tick)
    local runtime = raw_state()
    if runtime then
        for _, record in pairs(runtime.tracked) do clear_strands(record) end
        for _, entry in ipairs(runtime.transients) do remove(entry.handle) end
    end
    preset = nil
    runtime = state()
    runtime.tracked, runtime.queue, runtime.transients, runtime.attached = {}, scheduler.ensure_queue(), {}, {}
    runtime.last_pass, runtime.weapon_tick, runtime.weapon_created = nil, -1, 0
    runtime.revision = VISUAL_REVISION
    if not tuning().enabled then return end
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered{name = "ei-anisetron"}) do
            module.on_built_entity{entity = entity, tick = tick}
        end
    end
end

function module.snapshot()
    local runtime = raw_state()
    local result = {visual_fidelity = tuning().visual_fidelity, enabled = tuning().enabled,
        tracked_count = 0, live_strands = 0, live_motes = 0, live_flashes = 0,
        live_lights = 0, live_halos = 0, per_vehicle = {}, last_pass = runtime and runtime.last_pass,
        weapon_tick = runtime and runtime.weapon_tick, weapon_created = runtime and runtime.weapon_created}
    for id, record in pairs(runtime and runtime.tracked or {}) do
        result.tracked_count = result.tracked_count + 1
        local strands = 0
        for _, handle in pairs(record.strands) do if valid(handle) then strands = strands + 1 end end
        result.live_strands = result.live_strands + strands
        if valid(record.motion_light) then result.live_lights = result.live_lights + 1 end
        result.per_vehicle[id] = {moving = record.moving, strands = strands}
    end
    for _, entry in ipairs(runtime and runtime.transients or {}) do
        if valid(entry.handle) then
            local key = entry.kind == "mote" and "live_motes" or entry.kind == "flash" and "live_flashes" or "live_lights"
            result[key] = result[key] + 1
        end
    end
    local owner = storage.ei and storage.ei.runtime_scheduler and storage.ei.runtime_scheduler.modules.anisetron
    for _, record in pairs(owner and owner.active or {}) do
        local burst = record.burst
        if burst then
            local channels = burst.channels or {legacy = burst}
            for _, channel in pairs(channels) do
                for _, handle in pairs(channel.halos or {}) do if valid(handle) then result.live_halos = result.live_halos + 1 end end
            end
        end
    end
    return result
end
return module
