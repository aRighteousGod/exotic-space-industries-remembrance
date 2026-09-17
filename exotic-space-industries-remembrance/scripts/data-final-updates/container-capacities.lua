--==============================================================================
-- ESIR FILE MAP
-- owns: all non-K2SO storage capacity overrides; fixed vehicle depot inventory
-- loaded_by: data-final-fixes.lua after compatibility/prototype creation
-- cadence: once at data-final-fixes; no runtime scans or stored state
--==============================================================================
local config = require("lib/container-capacity-config")
local profile = config.resolve()

-- Scan every item subtype: modded storage need not be placed by a plain item.
local placeable = {}
for _, prototypes in pairs(data.raw) do
    for _, prototype in pairs(prototypes) do
        if prototype.place_result and not prototype.hidden then
            local hidden = false
            for _, flag in ipairs(prototype.flags or {}) do
                if flag == "hidden" then hidden = true end
            end
            if not hidden then placeable[prototype.place_result] = true end
        end
    end
end
for _, prototype_type in ipairs({"container", "logistic-container", "linked-container"}) do
    for _, prototype in pairs(data.raw[prototype_type] or {}) do
        local tier = config.classify(prototype, placeable)
        if tier then prototype.inventory_size = profile[tier] end
    end
end

-- This is a vehicle interface, not general storage; preserve its old override.
local depot = data.raw.container and data.raw.container["vehicle-depot-chest"]
if mods["aai-programmable-vehicles"] and depot then depot.inventory_size = 18 end
