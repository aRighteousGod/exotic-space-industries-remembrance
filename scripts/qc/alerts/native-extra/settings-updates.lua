-- This fixture exercises the ecology window regardless of cached staging settings.
local setting=data.raw['bool-setting']['ei-terrain-evolution-enabled']
setting.default_value=true;setting.hidden=true;setting.forced_value=true
data.raw['bool-setting']['ei-admin-tools-enabled'].default_value=true
