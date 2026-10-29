--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["air-scrubber"] then
    return
end

local ei_lib = require("lib/lib")

--atan-air-scrubber main entity, prefixes name with quality- when placed

local base_usage = 1.337
local max_reduction = 0.35
local curve_blend = 0.15 -- 0 = linear, 1 = smoothstep

local aas = ei_lib.raw.furnace["atan-air-scrubber"]
if aas then
    aas.fast_replaceable_group = "ei-air-scrubber"
    aas.energy_usage = base_usage .. "MW"

    local qualities = data.raw["quality"]
    if qualities and (mods["quality"] or mods["quality-se"]) then
        local quality_count = ei_lib.getn(qualities)
        local steps = math.max(quality_count - 1, 1)

        for name, quality in pairs(qualities) do
            local target = name .. "-atan-air-scrubber"
            local type_aas = data.raw.furnace[target]

            if type_aas then
                type_aas.fast_replaceable_group = "ei-air-scrubber"
                -- normalize quality level to 0..1
                local t = math.min(
                    math.max((quality.level - 1) / steps, 0),
                    1
                )

                -- linear curve
                local linear = t

                -- smoothstep S-curve
                local smooth = t * t * (3 - 2 * t)

                -- blend curves
                local curve = linear * (1 - curve_blend) + smooth * curve_blend

                local reduction = max_reduction * curve
                local usage = math.max(0.985,base_usage * (1 - reduction))
            
                type_aas.energy_usage = tostring(usage) .. "MW"
            end
        end
    end
end


ei_lib.raw.technology["atan-pollution-scrubbing"].age = "computer-age"

ei_lib.raw.recipe["atan-air-scrubber"].categories = {"crafting-with-fluid"}
ei_lib.raw.recipe["atan-air-scrubber"] = {
    energy_required = 20,
    ingredients = {
        { type = "item", name = "ei-steel-mechanical-parts", amount = 20 },
        { type = "item", name = "ei-electronic-parts", amount = 10 },
        { type = "item", name = "steel-plate", amount = 10 },
        { type = "item", name = "efficiency-module", amount = 2 },
        { type = "fluid", name = "lubricant", amount = 80 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()}
    }
}

ei_lib.raw.recipe["atan-pollution-filter"].categories = {"crafting-with-fluid", "ei-organic-or-assembling"}
ei_lib.raw.recipe["atan-pollution-filter"] = {
    energy_required = 20,
    ingredients = {
        { type = "item", name = "carbon", amount = 4 },
        { type = "item", name = "steel-plate", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 2 },
        { type = "fluid", name = "ei-medium-destilate", amount = 100 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()}
    }
}

ei_lib.raw.recipe["atan-spore-filter"].categories = {"crafting-with-fluid", "ei-organic-or-assembling"}
ei_lib.raw.recipe["atan-spore-filter"] = {
    energy_required = 20,
    ingredients = {
        { type = "item", name = "carbon-fiber", amount = 4 },
        { type = "item", name = "steel-plate", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 2 },
        { type = "fluid", name = "ei-heavy-destilate", amount = 100 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()}
    }
}
        
-- Restore the original organic/chemistry routing; the selected fork's pollution
-- recipe accidentally substitutes advanced-crafting for chemistry.
ei_lib.raw.recipe["atan-pollution-filter-cleaning"].categories = {"ei-organic-or-chemistry"}
ei_lib.raw.recipe["atan-spore-filter-cleaning"].categories = {"ei-organic-or-chemistry"}
ei_lib.raw.recipe["atan-pollution-filter-cleaning"] = {
    energy_required = 180,
    allow_productivity = false,
    ingredients = {
        { type = "item", name = "atan-used-pollution-filter", amount = 10 },
        { type = "fluid", name = "steam", amount = 3750, minimum_temperature = 300 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "ei-kerosene", amount = 50 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()}
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
        independent_probability = 1,
     fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
    {
        type = "item",
        name = "atan-ash",
        amount_min = 3,
        amount_max = 30,
        independent_probability = 0.75,
        ignored_by_productivity = 30,
    },
},
}

ei_lib.raw.recipe["atan-spore-filter-cleaning"] = {
    energy_required = 180,
    allow_productivity = false,
    ingredients = {
        { type = "item", name = "atan-used-spore-filter", amount = 10 },
        { type = "fluid", name = "steam", amount = 3750, minimum_temperature = 500 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()},
        { type = "fluid", name = "ei-kerosene", amount = 50 , fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier()}
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
        independent_probability = 1,
        ignored_by_productivity = 375,
     fluidbox_multiplier = ei_lib.recipe_fluidbox_multiplier(nil, true)},
    {
        type = "item",
        name = "spoilage",
        amount_min = 3,
        amount_max = 30,
        independent_probability = 0.75,
        ignored_by_productivity = 30,
    },
},
}

ei_lib.set_prerequisites("atan-spore-scrubbing", {"carbon-fiber","atan-pollution-scrubbing"})
