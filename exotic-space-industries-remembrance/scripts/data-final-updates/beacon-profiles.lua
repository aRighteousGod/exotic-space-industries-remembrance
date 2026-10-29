--==============================================================================
-- ESIR FILE MAP
-- owns: native diminishing returns and active-mode descriptions for ESIR beacons
-- loaded_by: data-final-fixes.lua after ESIR compatibility passes
-- cadence: data stage only; the engine owns effect scaling
--==============================================================================
local config = require("lib/beacon-profile-config")
local module_policy = require("lib/module-policy-config")
local overload_enabled = settings.startup["ei-beacon-overload"].value

for _, name in ipairs(config.beacon_names) do
    local beacon = data.raw.beacon[name]
    if beacon then
        if not overload_enabled then
            beacon.profile = config.build_profile()
            beacon.beacon_counter = "total"
        end
        beacon.localised_description = {"", beacon.localised_description or {"entity-description." .. name},
            "\n\n", config.mode_description(), "\n", module_policy.family_description(module_policy.beacon_families[name])}
        local item = data.raw.item[name]
        if item then
            item.localised_description = {"", item.localised_description or {"item-description." .. name},
                "\n\n", config.mode_description(), "\n", module_policy.family_description(module_policy.beacon_families[name])}
        end
    end
end
