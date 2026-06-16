--==============================================================================
-- ESIR FILE MAP
-- owns: temporary Surveyor weapon chain hiding
-- loaded_by: exotic-space-industries-remembrance\data-final-fixes.lua
-- cadence: data-final-updates load
-- forwarded_events: none
-- storage_roots: none
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: data-final prototype reload
--==============================================================================

local surveyor_weapon_names = {
    "ei-surveyor-carbine",
    "ei-surveyor-rifle",
    "ei-surveyor-cannon",
    "ei-adaptive-surveyor",
}

for _, name in ipairs(surveyor_weapon_names) do
    local gun = data.raw.gun and data.raw.gun[name]
    if gun then
        gun.hidden = true
    end

    local recipe = data.raw.recipe and data.raw.recipe[name]
    if recipe then
        recipe.hidden = true
        recipe.enabled = false
    end

    local technology = data.raw.technology and data.raw.technology[name]
    if technology then
        technology.hidden = true
    end
end
