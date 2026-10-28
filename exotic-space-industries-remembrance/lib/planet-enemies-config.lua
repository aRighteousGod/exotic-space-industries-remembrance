-- blueprint: .codex/esir/blueprints/planet-enemies.md#contract
-- Shared data/runtime identities; population settings never alter combat profiles.
local config = {}
config.created_effect = "ei-planet-enemy-created"
config.removals_per_tick = 128
config.rafts_per_tick = 64
config.gaia_control = "ei-gaia-electric-enemies"
config.demolisher_control = "ei-vulcanus-demolishers"
config.controls = {
    nauvis = {ordinary = "enemy-base", explosive = "hot_enemy_base", cold = "frost_enemy_base",
        arachnid = "ei-nauvis-arachnid-enemies", toxic = "ei-nauvis-toxic-enemies", armoured = "ei-nauvis-armoured-enemies"},
    vulcanus = {explosive = "ei-vulcanus-explosive-enemies", demolisher = config.demolisher_control},
    aquilo = {cold = "ei-aquilo-cold-enemies"},
    fulgora = {electric = "electric_enemies"},
    gaia = {electric = config.gaia_control},
    gleba = {pentapod = "gleba_enemy_base"},
}
config.rebindings = {
    {planet = "vulcanus", control = config.controls.vulcanus.explosive, legacy = "hot_enemy_base", prefix = "eb", family = "explosive", size = 1},
    {planet = "aquilo", control = config.controls.aquilo.cold, legacy = "frost_enemy_base", prefix = "cb", family = "cold", size = 1},
    {planet = "gaia", control = config.gaia_control, legacy = "electric_enemies", prefix = "ee", family = "electric", size = 5},
}
config.nauvis_splits = {"arachnid", "toxic", "armoured"}
-- blueprint-ref: .codex/esir/blueprints/planet-enemies.md#seed-compatibility
-- Stored as a native map-generation alias, so map exchange and reforge retain it.
config.revision_property = "ei-enemy-generation-revision"
config.legacy_revision = "ei-enemy-generation-legacy20"
config.native_revision = "ei-enemy-generation-native21"
local probability_properties = {
    ordinary = "enemy_base_probability", explosive = "eb_enemy_base_probability", cold = "cb_enemy_base_probability",
    arachnid = "ei_nauvis_arachnid_enemy_base_probability", toxic = "ei_nauvis_toxic_enemy_base_probability",
    armoured = "ei_nauvis_armoured_enemy_base_probability",
}
local electric_spawners = {"flying-electric-unit-spawner", "walker-electric-unit-spawner"}

---@param planet string
---@param revision string
---@return table<string, string>
function config.generation_aliases(planet, revision)
    local aliases = {[config.revision_property] = revision}
    if planet == "nauvis" then
        for family, property in pairs(probability_properties) do
            aliases[property] = (revision == config.legacy_revision and "ei_nauvis_" or "ei_native21_nauvis_")
                .. family .. "_enemy_base_probability"
        end
    elseif planet == "fulgora" and revision == config.legacy_revision then
        for _, suffix in ipairs({"radius", "frequency", "probability"}) do
            aliases["ee_enemy_base_" .. suffix] = "ei-legacy20-electric-" .. suffix
        end
        for _, name in ipairs(electric_spawners) do
            aliases["entity:" .. name .. ":probability"] = "ei-legacy20-electric-" .. name
        end
    elseif planet == "gaia" then
        local prefix = revision == config.legacy_revision and config.gaia_control or "ei-native21-gaia-electric"
        for _, suffix in ipairs({"radius", "frequency", "probability"}) do
            aliases["ee_enemy_base_" .. suffix] = prefix .. "-" .. suffix
        end
        for _, name in ipairs(electric_spawners) do
            aliases["entity:" .. name .. ":probability"] = prefix .. "-" .. name
        end
    end
    return aliases
end

