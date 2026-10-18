local config = require("test-config")
local name = "ei-productivity-auric-cyst-washing"
if config.baseline then
    assert(not data.raw.technology[name], "Auric baseline already contains productivity research")
    return
end

local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, "AURIC FINAL: "..message)
end
local technology = data.raw.technology[name]
local recipe = data.raw.recipe["ei-auric-cyst-washing"]
check(technology and technology.max_level == "infinite" and technology.upgrade, "infinite upgrade")
check(#technology.effects == 1, "single effect")
local effect = technology.effects[1]
check(effect.type == "change-recipe-productivity" and effect.recipe == recipe.name and effect.change == 0.1, "washing +10%")
local prerequisites = {}
for _, prerequisite in ipairs(technology.prerequisites) do prerequisites[prerequisite] = true end
check(prerequisites["ei-auric-marsh-inoculation"] and prerequisites["agricultural-science-pack"], "both milestones")
check(#technology.prerequisites == 2, "no extra gates")
local expected = {"ei-dark-age-tech", "ei-steam-age-tech", "ei-electricity-age-tech", "ei-computer-age-tech", "space-science-pack", "agricultural-science-pack"}
local packs = {}
for _, pack in ipairs(technology.unit.ingredients) do packs[pack[1] or pack.name] = pack[2] or pack.amount end
check(#technology.unit.ingredients == #expected, "six science packs")
for _, pack in ipairs(expected) do check(packs[pack] == 1, "science "..pack) end
check(technology.unit.time == 20 and technology.unit.count == nil, "research time/formula")
if config.no_scaling then
    check(technology.unit.count_formula == "100 * (1 + 0.15 * L)", "authored cost")
else
    local ei_data = require("__exotic-space-industries-remembrance__/lib/data")
    local common = require("__exotic-space-industries-remembrance__/lib/tech-scaling-common")
    local base = common.get_effective_base_start_price(settings.startup["ei-tech-scaling-startPrice"].value,
        ei_data.tech_scaling.switch_table[settings.startup["ei-tech-scaling-maxCost"].value],
        settings.startup["ei-tech-scaling-additionalMultiplier"].value)
    check(technology.unit.count_formula == "2^((L-1)*0.5)*"..tostring(base), "configured repeatable cost")
end
check(recipe.allow_productivity == true and recipe.maximum_productivity == 3, "modules and cap")
check(recipe.energy_required == 2 and recipe.category == "ei-purifier", "time and category")
local inputs = {}
for _, input in ipairs(recipe.ingredients) do inputs[input.name] = input.amount end
check(#recipe.ingredients == 3 and inputs["ei-auric-cyst"] == 1 and inputs["sulfuric-acid"] == 15 and inputs.steam == 100, "base inputs")
local outputs = {}
for _, output in ipairs(recipe.results) do outputs[output.name] = output end
check(#recipe.results == 3, "base products")
for _, row in ipairs({{"ei-gold-chunk", 1, 3, 0}, {"spoilage", 1, 3, 3}, {"ei-dirty-water", 5, 25, 25}}) do
    local output = outputs[row[1]]
    check(output and output.amount_min == row[2] and output.amount_max == row[3], "base output "..row[1])
    check((output.ignored_by_productivity or 0) == row[4], "bonus output "..row[1])
end
check(outputs.spoilage.probability == 0.5, "spoilage probability")
check(recipe.surface_conditions[1].min == 2000 and recipe.surface_conditions[1].max == 2000, "Gleba pressure")
for _, input in ipairs(recipe.ingredients) do if input.name == "steam" then check(input.minimum_temperature == 500, "hot steam") end end
for name, phase in pairs(data.raw.recipe) do if string.find(name, "ei-auric-vat-", 1, true) == 1 then check(phase.allow_productivity == false, "phase protected "..name) end end
check(technology.icon == data.raw.technology["ei-auric-marsh-inoculation"].icon, "auric icon")

-- The helper accelerates only time and power supply, retaining purifier module/fluid behavior.
local machine = table.deepcopy(data.raw["assembling-machine"]["ei-purifier"])
machine.name = "auric-qc-purifier"
machine.crafting_speed = 120
machine.energy_source = {type = "void"}
machine.minable = nil
machine.next_upgrade = nil
local module_bonus = data.raw.module["productivity-module-3"].effect.productivity
data:extend({machine, {
    type = "mod-data", name = "auric-qc-final",
    data = {checks = checks, technology = technology, recipe = recipe, module_bonus = module_bonus, no_scaling = config.no_scaling},
}})
