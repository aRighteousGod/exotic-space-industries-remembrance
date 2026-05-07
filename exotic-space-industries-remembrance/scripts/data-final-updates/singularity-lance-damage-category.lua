local singularity_lance_config = require("lib/singularity-lance-config")

local LANCE_DAMAGE_CATEGORY = singularity_lance_config.ammo_damage_category or "ei-singularity-lance"
local SOURCE_DAMAGE_CATEGORY = "laser"
local MIRRORED_DAMAGE_TECHS = {
    "laser-weapons-damage-6",
    "laser-weapons-damage-7",
}

-- The lance unlocks behind tier 5, but its own damage should begin at base value.
-- Mirror only later laser damage tiers into the lance-specific ammo category.
local function get_laser_damage_modifier(technology)
    for _, effect in pairs(technology.effects or {}) do
        if effect.type == "ammo-damage"
            and effect.ammo_category == SOURCE_DAMAGE_CATEGORY
            and type(effect.modifier) == "number"
        then
            return effect.modifier
        end
    end

    return nil
end

local function has_lance_damage_modifier(technology)
    for _, effect in pairs(technology.effects or {}) do
        if effect.type == "ammo-damage" and effect.ammo_category == LANCE_DAMAGE_CATEGORY then
            return true
        end
    end

    return false
end

for _, technology_name in ipairs(MIRRORED_DAMAGE_TECHS) do
    local technology = data.raw.technology[technology_name]
    if technology then
        technology.effects = technology.effects or {}

        if not has_lance_damage_modifier(technology) then
            local modifier = get_laser_damage_modifier(technology)
            if modifier then
                table.insert(technology.effects, {
                    type = "ammo-damage",
                    ammo_category = LANCE_DAMAGE_CATEGORY,
                    modifier = modifier,
                })
            end
        end
    end
end
