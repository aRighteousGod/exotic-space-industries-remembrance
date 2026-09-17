local test = require("test-config")
local setting = data.raw["string-setting"]["ei-container-capacity-profile"]
assert(#setting.allowed_values == 8)
assert(setting.default_value == "restrained")
assert(setting.localised_description[2][1] == "")
assert(#setting.localised_description[2] == 9)
setting.allowed_values = {test.profile}
setting.default_value = test.profile
if test.k2so then
    for _, name in ipairs({"ei-enable-preliminary-k2so-patch", "kr-containers"}) do
        local boolean = data.raw["bool-setting"][name]
        assert(boolean, name)
        boolean.hidden = true
        boolean.forced_value = true
        boolean.default_value = true
    end
end
