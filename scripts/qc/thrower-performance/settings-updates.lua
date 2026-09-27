local config = require("test-config")
local setting = data.raw["string-setting"]["ei-thrower-performance-profile"]
setting.allowed_values = {config.profile}
setting.default_value = config.profile
local adaptation = data.raw["bool-setting"]["ei-flamethrower-fuel-adaptation"]
adaptation.forced_value = config.adaptation
adaptation.default_value = config.adaptation
