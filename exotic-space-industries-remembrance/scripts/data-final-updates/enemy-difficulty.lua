local ei_lib = require("lib/lib")

local difficulty_setting = settings.startup["ei-enemy-difficulty"]
local difficulty = (difficulty_setting and difficulty_setting.value) or "Tempered"

-- The startup ladder is intentionally data-driven so we can rebalance tiers without
-- touching the actual scaling passes below. "Original" is handled by the early return.
local profiles = {
    Tempered = {
        unit_health = 0.82,
        armoured_health = 0.75,
        armoured_resistance = 0.85,
        healing = 0.82,
        damage = 0.88,
        range = 0.96,
        movement = 0.96,
        attack_cooldown = 1.10,
        spawner_health = 0.88,
        spawner_healing = 0.88,
        spawn_cooldown = 1.25,
        owned_friend_caps = 0.85,
    },
    Gentle = {
        unit_health = 0.70,
        armoured_health = 0.60,
        armoured_resistance = 0.70,
        healing = 0.70,
        damage = 0.78,
        range = 0.93,
        movement = 0.93,
        attack_cooldown = 1.20,
        spawner_health = 0.78,
        spawner_healing = 0.78,
        spawn_cooldown = 1.45,
        owned_friend_caps = 0.75,
    },
    Merciful = {
        unit_health = 0.55,
        armoured_health = 0.45,
        armoured_resistance = 0.55,
        healing = 0.55,
        damage = 0.65,
        range = 0.90,
        movement = 0.90,
        attack_cooldown = 1.35,
        spawner_health = 0.65,
        spawner_healing = 0.65,
        spawn_cooldown = 1.80,
        owned_friend_caps = 0.60,
    },
    Severe = {
        unit_health = 1.18,
        armoured_health = 1.30,
        armoured_resistance = 1.15,
        healing = 1.15,
        damage = 1.12,
        range = 1.03,
        movement = 1.04,
        attack_cooldown = 0.92,
        spawner_health = 1.15,
        spawner_healing = 1.15,
        spawn_cooldown = 0.85,
        owned_friend_caps = 1.15,
    },
    Nightmare = {
        unit_health = 1.40,
        armoured_health = 1.65,
        armoured_resistance = 1.28,
        healing = 1.30,
        damage = 1.25,
        range = 1.06,
        movement = 1.08,
        attack_cooldown = 0.82,
        spawner_health = 1.38,
        spawner_healing = 1.30,
        spawn_cooldown = 0.70,
        owned_friend_caps = 1.35,
    },
    Impossible = {
        unit_health = 1.75,
        armoured_health = 2.10,
        armoured_resistance = 1.40,
        healing = 1.55,
        damage = 1.42,
        range = 1.10,
        movement = 1.12,
        attack_cooldown = 0.72,
        spawner_health = 1.75,
        spawner_healing = 1.50,
        spawn_cooldown = 0.55,
        owned_friend_caps = 1.60,
    },
}

-- Only the outermost tiers get bespoke apex handling. Everything else stays on the
-- proportional ladder so the difficulty curve reads consistently.
local apex_profiles = {
    Merciful = {
        unit_health = 0.30,
        damage = 0.50,
        range = 0.85,
        cooldown = 1.50,
        spawner_health = 0.30,
        spawner_healing = 0.50,
        spawner_cooldown = 2.10,
        spawner_caps = 0.50,
    },
    Impossible = {
        unit_health = 2.40,
        damage = 1.60,
        range = 1.18,
        cooldown = 0.62,
        spawner_health = 2.25,
        spawner_healing = 1.60,
        spawner_cooldown = 0.45,
        spawner_caps = 1.75,
    },
}

-- The royal warrior is intentionally handled outside the broader apex bucket: it keeps
-- normal health scaling, but its damage and mobility still need bespoke pressure tuning.
local royal_profiles = {
    Merciful = {
        damage = 0.55,
        movement = 0.85,
    },
    Impossible = {
        damage = 1.55,
        movement = 1.18,
    },
}

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
