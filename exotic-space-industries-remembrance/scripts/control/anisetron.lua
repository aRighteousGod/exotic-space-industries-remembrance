--==============================================================================
-- ESIR FILE MAP
-- owns: prepaid ANISETRON twin beams and legacy facade bursts
-- loaded_by: control.lua
-- cadence: paid bursts/live attachments each tick; registered hover modifiers every four ticks; preset visual passes
-- forwarded_events: on_script_trigger_effect, on_entity_damaged, has_tick_work, updater, build, removal, teleport, rebuild
-- storage_roots: storage.ei.runtime_scheduler.modules.anisetron
-- gui_ids: native spider vehicle GUI
-- remote_interfaces: none
-- rebuild_on: serialized paid work resumes; init/configuration rebuild derived visuals and compensation
--==============================================================================
-- blueprint: .codex/esir/blueprints/anisetron.md#contract
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local config = require("lib/anisetron-config")
local art = require("lib/anisetron-graphics")
local beam_palette = require("lib/singularity-lance-config").presentation.beam_light_palette
local visuals = require("scripts/control/anisetron-visuals")
local mobility = require("scripts/control/anisetron-mobility")
local upgrades = require("scripts/control/anisetron-lance")
local module = {script_trigger_effect_id = config.charge_effect}
local TAU = math.pi * 2
assert(config.duration_ticks > 0 and config.contact_ticks > 0 and config.sweep_ticks > 0
    and config.sweep_ticks <= config.contact_ticks and config.arc_degrees > 0
    and config.arc_degrees <= 180, "Invalid ANISETRON burst tuning")

---@class AnisetronBeamState
---@field entity LuaEntity
---@field end_tick integer?
---@field beam LuaEntity?
---@field beam_light_index integer? Saved cosmetic choice, stable through heading-driven recreation.
---@field target LuaEntity?
---@field last_angle number?
---@field last_entity LuaEntity?
---@field direction integer
---@field from MapPosition?
---@field sweep_start integer?
---@field muzzle_index integer?
---@field visual_torso number?
---@field visual_tick integer?
---@field emitter string?
---@field from_entity LuaEntity?
---@field visual_index integer?
---@field halos LuaRenderObject[]?
---@field halo_palette_index integer? Last saved palette applied to the owned endpoint light.
---@field voice LuaEntity?
---@field endpoint MapPosition? Last logical aim; retained independently of beam creation.
---@field aim_angle number? Unwrapped bearing in radians, clockwise from north.
---@field aim_radius number?
---@field goal_angle number?
---@field from_angle number?
---@field from_radius number?
---@field aim_tick integer?
---@field acquired boolean?
---@field turn_start integer?
---@field turn_end integer?
---@field contact_tip MapPosition? Copied before damage can destroy its target.
---@field contact_until integer?
---@field hold_until integer?

---@class AnisetronBurst : AnisetronBeamState
---@field force_index integer
---@field surface_index integer
---@field quality string
---@field duration integer
---@field damage number
---@field start_tick integer?
---@field next_contact integer?
---@field contract_version integer?
---@field crown_damage number?
---@field facade_damage number?
---@field research_multiplier number? Snapshotted only when a new charge is paid.
---@field opening_target LuaEntity?
---@field channels table<string, AnisetronBeamState>?
---@field crown_range number? Snapshot; absent historical contracts retain 30.
---@field facade_range number?
---@field contact_ticks integer?
---@field lance table? Version-three prepaid coefficients, context and reserved pulse phase.

local function state()
    local runtime = scheduler.ensure_module_state("anisetron")
    runtime.active = runtime.active or {}
    return runtime
end

local function destroy_beam(burst)
    if lib.entity_check(burst.beam) then burst.beam.destroy() end
    burst.beam = nil
    visuals.destroy_weapon(burst)
end

local function destroy_voice(channel)
    if lib.entity_check(channel.voice) then channel.voice.destroy() end
    channel.voice = nil
end

-- Audio follows a native helper owned by the paid deadline, independent of core recreation and
-- startup graphics budgets. Missing targets stop only their own voice.
local function present_voice(channel, tick)
    local source = channel.entity
    if lib.entity_check(channel.voice) then channel.voice.teleport(source.position); return end
    channel.voice = source.surface.create_entity{
        name = config.vehicle.."-"..(channel.emitter or "facade").."-voice",
        position = source.position, force = source.force,
    }
    if lib.entity_check(channel.voice) then channel.voice.destructible = false end
