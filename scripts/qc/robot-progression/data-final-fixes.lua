-- Opt-in final-prototype checks; never loaded by the shipping mod.
local config = require("test-config")
local specs = {
    {"logistic-robot", "ei-cargo-bot", 25, 0.1, "6.25kJ", 1400},
    {"logistic-robot", "ei-advanced-logistic-bot", 30, 0.30, "10kJ", 2100},
    {"construction-robot", "ei-construction-bot", 5, 0.1, "10kJ", 1400},
    {"construction-robot", "ei-advanced-construction-bot", 10, 0.24, "5kJ", 2100},
}
local snapshot = {entities = {}, recipes = {}, technology = table.deepcopy(data.raw.technology["ei-advanced-bots"])}
local fields = {"speed", "max_payload_size", "max_health", "max_energy", "energy_per_move", "energy_per_tick",
    "min_to_charge", "max_to_charge", "speed_multiplier_when_out_of_energy", "minable", "flags", "corpse",
    "dying_explosion", "dying_trigger_effect", "damaged_trigger_effect", "open_sound", "close_sound", "factoriopedia_simulation"}
for _, spec in ipairs(specs) do
    local entity = assert(data.raw[spec[1]][spec[2]])
    local row = {}
    for _, field in ipairs(fields) do row[field] = table.deepcopy(entity[field]) end
    snapshot.entities[spec[2]] = row
    assert(entity.dying_explosion and entity.damaged_trigger_effect and entity.open_sound and entity.close_sound,
        "Robot presentation missing: "..spec[2])
    assert(entity.factoriopedia_simulation and entity.factoriopedia_simulation.init, "Robot scene missing: "..spec[2])
    if not config.baseline then
        assert(entity.max_payload_size == spec[3] and entity.speed == spec[4]
            and entity.energy_per_move == spec[5] and entity.max_health == spec[6], "Robot stats: "..spec[2])
    end
    snapshot.recipes[spec[2]] = table.deepcopy(data.raw.recipe[spec[2]])
    snapshot.recipes[spec[2].."-recycling"] = table.deepcopy(data.raw.recipe[spec[2].."-recycling"])
end
snapshot.recipes["ei-advanced-bot-engine"] = table.deepcopy(data.raw.recipe["ei-advanced-bot-engine"])
if not config.baseline then
    for _, pair in ipairs{{"ei-advanced-logistic-bot", "ei-cargo-bot"}, {"ei-advanced-construction-bot", "ei-construction-bot"}} do
        local name = pair[1].."-from-"..pair[2]:sub(4)
        local recipe = assert(data.raw.recipe[name])
        assert(recipe.category == "crafting" and recipe.energy_required == 4 and recipe.enabled == false, name.." crafting")
        assert(recipe.auto_recycle == false and recipe.allow_productivity == false and recipe.allow_quality == true, name.." bonuses")
        assert(recipe.allow_decomposition == false and recipe.allow_as_intermediate == false, name.." intermediate")
        assert(not recipe.hidden and not recipe.hide_from_player_crafting, name.." visible")
        assert(#recipe.ingredients == 3 and #recipe.results == 1 and recipe.results[1].amount == 1 and recipe.results[1].name == pair[1], name.." output")
        local ingredients = {}
        for _, ingredient in ipairs(recipe.ingredients) do ingredients[ingredient.name] = ingredient.amount end
        assert(ingredients[pair[2]] == 1 and ingredients["processing-unit"] == 4 and ingredients["ei-advanced-bot-engine"] == 4, name.." input")
        local unlocks = 0
        for _, effect in ipairs(snapshot.technology.effects) do if effect.recipe == name then unlocks = unlocks + 1 end end
        assert(unlocks == 1 and #recipe.icons == 10 and recipe.localised_name[1] == "", name.." unlock and presentation")
        snapshot.recipes[name] = table.deepcopy(recipe)
    end
end
data:extend{{type = "mod-data", name = "robot-qc-final", data_type = "robot-qc-final", data = snapshot}}
