local test = require("test-config")
for _, family in ipairs{"pyric-radiance", "ballistic-divergence"} do
    local toggle = data.raw["bool-setting"]["ei-"..family]
    local preset = data.raw["string-setting"]["ei-"..family.."-preset"]
    assert(toggle and not toggle.hidden and toggle.default_value == true, family.." startup toggle")
    assert(preset and preset.default_value == "tempered" and #preset.allowed_values == 10, family.." startup preset")
    toggle.default_value = test[family.."-enabled"]
    toggle.forced_value = toggle.default_value
    toggle.hidden = true
    preset.default_value = test[family]
    preset.allowed_values = {test[family]}
end
