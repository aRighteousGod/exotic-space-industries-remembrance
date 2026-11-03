-- Private legacy-input profile. The runtime definitions retain shipped defaults.
-- Invalid saved native values fall back to the sole admitted legacy value.
local converted = require("options-expected")
for _, name in ipairs(converted) do
    local prototype
    for _, kind in ipairs{"bool-setting", "int-setting", "double-setting", "string-setting"} do
        prototype = data.raw[kind] and data.raw[kind][name]
        if prototype then break end
    end
    assert(prototype and prototype.setting_type == "startup", "Missing legacy input: " .. name)
    local value = prototype.default_value
    if prototype.type == "bool-setting" then value = not value
    elseif prototype.allowed_values and #prototype.allowed_values > 0 then
        for _, candidate in ipairs(prototype.allowed_values) do
            if candidate ~= value then value = candidate; break end
        end
    elseif prototype.type == "string-setting" then value = "pipe; esir-qc-unknown-entity"
    elseif prototype.minimum_value ~= value then value = prototype.minimum_value
    else value = prototype.maximum_value end
    assert(value ~= prototype.default_value, "No alternate legacy input: " .. name)
    prototype.hidden = true
    prototype.default_value = value
    if prototype.type == "bool-setting" then prototype.forced_value = value
    else prototype.allowed_values = {value} end
end
