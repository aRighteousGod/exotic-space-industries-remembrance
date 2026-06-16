--====================================================================================================
--ARC FURNACE LIGHT FLICKER PRESET CONFIG
--====================================================================================================

local ei_lib = require("lib/lib")

local arc_furnace_light_config = {}

arc_furnace_light_config.setting_name = "ei-arc-furnace-light-flicker-preset"
arc_furnace_light_config.default_fidelity = "original"
arc_furnace_light_config.allowed_values = {"off", "static", "soft", "reduced", "original"}

local presets = {
    off = {
        remove_lights = true,
    },
    static = {
        lights = {
            {intensity = 0.24, size = 12},
            {intensity = 0.28, size = 12},
            {intensity = 0.36, size = 5},
            {intensity = 0.16, size = 28},
        },
    },
    soft = {
        lights = {
            {flicker_interval = 22, flicker_min_modifier = 0.90, flicker_max_modifier = 1.00, intensity = 0.32, size = 12},
            {flicker_interval = 18, flicker_min_modifier = 0.88, flicker_max_modifier = 0.98, intensity = 0.38, size = 12},
            {flicker_interval = 26, flicker_min_modifier = 0.92, flicker_max_modifier = 1.00, intensity = 0.44, size = 5},
            {flicker_interval = 30, flicker_min_modifier = 0.94, flicker_max_modifier = 1.00, intensity = 0.18, size = 32},
        },
    },
    reduced = {
        lights = {
            {flicker_interval = 14, flicker_min_modifier = 0.72, flicker_max_modifier = 0.96, intensity = 0.46, size = 14},
            {flicker_interval = 12, flicker_min_modifier = 0.68, flicker_max_modifier = 0.92, intensity = 0.52, size = 14},
            {flicker_interval = 16, flicker_min_modifier = 0.76, flicker_max_modifier = 1.00, intensity = 0.62, size = 5},
            {flicker_interval = 18, flicker_min_modifier = 0.82, flicker_max_modifier = 0.98, intensity = 0.24, size = 38},
        },
    },
    original = {},
}

arc_furnace_light_config.presets = presets

local function normalize_fidelity(value)
    if presets[value] then
        return value
    end

    return arc_furnace_light_config.default_fidelity
end

local function read_startup_fidelity()
    local setting = settings
        and settings.startup
        and settings.startup[arc_furnace_light_config.setting_name]

    return normalize_fidelity(setting and setting.value)
end

function arc_furnace_light_config.startup_setting_definition()
    return {
        name = arc_furnace_light_config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = arc_furnace_light_config.default_fidelity,
        allowed_values = ei_lib.copy_array(arc_furnace_light_config.allowed_values),
        order = "b5d",
    }
end

function arc_furnace_light_config.resolve(fidelity)
    local normalized = normalize_fidelity(fidelity or read_startup_fidelity())
    return ei_lib.copy_preset(normalized, presets[normalized], arc_furnace_light_config.setting_name)
end

return arc_furnace_light_config
