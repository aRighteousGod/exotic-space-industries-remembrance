-- blueprint: .codex/esir/blueprints/anisetron.md#contract
-- Restore the chassis/material gates after optional technology-tree flattening.
-- Native research pricing and prerequisite science propagation retain ownership.
local config = require("lib/anisetron-config")
local lance = require("lib/singularity-lance-config")
local artwork = require("lib/singularity-lance-art")
local visual = require("lib/anisetron-visual-config").resolve()
local canonical = lance.resolve("standard")
local presentation = lance.presentation
local upgrade_path = ei_path .. "graphics/singularity-lance-upgrades/prismatic-liturgy/"
local base_path = ei_graphics_entity_4_path .. "singularity-lance/beam/"
local intensity = math.min(1, canonical.visual_beam_light_intensity) * presentation.beam_light_strength
local extra_glow = visual.enabled and visual.visual_fidelity ~= "lean"
for _, name in ipairs{"ei-anisetron-beam", "ei-anisetron-crown-beam"} do
    local template = data.raw.beam[name]
    local base = artwork.beam(name, template.width,
        {intensity = intensity, size = canonical.visual_beam_light_size, color = presentation.beam_light_color},
        artwork.base_graphics(base_path, presentation.beam_scale, {}, true), nil)
    local shapes = name == "ei-anisetron-crown-beam" and {"", "axial", "testament", "axial-branch", "testament-branch"} or {""}
    for _, shape in ipairs(shapes) do
        local material, factor = base, name == "ei-anisetron-beam" and config.beam_scale_factor or config.crown_beam_scale_factor
        if shape ~= "" then
            material = artwork.material(base, upgrade_path, presentation, shape:gsub("%-branch$", ""), extra_glow)
            if shape:find("branch", 1, true) then factor = factor * presentation.branch_scale end
        end
        for index = 0, #presentation.beam_light_palette do
            local beam = table.deepcopy(template)
            beam.name = name .. (shape ~= "" and "-" .. shape or "") .. (index > 0 and "-light-" .. index or "")
            beam.graphics_set = table.deepcopy(material.graphics_set)
            -- start/ending are spatial endpoint art, including the crystal's
            -- origin flare. Keep them visible when an immutable offset changes.
            beam.graphics_set.beam.render_layer = "light-effect"
            beam.graphics_set.transparent_start_end_animations = false
            -- The core already contains its aligned additive glow. A second
            -- ground-projected ray separates from the elevated crystal ray.
            beam.graphics_set.ground = {head = util.empty_sprite(), tail = util.empty_sprite(), body = util.empty_sprite()}
            artwork.rescale(beam.graphics_set, factor)
            beam.action, beam.working_sound = nil, nil
            data:extend{beam}
        end
    end
end
for band = 1, 3 do
    local animation = artwork.upgrade_animation(upgrade_path, extra_glow, "wound-" .. band,
        presentation.wound_size, presentation.wound_size, presentation.wound_frames, 6,
        presentation.wound_scale, presentation.wound_speed)
    animation.type, animation.name = "animation", "ei-anisetron-lance-wound-" .. band
    data:extend{animation}
end
for _, key in ipairs{"collapse-concentrated-warning", "collapse-concentrated-impact",
    "testament-concentrated-warning", "testament-concentrated-impact", "echo-warning", "echo-impact"} do
    local is_warning = key:find("warning", 1, true)
    local scale = presentation.collapse_reference_radius * 32 / (presentation.collapse_size / 2 * presentation.warning_radius_fraction)
    local animation = artwork.upgrade_animation(upgrade_path, extra_glow, key:gsub("^echo%-", "testament-"),
        presentation.collapse_size, presentation.collapse_size, is_warning and lance.collapse.delay or presentation.impact_ticks, 6, scale, 1)
    animation.type, animation.name = "animation", "ei-anisetron-lance-" .. key
    data:extend{animation}
end
-- Match the Lance's final tier-six and infinite tier-seven effects exactly.
-- Earlier laser research gates construction but does not inflate base damage.
for _, technology_name in ipairs{"laser-weapons-damage-6", "laser-weapons-damage-7"} do
    local technology = data.raw.technology[technology_name]
    local modifier, present
    for _, effect in ipairs(technology.effects or {}) do
        if effect.type == "ammo-damage" then
            if effect.ammo_category == lance.ammo_damage_category then modifier = effect.modifier end
            if effect.ammo_category == config.ammo_damage_category then present = true end
        end
    end
    if modifier and not present then
        table.insert(technology.effects, {type = "ammo-damage", ammo_category = config.ammo_damage_category, modifier = modifier})
    end
end
-- Native tooltip fields describe the scripted contacts rather than the empty
-- opener action. Ammo quality is independent of the cathedral's own quality.
local crown_values, facade_values, duration_values, dps_values = {}, {}, {}, {}
for quality_name, quality in pairs(data.raw.quality) do
    local multiplier = quality.default_multiplier or (1 + 0.3 * quality.level)
    crown_values[quality_name] = {"anisetron-stat.laser-damage", tostring(config.crown_damage * multiplier)}
    facade_values[quality_name] = {"anisetron-stat.laser-damage", tostring(config.facade_damage * multiplier)}
    duration_values[quality_name] = {"anisetron-stat.seconds", tostring(math.floor(config.duration_ticks *
        (1 + quality.level * config.duration_quality_bonus_per_level)) / 60)}
    dps_values[quality_name] = {"anisetron-stat.damage-per-second", tostring((config.crown_damage + config.facade_damage) * multiplier * 60 / config.contact_ticks)}
end
ei_lib.set_custom_tooltip_fields(data.raw.ammo["ei-anisetron-crystal-charge"], {
    {name = {"anisetron-stat.burst-duration"}, value = duration_values.normal,
        quality_values = config.duration_quality_bonus_per_level > 0 and duration_values or nil},
    {name = {"anisetron-stat.crown-damage"}, value = crown_values.normal, quality_values = crown_values},
    {name = {"anisetron-stat.facade-damage"}, value = facade_values.normal, quality_values = facade_values},
    {name = {"anisetron-stat.contact-interval"}, value = {"anisetron-stat.ticks", tostring(config.contact_ticks)}},
    {name = {"anisetron-stat.base-dps"}, value = dps_values.normal, quality_values = dps_values},
    {name = {"anisetron-stat.crown-arc"}, value = {"anisetron-stat.degrees", tostring(config.crown_arc_degrees)}},
    {name = {"anisetron-stat.frontal-arc"}, value = {"anisetron-stat.degrees", tostring(config.arc_degrees)}},
    {name = {"anisetron-stat.crown-range"}, value = {"anisetron-stat.tiles", tostring(config.crown_range)}},
    {name = {"anisetron-stat.facade-range"}, value = {"anisetron-stat.tiles", tostring(config.range)}},
    {name = {"anisetron-stat.lance-upgrades"}, value = {"anisetron-stat.lance-upgrades-value"}},
})
for _, prerequisite in ipairs{
    "ei-gaian-saucer", "ei-crystal-accumulator", "ei-computing-unit",
    "ei-neodymium-magnet", "ei-sus-plating", "ei-high-energy-crystal",
    "ei-electronic-parts", "laser-weapons-damage-5", "ei-singularity-lance",
} do
    ei_lib.add_prerequisite("ei-anisetron", prerequisite)
end
