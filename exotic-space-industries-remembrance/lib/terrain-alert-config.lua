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
local model={definitions={},schema={},by_name={},categories={
    "wildfire","flood","drought","cliff","paving","pollution","restoration","depletion-scars","working-scars",
    "mining-restoration","tree-stress","tree-recovery","regrowth","aging","rot","thermal","blood"}}
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
local defaults={wildfire=true,flood=true,drought=true,cliff=true,paving=true}
for _,category in ipairs(model.categories) do define(category,"bool-setting",defaults[category] or false) end
return model
