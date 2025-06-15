--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["atan-air-scrubbing"] then
    return
end

local ei_lib = require("lib/lib")

ei_lib.raw.technology["atan-pollution-scrubbing"].age = "computer-age"

ei_lib.raw.recipe["atan-air-scrubber"] = {
    category = "crafting-with-fluid",
    energy_required = 20,
    ingredients = {
        { type = "item", name = "ei-steel-mechanical-parts", amount = 20 },
        { type = "item", name = "ei-electronic-parts", amount = 10 },
        { type = "item", name = "steel-plate", amount = 10 },
        { type = "item", name = "efficiency-module", amount = 2 },
        { type = "fluid", name = "ei-lube-destilate", amount = 80 }
    }
}

ei_lib.raw.recipe["atan-pollution-filter"] = {
    category = "crafting-with-fluid",
    additional_categories = {"organic-or-assembling"},
    ingredients = {
        { type = "item", name = "carbon", amount = 2 },
        { type = "item", name = "steel-plate", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 1 },
        { type = "fluid", name = "ei-medium-destilate", amount = 80 }
    }
}

ei_lib.raw.recipe["atan-spore-filter"] = {
    category = "crafting-with-fluid",
    additional_categories = {"organic-or-assembling"},
    ingredients = {
        { type = "item", name = "carbon", amount = 2 },
        { type = "item", name = "steel-plate", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 1 },
        { type = "fluid", name = "ei-medium-destilate", amount = 80 }
    }
}
        
ei_lib.raw.recipe["atan-pollution-filter-cleaning"] = {
    energy_required = 60,
    ingredients = {
        { type = "item", name = "atan-used-pollution-filter", amount = 10 },
        { type = "fluid", name = "steam", amount = 500 },
        { type = "fluid", name = "ei-kerosene", amount = 50 }
    },
    results = {
    {
        type = "item",
        name = "atan-pollution-filter",
        amount_min = 6,
        amount_max = 10,
        ignored_by_productivity = 10,
    },
    {
        type = "fluid",
        name = "ei-dirty-water",
        amount_min = 125,
        amount_max = 375,
        probability = 1,
    },
    {
        type = "item",
        name = "atan-ash",
        amount_min = 1,
        amount_max = 10,
        probability = 0.75,
    },
},
}

ei_lib.raw.recipe["atan-spore-filter-cleaning"] = {
    energy_required = 60,
    ingredients = {
        { type = "item", name = "atan-used-spore-filter", amount = 10 },
        { type = "fluid", name = "steam", amount = 500 },
        { type = "fluid", name = "ei-kerosene", amount = 50 }
    },
    results = {
    {
        type = "item",
        name = "atan-spore-filter",
        amount_min = 6,
        amount_max = 10,
        ignored_by_productivity = 10,
    },
    {
        type = "fluid",
        name = "ei-dirty-water",
        amount_min = 125,
        amount_max = 375,
        probability = 1,
    },
    {
        type = "item",
        name = "spoilage",
        amount_min = 1,
        amount_max = 10,
        probability = 0.75,
    },
},
}