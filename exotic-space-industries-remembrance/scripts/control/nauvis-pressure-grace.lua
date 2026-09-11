--==============================================================================
-- ESIR FILE MAP
-- owns: Nauvis pressure grace milestone and pollution/evolution pressure
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: configuration changes, research-finished, and scheduled tick step 1
-- forwarded_events: on_init, has_tick_work, on_configuration_changed, on_research_finished, on_scripted_research_burst, updater
-- storage_roots: storage.ei
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: startup settings, research progression, configuration changes
--==============================================================================
local ei_lib = require("lib/lib")
local enemy_difficulty_config = require("lib/enemy-difficulty-config")
local model = {}

local CHECK_INTERVAL = 18000
local STATE_SCHEMA_VERSION = 2
local PROFILE_CLASSIC = "Classic"
local PROFILE_EXTENDED = "Extended"
local DIFFICULTY_MERCIFUL = "Merciful"
local DIFFICULTY_IMPOSSIBLE = "Impossible"
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

---@type table<string, NauvisPressureGracePolicy>
local MERCIFUL_CLASSIC_POLICIES = {
    pre_steam = {
        key = "merciful_classic_pre_steam",
        milestone = 0,
        evolution_target = 0.15,
        max_reduction = 0.010,
    },
    steam_to_electricity = {
        key = "merciful_classic_steam_to_electricity",
        milestone = 1,
        evolution_target = 0.30,
        max_reduction = 0.008,
    },
    inactive = {
        key = PHASE_INACTIVE,
        milestone = 2,
    },
}

---@type table<string, NauvisPressureGracePolicy>
local MERCIFUL_EXTENDED_POLICIES = {
    pre_steam = {
        key = "merciful_extended_pre_steam",
        milestone = 0,
        evolution_target = 0.15,
        max_reduction = 0.010,
        pollution_factor_multiplier = 0.45,
    },
    steam_to_electricity = {
        key = "merciful_extended_steam_to_electricity",
        milestone = 1,
        evolution_target = 0.30,
        max_reduction = 0.008,
        pollution_factor_multiplier = 0.55,
    },
    electricity_pre_power = {
        key = "merciful_extended_electricity_pre_power",
        milestone = 2,
        evolution_target = 0.38,
        max_reduction = 0.006,
        pollution_factor_multiplier = 0.60,
    },
    electricity_pre_defense = {
        key = "merciful_extended_electricity_pre_defense",
        milestone = 2,
        evolution_target = 0.44,
        max_reduction = 0.005,
        pollution_factor_multiplier = 0.68,
    },
    electricity_pre_computer = {
        key = "merciful_extended_electricity_pre_computer",
        milestone = 2,
        evolution_target = 0.50,
        max_reduction = 0.004,
        pollution_factor_multiplier = 0.75,
    },
    computer_pre_branch = {
        key = "merciful_extended_computer_pre_branch",
        milestone = 3,
        evolution_target = 0.60,
        max_reduction = 0.003,
        pollution_factor_multiplier = 0.82,
    },
    computer_one_branch = {
        key = "merciful_extended_computer_one_branch",
        milestone = 3,
        evolution_target = 0.68,
        max_reduction = 0.002,
        pollution_factor_multiplier = 0.90,
    },
    computer_both_branches = {
        key = "merciful_extended_computer_both_branches",
        milestone = 3,
        evolution_target = 0.75,
        max_reduction = 0.001,
        pollution_factor_multiplier = 0.95,
    },
    inactive = {
        key = PHASE_INACTIVE,
        milestone = 4,
    },
}

---@class NauvisPressureGraceState
---@field schema_version integer
---@field last_run_tick uint
---@field last_sync_tick uint|nil
---@field profile "Classic"|"Extended"
---@field enabled boolean
---@field phase string|nil
---@field milestone integer|nil
---@field evolution_target number|nil
---@field max_reduction number|nil
---@field selected_difficulty string|nil
---@field selected_policy string|nil
---@field pollution_factor_base number|nil
---@field pollution_factor_last_applied number|nil
---@field pollution_factor_multiplier number|nil

