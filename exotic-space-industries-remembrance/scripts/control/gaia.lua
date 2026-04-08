local ei_lib = require("lib/lib")

local gaia_mapgen_data = require("scripts/control/gaia-mapgen-data")

local model = {}

local function copy_value(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, nested in pairs(value) do
        clone[copy_value(key)] = copy_value(nested)
    end
    return clone
end

--====================================================================================================
--GAIA
--====================================================================================================

-- buildings that will get destroyed on gaia
model.destroy_gaia = {
     ["offshore-pump"] = true,
}

-- buildings that will get destroyed on non gaia
model.destroy_non_gaia = {
    ["ei-gaia-pump"] = true,
}

-- buildings that will get swapped to gaia version
model.swap_gaia = {
    ["ei-crystal-accumulator"] = "ei-crystal-accumulator-gaia",
    ["offshore-pump"] = "ei-gaia-pump"
}


-- happens 10 times in total before the entity is destroyed
model.hour = 60 * 60 * 60

model.entity_damage_ticks = {
  
}

local function gaia_planet()
    return game.planets["gaia"] or nil
end

local function legacy_gaia_surface()
    local surface = game.surfaces and game.surfaces["Gaia"]
    if surface and surface.valid then
        return surface
    end
end

local function safe_return_surface()
    return game.surfaces["nauvis"] or game.default_surface
end

local function connected_players_on_surface(surface)
    local players = {}
    for _, player in pairs(game.connected_players) do
        if player.surface == surface then
            table.insert(players, player)
        end
    end
    return players
end

--====================================================================================================
--UTIL
--====================================================================================================

function model.entity_check(entity)

    if not storage.gaia_surfaces then 
      storage.gaia_surfaces = {}
      storage.gaia_surfaces["gaia"] = true
      storage.gaia_surfaces["Gaia"] = true
    end

    if entity == nil then
        return false
    end

    if not entity.valid then
        return false
    end

    return true
end

--====================================================================================================
--SURFACE MIGRATION (for old worlds missing new autoplace controls)
--====================================================================================================

function model.migrate_gaia_surface(surface)
    if not (surface and surface.valid) then
        return
    end

    local current_settings = surface.map_gen_settings
    if not current_settings then
        return
    end

    -- Get the complete, current autoplace controls and settings
    local proper_controls = gaia_mapgen_data.get_autoplace_controls()
    local proper_settings = gaia_mapgen_data.get_autoplace_settings()

    local needs_update = false
    local current_autoplace_settings = current_settings.autoplace_settings

    -- Check if surface is missing any required autoplace controls
    for control_name, _ in pairs(proper_controls) do
        if not current_settings.autoplace_controls or not current_settings.autoplace_controls[control_name] then
            needs_update = true
            break
        end
    end

    if not needs_update then
        local current_tile_settings = current_autoplace_settings and current_autoplace_settings.tile and current_autoplace_settings.tile.settings
        for tile_name, _ in pairs(proper_settings.tile.settings) do
            if not current_tile_settings or not current_tile_settings[tile_name] then
                needs_update = true
                break
            end
        end
    end

    if needs_update then
        -- Ensure autoplace_controls exists
        if not current_settings.autoplace_controls then
            current_settings.autoplace_controls = {}
        end

        -- Update/add all required autoplace controls
        for control_name, control_settings in pairs(proper_controls) do
                if not current_settings.autoplace_controls[control_name] then
                current_settings.autoplace_controls[control_name] = copy_value(control_settings)
            end
        end

        -- Ensure autoplace_settings exists and has all required entities/decoratives
        if not current_settings.autoplace_settings then
            current_settings.autoplace_settings = copy_value(proper_settings)
        else
            -- Merge in missing entity settings
            if proper_settings.entity then
                if not current_settings.autoplace_settings.entity then
                    current_settings.autoplace_settings.entity = {settings = {}}
                end
                if not current_settings.autoplace_settings.entity.settings then
                    current_settings.autoplace_settings.entity.settings = {}
                end
                for entity_name, entity_settings in pairs(proper_settings.entity.settings) do
                    if not current_settings.autoplace_settings.entity.settings[entity_name] then
                        current_settings.autoplace_settings.entity.settings[entity_name] = copy_value(entity_settings)
                    end
                end
            end

            -- Merge in missing decorative settings
            if proper_settings.decorative then
                if not current_settings.autoplace_settings.decorative then
                    current_settings.autoplace_settings.decorative = {settings = {}}
                end
                if not current_settings.autoplace_settings.decorative.settings then
                    current_settings.autoplace_settings.decorative.settings = {}
                end
                for decorative_name, decorative_settings in pairs(proper_settings.decorative.settings) do
                    if not current_settings.autoplace_settings.decorative.settings[decorative_name] then
                        current_settings.autoplace_settings.decorative.settings[decorative_name] = copy_value(decorative_settings)
                    end
                end
            end

            -- Merge in missing tile settings so runtime Gaia surfaces keep parity with
            -- the data-stage biome tile candidates.
            if proper_settings.tile then
                if not current_settings.autoplace_settings.tile then
                    current_settings.autoplace_settings.tile = {settings = {}}
                end
                if not current_settings.autoplace_settings.tile.settings then
                    current_settings.autoplace_settings.tile.settings = {}
                end
                for tile_name, tile_settings in pairs(proper_settings.tile.settings) do
                    if not current_settings.autoplace_settings.tile.settings[tile_name] then
                        current_settings.autoplace_settings.tile.settings[tile_name] = copy_value(tile_settings)
                    end
                end
            end
        end

        ei_lib.crystal_echo("✧ [Gaia Awakening] — Updated Gaia's autoplace controls to current version")
    end
end

function model.ensure_surface()
    local planet = gaia_planet()
    if not planet then
        return nil
    end

    local surface = planet.surface
    if surface and surface.valid then
        storage.gaia_surfaces = storage.gaia_surfaces or {}
        storage.gaia_surfaces[surface.name] = true
        -- Migrate old surface to have new autoplace controls
        model.migrate_gaia_surface(surface)
        return surface
    end

    local legacy_surface = legacy_gaia_surface()
    if legacy_surface then
        storage.gaia_surfaces = storage.gaia_surfaces or {}
        storage.gaia_surfaces[legacy_surface.name] = true
        storage.gaia_surfaces["gaia"] = true
        planet.associate_surface(legacy_surface)
        ei_lib.crystal_echo("Gaia surface rebound from legacy name")
        -- Migrate old surface to have new autoplace controls
        model.migrate_gaia_surface(legacy_surface)
        return legacy_surface
    end

    if planet.create_surface then
        local created = planet.create_surface()
        if created and created.valid then
            storage.gaia_surfaces = storage.gaia_surfaces or {}
            storage.gaia_surfaces[created.name] = true
            storage.gaia_surfaces["gaia"] = true
            ei_lib.crystal_echo("Gaia surface created")
            return created
        end
    end

    -- Future-proof: create surface manually from map-gen data and associate
    local map_gen_settings = gaia_mapgen_data.get_map_gen_settings()
    local created = game.create_surface("gaia", map_gen_settings)
    if created and created.valid then
        planet.associate_surface(created)
        storage.gaia_surfaces = storage.gaia_surfaces or {}
        storage.gaia_surfaces[created.name] = true
        storage.gaia_surfaces["gaia"] = true
        ei_lib.crystal_echo("Gaia surface created (manual create_surface + planet association)")
        return created
    end

    return nil
end

function model.create_gaia()
    return model.ensure_surface()
end

local reforge_staging_surface_name = "gaia-reforge-staging"
local reforge_phase_timeout_ticks = 60 * 60
local reforge_phase_retry_notice_interval = 10 * 60
local reforge_phase_status = {
    migrate_legacy = "resolving any legacy Gaia surface before the rebuild.",
    check_intact = "checking whether Gaia already matches the intended terrain and still bears resources.",
    evacuate = "moving players off Gaia before the rebuild continues.",
    purge = "clearing the old Gaia shell of remaining entities.",
    stage_surface = "preparing a staged Gaia surface from the current map generation pattern.",
    queue_delete = "queueing the old Gaia shell for deletion.",
    wait_for_release = "waiting for the old planetary bond to dissolve.",
    rename_and_bind = "taking the canonical gaia name and binding the staged surface to the planet.",
    verify = "verifying the staged surface is now Gaia's canonical planet surface.",
}
local fail_reforge

local function update_gaia_surface_registry(surface_name, enabled)
    storage.gaia_surfaces = storage.gaia_surfaces or {}
    if enabled then
        storage.gaia_surfaces[surface_name] = true
    else
        storage.gaia_surfaces[surface_name] = nil
    end
end

local function reforge_status_text(phase)
    return reforge_phase_status[phase] or "rebuilding Gaia."
end

local function report_reforge_status(state)
    if not state then
        return
    end

    ei_lib.crystal_echo("◌ [Reforge Status] — Gaia reforge is " .. reforge_status_text(state.phase))
end

local function current_reforge_tick(event)
    return event and event.tick or game.tick
end

local function set_reforge_phase(state, phase, event)
    if not state then
        return
    end

    state.phase = phase
    state.phase_started_tick = current_reforge_tick(event)
    state.phase_last_retry_notice_tick = nil
end

local function retry_or_fail_reforge_phase(state, event, wait_message, fail_message)
    local tick = current_reforge_tick(event)
    local phase_started_tick = state.phase_started_tick or state.started_tick or tick

    if tick - phase_started_tick >= reforge_phase_timeout_ticks then
        fail_reforge(state, fail_message)
        return false
    end

    if wait_message then
        local last_notice_tick = state.phase_last_retry_notice_tick or 0
        if state.phase_last_retry_notice_tick == nil or tick - last_notice_tick >= reforge_phase_retry_notice_interval then
            ei_lib.crystal_echo(wait_message)
            state.phase_last_retry_notice_tick = tick
        end
    end

    return true
end

local function checksum(tbl)
    local serialized = serpent.block(tbl, {sortkeys = true, numformat = "%0.8f"})
    local sum = 0

    for i = 1, #serialized do
        sum = (sum + serialized:byte(i)) % 2147483647
    end

    return sum
end

local function surface_contains_any_resources(surface)
    if not (surface and surface.valid) then
        return false, nil, 0
    end

    local resources = surface.find_entities_filtered({type = "resource"})
    if not resources or #resources == 0 then
        return false, nil, 0
    end

    return true, resources[1].name, #resources
end

local function gaia_map_settings_match(surface)
    if not (surface and surface.valid) then
        return false
    end

    local desired_settings = gaia_mapgen_data.get_map_gen_settings()
    local ok_current, current_checksum = pcall(checksum, surface.map_gen_settings)
    local ok_desired, desired_checksum = pcall(checksum, desired_settings)

    return ok_current and ok_desired and current_checksum == desired_checksum
end

local function resolve_reforge_safe_surface(state)
    if state and state.safe_surface_name then
        local safe_surface = game.get_surface(state.safe_surface_name)
        if safe_surface and safe_surface.valid then
            return safe_surface
        end
    end

    return safe_return_surface()
end

local function resolve_reforge_source_surface(state, planet)
    if planet and planet.surface and planet.surface.valid and planet.surface.name ~= state.staging_surface_name then
        return planet.surface
    end

    local canonical_surface = game.surfaces and game.surfaces[state.result_surface_name]
    if canonical_surface and canonical_surface.valid and canonical_surface.name ~= state.staging_surface_name then
        return canonical_surface
    end

    local legacy_surface = legacy_gaia_surface()
    if legacy_surface and legacy_surface.name ~= state.staging_surface_name then
        return legacy_surface
    end
end

fail_reforge = function(state, message)
    if message then
        ei_lib.crystal_echo(message)
    end

    if state and state.staging_surface_name then
        update_gaia_surface_registry(state.staging_surface_name, false)
    end

    storage.ei.reforge_gaia = nil
    return nil
end

local function complete_reforge(state, surface)
    if not (state and surface and surface.valid) then
        return nil
    end

    update_gaia_surface_registry(state.staging_surface_name, false)
    update_gaia_surface_registry("Gaia", false)
    update_gaia_surface_registry(surface.name, true)
    update_gaia_surface_registry("gaia", true)

    if state.teleport_when_done and state.request_player_index then
        local player = game.get_player(state.request_player_index)
        if player and player.valid then
            player.teleport({0, 0}, surface)
        end
    end

    storage.ei.reforge_gaia = nil
    return surface
end

function model.reforge_gaia_surface(event)
    local planet = gaia_planet()
    if not planet then
        ei_lib.crystal_echo("☠ [Void's Echo] — Gaia's name lies unwritten; the rite dissolves into silent void.")
        return nil
    end

    storage.ei = storage.ei or {}

    if storage.ei.reforge_gaia then
        report_reforge_status(storage.ei.reforge_gaia)
        return nil
    end

    local safe_surface = safe_return_surface()
    if not safe_surface then
        ei_lib.crystal_echo("☠ [Invocation Fracture] — No safe return surface exists for Gaia's evacuees.")
        return nil
    end

    storage.ei.reforge_gaia = {
        phase = "migrate_legacy",
        started_tick = current_reforge_tick(event),
        phase_started_tick = current_reforge_tick(event),
        request_player_index = event and event.player_index or nil,
        teleport_when_done = not not (event and event.player_index),
        safe_surface_name = safe_surface.name,
        staging_surface_name = reforge_staging_surface_name,
        result_surface_name = "gaia",
    }

    report_reforge_status(storage.ei.reforge_gaia)
    model.reforge_on_tick(event or {tick = game.tick})
    return nil
end

function model.reforge_on_tick(event)
    if not (storage.ei and storage.ei.reforge_gaia) then
        return
    end

    local state = storage.ei.reforge_gaia
    local planet = gaia_planet()
    if not planet then
        retry_or_fail_reforge_phase(
            state,
            event,
            "◌ [Stillness] — Gaia's planetary record cannot yet be reached. The rite keeps searching for the bond.",
            "☠ [Void's Echo] — Gaia vanished from the planet registry during reforging."
        )
        return
    end

    if state.phase == "migrate_legacy" then
        local legacy_surface = legacy_gaia_surface()
        if legacy_surface and not (planet.surface and planet.surface.valid) then
            planet.associate_surface(legacy_surface)
            update_gaia_surface_registry(legacy_surface.name, true)
            update_gaia_surface_registry("gaia", true)
            ei_lib.crystal_echo("☲ [Ghost Reclaimed] — Legacy Gaia has been rebound to the canonical gaia planet.")
        end

        set_reforge_phase(state, "check_intact", event)
        return
    end

    if state.phase == "check_intact" then
        local current_surface = planet.surface
        if current_surface and current_surface.valid and current_surface.name == state.result_surface_name then
            if gaia_map_settings_match(current_surface) then
                local has_resources, resource_name, resource_count = surface_contains_any_resources(current_surface)
                if has_resources then
                    ei_lib.crystal_echo("✔ [Echo Intact] — " .. resource_name .. " crystals endure (" .. resource_count .. "). Gaia stands.")
                    complete_reforge(state, current_surface)
                    return
                end
            end
        end

        set_reforge_phase(state, "evacuate", event)
        return
    end

    if state.phase == "evacuate" then
        local source_surface = resolve_reforge_source_surface(state, planet)
        if source_surface then
            local safe_surface = resolve_reforge_safe_surface(state)
            if not safe_surface then
                retry_or_fail_reforge_phase(
                    state,
                    event,
                    "◌ [Stillness] — Gaia's evacuees still have no safe refuge. The rite will keep searching.",
                    "☠ [Invocation Fracture] — No safe surface remains for Gaia's evacuees."
                )
                return
            end

            for _, player in pairs(connected_players_on_surface(source_surface)) do
                ei_lib.crystal_echo("⚠ [Displacement] — Moving " .. player.name .. " to safety while Gaia is reforged.")
                player.teleport({0, 0}, safe_surface)
                if event and event.tick then
                    ei_echo_codex.youHaveArrived({player_index = player.index, tick = event.tick})
                end
            end
        end

        set_reforge_phase(state, "purge", event)
        return
    end

    if state.phase == "purge" then
        local source_surface = resolve_reforge_source_surface(state, planet)
        if source_surface then
            for _, entity in pairs(source_surface.find_entities()) do
                if entity and entity.valid then
                    pcall(function()
                        entity.destroy({raise_destroy = true})
                    end)
                end
            end
        end

        set_reforge_phase(state, "stage_surface", event)
        return
    end

    if state.phase == "stage_surface" then
        local staging_surface = game.surfaces[state.staging_surface_name]
        if staging_surface and staging_surface.valid then
            if staging_surface.planet then
                retry_or_fail_reforge_phase(
                    state,
                    event,
                    "◌ [Stillness] — Gaia's staging shell is still bound elsewhere. The rite is waiting for it to release.",
                    "☠ [Invocation Fracture] — Gaia's staging surface is already planet-bound and cannot be safely reused."
                )
                return
            end

            if not state.staging_cleanup_requested then
                game.delete_surface(staging_surface)
                state.staging_cleanup_requested = true
                return
            end

            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's old staging shell is still fading. The rite is waiting for the surface to clear.",
                "☠ [Invocation Fracture] — Gaia's old staging surface did not clear in time for a fresh rebuild."
            )
            return
        end

        state.staging_cleanup_requested = nil

        local map_gen_settings = gaia_mapgen_data.get_map_gen_settings()
        local created_surface = game.create_surface(state.staging_surface_name, map_gen_settings)
        if not (created_surface and created_surface.valid) then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's staged shell has not formed yet. The rite is still shaping it from the map generation table.",
                "☠ [Invocation Fracture] — Failed to shape Gaia's staged surface from the map generation table."
            )
            return
        end

        update_gaia_surface_registry(created_surface.name, true)
        ei_lib.crystal_echo("✖ [Silence] — Gaia's old shell has been cleared. A new shell is being prepared.")
        set_reforge_phase(state, "queue_delete", event)
        return
    end

    if state.phase == "queue_delete" then
        if not state.delete_requested then
            local canonical_surface = game.surfaces[state.result_surface_name]
            if canonical_surface and canonical_surface.valid and canonical_surface.name ~= state.staging_surface_name then
                game.delete_surface(canonical_surface)
            end

            local legacy_surface = legacy_gaia_surface()
            if legacy_surface and legacy_surface.valid and legacy_surface.name ~= state.staging_surface_name then
                game.delete_surface(legacy_surface)
            end

            state.delete_requested = true
            ei_lib.crystal_echo("◌ [Stillness] — The new Gaia waits while the old planetary bond dissolves.")
        end

        set_reforge_phase(state, "wait_for_release", event)
        return
    end

    if state.phase == "wait_for_release" then
        local canonical_surface = game.surfaces[state.result_surface_name]
        local legacy_surface = legacy_gaia_surface()
        local canonical_planet_surface = planet.surface

        if canonical_surface and canonical_surface.valid then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's old canonical surface still clings to the void. The rite remains patient.",
                "☠ [Invocation Fracture] — Gaia's old canonical surface did not release within one minute."
            )
            return
        end

        if legacy_surface and legacy_surface.valid and legacy_surface.name ~= state.staging_surface_name then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's legacy shell still lingers. The rite remains patient.",
                "☠ [Invocation Fracture] — Gaia's legacy shell did not release within one minute."
            )
            return
        end

        if canonical_planet_surface and canonical_planet_surface.valid and canonical_planet_surface.name ~= state.staging_surface_name then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's old planetary bond has not dissolved yet. The rite remains patient.",
                "☠ [Invocation Fracture] — Gaia's old planetary bond did not dissolve within one minute."
            )
            return
        end

        set_reforge_phase(state, "rename_and_bind", event)
        return
    end

    if state.phase == "rename_and_bind" then
        local staging_surface = game.surfaces[state.staging_surface_name]
        if not (staging_surface and staging_surface.valid) then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's staged shell cannot yet be reached. The rite keeps seeking it.",
                "☠ [Invocation Fracture] — Gaia's staged surface vanished before the canonical bond could be restored."
            )
            return
        end

        local ok_rename, rename_err = pcall(function()
            staging_surface.name = state.result_surface_name
        end)
        if not ok_rename then
            log("[Gaia Reforge] Staging surface rename failed: " .. tostring(rename_err))
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's staged shell has not yet taken the canonical gaia name. The rite will keep trying.",
                "☠ [Invocation Fracture] — Gaia's staged surface could not take the canonical gaia name."
            )
            return
        end

        planet.associate_surface(staging_surface)

        set_reforge_phase(state, "verify", event)
        return
    end

    if state.phase == "verify" then
        local rebuilt_surface = game.surfaces[state.result_surface_name]
        if not (rebuilt_surface and rebuilt_surface.valid) then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's renamed shell is not yet stable enough to verify. The rite keeps watching.",
                "☠ [Invocation Fracture] — Gaia's renamed surface is missing during final verification."
            )
            return
        end

        if planet.surface ~= rebuilt_surface then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's shell exists, but the planet still points elsewhere. The rite keeps testing the bond.",
                "☠ [Invocation Fracture] — Gaia's staged surface exists, but the canonical planet still points elsewhere."
            )
            return
        end

        if not rebuilt_surface.planet or rebuilt_surface.planet.name ~= state.result_surface_name then
            retry_or_fail_reforge_phase(
                state,
                event,
                "◌ [Stillness] — Gaia's shell exists, but the final planetary signature is not yet stable. The rite keeps watching.",
                "☠ [Invocation Fracture] — Gaia's staged surface exists, but canonical binding verification failed."
            )
            return
        end

        model.migrate_gaia_surface(rebuilt_surface)
        ei_lib.crystal_echo("✧ [Resurrection] — Gaia's new surface has taken the canonical name and the planet bond is restored.")
        complete_reforge(state, rebuilt_surface)
        return
    end
