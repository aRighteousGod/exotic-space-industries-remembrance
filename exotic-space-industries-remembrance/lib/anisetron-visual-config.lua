-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- blueprint-ref: .codex/esir/blueprints/anisetron.md#visuals
-- Presentation authority. Weapon payment, timing and damage never read presets.
local lib = require("lib/lib")
local tip_count = #require("lib/anisetron-graphics").keel_tips
---@class AnisetronVisualPreset
---@field enabled boolean
---@field update_interval integer
---@field service_cap integer?
---@field strand_cap integer?
---@field weapon_cap integer?
---@field halo_alpha number
---@field flash_ttl integer
---@field strand_ttl integer
---@field movement_start number
---@field movement_stop number
local config = {
    setting_name = "ei-anisetron-visual-fidelity",
    default_fidelity = "standard",
    allowed_values = {"off", "lean", "standard", "cinematic", "maximal", "unbounded"},
    -- Native bob is now bounded around height1.8. Entity render targets already
    -- include that base height; the previous speed guess added up to17px error.
    attachment_lift = {minimum = 0, span = 0, speed = 1},
}

---@return AnisetronVisualPreset
local function preset(interval, visits, weapon_cap, alpha, flash_ttl)
    return {enabled = interval > 0, update_interval = interval, service_cap = visits,
        strand_cap = visits and visits * tip_count or nil, weapon_cap = weapon_cap,
        halo_alpha = alpha, flash_ttl = flash_ttl, strand_ttl = 12,
        movement_start = 0.01, movement_stop = 0.005}
end
config.presets = {
    off = preset(0, 0, 0, 0, 0),
    lean = preset(8, 8, 8, .25, 4),
    standard = preset(4, 32, 32, .40, 6),
    cinematic = preset(3, 64, 64, .50, 8),
    maximal = preset(2, 128, 128, .60, 10),
    unbounded = preset(1, nil, nil, .70, 12),
}

---@return data.StringSettingPrototype
function config.startup_setting_definition()
    return {name = config.setting_name, type = "string-setting", setting_type = "startup",
        default_value = config.default_fidelity, allowed_values = lib.copy_array(config.allowed_values), order = "b5e"}
end

---@param fidelity string?
---@return AnisetronVisualPreset
function config.resolve(fidelity)
    local setting = settings and settings.startup and settings.startup[config.setting_name]
    local name = fidelity or (setting and setting.value) or config.default_fidelity
    if not config.presets[name] then name = config.default_fidelity end
    return lib.copy_preset(name, config.presets[name], config.setting_name)
end
return config