end

-- Both sides of friendship/cease-fire are respected at every contact, including
-- diplomacy changes during a prepaid burst. Neutral entities are never targets.
local function hostile(source, target)
    if not lib.entity_check(target) or target.surface ~= source.surface
        or not target.health or target.health <= 0 or not target.is_military_target then return false end
    local a, b = source.force, target.force
    return a ~= b and b ~= game.forces.neutral
        and not a.get_friend(b) and not b.get_friend(a)
        and not a.get_cease_fire(b) and not b.get_cease_fire(a)
end

local function angle_in_range(source, target, range, box_range)
    range = range or config.range
    local dx, dy
    if box_range then
        -- Native Spidertron acquisition includes its body and the target's bounds.
        local a, b = source.bounding_box, target.bounding_box
        dx = math.max(0, a.left_top.x - b.right_bottom.x, b.left_top.x - a.right_bottom.x)
        dy = math.max(0, a.left_top.y - b.right_bottom.y, b.left_top.y - a.right_bottom.y)
    else
        local a, b = source.position, target.position
        dx, dy = b.x - a.x, b.y - a.y
    end
    return dx * dx + dy * dy <= range * range
end

local function twin(burst)
    return burst and (burst.contract_version == 2 or burst.contract_version == 3)
end

local function angle_in_arc(source, target)
    if not angle_in_range(source, target) then return nil end
    local a, b = source.position, target.position
    local dx, dy = b.x - a.x, b.y - a.y
    local relative = (math.atan2(dx, -dy) / TAU - source.torso_orientation + 0.5) % 1 - 0.5
    if math.abs(relative) <= config.arc_degrees / 720 then return relative end
end

