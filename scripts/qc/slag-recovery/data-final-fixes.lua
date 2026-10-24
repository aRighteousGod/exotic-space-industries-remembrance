-- Capture merged prototypes before adding the disposable accelerated purifier.
local names = {
    "ei-slag-crushing", "ei-auric-slag-washing", "ei-auric-vapor-condensation",
    "ei-carbide-precipitation-core", "sulfuric-acid", "ei-nitric-acid",
    "ei-stone-slag-processing", "ei-concrete-slag", "ei-dirty-water-slag",
}
for _, tier in ipairs({"sulfuric", "nitric", "morphium"}) do
    names[#names + 1] = "ei-slag-extraction-"..tier
    names[#names + 1] = "ei-slag-extraction-"..tier.."-crushed"
end
for _, metal in ipairs({"lead", "gold"}) do
    for _, name in ipairs({"ei-"..metal.."-chunk-purifier", "ei-molten-"..metal.."-pure-ore",
        "ei-plasma-molten-"..metal.."-pure-ore", "ei-cast-"..metal.."-ingot",
        "ei-crushed-"..metal, "ei-crushed-"..metal.."-sulfuric-extraction"}) do
        names[#names + 1] = name
    end
end
local recipes, unlocks, productivity = {}, {}, {}
for _, name in ipairs(names) do
    assert(data.raw.recipe[name], "Missing acceptance recipe: "..name)
    recipes[name] = table.deepcopy(data.raw.recipe[name])
    unlocks[name] = {}
    productivity[name] = {}
    for tech_name, tech in pairs(data.raw.technology) do
        for _, effect in ipairs(tech.effects or {}) do
            if effect.type == "unlock-recipe" and effect.recipe == name then
                unlocks[name][#unlocks[name] + 1] = tech_name
            end
            if effect.type == "change-recipe-productivity" and effect.recipe == name then
                productivity[name][tech_name] = {change = effect.change, max_level = tech.max_level}
            end
        end
    end
    table.sort(unlocks[name])
end
---@type data.AssemblingMachinePrototype
local machine = table.deepcopy(data.raw["assembling-machine"]["ei-purifier"])
machine.name = "slag-qc-purifier"
machine.crafting_speed = 60
machine.energy_source = {type = "void"}
machine.minable = nil
machine.next_upgrade = nil
data:extend({machine, {
    type = "mod-data", name = "slag-qc-final",
    data = {recipes = recipes, unlocks = unlocks, productivity = productivity,
        technology = table.deepcopy(data.raw.technology["ei-productivity-slag-chunk-extraction"]),
        crusher_power = data.raw["assembling-machine"]["ei-crusher"].energy_usage},
}})
