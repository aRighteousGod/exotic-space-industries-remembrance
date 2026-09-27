local config=require("test-config")
data.raw["bool-setting"]["ei-flamethrower-fuel-adaptation"].forced_value=config.enabled
data.raw["bool-setting"]["ei-flamethrower-fuel-adaptation"].default_value=config.enabled
data.raw["bool-setting"]["ei-flamethrower-fuel-adaptation"].hidden=true
data.raw["int-setting"]["ei-max_updates_per_tick"].default_value=config.budget
data.raw["int-setting"]["ei-max_updates_per_tick"].allowed_values={config.budget}
if config.overlap then
    local profile=data.raw["string-setting"]["ei-thrower-performance-profile"]
    profile.default_value=config.profile
    profile.allowed_values={config.profile}
end
