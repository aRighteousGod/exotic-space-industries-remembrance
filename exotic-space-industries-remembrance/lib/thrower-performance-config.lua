--==============================================================================
-- ESIR FILE MAP
-- owns: flame/acid turret startup profiles and numerical setting tooltip
-- loaded_by: settings.lua, scripts/data-final-updates/thrower-performance.lua
-- cadence: settings/data stage only; no runtime state
--==============================================================================
local ei_lib = require("lib/lib")

---@alias ThrowerPerformanceProfileName "original"|"2x"|"4x"|"8x"|"16x"
---@class ThrowerPerformanceProfile
---@field factor integer
---@field sticker_interval_cap integer
local config = {}
config.setting_name = "ei-thrower-performance-profile"
config.default_profile = "original"
config.allowed_values = {"original", "2x", "4x", "8x", "16x"}
---@type table<ThrowerPerformanceProfileName, ThrowerPerformanceProfile>
config.profiles = {
    original = {factor = 1, sticker_interval_cap = 30},
    ["2x"] = {factor = 2, sticker_interval_cap = 30},
    ["4x"] = {factor = 4, sticker_interval_cap = 30},
    ["8x"] = {factor = 8, sticker_interval_cap = 30},
    ["16x"] = {factor = 16, sticker_interval_cap = 30},
}

---@param name ThrowerPerformanceProfileName|nil
---@return ThrowerPerformanceProfile
function config.resolve(name)
    local setting = settings and settings.startup and settings.startup[config.setting_name]
    name = name or (setting and setting.value) or config.default_profile
    if not config.profiles[name] then name = config.default_profile end
    return ei_lib.copy_preset(name, config.profiles[name], config.setting_name)
end

---@return data.StringSettingPrototype
function config.startup_setting_definition()
    local description = {"", {"mod-setting-description." .. config.setting_name}}
    for _, name in ipairs(config.allowed_values) do
        local factor = config.profiles[name].factor
        description[#description + 1] = {"thrower-performance.profile-row",
            {"string-mod-setting." .. config.setting_name .. "-" .. name},
            tostring(4 * factor), tostring(2 * factor), tostring(30 / factor), tostring(factor),
            tostring(math.min(10 * factor, 30)), tostring(math.min(factor, 30))}
    end
    return {
        type = "string-setting", name = config.setting_name, setting_type = "startup",
        default_value = config.default_profile, allowed_values = ei_lib.copy_array(config.allowed_values),
        localised_description = description, order = "b5b",
    }
end

return config
