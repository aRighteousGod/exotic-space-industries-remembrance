if not mods["PollutionCombinator-JamieFork"] then return end
--====================================================================================================
local ei_lib = require("lib/lib")

ei_lib.raw.item["PollutionCombinator-JamieFork-pollution-combinator"] = {
    ingredients = {
    { type = "item", name = "constant-combinator", amount = 1 },
    { type = "item", name = "ei-electronic-parts",  amount = 2 },
};
}