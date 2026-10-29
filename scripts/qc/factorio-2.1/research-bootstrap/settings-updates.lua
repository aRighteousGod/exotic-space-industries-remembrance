local config = require("test-config")
for name, value in pairs({["ei-no-triggers"]=config.no_triggers, ["ei-tech-tree-flatten"]=config.flatten}) do
    -- Factorio only applies forced_value to hidden settings. These overrides
    -- belong exclusively to this private QC mod, never the shipping settings.
    data.raw["bool-setting"][name].hidden = true
    data.raw["bool-setting"][name].default_value = value
    data.raw["bool-setting"][name].forced_value = value
end
