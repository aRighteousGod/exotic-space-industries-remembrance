--==============================================================================
-- ESIR FILE MAP
-- owns: pinpoint native status lights on the curated production machine sprites
-- loaded_by: exotic-space-industries-remembrance/data-final-fixes.lua
-- cadence: data-final stage load after fuel and arc furnace lighting
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: machine sprite geometry or indicator artwork changes
--==============================================================================
-- blueprint: .codex/esir/blueprints/machine-status-lights.md#contract

local preset = require("lib/machine-status-light-config").resolve()
if preset.preserve_original then return end
local definitions = require("lib/machine-status-light-definitions")

---@type data.StatusColors
local status_colors = {
    idle = {1, 0.06, 0.03, 1},
    insufficient_input = {1, 0.06, 0.03, 1},
    full_output = {1, 1, 0, 1},
    disabled = {1, 0.06, 0.03, 1},
    no_power = {0, 0, 0, 0},
    working = {0.08, 1, 0.12, 1},
    low_power = {1, 0.5, 0, 1},
}

-- Deliberately match the complete old light-only entry. A compatibility mod's
-- colored, positioned, tinted, or combined animation/light entry is not ours.
---@param visual data.WorkingVisualisation
---@return boolean
local function is_plain_working_light(visual)
    local light = visual.light
    if not light or light.type ~= "basic" or light.intensity ~= 1 or light.size ~= 15 then
        return false
    end
    for field in pairs(visual) do
        if field ~= "light" then return false end
    end
    for field in pairs(light) do
        if field ~= "type" and field ~= "intensity" and field ~= "size" then return false end
    end
    return true
end

---@param animation data.Animation
---@param pixel data.Vector
---@return data.Vector
local function indicator_position(animation, pixel)
    local size = animation.size
    local width = animation.width or (type(size) == "table" and size[1] or size)
    local height = animation.height or (type(size) == "table" and size[2] or size)
    local shift = animation.shift or {0, 0}
    local scale = (animation.scale or 1) / 32
    return {
        (shift[1] or shift.x or 0) + (pixel[1] - width / 2) * scale,
        (shift[2] or shift.y or 0) + (pixel[2] - height / 2) * scale,
    }
end

---@param graphics data.WorkingVisualisations
---@param pixels data.Vector[]
---@param prepend boolean
---@param name string
local function add_status_lights(graphics, pixels, prepend, name)
    graphics.status_colors = table.deepcopy(status_colors)
    for index, pixel in ipairs(pixels) do
        local position = indicator_position(graphics.animation, pixel)
        -- These bodies share art across orientations. Native tint draws while
        -- stopped and removes only the status emission when energy is absent.
        local visual = {
            always_draw = true,
            apply_tint = "status",
            -- The neutral lens covers the colored face, rim and filtered edge.
            -- Native tint drives both lens and emitter; no-power hides both.
            render_layer = "light-effect",
            secondary_draw_order = 4,
            animation = {
                filename = "__exotic-space-industries-remembrance__/graphics/status-lights/" .. name:sub(4) .. "-" .. index .. ".png",
                size = 64,
                scale = graphics.animation.scale or 1,
                frame_count = 1,
                draw_as_glow = true,
                blend_mode = "normal",
            },
            north_position = table.deepcopy(position),
            east_position = table.deepcopy(position),
            south_position = table.deepcopy(position),
            west_position = table.deepcopy(position),
            light = {
                type = "basic",
                color = {1, 1, 1},
                size = definitions.radius[name] or 0.35,
                -- Calibrated against the reskinned assemblers' emissive LEDs.
                intensity = 1,
                minimum_darkness = 0.1,
            },
        }
        local visuals = graphics.working_visualisations
        table.insert(visuals, prepend and index or (#visuals + 1), visual)
    end
end

for name, pixels in pairs(definitions.replacements) do
    local prototype = data.raw["assembling-machine"][name]
    local graphics = prototype and prototype.graphics_set
    local visuals = graphics and graphics.working_visualisations
    if visuals then
        local replaced = false
        for index = #visuals, 1, -1 do
            if is_plain_working_light(visuals[index]) then
                table.remove(visuals, index)
                replaced = true
            end
        end
        if replaced and preset.status_lights and #pixels > 0 then
            add_status_lights(graphics, pixels, false, name)
        end
    end
end

if preset.status_lights then
    for name, pixels in pairs(definitions.additions) do
        local prototype = data.raw["assembling-machine"][name] or data.raw.furnace[name]
        local graphics = prototype and prototype.graphics_set
        if graphics and graphics.working_visualisations then
            -- Run after the arc-light preset, which owns only its tagged process
            -- lights. Keep that preset independent of these steady status lights.
            -- Emitters have no sprite depth. Keep entries first, with the lens
            -- overlay above the original pixels, without reordering authored art.
            add_status_lights(graphics, pixels, true, name)
        end
    end
end
