--==============================================================================
-- ESIR FILE MAP
-- owns: Emerald Apocalypse Hover Tank final data-stage hover tuning
-- loaded_by: data-final-fixes.lua
-- cadence: data-final-updates load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data-final-updates reload, prototype cache rebuild
--==============================================================================

local ei_lib = require("lib.lib")

local tank = data.raw.car and data.raw.car["ei-emerald-apocalypse-hover-tank"]
local hover_layer = mods["Hovercrafts"] and "hovercraft" or "ei_hovercraft"
local LASER_7_TECH = "laser-weapons-damage-7"
local ORBITAL_SHARD_LASER_7_DESCRIPTION = "modifier-description.ei-emerald-orbital-shards-laser-7-bonus"

local STRONG_RESISTANCES = {
    fire = {decrease = 120, percent = 95},
    physical = {decrease = 80, percent = 95},
    impact = {decrease = 180, percent = 95},
    explosion = {decrease = 140, percent = 95},
    acid = {decrease = 80, percent = 95},
    laser = {decrease = 80, percent = 95},
    electric = {decrease = 80, percent = 95},
    ["ei-plasma"] = {decrease = 140, percent = 95},
}

local function mask_layers(prototype)
    if type(prototype) ~= "table" or type(prototype.collision_mask) ~= "table" then
        return nil
    end

    prototype.collision_mask.layers = prototype.collision_mask.layers or {}
    return prototype.collision_mask.layers
end

local function add_hover_layer_to_player_colliders()
    for prototype_type, prototypes in pairs(data.raw) do
        if prototype_type ~= "tile" and type(prototypes) == "table" then
            for _, prototype in pairs(prototypes) do
                local layers = mask_layers(prototype)
                if layers and layers.player == true and prototype.name ~= "ei-emerald-apocalypse-hover-tank" then
                    layers[hover_layer] = true
                end
            end
        end
    end
end

local function set_hover_mask(prototype)
    prototype.collision_mask = prototype.collision_mask or {layers = {}}
    prototype.collision_mask.layers = prototype.collision_mask.layers or {}
    prototype.collision_mask.layers.player = nil
    prototype.collision_mask.layers[hover_layer] = true
    prototype.collision_mask.layers.object = true
    prototype.collision_mask.layers.train = true
    prototype.collision_mask.layers.is_object = true
    prototype.collision_mask.layers.is_lower_object = true
end

local function reinforce_resistances(prototype)
    for damage_name in pairs(data.raw["damage-type"] or {}) do
        local strong = STRONG_RESISTANCES[damage_name]
        ei_lib.upsert_resistance(prototype, {
            type = damage_name,
            decrease = strong and strong.decrease or 30,
            percent = strong and strong.percent or 90,
        })
    end
end

local function has_orbital_shard_laser_marker(technology)
    for _, effect in pairs(technology.effects or {}) do
        local description = effect and effect.effect_description
        if effect.type == "nothing"
            and type(description) == "table"
            and description[1] == ORBITAL_SHARD_LASER_7_DESCRIPTION then
            return true
        end
    end

    return false
end

local function add_orbital_shard_laser_marker()
    local technology = data.raw.technology and data.raw.technology[LASER_7_TECH]
    if not technology then
        return false
    end

    technology.effects = type(technology.effects) == "table" and technology.effects or {}
    if has_orbital_shard_laser_marker(technology) then
        return false
    end

    technology.effects[#technology.effects + 1] = {
        type = "nothing",
        effect_description = {ORBITAL_SHARD_LASER_7_DESCRIPTION},
    }
    return true
end

if tank then
    add_hover_layer_to_player_colliders()
    set_hover_mask(tank)
    reinforce_resistances(tank)
end

add_orbital_shard_laser_marker()
