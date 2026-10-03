local enabled=require("fixture-config").enabled
local setting=data.raw["bool-setting"]["ei-admin-tools-enabled"]
setting.default_value=enabled
setting.forced_value=enabled
setting.hidden=true
