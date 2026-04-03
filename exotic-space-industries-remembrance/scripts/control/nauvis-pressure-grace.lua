local model = {}

local CHECK_INTERVAL = 18000
local PRE_STEAM_TARGET = 0.25
local PRE_ELECTRICITY_TARGET = 0.5
local MAX_REDUCTION_PER_PASS = 0.005

local function get_evolution_target()
    if storage.ei.nauvis_pressure.milestone then
        if storage.ei.nauvis_pressure.milestone == 2 then
            return nil
        elseif storage.ei.nauvis_pressure.milestone == 1 then
            return PRE_ELECTRICITY_TARGET
        elseif storage.ei.nauvis_pressure.milestone == 0 then
             return PRE_STEAM_TARGET
        else
            log("Invalid milestone value for nauvis pressure grace: " .. tostring(storage.ei.nauvis_pressure.milestone))
            return nil
        end
    end
end

function model.on_configuration_changed(event)
    local player_force = game and game.forces and game.forces.player
    if not player_force then
         return
        end
    local technologies = player_force.technologies
    if not technologies then
        return
    end
    local electricity_age = technologies["ei-electricity-age"]
    local steam_age = technologies["ei-steam-age"]
    if electricity_age and electricity_age.researched then
        storage.ei.nauvis_pressure.milestone = 2
    elseif steam_age and steam_age.researched then
        storage.ei.nauvis_pressure.milestone = 1
    else
        storage.ei.nauvis_pressure.milestone = 0
    end
end

function model.on_research_finished(event)
    if storage.ei.nauvis_pressure.milestone == 2 then
        return
    end

    if not event or not event.research or not event.research.name then
         return
     end

     local research_name = event.research.name

     if research_name == "ei-steam-age" then
        storage.ei.nauvis_pressure.milestone = 1
     elseif research_name == "ei-electricity-age" then
        storage.ei.nauvis_pressure.milestone = 2
     end
end

function model.updater(event)
    if not event or not event.tick then
        return
    end

    if storage.ei.nauvis_pressure.enabled == false or storage.ei.nauvis_pressure.milestone == 2 then
        return
    end

    local last_run_tick = storage.ei.nauvis_pressure.last_run_tick or 0
    if event.tick - last_run_tick < CHECK_INTERVAL then
        return
    end

    storage.ei.nauvis_pressure.last_run_tick = event.tick

    local nauvis = game and game.surfaces and game.surfaces["nauvis"]
    local enemy_force = game and game.forces and game.forces.enemy
    if not nauvis or not enemy_force then
        return
    end

    local target = get_evolution_target()
    if not target then
        return
    end

    local current = enemy_force.get_evolution_factor(nauvis)
    if not current or current <= target then
        return
    end

    local next_evolution = current - math.min(current - target, MAX_REDUCTION_PER_PASS)
    enemy_force.set_evolution_factor(next_evolution, nauvis)
end

return model
