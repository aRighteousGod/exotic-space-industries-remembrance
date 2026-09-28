-- Finite capabilities; all prices remain owned by final-tech-fixes.
local c = require("lib/singularity-lance-config")
local path = "__exotic-space-industries-remembrance__/graphics/singularity-lance-upgrades/"
local art_path = path .. "prismatic-liturgy/"
local art = c.presentation
for index, upgrade in ipairs(c.upgrades) do
    local name = "ei-singularity-lance-" .. upgrade.key
    data:extend({{
        type = "technology", name = name,
        icons = {{icon = art_path .. upgrade.key .. "-mineral.png", icon_size = 256},
            {icon = art_path .. upgrade.key .. "-phenomenon.png", icon_size = 256}},
        prerequisites = table.deepcopy(upgrade.prerequisites),
        localised_description = {"", c.effect_description(index), "\n", {"lance-upgrades.static-values"}, "\n", {"lance-upgrades.protection"}},
        effects = {{type = "nothing", effect_description = c.effect_description(index)}},
        unit = {count = 100, time = 30, ingredients = table.deepcopy(ei_data.science[upgrade.science])},
        age = upgrade.age, order = "e-lance-" .. index,
    }})
end

local lean = c.resolve().visual_fidelity == "lean"
-- Retain the old Sprite prototypes only for saved rendering handles. The in-place
-- presentation migration destroys them; no new shot uses this legacy artwork.
for _, key in ipairs({"beam-base", "beam-axial", "beam-testament", "wound-1", "wound-2", "wound-3"}) do
    local beam = key:sub(1, 4) == "beam"
    local layer = {filename = path .. key .. ".png", width = beam and 256 or 128, height = beam and 64 or 128,
        scale = beam and 1 or 0.5, flags = {"no-crop"}, draw_as_glow = true}
    local glow = table.deepcopy(layer)
    glow.filename, glow.blend_mode = path .. key .. "-glow.png", "additive"
    data:extend({{type = "sprite", name = "ei-singularity-lance-" .. key,
        layers = lean and {layer} or {glow, layer}}})
end

---@return data.Animation
local function prismatic_animation(key, width, height, frames, columns, scale, speed)
    local semantic = {filename = art_path .. key .. ".png", width = width, height = height,
        frame_count = frames, line_length = columns, scale = scale, animation_speed = speed,
        flags = {"no-crop"}, draw_as_glow = true}
    local glow = table.deepcopy(semantic)
    glow.filename, glow.blend_mode = art_path .. key .. "-glow.png", "additive-soft"
    return {layers = lean and {semantic} or {glow, semantic}}
end

-- Reuse the original native cosmetic beam's flags, width, light and empty ground
-- graphics. Periodic bodies keep the material density independent of shot length.
for _, shape in ipairs({"axial", "testament"}) do
    local beam = table.deepcopy(data.raw.beam["ei-singularity-lance-beam"])
    beam.name = "ei-singularity-lance-beam-" .. shape
    local body = prismatic_animation("beam-" .. shape .. "-body", 256, 96, art.beam_frames, 4, art.beam_scale, art.beam_speed)
    local head = prismatic_animation("beam-" .. shape .. "-head", 192, 160, art.beam_frames, 4, art.beam_scale, art.beam_speed)
    local tail = prismatic_animation("beam-" .. shape .. "-tail", 192, 160, art.beam_frames, 4, art.beam_scale, art.beam_speed)
    beam.graphics_set.beam = {start = table.deepcopy(tail), ending = table.deepcopy(head),
        head = head, tail = tail, body = {body}, render_layer = "projectile"}
    beam.action, beam.working_sound = nil, nil
    data:extend({beam})
end
for band = 1, 3 do
    local key = "wound-" .. band
    local prototype = prismatic_animation(key, art.wound_size, art.wound_size, art.wound_frames, 6, art.wound_scale, art.wound_speed)
    prototype.type, prototype.name = "animation", "ei-singularity-lance-" .. key
    data:extend({prototype})
end
local crown = prismatic_animation("wound-crown", art.wound_size, art.wound_size, art.crown_ticks, 6, art.wound_scale, 1)
crown.type, crown.name = "animation", "ei-singularity-lance-wound-crown"
data:extend({crown})
for _, key in ipairs({"collapse-warning", "collapse-impact", "testament-warning", "testament-impact"}) do
    local warning = key:find("warning", 1, true)
    local scale = art.collapse_reference_radius * 32 / (art.collapse_size / 2 * art.warning_radius_fraction)
    local prototype = prismatic_animation(key, art.collapse_size, art.collapse_size,
        warning and c.collapse.delay or art.impact_ticks, 6, scale, 1)
    prototype.type, prototype.name = "animation", "ei-singularity-lance-" .. key
    data:extend({prototype})
end
data:extend({{type = "sound", name = "ei-singularity-lance-testament-sound",
    variations = {{filename = "__exotic-space-industries-remembrance-graphics-4__/sounds/singularity-lance-beam-3.ogg", volume = 0.7}}}})
