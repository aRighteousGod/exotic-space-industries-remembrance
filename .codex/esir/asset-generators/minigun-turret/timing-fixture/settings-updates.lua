local test = require("test-config")
local toggle = data.raw["bool-setting"]["ei-ballistic-divergence"]
toggle.default_value = test.ballistic
toggle.forced_value = test.ballistic
toggle.hidden = true
local preset = data.raw["string-setting"]["ei-ballistic-divergence-preset"]
preset.default_value = "tempered"
preset.allowed_values = {"tempered"}
