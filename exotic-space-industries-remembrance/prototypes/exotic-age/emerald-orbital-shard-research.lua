--==============================================================================
-- ESIR FILE MAP
-- owns: Emerald Apocalypse orbital shard and scripted tank doctrine upgrade technologies
-- loaded_by: prototypes/exotic-age/exotic-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================

local ei_data = require("lib/data")

local tank_name = "ei-emerald-apocalypse-hover-tank"
local tank_tech_icon = ei_graphics_tech_4_path.."emerald-apocalypse-hover-tank.png"

local function emerald_upgrade_technology(name, prerequisite, order)
    return {
        name = name,
        type = "technology",
        localised_name = {"technology-name."..name},
        localised_description = {"technology-description."..name},
        icon = tank_tech_icon,
        icon_size = 256,
        prerequisites = type(prerequisite) == "table" and prerequisite or {prerequisite},
        effects = {
            {
                type = "nothing",
                effect_description = {"modifier-description."..name},
            },
        },
        unit = {
            count = 10,
            ingredients = ei_data.science["exotic-age"],
            time = 20,
        },
        age = "exotic-age",
        upgrade = true,
        order = "e-a["..tank_name.."]-s["..order.."]",
    }
end

data:extend({
    emerald_upgrade_technology("ei-emerald-shard-manifold-1", tank_name, "a-1"),
    emerald_upgrade_technology("ei-emerald-shard-manifold-2", "ei-emerald-shard-manifold-1", "a-2"),
    emerald_upgrade_technology("ei-emerald-shard-manifold-3", "ei-emerald-shard-manifold-2", "a-3"),

    emerald_upgrade_technology("ei-emerald-reload-litany-1", tank_name, "b-1"),
    emerald_upgrade_technology("ei-emerald-reload-litany-2", "ei-emerald-reload-litany-1", "b-2"),
    emerald_upgrade_technology("ei-emerald-reload-litany-3", "ei-emerald-reload-litany-2", "b-3"),

    emerald_upgrade_technology("ei-emerald-target-verdict", tank_name, "c-1"),

    emerald_upgrade_technology("ei-emerald-verdict-aperture-1", "ei-emerald-target-verdict", "d-1"),
    emerald_upgrade_technology("ei-emerald-verdict-aperture-2", "ei-emerald-verdict-aperture-1", "d-2"),
    emerald_upgrade_technology("ei-emerald-verdict-aperture-3", "ei-emerald-verdict-aperture-2", "d-3"),

    emerald_upgrade_technology("ei-emerald-charge-catechism-1", tank_name, "e-1"),
    emerald_upgrade_technology("ei-emerald-charge-catechism-2", "ei-emerald-charge-catechism-1", "e-2"),
    emerald_upgrade_technology("ei-emerald-charge-catechism-3", "ei-emerald-charge-catechism-2", "e-3"),

    emerald_upgrade_technology("ei-emerald-inertial-oath-1", tank_name, "f-1"),
    emerald_upgrade_technology("ei-emerald-inertial-oath-2", "ei-emerald-inertial-oath-1", "f-2"),

    emerald_upgrade_technology("ei-emerald-aegis-covenant-1", tank_name, "g-1"),
    emerald_upgrade_technology("ei-emerald-aegis-covenant-2", "ei-emerald-aegis-covenant-1", "g-2"),

    emerald_upgrade_technology("ei-emerald-vector-keel-1", tank_name, "h-1"),
    emerald_upgrade_technology("ei-emerald-vector-keel-2", "ei-emerald-vector-keel-1", "h-2"),

    emerald_upgrade_technology("ei-emerald-collapse-mandate-1", tank_name, "i-1"),
    emerald_upgrade_technology("ei-emerald-collapse-mandate-2", "ei-emerald-collapse-mandate-1", "i-2"),
    emerald_upgrade_technology("ei-emerald-collapse-mandate-3", "ei-emerald-collapse-mandate-2", "i-3"),

    emerald_upgrade_technology("ei-emerald-apocalypse-recursion", {
        "ei-emerald-charge-catechism-3",
        "ei-emerald-inertial-oath-2",
        "ei-emerald-aegis-covenant-2",
        "ei-emerald-vector-keel-2",
        "ei-emerald-collapse-mandate-3",
    }, "j-1"),
})
