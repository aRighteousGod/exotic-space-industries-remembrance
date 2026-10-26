local ecology=data.raw["bool-setting"]["ei-terrain-evolution-enabled"]
ecology.hidden=true;ecology.default_value=not require("options").disabled;ecology.forced_value=ecology.default_value
local setting=data.raw["string-setting"]["ei-alert-icon-set-default"]
-- Fixture override proves provider inheritance; production still defaults Rendered.
setting.default_value=mods["esir-icon-sets-provider-qc"] and "esir-icon-sets-provider-qc__partial" or "rendered"
