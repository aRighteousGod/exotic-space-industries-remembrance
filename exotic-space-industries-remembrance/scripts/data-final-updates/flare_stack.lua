--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["Flare Stack"] then
    return
end
local ei_data = require("lib/data")
local ei_lib = require("lib/lib")

ei_lib.raw.technology["flare-stack-item-venting-tech"] = {
    prerequisites = {"flammables"},
    age = "steam-age",
    unit = {
    count = 100,
    ingredients = ei_data.science["steam-age"],
    time = 20
    },
}

ei_lib.raw.technology["flare-stack-item-venting-electric-tech"] = {
    prerequisites = {"ei-electricity-power","flammables"},
    age = "electricity-age",
    unit = {
    count = 100,
    ingredients = ei_data.science["electricity-age"],
    time = 20
    },
}

ei_lib.raw.technology["flare-stack-fluid-venting-tech"] = {
    prerequisites = {"ei-fluid-boiler","flammables"},
    age = "steam-age",
    unit = {
    count = 100,
    ingredients = ei_data.science["steam-age"],
    time = 20
    },
}

ei_lib.recipe_add("flare-stack", "ei-steel-beam", 5,false)
ei_lib.recipe_add("incinerator", "ei-iron-beam", 5,false)
ei_lib.recipe_add("electric-incinerator", "ei-iron-beam", 5,false)

ei_lib.raw.furnace["flare-stack"].energy_source.emissions_per_minute = {pollution = 16}
ei_lib.raw.furnace["electric-incinerator"].energy_source.emissions_per_minute = {pollution = 16}
ei_lib.raw.furnace["incinerator"].energy_source.emissions_per_minute = {pollution = 16}