-- Init storage variables for Exotic Industries
ei_lib = require("lib/lib")
ei_echo_codex = require("lib/echo-codex")
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
    storage.ei["rocket_launch_pollution"] = {}
    storage.ei["rocket_launch_pollution"].mode = "linear"
    storage.ei["rocket_launch_pollution"].cap = 10000
    storage.ei["rocket_launch_pollution"].launch_smoke = {}
    storage.ei.fulgora_day_length_variation = {}
    --depreciated by NSB
    --storage.ei.spaced_updates = 0
    storage.ei.fluid_entity = {}
    storage.ei.fluid_entity_count = 0
    storage.ei.arrival_waves = {}
    storage.ei.alien = {}
    storage.ei.locomotives = {}
    storage.ei.campfire = {}
    ei_lib.crystal_echo("»» INITIALIZING SYSTEM CORE: ＥＸＯＴＩＣ ＳＰΛＣΣ ＩＮＤＵＳＴＲＩＥＳ ««","default-bold")
    ei_lib.crystal_echo(">> Integrating chronometric lattices... Binding entropy to mass... Stand by.","default-semibold")
end

function ei_global.check_init(event)
    -- TODO: dont hardcode this
    if not storage.ei then
	    storage.ei = {}
    end
    if not storage.ei.arrival_waves then
        storage.ei.arrival_waves = {}
    end
    if not storage.ei.campfire then
        storage.ei.campfire = {}
    end
    if not storage.ei.locomotives then
        storage.ei.locomotives = {}
    end
    if not storage.ei.rocket_launch_pollution then
        storage.ei.rocket_launch_pollution = {}
        storage.ei["rocket_launch_pollution"].mode = "linear"
        storage.ei["rocket_launch_pollution"].cap = 10000
    end
    if not storage.ei.rocket_launch_pollution.launch_smoke then
        storage.ei.rocket_launch_pollution.launch_smoke = {}
    end
    if not storage.ei.fulgora_day_length_variation then
        storage.ei.fulgora_day_length_variation = {}
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
    if storage.ei.gaia_reforged ~= nil then
        storage.ei.gaia_reforged = nil
    end
    if storage.ei.original_gaia_settings ~= nil then
        storage.ei.original_gaia_settings = nil
    end
    --powered beacons
    --depreciated by NSB
    --[[
    if not storage.ei.spaced_updates then
        storage.ei.spaced_updates = 0
    end
    ]]
    --powered beacon and etc fluid handlers
    if not storage.ei.fluid_entity then
        storage.ei.fluid_entity = {}
    end
    --int count of fluid handling entities
    if not storage.ei.fluid_entity_count then
        storage.ei.fluid_entity_count = 0

        --1.2.20 migration
        for _,surface in pairs(game.surfaces) do
            for _,entity in pairs(surface.find_entities()) do
                if entity and entity.valid and entity.force and ei_powered_beacon.counts_for_fluid_handling(entity) then
                    ei_register.register_fluid_entity(entity)
                end
            end
        end
    end

    if not storage.ei.alien then
        storage.ei.alien = {}
        storage.ei.alien.state = {}
    end

end

return ei_global
