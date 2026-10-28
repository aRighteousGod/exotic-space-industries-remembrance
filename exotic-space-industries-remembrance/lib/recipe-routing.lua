--==============================================================================
-- ESIR FILE MAP
-- owns: recipe category identities and established machine eligibility
-- loaded_by: data.lua; data-updates.lua
-- cadence: data stages only
-- storage_roots: none
--==============================================================================
-- blueprint: .codex/esir/blueprints/recipe-routing.md#contract
local ei_lib = require("lib/lib")
local routing = {}
local assemblers = {"assembling-machine-2", "assembling-machine-3", "ei-neo-assembler", "ei-steam-assembler"}
local chemical_plants = {"chemical-plant", "ei-advanced-chem-plant", "ei-heat-chemical-plant"}
local grants = {
    ["ei-electronics"] = {assemblers, {"character", "assembling-machine-1", "electromagnetic-plant"}},
    ["ei-electronics-with-fluid"] = {assemblers, {"electromagnetic-plant"}},
    ["ei-electronics-or-assembling"] = {assemblers, {"electromagnetic-plant"}},
    ["ei-pressing"] = {assemblers, {"character", "assembling-machine-1", "foundry"}},
    ["ei-chemistry-or-cryogenics"] = {chemical_plants, {"cryogenic-plant"}},
    ["ei-organic-or-assembling"] = {assemblers, {"character", "biochamber"}},
    ["ei-organic-or-hand-crafting"] = {assemblers, {"character", "biochamber"}},
    ["ei-organic-or-chemistry"] = {chemical_plants, {"biochamber"}},
    ["ei-cryogenics-or-assembling"] = {assemblers, {"cryogenic-plant"}},
    ["ei-metallurgy-or-assembling"] = {assemblers, {"foundry"}},
    ["ei-crafting-with-fluid-or-metallurgy"] = {assemblers, {"foundry"}},
}

-- Bounded pre-existing recipes: new native content keeps its authored routing.
-- Apply before ESIR clones these sources into explosives and acid variants.
local native_routes = {
    {categories = {"ei-electronics"}, recipes = {
        "accumulator", "beacon", "big-electric-pole", "copper-cable", "discharge-defense-equipment",
        "efficiency-module", "efficiency-module-2", "efficiency-module-3", "electronic-circuit",
        "lightning-rod", "medium-electric-pole", "productivity-module", "productivity-module-2",
        "productivity-module-3", "quality-module", "quality-module-2", "quality-module-3",
        "small-electric-pole", "solar-panel", "speed-module-2", "speed-module-3", "substation",
        "accumulator-v2", "solar-matrix",
    }},
    {categories = {"ei-chemistry-or-cryogenics"}, recipes = {
        "acid-neutralisation", "ammonia-rocket-fuel", "ammoniacal-solution-separation", "battery", "carbon",
        "explosives", "lithium", "plastic-bar", "solid-fuel-from-ammonia", "steam-condensation", "sulfur", "sulfuric-acid",
    }},
    {categories = {"crafting-with-fluid", "ei-electronics-with-fluid"}, recipes = {"advanced-circuit"}},
    {categories = {"ei-electronics-with-fluid"}, recipes = {"speed-module"}},
    {categories = {"crafting", "ei-electronics"}, recipes = {"processing-unit"}},
    {categories = {"ei-organic-or-assembling"}, recipes = {"biochamber", "nutrients-from-biter-egg", "nutrients-from-fish", "nutrients-from-spoilage"}},
    {categories = {"ei-organic-or-hand-crafting"}, recipes = {"copper-bacteria", "iron-bacteria", "jellynut-processing", "yumako-processing"}},
    {categories = {"ei-organic-or-chemistry"}, recipes = {"fish-breeding", "heavy-oil-cracking", "light-oil-cracking"}},
    {categories = {"ei-cryogenics-or-assembling"}, recipes = {"cryogenic-plant"}},
    {categories = {"ei-electronics-or-assembling"}, recipes = {"electromagnetic-plant"}},
    {categories = {"ei-crafting-with-fluid-or-metallurgy"}, recipes = {"express-splitter", "express-transport-belt", "express-underground-belt", "holmium-plate"}},
    {categories = {"ei-pressing"}, recipes = {"fast-splitter", "fast-transport-belt", "fast-underground-belt"}},
    {categories = {"ei-metallurgy-or-assembling"}, recipes = {"foundry"}},
}

function routing.declare_and_grant()
    for category, groups in pairs(grants) do
        data:extend({{type = "recipe-category", name = category}})
        for _, names in ipairs(groups) do
            for _, name in ipairs(names) do
                local machine = data.raw["assembling-machine"][name] or data.raw.character[name]
                if machine and not ei_lib.table_contains_value(machine.crafting_categories, category) then
                    table.insert(machine.crafting_categories, category)
                end
            end
        end
    end
end

function routing.apply_native_routes()
    for _, route in ipairs(native_routes) do
        for _, name in ipairs(route.recipes) do
            local recipe = data.raw.recipe[name]
            if recipe then recipe.categories = table.deepcopy(route.categories) end
        end
    end
end

return routing
