--==============================================================================
-- ESIR FILE MAP
-- owns: electric offshore pump technology that unlocks the vanilla offshore pump tier
-- loaded_by: exotic-space-industries-remembrance\prototypes\electricity-age\electricity-age.lua
-- cadence: data-stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data stage reload, prototype cache rebuild
--==============================================================================

local ei_data = require("lib/data")

local base_item = data.raw.item["offshore-pump"]

data:extend({
    {
        name = "ei-electric-offshore-pump",
        type = "technology",
        icon = base_item.icon,
        icon_size = base_item.icon_size,
        prerequisites = {"ei-electricity-power", "ei-steam-offshore-pump"},
        effects = {
            {
                type = "unlock-recipe",
                recipe = "offshore-pump",
            },
        },
        unit = {
            count = 100,
            ingredients = ei_data.science["electricity-age"],
            time = 20,
        },
        age = "electricity-age",
    },
})
