--==============================================================================
-- ESIR FILE MAP
-- owns: Pyric Radiance doctrines and shared numerical descriptions
-- loaded_by: settings.lua, final presentation pass, Informatron
-- cadence: startup/data stage and on-demand help; no persistent state
--==============================================================================
-- blueprint: .codex/esir/blueprints/combat-doctrines.md#contract
local ei_lib = require("lib/lib")

---@class PyricRadianceDoctrine
---@field fire number
---@field explosion number
---@field projectile number
---@field muzzle number
---@field impact boolean
---@field nuclear number
---@field visual_fidelity string
---@field setting_name string
local config = {toggle_name="ei-pyric-radiance", setting_name="ei-pyric-radiance-preset", default_profile="tempered"}
config.allowed_values = {"ember", "veiled", "furnace-vigil", "iron-benediction", "signal-threads", "tempered",
    "night-liturgy", "siege-hymn", "cataclysm", "apotheosis"}
---@type table<string, PyricRadianceDoctrine>
config.profiles = {
    ember = {fire=0.60, explosion=0.50, projectile=0, muzzle=0.50, impact=false, nuclear=0},
    veiled = {fire=0.75, explosion=0.65, projectile=0.40, muzzle=0.65, impact=false, nuclear=0},
    ["furnace-vigil"] = {fire=1.20, explosion=0.60, projectile=0, muzzle=0.60, impact=false, nuclear=0},
    ["iron-benediction"] = {fire=0.65, explosion=0.65, projectile=0.35, muzzle=1.30, impact=false, nuclear=0},
    ["signal-threads"] = {fire=0.75, explosion=0.65, projectile=1.35, muzzle=0.75, impact=false, nuclear=0},
    tempered = {fire=0.90, explosion=0.90, projectile=0.75, muzzle=0.90, impact=false, nuclear=0},
    ["night-liturgy"] = {fire=1.10, explosion=1.10, projectile=1, muzzle=1, impact=true, nuclear=0.25},
    ["siege-hymn"] = {fire=0.90, explosion=1.25, projectile=1.10, muzzle=1.30, impact=true, nuclear=0.25},
    cataclysm = {fire=1.35, explosion=1.45, projectile=1.25, muzzle=1.25, impact=true, nuclear=1},
    apotheosis = {fire=1.70, explosion=1.60, projectile=1.40, muzzle=1.40, impact=true, nuclear=1.25},
}

---@return boolean
function config.enabled()
    local setting = settings and settings.startup and settings.startup[config.toggle_name]
    return not setting or setting.value
end

---@param name string|nil
---@return PyricRadianceDoctrine
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
    return {"", {"pyric-radiance.row", {"string-mod-setting."..config.setting_name.."-"..name},
        tostring(p.fire), tostring(p.explosion), tostring(p.projectile), tostring(p.muzzle),
        {p.impact and "combat-doctrines.on" or "combat-doctrines.off"}, tostring(p.nuclear)},
        {"string-mod-setting-description."..config.setting_name.."-"..name}, "\n"}
end

---@return data.ModSettingPrototype[]
function config.startup_setting_definitions()
    local description = {"", {"mod-setting-description."..config.setting_name}}
    for _, name in ipairs(config.allowed_values) do description[#description+1] = config.describe(name) end
    return {
        {type="bool-setting", name=config.toggle_name, setting_type="startup", default_value=true, order="b5p-a"},
        {type="string-setting", name=config.setting_name, setting_type="startup", default_value=config.default_profile,
            allowed_values=ei_lib.copy_array(config.allowed_values), localised_description=description, order="b5p-b"},
    }
end

return config
