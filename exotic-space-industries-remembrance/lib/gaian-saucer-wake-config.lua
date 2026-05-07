--====================================================================================================
--GAIAN SAUCER WAKE VISUAL FIDELITY CONFIG
--====================================================================================================

local ei_lib = require("lib/lib")
local gaian_saucer_wake_config = {}

gaian_saucer_wake_config.setting_name = "ei-gaian-saucer-wake-visual-fidelity"
gaian_saucer_wake_config.default_fidelity = "standard"
gaian_saucer_wake_config.allowed_values = {"off", "lean", "standard", "cinematic", "maximal", "unbounded"}

local presets = {
    off = {
        enabled = false,
        update_interval = 0,
        movement_threshold = 999,
        service_cap = 0,
        global_burst_cap = 0,
        burst_ttl = 0,
        animation_speed = 0,
        scale = 0,
        wake_offset = 0,
        wake_rear_bias = 0,
        wake_turn_gain = 0,
        wake_turn_max = 0,
        wake_turn_smoothing = 1,
        min_unit_emit_interval = 999,
    },
    lean = {
        enabled = true,
        update_interval = 8,
        movement_threshold = 0.08,
        service_cap = 8,
        global_burst_cap = 8,
        burst_ttl = 10,
        animation_speed = 0.34,
        scale = 0.20,
        wake_offset = 1.20,
        wake_rear_bias = 0.50,
        wake_turn_gain = 0.55,
        wake_turn_max = 0.10,
        wake_turn_smoothing = 0.80,
        min_unit_emit_interval = 12,
    },
    standard = {
        enabled = true,
        update_interval = 4,
        movement_threshold = 0.03,
        service_cap = 32,
        global_burst_cap = 32,
        burst_ttl = 18,
        animation_speed = 0.45,
        scale = 0.23,
        wake_offset = 1.40,
        wake_rear_bias = 0.55,
        wake_turn_gain = 0.90,
        wake_turn_max = 0.18,
        wake_turn_smoothing = 0.72,
        min_unit_emit_interval = 4,
    },
    cinematic = {
        enabled = true,
        update_interval = 3,
        movement_threshold = 0.02,
        service_cap = 64,
        global_burst_cap = 64,
        burst_ttl = 26,
        animation_speed = 0.55,
        scale = 0.25,
        wake_offset = 1.45,
        wake_rear_bias = 0.65,
        wake_turn_gain = 1.45,
        wake_turn_max = 0.32,
        wake_turn_smoothing = 0.66,
        min_unit_emit_interval = 3,
    },
    maximal = {
        enabled = true,
        update_interval = 2,
        movement_threshold = 0.015,
        service_cap = 128,
        global_burst_cap = 128,
        burst_ttl = 36,
        animation_speed = 0.70,
        scale = 0.27,
        wake_offset = 1.50,
        wake_rear_bias = 0.75,
        wake_turn_gain = 2.00,
        wake_turn_max = 0.45,
        wake_turn_smoothing = 0.60,
        min_unit_emit_interval = 2,
    },
    unbounded = {
        enabled = true,
        update_interval = 1,
        movement_threshold = 0.01,
        service_cap_unbounded = true,
        global_burst_cap_unbounded = true,
        burst_ttl = 48,
        animation_speed = 0.85,
        scale = 0.30,
        wake_offset = 1.55,
        wake_rear_bias = 0.80,
        wake_turn_gain = 2.40,
        wake_turn_max = 0.60,
        wake_turn_smoothing = 0.55,
        min_unit_emit_interval = 0,
    },
}

gaian_saucer_wake_config.presets = presets

local function normalize_fidelity(value)
    if presets[value] then
        return value
    end

    return gaian_saucer_wake_config.default_fidelity
end

local function read_startup_fidelity()
    local setting = settings
        and settings.startup
        and settings.startup[gaian_saucer_wake_config.setting_name]

    return normalize_fidelity(setting and setting.value)
end

function gaian_saucer_wake_config.startup_setting_definition()
    return {
        name = gaian_saucer_wake_config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = gaian_saucer_wake_config.default_fidelity,
        allowed_values = ei_lib.copy_array(gaian_saucer_wake_config.allowed_values),
        order = "b5b",
    }
end

function gaian_saucer_wake_config.resolve(fidelity)
    local normalized = normalize_fidelity(fidelity or read_startup_fidelity())
    return ei_lib.copy_preset(normalized, presets[normalized], gaian_saucer_wake_config.setting_name)
end

function gaian_saucer_wake_config.get_service_cap(preset_or_name)
    local preset = type(preset_or_name) == "table"
        and preset_or_name
        or gaian_saucer_wake_config.resolve(preset_or_name)

    if preset.service_cap_unbounded then
        return nil
    end

    return ei_lib.clamp_integer(preset.service_cap, 0, nil, 0)
end

function gaian_saucer_wake_config.get_global_burst_cap(preset_or_name)
    local preset = type(preset_or_name) == "table"
        and preset_or_name
        or gaian_saucer_wake_config.resolve(preset_or_name)

    if preset.global_burst_cap_unbounded then
        return nil
    end

    return ei_lib.clamp_integer(preset.global_burst_cap, 0, nil, 0)
end

function gaian_saucer_wake_config.runtime_snapshot(preset_or_name)
    local preset = gaian_saucer_wake_config.resolve(
        type(preset_or_name) == "table" and preset_or_name.visual_fidelity or preset_or_name
    )

    preset.service_cap = gaian_saucer_wake_config.get_service_cap(preset) or "unbounded"
    preset.global_burst_cap = gaian_saucer_wake_config.get_global_burst_cap(preset) or "unbounded"

    return preset
end

return gaian_saucer_wake_config
