--==============================================================================
-- ESIR FILE MAP
-- owns: Oathbreaker Saw runtime blade overlay and attack sound gate
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: build/destroy/script trigger effects and render-object destruction only; no steady polling
-- forwarded_events: check_global, get_runtime_status, on_built_entity, on_configuration_changed, on_destroyed_entity, on_object_destroyed, on_script_trigger_effect, rebuild_runtime_state, reset_runtime_state
-- storage_roots: storage.ei.sawblade_turret
-- storage_shape: render-object ownership by turret unit plus one attack-sound gate per turret
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: runtime schema changes, animation prototype changes, attack sound duration changes
--==============================================================================

local model = {}

local ei_lib = require("lib/lib")

local RUNTIME_VERSION = 5
local TURRET_NAME = "ei-sawblade-turret"
local SHOT_EFFECT_ID = TURRET_NAME.."-shot"
local STATIC_BLADE_ANIMATION_NAME = TURRET_NAME.."-blade-static"
local SPIN_ANIMATION_NAME = TURRET_NAME.."-spin"
local FRAME_COUNT = 64
local SPIN_TTL = 45
local SPIN_ANIMATION_SPEED = 1.0
local ATTACK_SOUND_PREFIX = TURRET_NAME.."-attack-sound-"
local ATTACK_SOUND_PAD_TICKS = 6
-- These are the trimmed clip lengths in ticks. They intentionally gate per
-- turret, not globally, so one saw cannot overlap itself while two saws can
-- still be heard as two machines.
local ATTACK_SOUND_DURATIONS = {
    180,
    177,
    187,
    239,
    243,
}
local ATTACK_SOUND_COUNT = #ATTACK_SOUND_DURATIONS

local runtime_state

local COUNTER_NAMES = {
    "shot_triggers",
    "static_created",
    "static_destroyed",
    "spin_created",
    "spin_refreshed",
    "spin_destroyed",
    "spin_expired",
    "attack_sounds_played",
    "attack_sounds_gated",
    "attack_sound_errors",
    "invalid_events",
}

local function new_counters()
    return {
        shot_triggers = 0,
        static_created = 0,
        static_destroyed = 0,
        spin_created = 0,
        spin_refreshed = 0,
        spin_destroyed = 0,
        spin_expired = 0,
        attack_sounds_played = 0,
        attack_sounds_gated = 0,
        attack_sound_errors = 0,
        invalid_events = 0,
    }
end

local function new_state()
    return {
        version = RUNTIME_VERSION,
        blade_renders_by_unit = {},
        blade_modes_by_unit = {},
        entities_by_unit = {},
        render_registrations_by_unit = {},
        units_by_render_registration = {},
        render_kinds_by_registration = {},
        next_sound_tick_by_unit = {},
        last_sound_index_by_unit = {},
        counters = new_counters(),
    }
end

local function get_stored_state()
    local ei_state = storage.ei
    local state = ei_state and ei_state.sawblade_turret
    if type(state) == "table" and state.version == RUNTIME_VERSION then
        return state
    end

    return nil
end

-- Any version mismatch rebuilds from world entities. Render objects are not
-- recoverable from stale tables across schema changes, so old state is treated
-- as disposable.
local function ensure_state()
    if runtime_state and runtime_state.version == RUNTIME_VERSION then
        return runtime_state
    end

    storage.ei = storage.ei or {}

    local state = storage.ei.sawblade_turret
    if type(state) ~= "table" or state.version ~= RUNTIME_VERSION then
        state = new_state()
        storage.ei.sawblade_turret = state
    end

    state.blade_renders_by_unit = type(state.blade_renders_by_unit) == "table" and state.blade_renders_by_unit or {}
    state.blade_modes_by_unit = type(state.blade_modes_by_unit) == "table" and state.blade_modes_by_unit or {}
    state.entities_by_unit = type(state.entities_by_unit) == "table" and state.entities_by_unit or {}
    state.render_registrations_by_unit = type(state.render_registrations_by_unit) == "table" and state.render_registrations_by_unit or {}
    state.units_by_render_registration = type(state.units_by_render_registration) == "table" and state.units_by_render_registration or {}
    state.render_kinds_by_registration = type(state.render_kinds_by_registration) == "table" and state.render_kinds_by_registration or {}
    state.next_sound_tick_by_unit = type(state.next_sound_tick_by_unit) == "table" and state.next_sound_tick_by_unit or {}
    state.last_sound_index_by_unit = type(state.last_sound_index_by_unit) == "table" and state.last_sound_index_by_unit or {}
    state.counters = type(state.counters) == "table" and state.counters or new_counters()
    for _, counter_name in ipairs(COUNTER_NAMES) do
        if state.counters[counter_name] == nil then
            state.counters[counter_name] = 0
        end
    end

    runtime_state = state
    return state
