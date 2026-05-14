--==============================================================================
-- ESIR FILE MAP
-- owns: startup-controlled item picture glow overlay fidelity
-- loaded_by: exotic-space-industries-remembrance\data-final-fixes.lua
-- cadence: data-final stage load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: item picture glow overlay or startup setting changes
--==============================================================================

local ei_lib = require("lib/lib")

local mode = ei_lib.config("item-glow-overlay-fidelity")

if mode ~= "flat" and mode ~= "off" then
    return
end

local item_picture_prototype_types = {
    "item",
    "tool",
    "ammo",
}

local modified_vanilla_science_packs = {
    ["agricultural-science-pack"] = true,
    ["cryogenic-science-pack"] = true,
    ["electromagnetic-science-pack"] = true,
    ["metallurgic-science-pack"] = true,
    ["promethium-science-pack"] = true,
}

local function should_apply_to_prototype(prototype)
    local name = prototype and prototype.name

    return ei_lib.startswith(name, "ei-") or modified_vanilla_science_packs[name] == true
end

local function has_light_flag(flags)
    if type(flags) ~= "table" then
        return false
    end

    for key, flag in pairs(flags) do
        if key == "light" or flag == "light" then
            return true
        end
    end

    return false
end

local function clear_light_flag(layer)
    local flags = layer.flags

    if type(flags) ~= "table" then
        return false
    end

    local changed = false

    for i = #flags, 1, -1 do
        if flags[i] == "light" then
            table.remove(flags, i)
            changed = true
        end
    end

    if flags.light ~= nil then
        flags.light = nil
        changed = true
    end

    if not next(flags) then
        layer.flags = nil
    end

    return changed
end

local function is_item_glow_layer(layer)
    return type(layer) == "table" and (layer.draw_as_light == true or has_light_flag(layer.flags))
end

local function flatten_glow_layer(layer)
    local changed = false

    if layer.draw_as_light == true then
        layer.draw_as_light = nil
        changed = true
    end

    return clear_light_flag(layer) or changed
end

local function apply_mode_to_layers(layers)
    if type(layers) ~= "table" then
        return false
    end

    local changed = false

    if mode == "flat" then
        for _, layer in ipairs(layers) do
            if is_item_glow_layer(layer) then
                changed = flatten_glow_layer(layer) or changed
            end
        end

        return changed
    end

    local retained_layers = 0

    for _, layer in ipairs(layers) do
        if type(layer) == "table" and not is_item_glow_layer(layer) then
            retained_layers = retained_layers + 1
        end
    end

    if retained_layers == 0 then
        -- Avoid producing an empty sprite if a future item picture is authored as light-only.
        for _, layer in ipairs(layers) do
            if is_item_glow_layer(layer) then
                changed = flatten_glow_layer(layer) or changed
            end
        end

        return changed
    end

    for i = #layers, 1, -1 do
        if is_item_glow_layer(layers[i]) then
            table.remove(layers, i)
            changed = true
        end
    end

    return changed
end

local function apply_mode_to_picture(picture)
    if type(picture) ~= "table" then
        return false
    end

    local changed = apply_mode_to_layers(picture.layers)

    if type(picture.hr_version) == "table" then
        changed = apply_mode_to_picture(picture.hr_version) or changed
    end

    return changed
end

local function apply_mode_to_pictures(pictures)
    if type(pictures) ~= "table" then
        return false
    end

    local changed = apply_mode_to_picture(pictures)

    for i = 1, #pictures do
        changed = apply_mode_to_picture(pictures[i]) or changed
    end

    return changed
end

for _, prototype_type in pairs(item_picture_prototype_types) do
    local prototypes = data.raw[prototype_type]

    if prototypes then
        for _, prototype in pairs(prototypes) do
            if should_apply_to_prototype(prototype) then
                apply_mode_to_pictures(prototype.pictures)
            end
        end
    end
end
