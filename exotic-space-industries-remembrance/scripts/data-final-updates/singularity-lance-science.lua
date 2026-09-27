-- Run after generic pack inheritance, BEFORE the only research cost calculation.
local c = require("lib/singularity-lance-config")
local ei_lib = require("lib/lib")
for index, upgrade in ipairs(c.upgrades) do
    local ingredients = index == 1 and data.raw.technology["ei-singularity-lance"].unit.ingredients
        or ei_data.science[upgrade.science]
    ei_lib.set_science_packs("ei-singularity-lance-" .. upgrade.key, table.deepcopy(ingredients))
end
