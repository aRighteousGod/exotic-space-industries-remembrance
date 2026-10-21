local config = require("test-config")
local cases = require("cases")
local checks = 0
local function check(value, label)
    checks = checks + 1
    assert(value, "PLASMA DATA: "..label)
end
local snapshot = {recipes = {}, machines = {}, technologies = {}}
for name, recipe in pairs(data.raw.recipe) do
    if recipe.category == "ei-arc-furnace" or recipe.category == "ei-arc-smelting" or recipe.category == "ei-plasma-heater" or recipe.category == "ei-plasma-smelting" then
        snapshot.recipes[name] = table.deepcopy(recipe)
    end
end
for _, name in ipairs({"ei-arc-furnace", "ei-plasma-heater"}) do
    local machine = data.raw.furnace[name] or data.raw["assembling-machine"][name]
    snapshot.machines[name] = {}
    for _, key in ipairs({"crafting_categories", "crafting_speed", "energy_usage", "energy_source", "allowed_effects", "module_slots", "dying_explosion", "dying_trigger_effect", "damaged_trigger_effect", "open_sound", "close_sound", "factoriopedia_simulation"}) do
        snapshot.machines[name][key] = table.deepcopy(machine[key])
    end
    check(machine.dying_explosion and machine.damaged_trigger_effect and machine.open_sound and machine.close_sound and machine.factoriopedia_simulation, "presentation "..name)
end
local function has_category(machine, category)
    for _, value in ipairs(snapshot.machines[machine].crafting_categories) do if value == category then return true end end
    return false
end
for _, suffix in ipairs({"", "-advanced", "-quantum", "-exotic", "-black-hole"}) do
    local name = "ei-productivity-pure-ore-smelting"..suffix
    snapshot.technologies[name] = table.deepcopy(data.raw.technology[name])
end
snapshot.technologies["ei-plasma-heater"] = table.deepcopy(data.raw.technology["ei-plasma-heater"])
if not config.baseline then
    check(has_category("ei-arc-furnace", "ei-arc-smelting") and not has_category("ei-arc-furnace", "ei-plasma-smelting"), "arc route")
    check(has_category("ei-plasma-heater", "ei-plasma-smelting") and not has_category("ei-plasma-heater", "ei-arc-smelting"), "plasma route")
    for _, row in ipairs(cases) do
        local old = data.raw.recipe["ei-molten-"..row[1]]
        local new = data.raw.recipe["ei-plasma-molten-"..row[1]]
        check(old and new, row[1].." both recipe IDs exist")
        check(old.category == "ei-arc-smelting" and new.category == "ei-plasma-smelting", row[1].." categories: "..old.category.." / "..new.category)
        check(#new.ingredients == 1 and new.ingredients[1].name == row[2] and new.ingredients[1].amount == row[4], row[1].." inputs")
        check(#new.results == 1 and new.results[1].name == row[3] and new.results[1].amount == row[6] and new.results[1].temperature == 900, row[1].." output")
        check(new.energy_required == row[7] and new.maximum_productivity == 3, row[1].." time and cap")
        check(not new.enabled and not new.hidden_in_factoriopedia and #new.icons == 3 and new.localised_name, row[1].." presentation")
        local unlocks = 0
        for _, effect in ipairs(data.raw.technology["ei-plasma-heater"].effects) do
            if effect.type == "unlock-recipe" and effect.recipe == new.name then unlocks = unlocks + 1 end
        end
        check(unlocks == 1, row[1].." unlock")
        for name, technology in pairs(snapshot.technologies) do
            if name ~= "ei-plasma-heater" then
                local matches = 0
                for _, effect in ipairs(technology.effects) do
                    if effect.type == "change-recipe-productivity" and effect.recipe == new.name then
                        check(effect.change == row[8], row[1].." bonus "..name)
                        matches = matches + 1
                    end
                end
                check(matches == 1, row[1].." unique effect "..name)
            end
        end
    end
end
data:extend({{type = "mod-data", name = "plasma-qc-final", data = {checks = checks, snapshot = snapshot}}})
