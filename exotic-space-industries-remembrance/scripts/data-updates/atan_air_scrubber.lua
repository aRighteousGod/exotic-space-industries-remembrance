--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["atan-air-scrubbing"] then
    return
end

local ei_lib = require("lib/lib")

--atan-air-scrubber main entity, prefixes name with quality- when placed

local aas = ei_lib.raw.furnace["atan-air-scrubber"]
if aas then
    aas.energy_usage = "1.337MW"
    for name, quality in pairs(data.raw["quality"]) do
        local target = name.."-atan-air-scrubber"
        local type_aas = ei_lib.raw.furnace[target]
        if type_aas then
            local usage = 1.337-(1.337*((quality.level-1)*0.0725))
            type_aas.energy_usage = tostring(usage).."MW"
        end
    end
end

ei_lib.raw.technology["atan-pollution-scrubbing"].age = "computer-age"

ei_lib.raw.recipe["atan-air-scrubber"] = {
    category = "crafting-with-fluid",
    energy_required = 20,
    ingredients = {
        { type = "item", name = "ei-steel-mechanical-parts", amount = 20 },
        { type = "item", name = "ei-electronic-parts", amount = 10 },
        { type = "item", name = "steel-plate", amount = 10 },
        { type = "item", name = "efficiency-module", amount = 2 },
        { type = "fluid", name = "lubricant", amount = 80 }
    }
}

ei_lib.raw.recipe["atan-pollution-filter"] = {
    category = "crafting-with-fluid",
    additional_categories = {"organic-or-assembling"},
    energy_required = 20,
    ingredients = {
        { type = "item", name = "carbon", amount = 4 },
        { type = "item", name = "steel-plate", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 2 },
        { type = "fluid", name = "ei-medium-destilate", amount = 100 }
    }
}

ei_lib.raw.recipe["atan-spore-filter"] = {
    category = "crafting-with-fluid",
    additional_categories = {"organic-or-assembling"},
    energy_required = 20,
    ingredients = {
        { type = "item", name = "carbon", amount = 4 },
        { type = "item", name = "steel-plate", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 2 },
        { type = "fluid", name = "ei-medium-destilate", amount = 100 }
    }
}
        
ei_lib.raw.recipe["atan-pollution-filter-cleaning"] = {
    energy_required = 180,
    allow_productivity = false,
    ingredients = {
        { type = "item", name = "atan-used-pollution-filter", amount = 10 },
        { type = "fluid", name = "steam", amount = 3750, minimum_temperature = 300 },
        { type = "fluid", name = "ei-kerosene", amount = 50 }
    },
    results = {
    {
        type = "item",
        name = "atan-pollution-filter",
        amount_min = 4,
        amount_max = 10,
        ignored_by_productivity = 10,
    },
    {
        type = "fluid",
        name = "ei-dirty-water",
        amount_min = 125,
        amount_max = 375,
        ignored_by_productivity = 375,
        probability = 1,
    },
    {
        type = "item",
        name = "atan-ash",
        amount_min = 3,
        amount_max = 30,
        probability = 0.75,
        ignored_by_productivity = 30,
    },
},
}

ei_lib.raw.recipe["atan-spore-filter-cleaning"] = {
    energy_required = 180,
    allow_productivity = false,
    ingredients = {
        { type = "item", name = "atan-used-spore-filter", amount = 10 },
        { type = "fluid", name = "steam", amount = 3750, minimum_temperature = 300 },
        { type = "fluid", name = "ei-kerosene", amount = 50 }
    },
    results = {
    {
        type = "item",
        name = "atan-spore-filter",
        amount_min = 4,
        amount_max = 10,
        ignored_by_productivity = 10,
    },
    {
        type = "fluid",
        name = "ei-dirty-water",
        amount_min = 125,
        amount_max = 375,
        probability = 1,
        ignored_by_productivity = 375,
    },
    {
        type = "item",
        name = "spoilage",
        amount_min = 3,
        amount_max = 30,
        probability = 0.75,
        ignored_by_productivity = 30,
    },
},
}