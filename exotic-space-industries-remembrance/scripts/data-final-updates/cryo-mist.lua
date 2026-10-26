--==============================================================================
-- ESIR FILE MAP
-- owns: native cold mist on the hypercooler and nitrogen beacon power sources
-- loaded_by: exotic-space-industries-remembrance/data-final-fixes.lua
-- cadence: data-final stage load, after Nonstandard Beacons creates its sources
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: cooling artwork or nitrogen beacon source prototype changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/cryo-mist.md#contract

-- The source assembler owns nitrogen consumption and native working state.
-- Its existing lifecycle also removes the mist when the beacon is removed.
---@type {type: string, name: string, scale: number, shift_y: number}[]
local targets = {
    {type = "furnace", name = "ei-cooler", scale = 0.8, shift_y = 24},
    {type = "assembling-machine", name = "ei-copper-beacon-source", scale = 0.5, shift_y = 12},
    {type = "assembling-machine", name = "ei-iron-beacon-source", scale = 0.5, shift_y = 12},
}

for _, target in ipairs(targets) do
    local prototype = data.raw[target.type] and data.raw[target.type][target.name]
    if prototype then
        prototype.graphics_set = prototype.graphics_set or {}
        local graphics = prototype.graphics_set
        graphics.working_visualisations = graphics.working_visualisations or {}
        ---@type data.WorkingVisualisation
        local mist = {
            name = "ei-cryo-mist",
            always_draw = false,
            constant_speed = true,
            render_layer = "higher-object-under",
            animation = {
                filename = "__exotic-space-industries-remembrance__/graphics/entities/cryo-mist.png",
                width = 256,
                height = 256,
                frame_count = 60,
                line_length = 8,
                animation_speed = 0.15,
                scale = target.scale,
                shift = util.by_pixel(0, target.shift_y),
                blend_mode = "additive",
                tint = {r = 0.5, g = 0.5, b = 0.5, a = 1},
            },
        }
        graphics.working_visualisations[#graphics.working_visualisations + 1] = mist

        if target.type == "assembling-machine" then
            -- Omitting light_flicker restores the native white light defaults.
            prototype.energy_source.light_flicker = {minimum_intensity = 0, maximum_intensity = 0}
        end
    end
end
