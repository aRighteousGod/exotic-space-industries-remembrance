--==============================================================================
-- ESIR FILE MAP
-- owns: compatibility init and configuration checks
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: init and configuration-changed
-- forwarded_events: check_init, nth_tick
-- storage_roots: storage.gaia_surfaces
-- gui_ids: none
-- remote_interfaces: exotic-industries
-- rebuild_on: mod changes
--==============================================================================
local model = {}

--====================================================================================================
--MOD COMPATIBILITY
--====================================================================================================

local function ensure_beacon_overload_state()
    storage.ei = storage.ei or {}
    storage.ei.beacon_overload = storage.ei.beacon_overload or {}
    storage.ei.beacon_overload.compat = storage.ei.beacon_overload.compat or {}

    local compat = storage.ei.beacon_overload.compat
    compat.machine_exclusions = compat.machine_exclusions or {}
    compat.beacon_exclusions = compat.beacon_exclusions or {}
    compat.beacon_weights = compat.beacon_weights or {}

    return compat
end

local function queue_beacon_overload_refresh()
    if ei_beacon_overload and ei_beacon_overload.refresh_tracked_overloads then
        ei_beacon_overload.refresh_tracked_overloads()
    elseif ei_beacon_overload and ei_beacon_overload.refresh_all_overloads then
        ei_beacon_overload.refresh_all_overloads()
    end
end

local function normalize_weight(weight)
    local numeric_weight = tonumber(weight)
    if not numeric_weight then
        return nil
    end

    numeric_weight = math.floor(numeric_weight)
    if numeric_weight < 1 then
        return nil
    end

    return numeric_weight
end

local function clear_table(table_value)
    for key in pairs(table_value) do
        table_value[key] = nil
    end
end

function model.check_init(event)
    -- K2
    ---------------------------------------------------------------------------
    if script.active_mods["krastorio2-spaced-out"] and remote.interfaces["kr-intergalactic-transceiver"] then
        remote.call("kr-intergalactic-transceiver", "set_no_victory", true)
    end
    -- DiscoScience
    if script.active_mods["DiscoScience"] then
        if remote.interfaces["DiscoScience"] then
            if remote.interfaces["DiscoScience"]["setLabScale"] then
                remote.call("DiscoScience", "setLabScale", "ei-dark-age-lab", 1)
            end
            if remote.interfaces["DiscoScience"]["setIngredientColor"] then
                remote.call("DiscoScience", "setIngredientColor", "ei-dark-age-tech", {r = 0.91, g = 0.16, b = 0.20})
                remote.call("DiscoScience", "setIngredientColor", "ei-steam-age-tech", {r = 0.29, g = 0.97, b = 0.31})
                remote.call("DiscoScience", "setIngredientColor", "ei-electricity-age-tech", {r = 0.28, g = 0.93, b = 0.95})
                remote.call("DiscoScience", "setIngredientColor", "ei-computer-age-tech", {r = 0.96, g = 0.93, b = 0.30})
                remote.call("DiscoScience", "setIngredientColor", "ei-advanced-computer-age-tech", {r = 0.0, g = 0.95, b = 0.58})
                remote.call("DiscoScience", "setIngredientColor", "ei-alien-computer-age-tech", {r = 0.95, g = 0.42, b = 0.45})
                remote.call("DiscoScience", "setIngredientColor", "ei-quantum-age-tech", {r = 1.0, g = 0.35, b = 0.95})
                remote.call("DiscoScience", "setIngredientColor", "ei-fusion-quantum-age-tech", {r = 1.0, g = 0.48, b = 0.07})
                remote.call("DiscoScience", "setIngredientColor", "ei-exotic-age-tech", {r = 0.81, g = 0.97, b = 0.0})
                remote.call("DiscoScience", "setIngredientColor", "ei-black-hole-exotic-age-tech", {r = 1.0, g = 0.70, b = 0.32})
                --[[
                if script.active_mods["krastorio2-spaced-out"] then
                    remote.call("DiscoScience", "setIngredientColor", "basic-tech-card", {r = 0.89, g = 0.43, b = 0.29})
                    remote.call("DiscoScience", "setIngredientColor", "advanced-tech-card", {r = 1.0, g = 1.00, b = 0.53})
                    remote.call("DiscoScience", "setIngredientColor", "singularity-tech-card", {r = 1.0, g = 0.02, b = 1.00})
                    remote.call("DiscoScience", "setIngredientColor", "matter-tech-card", {r = 0.02, g = 0.90, b = 0.98})
                end]]
            end
        end
    end
end


function model.nth_tick(e)

end

--====================================================================================================
--Mod Interfaces
--need to add something to allow additions to beacon overload exclusion list
--function model.counts_for_overload(entity) in /scripts/control/beacon_overload
--====================================================================================================

-- add more surface that accept gaia buildings
remote.add_interface("exotic-industries", {
    add_gaia_surface = function(surface_name)
        if not storage.gaia_surfaces then storage.gaia_surfaces = {} end
        storage.gaia_surfaces[surface_name] = true
    end,
    clear_gaia_surfaces = function()
        storage.gaia_surfaces = nil
    end,
    add_beacon_overload_machine_exclusion = function(entity_name)
        if type(entity_name) ~= "string" or entity_name == "" then
            return false
        end

        local compat = ensure_beacon_overload_state()
        compat.machine_exclusions[entity_name] = true
        queue_beacon_overload_refresh()
        return true
    end,
    add_beacon_overload_beacon_exclusion = function(entity_name)
        if type(entity_name) ~= "string" or entity_name == "" then
            return false
        end

        local compat = ensure_beacon_overload_state()
        compat.beacon_exclusions[entity_name] = true
        compat.beacon_weights[entity_name] = nil
        queue_beacon_overload_refresh()
        return true
    end,
    set_beacon_overload_beacon_weight = function(entity_name, weight)
        if type(entity_name) ~= "string" or entity_name == "" then
            return false
        end

        local normalized_weight = normalize_weight(weight)
        if not normalized_weight then
            return false
        end

        local compat = ensure_beacon_overload_state()
        compat.beacon_weights[entity_name] = normalized_weight
        compat.beacon_exclusions[entity_name] = nil
        queue_beacon_overload_refresh()
        return true
    end,
    clear_beacon_overload_overrides = function()
        local compat = ensure_beacon_overload_state()
        clear_table(compat.machine_exclusions)
        clear_table(compat.beacon_exclusions)
        clear_table(compat.beacon_weights)
        queue_beacon_overload_refresh()
        return true
    end
})

return model
