--==============================================================================
-- ESIR FILE MAP
-- owns: fluid safety ignore-list startup setting and runtime predicate
-- loaded_by: exotic-space-industries-remembrance\settings.lua, runtime fluid modules
-- cadence: settings-stage definition; runtime on-demand cache
-- forwarded_events: is_ignored_entity, parse_ignored_entities, reset_cache, startup_setting_definition
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup setting changes
--==============================================================================

local config = {}

config.setting_name = "ei-fluid-safety-ignored-entities"
config.default_ignored_entities = {
    "tnd-input-pump",
    "tnd-output-pump",
    "tnd-linked-pipe",
    "tnd-pipe-name",
    "tnd-storage-tank",
}
config.default_value = table.concat(config.default_ignored_entities, ",")

local cached_raw_value = nil
local cached_lookup = nil

---@param raw_value string|nil
---@return table<string, boolean>
function config.parse_ignored_entities(raw_value)
    local lookup = {}
    if type(raw_value) ~= "string" then
        return lookup
    end

    for name in string.gmatch(raw_value, "[^,%s;]+") do
        if name ~= "" then
            lookup[name] = true
        end
    end

    return lookup
end

local function read_startup_value()
    local setting = settings
        and settings.startup
        and settings.startup[config.setting_name]

    return setting and setting.value or config.default_value
end

local function get_ignored_lookup()
    local raw_value = read_startup_value()
    if cached_lookup and cached_raw_value == raw_value then
        return cached_lookup
    end

    cached_raw_value = raw_value
    cached_lookup = config.parse_ignored_entities(raw_value)
    return cached_lookup
end

---@param entity_or_name LuaEntity|string|nil
---@return boolean
function config.is_ignored_entity(entity_or_name)
    local name = nil
    if type(entity_or_name) == "string" then
        name = entity_or_name
    elseif entity_or_name ~= nil then
        local ok, entity_name = pcall(function()
            return entity_or_name.name
        end)
        if ok then
            name = entity_name
        end
    end

    if type(name) ~= "string" or name == "" then
        return false
    end

    return get_ignored_lookup()[name] == true
end

function config.reset_cache()
    cached_raw_value = nil
    cached_lookup = nil
end

function config.startup_setting_definition()
    return {
        name = config.setting_name,
        type = "string-setting",
        setting_type = "startup",
        default_value = config.default_value,
        allow_blank = true,
        order = "a7bb",
    }
end

return config
