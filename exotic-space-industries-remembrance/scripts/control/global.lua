-- Init storage variables for Exotic Industries
ei_lib = require("lib/lib")
ei_echo_codex = require("lib/echo_codex")
local ei_global = {}


--====================================================================================================
--GLOBAL VARIABLES
--====================================================================================================

function ei_global.init()
    storage.ei = {}

    storage.ei["tech_scaling"] = {}
    storage.ei["tech_scaling"].maxCost = 0
    storage.ei["tech_scaling"].startPrice = 0
    storage.ei["tech_scaling"].techCount = 0

    storage.ei["overload_icons"] = {}
    storage.ei["neutron_collector_animation"] = {}
    storage.ei["neutron_sources"] = {}
    storage.ei["spawner_queue"] = {}
    storage.ei["orbital_combinators"] = {}
    storage.ei.spaced_updates = 0
    storage.ei.arrival_waves = {}
    storage.ei.alien = {}
    storage.ei.locomotives = {}
    
    storage.ei.gaia_reforged = 0    --Leaving room for planetary evolution down the road
    ei_lib.crystal_echo("»» INITIALIZING SYSTEM CORE: ＥＸＯＴＩＣ ＳＰΛＣΣ ＩＮＤＵＳＴＲＩＥＳ ««","default-bold")
    ei_lib.crystal_echo(">> Integrating chronometric lattices... Binding entropy to mass... Stand by.","default-semibold")
end

function ei_global.check_init()
    -- TODO: dont hardcode this
    if not storage.ei then
	    storage.ei = {}
    end
    if not storage.ei.arrival_waves then
        storage.ei.arrival_waves = {}
    end
    if not storage.ei.original_gaia_settings then
        storage.ei.original_gaia_settings = full_gaia_map_gen_settings
    end
    if not storage.ei.gaia_reforged_version then
        storage.ei.gaia_reforged = 0    --Leaving room for planetary evolution down the road
    end
    if not storage.ei.locomotives then
        storage.ei.locomotives = {}
    end
    if not storage.ei["tech_scaling"] then
        storage.ei["tech_scaling"] = {}
    end

    if not storage.ei["tech_scaling"].maxCost then
        storage.ei["tech_scaling"].maxCost = 0
    end

    if not storage.ei["tech_scaling"].startPrice then
        storage.ei["tech_scaling"].startPrice = 0
    end

    if not storage.ei["tech_scaling"].techCount then
        storage.ei["tech_scaling"].techCount = 0
    end

    if not storage.ei["overload_icons"] then
        storage.ei["overload_icons"] = {}
    end

    if not storage.ei["neutron_collector_animation"] then
        storage.ei["neutron_collector_animation"] = {}
    end

    if not storage.ei["neutron_sources"] then
        storage.ei["neutron_sources"] = {}
    end

    if not storage.ei["spawner_queue"] then
        storage.ei["spawner_queue"] = {}
    end

    if not storage.ei["orbital_combinators"] then
        storage.ei["orbital_combinators"] = {}
    end

    if not storage.ei.spaced_updates then
        storage.ei.spaced_updates = 0
    end

    if not storage.ei.alien then
        storage.ei.alien = {}
        storage.ei.alien.state = {}
    end

end

return ei_global