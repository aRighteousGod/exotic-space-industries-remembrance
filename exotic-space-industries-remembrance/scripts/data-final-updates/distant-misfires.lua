--====================================================================================================
--CHECK FOR MOD
--====================================================================================================

if not mods["distant-misfires"] then
    return
end

local ei_lib = require("lib/lib")

local function ensure_array(value)
    if not value then
        return {}
    end

    if value[1] then
        return value
    end

    return {value}
end

local function find_projectile_delivery(ammo)
    if not ammo or not ammo.ammo_type or not ammo.ammo_type.action then
        return nil
    end

    for _, action in ipairs(ensure_array(ammo.ammo_type.action)) do
        for _, delivery in ipairs(ensure_array(action.action_delivery)) do
            if delivery and delivery.type == "projectile" then
                return delivery
            end
        end
    end

    return nil
end

-- Surveyor weapons are hidden for now, so keep their Distant Misfires restore
-- patch parked until the chain comes back.
--[[
local surveyor_guns = {
    ["ei-surveyor-carbine"] = {
        range = 40,
        cooldown = 36,
        damage_modifier = 6.4,
        movement_slow_down_factor = 0.6,
    },
    ["ei-surveyor-rifle"] = {
        range = 52,
        cooldown = 45,
        damage_modifier = 9.0,
        movement_slow_down_factor = 0.65,
    },
    ["ei-surveyor-cannon"] = {
        range = 70,
        cooldown = 60,
        damage_modifier = 24.0,
        movement_slow_down_factor = 0.8,
    },
    ["ei-adaptive-surveyor"] = {
        range = 90,
        cooldown = 72,
        damage_modifier = 34.2,
        movement_slow_down_factor = 0.75,
    },
}

local function restore_surveyor_gun(name, spec)
    local gun = ei_lib.raw["gun"][name]
    local attack_parameters = gun and gun.attack_parameters
    if not attack_parameters then
        return 0
    end

    -- Distant Misfires sees Surveyors as ordinary bullet guns. Reassert the
    -- scoped weapon profile after its generic gun pass has finished.
    attack_parameters.ammo_category = "bullet"
    attack_parameters.range = spec.range
    attack_parameters.cooldown = spec.cooldown
    attack_parameters.damage_modifier = spec.damage_modifier
    attack_parameters.movement_slow_down_factor = spec.movement_slow_down_factor
    attack_parameters.projectile_creation_distance = 1.125
    attack_parameters.projectile_center = {0, -0.9}
    attack_parameters.use_shooter_direction = true

    if attack_parameters.shell_particle then
        attack_parameters.shell_particle.center = {0, 0.9}
    end

    return spec.range
end

local function ensure_bullet_projectile_range(minimum_range)
    for _, ammo in pairs(data.raw.ammo) do
        if ammo.ammo_category == "bullet" then
            local delivery = find_projectile_delivery(ammo)
            if delivery and (not delivery.max_range or delivery.max_range < minimum_range) then
                delivery.max_range = minimum_range
            end
        end
    end
end
]]

local ur_mag = ei_lib.raw["ammo"]["uranium-rounds-magazine"]
if ur_mag then
    local ur_delivery = find_projectile_delivery(ur_mag)

    for _, ammo_name in ipairs({
        "ei-compound-ammo",
        "ei-corrosive-ammo",
        "ei-cryo-ammo",
        "ei-oxyfluoride-ammo",
        "ei-morphium-ammo",
        "ei-hexafluoride-ammo",
        "ei-arc-ammo",
        "ei-neutron-ammo",
    }) do
        local ammo = ei_lib.raw["ammo"][ammo_name]
        if ammo then
            ammo.magazine_size = ur_mag.magazine_size

            -- Distant Misfires only applies its heavy bullet spread pass to ammo ids
            -- containing "magazine". Our exotic rounds keep custom ids ending in
            -- "-ammo", so mirror the scalar projectile delivery fields from the
            -- already-mutated uranium rounds without replacing the exotic projectile.
            if ur_delivery then
                local ammo_delivery = find_projectile_delivery(ammo)
                if ammo_delivery then
                    ammo.ammo_type.target_type = ur_mag.ammo_type and ur_mag.ammo_type.target_type or ammo.ammo_type.target_type
                    for _, field in ipairs({"starting_speed", "direction_deviation", "range_deviation", "max_range"}) do
                        if ur_delivery[field] ~= nil then
                            ammo_delivery[field] = ur_delivery[field]
                        end
                    end
                end
            end
        end
    end
end

--[[
local max_surveyor_range = 0
for name, spec in pairs(surveyor_guns) do
    max_surveyor_range = math.max(max_surveyor_range, restore_surveyor_gun(name, spec))
end

if max_surveyor_range > 0 then
    ensure_bullet_projectile_range(max_surveyor_range)
end
]]
