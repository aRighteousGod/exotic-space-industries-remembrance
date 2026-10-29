local case = require("case")
for name, value in pairs({
    ["ei-beacon-quality-modules"] = case.quality_permission,
    ["ei-beacon-productivity-modules"] = case.productivity_permission,
    ["ei-quality-module-effects"] = case.effects,
}) do
    local setting = assert(data.raw["string-setting"][name], name)
    assert(setting.setting_type == "startup" and not setting.hidden, name .. " startup visibility")
    assert(setting.default_value == (name == "ei-quality-module-effects" and "esir" or "both"), name .. " default")
    assert(table.concat(setting.allowed_values, ",") == (name == "ei-quality-module-effects"
        and "esir,vanilla" or "neither,nitrogen,alien,both"), name .. " choices")
    setting.default_value = value
    setting.allowed_values = {value}
end
local overload = data.raw["bool-setting"]["ei-beacon-overload"]
overload.default_value = case.overload
overload.forced_value = case.overload
overload.hidden = true
