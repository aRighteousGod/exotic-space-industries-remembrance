local model = {}

--====================================================================================================
--MOD COMPATIBILITY
--====================================================================================================

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
            end
                --[[
                remote.call("DiscoScience", "setIngredientColor", "basic-tech-card", {r = 0.89, g = 0.43, b = 0.29})
                remote.call("DiscoScience", "setIngredientColor", "advanced-tech-card", {r = 1.0, g = 1.00, b = 0.53})
                remote.call("DiscoScience", "setIngredientColor", "singularity-tech-card", {r = 1.0, g = 0.02, b = 1.00})
                remote.call("DiscoScience", "setIngredientColor", "matter-tech-card", {r = 0.02, g = 0.90, b = 0.98})
                ]]
        end
    end
end


function model.nth_tick(e)

end

--====================================================================================================
--Mod Interfaces
--====================================================================================================

-- add more surface that accept gaia buildings
remote.add_interface("exotic-industries", {
    add_gaia_surface = function(surface_name)
        if not storage.gaia_surfaces then storage.gaia_surfaces = {} end
        storage.gaia_surfaces[surface_name] = true
    end,
    clear_gaia_surfaces = function()
        storage.gaia_surfaces = nil
    end
})

return model