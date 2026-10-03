--==============================================================================
-- ESIR FILE MAP
-- owns: Ballistic Divergence doctrines and shared numerical descriptions
-- loaded_by: settings.lua, final ballistic pass, Informatron
-- cadence: startup/data stage and on-demand help; no persistent state
--==============================================================================
-- blueprint: .codex/esir/blueprints/combat-doctrines.md#contract
local ei_lib = require("lib/lib")

---@class BallisticDivergenceDoctrine
---@field flight number
---@field scatter number
---@field magazine number
---@field shotgun_variation number
---@field terrain boolean
---@field visual_fidelity string
---@field setting_name string
local config = {toggle_name="ei-ballistic-divergence", setting_name="ei-ballistic-divergence-preset", default_profile="tempered"}
config.allowed_values = {"needle-oath", "measured-volleys", "breach-doctrine", "tempered", "distant-thunder",
    "fortress-oath", "wildfire-doctrine", "crossfire", "saturation", "terminal-barrage"}
---@type table<string, BallisticDivergenceDoctrine>
config.profiles = {
    ["needle-oath"] = {flight=1, scatter=0, magazine=1, shotgun_variation=1, terrain=false},
    ["measured-volleys"] = {flight=1.10, scatter=0.25, magazine=1, shotgun_variation=1, terrain=true},
    ["breach-doctrine"] = {flight=1, scatter=0.75, magazine=1.25, shotgun_variation=2, terrain=false},
    tempered = {flight=1.25, scatter=0.50, magazine=1, shotgun_variation=1.50, terrain=false},
    ["distant-thunder"] = {flight=1.75, scatter=0.35, magazine=1, shotgun_variation=1.50, terrain=false},
    ["fortress-oath"] = {flight=1.40, scatter=0.65, magazine=1.50, shotgun_variation=2, terrain=true},
    ["wildfire-doctrine"] = {flight=1.50, scatter=1, magazine=1.75, shotgun_variation=4, terrain=true},
    crossfire = {flight=1.75, scatter=1.25, magazine=1.50, shotgun_variation=3, terrain=false},
    saturation = {flight=2, scatter=1.50, magazine=2, shotgun_variation=3, terrain=true},
    ["terminal-barrage"] = {flight=2.50, scatter=2, magazine=3, shotgun_variation=4, terrain=false},
}

---@return boolean
function config.enabled()
    local setting = settings and settings.startup and settings.startup[config.toggle_name]
    return not setting or setting.value
end

---@param name string|nil
---@return BallisticDivergenceDoctrine
function config.resolve(name)
    local setting = settings and settings.startup and settings.startup[config.setting_name]
    name = name or (setting and setting.value) or config.default_profile
    if not config.profiles[name] then name = config.default_profile end
    return ei_lib.copy_preset(name, config.profiles[name], config.setting_name)
end

---@param name string
---@return LocalisedString
function config.describe(name)
    local p = config.resolve(name)
    return {"", {"ballistic-divergence.row", {"string-mod-setting."..config.setting_name.."-"..name},
        tostring(p.flight), tostring(p.scatter), tostring(p.magazine), tostring(p.shotgun_variation),
        {p.terrain and "combat-doctrines.on" or "combat-doctrines.off"}},
        {"string-mod-setting-description."..config.setting_name.."-"..name}, "\n"}
end

---@return data.ModSettingPrototype[]
function config.startup_setting_definitions()
    local description = {"", {"mod-setting-description."..config.setting_name}}
    for _, name in ipairs(config.allowed_values) do description[#description+1] = config.describe(name) end
    return {
        {type="bool-setting", name=config.toggle_name, setting_type="startup", default_value=true, order="b5q-a"},
        {type="string-setting", name=config.setting_name, setting_type="startup", default_value=config.default_profile,
            allowed_values=ei_lib.copy_array(config.allowed_values), localised_description=description, order="b5q-b"},
    }
end

return config
