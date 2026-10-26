--==============================================================================
-- ESIR FILE MAP
-- owns: stage-safe alert IDs, icons and mandatory personal setting definitions
-- loaded_by: settings.lua, prototypes/alerts.lua, lib/alerts.lua, terrain-alert-config.lua
-- cadence: settings/data loading and runtime constant lookup
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: module loading
--==============================================================================
-- blueprint: .codex/esir/blueprints/runtime-alerts.md#contract
local model = {entries = {}, by_id = {}, by_setting = {}, ecology_categories = {}}

---@class EsirAlertDefinition
---@field id string
---@field channel string
---@field setting_name string
---@field default_enabled boolean
---@field icon_signal string
---@field category string?
---@field master string?
---@field localised_name LocalisedString
---@field localised_description LocalisedString
---@field order string

---@param entry EsirAlertDefinition
function model.add(entry)
    assert(type(entry.id) == "string" and not model.by_id[entry.id], "Invalid or duplicate ESIR alert ID")
    assert(type(entry.channel) == "string" and type(entry.default_enabled) == "boolean", "ESIR alerts require a channel and explicit default")
    assert(type(entry.setting_name) == "string" and not model.by_setting[entry.setting_name], "ESIR alerts require unique personal settings")
    assert(type(entry.icon_signal) == "string" and entry.localised_name and entry.localised_description and entry.order, "Incomplete ESIR alert presentation")
    model.entries[#model.entries + 1] = entry
    model.by_id[entry.id] = entry
    model.by_setting[entry.setting_name] = entry
end

local operational = {
    {"gate-low-power", "ei-gate-notifications", default_enabled=true},
    {"black-hole-containment", "ei-black-hole-notifications", default_enabled=true},
    {"matter-cascade", "ei-matter-machine-notifications", default_enabled=true},
    {"gaia-degradation", default_enabled=true},
    {"fluid-phase-shift", "ei-insulated-pipe-notifications", default_enabled=true},
    {"fluid-data", "ei-insulated-pipe-notifications", default_enabled=true},
    {"fluid-cryo", "ei-insulated-pipe-notifications", default_enabled=true},
    {"fluid-thermal", "ei-insulated-pipe-notifications", default_enabled=true},
    {"fluid-chemical", "ei-insulated-pipe-notifications", default_enabled=true},
    {"fluid-rupture", "ei-insulated-pipe-notifications", default_enabled=true},
}
for index, row in ipairs(operational) do
    model.add{id=row[1], channel="operational", master=row[2], setting_name="ei-alert-"..row[1],
        default_enabled=row.default_enabled, icon_signal="ei-alert-"..row[1], order=string.format("e-alert-%02d-1",index),
        localised_name={"ei-alerts.name-"..row[1]}, localised_description={"ei-alerts.setting-"..row[1]}}
end
for index, row in ipairs{
    {"wildfire",true},{"flood",true},{"drought",true},{"cliff",true},{"paving",true},
    {"pollution",false},{"restoration",false},{"depletion-scars",false},{"working-scars",false},
    {"mining-restoration",false},{"tree-stress",false},{"tree-recovery",false},{"regrowth",false},
    {"aging",false},{"rot",false},{"thermal",false},{"blood",false}
} do
    local category = row[1]
    model.ecology_categories[#model.ecology_categories + 1] = category
    model.add{id="ecology-"..category, channel="ecology", category=category, master="ei-ecology-alert-enabled",
        setting_name="ei-ecology-alert-"..category, default_enabled=row[2],
        icon_signal="ei-alert-ecology-"..category, order=string.format("d-ecology-alert-%03d",index+4),
        localised_name={"mod-setting-name.ei-ecology-alert-"..category},
        localised_description={"mod-setting-description.ei-ecology-alert-"..category}}
end

---@param channel string? Optional selection; omission generates every alert setting.
function model.setting_definitions(channel)
    local definitions = {}
    for _, entry in ipairs(model.entries) do
        if not channel or channel == entry.channel then
            definitions[#definitions + 1] = {type="bool-setting", name=entry.setting_name,
                setting_type="runtime-per-user", default_value=entry.default_enabled, hidden=false,
                localised_name=entry.localised_name, localised_description=entry.localised_description, order=entry.order}
        end
    end
    return definitions
end
return model