end

local function get_state_if_present()
    if runtime_state and runtime_state.version == RUNTIME_VERSION then
        return runtime_state
    end

    runtime_state = get_stored_state()
    return runtime_state
end

local function copy_counters(counters)
    return {
        shot_triggers = counters.shot_triggers or 0,
        static_created = counters.static_created or 0,
        static_destroyed = counters.static_destroyed or 0,
        spin_created = counters.spin_created or 0,
        spin_refreshed = counters.spin_refreshed or 0,
        spin_destroyed = counters.spin_destroyed or 0,
        spin_expired = counters.spin_expired or 0,
        attack_sounds_played = counters.attack_sounds_played or 0,
        attack_sounds_gated = counters.attack_sounds_gated or 0,
        attack_sound_errors = counters.attack_sound_errors or 0,
        invalid_events = counters.invalid_events or 0,
    }
end

local function forget_spin_registration(state, unit_number)
    local registration_number = state.render_registrations_by_unit[unit_number]
    if registration_number then
        state.units_by_render_registration[registration_number] = nil
        state.render_kinds_by_registration[registration_number] = nil
        state.render_registrations_by_unit[unit_number] = nil
    end
end

local function destroy_render(render_object)
    if not (render_object and render_object.valid) then
        return false
    end

    render_object.destroy()
    return true
end

local function destroy_blade_render(state, unit_number)
    if not unit_number then
        return
    end

    forget_spin_registration(state, unit_number)

    local mode = state.blade_modes_by_unit[unit_number]
    local render_object = state.blade_renders_by_unit[unit_number]
    if destroy_render(render_object) then
        if mode == "static" then
            state.counters.static_destroyed = state.counters.static_destroyed + 1
        else
            state.counters.spin_destroyed = state.counters.spin_destroyed + 1
        end
    end
    state.blade_renders_by_unit[unit_number] = nil
    state.blade_modes_by_unit[unit_number] = nil
end

