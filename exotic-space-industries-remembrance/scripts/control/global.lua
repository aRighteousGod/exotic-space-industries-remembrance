-- Init storage variables for Exotic Industries
ei_lib = require("lib/lib")
ei_echo_codex = require("lib/echo-codex")
local ei_global = {}

local function new_steam_train_runtime()
    -- Steam trains maintain a full tracked set plus a smaller active queue for frequent wheel updates.
    return {
        locomotives_by_unit = {},
        tracked_units = {},
        tracked_index_by_unit = {},
        active_units = {},
        active_index_by_unit = {},
        audit_cursor = 1
    }
end


--====================================================================================================
--GLOBAL VARIABLES
--====================================================================================================

function ei_global.init()
    storage.ei = {}

    storage.ei["tech_scaling"] = {}
    storage.ei["tech_scaling"].maxCost = 0
    storage.ei["tech_scaling"].startPrice = 0
    storage.ei["tech_scaling"].baseStartPrice = 0
    storage.ei["tech_scaling"].techCount = 0

    storage.ei["overload_icons"] = {}
    storage.ei["neutron_collector_animation"] = {}
    storage.ei.neutron_runtime = {}
    storage.ei["spawner_queue"] = {}
    storage.ei["orbital_combinators"] = {}
    storage.ei.orbital_combinator_banks = {}
    storage.ei.orbital_combinator_bank_by_unit = {}
    storage.ei.orbital_combinator_bank_count = 0
    storage.ei.orbital_combinator_platform_cache = {}
    storage.ei.orbital_combinator_platform_by_hub = {}
    storage.ei.orbital_combinator_platform_reconcile_tick = 0
    storage.ei["rocket_launch_pollution"] = {}
    storage.ei["rocket_launch_pollution"].mode = "linear"
    storage.ei["rocket_launch_pollution"].cap = 10000
    storage.ei["rocket_launch_pollution"].launch_smoke = {}
    storage.ei.fulgora_day_length_variation = {}
    storage.ei.enemy_difficulty = "Tempered"
    storage.ei.nauvis_pressure = {}
    storage.ei.nauvis_pressure.milestone = 0
    storage.ei.nauvis_pressure.last_run_tick = 0
    --depreciated by NSB
    --storage.ei.spaced_updates = 0
    storage.ei.fluid_entity = {}
    storage.ei.fluid_entity_count = 0
    storage.ei.arrival_waves = {}
    storage.ei.alien = {}
    -- Initialize the indexed steam train runtime shape up front so new saves and migrated saves agree.
    storage.ei.locomotives = new_steam_train_runtime()
    storage.ei.campfire = {}
    storage.ei.campfire_last_run_tick = 0
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
    if not storage.ei.campfire_last_run_tick then
        storage.ei.campfire_last_run_tick = 0
    end
    -- Older saves may still carry the legacy locomotive array, so rebuild the container if the
    -- indexed fields are missing.
    if not storage.ei.locomotives or not storage.ei.locomotives.locomotives_by_unit then
        storage.ei.locomotives = new_steam_train_runtime()
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
    if not storage.ei.enemy_difficulty then
        storage.ei.enemy_difficulty = "Tempered"
    end
    if not storage.ei.nauvis_pressure then
        storage.ei.nauvis_pressure = {}
        storage.ei.nauvis_pressure.milestone = 0
    end
    if not storage.ei.nauvis_pressure.last_run_tick then
        storage.ei.nauvis_pressure.last_run_tick = 0
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

    if not storage.ei["tech_scaling"].baseStartPrice then
        storage.ei["tech_scaling"].baseStartPrice = 0
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

    if not storage.ei.neutron_runtime then
        storage.ei.neutron_runtime = {}
    end

    if not storage.ei["spawner_queue"] then
        storage.ei["spawner_queue"] = {}
    end

    if not storage.ei["orbital_combinators"] then
        storage.ei["orbital_combinators"] = {}
    end
    if not storage.ei.orbital_combinator_banks then
        storage.ei.orbital_combinator_banks = {}
    end
    if not storage.ei.orbital_combinator_bank_by_unit then
        storage.ei.orbital_combinator_bank_by_unit = {}
    end
    if storage.ei.orbital_combinator_bank_count == nil then
        storage.ei.orbital_combinator_bank_count = 0
    end
    if not storage.ei.orbital_combinator_platform_cache then
        storage.ei.orbital_combinator_platform_cache = {}
    end
    if not storage.ei.orbital_combinator_platform_by_hub then
        storage.ei.orbital_combinator_platform_by_hub = {}
    end
    if storage.ei.orbital_combinator_platform_reconcile_tick == nil then
        storage.ei.orbital_combinator_platform_reconcile_tick = 0
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
