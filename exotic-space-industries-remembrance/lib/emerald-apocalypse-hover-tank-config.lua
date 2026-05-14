--====================================================================================================
-- EMERALD APOCALYPSE HOVER TANK HOVER VISUAL FIDELITY CONFIG
--====================================================================================================

local ei_lib = require("lib/lib")
local emerald_hover_tank_config = {}

emerald_hover_tank_config.setting_name = "ei-emerald-apocalypse-hover-tank-hover-visual-fidelity"
emerald_hover_tank_config.default_fidelity = "standard"
emerald_hover_tank_config.allowed_values = {"off", "lean", "standard", "cinematic", "maximal", "unbounded"}

local presets = {
    off = {
        enabled = false,
        update_interval = 0,
        movement_threshold = 999,
        service_cap = 0,
        global_emitter_cap = 0,
        ring_ttl = 0,
        moving_emit_interval = 999,
        idle_emit_interval = 999,
        radius = 0,
        width = 0,
        echo_alpha = 0,
        arc_alpha = 0,
        arc_count = 0,
        arc_span = 0,
        arc_thickness = 0,
        phase_speed = 0,
    },
    lean = {
        enabled = true,
        update_interval = 10,
        movement_threshold = 0.075,
        service_cap = 4,
        global_emitter_cap = 8,
        ring_ttl = 14,
        moving_emit_interval = 12,
        idle_emit_interval = 120,
        radius = 0.34,
        width = 1.5,
        echo_alpha = 0,
        arc_alpha = 0.20,
        arc_count = 1,
        arc_span = 0.72,
        arc_thickness = 0.040,
        phase_speed = 0.018,
    },
    standard = {
        enabled = true,
        update_interval = 4,
        movement_threshold = 0.035,
        service_cap = 12,
        global_emitter_cap = 32,
        ring_ttl = 18,
        moving_emit_interval = 5,
        idle_emit_interval = 48,
        radius = 0.42,
        width = 2.0,
        echo_alpha = 0.13,
        arc_alpha = 0.26,
        arc_count = 2,
        arc_span = 0.86,
        arc_thickness = 0.050,
        phase_speed = 0.026,
    },
    cinematic = {
        enabled = true,
        update_interval = 3,
        movement_threshold = 0.025,
        service_cap = 24,
        global_emitter_cap = 64,
        ring_ttl = 24,
        moving_emit_interval = 3,
        idle_emit_interval = 28,
        radius = 0.47,
        width = 2.4,
        echo_alpha = 0.18,
        arc_alpha = 0.32,
        arc_count = 3,
        arc_span = 1.00,
        arc_thickness = 0.060,
        phase_speed = 0.036,
    },
    maximal = {
        enabled = true,
        update_interval = 2,
        movement_threshold = 0.015,
        service_cap = 48,
        global_emitter_cap = 128,
        ring_ttl = 32,
        moving_emit_interval = 2,
        idle_emit_interval = 14,
        radius = 0.52,
        width = 3.0,
        echo_alpha = 0.24,
        arc_alpha = 0.40,
        arc_count = 4,
        arc_span = 1.12,
        arc_thickness = 0.070,
        phase_speed = 0.048,
    },
    unbounded = {
        enabled = true,
        update_interval = 1,
        movement_threshold = 0.010,
        service_cap_unbounded = true,
        global_emitter_cap_unbounded = true,
        ring_ttl = 44,
        moving_emit_interval = 0,
        idle_emit_interval = 6,
        radius = 0.57,
        width = 3.4,
        echo_alpha = 0.30,
        arc_alpha = 0.48,
        arc_count = 5,
        arc_span = 1.24,
        arc_thickness = 0.085,
        phase_speed = 0.066,
    },
}

emerald_hover_tank_config.presets = presets

local function normalize_fidelity(value)
    if presets[value] then
        return value
    end

    return emerald_hover_tank_config.default_fidelity
end

local function read_startup_fidelity()
    local setting = settings
        and settings.startup
        and settings.startup[emerald_hover_tank_config.setting_name]

    return normalize_fidelity(setting and setting.value)
end

function emerald_hover_tank_config.startup_setting_definition()
    return {
        name = emerald_hover_tank_config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = emerald_hover_tank_config.default_fidelity,
        allowed_values = ei_lib.copy_array(emerald_hover_tank_config.allowed_values),
        order = "b5c",
    }
end

function emerald_hover_tank_config.resolve(fidelity)
    local normalized = normalize_fidelity(fidelity or read_startup_fidelity())
    return ei_lib.copy_preset(normalized, presets[normalized], emerald_hover_tank_config.setting_name)
end

function emerald_hover_tank_config.get_service_cap(preset_or_name)
    local preset = type(preset_or_name) == "table"
        and preset_or_name
        or emerald_hover_tank_config.resolve(preset_or_name)

    if preset.service_cap_unbounded then
        return nil
    end

    return ei_lib.clamp_integer(preset.service_cap, 0, nil, 0)
end

function emerald_hover_tank_config.get_global_emitter_cap(preset_or_name)
    local preset = type(preset_or_name) == "table"
        and preset_or_name
        or emerald_hover_tank_config.resolve(preset_or_name)

    if preset.global_emitter_cap_unbounded then
        return nil
    end

    return ei_lib.clamp_integer(preset.global_emitter_cap, 0, nil, 0)
end

function emerald_hover_tank_config.runtime_snapshot(preset_or_name)
    local preset = emerald_hover_tank_config.resolve(
        type(preset_or_name) == "table" and preset_or_name.visual_fidelity or preset_or_name
    )

    preset.service_cap = emerald_hover_tank_config.get_service_cap(preset) or "unbounded"
    preset.global_emitter_cap = emerald_hover_tank_config.get_global_emitter_cap(preset) or "unbounded"

    return preset
end

return emerald_hover_tank_config
