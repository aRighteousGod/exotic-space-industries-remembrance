-- Isolated fixture settings; never loaded by the shipping mod.
local config = require("test-config")
local setting = assert(data.raw["bool-setting"]["ei-ballistic-divergence"])
setting.default_value = config.ballistic
setting.forced_value = config.ballistic
setting.hidden = true
local preset = assert(data.raw["string-setting"]["ei-ballistic-divergence-preset"])
preset.default_value = "tempered"
preset.allowed_values = {"tempered"}
