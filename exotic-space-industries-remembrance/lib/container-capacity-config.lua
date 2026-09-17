--==============================================================================
-- ESIR FILE MAP
-- owns: storage capacity profiles, classification policy, startup tooltip
-- loaded_by: settings.lua, container-capacities.lua, krastorio-patches.lua
-- cadence: settings/data stage only; no runtime state
--==============================================================================
local ei_lib = require("lib/lib")

---@alias ContainerCapacityTier "wooden"|"iron"|"steel"|"small"|"medium"|"warehouse"
---@class ContainerCapacityProfile
---@field wooden integer
---@field iron integer
---@field steel integer
---@field small integer
---@field medium integer
---@field warehouse integer
local config = {}
config.setting_name = "ei-container-capacity-profile"
config.default_profile = "restrained"
config.allowed_values = {"restrained", "standard", "expanded", "generous", "industrial", "massive", "vast", "extreme"}
config.tiers = {"wooden", "iron", "steel", "small", "medium", "warehouse"}

---@type table<string, ContainerCapacityProfile>
config.profiles = {
    restrained = {wooden = 8, iron = 16, steel = 16, small = 24, medium = 32, warehouse = 64},
    standard = {wooden = 8, iron = 16, steel = 24, small = 32, medium = 64, warehouse = 128},
    expanded = {wooden = 16, iron = 24, steel = 32, small = 48, medium = 96, warehouse = 192},
    generous = {wooden = 16, iron = 32, steel = 48, small = 64, medium = 128, warehouse = 256},
    industrial = {wooden = 24, iron = 48, steel = 64, small = 96, medium = 192, warehouse = 384},
    massive = {wooden = 32, iron = 64, steel = 96, small = 128, medium = 256, warehouse = 512},
    vast = {wooden = 48, iron = 96, steel = 128, small = 192, medium = 384, warehouse = 768},
    extreme = {wooden = 64, iron = 128, steel = 192, small = 256, medium = 512, warehouse = 1024},
}

---@type table<string, ContainerCapacityTier>
config.explicit_tiers = { ["wooden-chest"] = "wooden", ["iron-chest"] = "iron", ["steel-chest"] = "steel" }
for size, tier in pairs({[1] = "small", [2] = "medium", [6] = "warehouse"}) do
    for _, suffix in ipairs({"", "-filter", "-blue", "-red", "-pink", "-yellow", "-green"}) do
        config.explicit_tiers["ei-" .. size .. "x" .. size .. "-container" .. suffix] = tier
    end
end
for _, mode in ipairs({"active-provider", "passive-provider", "storage", "buffer", "requester"}) do
    config.explicit_tiers[mode .. "-chest"] = "small"
    config.explicit_tiers["rp-steam-logistic-chest-" .. mode] = "medium"
end

-- Owned by the guarded K2SO compatibility pass, including disabled content.
---@type table<string, ContainerCapacityTier>
config.k2so_tiers = {}
for family, tier in pairs({strongbox = "medium", warehouse = "warehouse"}) do
    config.k2so_tiers["kr-" .. family] = tier
    for _, mode in ipairs({"active-provider", "passive-provider", "storage", "buffer", "requester"}) do
        config.k2so_tiers["kr-" .. mode .. "-" .. family] = tier
    end
end
for size, tier in pairs({medium = "medium", big = "warehouse"}) do
    config.k2so_tiers["kr-" .. size .. "-container"] = tier
    for _, mode in ipairs({"active-provider", "passive-provider", "storage", "buffer", "requester"}) do
        config.k2so_tiers["kr-" .. size .. "-" .. mode .. "-container"] = tier
    end
end
config.excluded_names = {
    ["ei-gate"] = true, ["ei-gate-container"] = true,
    ["ei-fueler"] = true, ["ei-black-hole"] = true, ["vehicle-depot-chest"] = true,
}

---@param name string|nil
---@return ContainerCapacityProfile
function config.resolve(name)
    local setting = settings and settings.startup and settings.startup[config.setting_name]
    name = name or (setting and setting.value) or config.default_profile
    if not config.profiles[name] then name = config.default_profile end
    return ei_lib.copy_preset(name, config.profiles[name], config.setting_name)
end

---@param name string
---@return LocalisedString
function config.profile_row(name)
    local row = {"container-capacity.row", {"string-mod-setting." .. config.setting_name .. "-" .. name}}
    for _, tier in ipairs(config.tiers) do
        row[#row + 1] = tostring(config.profiles[name][tier])
    end
    return row
end

---@return LocalisedString
function config.tooltip()
    local rows = {""}
    for _, name in ipairs(config.allowed_values) do
        rows[#rows + 1] = {"", "\n", config.profile_row(name)}
    end
    return {"mod-setting-description." .. config.setting_name, rows}
end

---@return table
function config.startup_setting_definition()
    return {
        type = "string-setting", name = config.setting_name, setting_type = "startup",
        default_value = config.default_profile, allowed_values = ei_lib.copy_array(config.allowed_values),
        localised_description = config.tooltip(), order = "b6-container-capacity",
    }
end

---@param prototype table Data-stage container prototype.
---@param placeable table<string, boolean> Entities placed by visible items.
---@return ContainerCapacityTier|nil
function config.classify(prototype, placeable)
    local name = prototype.name
    if config.excluded_names[name] or config.k2so_tiers[name]
        or ei_lib.startswith(name, "ei-gate-")
        or not placeable[name] or prototype.hidden
        or not prototype.inventory_size or prototype.inventory_size <= 0
        or prototype.inventory_type == "with_custom_stack_size"
        or prototype.inventory_type == "with_weight_limit" then return nil end
    for _, flag in ipairs(prototype.flags or {}) do
        if flag == "hidden" or flag == "not-selectable-in-game" then return nil end
    end
    if config.explicit_tiers[name] then return config.explicit_tiers[name] end
    local box = prototype.selection_box
    local first = box and (box.left_top or box[1])
    local last = box and (box.right_bottom or box[2])
    local width = prototype.tile_width
    local height = prototype.tile_height
    if not width and first and last then width = math.ceil((last.x or last[1]) - (first.x or first[1])) end
    if not height and first and last then height = math.ceil((last.y or last[2]) - (first.y or first[2])) end
    if not width or not height or width <= 0 or height <= 0 then return nil end
    local area = width * height
    return area <= 1 and "small" or (area <= 16 and "medium" or "warehouse")
end

return config
