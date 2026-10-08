-- Fixture-only startup default. Fresh staged runs do not copy user mod-settings.dat.
local config=require("test-config")
local setting=assert(data.raw["string-setting"]["ei-anisetron-visual-fidelity"])
assert(setting.default_value=="standard")
assert(table.concat(setting.allowed_values,",")=="off,lean,standard,cinematic,maximal,unbounded")
setting.default_value=config.fidelity
