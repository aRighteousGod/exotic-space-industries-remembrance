-- Private final-data experiment: identify native fixed-recipe capacity semantics.
local names = {"ei-railgun-cooling-proxy", "ei-railgun-cooling-proxy-nw",
    "ei-railgun-cooling-proxy-ne", "ei-railgun-cooling-proxy-sw", "ei-railgun-cooling-proxy-se"}
for index, name in ipairs(names) do
    local recipe = table.deepcopy(data.raw.recipe["ei-railgun-cooling-proxy-running"])
    recipe.name = "qc-capacity-" .. index
    recipe.ingredients[1].fluidbox_multiplier = index == 5 and 2 or index
    if index == 5 then recipe.ingredients[1].amount = 15 end
    recipe.results[1].fluidbox_multiplier = 2
    data:extend{recipe}
    data.raw["assembling-machine"][name].fixed_recipe = recipe.name
end
