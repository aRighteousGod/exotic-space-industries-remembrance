-- Runs after every enabled source mod. Snapshot before any fixture-only recipes.
local config = require("test-config")
local snapshot = {entities = {}, excluded = {}, pyric = settings.startup["ei-pyric-radiance"].value}
for kind, prototypes in pairs(data.raw) do
    for name, prototype in pairs(prototypes) do
        local energy = prototype.energy_source
        if name:sub(1, 3) == "ei-" and energy and energy.type == "fluid"
            and energy.fluid_box and energy.fluid_box.filter == "steam" then
            snapshot.entities[name] = table.deepcopy(prototype)
            if config.mode ~= "baseline" then
                assert(energy.light_flicker and energy.light_flicker.minimum_intensity == 0
                    and energy.light_flicker.maximum_intensity == 0, "Steam glow: " .. kind .. "/" .. name)
            end
        elseif name == "ei-big-turbine" or (kind == "locomotive" and name:find("steam", 1, true)) then
            snapshot.excluded[name] = table.deepcopy(prototype)
        end
    end
end
for _, name in ipairs(require("cases")) do assert(snapshot.entities[name], "Missing consumer: " .. name) end
assert(snapshot.pyric == (config.mode ~= "off"), "Wrong Pyric setting")
data:extend{{type = "mod-data", name = "steam-glow-qc", data_type = "steam-glow-qc", data = snapshot}}

-- Exercise original graphics with a tiny deterministic item recipe.
data:extend{
    {type = "recipe-category", name = "steam-glow-qc"},
    {type = "recipe", name = "steam-glow-qc", enabled = true,
        energy_required = 0.5, ingredients = {{type = "item", name = "iron-plate", amount = 1}},
        results = {{type = "item", name = "copper-plate", amount = 1}}},
}
if mods.base:sub(1,3)=="2.1" then data.raw.recipe["steam-glow-qc"].categories={"steam-glow-qc"}
else data.raw.recipe["steam-glow-qc"].category="steam-glow-qc" end
for name in pairs(snapshot.entities) do
    local prototype = data.raw["assembling-machine"][name]
    if prototype then prototype.crafting_categories[#prototype.crafting_categories + 1] = "steam-glow-qc" end
end
