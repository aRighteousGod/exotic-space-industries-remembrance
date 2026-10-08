-- Finite capabilities; all prices remain owned by final-tech-fixes.
local c = require("lib/singularity-lance-config")
local path = ei_path.."graphics/singularity-lance-upgrades/"
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

local artwork = require("lib/singularity-lance-art")
local function prismatic_animation(key, width, height, frames, columns, scale, speed)
    return artwork.upgrade_animation(art_path, not lean, key, width, height, frames, columns, scale, speed)
end

-- Each upgraded material has its own source aperture. Retain the original impact
-- bloom and native ground lighting; source position remains the crystal eye.
-- Periodic bodies keep the material density independent of shot length.
for _, shape in ipairs({"axial", "testament"}) do
    local beam = artwork.material(data.raw.beam["ei-singularity-lance-beam"], art_path, art, shape, not lean)
    beam.name = "ei-singularity-lance-beam-" .. shape
    data:extend({beam})
    local branch = table.deepcopy(beam)
    branch.name = beam.name .. "-branch"
    -- Native material and terrain masks narrow together. The inherited impact
    -- bloom remains at its original scale on every segment endpoint.
    for _, group in pairs({branch.graphics_set.beam, branch.graphics_set.ground}) do
        for key, value in pairs(group or {}) do
            if key ~= "ending" and type(value) == "table" then
                local function narrow(animation)
                    if animation.layers then for _, layer in ipairs(animation.layers) do narrow(layer) end
                    elseif animation.filename then
                        animation.scale = (animation.scale or 1) * art.branch_scale
                        if animation.shift then
                            animation.shift = {animation.shift[1] * art.branch_scale, animation.shift[2] * art.branch_scale}
                        end
                    else for _, part in ipairs(animation) do narrow(part) end end
                end
                narrow(value)
            end
        end
    end
    data:extend({branch})
end
-- Reuse native light masks and all existing artwork. Only middle/end illumination
-- changes color; the crystal-side tail keeps its subdued violet tint. Selecting a
-- variant on natural creation avoids rebuilding a live beam just to recolor it.
local light_strength = math.min(1, c.resolve().visual_beam_light_intensity) * art.beam_light_strength
for index, color in ipairs(art.beam_light_palette) do
    for _, suffix in ipairs({"", "-axial", "-testament", "-axial-branch", "-testament-branch"}) do
        local beam = table.deepcopy(data.raw.beam["ei-singularity-lance-beam" .. suffix])
        beam.name = beam.name .. "-light-" .. index
        for _, part in ipairs({"body", "head"}) do
            beam.graphics_set.ground[part].tint = {r = color.r * light_strength,
                g = color.g * light_strength, b = color.b * light_strength, a = 1}
        end
        data:extend({beam})
    end
    for _, suffix in ipairs({"-contact-light", "-afterglow-light"}) do
        local light = table.deepcopy(data.raw.explosion["ei-singularity-lance" .. suffix])
        light.name = light.name .. "-" .. index
        light.light.color = table.deepcopy(color)
        data:extend({light})
    end
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
for _, key in ipairs({"collapse-warning", "collapse-impact", "testament-warning", "testament-impact",
    "collapse-concentrated-warning", "collapse-concentrated-impact", "testament-concentrated-warning",
    "testament-concentrated-impact", "echo-warning", "echo-impact"}) do
    local warning = key:find("warning", 1, true)
    local scale = art.collapse_reference_radius * 32 / (art.collapse_size / 2 * art.warning_radius_fraction)
    local filename = key:gsub("^echo%-", "testament-")
    local prototype = prismatic_animation(filename, art.collapse_size, art.collapse_size,
        warning and c.collapse.delay or art.impact_ticks, 6, scale, 1)
    prototype.type, prototype.name = "animation", "ei-singularity-lance-" .. key
    data:extend({prototype})
end
data:extend({{type = "sound", name = "ei-singularity-lance-testament-sound",
    variations = {{filename = ei_sounds_4_path.."singularity-lance-beam-3.ogg", volume = 0.7}}}})
