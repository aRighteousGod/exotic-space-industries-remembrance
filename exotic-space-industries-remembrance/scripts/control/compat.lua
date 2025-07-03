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