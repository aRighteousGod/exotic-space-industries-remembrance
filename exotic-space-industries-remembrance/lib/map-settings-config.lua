-- blueprint: .codex/esir/blueprints/map-settings.md#contract
-- Typed editor allowlist. Excluded native map-generation internals are never rebuilt.
local config = {surface = {}, global = {}}
---@class EiMapField
---@field id string
---@field kind string
---@field group string
---@field key string
---@field type string
---@field min number|nil
---@field max number|nil
---@field integer boolean|nil
---@field factor number|nil Display units per native unit.
---@field advanced boolean|nil
---@field control string|nil
---@field slider boolean|nil
---@field mapgen boolean|nil
---@field scale boolean|nil Inverse native frequency displayed as terrain scale.
---@field native_group string|nil
---@field difficulty boolean|nil
---@field live_only boolean|nil
---@field label LocalisedString|nil
---@field description LocalisedString|nil
local function field(scope, id, group, kind, minimum, maximum, extra)
    local entry = {id=id, key=id:match("[^.]+$"), group=group, kind=scope, type=kind, min=minimum, max=maximum}
    for key, value in pairs(extra or {}) do entry[key] = value end
    config[scope][#config[scope]+1] = entry
end
field("surface", "peaceful_mode", "surface", "boolean")
field("surface", "no_enemies_mode", "surface", "boolean")
field("surface", "new_bases", "surface", "boolean")
field("surface", "evolution", "surface", "number", 0, 1, {factor=100, live_only=true})
field("surface", "starting_area", "start", "number", 0, 6, {mapgen=true, slider=true})
field("surface", "seed", "advanced", "number", 0, 4294967295, {integer=true, advanced=true})
field("global", "enemy_evolution.enabled", "enemy_evolution", "boolean")
for _, key in ipairs({"time_factor", "destroy_factor", "pollution_factor"}) do
    field("global", "enemy_evolution."..key, "enemy_evolution", "number", 0, 1)
end
field("global", "enemy_expansion.enabled", "enemy_expansion", "boolean")
for _, key in ipairs({"max_expansion_distance", "settler_group_min_size", "settler_group_max_size"}) do
    field("global", "enemy_expansion."..key, "enemy_expansion", "number", 1, 4294967295, {integer=true})
end
for _, key in ipairs({"min_expansion_cooldown", "max_expansion_cooldown"}) do
    field("global", "enemy_expansion."..key, "enemy_expansion", "number", 1, 4294967295, {integer=true, factor=1/3600})
end
field("global", "pollution.enabled", "pollution", "boolean")
for _, key in ipairs({"ageing", "enemy_attack_pollution_consumption_modifier", "min_pollution_to_damage_trees",
    "pollution_with_max_forest_damage", "pollution_per_tree_damage", "pollution_restored_per_tree_damage", "max_pollution_to_restore_trees"}) do
    field("global", "pollution."..key, "pollution", "number", 0, 1000000)
end
field("global", "pollution.diffusion_ratio", "pollution", "number", 0, 0.25)
field("global", "asteroids.spawning_rate", "space", "number", 0, 1000, {native_group="asteroids"})
field("global", "difficulty.spoil_time_modifier", "space", "number", 0.01, 100, {difficulty=true})
field("global", "difficulty.technology_price_multiplier", "advanced", "number", 0.001, 1000, {difficulty=true, advanced=true})
return config
