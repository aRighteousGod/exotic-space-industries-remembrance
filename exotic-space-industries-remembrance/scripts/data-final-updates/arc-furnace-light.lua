--==============================================================================
-- ESIR FILE MAP
-- owns: startup-controlled arc furnace working light flicker presets
-- loaded_by: exotic-space-industries-remembrance\data-final-fixes.lua
-- cadence: data-final stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: arc furnace light prototype or startup setting changes
--==============================================================================

local arc_furnace_light_config = require("lib/arc-furnace-light-config")

local preset = arc_furnace_light_config.resolve()

if preset.visual_fidelity == "original" then
    return
end

local arc_furnace = (data.raw.furnace and data.raw.furnace["ei-arc-furnace"])
    or (data.raw["assembling-machine"] and data.raw["assembling-machine"]["ei-arc-furnace"])

local working_visualisations = arc_furnace
    and arc_furnace.graphics_set
    and arc_furnace.graphics_set.working_visualisations

if type(working_visualisations) ~= "table" then
    return
end

local animation_fields = {
    "animation",
    "north_animation",
    "east_animation",
    "south_animation",
    "west_animation",
}

local function is_arc_furnace_glow_light(visual)
    local light = visual and visual.light
    return type(light) == "table" and light.sprite == "arc_furnace_glow"
end

local function visual_has_animation(visual)
    if type(visual) ~= "table" then
        return false
    end

    for _, field in pairs(animation_fields) do
        if type(visual[field]) == "table" then
            return true
        end
    end

    return false
end

local function clear_flicker(light)
    light.flicker_interval = nil
    light.flicker_min_modifier = nil
    light.flicker_max_modifier = nil
    light.offset_flicker = nil
end

local function apply_light_preset(light, light_preset)
    if type(light) ~= "table" or type(light_preset) ~= "table" then
        return
    end

    clear_flicker(light)

    light.intensity = light_preset.intensity or light.intensity
    light.size = light_preset.size or light.size

    if light_preset.flicker_interval ~= nil then
        light.flicker_interval = light_preset.flicker_interval
    end

    if light_preset.flicker_min_modifier ~= nil then
        light.flicker_min_modifier = light_preset.flicker_min_modifier
    end

    if light_preset.flicker_max_modifier ~= nil then
        light.flicker_max_modifier = light_preset.flicker_max_modifier
    end

    if light_preset.flicker_interval ~= nil then
        light.offset_flicker = true
    end
end

if preset.remove_lights then
    for index = #working_visualisations, 1, -1 do
        local visual = working_visualisations[index]

        if is_arc_furnace_glow_light(visual) then
            if visual_has_animation(visual) then
                visual.light = nil
            else
                table.remove(working_visualisations, index)
            end
        end
    end

    return
end

local light_index = 0
local light_presets = preset.lights or {}

for _, visual in ipairs(working_visualisations) do
    if is_arc_furnace_glow_light(visual) then
        light_index = light_index + 1
        apply_light_preset(visual.light, light_presets[light_index] or light_presets[#light_presets])
    end
end