end

--ENTITY LIFETIMES AND REGISTER
------------------------------------------------------------------------------------------------------

function model.register_entity(entity, overload, event)

    overload = overload or false

    if not model.entity_check(entity) then
        return
    end

    -- this a player built entity?
    if not entity.last_user then
        if not overload then
            return
        end
    end

    if not storage.ei.damage_ticks then
        storage.ei.damage_ticks = {}
    end

    if not model.entity_damage_ticks[entity.name] then
        return
    end

    -- register the entity for lifetime
    table.insert(storage.ei.damage_ticks, {
        ["entity"] = entity,
        ["update_tick"] = event.tick + model.entity_damage_ticks[entity.name],
        ["damage"] = 90
    })

end


function model.update_entity_lifetimes(event)

    if not storage.ei.damage_ticks then
        return
    end

    local damage_ticks = storage.ei.damage_ticks
    local new_update = {}

    -- apply damage to entities that are registered
    for i,v in ipairs(damage_ticks) do
       local entity = v.entity
       local update_tick = v.update_tick
       local damage = v.damage
        
        if not model.entity_check(entity) then
            goto continue
        end

        if update_tick > event.tick then
            goto continue
        end

        -- apply damage
        if damage > 10 then
            damage = damage - 10
            
            rendering.draw_text{
                text = tostring(damage).."%",
                surface = entity.surface,
                target = entity,
                color = {r=0, g=0.86, b=0.1},
                scale = 1.25,
                target_offset = {0, 0.5},
                alignment = "center",
                scale_with_zoom = false,
                time_to_live = model.entity_damage_ticks[entity.name]+1,
            }
        else
            model.degrade_building(entity)
            goto continue
        end
        

        table.insert(new_update, {
            ["entity"] = entity,
            ["update_tick"] = event.tick + model.entity_damage_ticks[entity.name],
            ["damage"] = damage
        })

        ::continue::

    end

    -- add new entities to the update list
    for i,v in ipairs(new_update) do
        table.insert(damage_ticks, v)
    end
    
    -- remove old entities from the update list
    while true do
        if not model.remove_search_tick(storage.ei.damage_ticks, event.tick) then
            break
        end
    end

