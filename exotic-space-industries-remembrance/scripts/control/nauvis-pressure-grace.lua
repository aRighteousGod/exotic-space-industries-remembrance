--==============================================================================
-- ESIR FILE MAP
-- owns: Nauvis pressure grace milestone and pollution/evolution pressure
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: configuration changes, research-finished, and scheduled tick step 1
-- forwarded_events: has_tick_work, on_configuration_changed, on_research_finished, on_scripted_research_burst, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup settings, research progression, configuration changes
--==============================================================================
local ei_lib = require("lib/lib")
local model = {}

local CHECK_INTERVAL = 18000
local PROFILE_CLASSIC = "Classic"
local PROFILE_EXTENDED = "Extended"
local PHASE_INACTIVE = "inactive"
local POLLUTION_FACTOR_EPSILON = 0.000000000001

local ELECTRIC_DEFENSE_TECHS = {
    "ei-sawblade-turret",
    "ei-gatling-turret",
    "ei-auto-shotgun-turret",
    "ei-cannon-turret",
    "laser-turret",
}

---@class NauvisPressureGracePolicy
---@field key string
---@field milestone integer
---@field evolution_target number|nil
---@field max_reduction number|nil
---@field pollution_factor_multiplier number|nil

---@type table<string, NauvisPressureGracePolicy>
local PHASE_POLICIES = {
    pre_steam = {
        key = "pre_steam",
        milestone = 0,
        evolution_target = 0.25,
        max_reduction = 0.005,
    },
    steam_to_electricity = {
        key = "steam_to_electricity",
        milestone = 1,
        evolution_target = 0.45,
        max_reduction = 0.005,
    },
    electricity_pre_power = {
        key = "electricity_pre_power",
        milestone = 2,
        evolution_target = 0.50,
        max_reduction = 0.003,
        pollution_factor_multiplier = 0.70,
    },
    electricity_pre_defense = {
        key = "electricity_pre_defense",
        milestone = 2,
        evolution_target = 0.55,
        max_reduction = 0.002,
        pollution_factor_multiplier = 0.80,
    },
    electricity_pre_computer = {
        key = "electricity_pre_computer",
        milestone = 2,
        evolution_target = 0.60,
        max_reduction = 0.001,
        pollution_factor_multiplier = 0.90,
    },
    inactive = {
        key = PHASE_INACTIVE,
        milestone = 3,
    },
}

local function ensure_state()
    storage.ei = storage.ei or {}
    storage.ei.nauvis_pressure = storage.ei.nauvis_pressure or {}

    local state = storage.ei.nauvis_pressure
    if state.last_run_tick == nil then
        state.last_run_tick = 0
    end
    if state.profile ~= PROFILE_CLASSIC and state.profile ~= PROFILE_EXTENDED then
        state.profile = PROFILE_EXTENDED
    end
    if state.enabled == nil then
        state.enabled = true
    end

    return state
end

local function get_player_force()
    return game and game.forces and game.forces.player or nil
end

local function is_player_force(force)
    local player_force = get_player_force()
    return force and player_force and force.index == player_force.index
end

local function force_has_researched(force, technology_name)
    if not force or not force.valid or not force.technologies then
        return false
    end

    local technology = force.technologies[technology_name]
    return technology and technology.researched == true
end

local function force_has_electric_defense(force)
    for _, technology_name in ipairs(ELECTRIC_DEFENSE_TECHS) do
        if force_has_researched(force, technology_name) then
            return true
        end
    end

    return false
end

local function get_pollution_factor()
    local enemy_evolution = game
        and game.map_settings
        and game.map_settings.enemy_evolution
        or nil

    if not enemy_evolution then
        return nil
    end

    local pollution_factor = tonumber(enemy_evolution.pollution_factor)
    if not ei_lib.is_valid_number(pollution_factor) then
        return nil
    end

    return pollution_factor
end

local function set_pollution_factor(pollution_factor)
    if not ei_lib.is_valid_number(pollution_factor) then
        return false
    end

    local enemy_evolution = game
        and game.map_settings
        and game.map_settings.enemy_evolution
        or nil

    if not enemy_evolution then
        return false
    end

    enemy_evolution.pollution_factor = pollution_factor
    return true
end

local function restore_pollution_factor(state)
    state = state or ensure_state()

    if (state.pollution_factor_last_applied ~= nil or state.pollution_factor_multiplier ~= nil)
        and ei_lib.is_valid_number(state.pollution_factor_base) then
        if set_pollution_factor(state.pollution_factor_base) then
            state.pollution_factor_last_applied = nil
            state.pollution_factor_multiplier = nil
            return true
        end

        return false
    end

    state.pollution_factor_last_applied = nil
    state.pollution_factor_multiplier = nil
    return false
end

