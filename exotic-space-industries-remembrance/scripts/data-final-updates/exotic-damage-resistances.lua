local ei_lib = require("lib/lib")

local hostile_turret_types = {
    "turret",
    "ammo-turret",
    "electric-turret",
    "artillery-turret",
    "fluid-turret",
}

local non_hostile_turret_types = hostile_turret_types

local armor_resistances = {
    ["light-armor"] = {radiological = 0, morphium = 0},
    ["heavy-armor"] = {radiological = 0, morphium = 0},
    ["modular-armor"] = {radiological = 0, morphium = 0},
    ["power-armor"] = {radiological = 30, morphium = 20},
    ["power-armor-mk2"] = {radiological = 40, morphium = 30},
    ["mech-armor"] = {radiological = 50, morphium = 35},
    ["ei-bio-armor"] = {radiological = 45, morphium = 45},
    ["cb-modular-armor"] = {radiological = 0, morphium = 0},
    ["cb-power-armor"] = {radiological = 30, morphium = 20},
    ["cb-power-armor-mk2"] = {radiological = 40, morphium = 30},
}

local function has_flag(prototype, flag_name)
    if type(prototype) ~= "table" or type(prototype.flags) ~= "table" then
        return false
    end

    for _, flag in pairs(prototype.flags) do
        if flag == flag_name then
            return true
        end
    end

    return false
end

local function is_hostile(prototype)
    if type(prototype) ~= "table" then
        return false
    end

    return has_flag(prototype, "placeable-enemy") or prototype.subgroup == "enemies"
end

local function add_missing_damage_resistance(prototype, damage_type, percent)
    ei_lib.upsert_resistance(prototype, {
        type = damage_type,
        percent = percent
    })
end

local function apply_pair(prototype, radiological_percent, morphium_percent)
    add_missing_damage_resistance(prototype, "ei-radiological", radiological_percent)
    add_missing_damage_resistance(prototype, "ei-morphium", morphium_percent)
end

local function get_hostile_pair(name)
    local lowered = string.lower(name or "")

    if ei_lib.contains(lowered, "electric-unit-boss") then
        return 60, 35
    end

    if ei_lib.contains(lowered, "electric-unit-spawner") then
        return 50, 35
    end

    if ei_lib.contains(lowered, "electric-unit") then
        return 40, 30
    end

    if ei_lib.contains(lowered, "gleba-spawner") or ei_lib.contains(lowered, "gleba_spawner") then
        return 12, 5
    end

    if ei_lib.contains(lowered, "wriggler-pentapod") then
        return 0, 5
    end

    if ei_lib.contains(lowered, "strafer-pentapod") then
        return 10, 5
    end

    if ei_lib.contains(lowered, "stomper-pentapod") then
        return 20, 5
    end

    if ei_lib.startswith(lowered, "small-demolisher") then
        return 15, 5
    end

    if ei_lib.startswith(lowered, "medium-demolisher") then
        return 25, 5
    end

    if ei_lib.startswith(lowered, "big-demolisher") then
        return 35, 5
    end

    if ei_lib.contains(lowered, "armoured") then
        return 5, 25
    end

    return 10, 10
end

local function patch_hostile_prototype(prototype)
    if not (prototype and prototype.name and is_hostile(prototype)) then
        return false
    end

    local radiological_percent, morphium_percent = get_hostile_pair(prototype.name)
    apply_pair(prototype, radiological_percent, morphium_percent)
    return true
end

local patched_hostiles = 0
for _, prototype in pairs(data.raw.unit or {}) do
    if patch_hostile_prototype(prototype) then
        patched_hostiles = patched_hostiles + 1
    end
end

for _, prototype in pairs(data.raw["spider-unit"] or {}) do
    if patch_hostile_prototype(prototype) then
        patched_hostiles = patched_hostiles + 1
    end
end

for _, prototype in pairs(data.raw["unit-spawner"] or {}) do
    if patch_hostile_prototype(prototype) then
        patched_hostiles = patched_hostiles + 1
    end
end

for _, prototype in pairs(data.raw["segmented-unit"] or {}) do
    if patch_hostile_prototype(prototype) then
        patched_hostiles = patched_hostiles + 1
    end
end

for _, turret_type in pairs(hostile_turret_types) do
    for _, prototype in pairs(data.raw[turret_type] or {}) do
        if patch_hostile_prototype(prototype) then
            patched_hostiles = patched_hostiles + 1
        end
    end
end

-- Demolisher segments and tails can live outside the main segmented-unit table.
for _, prototypes in pairs(data.raw) do
    for _, prototype in pairs(prototypes) do
        if type(prototype) == "table" and type(prototype.name) == "string" then
            local lowered = string.lower(prototype.name)
            if prototype.resistances and (
                ei_lib.startswith(lowered, "small-demolisher")
                or ei_lib.startswith(lowered, "medium-demolisher")
                or ei_lib.startswith(lowered, "big-demolisher")
            ) then
                patch_hostile_prototype(prototype)
            end
        end
    end
end

for armor_name, pair in pairs(armor_resistances) do
    local armor = data.raw.armor and data.raw.armor[armor_name]
    if armor then
        apply_pair(armor, pair.radiological, pair.morphium)
    end
end

for _, prototype in pairs(data.raw.wall or {}) do
    local lowered = string.lower(prototype.name or "")
    if lowered == "tough-wall" then
        apply_pair(prototype, 35, 75)
    elseif lowered == "plated-wall" then
        apply_pair(prototype, 45, 80)
    else
        apply_pair(prototype, 25, 65)
    end
end

for _, prototype in pairs(data.raw.gate or {}) do
    apply_pair(prototype, 25, 65)
end

local rolling_stock_types = {
    "locomotive",
    "cargo-wagon",
    "fluid-wagon",
    "artillery-wagon",
}

for _, raw_type in pairs(rolling_stock_types) do
    for _, prototype in pairs(data.raw[raw_type] or {}) do
        apply_pair(prototype, 25, 60)
    end
end

for _, turret_type in pairs(non_hostile_turret_types) do
    for _, prototype in pairs(data.raw[turret_type] or {}) do
        if not is_hostile(prototype) then
            apply_pair(prototype, 20, 50)
        end
    end
end

log("EI exotic damage resistances patched hostile and infrastructure surfaces.")
