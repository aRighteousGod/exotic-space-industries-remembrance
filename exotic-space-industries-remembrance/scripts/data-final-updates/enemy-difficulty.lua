local ei_lib = require("lib/lib")
local difficulty_config = require("lib/enemy-difficulty-config")

local difficulty_setting = settings.startup["ei-enemy-difficulty"]
local difficulty = (difficulty_setting and difficulty_setting.value) or difficulty_config.default

local profiles = difficulty_config.profiles
local apex_profiles = difficulty_config.apex_profiles
local royal_profiles = difficulty_config.royal_profiles

local hostile_turret_types = {
    ["turret"] = true,
    ["ammo-turret"] = true,
    ["electric-turret"] = true,
    ["artillery-turret"] = true,
    ["fluid-turret"] = true,
}

local profile = profiles[difficulty]
-- "Original" means "leave the hostile prototype stack exactly as the dependencies built it".
-- Unknown values also fail closed here instead of partially mutating prototypes.
if difficulty == "Original" or not profile then
    return
end

local function scale_integer(value, multiplier, minimum)
    if type(value) ~= "number" then
        return value
    end

    local min_value = minimum or 1
    local scaled = math.floor(value * multiplier + 0.5)
    if scaled < min_value then
        scaled = min_value
    end

    return scaled
end

local function scale_positive(value, multiplier)
    if type(value) == "number" and value > 0 then
        return value * multiplier
    end

    return value
end

local function scale_damage_tables(node, multiplier, seen)
    if type(node) ~= "table" then
        return
    end

    seen = seen or {}
    if seen[node] then
        return
    end
    seen[node] = true

    -- Attack definitions can hide direct damage tables several layers deep inside
    -- nested actions and deliveries, so we recurse instead of hard-coding one layout.
    if type(node.damage) == "table" and type(node.damage.amount) == "number" then
        node.damage.amount = node.damage.amount * multiplier
    end

    for _, value in pairs(node) do
        if type(value) == "table" then
            scale_damage_tables(value, multiplier, seen)
        end
    end
end

local function scale_attack_parameters(attack_parameters, multipliers)
    if type(attack_parameters) ~= "table" then
        return
    end

    if type(attack_parameters.range) == "number" then
        attack_parameters.range = math.max(0, attack_parameters.range * multipliers.range)
    end

    if type(attack_parameters.min_attack_distance) == "number" then
        attack_parameters.min_attack_distance = math.max(0, attack_parameters.min_attack_distance * multipliers.range)
    end

    if type(attack_parameters.cooldown) == "number" and attack_parameters.cooldown > 0 then
        attack_parameters.cooldown = scale_integer(attack_parameters.cooldown, multipliers.cooldown, 1)
    end

    -- We scale both the exposed damage modifier and any directly embedded damage tables
    -- because dependency mods use both patterns.
    if type(attack_parameters.damage_modifier) == "number" and attack_parameters.damage_modifier > 0 then
        attack_parameters.damage_modifier = attack_parameters.damage_modifier * multipliers.damage
    end

    scale_damage_tables(attack_parameters, multipliers.damage)
end

local function scale_armoured_resistances(prototype, multiplier)
    if type(prototype.resistances) ~= "table" then
        return
    end

    for _, resistance in pairs(prototype.resistances) do
        if type(resistance) == "table" then
            -- Positive partial resistances get scaled; full immunities and weird negative
            -- values are left alone so we do not accidentally invert bespoke prototype logic.
            if type(resistance.percent) == "number" and resistance.percent > 0 and resistance.percent < 100 then
                resistance.percent = math.min(100, resistance.percent * multiplier)
            end

            if type(resistance.decrease) == "number" and resistance.decrease > 0 then
                resistance.decrease = resistance.decrease * multiplier
            end
        end
    end
end

local function is_excluded_name(name)
    -- v1 deliberately leaves pentapod/demolisher/Gleba ecology alone. Those surfaces and
    -- factions have their own pressure assumptions and are easier to over-correct.
    return ei_lib.contains(name, "pentapod")
        or ei_lib.contains(name, "demolisher")
        or ei_lib.contains(name, "gleba")
end

local function is_target_enemy(prototype)
    if not (prototype and prototype.name and prototype.subgroup == "enemies") then
        return false
    end

    return not is_excluded_name(prototype.name)
end

local function is_armoured(prototype)
    return prototype and prototype.name and ei_lib.contains(prototype.name, "armoured")
end

local function is_apex(prototype)
    if not (prototype and prototype.name) then
        return false
    end

    local name = prototype.name
    return ei_lib.contains(name, "leviathan")
        or ei_lib.contains(name, "mother")
        or ei_lib.startswith(name, "maf-boss-")
        or ei_lib.startswith(name, "walking-electric-unit-boss-")
        or name == "tb_infected_ship_boss"
end

local function is_royal(prototype)
    return prototype and prototype.name == "arachnid-biter-royalwarrior-unit"
end