local function apply_pollution_factor_multiplier(policy, state)
    state = state or ensure_state()
    local multiplier = policy and policy.pollution_factor_multiplier or nil

    if not multiplier then
        return restore_pollution_factor(state)
    end

    local current_factor = get_pollution_factor()
    if not current_factor then
        return false
    end

    if not ei_lib.is_valid_number(state.pollution_factor_base) then
        state.pollution_factor_base = current_factor
    end

    local target_factor = state.pollution_factor_base * multiplier
    if math.abs(current_factor - target_factor) > POLLUTION_FACTOR_EPSILON then
        if not set_pollution_factor(target_factor) then
            return false
        end
    end

    state.pollution_factor_last_applied = target_factor
    state.pollution_factor_multiplier = multiplier
    return true
end

local function resolve_phase_policy(force, profile)
    if not force or not force.valid or not force.technologies then
        return PHASE_POLICIES.inactive
    end

    if profile == PROFILE_CLASSIC then
        if force_has_researched(force, "ei-electricity-age") then
            return PHASE_POLICIES.inactive
        end
        if force_has_researched(force, "ei-steam-age") then
            return PHASE_POLICIES.steam_to_electricity
        end
        return PHASE_POLICIES.pre_steam
    end

    if force_has_researched(force, "ei-computer-age") then
        return PHASE_POLICIES.inactive
    end
    if force_has_electric_defense(force) then
        return PHASE_POLICIES.electricity_pre_computer
    end
    if force_has_researched(force, "ei-electricity-power") then
        return PHASE_POLICIES.electricity_pre_defense
    end
    if force_has_researched(force, "ei-electricity-age") then
        return PHASE_POLICIES.electricity_pre_power
    end
    if force_has_researched(force, "ei-steam-age") then
        return PHASE_POLICIES.steam_to_electricity
    end

    return PHASE_POLICIES.pre_steam
end

local function refresh_player_force_policy()
    local state = ensure_state()
    local policy = resolve_phase_policy(get_player_force(), state.profile)

    state.phase = policy.key
    state.milestone = policy.milestone
    state.evolution_target = policy.evolution_target
    state.max_reduction = policy.max_reduction

    return policy
end

local function sync_runtime_pressure(policy)
    local state = ensure_state()
    state.last_sync_tick = game and game.tick or state.last_sync_tick

    if storage.ei.enemy_difficulty == "Impossible"
        or state.enabled == false
        or (policy and policy.key or PHASE_INACTIVE) == PHASE_INACTIVE then
        restore_pollution_factor(state)
        return false
    end

    apply_pollution_factor_multiplier(policy, state)
    return true
end

function model.on_configuration_changed(event)
    local policy = refresh_player_force_policy()
    sync_runtime_pressure(policy)
end

function model.on_research_finished(event)
    local research_force = event and event.research and event.research.force or nil
    if research_force and not is_player_force(research_force) then
        return false
    end

    local policy = refresh_player_force_policy()
    return sync_runtime_pressure(policy)
end

function model.on_scripted_research_burst(force)
    if force and not is_player_force(force) then
        return false
    end

    local policy = refresh_player_force_policy()
    return sync_runtime_pressure(policy)
end

function model.has_tick_work(event)
    if not event or not event.tick then
        return false
    end

    local state = storage and storage.ei and storage.ei.nauvis_pressure or nil
    if type(state) ~= "table" then
        return true
    end

    local needs_pressure_restore = state.pollution_factor_last_applied ~= nil
        or state.pollution_factor_multiplier ~= nil

    if storage.ei.enemy_difficulty == "Impossible" or state.enabled == false then
        return needs_pressure_restore
    end

    if state.phase == nil then
        return true
    end

    if state.last_sync_tick == nil then
        return true
    end

    if state.phase == PHASE_INACTIVE then
        return needs_pressure_restore
    end

    local last_run_tick = state.last_run_tick or 0
    return event.tick - last_run_tick >= CHECK_INTERVAL
end

function model.updater(event)
    if not event or not event.tick then
        return
    end

    local policy = refresh_player_force_policy()
    if not sync_runtime_pressure(policy) then
        return
    end

    local state = ensure_state()
    local last_run_tick = state.last_run_tick or 0
    if event.tick - last_run_tick < CHECK_INTERVAL then
        return
    end

    state.last_run_tick = event.tick

    local nauvis = game and game.surfaces and game.surfaces["nauvis"]
    local enemy_force = game and game.forces and game.forces.enemy
    if not nauvis or not enemy_force then
        return
    end

    local target = policy.evolution_target
    local max_reduction = policy.max_reduction
    if not target or not max_reduction then
        return
    end

    local current = enemy_force.get_evolution_factor(nauvis)
    if not current or current <= target then
        return
    end

    local next_evolution = current - math.min(current - target, max_reduction)
    enemy_force.set_evolution_factor(next_evolution, nauvis)
end

return model
