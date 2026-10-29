-- QC-only controls, created after the complete shipping prototype snapshot.
local config = require("test-config")
if not config.overlaps then return end
for _, case in ipairs(require("cases")) do
    if #case.lights > 0 then
        local original = data.raw["assembling-machine"][case.name] or data.raw.furnace[case.name]
        for _, variant in ipairs{"legacy", "light-only"} do
            local clone = table.deepcopy(original)
            clone.name = "machine-light-" .. variant .. "-" .. case.name
            clone.next_upgrade, clone.minable, clone.placeable_by = nil, nil, nil
            clone.hidden_in_factoriopedia = true
            for _, visual in ipairs(clone.graphics_set.working_visualisations) do
                if visual.animation and visual.animation.filename and
                    visual.animation.filename:find("/graphics/status-lights/", 1, true) then
                    if variant == "legacy" then visual.render_layer = "light-effect"
                    else visual.animation = nil end
                end
            end
            data:extend{clone}
        end
    end
end
