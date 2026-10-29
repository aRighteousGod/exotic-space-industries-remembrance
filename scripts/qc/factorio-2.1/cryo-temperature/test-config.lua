---@class CryoTemperatureTestConfig
---@field mutate boolean Test a later changed range and replacement fluid identity.
---@field galore boolean Test both Space Age Galore temperature overrides in data.lua.
---@field assert_final boolean Assert final recipes; disable only for before-fix error reproduction.
---@type CryoTemperatureTestConfig
return {mutate = false, galore = false, assert_final = true}
