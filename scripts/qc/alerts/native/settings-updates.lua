-- Fixture profiles must override saved staging settings, not merely their defaults.
local options=require('options')
local ecology=data.raw['bool-setting']['ei-terrain-evolution-enabled']
ecology.default_value=not options.disabled
-- Factorio loads a bool forced_value only when the setting is hidden (fixture only).
ecology.hidden=true
ecology.forced_value=not options.disabled
data.raw['bool-setting']['ei-admin-tools-enabled'].default_value=true
