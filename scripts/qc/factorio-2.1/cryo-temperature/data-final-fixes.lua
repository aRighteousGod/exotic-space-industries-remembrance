local config = require("test-config")
local cases = {
    {"thruster-fuel", 25}, {"thruster-oxidizer", 25},
    {"holmium-solution", 15}, {"electrolyte", 15},
    {"ammoniacal-solution", (config.mutate or config.galore) and 15 or -50},
    {"ammonia", config.galore and 15 or config.mutate and 25 or -35},
    {"fluorine", 25}, {"lithium-brine", 15}, {"auric-vapor", 500},
}
local rows = {}
for _, case in ipairs(cases) do
    local fill = data.raw.recipe["ei-fill-cryo-container-"..case[1]]
    local empty = data.raw.recipe["ei-empty-cryo-container-"..case[1]]
    local input, output
    for _, part in ipairs(fill.ingredients) do if part.type == "fluid" then input = part end end
    for _, part in ipairs(empty.results) do if part.type == "fluid" then output = part end end
    if config.assert_final then
        assert(input.name == output.name and input.amount == output.amount, "cryo quantity/identity parity")
        assert(input.temperature == case[2] and output.temperature == case[2], "cryo temperature: "..case[1])
        assert(input.minimum_temperature == nil and input.maximum_temperature == nil, "exact transfer temperature")
        if config.galore and (case[1] == "ammonia" or case[1] == "ammoniacal-solution") then
            local fluid = data.raw.fluid[case[1]]
            assert(input.name == case[1] and fluid.default_temperature == 15
                and fluid.max_temperature == (case[1] == "ammonia" and 450 or 100), "Galore fluid identity/range")
        end
        for _, recipe in ipairs({fill, empty}) do
            assert(recipe.energy_required == 1 and recipe.allow_productivity == false
                and recipe.allow_quality == false and recipe.auto_recycle == false, "transfer contract")
        end
    end
    rows[#rows + 1] = {suffix=case[1], fluid=input.name, temperature=case[2],
        capacity=input.amount, fill=fill.name, empty=empty.name,
        maximum=data.raw.fluid[input.name].max_temperature or data.raw.fluid[input.name].default_temperature}
end
data:extend({{type="mod-data", name="esir-qc-cryo-temperature", data={mutated=config.mutate, galore=config.galore or false, rows=rows}}})
log("CRYO TEMPERATURE FINAL: "..#rows.." paired recipes; mutated="..tostring(config.mutate).."; galore="..tostring(config.galore))
