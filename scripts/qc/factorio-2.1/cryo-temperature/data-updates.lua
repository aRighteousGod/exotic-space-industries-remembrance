local config = require("test-config")
if not config.mutate then return end

-- Match the reported 15-100 C range after ESIR has declared its recipes.
data.raw.fluid["ammoniacal-solution"].default_temperature = 15
data.raw.fluid["ammoniacal-solution"].max_temperature = 100

-- Also exercise a compatibility replacement, without depending on K2 itself.
local ammonia = table.deepcopy(data.raw.fluid.ammonia)
ammonia.name = "esir-qc-ammonia"
ammonia.default_temperature = 25
ammonia.max_temperature = 100
data:extend({ammonia})
for _, parts in ipairs({
    data.raw.recipe["ei-fill-cryo-container-ammonia"].ingredients,
    data.raw.recipe["ei-empty-cryo-container-ammonia"].results,
}) do
    for _, part in ipairs(parts) do
        if part.type == "fluid" then part.name = ammonia.name end
    end
end