end


function model.remove_search_tick(foo, tick)

    for i,v in ipairs(foo) do
        if v.update_tick == tick then
            table.remove(foo, i)
            return true
        end
    end

    return false

end


function model.degrade_building(entity)

    -- if there is an unrepaired version of this building then create it
    -- destroy original building

    if not model.entity_check(entity) then
        return
    end

    -- check if this entity is in ei_data.repair_tools
    for i,v in pairs(ei_data.repair_tools) do
        if v.result == entity.name then
            local new_entity,_ = next(v.targets)
            entity.surface.create_entity({
                name = new_entity,
                position = entity.position,
                force = entity.force,
                direction = entity.direction,
                create_build_effect_smoke = false,
                raise_built = false,
            })
            break
        end
    end

    -- also print warning
    game.print({"exotic-industries.building-degraded", entity.name, entity.position.x, entity.position.y})

    entity.destroy()

end

--GAIA RELATED ENTITY SWAPS
------------------------------------------------------------------------------------------------------

function model.swap_entity(entity)
    -- swap an entity to its gaia version if placed on gaia

    if not model.entity_check(entity) then return end

    if not storage.gaia_surfaces[entity.surface.name] then return end
    if not model.swap_gaia[entity.name] then return end

    local swap_entity = entity.surface.create_entity({
        name = model.swap_gaia[entity.name],
        position = entity.position,
        force = entity.force,
        direction = entity.direction,
        create_build_effect_smoke = false,
        raise_built = false,
    })

    entity.destroy()

