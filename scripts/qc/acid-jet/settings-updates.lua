local profile=require("test-config").profile
local setting=data.raw["string-setting"]["ei-thrower-performance-profile"]
setting.allowed_values={profile};setting.default_value=profile
