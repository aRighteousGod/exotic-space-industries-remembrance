--==============================================================================
-- ESIR FILE MAP
-- owns: historical recycling eligibility and generation-stage duration policy
-- loaded_by: data.lua; data-updates.lua; scripts/data-final-updates/recycling.lua
-- cadence: data stages only
-- storage_roots: none; temporary prototype references never enter runtime
--==============================================================================
-- blueprint: .codex/esir/blueprints/recycling.md#contract
local util = require("util")
local recycling = require("__recycler__/recycling")
local policy = {}
local initial_times = {}
local temporary_opt_out = {}
local metallurgy = { ["big-mining-drill"] = true, ["turbo-transport-belt"] = true,
    ["turbo-underground-belt"] = true, ["turbo-splitter"] = true }
local cryogenics = { ["railgun-turret"] = true, railgun = true, ["cryogenic-plant"] = true,
    ["fusion-reactor"] = true, ["fusion-generator"] = true }

-- Match the old category as a set: an organic/chemistry union was eligible,
-- while chemistry/cryogenics was excluded except for batteries. Rejecting any
-- matching member would incorrectly exclude several former union categories.
function policy.can_recycle(recipe)
    if recipe.auto_recycle == false or recipe.subgroup == "empty-barrel" then return false end
    local categories = recipe.categories or {"crafting"}
    if #categories == 1 then
        local category = categories[1]
        if category == "recycling" or category == "smelting" or category == "chemistry"
            or category == "crushing" or category == "organic" then return false end
        if category == "metallurgy" and not metallurgy[recipe.name] then return false end
        if category == "cryogenics" and not cryogenics[recipe.name] then return false end
        if category == "ei-chemistry-or-cryogenics" and recipe.name ~= "battery" then return false end
    elseif #categories == 2 and recipe.name ~= "battery" then
        if (categories[1] == "chemistry" and categories[2] == "cryogenics")
            or (categories[2] == "chemistry" and categories[1] == "cryogenics") then return false end
    end
    if recipe.name:find("science", 1, true) and recipe.name:find("pack", 1, true) then return false end
    return recipe.name ~= "tungsten-carbide" and recipe.name ~= "superconductor" and recipe.name ~= "biolab"
end

-- Native generation selects one fixed-count item product, ignoring fluids.
-- Resolve the same target so a failed generation never retimes an older winner.
local function target_name(recipe)
    if not (recipe.results or recipe.result) then return end
    local result
    for _, product in pairs(util.normalize_recipe_products(recipe)) do
        if product.type == "item" then
            if result then return end
            if product.amount_min == product.amount_max then result = product.name end
        end
    end
    return result and (result .. "-recycling")
end

function policy.capture_initial()
    -- Preserve the established reverse recipe for these native items. 2.1's
    -- new redirection/opt-out would otherwise change ESIR's effective outputs.
    for _, name in ipairs({"hazard-concrete", "refined-hazard-concrete"}) do
        if data.raw.recipe[name] then data.raw.recipe[name].recycle_to_ingredients_of = nil end
    end
    if data.raw.recipe.pistol then data.raw.recipe.pistol.auto_recycle = nil end
    for _, recipe in pairs(data.raw.recipe) do
        if policy.can_recycle(recipe) then
            local target = target_name(recipe)
            if target then
                for _, ingredient in pairs(recipe.ingredients or {}) do
                    if ingredient.type == "item" then
                        initial_times[target] = (recipe.energy_required or 0.5) / 16
                        break
                    end
                end
            end
        elseif recipe.auto_recycle == nil then
            -- The native Recycler runs before ESIR data-updates. Mark only
            -- recipes, retaining the native 25% item self-recycling fallback.
            temporary_opt_out[recipe] = true
            recipe.auto_recycle = false
        end
    end
    for item_type in pairs(defines.prototypes.item) do
        for name, item in pairs(data.raw[item_type] or {}) do
            local target = name .. "-recycling"
            if not initial_times[target] and not data.raw.recipe[target] and item.auto_recycle ~= false and not item.parameter
                and not name:find("-barrel", 1, true) then
                local recipe = data.raw.recipe[name]
                initial_times[target] = (recipe and recipe.energy_required or 0.5) / 16
            end
        end
    end
    -- The new native tree-seed craft must not retime the pre-existing self
    -- recycler: 2.0 had no same-name source and used the 0.5-second fallback.
    if initial_times["tree-seed-recycling"] then initial_times["tree-seed-recycling"] = 0.5 / 16 end
end

function policy.restore_initial()
    for name, duration in pairs(initial_times) do
        if data.raw.recipe[name] then data.raw.recipe[name].energy_required = duration end
    end
    for recipe in pairs(temporary_opt_out) do
        if recipe.auto_recycle == false then recipe.auto_recycle = nil end
    end
    initial_times, temporary_opt_out = {}, {}
end

function policy.generate(recipe)
    local target = target_name(recipe)
    local previous = target and data.raw.recipe[target]
    recycling.generate_recycling_recipe(recipe, policy.can_recycle)
    local generated = target and data.raw.recipe[target]
    if generated and generated ~= previous then
        generated.energy_required = (recipe.energy_required or 0.5) / 16
    end
end

function policy.generate_self(item)
    recycling.generate_self_recycling_recipe(item)
    local source = data.raw.recipe[item.name]
    data.raw.recipe[item.name .. "-recycling"].energy_required = (source and source.energy_required or 0.5) / 16
end

return policy
