-- Fixture-only comparison of native emissive assembler LEDs and light intensities.
local config = require("test-config")
if config.overlaps or config.mode ~= "status" or config.focus == "smelters" or (config.bottleneck and config.bottleneck ~= "absent") then return end

local sources = {"ei-crusher", "ei-advanced-chem-plant", "ei-nano-factory", "ei-fission-facility", "ei-castor"}
local levels = {0.35, 0.5, 0.65, 0.8, 1.0}
local entries = {}
for source_index, name in ipairs(sources) do
    local variants = {}
    for index = 1, 3 do
        local reference = data.raw["assembling-machine"]["assembling-machine-" .. index]
        local reference_lamp
        for _, visual in ipairs(reference.graphics_set.working_visualisations or {}) do
            local animation = visual.animation
            if visual.apply_tint == "status" and animation and animation.filename
                and animation.filename:find("__Assembler%-Reskin__/.*/steampunk%-assembler%-il.png") then
                assert(visual.always_draw and animation.draw_as_glow and animation.blend_mode == "additive" and animation.scale == 0.5)
                reference_lamp = animation.filename
            end
        end
        assert(reference_lamp, "Native reskinned assembler reference")
        reference.crafting_categories = {"machine-light-qc"}
        reference.fixed_recipe = nil
        variants[#variants + 1] = {name = reference.name, label = "Assembler " .. index,
            source_type = reference.energy_source.type, lamps = {{0.966875, 1.0015625}}, reference = true,
            reference_lamp = reference_lamp, reference_colors = table.deepcopy(reference.graphics_set.status_colors)}
    end
    for index, intensity in ipairs(levels) do
        local clone = table.deepcopy(data.raw["assembling-machine"][name])
        clone.name = "machine-light-brightness-" .. source_index .. "-" .. index
        clone.next_upgrade, clone.minable, clone.placeable_by = nil, nil, nil
        clone.hidden_in_factoriopedia = true
        local lamps = {}
        for _, visual in ipairs(clone.graphics_set.working_visualisations) do
            if visual.apply_tint == "status" and visual.light then
                visual.light.intensity = intensity
                lamps[#lamps + 1] = table.deepcopy(visual.north_position)
            end
        end
        assert(#lamps > 0)
        data:extend{clone}
        variants[#variants + 1] = {name = clone.name, label = tostring(intensity),
            source_type = clone.energy_source.type, lamps = lamps, intensity = intensity}
    end
    for state_index, state in ipairs{"working", "idle"} do
        for column, variant in ipairs(variants) do
            local entry = table.deepcopy(variant)
            entry.source = name
            entry.state = state
            entry.position = {(column - 4.5) * 10, ((source_index - 1) * 2 + state_index - 5.5) * 10}
            entries[#entries + 1] = entry
        end
    end
end
data:extend{{type = "mod-data", name = "machine-light-brightness", data_type = "machine-light-brightness", data = {entries = entries}}}
