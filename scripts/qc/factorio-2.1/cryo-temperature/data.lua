local config = require("test-config")
assert(not (config.galore and config.mutate), "Select Galore overrides or the replacement-fluid fixture")
if not config.galore then return end

-- Space Age Galore applies both temperature overrides in the initial data stage.
-- Source: Project-Galore 85e1e446e63621f2f67ec7669bbc1f572ef00992,
-- space_age_galore/overrides/overrides.lua, lines 27-35.
data.raw.fluid["ammoniacal-solution"].default_temperature = 15
data.raw.fluid["ammoniacal-solution"].max_temperature = 100
data.raw.fluid.ammonia.default_temperature = 15
data.raw.fluid.ammonia.max_temperature = 450
data.raw.fluid.ammonia.gas_temperature = -33