local function get_unit_like_multipliers(prototype)
    local multipliers = {
        health = is_armoured(prototype) and profile.armoured_health or profile.unit_health,
        healing = profile.healing,
        damage = profile.damage,
        movement = profile.movement,
        range = profile.range,
        cooldown = profile.attack_cooldown,
    }

    -- Royal overrides win first because the royal warrior deliberately keeps general hp,
    -- unlike the broader Merciful/Impossible apex bucket.
    local royal = royal_profiles[difficulty]
    if royal and is_royal(prototype) then
        multipliers.damage = royal.damage
        multipliers.movement = royal.movement
        return multipliers
    end

    -- Apex overrides are name-based on purpose: several dependency mods do not expose a
    -- shared marker, but their boss chains are reliably named.
    local apex = apex_profiles[difficulty]
    if apex and is_apex(prototype) then
        multipliers.health = apex.unit_health
        multipliers.damage = apex.damage
        multipliers.range = apex.range
        multipliers.cooldown = apex.cooldown
    end

    return multipliers
end

local function get_spawner_multipliers(prototype)
    local multipliers = {
        health = profile.spawner_health,
        healing = profile.spawner_healing,
        spawn_cooldown = profile.spawn_cooldown,
        caps = profile.owned_friend_caps,
    }

    local apex = apex_profiles[difficulty]
    if apex and is_apex(prototype) then
        multipliers.health = apex.spawner_health
        multipliers.healing = apex.spawner_healing
        multipliers.spawn_cooldown = apex.spawner_cooldown
        multipliers.caps = apex.spawner_caps
    end

    return multipliers
end

local function scale_hostile_unit_like(prototype, multipliers)
    if type(prototype.max_health) == "number" and prototype.max_health > 0 then
        prototype.max_health = scale_integer(prototype.max_health, multipliers.health, 1)
    end

    if type(prototype.healing_per_tick) == "number" and prototype.healing_per_tick > 0 then
        prototype.healing_per_tick = prototype.healing_per_tick * multipliers.healing
    end

    if type(prototype.movement_speed) == "number" and prototype.movement_speed > 0 then
        prototype.movement_speed = prototype.movement_speed * multipliers.movement
    end

    if type(prototype.distance_per_frame) == "number" and prototype.distance_per_frame > 0 then
        prototype.distance_per_frame = prototype.distance_per_frame * multipliers.movement
    end

    scale_attack_parameters(prototype.attack_parameters, multipliers)
end

local function scale_hostile_spawner(prototype, multipliers)
    if type(prototype.max_health) == "number" and prototype.max_health > 0 then
        prototype.max_health = scale_integer(prototype.max_health, multipliers.health, 1)
    end

    if type(prototype.healing_per_tick) == "number" and prototype.healing_per_tick > 0 then
        prototype.healing_per_tick = prototype.healing_per_tick * multipliers.healing
    end

    if type(prototype.spawning_cooldown) == "table" then
        for index, value in ipairs(prototype.spawning_cooldown) do
            if type(value) == "number" and value > 0 then
                prototype.spawning_cooldown[index] = scale_integer(value, multipliers.spawn_cooldown, 1)
            end
        end
    elseif type(prototype.spawning_cooldown) == "number" and prototype.spawning_cooldown > 0 then
        prototype.spawning_cooldown = scale_integer(prototype.spawning_cooldown, multipliers.spawn_cooldown, 1)
    end

    if type(prototype.max_count_of_owned_units) == "number" and prototype.max_count_of_owned_units > 0 then
        prototype.max_count_of_owned_units = scale_integer(prototype.max_count_of_owned_units, multipliers.caps, 1)
    end

    if type(prototype.max_friends_around_to_spawn) == "number" and prototype.max_friends_around_to_spawn > 0 then
        prototype.max_friends_around_to_spawn = scale_integer(prototype.max_friends_around_to_spawn, multipliers.caps, 1)
    end
end

local scaled_counts = {
    units = 0,
    spawners = 0,
    turrets = 0,
}

-- Units, hostile turrets, and spawners each get their own pass because their mutable
-- fields differ enough that a single generic walker would become harder to trust.
for _, prototype in pairs(data.raw.unit or {}) do
    if is_target_enemy(prototype) then
        scale_hostile_unit_like(prototype, get_unit_like_multipliers(prototype))
        if is_armoured(prototype) then
            scale_armoured_resistances(prototype, profile.armoured_resistance)
        end
        scaled_counts.units = scaled_counts.units + 1
    end
end

for turret_type, _ in pairs(hostile_turret_types) do
    for _, prototype in pairs(data.raw[turret_type] or {}) do
        if is_target_enemy(prototype) then
            scale_hostile_unit_like(prototype, get_unit_like_multipliers(prototype))
            if is_armoured(prototype) then
                scale_armoured_resistances(prototype, profile.armoured_resistance)
            end
            scaled_counts.turrets = scaled_counts.turrets + 1
        end
    end
end

for _, prototype in pairs(data.raw["unit-spawner"] or {}) do
    if is_target_enemy(prototype) then
        scale_hostile_spawner(prototype, get_spawner_multipliers(prototype))
        if is_armoured(prototype) then
            scale_armoured_resistances(prototype, profile.armoured_resistance)
        end
        scaled_counts.spawners = scaled_counts.spawners + 1
    end
end

log(
    "EI enemy difficulty "
        .. difficulty
        .. " scaled "
        .. scaled_counts.units
        .. " hostile units, "
        .. scaled_counts.turrets
        .. " hostile turrets, and "
        .. scaled_counts.spawners
        .. " hostile spawners."
)
