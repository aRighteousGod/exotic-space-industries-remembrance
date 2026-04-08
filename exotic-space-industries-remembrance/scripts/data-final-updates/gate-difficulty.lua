local ei_lib = require("lib/lib")
local ei_data = require("lib/data")

local gate_tech = data.raw.technology["ei-gate"]
local gate_recipe = data.raw.recipe["ei-gate"]
local receiver_recipe = data.raw.recipe["ei-gate-receiver"]

if not gate_tech or not gate_recipe or not receiver_recipe then
    return
end

local attunement_setting = settings.startup["ei-gate-difficulty"]
local attunement = (attunement_setting and attunement_setting.value) or "Recovered"

-- Use the current gate and receiver as the hard floor for every harder attunement.
local base_gate_ingredients = table.deepcopy(gate_recipe.ingredients or {})
local base_receiver_ingredients = table.deepcopy(receiver_recipe.ingredients or {})

local function merge_ingredients(base_ingredients, extra_ingredients)
    local merged = table.deepcopy(base_ingredients)

    for _, extra in ipairs(extra_ingredients or {}) do
        local found = false

        for _, ingredient in ipairs(merged) do
            if ingredient.type == extra.type and ingredient.name == extra.name then
                ingredient.amount = (ingredient.amount or 0) + (extra.amount or 0)
                found = true
                break
            end
        end

        if not found then
            table.insert(merged, table.deepcopy(extra))
        end
    end

    return merged
end

local profiles = {
    ["Recovered"] = {
        prerequisites = {"ei-alien-computer-age-tech", "ei-purifier"},
        science_key = "alien-computer-age",
        count = 100,
        time = 20,
        age = "alien-computer-age",
        gate_extras = {},
        receiver_extras = {},
    },
    ["Attuned"] = {
        prerequisites = {"ei-alien-computer-age-tech", "ei-purifier", "ei-bio-reactor", "ei-crystal-accumulator"},
        science_key = "alien-computer-age",
        count = 250,
        time = 30,
        age = "alien-computer-age",
        gate_extras = {
            {type = "item", name = "ei-sus-plating", amount = 120},
            {type = "item", name = "ei-condensed-cryodust", amount = 80},
            {type = "item", name = "ei-high-energy-crystal", amount = 40},
        },
        receiver_extras = {
            {type = "item", name = "ei-sus-plating", amount = 30},
            {type = "item", name = "ei-condensed-cryodust", amount = 16},
            {type = "item", name = "ei-high-energy-crystal", amount = 4},
        },
    },
    ["Resonant"] = {
        prerequisites = {"ei-purifier", "ei-exotic-assembler", "ei-cavity", "ei-plasma-cube", "ei-high-tech-parts"},
        science_key = "both-quantum-age",
        count = 500,
        time = 40,
        age = "both-quantum-age",
        gate_extras = {
            {type = "item", name = "ei-odd-plating", amount = 140},
            {type = "item", name = "ei-plasma-cube", amount = 24},
            {type = "item", name = "ei-cavity", amount = 16},
            {type = "item", name = "ei-high-tech-parts", amount = 60},
        },
        receiver_extras = {
            {type = "item", name = "ei-odd-plating", amount = 36},
            {type = "item", name = "ei-plasma-cube", amount = 5},
            {type = "item", name = "ei-cavity", amount = 3},
            {type = "item", name = "ei-high-tech-parts", amount = 12},
        },
    },
    ["Paradox"] = {
        prerequisites = {"ei-purifier", "ei-exotic-age", "ei-matter-stabilizer", "ei-gauss-module"},
        science_key = "exotic-age",
        count = 800,
        time = 50,
        age = "exotic-age",
        gate_extras = {
            {type = "item", name = "ei-odd-plating", amount = 200},
            {type = "item", name = "ei-plasma-cube", amount = 40},
            {type = "item", name = "ei-cavity", amount = 24},
            {type = "item", name = "ei-high-tech-parts", amount = 100},
            {type = "item", name = "ei-matter-stabilizer", amount = 10},
            {type = "item", name = "ei-gauss-module", amount = 2},
            {type = "item", name = "ei-exotic-matter-up", amount = 16},
            {type = "item", name = "ei-exotic-matter-down", amount = 16},
        },
        receiver_extras = {
            {type = "item", name = "ei-odd-plating", amount = 48},
            {type = "item", name = "ei-plasma-cube", amount = 8},
            {type = "item", name = "ei-cavity", amount = 4},
            {type = "item", name = "ei-high-tech-parts", amount = 20},
            {type = "item", name = "ei-matter-stabilizer", amount = 2},
            {type = "item", name = "ei-gauss-module", amount = 1},
            {type = "item", name = "ei-exotic-matter-up", amount = 4},
            {type = "item", name = "ei-exotic-matter-down", amount = 4},
        },
    },
}

local profile = profiles[attunement] or profiles["Recovered"]

ei_lib.set_prerequisites("ei-gate", profile.prerequisites)
ei_lib.set_age_packs("ei-gate", profile.science_key)
gate_tech.unit.count = profile.count
gate_tech.unit.time = profile.time
gate_tech.age = profile.age

gate_recipe.ingredients = merge_ingredients(base_gate_ingredients, profile.gate_extras)
receiver_recipe.ingredients = merge_ingredients(base_receiver_ingredients, profile.receiver_extras)
