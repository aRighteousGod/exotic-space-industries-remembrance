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
