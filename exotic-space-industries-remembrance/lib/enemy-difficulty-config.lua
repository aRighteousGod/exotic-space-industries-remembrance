--==============================================================================
--==============================================================================
-- ESIR FILE MAP
-- owns: stage-neutral enemy difficulty order and multiplier profiles
-- loaded_by: settings.lua, scripts/data-final-updates/enemy-difficulty.lua,
--            scripts/control/informatron.lua
-- cadence: load-time constants only
-- forwarded_events: none
-- storage_roots: none
-- rebuild_on: enemy difficulty balance or documentation changes
--==============================================================================

---@class EnemyDifficultyProfile
---@field unit_health number
---@field armoured_health number
---@field armoured_resistance number
---@field healing number
---@field damage number
---@field range number
---@field movement number
---@field attack_cooldown number
---@field spawner_health number
---@field spawner_healing number
---@field spawn_cooldown number
---@field owned_friend_caps number

---@class EnemyDifficultyApexProfile
---@field unit_health number
---@field damage number
---@field range number
---@field cooldown number
---@field spawner_health number
---@field spawner_healing number
---@field spawner_cooldown number
---@field spawner_caps number

---@class EnemyDifficultyRoyalProfile
---@field damage number
---@field movement number

local config = {
    default = "Tempered",
    order = {
        "Merciful",
        "Sheltered",
        "Forgiving",
        "Lenient",
        "Gentle",
        "Tempered",
        "Original",
        "Severe",
        "Nightmare",
        "Impossible",
    },
    locale_suffixes = {
        Merciful = "merciful",
        Sheltered = "sheltered",
        Forgiving = "forgiving",
        Lenient = "lenient",
        Gentle = "gentle",
        Tempered = "tempered",
        Original = "original",
        Severe = "severe",
        Nightmare = "nightmare",
        Impossible = "impossible",
    },
    ---@type table<string, EnemyDifficultyProfile>
    profiles = {
        Merciful = {
            unit_health = 0.25,
            armoured_health = 0.20,
            armoured_resistance = 0.25,
            healing = 0.20,
            damage = 0.30,
            range = 0.84,
            movement = 0.84,
            attack_cooldown = 1.75,
            spawner_health = 0.30,
            spawner_healing = 0.25,
            spawn_cooldown = 3.00,
            owned_friend_caps = 0.20,
        },
        Sheltered = {
            unit_health = 0.35,
            armoured_health = 0.28,
            armoured_resistance = 0.35,
            healing = 0.32,
            damage = 0.42,
            range = 0.86,
            movement = 0.86,
            attack_cooldown = 1.60,
            spawner_health = 0.42,
            spawner_healing = 0.40,
            spawn_cooldown = 2.55,
            owned_friend_caps = 0.35,
        },
        Forgiving = {
            unit_health = 0.45,
            armoured_health = 0.36,
            armoured_resistance = 0.45,
            healing = 0.44,
            damage = 0.54,
            range = 0.88,
            movement = 0.88,
            attack_cooldown = 1.47,
            spawner_health = 0.54,
            spawner_healing = 0.52,
            spawn_cooldown = 2.15,
            owned_friend_caps = 0.48,
        },
        Lenient = {
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
        Original = {
            unit_health = 1.00,
            armoured_health = 1.00,
            armoured_resistance = 1.00,
            healing = 1.00,
            damage = 1.00,
            range = 1.00,
            movement = 1.00,
            attack_cooldown = 1.00,
            spawner_health = 1.00,
            spawner_healing = 1.00,
            spawn_cooldown = 1.00,
            owned_friend_caps = 1.00,
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
    },
    ---@type table<string, EnemyDifficultyApexProfile>
    apex_profiles = {
        Merciful = {
            unit_health = 0.15,
            damage = 0.20,
            range = 0.82,
            cooldown = 2.10,
            spawner_health = 0.15,
            spawner_healing = 0.15,
            spawner_cooldown = 4.00,
            spawner_caps = 0.10,
        },
        Sheltered = {
            unit_health = 0.20,
            damage = 0.30,
            range = 0.83,
            cooldown = 1.90,
            spawner_health = 0.20,
            spawner_healing = 0.27,
            spawner_cooldown = 3.35,
            spawner_caps = 0.23,
        },
        Forgiving = {
            unit_health = 0.25,
            damage = 0.40,
            range = 0.84,
            cooldown = 1.70,
            spawner_health = 0.25,
            spawner_healing = 0.38,
            spawner_cooldown = 2.70,
            spawner_caps = 0.37,
        },
        Lenient = {
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
    },
    ---@type table<string, EnemyDifficultyRoyalProfile>
    royal_profiles = {
        Merciful = {damage = 0.22, movement = 0.82},
        Sheltered = {damage = 0.33, movement = 0.83},
        Forgiving = {damage = 0.44, movement = 0.84},
        Lenient = {damage = 0.55, movement = 0.85},
        Impossible = {damage = 1.55, movement = 1.18},
    },
}

function config.copy_order()
    local copy = {}
    for index, name in ipairs(config.order) do
        copy[index] = name
    end
    return copy
end

return config