-- A spatially bounded native query runs once per contact for paid bursts only.
-- Sorting by angle and unit number makes the left/right procession deterministic.
local function select_target(burst)
    local source = burst.entity
    local candidates = {}
    for _, target in pairs(source.surface.find_entities_filtered{
        position = source.position, radius = config.range, is_military_target = true,
    }) do
        if hostile(source, target) then
            local angle = angle_in_arc(source, target)
            if angle then candidates[#candidates + 1] = {entity = target, angle = angle} end
        end
    end
    table.sort(candidates, function(a, b)
        if a.angle ~= b.angle then return a.angle < b.angle end
        return (a.entity.unit_number or 0) < (b.entity.unit_number or 0)
    end)
    local count = #candidates
    if count == 0 then return nil end
    local index = burst.direction > 0 and 1 or count
    local previous
    for i, candidate in ipairs(candidates) do
        if candidate.entity == burst.last_entity then previous = i; break end
    end
    if previous then
        index = previous + burst.direction
        if index < 1 or index > count then
            burst.direction = -burst.direction
            index = math.max(1, math.min(count, previous + burst.direction))
        end
    elseif burst.last_angle then
        local found
        for i = 1, count do
            local j = burst.direction > 0 and i or count - i + 1
            if (candidates[j].angle - burst.last_angle) * burst.direction > 0.000001 then
                index = j; found = true; break
            end
        end
        if not found then
            burst.direction = -burst.direction
            index = burst.direction > 0 and math.min(2, count) or math.max(1, count - 1)
        end
    end
    burst.last_angle = candidates[index].angle
    burst.last_entity = candidates[index].entity
    return candidates[index].entity
end

-- blueprint-ref: .codex/esir/blueprints/anisetron.md#framing
---@param channel AnisetronBeamState
---@return integer
local function beam_light_index(channel)
    if not channel.beam_light_index then
        local runtime = state()
        runtime.light_random = runtime.light_random or game.create_random_generator()
        channel.beam_light_index = runtime.light_random(#beam_palette)
    end
    return channel.beam_light_index
end

local function render_core(channel, tick, endpoint)
    local source = channel.entity
    local index = visuals.direction_index(source, channel, tick)
    -- Source offsets are immutable; sustained-only graphics have no transparent
    -- start/end phase, so changing body headings cannot repeatedly hide the core.
    local shape = channel.emitter == "crown" and (channel.lance_level or 0) >= 1
        and ((channel.testament_until or 0) > tick and "-testament" or "-axial") or ""
    if channel.muzzle_index ~= index or channel.beam_shape ~= shape then destroy_beam(channel) end
    if not lib.entity_check(channel.beam) then
        channel.beam = source.surface.create_entity{
            name = config.vehicle .. (channel.emitter == "crown" and "-crown-beam" or "-beam")
                .. shape .. "-light-" .. beam_light_index(channel),
            position = source.position, source = source,
            source_offset = (art[channel.emitter or "facade"] or art.muzzle)[index][2],
            target = endpoint, cause = source, force = source.force,
            duration = math.max(1, channel.end_tick - tick),
        }
        channel.muzzle_index, channel.beam_shape = index, shape
    else channel.beam.set_beam_target(endpoint) end
    visuals.present_weapon(channel, tick, index, endpoint)
    present_voice(channel, tick)
end

-- Versionless paid work keeps its historical target/timing contract. A copied
-- impact point survives a lethal packet for presentation only.
local function present_legacy(burst, tick)
    local source, target = burst.entity, burst.target
    local endpoint
    if hostile(source, target) and angle_in_arc(source, target) then
        endpoint = target.position
        local progress = math.min(1, (tick - burst.sweep_start) / config.sweep_ticks)
        if burst.from and progress < 1 then
            progress = progress * progress * (3 - 2 * progress)
            endpoint = {x = burst.from.x + (endpoint.x - burst.from.x) * progress,
                        y = burst.from.y + (endpoint.y - burst.from.y) * progress}
        end
    elseif burst.contact_tip and tick < burst.contact_until then endpoint = burst.contact_tip end
    if endpoint then render_core(burst, tick, endpoint)
    else destroy_beam(burst); destroy_voice(burst) end
end

-- The tracked channels use the Lance's persistent angular waypoint pattern.
-- Bearings are unwrapped against their previous value, never rebuilt modulo a
-- full turn from the original start when either the source or target moves.
local function shortest_turn(from, goal) return (goal - from + math.pi) % TAU - math.pi end

local function bearing(origin, point)
    local dx, dy = point.x - origin.x, point.y - origin.y
    return math.atan2(dx, -dy), math.sqrt(dx * dx + dy * dy)
end

local function begin_turn(channel, goal, tick)
    local delta = shortest_turn(channel.aim_angle, goal)
    local policy = config.acquisition
    -- Smoothstep has a 1.5 peak derivative; reserve time for its peak speed.
    local duration = lib.clamp(math.ceil(math.abs(delta) * 360 / TAU
        * 1.5 / policy.degrees_per_tick), policy.minimum_ticks, policy.maximum_ticks)
    channel.acquired = false
    channel.turn_start, channel.turn_end = tick, tick + duration
    channel.from_angle, channel.from_radius = channel.aim_angle, channel.aim_radius
    channel.goal_angle = channel.aim_angle + delta
end

---@param channel AnisetronBeamState
---@param target LuaEntity?
---@param tick integer
local function set_target(channel, target, tick)
    if channel.target == target and channel.aim_angle then return end
    upgrades.target_changed(channel, target)
    channel.target, channel.acquired = target, false
    channel.aim_tick = nil
    if not target then return end
    local origin, point = channel.entity.position, target.position
    local goal, radius = bearing(origin, point)
    if not channel.endpoint then
        -- The native opener already acquired the first enemy. Retargeting from
        -- an existing signal must turn; first acquisition remains responsive.
        channel.aim_angle, channel.aim_radius = goal, radius
        channel.endpoint = {x = point.x, y = point.y}
        channel.acquired = true
        channel.turn_start, channel.turn_end = tick, tick
    else
        local from, distance = bearing(origin, channel.endpoint)
        channel.aim_angle, channel.aim_radius = from, distance
        begin_turn(channel, goal, tick)
    end
    channel.from_angle, channel.from_radius = channel.aim_angle, channel.aim_radius
    channel.goal_angle = channel.aim_angle + shortest_turn(channel.aim_angle, goal)
end

local function constrain_facade(channel)
    if channel.emitter == "crown" then return end
    local front = channel.entity.torso_orientation * TAU
    local half_arc = config.arc_degrees * TAU / 720
    local relative = shortest_turn(front, channel.aim_angle)
    local limited = front + lib.clamp(relative, -half_arc, half_arc)
    channel.aim_angle = channel.aim_angle + shortest_turn(channel.aim_angle, limited)
end

---@param channel AnisetronBeamState
---@param tick integer
local function advance_aim(channel, tick)
    local source, target = channel.entity, channel.target
    local eligible = hostile(source, target) and angle_in_range(source, target, channel.range, channel.box_range)
        and (channel.emitter == "crown" or angle_in_arc(source, target) ~= nil)
    if not eligible then
        if target then
            upgrades.target_changed(channel, nil)
            channel.target, channel.acquired = nil, false
            channel.hold_until = math.max(channel.contact_until or 0, tick + config.contact_hold_ticks)
        end
        -- A target's death must not erase the packet that just reached it.
        if channel.aim_angle and channel.endpoint then
            if channel.contact_tip and tick < (channel.contact_until or 0) then
                local goal, radius = bearing(source.position, channel.contact_tip)
                channel.aim_angle = channel.aim_angle + shortest_turn(channel.aim_angle, goal)
                channel.aim_radius = radius
            end
            constrain_facade(channel)
            local origin = source.position
            channel.endpoint = {x = origin.x + math.sin(channel.aim_angle) * channel.aim_radius,
                y = origin.y - math.cos(channel.aim_angle) * channel.aim_radius}
        end
        return
    end
    -- Old active v2 saves have targets but no angular tracking fields. Adopt
    -- that target lazily without replacing their payment, queue or deadline.
    if not channel.aim_angle then set_target(channel, target, tick) end
    if channel.aim_tick == tick then return end
    channel.aim_tick = tick
    local origin = source.position
    local goal, radius = bearing(origin, target.position)
    channel.goal_angle = channel.goal_angle + shortest_turn(channel.goal_angle, goal)
    local cap = config.acquisition.degrees_per_tick * TAU / 360
    if channel.acquired and math.abs(shortest_turn(channel.aim_angle, goal)) > cap then
        -- Teleports and very close crossings retain the lock but must reacquire
        -- its bearing rather than jumping across the craft in one tick.
        begin_turn(channel, goal, tick)
    end
    if channel.acquired then
        -- As with the Lance, the same living enemy stays tracked while moving.
        channel.aim_angle, channel.aim_radius = channel.goal_angle, radius
    else
        local span = channel.turn_end - channel.turn_start
        local fraction = span > 0 and lib.clamp((tick - channel.turn_start) / span, 0, 1) or 1
        local eased = fraction * fraction * (3 - 2 * fraction)
        local desired = channel.from_angle + (channel.goal_angle - channel.from_angle) * eased
        channel.aim_angle = channel.aim_angle + lib.clamp(desired - channel.aim_angle, -cap, cap)
        channel.aim_radius = channel.from_radius + (radius - channel.from_radius) * eased
        channel.acquired = fraction >= 1 and math.abs(shortest_turn(channel.aim_angle, goal)) < 0.000001
    end
    constrain_facade(channel)
    channel.endpoint = {x = origin.x + math.sin(channel.aim_angle) * channel.aim_radius,
        y = origin.y - math.cos(channel.aim_angle) * channel.aim_radius}
end

local function present_tracked(channel, tick)
    advance_aim(channel, tick)
    local live = lib.entity_check(channel.target)
    local hold = math.max(channel.contact_until or 0, channel.hold_until or 0)
    if channel.endpoint and (live or tick < hold) then render_core(channel, tick, channel.endpoint)
    else destroy_beam(channel); destroy_voice(channel) end
end

-- Version two has one bounded query and two independent retained target locks.
-- Stable distance/unit ordering is used only when a target becomes ineligible.
local function candidates(burst)
    local source, range = burst.entity, burst.crown_range or config.range
    local result = {}
    local origin, bounds = source.position, source.bounding_box
    local query = burst.lance and {area = {{bounds.left_top.x - range, bounds.left_top.y - range},
        {bounds.right_bottom.x + range, bounds.right_bottom.y + range}}, is_military_target = true}
        or {position = origin, radius = range, is_military_target = true}
    for _, target in pairs(source.surface.find_entities_filtered(query)) do
        if hostile(source, target) then
            local dx, dy = target.position.x - origin.x, target.position.y - origin.y
            result[#result + 1] = {entity = target, angle = (math.atan2(dx, -dy) / TAU) % 1,
                distance = dx * dx + dy * dy}
        end
    end
    table.sort(result, function(a, b)
        if a.angle ~= b.angle then return a.angle < b.angle end
        return (a.entity.unit_number or 0) < (b.entity.unit_number or 0)
    end)
    return result
end

local function crown_target(burst, channel, choices)
    local source = burst.entity
    if hostile(source, channel.target) and angle_in_range(source, channel.target, channel.range, channel.box_range) then return channel.target end
    if hostile(source, burst.opening_target) and angle_in_range(source, burst.opening_target, channel.range, channel.box_range) then
        return burst.opening_target
    end
    local selected, distance
    for _, choice in ipairs(choices) do
        if hostile(source, choice.entity) and angle_in_range(source, choice.entity, channel.range, channel.box_range)
            and (not distance or choice.distance < distance or (choice.distance == distance
                and (choice.entity.unit_number or 0) < (selected.unit_number or 0))) then
            selected, distance = choice.entity, choice.distance
        end
    end
    return selected
end

local function facade_target(burst, channel, choices)
    local source = burst.entity
    if hostile(source, channel.target) and angle_in_arc(source, channel.target) then return channel.target end
    if hostile(source, burst.opening_target) and angle_in_arc(source, burst.opening_target) then
        local target = burst.opening_target; burst.opening_target = nil; return target
    end
    burst.opening_target = nil
    local selected, distance
    for _, choice in ipairs(choices) do
        if hostile(source, choice.entity) and angle_in_arc(source, choice.entity)
            and (not distance or choice.distance < distance or (choice.distance == distance
                and choice.entity.unit_number < selected.unit_number)) then
            selected, distance = choice.entity, choice.distance
        end
    end
    return selected
end

local function destroy_burst(burst)
    destroy_beam(burst)
    destroy_voice(burst)
    visuals.destroy_weapon(burst)
    for _, channel in pairs(burst.channels or {}) do
        destroy_beam(channel); destroy_voice(channel); visuals.destroy_weapon(channel); upgrades.clear_channel(channel)
    end
end

local function dual_contact(burst, runtime, tick)
    local source = burst.entity
    burst.channels = burst.channels or {}
    for _, emitter in ipairs{"crown", "facade"} do
        burst.channels[emitter] = burst.channels[emitter] or {entity = source,
            emitter = emitter, direction = 1, end_tick = burst.end_tick}
    end
    local empowered = upgrades.pulse(burst)
    local choices = candidates(burst)
    for _, emitter in ipairs{"crown", "facade"} do
        if not lib.entity_check(source) or source.force.index ~= burst.force_index
            or source.surface.index ~= burst.surface_index then return end
        local channel = burst.channels[emitter]
        channel.range = emitter == "crown" and (burst.crown_range or config.range) or (burst.facade_range or config.range)
        channel.box_range = emitter == "crown" and burst.lance ~= nil
        channel.lance_level = emitter == "crown" and burst.lance and burst.lance.level or 0
        channel.wound_context = emitter == "crown" and burst.lance and burst.lance.context or nil
        local target
        if emitter == "crown" then target = crown_target(burst, channel, choices)
        else target = facade_target(burst, channel, choices) end
        set_target(channel, target, tick)
        advance_aim(channel, tick)
        -- Recheck after the crown's synchronous damage callback. A visually
        -- crossed entity cannot receive this packet, and turn time is never
        -- queued beyond the original paid deadline.
        if channel.acquired and hostile(source, target) and angle_in_range(source, target, channel.range, channel.box_range)
            and (emitter == "crown" or angle_in_arc(source, target) ~= nil) then
            local point = target.position
            channel.contact_tip = {x = point.x, y = point.y}
            channel.contact_until = tick + config.contact_hold_ticks
            visuals.contact(source, channel.contact_tip, tick, beam_light_index(channel))
            if emitter == "crown" and burst.lance then
                upgrades.contact(burst, channel, target, tick, empowered)
            else
                target.damage(emitter == "crown" and burst.crown_damage or burst.facade_damage,
                    source.force, "laser", source, source)
            end
            local counter = emitter.."_contacts"
            runtime.counters[counter] = (runtime.counters[counter] or 0) + 1
            runtime.counters.contacts = (runtime.counters.contacts or 0) + 1
        end
    end
end

-- blueprint-ref: .codex/esir/blueprints/anisetron.md#weapon
---@param event EventData.on_script_trigger_effect
function module.on_script_trigger_effect(event)
    local source = lib.get_valid_entity(event.source_entity)
    if not source or source.name ~= config.vehicle then source = lib.get_valid_entity(event.cause_entity) end
    if not source or source.name ~= config.vehicle then return end
    local runtime = state()
    local id = source.unit_number
    local owner = runtime.active[id]
    if not owner then owner = {queue = scheduler.ensure_queue()}; runtime.active[id] = owner end
    local quality = prototypes.quality[event.quality or "normal"]
    -- Like the Lance, paid work snapshots research once. Existing active and
    -- queued contracts retain their numeric damage across research/reloads.
    local research_multiplier = math.max(0, 1 + source.force.get_ammo_damage_modifier(config.ammo_damage_category))
    local damage_multiplier = quality.default_multiplier * research_multiplier
    local burst = {
        entity = source, force_index = source.force.index, surface_index = source.surface.index,
        quality = quality.name, direction = 1,
        duration = math.max(1, math.floor(config.duration_ticks *
            (1 + quality.level * config.duration_quality_bonus_per_level))),
        damage = config.contact_damage * quality.default_multiplier,
        contract_version = config.contract_version,
        crown_damage = config.crown_damage * damage_multiplier,
        facade_damage = config.facade_damage * damage_multiplier,
        research_multiplier = research_multiplier,
        opening_target = lib.get_valid_entity(event.target_entity),
    }
    upgrades.admit(burst, damage_multiplier)
    scheduler.queue_push(owner.queue, burst)
    runtime.counters.paid = (runtime.counters.paid or 0) + 1
    runtime.last_tick = event.tick
end

-- blueprint-ref: .codex/esir/blueprints/anisetron.md#dispatch
-- Paid owners stay hot for native beam tracking. Child clocks also admit work
-- after a paid owner disappears; committed pulses and mobility are independent.
---@param event EventData.on_tick
---@return boolean
function module.has_tick_work(event)
    local runtime = storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    if not runtime then return false end
    if runtime.active and next(runtime.active) ~= nil then return true end
    return mobility.has_tick_work(event.tick) or visuals.has_tick_work(event.tick)
        or upgrades.has_tick_work(event.tick)
end

---@param event EventData.on_tick
function module.updater(event)
    mobility.update(event.tick)
    visuals.update(event.tick)
    upgrades.update(event.tick)
    local runtime = storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    if not runtime or not runtime.active or not next(runtime.active) then return end
    local tick = event.tick
    runtime.last_tick = tick
    for id, owner in pairs(runtime.active) do
        -- One bounded handoff keeps new paid contracts contiguous. A legacy
        -- next record retains its historical one-tick FIFO handoff.
        for _ = 1, 2 do
            local burst = owner.burst or scheduler.queue_pop(owner.queue)
            owner.burst = burst
            if burst then
                local source = lib.get_valid_entity(burst.entity)
                if not source or source.force.index ~= burst.force_index or source.surface.index ~= burst.surface_index then
                    destroy_burst(burst); runtime.active[id] = nil; upgrades.remove(id)
                    break
                else
                    if not burst.start_tick then
                        burst.start_tick, burst.end_tick, burst.next_contact = tick, tick + burst.duration, tick
                    end
                    -- Half-open paid interval yields exactly 100 normal contacts, never 101.
                    if tick >= burst.end_tick then
                        local next_burst = scheduler.queue_peek(owner.queue)
                        if twin(burst) and twin(next_burst) then
                            -- A new charge renews the signal, not its aim. Carry
                            -- locks and interpolation across contiguous paid work.
                            next_burst.channels, burst.channels = burst.channels, nil
                            for _, channel in pairs(next_burst.channels or {}) do
                                destroy_beam(channel)
                                upgrades.clear_channel(channel)
                                channel.end_tick = tick + next_burst.duration
                            end
                        end
                        destroy_burst(burst); owner.burst = nil
                        if not next_burst then runtime.active[id] = nil; break end
                        if not twin(next_burst) then break end
                    else
                        if tick >= burst.next_contact then
                            if twin(burst) then
                                dual_contact(burst, runtime, tick)
                            else
                                -- Grandfather already-paid records and FIFO entries.
                                local target = lib.get_valid_entity(burst.target)
                                if not hostile(source, target) or not angle_in_arc(source, target) then
                                    target = select_target(burst)
                                end
                                burst.next_contact = tick + (burst.contact_ticks or config.contact_ticks)
                                if target then
                                    burst.from = {x = target.position.x, y = target.position.y}
                                    burst.contact_tip, burst.contact_until = burst.from, tick + config.contact_hold_ticks
                                    target.damage(burst.damage, source.force, "laser", source, source)
                                    runtime.counters.contacts = (runtime.counters.contacts or 0) + 1
                                end
                                if lib.entity_check(source) then
                                    burst.target, burst.sweep_start = select_target(burst), tick
                                end
                            end
                            burst.next_contact = tick + (burst.contact_ticks or config.contact_ticks)
                        end
                        if lib.entity_check(source) and source.force.index == burst.force_index
                            and source.surface.index == burst.surface_index and runtime.active[id] == owner then
                            if twin(burst) then
                                for _, emitter in ipairs{"crown", "facade"} do present_tracked(burst.channels[emitter], tick) end
                            else present_legacy(burst, tick) end
                        else destroy_burst(burst); runtime.active[id] = nil end
                        break
                    end
                end
            else runtime.active[id] = nil; break end
        end
    end
end

---@param event table
function module.on_built_entity(event)
    local entity = lib.get_valid_entity(event.destination or event.entity or event.created_entity)
    -- A copied sound helper has no paid owner. Native vehicle cloning must not
    -- leave an independent permanent voice behind.
    if entity and (entity.name == config.vehicle.."-crown-voice"
        or entity.name == config.vehicle.."-facade-voice") then
        entity.destroy()
        return
    end
    visuals.on_built_entity(event)
    mobility.on_built_entity(event)
end
---@param event EventData.on_entity_damaged
function module.on_entity_damaged(event) mobility.on_entity_damaged(event) end
---@param event EventData.script_raised_teleported
function module.on_teleported(event)
    visuals.on_teleported(event)
    mobility.on_teleported(event)
end
---@param event table
function module.on_destroyed_entity(event)
    visuals.on_destroyed_entity(event)
    mobility.on_destroyed_entity(event)
    local id = lib.get_entity_unit_number(event.entity)
    local runtime = storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    upgrades.remove(id)
    local owner = runtime and runtime.active and id and runtime.active[id]
    if owner then
        if owner.burst then destroy_burst(owner.burst) end
        runtime.active[id] = nil
    end
end
---@param tick integer
function module.rebuild_visuals(tick)
    visuals.rebuild(tick)
    mobility.rebuild(tick)
    upgrades.rebuild(tick)
    local runtime = storage.ei and storage.ei.runtime_scheduler
        and storage.ei.runtime_scheduler.modules.anisetron
    for _, owner in pairs(runtime and runtime.active or {}) do
        if owner.burst then
            destroy_burst(owner.burst)
            owner.burst.muzzle_index = nil
            for _, channel in pairs(owner.burst.channels or {}) do channel.muzzle_index = nil end
        end
    end
    -- Exact one-time cleanup also catches helpers whose source was removed
    -- while this feature was unavailable; no periodic surface scan owns audio.
    for _, surface in pairs(game.surfaces) do
        for _, voice in pairs(surface.find_entities_filtered{
            name = {config.vehicle.."-crown-voice", config.vehicle.."-facade-voice"},
        }) do voice.destroy() end
    end
end

module.on_research_finished = upgrades.on_research_finished
module.on_scripted_research_burst = upgrades.refresh_force
module.on_force_reset = upgrades.on_force_reset
module.on_diplomacy_changed = upgrades.on_diplomacy_changed
module.on_forces_merged = upgrades.on_forces_merged
module.on_surface_deleted = upgrades.on_surface_deleted
module.on_object_destroyed = upgrades.on_object_destroyed
function module.get_lance_qc_snapshot() return upgrades.snapshot() end
function module.get_qc_snapshot() return visuals.snapshot() end
---@param limit integer?
---@param event table
function module.service_visuals_for_qc(limit, event) return visuals.service(event.tick, limit) end

return module
