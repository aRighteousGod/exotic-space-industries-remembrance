--==============================================================================
-- ESIR FILE MAP
-- owns: startup-selected turret stream density, impact damage and sticker cadence
-- loaded_by: data-final-fixes.lua, after fuel variants and compatibility passes
-- cadence: data stage only; no runtime handlers, storage or scripted damage
--==============================================================================
local config = require("lib/thrower-performance-config")
local fuels = require("lib/flamethrower-fuels")
local profile = config.resolve()
local factor = profile.factor
local enabled = factor > 1
local turret_names = {fuels.base_turret, "ei-acidthrower-turret"}

-- Fuel-specific turret effects already have separate ammo/vehicle counterparts.
-- Shared vanilla/acid effects need stable private copies, even under Original,
-- so active saved effects still have prototypes after a profile is switched off.
local exclusive = {stream = {}, fire = {}, sticker = {}}
for _, fuel in ipairs(fuels.fuels) do
    turret_names[#turret_names + 1] = fuel.turret
    exclusive.stream["ei-flame-" .. fuel.id .. "-flamethrower-fire-stream"] = true
    exclusive.fire["ei-flame-" .. fuel.id .. "-turret-fire"] = true
    exclusive.sticker["ei-flame-" .. fuel.id .. "-turret-sticker"] = true
end

---@type table<string, table<string, table>>
local resolved = {stream = {}, fire = {}, sticker = {}}

---@param kind "stream"|"fire"|"sticker"
---@param name string
---@return table
---@return boolean first_visit
local function effect_prototype(kind, name)
    if resolved[kind][name] then return resolved[kind][name], false end
    local source = assert(data.raw[kind][name], "Missing thrower " .. kind .. ": " .. name)
    local effect = source
    if not exclusive[kind][name] then
        effect = table.deepcopy(source)
        effect.name = "ei-thrower-performance-" .. name
        effect.localised_name = source.localised_name or {"entity-name." .. name}
        effect.hidden = true
        data:extend({effect})
    end
    resolved[kind][name] = effect
    return effect, true
end

---@param sources table|nil
local function thin_smoke_sources(sources)
    for _, source in pairs(sources or {}) do
        if source.frequency then source.frequency = source.frequency / factor end
    end
end

---@param node table
local function thin_fuel_smoke(node)
    if node.type == "create-trivial-smoke" then node.probability = (node.probability or 1) / factor end
    for _, child in pairs(node) do
        if type(child) == "table" then thin_fuel_smoke(child) end
    end
end

-- This visitor follows only the turret's impact graph, not arbitrary data.raw
-- references. In particular, tree fires and sticker spread targets stay native.
---@param node table
local function impact_effects(node)
    if node.type == "damage" and enabled then
        node.damage.amount = node.damage.amount * factor
    elseif node.type == "create-sticker" then
        local sticker, first = effect_prototype("sticker", node.sticker)
        if first and enabled and sticker.damage_per_tick then
            local old_interval = sticker.damage_interval or 1
            sticker.damage_interval = math.min(old_interval * factor, profile.sticker_interval_cap)
            sticker.damage_per_tick.amount = sticker.damage_per_tick.amount * sticker.damage_interval / old_interval
        end
        if enabled then node.sticker = sticker.name end
    elseif node.type == "create-fire" then
        local fire, first = effect_prototype("fire", node.entity_name)
        if first and enabled then
            thin_smoke_sources(fire.smoke)
            if fire.on_fuel_added_action then thin_fuel_smoke(fire.on_fuel_added_action) end
        end
        if enabled then node.entity_name = fire.name end
    elseif node.type == "create-trivial-smoke" and enabled then
        node.probability = (node.probability or 1) / factor
    end
    for _, child in pairs(node) do
        if type(child) == "table" then impact_effects(child) end
    end
end

---@param node table
---@param cooldown number
local function turret_deliveries(node, cooldown)
    if node.type == "stream" and node.stream then
        local stream, first = effect_prototype("stream", node.stream)
        if first then
            -- Original must leave source references untouched while still
            -- declaring saved-effect aliases. Visit a copy of its trigger graph.
            local action = enabled and stream.action or table.deepcopy(stream.action)
            local initial_action = enabled and stream.initial_action or table.deepcopy(stream.initial_action)
            if action then impact_effects(action) end
            if initial_action then impact_effects(initial_action) end
            if enabled then
                stream.particle_spawn_timeout = stream.particle_spawn_timeout or 4 * stream.particle_spawn_interval
                stream.particle_spawn_interval = stream.particle_spawn_interval * factor
                thin_smoke_sources(stream.smoke_sources)
            end
        end
        if enabled then
            -- Shared streams may serve several allowed turrets: retain enough
            -- emission time for the slowest owner without transforming twice.
            stream.particle_spawn_timeout = math.max(stream.particle_spawn_timeout or 4 * stream.particle_spawn_interval,
                cooldown + stream.particle_spawn_interval)
            node.stream = stream.name
        end
    end
    for _, child in pairs(node) do
        if type(child) == "table" then turret_deliveries(child, cooldown) end
    end
end

for _, name in ipairs(turret_names) do
    local turret = data.raw["fluid-turret"][name]
    if turret then
        local attack = turret.attack_parameters
        if enabled then
            attack.cooldown = attack.cooldown * factor
            attack.fluid_consumption = (attack.fluid_consumption or 0) * factor
        end
        -- Traverse only ammo delivery; never scale attack.damage_modifier, fuel
        -- bonuses, ground-fire DPS or the native research/quality multipliers.
        if attack.ammo_type then turret_deliveries(attack.ammo_type, attack.cooldown) end
    end
end
