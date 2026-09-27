-- Finite capabilities; all prices remain owned by final-tech-fixes.
local c = require("lib/singularity-lance-config")
for index, upgrade in ipairs(c.upgrades) do
    local name = "ei-singularity-lance-" .. upgrade.key
    data:extend({{
        type = "technology", name = name,
        icon = "__exotic-space-industries-remembrance__/graphics/singularity-lance-upgrades/" .. upgrade.key .. ".png",
        icon_size = 256, prerequisites = table.deepcopy(upgrade.prerequisites),
        localised_description = {"", c.effect_description(index), "\n", {"lance-upgrades.static-values"}, "\n", {"lance-upgrades.protection"}},
        effects = {{type = "nothing", effect_description = c.effect_description(index)}},
        unit = {count = 100, time = 30, ingredients = table.deepcopy(ei_data.science[upgrade.science])},
        age = upgrade.age, order = "e-lance-" .. index,
    }})
end

local path = "__exotic-space-industries-remembrance__/graphics/singularity-lance-upgrades/"
local lean = c.resolve().visual_fidelity == "lean"
for _, key in ipairs({"beam-base", "beam-axial", "beam-testament", "wound-1", "wound-2", "wound-3"}) do
    local beam = key:sub(1, 4) == "beam"
    local layer = {filename = path .. key .. ".png", width = beam and 256 or 128, height = beam and 64 or 128,
        scale = beam and 1 or 0.5, flags = {"no-crop"}, draw_as_glow = true}
    local glow = table.deepcopy(layer)
    glow.filename, glow.blend_mode = path .. key .. "-glow.png", "additive"
    data:extend({{type = "sprite", name = "ei-singularity-lance-" .. key,
        layers = lean and {layer} or {glow, layer}}})
end
for _, key in ipairs({"collapse-warning", "collapse-impact", "testament-warning", "testament-impact"}) do
    local warning = key:find("warning", 1, true)
    local layer = {filename = path .. key .. ".png", width = 192, height = 192, line_length = 6,
        frame_count = warning and 30 or 12, animation_speed = 1, flags = {"no-crop"}, draw_as_glow = true}
    local glow = table.deepcopy(layer)
    glow.filename, glow.blend_mode = path .. key .. "-glow.png", "additive"
    data:extend({{type = "animation", name = "ei-singularity-lance-" .. key, layers = lean and {layer} or {glow, layer}}})
end
data:extend({{type = "sound", name = "ei-singularity-lance-testament-sound",
    variations = {{filename = "__exotic-space-industries-remembrance-graphics-4__/sounds/singularity-lance-beam-3.ogg", volume = 0.7}}}})
