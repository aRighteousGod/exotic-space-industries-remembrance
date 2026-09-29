local test = require("test-config")
local toggle = data.raw["bool-setting"]["ei-beacon-overload"]
local preset = data.raw["string-setting"]["ei-beacon-diminishing-returns"]
assert(not toggle.hidden and toggle.default_value == true, "Overload visibility/default")
assert(not preset.hidden and preset.default_value == "strict", "Profile visibility/default")
assert(table.concat(preset.allowed_values, ",") == "gentle,vanilla,strict,harsh,severe,saturating", "Profile options")
assert(toggle.order < preset.order and preset.order < data.raw["bool-setting"]["ei-em_train_glow"].order, "Adjacent settings")
toggle.default_value = test.overload
toggle.forced_value = test.overload
-- Factorio only honors forced_value for hidden bool settings. The production
-- visibility was asserted above; this change is confined to the fixture.
toggle.hidden = true
preset.default_value = test.profile
preset.allowed_values = {test.profile}
