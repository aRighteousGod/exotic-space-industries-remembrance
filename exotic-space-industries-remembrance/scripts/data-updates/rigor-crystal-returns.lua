--==============================================================================
-- ESIR FILE MAP
-- owns: Rigor target selection around conserved high-energy crystal returns
-- loaded_by: data-updates.lua after recipe declarations and compatibility patches
-- cadence: data updates only, before Rigor's final variant generation
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/recipe-economy.md#contract
-- blueprint-ref: .codex/esir/blueprints/recipe-economy.md#crystal-rigor
if not mods["rigor-module"] then return end
local rigor = require("__rigor-module__.data-utils")

for _, recipe in pairs(data.raw.recipe) do
    local consumes, high, ordinary = false, nil, nil
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if ingredient.name == "ei-high-energy-crystal" then consumes = true end
    end
    for _, result in ipairs(recipe.results or {}) do
        if result.name == "ei-high-energy-crystal" then high = result end
        if result.name == "ei-energy-crystal" then ordinary = result end
    end
    if consumes and high and ordinary then
        -- Rigor normally selects the rarest result, which would improve the
        -- depleted crystal and alter the approved 98/2, 90/10 or 92/8 return.
        -- Its own selector can still improve an unrelated random byproduct.
        local candidates = {results = {}}
        high.rigor_product, ordinary.rigor_product = nil, nil
        for _, result in ipairs(recipe.results) do
            if result ~= high and result ~= ordinary then
                table.insert(candidates.results, result)
            end
        end
        local selected = rigor.choose_rigor_ingredient_idx(candidates)
        if selected then candidates.results[selected].rigor_product = true
        else recipe.rigor_blacklist = true end
    end
end