end

--NON GAIA BUILDING DESTRUCTION
------------------------------------------------------------------------------------------------------

function model.create_drop(entity)

    if not model.entity_check(entity) then return end

    -- create an item drop of this entity at its pos
    -- that is marked for deconstruction

    local surface = entity.surface
    local pos = entity.position
    local drop_name = entity.name -- only works if item name is the same as entity name

    -- create the drop
    local drop = surface.create_entity({
        name = "item-on-ground",
        position = pos,
        stack = {name = drop_name, count = 1}
    })

    -- mark the drop for deconstruction
    drop.order_deconstruction(entity.force)

end


function model.destroy_building(entity)

    local destroy_gaia = model.destroy_gaia
    local destroy_non_gaia = model.destroy_non_gaia
    local surface = entity.surface

    if destroy_gaia[entity.name] then

        if storage.gaia_surfaces[surface.name] then

            -- game.print(serpent.block(storage.gaia_surfaces))
            -- create flying text
            rendering.draw_text{
                target = entity.position,
                text = "Can't build on Gaia!",
                color = {r=1, g=0, b=0},
                surface = entity.surface,
                scale = 1,
                time_to_live = 120
            }
            model.create_drop(entity)

            entity.destroy()
            return
        end

    end

    if destroy_non_gaia[entity.name] then

        if not storage.gaia_surfaces[surface.name] then

            -- game.print(serpent.block(storage.gaia_surfaces))
            -- create flying text
            rendering.draw_text{
                target = entity.position,
                text = "Can only be built on Gaia!",
                color = {r=1, g=0, b=0},
                surface = entity.surface,
                scale = 1,
                time_to_live = 120
            }
            model.create_drop(entity)

            entity.destroy()
            return
        end

    end
end

--DEV COMMANDS
------------------------------------------------------------------------------------------------------

-- give the player the spawner tool, when creating a new player
function model.spawn_command(event)

    if not event.player_index then
        return
    end

    local player = game.get_player(event.player_index)
    if not player then
        return
    end
    
    if event.command == "gaia" then
        game.print("Spawning Gaia")

        local surface = model.create_gaia()
        if surface then
            player.teleport({0, 0}, surface)
        end
    end
    
end


--====================================================================================================
--HANDLERS
--====================================================================================================

function model.on_built_entity(event)
    local entity = event.entity
    if model.entity_check(entity) == false then
        return
    end

    model.destroy_building(entity)
    model.swap_entity(entity)
    model.register_entity(entity,event)

end


function model.update(event)

    model.update_entity_lifetimes(event)

end


return model
