--==============================================================================
-- ESIR FILE MAP
-- owns: optional Quality effects and beacon family module permissions
-- loaded_by: settings, beacon prototypes, module updates, runtime reconciliation and Informatron
-- cadence: startup/data stage and explicit lifecycle/help calls; no tick work
--==============================================================================
-- blueprint: .codex/esir/blueprints/beacon-overload.md#contract
local lib = require("lib/lib")
local config = {}

---@alias BeaconModuleFamily "nitrogen"|"alien"
---@alias BeaconModuleSelection "neither"|"nitrogen"|"alien"|"both"
---@class BeaconModulePermissions
---@field quality boolean
---@field productivity boolean
config.quality_setting = "ei-beacon-quality-modules"
config.productivity_setting = "ei-beacon-productivity-modules"
config.effects_setting = "ei-quality-module-effects"
config.allowed_values = {"neither", "nitrogen", "alien", "both"}
config.beacon_families = {
    ["ei-copper-beacon"] = "nitrogen", ["ei-iron-beacon"] = "nitrogen",
    ["ei-alien-beacon"] = "alien", ["ei-warp-beacon"] = "alien",
}

---@param name string
---@param fallback string
---@return string
local function selected(name, fallback)
    local setting = settings and settings.startup and settings.startup[name]
    return setting and setting.value or fallback
end

---@param selection BeaconModuleSelection
---@param family BeaconModuleFamily
---@return boolean
local function permits(selection, family)
    return selection == "both" or selection == family
end

---@param family BeaconModuleFamily
---@param quality BeaconModuleSelection|nil
---@param productivity BeaconModuleSelection|nil
---@return BeaconModulePermissions
function config.resolve(family, quality, productivity)
    return {
        quality = permits(quality or selected(config.quality_setting, "both"), family),
        productivity = permits(productivity or selected(config.productivity_setting, "both"), family),
    }
end

---@param family BeaconModuleFamily
---@return string[]
function config.allowed_effects(family)
    local policy = config.resolve(family)
    local effects = {"speed", "consumption", "pollution"}
    if policy.quality then effects[#effects + 1] = "quality" end
    if policy.productivity then effects[#effects + 1] = "productivity" end
    return effects
end

---@return boolean
function config.use_esir_quality_effects()
    return selected(config.effects_setting, "esir") == "esir"
end

---@return data.StringSettingPrototype[]
function config.startup_setting_definitions()
    local definitions = {}
    for index, name in ipairs({config.quality_setting, config.productivity_setting}) do
        definitions[#definitions + 1] = {
            type = "string-setting", name = name, setting_type = "startup",
            default_value = "both", allowed_values = lib.copy_array(config.allowed_values),
            order = "b1b" .. index,
        }
    end
    definitions[#definitions + 1] = {
        type = "string-setting", name = config.effects_setting, setting_type = "startup",
        default_value = "esir", allowed_values = {"esir", "vanilla"}, order = "b1b3",
    }
    return definitions
end

---@param family BeaconModuleFamily
---@return LocalisedString
function config.family_description(family)
    local policy = config.resolve(family)
    local available = (mods and mods.quality) or (script and script.active_mods.quality)
    return {"beacon-module-policy.summary",
        {available and (policy.quality and "beacon-module-policy.allowed" or "beacon-module-policy.blocked")
            or "beacon-module-policy.quality-unavailable"},
        {policy.productivity and "beacon-module-policy.allowed" or "beacon-module-policy.blocked"}}
end

---@return LocalisedString
function config.description()
    return {"", {"beacon-module-policy.family-summary", config.family_description("nitrogen"), config.family_description("alien")},
        "\n", {"beacon-module-policy.effects-summary", {"string-mod-setting." .. config.effects_setting .. "-" .. selected(config.effects_setting, "esir")}}}
end

return config
