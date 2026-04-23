local space_condition = {
    {
        property = "gravity",
        min = 0,
        max = 1000
    }
}
local space_condition_targets = {
--    {type = "cargo-wagon", name = "cargo-wagon"},
--    {type = "fluid-wagon", name = "fluid-wagon"},
    {type = "rail-signal", name = "rail-signal"},
    {type = "rail-chain-signal", name = "rail-chain-signal"},
    {type = "curved-rail-b", name = "curved-rail-b"},
    {type = "curved-rail-a", name = "curved-rail-a"},
    {type = "half-diagonal-rail", name = "half-diagonal-rail"},
    {type = "straight-rail", name = "straight-rail"},
    {type = "rail-ramp", name = "rail-ramp"},
    {type = "elevated-straight-rail", name = "elevated-straight-rail"},
    {type = "elevated-half-diagonal-rail", name = "elevated-half-diagonal-rail"},
    {type = "elevated-curved-rail-a", name = "elevated-curved-rail-a"},
    {type = "elevated-curved-rail-b", name = "elevated-curved-rail-b"},
    {type = "rail-support", name = "rail-support"},
    {type = "train-stop", name = "train-stop"},
    {type = "item", name = "rail-signal"},
    {type = "item", name = "rail-chain-signal"},
}

for _, target in ipairs(space_condition_targets) do
    local prototypes = data.raw[target.type]
    if prototypes and prototypes[target.name] then
        prototypes[target.name].surface_conditions = table.deepcopy(space_condition)
    end
end
