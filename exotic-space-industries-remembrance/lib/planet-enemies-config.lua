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
