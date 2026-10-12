local config=require("test-config")
local targeting=data.raw["string-setting"]["ei-water-turret-fire-targeting"]
if targeting then targeting.default_value=config.targeting or "first-nearby" end
local adaptation=data.raw["bool-setting"]["ei-flamethrower-fuel-adaptation"]
if adaptation and config.adaptation~=nil then adaptation.default_value=config.adaptation end
