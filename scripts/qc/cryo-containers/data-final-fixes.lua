local config = require("test-config")
if config.baseline then
    assert(not data.raw.technology["ei-propellant-cryo-container"], "Baseline must use the pre-feature main mod")
    return
end
local cases = require("cases")
local science = require("__exotic-space-industries-remembrance__/lib/data").science
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, "CRYO FINAL: "..message)
end
local function pack_set(ingredients)
    local names = {}
    for _, ingredient in pairs(ingredients) do names[#names + 1] = (ingredient.name or ingredient[1])..":"..(ingredient.amount or ingredient[2]) end
    table.sort(names)
    return table.concat(names, ",")
end
local snapshot = {capacity = config.capacity, items = {}, recipes = {}, technologies = {}, machines = {}}
local expected_items, expected_recipes = {}, {}
for _, row in ipairs(cases.fluids) do
    local item_name = "ei-cryo-container-"..row[2]
    local item = data.raw.item[item_name]
    check(item and item.stack_size == 50, item_name.." stack")
    check(not item.spoil_ticks, item_name.." no spoilage")
    expected_items[item_name] = true
    snapshot.items[item_name] = item
    check(data.raw.fluid[row[1]].auto_barrel == false, row[1].." regular barrel exclusion")
    for _, direction in ipairs({"fill", "empty"}) do
        local name = "ei-"..direction.."-cryo-container-"..row[2]
        local recipe = data.raw.recipe[name]
        expected_recipes[name] = true
        snapshot.recipes[name] = recipe
        check(recipe and recipe.category == "crafting-with-fluid" and recipe.energy_required == 1, name.." machine and time")
        check(recipe.enabled == false and recipe.allow_productivity == false and recipe.allow_quality == false and recipe.auto_recycle == false, name.." transfer flags")
        check(not recipe.surface_conditions and not recipe.hidden and not recipe.hidden_in_factoriopedia, name.." visibility/surface")
        local fluid_side = direction == "fill" and recipe.ingredients or recipe.results
        local found = false
        for _, ingredient in pairs(fluid_side) do
            if ingredient.type == "fluid" then
                found = ingredient.name == row[1] and ingredient.amount == config.capacity and ingredient.temperature == row[3]
            end
        end
        check(found, name.." capacity and temperature")
        local owners = {}
        for tech_name, technology in pairs(data.raw.technology) do
            for _, effect in pairs(technology.effects or {}) do
                if effect.type == "unlock-recipe" and effect.recipe == name then owners[#owners + 1] = tech_name end
            end
        end
        check(#owners == 1 and owners[1] == "ei-"..cases.families[row[4]][1].."-cryo-container", name.." sole unlock owner")
    end
end
local item_count, recipe_count, tech_count = 0, 0, 0
for name in pairs(data.raw.item) do
    if name:find("^ei%-cryo%-container%-") and name ~= "ei-cryo-container-nitrogen" and name ~= "ei-cryo-container-oxygen" then
        check(expected_items[name], "unexpected cryo item "..name)
        item_count = item_count + 1
    end
end
for name in pairs(data.raw.recipe) do
    if (name:find("^ei%-fill%-cryo%-container%-") or name:find("^ei%-empty%-cryo%-container%-")) and not name:find("%-nitrogen$") and not name:find("%-oxygen$") and not name:find("%-recycling$") then
        check(expected_recipes[name], "unexpected cryo recipe "..name)
        recipe_count = recipe_count + 1
    end
end
for _, family in ipairs(cases.families) do
    local name = "ei-"..family[1].."-cryo-container"
    local technology = data.raw.technology[name]
    snapshot.technologies[name] = technology
    check(technology and technology.unit.time == 20, name.." time")
    check(#technology.prerequisites == 2 and technology.prerequisites[1] == "ei-cryo-container" and technology.prerequisites[2] == family[2], name.." exact gates")
    local ingredients = family[4] and data.raw.technology[family[4]].unit.ingredients or science[family[3]]
    check(pack_set(technology.unit.ingredients) == pack_set(ingredients), name.." final science")
    if family[1] == "aquilan" then check(not pack_set(technology.unit.ingredients):find("cryogenic%-science%-pack"), name.." no cryogenic science") end
    local visiting, visited = {}, {}
    local function visit(id)
        check(not visiting[id], "research cycle "..id)
        if visited[id] then return end
        visiting[id] = true
        for _, prerequisite in pairs(data.raw.technology[id].prerequisites or {}) do visit(prerequisite) end
        visiting[id] = nil
        visited[id] = true
    end
    visit(name)
    tech_count = tech_count + 1
end
check(item_count == 9 and recipe_count == 18 and tech_count == 4, "exact feature counts")
for _, fluid in ipairs({"ei-acidic-water", "fluoroketone-cold", "fluoroketone-hot"}) do
    check(data.raw.recipe[fluid.."-barrel"] and data.raw.recipe["empty-"..fluid.."-barrel"], fluid.." regular recipes")
    for _, name in ipairs({fluid.."-barrel", "empty-"..fluid.."-barrel"}) do
        local owner = false
        for _, effect in pairs(data.raw.technology["fluid-handling"].effects or {}) do
            if effect.recipe == name then owner = true end
        end
        check(owner, name.." fluid-handling unlock")
    end
end
for name, machine in pairs(data.raw["assembling-machine"]) do
    for _, category in pairs(machine.crafting_categories) do
        if category == data.raw.recipe["ei-fill-cryo-container-nitrogen"].category then snapshot.machines[#snapshot.machines + 1] = name end
    end
end
check(#snapshot.machines > 0, "native crafting machines")
snapshot.checks = checks
snapshot.counts = {items = item_count, recipes = recipe_count, technologies = tech_count}
data:extend({{type = "mod-data", name = "cryo-qc-final", data = snapshot}})
log("CRYO FINAL PASSED: "..checks.." checks")
