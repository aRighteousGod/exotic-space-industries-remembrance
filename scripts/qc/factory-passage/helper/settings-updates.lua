local fixture=require("fixture-config")
data.raw["int-setting"]["ei-factory-passage-update-budget"].default_value=fixture.budget or 256
local setting=data.raw["string-setting"]["ei-factory-passage-pipe-mode"]
setting.allowed_values={fixture.mode};setting.default_value=fixture.mode;setting.hidden=true
local enabled=data.raw["bool-setting"]["ei-factory-passage-enabled"]
enabled.hidden=true;enabled.forced_value=fixture.enabled
for _,category in ipairs{"production","power","logistics","turrets"} do
    local value=not fixture.disabled_category or fixture.disabled_category~=category
    local entry=data.raw["bool-setting"]["ei-factory-passage-"..category]
    entry.hidden=true;entry.forced_value=value
end