local function destroy_all_blade_renders(state)
    if type(state) ~= "table" or type(state.blade_renders_by_unit) ~= "table" then
        return
    end

    state.blade_modes_by_unit = type(state.blade_modes_by_unit) == "table" and state.blade_modes_by_unit or {}
    state.render_registrations_by_unit = type(state.render_registrations_by_unit) == "table" and state.render_registrations_by_unit or {}
    state.units_by_render_registration = type(state.units_by_render_registration) == "table" and state.units_by_render_registration or {}
    state.render_kinds_by_registration = type(state.render_kinds_by_registration) == "table" and state.render_kinds_by_registration or {}
    state.counters = type(state.counters) == "table" and state.counters or new_counters()

    local existing_units = {}
    for unit_number in pairs(state.blade_renders_by_unit) do
        existing_units[#existing_units + 1] = unit_number
    end

    for _, unit_number in ipairs(existing_units) do
        destroy_blade_render(state, unit_number)
    end
end

local function get_shot_source(event)
    local source = ei_lib.get_valid_entity(event.source_entity)
    if source and source.name == TURRET_NAME then
        return source
    end

    local cause = ei_lib.get_valid_entity(event.cause_entity)
    if cause and cause.name == TURRET_NAME then
        return cause
    end

    return nil
end

local function get_turret_entity(event_or_entity)
    local entity = nil
    if type(event_or_entity) == "table" then
        entity = event_or_entity.entity or event_or_entity.created_entity or event_or_entity.destination
    else
        entity = event_or_entity
    end

    entity = ei_lib.get_valid_entity(entity)
    if entity and entity.name == TURRET_NAME then
        return entity
    end

    return nil
end

local function refresh_existing_spin(render_object)
    if not (render_object and render_object.valid) then
        return false
    end

    -- Keep the current frame. Resetting animation_offset here would snap the saw
    -- back to the start of the loop every time damage is dealt.
    render_object.time_to_live = SPIN_TTL

    return true
end

local function remember_entity(state, source)
    local unit_number = ei_lib.get_entity_unit_number(source)
    if unit_number then
        state.entities_by_unit[unit_number] = source
    end

    return unit_number
end

local function choose_attack_sound_index(unit_number, tick, last_sound_index)
    local index = ((unit_number + tick) % ATTACK_SOUND_COUNT) + 1

    if ATTACK_SOUND_COUNT > 1 and index == last_sound_index then
        index = (index % ATTACK_SOUND_COUNT) + 1
    end

    return index
end

-- Sound playback rides the same script-trigger pulse that keeps the blade
-- overlay alive. This avoids prototype aggregation limits, which are too broad
-- for the desired "one sound per turret" behavior.
local function play_attack_sound(state, source, unit_number, tick)
    if tick < (state.next_sound_tick_by_unit[unit_number] or 0) then
        state.counters.attack_sounds_gated = state.counters.attack_sounds_gated + 1
        return
    end

    local surface = source.surface
    if not (surface and surface.valid) then
        state.counters.invalid_events = state.counters.invalid_events + 1
        return
    end

    local sound_index = choose_attack_sound_index(unit_number, tick, state.last_sound_index_by_unit[unit_number])
    local ok = pcall(function()
        surface.play_sound{
            path = ATTACK_SOUND_PREFIX..sound_index,
            position = source.position,
            volume_modifier = 1,
        }
    end)

    if not ok then
        state.counters.attack_sound_errors = state.counters.attack_sound_errors + 1
        return
    end

    state.last_sound_index_by_unit[unit_number] = sound_index
    state.next_sound_tick_by_unit[unit_number] = tick + ATTACK_SOUND_DURATIONS[sound_index] + ATTACK_SOUND_PAD_TICKS
    state.counters.attack_sounds_played = state.counters.attack_sounds_played + 1
end

local function register_render(state, unit_number, render_object, kind)
    local registration_number = script.register_on_object_destroyed(render_object)
    state.blade_renders_by_unit[unit_number] = render_object
    state.blade_modes_by_unit[unit_number] = kind
    state.render_registrations_by_unit[unit_number] = registration_number
    state.units_by_render_registration[registration_number] = unit_number
    state.render_kinds_by_registration[registration_number] = kind
end

local function draw_static_blade(state, source)
    local unit_number = remember_entity(state, source)
    if not unit_number then
        state.counters.invalid_events = state.counters.invalid_events + 1
        return
    end

    local current_blade = state.blade_renders_by_unit[unit_number]
    if current_blade and current_blade.valid and state.blade_modes_by_unit[unit_number] == "static" then
        return
    end

    destroy_blade_render(state, unit_number)

    local render_object = rendering.draw_animation{
        animation = STATIC_BLADE_ANIMATION_NAME,
        target = source,
        surface = source.surface,
        render_layer = "object",
        animation_speed = 1.0,
    }
    register_render(state, unit_number, render_object, "static")
    state.counters.static_created = state.counters.static_created + 1
end

local function draw_spin(state, source, tick)
    local unit_number = remember_entity(state, source)
    if not unit_number then
        state.counters.invalid_events = state.counters.invalid_events + 1
        return nil
    end

    local current_spin = state.blade_renders_by_unit[unit_number]
    if state.blade_modes_by_unit[unit_number] == "attack" and refresh_existing_spin(current_spin) then
        state.counters.spin_refreshed = state.counters.spin_refreshed + 1
        return unit_number
    end

    destroy_blade_render(state, unit_number)

    local render_object = rendering.draw_animation{
        animation = SPIN_ANIMATION_NAME,
        target = source,
        surface = source.surface,
        render_layer = "object",
        animation_speed = SPIN_ANIMATION_SPEED,
        animation_offset = tick % FRAME_COUNT,
        time_to_live = SPIN_TTL,
    }
    register_render(state, unit_number, render_object, "attack")
    state.counters.spin_created = state.counters.spin_created + 1

    return unit_number
end

local function unregister_turret(state, entity)
    local unit_number = ei_lib.get_entity_unit_number(entity)
    if not unit_number then
        return
    end

    destroy_blade_render(state, unit_number)
    state.entities_by_unit[unit_number] = nil
    state.next_sound_tick_by_unit[unit_number] = nil
    state.last_sound_index_by_unit[unit_number] = nil
end

local function register_turret(state, entity)
    if not entity then
        return
    end

    draw_static_blade(state, entity)
end

function model.check_global()
    ensure_state()
end

function model.rebuild_runtime_state()
    local old_state = runtime_state or (storage.ei and storage.ei.sawblade_turret)
    -- Destroy stale render objects before replacing versioned state so updates
    -- cannot leave a second blade overlay attached to the turret.
    destroy_all_blade_renders(old_state)

    runtime_state = new_state()
    storage.ei = storage.ei or {}
    storage.ei.sawblade_turret = runtime_state

    if game and game.surfaces then
        for _, surface in pairs(game.surfaces) do
            for _, entity in pairs(surface.find_entities_filtered{name = TURRET_NAME}) do
                register_turret(runtime_state, entity)
            end
        end
    end

    return runtime_state
end

function model.reset_runtime_state()
    destroy_all_blade_renders(ensure_state())
    runtime_state = new_state()
    storage.ei.sawblade_turret = runtime_state
    return model.get_runtime_status()
end

function model.on_configuration_changed()
    model.rebuild_runtime_state()
end

function model.on_built_entity(event_or_entity)
    local entity = get_turret_entity(event_or_entity)
    if not entity then
        return
    end

    register_turret(ensure_state(), entity)
end

function model.on_script_trigger_effect(event)
    if not (event and event.effect_id == SHOT_EFFECT_ID) then
        return
    end

    local state = ensure_state()
    local source = get_shot_source(event)
    if not source then
        state.counters.invalid_events = state.counters.invalid_events + 1
        return
    end

    state.counters.shot_triggers = state.counters.shot_triggers + 1
    local tick = event.tick or 0
    local unit_number = draw_spin(state, source, tick)
    if unit_number then
        -- Damage pulses arrive much faster than the saw clips. The per-unit
        -- gate keeps continuous attacks loud enough without turning into a
        -- stacked wall of sound.
        play_attack_sound(state, source, unit_number, tick)
    end
end

function model.on_destroyed_entity(event_or_entity)
    local entity = get_turret_entity(event_or_entity)
    if not entity then
        return
    end

    local state = get_state_if_present()
    if state then
        unregister_turret(state, entity)
    end
end

function model.on_object_destroyed(event)
    local state = get_state_if_present()
    if not (state and event and event.registration_number) then
        return
    end

    local registration_number = event.registration_number
    local unit_number = state.units_by_render_registration[registration_number]
    if not unit_number then
        return
    end

    local kind = state.render_kinds_by_registration[registration_number]
    state.units_by_render_registration[registration_number] = nil
    state.render_kinds_by_registration[registration_number] = nil
    state.render_registrations_by_unit[unit_number] = nil
    state.blade_renders_by_unit[unit_number] = nil
    state.blade_modes_by_unit[unit_number] = nil

    if kind == "attack" then
        state.counters.spin_expired = state.counters.spin_expired + 1
        local entity = ei_lib.get_valid_entity(state.entities_by_unit[unit_number])
        if entity and entity.name == TURRET_NAME then
            draw_static_blade(state, entity)
        else
            state.entities_by_unit[unit_number] = nil
            state.next_sound_tick_by_unit[unit_number] = nil
            state.last_sound_index_by_unit[unit_number] = nil
        end
    end
end

function model.get_runtime_status()
    local state = ensure_state()
    local active_blades = 0
    local active_spins = 0
    local stale_blades = 0

    for unit_number, render_object in pairs(state.blade_renders_by_unit) do
        if render_object and render_object.valid then
            active_blades = active_blades + 1
            if state.blade_modes_by_unit[unit_number] == "attack" then
                active_spins = active_spins + 1
            end
        else
            stale_blades = stale_blades + 1
        end
    end

    return {
        version = state.version,
        active_blades = active_blades,
        active_spins = active_spins,
        stale_blades = stale_blades,
        counters = copy_counters(state.counters),
    }
end

model.script_trigger_effect_id = SHOT_EFFECT_ID

return model
