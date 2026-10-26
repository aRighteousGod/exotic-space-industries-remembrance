local config = require("test-config")
local setting = assert(data.raw["string-setting"]["ei-production-machine-lights"])
assert(setting.default_value == "status")
assert(table.concat(setting.allowed_values, ",") == "off,status,original")
-- Force a real startup value, including when a previous fixture run persisted one.
local mode = config.mode == "baseline" and "original" or config.mode
setting.default_value = mode
setting.allowed_values = {mode}
if config.arc then
    local arc = assert(data.raw["string-setting"]["ei-arc-furnace-light-flicker-preset"])
    arc.default_value = config.arc
    arc.allowed_values = {config.arc}
end
if data.raw["bool-setting"]["bnl-enable"] then
    local enabled = config.bottleneck ~= "disabled"
    data.raw["bool-setting"]["bnl-enable"].default_value = enabled
    data.raw["bool-setting"]["bnl-enable"].hidden = true
    data.raw["bool-setting"]["bnl-enable"].forced_value = enabled
    if config.bottleneck == "custom" then
        for _, status in ipairs{"disabled", "full_output", "idle", "insufficient_input", "low_power", "no_minable_resources", "no_power", "working"} do
            local color = data.raw["color-setting"]["bnl-color-" .. status]
            color.default_value = {r = 0.2, g = 0.7, b = 1, a = 1}
            color.hidden = true
            color.forced_value = {r = 0.2, g = 0.7, b = 1, a = 1}
        end
    end
end
