local singularity_lance_config = require("lib/singularity-lance-config")
local ei_lib = require("lib/lib")

-- Tree flattening may remove these links. Restore capability order without erasing
-- science/compatibility prerequisites or changing already priced ingredients.
for index, upgrade in ipairs(singularity_lance_config.upgrades) do
    local name = "ei-singularity-lance-" .. upgrade.key
    for _, prerequisite in ipairs(upgrade.prerequisites) do
        ei_lib.add_prerequisite(name, prerequisite)
    end
    local expected = index == 1 and data.raw.technology["ei-singularity-lance"].unit.ingredients
        or ei_data.science[upgrade.science]
    local actual = {}
    for _, pack in pairs(data.raw.technology[name].unit.ingredients) do actual[pack.name or pack[1]] = pack.amount or pack[2] end
    local count = 0
    for _, pack in pairs(expected) do
        assert(actual[pack.name or pack[1]] == (pack.amount or pack[2]), name .. ": science drift after pricing")
        count = count + 1
    end
    assert(table_size(actual) == count, name .. ": unexpected science after pricing")
end

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