---@param properties table<string, string>|nil
---@param planet string
---@param fallback string
---@return string
function config.generation_revision(properties, planet, fallback)
    properties = properties or {}
    local marker = properties[config.revision_property]
    if marker ~= nil then return marker end
    for key, value in pairs(config.generation_aliases(planet, config.legacy_revision)) do
        if key ~= config.revision_property and properties[key] == value then return config.legacy_revision end
    end
    return fallback
end

---@param properties table<string, string>
---@param defaults table<string, string>
---@param planet string
---@param fallback string
---@return boolean changed
function config.merge_generation_aliases(properties, defaults, planet, fallback)
    local revision = config.generation_revision(properties, planet, fallback)
    local legacy, native = config.generation_aliases(planet, config.legacy_revision), config.generation_aliases(planet, config.native_revision)
    local selected = config.generation_aliases(planet, revision)
    -- These aliases do not change distribution between revisions.
    for _, binding in ipairs(config.rebindings) do
        if binding.planet == planet and planet ~= "gaia" then
            for _, suffix in ipairs({"radius", "frequency"}) do
                local key = binding.prefix .. "_enemy_base_" .. suffix
                selected[key] = defaults[key]
            end
            for key, value in pairs(defaults) do
                if key:sub(1, 7) == "entity:" and value:sub(1, #binding.control + 1) == binding.control .. "-" then selected[key] = value end
            end
        end
    end
    for _, key in ipairs(planet == "gleba" and {"enemy_base_radius", "enemy_base_frequency"}
        or planet == "vulcanus" and {"demolisher_territory_radius", "demolisher_variation_expression"} or {}) do
        selected[key] = defaults[key]
    end
    local changed = false
    for key, value in pairs(selected) do
        local current = properties[key]
        -- Exact owned identities only; custom expressions are never prefix-matched.
        if current == nil or current == key or current == legacy[key] or current == native[key] or current == value then
            if value == key then value = nil end
            if current ~= value then properties[key] = value; changed = true end
        end
    end
    return changed
end

config.hostile_types = {unit = true, ["spider-unit"] = true, ["unit-spawner"] = true, turret = true,
    ["ammo-turret"] = true, ["electric-turret"] = true, ["artillery-turret"] = true}
local infected = {tb_infected_ship=true, tb_infected_ship_boss=true, tb_infected_radar=true,
    tb_infected_gun_turret=true, tb_infected_laser_turret=true, tb_infected_artillery_turret=true}
local ordinary = {["biter-spawner"]=true, ["spitter-spawner"]=true}
for _, size in ipairs({"small", "medium", "big", "behemoth"}) do
    for _, body in ipairs({"biter", "spitter", "worm-turret"}) do ordinary[size .. "-" .. body] = true end
end

---@param name string
---@param prototype_type string
---@return string|nil family
function config.family(name, prototype_type)
    if not config.hostile_types[prototype_type] then return nil end
    if infected[name] then return "toxic" end
    -- Turret integrations are exact; ordinary player turrets never receive a hook.
    if prototype_type == "ammo-turret" or prototype_type == "electric-turret" or prototype_type == "artillery-turret" then return nil end
    if name:find("arachnid", 1, true) then return "arachnid" end
    if name:find("armoured", 1, true) then return "armoured" end
    if name:find("toxic", 1, true) then return "toxic" end
    if name:find("electric-unit", 1, true) then return "electric" end
    if name:find("explosive", 1, true) then return "explosive" end
    if name:find("-cold-", 1, true) or name:find("maf-boss-frost-", 1, true) then return "cold" end
    if name:find("-pentapod", 1, true) or config.is_raft(name) then return "pentapod" end
    if ordinary[name] then return "ordinary" end
end

---@param name string
---@return boolean
function config.is_raft(name)
    return name == "gleba-spawner" or name == "gleba-spawner-small"
end

---@param name string
---@return boolean
function config.is_demolisher(name)
    return name == "small-demolisher" or name == "medium-demolisher" or name == "big-demolisher"
end

return config
