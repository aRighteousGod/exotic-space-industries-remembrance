--==============================================================================
-- ESIR FILE MAP
-- owns: production machine status light startup modes
-- loaded_by: settings.lua and scripts/data-updates/machine-status-lights.lua and scripts/data-final-updates/machine-status-lights.lua
-- cadence: settings, data-updates and data-final stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup mode changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/machine-status-lights.md#contract

local ei_lib = require("lib/lib")
local config = {}

config.setting_name = "ei-production-machine-lights"
config.default_fidelity = "status"
config.allowed_values = {"off", "status", "original"}

local presets = {
    off = {status_lights = false},
    status = {status_lights = true},
    original = {preserve_original = true},
}

---@return data.StringSettingPrototype
function config.startup_setting_definition()
    return {
        name = config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = config.default_fidelity,
        allowed_values = ei_lib.copy_array(config.allowed_values),
        order = "b5da",
    }
end

---@param fidelity? string
---@return table
function config.resolve(fidelity)
    local setting = settings and settings.startup and settings.startup[config.setting_name]
    local selected = fidelity or (setting and setting.value)
    if not presets[selected] then selected = config.default_fidelity end
    return ei_lib.copy_preset(selected, presets[selected], config.setting_name)
end

return config
