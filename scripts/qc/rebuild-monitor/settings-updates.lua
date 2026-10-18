-- Fixture only: exercise actual disabled-mode restoration in the full pack.
local setting=data.raw["bool-setting"] and data.raw["bool-setting"]["ei-flamethrower-fuel-adaptation"]
if setting then setting.forced_value=false;setting.default_value=false;setting.hidden=true end
