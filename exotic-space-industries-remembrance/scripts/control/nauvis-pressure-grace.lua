local model = {}

local CHECK_INTERVAL = 18000
local PRE_STEAM_TARGET = 0.25
local PRE_ELECTRICITY_TARGET = 0.5
local MAX_REDUCTION_PER_PASS = 0.005

local function get_evolution_target()
    local player_force = game and game.forces and game.forces.player
    if not player_force then
        return nil
    end

    local technologies = player_force.technologies
    if not technologies then
        return nil
    end

    local electricity_age = technologies["ei-electricity-age"]
    if electricity_age and electricity_age.researched then
        storage.ei.nauvis_pressure.milestone_reached = true
        return nil
    end

    local steam_age = technologies["ei-steam-age"]
    if steam_age and steam_age.researched then
        return PRE_ELECTRICITY_TARGET
    end

    return PRE_STEAM_TARGET
end

function model.updater(event)
    if not event or not event.tick or event.tick % CHECK_INTERVAL ~= 0 then
        return
    end

    if storage.ei.nauvis_pressure.enabled == false or storage.ei.nauvis_pressure.milestone_reached == true then
        return
    end

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
