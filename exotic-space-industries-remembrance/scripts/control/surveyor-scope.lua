--==============================================================================
-- ESIR FILE MAP
-- owns: Surveyor rifle inventory zoom limits
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: player inventory/lifecycle/controller events
-- forwarded_events: check_global, refresh_player, on_player_ready,
--                   on_player_gun_inventory_changed, on_player_controller_changed,
--                   on_player_died, on_player_left_game, on_player_removed,
--                   on_configuration_changed
-- storage_roots: storage.ei.surveyor_scope
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: init and configuration change
--==============================================================================

---@class SurveyorScopePlayerState
---@field active boolean
---@field saved_zoom_limits ZoomLimits?

---@class SurveyorScopeRuntime
---@field players table<uint, SurveyorScopePlayerState>

---@class SurveyorScopeModule
---@field check_global fun(): SurveyorScopeRuntime
---@field refresh_player fun(player_index: uint?): boolean
---@field on_player_ready fun(player_index: uint?): boolean
---@field on_player_gun_inventory_changed fun(event: EventData.on_player_gun_inventory_changed?): boolean
---@field on_player_controller_changed fun(event: table?): boolean
---@field on_player_died fun(event: EventData.on_player_died?): boolean
---@field on_player_left_game fun(event_or_player_index: table|uint?): boolean
---@field on_player_removed fun(event: EventData.on_player_removed?): boolean
---@field on_configuration_changed fun(event: ConfigurationChangedData?)

---@type SurveyorScopeModule
local model = {}

local SURVEYOR_GUNS = {
    ["ei-surveyor-carbine"] = true,
    ["ei-surveyor-rifle"] = true,
    ["ei-surveyor-cannon"] = true,
    ["ei-adaptive-surveyor"] = true,
}

local SCOPED_ZOOM_LIMITS = {
    furthest = {distance = 200, max_distance = 240},
    furthest_game_view = {distance = 200, max_distance = 240},
}

local function copy_table(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copy_table(child)
    end
    return copy
end

---@param event_or_player_index table|uint?
---@return LuaPlayer?
local function get_player(event_or_player_index)
    local player_index = type(event_or_player_index) == "table"
        and event_or_player_index.player_index
        or event_or_player_index
    if not player_index or not game then
        return nil
    end
    return game.get_player(player_index)
end

local function character_controller()
    return defines and defines.controllers and defines.controllers.character or nil
end

---@param player LuaPlayer?
---@return LuaInventory?
local function get_gun_inventory(player)
    if not player or not player.valid then
        return nil
    end

    local inventory_id = defines and defines.inventory and defines.inventory.character_guns
    if not inventory_id then
        return nil
    end

    local character = player.character
    if character and character.valid then
        local ok, inventory = pcall(function()
            return character.get_inventory(inventory_id)
        end)
        if ok then
            return inventory
        end
    end

    return nil
end

---@param player LuaPlayer?
---@return boolean
local function has_surveyor_gun(player)
    local inventory = get_gun_inventory(player)
    if not inventory then
        return false
    end

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read and SURVEYOR_GUNS[stack.name] then
            return true
        end
    end

    return false
end

---@param player LuaPlayer?
---@param zoom_limits ZoomLimits?
---@return boolean
local function set_character_zoom_limits(player, zoom_limits)
    local controller = character_controller()
    if not player or not player.valid or not controller then
        return false
    end

    local ok = pcall(function()
        player.set_zoom_limits(controller, copy_table(zoom_limits or {}))
    end)

    return ok
end

---@param runtime SurveyorScopeRuntime
---@param player_index uint
---@return SurveyorScopePlayerState
local function get_player_state(runtime, player_index)
    runtime.players[player_index] = runtime.players[player_index] or {
        active = false,
        saved_zoom_limits = nil,
    }
    return runtime.players[player_index]
end

function model.check_global()
    storage.ei = storage.ei or {}
    if type(storage.ei.surveyor_scope) ~= "table" then
        storage.ei.surveyor_scope = {}
    end

    local runtime = storage.ei.surveyor_scope
    if type(runtime.players) ~= "table" then
        runtime.players = {}
    end

    return runtime
end

---@param runtime SurveyorScopeRuntime
---@param player LuaPlayer
local function apply_scope(runtime, player)
    local state = get_player_state(runtime, player.index)

    if not state.active then
        state.saved_zoom_limits = copy_table(player.zoom_limits or {})
    end

    state.active = true
    set_character_zoom_limits(player, SCOPED_ZOOM_LIMITS)
end

---@param runtime SurveyorScopeRuntime
---@param player_index uint
---@param player LuaPlayer?
---@return boolean
local function restore_scope(runtime, player_index, player)
    local state = runtime.players[player_index]
    if not state then
        return true
    end

    if state.active and player and player.valid then
        if not set_character_zoom_limits(player, state.saved_zoom_limits or {}) then
            return false
        end
    end

    runtime.players[player_index] = nil
    return true
end

function model.refresh_player(player_index)
    local runtime = model.check_global()
    if not player_index then
        return false
    end

    local player = get_player(player_index)
    if not player or not player.valid then
        runtime.players[player_index] = nil
        return false
    end

    local controller = character_controller()
    local should_scope = player.connected
        and controller ~= nil
        and player.controller_type == controller
        and has_surveyor_gun(player)

    if should_scope then
        apply_scope(runtime, player)
        return true
    end

    restore_scope(runtime, player.index, player)
    return false
end

function model.on_player_ready(player_index)
    return model.refresh_player(player_index)
end

function model.on_player_gun_inventory_changed(event)
    return model.refresh_player(event and event.player_index)
end

function model.on_player_controller_changed(event)
    return model.refresh_player(event and event.player_index)
end

function model.on_player_died(event)
    return model.on_player_left_game(event)
end

function model.on_player_left_game(event_or_player_index)
    local runtime = model.check_global()
    local player = get_player(event_or_player_index)
    local player_index = player and player.index or (
        type(event_or_player_index) == "table" and event_or_player_index.player_index or event_or_player_index
    )
    if player_index then
        return restore_scope(runtime, player_index, player)
    end
    return false
end

function model.on_player_removed(event)
    return model.on_player_left_game(event)
end

function model.on_configuration_changed(_event)
    local runtime = model.check_global()

    for player_index, state in pairs(runtime.players) do
        if state and state.active then
            local player = game.get_player(player_index)
            if player and player.valid then
                set_character_zoom_limits(player, state.saved_zoom_limits or {})
            end
        end
        runtime.players[player_index] = nil
    end

    for _, player in pairs(game.connected_players) do
        model.refresh_player(player.index)
    end
end

return model