---@return NauvisPressureGraceState
local function ensure_state()
    storage.ei = storage.ei or {}
    storage.ei.nauvis_pressure = storage.ei.nauvis_pressure or {}

    local state = storage.ei.nauvis_pressure
    if state.schema_version ~= STATE_SCHEMA_VERSION then
        -- Legacy active modifier fields are retained. A base without either active
        -- marker was stale under schema 1 and must not become a future restore target.
        if state.pollution_factor_last_applied == nil
            and state.pollution_factor_multiplier == nil then
            state.pollution_factor_base = nil
        end
        state.schema_version = STATE_SCHEMA_VERSION
    end
    if state.last_run_tick == nil then
        state.last_run_tick = 0
    end
    if state.profile ~= PROFILE_CLASSIC and state.profile ~= PROFILE_EXTENDED then
        state.profile = PROFILE_EXTENDED
    end
    if state.enabled == nil then
        state.enabled = true
    end

    if state.pollution_factor_last_applied == nil
        and state.pollution_factor_multiplier == nil then
        state.pollution_factor_base = nil
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

---@param state NauvisPressureGraceState
local function clear_pollution_factor_state(state)
    state.pollution_factor_base = nil
    state.pollution_factor_last_applied = nil
    state.pollution_factor_multiplier = nil
end

---@param left number|nil
---@param right number|nil
---@return boolean
local function factors_match(left, right)
    return ei_lib.is_valid_number(left)
        and ei_lib.is_valid_number(right)
        and math.abs(left - right) <= POLLUTION_FACTOR_EPSILON
end

---@param state NauvisPressureGraceState|nil
---@return boolean
local function restore_pollution_factor(state)
    state = state or ensure_state()
    local has_active_modifier = state.pollution_factor_last_applied ~= nil
        or state.pollution_factor_multiplier ~= nil
    if not has_active_modifier then
        clear_pollution_factor_state(state)
        return false
    end

    local current_factor = get_pollution_factor()
    if not current_factor then
        return false
    end

    local base_factor = state.pollution_factor_base
    local owned_factor = state.pollution_factor_last_applied
    if not ei_lib.is_valid_number(owned_factor)
        and ei_lib.is_valid_number(base_factor)
        and ei_lib.is_valid_number(state.pollution_factor_multiplier) then
        owned_factor = base_factor * state.pollution_factor_multiplier
    end

    -- A different live value belongs to another mod or command. Preserve it rather
    -- than restoring ESIR's stale baseline over an external mid-game decision.
    if ei_lib.is_valid_number(owned_factor) and not factors_match(current_factor, owned_factor) then
        clear_pollution_factor_state(state)
        return true
    end

    if ei_lib.is_valid_number(base_factor) and not factors_match(current_factor, base_factor) then
        if not set_pollution_factor(base_factor) then
            return false
        end
    end

    clear_pollution_factor_state(state)
    return true
end

---@param policy NauvisPressureGracePolicy|nil
---@param state NauvisPressureGraceState|nil
---@return boolean
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

    local owned_factor = state.pollution_factor_last_applied
    if not ei_lib.is_valid_number(owned_factor)
        and ei_lib.is_valid_number(state.pollution_factor_base)
        and ei_lib.is_valid_number(state.pollution_factor_multiplier) then
        owned_factor = state.pollution_factor_base * state.pollution_factor_multiplier
    end

    if ei_lib.is_valid_number(owned_factor) and not factors_match(current_factor, owned_factor) then
        -- Rebase on external edits so later policy changes never compound an already
        -- scaled value and shutdown never overwrites someone else's current setting.
        state.pollution_factor_base = current_factor
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

---@param force LuaForce|nil
---@param profile "Classic"|"Extended"
---@return NauvisPressureGracePolicy
local function resolve_standard_phase_policy(force, profile)
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

