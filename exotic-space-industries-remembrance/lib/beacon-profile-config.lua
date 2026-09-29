--==============================================================================
-- ESIR FILE MAP
-- owns: beacon diminishing-return presets, native profiles, numerical tooltips
-- loaded_by: settings.lua, data-final beacon profiles, Informatron
-- cadence: startup/data stage and on-demand help; no persistent state
--==============================================================================
-- blueprint: .codex/esir/blueprints/beacon-overload.md#contract
local ei_lib = require("lib/lib")

---@alias BeaconProfileName "gentle"|"vanilla"|"strict"|"harsh"|"severe"|"saturating"
---@class BeaconProfilePreset
---@field exponent number|nil Nil selects the rational severe curve.
---@class ResolvedBeaconProfilePreset: BeaconProfilePreset
---@field visual_fidelity BeaconProfileName Shared preset helper's selected identifier.
---@field setting_name string
local config = {}
config.setting_name = "ei-beacon-diminishing-returns"
config.default_profile = "strict"
config.allowed_values = {"gentle", "vanilla", "strict", "harsh", "severe", "saturating"}
config.profile_length = 4096
config.beacon_names = {"ei-copper-beacon", "ei-iron-beacon", "ei-alien-beacon", "ei-warp-beacon"}
---@type table<BeaconProfileName, BeaconProfilePreset>
config.profiles = {
    gentle = {exponent = 0.25},
    vanilla = {exponent = 0.5},
    strict = {exponent = 0.625},
    harsh = {exponent = 0.75},
    severe = {},
    saturating = {exponent = 1},
}

---@param name BeaconProfileName|nil
---@return ResolvedBeaconProfilePreset
function config.resolve(name)
    local setting = settings and settings.startup and settings.startup[config.setting_name]
    name = name or (setting and setting.value) or config.default_profile
    if not config.profiles[name] then name = config.default_profile end
    return ei_lib.copy_preset(name, config.profiles[name], config.setting_name)
end

---@param preset BeaconProfilePreset
---@param count integer Positive number of covering beacons.
---@return number
function config.multiplier(preset, count)
    return preset.exponent and count ^ -preset.exponent or 2 / (count + 1)
end

---@param name BeaconProfileName|nil
---@return number[]
function config.build_profile(name)
    local preset = config.resolve(name)
    local profile = {}
    -- Factorio repeats the final sample beyond this length. Do not round native
    -- multipliers or describe the rational/reciprocal curves as unlimited caps.
    for count = 1, config.profile_length do
        profile[count] = config.multiplier(preset, count)
    end
    return profile
end

---@return LocalisedString
function config.tooltip()
    local rows = {""}
    for _, name in ipairs(config.allowed_values) do
        local preset = config.resolve(name)
        local row = {"beacon-profile.row", {"string-mod-setting." .. config.setting_name .. "-" .. name}}
        for _, count in ipairs({1, 4, 8, 16}) do
            row[#row + 1] = string.format("%.1f", 100 * config.multiplier(preset, count))
        end
        rows[#rows + 1] = row
    end
    return {"mod-setting-description." .. config.setting_name, rows}
end

---@return data.StringSettingPrototype
function config.startup_setting_definition()
    return {
        type = "string-setting", name = config.setting_name, setting_type = "startup",
        default_value = config.default_profile, allowed_values = ei_lib.copy_array(config.allowed_values),
        localised_description = config.tooltip(), order = "b1a",
    }
end

---@return LocalisedString
function config.mode_description()
    if settings.startup["ei-beacon-overload"].value then return {"beacon-profile.overload-enabled"} end
    local preset = config.resolve()
    return {"beacon-profile.overload-disabled",
        {"string-mod-setting." .. config.setting_name .. "-" .. preset.visual_fidelity}}
end

return config
