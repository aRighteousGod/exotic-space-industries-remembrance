local ei_lib = require("lib/lib")

local gaia_mapgen_data = require("scripts/control/gaia-mapgen-data")

local model = {}

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

    -- Check if surface is missing any required autoplace controls
    for control_name, _ in pairs(proper_controls) do
        if not current_settings.autoplace_controls or not current_settings.autoplace_controls[control_name] then
            needs_update = true
            break
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
                current_settings.autoplace_controls[control_name] = table.deepcopy(control_settings)
            end
        end

        -- Ensure autoplace_settings exists and has all required entities/decoratives
        if not current_settings.autoplace_settings then
            current_settings.autoplace_settings = table.deepcopy(proper_settings)
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
                        current_settings.autoplace_settings.entity.settings[entity_name] = table.deepcopy(entity_settings)
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
                        current_settings.autoplace_settings.decorative.settings[decorative_name] = table.deepcopy(decorative_settings)
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
        planet:associate_surface(legacy_surface)
        ei_lib.crystal_echo("Gaia surface rebound from legacy name")
        -- Migrate old surface to have new autoplace controls
        model.migrate_gaia_surface(legacy_surface)
        return legacy_surface
    end

    if planet.create_surface then
        local created = planet:create_surface()
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
        pcall(function()
            planet:associate_surface(created)
        end)
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

function model.reforge_gaia_surface(event)
    local planet = gaia_planet()
    if not planet then
        return nil
    end
    local surface = planet.surface
    local return_surface = safe_return_surface()
    if surface then
        -- Only teleport players who are actually on this surface
        for _, player in pairs(connected_players_on_surface(surface)) do
            if return_surface then
                player.teleport({0, 0}, return_surface)
                ei_lib.crystal_echo("Moving " .. player.name .. " off Gaia for recovery")
                if event and event.tick then
                    ei_lib.crystal_echo("Gaia recovery moved " .. player.name .. " to safety")
                end
            else
                ei_lib.crystal_echo("No safe surface found to move " .. player.name .. " during Gaia recovery")
                return nil
            end
        end

        for _, entity in pairs(surface.find_entities()) do
            if entity and entity.valid then
                pcall(function()
                    entity.destroy({raise_destroy = true})
                end)
            end
        end
    end

    -- Ensure the target gaia name is free from existing surface collisions before creating new surface
    if game.surfaces["gaia"] then
        game.delete_surface("gaia")
        ei_lib.crystal_echo("Gaia recovery removed old Gaia surface to clear way for rebuild, run command again to complete rebuild")
    elseif game.surfaces["Gaia"] then
        game.delete_surface("Gaia")
        ei_lib.crystal_echo("Gaia recovery removed old Gaia surface to clear way for rebuild, run command again to complete rebuild")
    else
        local map_gen_settings = gaia_mapgen_data.get_map_gen_settings()
        local rebuilt = game.create_surface("gaia", map_gen_settings)
        if rebuilt and rebuilt.valid and planet then
            -- associate the newly created surface with the planet
            pcall(function()
                planet:associate_surface(rebuilt)
            end)

            storage.gaia_surfaces = storage.gaia_surfaces or {}
            storage.gaia_surfaces["gaia"] = true
            storage.gaia_surfaces[rebuilt.name] = true

            -- Migrate old surface to have new autoplace controls
            ei_lib.crystal_echo("Gaia recovery rebuilt the surface with complete map-gen and planet association")
            return rebuilt
        end

        ei_lib.crystal_echo("Gaia recovery failed to recreate surface")
        return nil
    end
end

function model.reforge_on_tick(event)
    if storage.ei.reforge_gaia and event.tick >= storage.ei.reforge_gaia_tick then
        model.reforge_gaia_surface(event)
        storage.ei.reforge_gaia = nil
        storage.ei.reforge_gaia_tick = nil
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