---@param force LuaForce|nil
---@param profile "Classic"|"Extended"
---@return NauvisPressureGracePolicy
local function resolve_merciful_phase_policy(force, profile)
    if not force or not force.valid or not force.technologies then
        return MERCIFUL_EXTENDED_POLICIES.inactive
    end

    if profile == PROFILE_CLASSIC then
        if force_has_researched(force, "ei-electricity-age") then
            return MERCIFUL_CLASSIC_POLICIES.inactive
        end
        if force_has_researched(force, "ei-steam-age") then
            return MERCIFUL_CLASSIC_POLICIES.steam_to_electricity
        end
        return MERCIFUL_CLASSIC_POLICIES.pre_steam
    end

    if force_has_researched(force, "ei-quantum-age") then
        return MERCIFUL_EXTENDED_POLICIES.inactive
    end

    if force_has_researched(force, "ei-computer-age") then
        local advanced_branch = force_has_researched(force, "ei-advanced-computer-age-tech")
        local alien_branch = force_has_researched(force, "ei-alien-computer-age-tech")
        if advanced_branch and alien_branch then
            return MERCIFUL_EXTENDED_POLICIES.computer_both_branches
        end
        if advanced_branch or alien_branch then
            return MERCIFUL_EXTENDED_POLICIES.computer_one_branch
        end
        return MERCIFUL_EXTENDED_POLICIES.computer_pre_branch
    end

    if force_has_electric_defense(force) then
        return MERCIFUL_EXTENDED_POLICIES.electricity_pre_computer
    end
    if force_has_researched(force, "ei-electricity-power") then
        return MERCIFUL_EXTENDED_POLICIES.electricity_pre_defense
    end
    if force_has_researched(force, "ei-electricity-age") then
        return MERCIFUL_EXTENDED_POLICIES.electricity_pre_power
    end
    if force_has_researched(force, "ei-steam-age") then
        return MERCIFUL_EXTENDED_POLICIES.steam_to_electricity
    end
    return MERCIFUL_EXTENDED_POLICIES.pre_steam
end

---@param force LuaForce|nil
---@param profile "Classic"|"Extended"
---@param difficulty string
---@return NauvisPressureGracePolicy
local function resolve_phase_policy(force, profile, difficulty)
    if difficulty == DIFFICULTY_MERCIFUL then
        return resolve_merciful_phase_policy(force, profile)
    end
    return resolve_standard_phase_policy(force, profile)
end

local function refresh_player_force_policy()
    local state = ensure_state()
    local difficulty = storage.ei.enemy_difficulty or enemy_difficulty_config.default
    local policy = resolve_phase_policy(get_player_force(), state.profile, difficulty)

    state.phase = policy.key
    state.milestone = policy.milestone
    state.evolution_target = policy.evolution_target
    state.max_reduction = policy.max_reduction
    state.selected_difficulty = difficulty
    state.selected_policy = policy.key

    return policy
end

---@param policy NauvisPressureGracePolicy|nil
---@param event_or_tick table|uint|nil
local function sync_runtime_pressure(policy, event_or_tick)
    local state = ensure_state()
    state.last_sync_tick = ei_lib.get_event_tick(event_or_tick)

    if storage.ei.enemy_difficulty == DIFFICULTY_IMPOSSIBLE
        or state.enabled == false
        or (policy and policy.key or PHASE_INACTIVE) == PHASE_INACTIVE then
        restore_pollution_factor(state)
        return false
    end

    apply_pollution_factor_multiplier(policy, state)
    return true
end

---@param event EventData.on_init
function model.on_init(event)
    local policy = refresh_player_force_policy()
    return sync_runtime_pressure(policy, event)
end

function model.on_configuration_changed(event)
    local policy = refresh_player_force_policy()
    sync_runtime_pressure(policy, event)
end

function model.on_research_finished(event)
    local research_force = event and event.research and event.research.force or nil
    if research_force and not is_player_force(research_force) then
        return false
    end

    local policy = refresh_player_force_policy()
    return sync_runtime_pressure(policy, event)
end

function model.on_scripted_research_burst(force)
    if force and not is_player_force(force) then
        return false
    end

    local policy = refresh_player_force_policy()
    return sync_runtime_pressure(policy, game and game.tick or 0)
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

    if storage.ei.enemy_difficulty == DIFFICULTY_IMPOSSIBLE or state.enabled == false then
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
    if not sync_runtime_pressure(policy, event) then
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
