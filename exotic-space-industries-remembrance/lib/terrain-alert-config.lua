--==============================================================================
-- ESIR FILE MAP
-- owns: per-player ecology alert setting definitions
-- loaded_by: settings.lua, terrain-alerts.lua, terrain-gui.lua
-- cadence: settings and player preference changes
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local catalog=require("lib/alert-catalog")
local model={definitions={},schema={},by_name={},categories=catalog.ecology_categories}
local function define(key,kind,default)
    local row={key=key,name="ei-ecology-alert-"..key,type=kind,default=default}
    model.schema[#model.schema+1]=row;model.by_name[row.name]=row
    model.definitions[#model.definitions+1]={type=kind,name=row.name,setting_type="runtime-per-user",default_value=default,
        order=string.format("d-ecology-alert-%03d",#model.schema),allow_blank=kind=="string-setting" and true or nil}
end
define("enabled","bool-setting",true)
define("surfaces","string-setting","all")
define("current-surface-only","bool-setting",false)
define("allow-unrevealed","bool-setting",false)
-- Category settings are generated once by the shared catalogue in settings.lua.
for _,category in ipairs(model.categories) do
    local entry=catalog.by_id["ecology-"..category]
    local row={key=category,name=entry.setting_name,type="bool-setting",default=entry.default_enabled}
    model.schema[#model.schema+1]=row;model.by_name[row.name]=row
end
return model
