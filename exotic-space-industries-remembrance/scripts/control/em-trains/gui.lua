--==============================================================================
-- ESIR FILE MAP
-- owns: EM train GUI and dirty refresh
-- loaded_by: exotic-space-industries-remembrance\control.lua
-- cadence: dirty-gated refresh and GUI click dispatch
-- forwarded_events: force_has_access, get_data, has_tick_work, make_mod_button, mark_dirty, on_gui_click, on_player_ready, open_mod_gui, player_has_access, sync_mod_button, update_mod_gui, updater
-- storage_roots: storage.ei_emt
-- gui_ids: ei_emt_button, ei_mod-gui, mod_gui
-- remote_interfaces: none
-- rebuild_on: GUI schema changes, EM train runtime changes
--==============================================================================
local mod_gui = require("mod-gui")
local model = {}
local GUI_NAME = "ei_mod-gui"
local BUTTON_NAME = "ei_emt_button"
local UNLOCK_TECH_NAME = "ei_em-trains"
local ACCESS_RECIPE_NAMES = {
    "ei_em-locomotive",
    "ei_em-fluid-wagon",
    "ei_em-cargo-wagon",
    "ei_charger",
    "ei_em-fielder",
}

model.gui_name = GUI_NAME

--====================================================================================================
--MAIN
--====================================================================================================

--MOD GUI
------------------------------------------------------------------------------------------------------

---@param force LuaForce|nil
---@return boolean
function model.force_has_access(force)
    if not force or force.valid == false then
        return false
    end

    local technologies = force.technologies
    local unlock_technology = technologies and technologies[UNLOCK_TECH_NAME] or nil
    if unlock_technology then
        return unlock_technology.researched == true
    end

    local recipes = force.recipes
    if not recipes then
        return false
    end

    for _, recipe_name in ipairs(ACCESS_RECIPE_NAMES) do
        local recipe = recipes[recipe_name]
        if recipe and recipe.enabled then
            return true
        end
    end

    return false
end

---@param player LuaPlayer|nil
---@return boolean
function model.player_has_access(player)
    return player
        and player.valid
        and model.force_has_access(player.force)
        or false
end

---@param player LuaPlayer|nil
function model.close_mod_gui(player)
    if not (player and player.valid) then
        return
    end

    local root = player.gui.left[GUI_NAME]
    if root and root.valid then
        root.destroy()
    end
end

---@param player LuaPlayer|nil
---@return boolean
function model.make_mod_button(player)
    if not model.player_has_access(player) then
        return false
    end

    em_trains.check_global()

    local button_flow = mod_gui.get_button_flow(player)
    if not button_flow then
        return false
    end

    -- if button already exists, return
    local button = button_flow[BUTTON_NAME]
    if button and button.valid then
        return true
    end

    button_flow.add{
        type = "sprite-button",
        name = BUTTON_NAME,
        sprite = "ei_emt-logo",
        style = mod_gui.button_style,
        tags = {
            action = "open_mod_gui",
            parent_gui = "mod_gui"
        }
    }

    return true
end

---@param player LuaPlayer|nil
---@return boolean
function model.sync_mod_button(player)
    if not (player and player.valid) then
        return false
    end

    local button_flow = mod_gui.get_button_flow(player)
    local button = button_flow and button_flow[BUTTON_NAME] or nil
    if model.player_has_access(player) then
        return model.make_mod_button(player)
    end

    if button and button.valid then
        button.destroy()
    end
    model.close_mod_gui(player)
    return false
end

---@param player_index uint|nil
function model.on_player_ready(player_index)
    if not player_index then
        return
    end

    local player = game.get_player(player_index)
    if not player then
        return
    end

    model.sync_mod_button(player)
    model.update_mod_gui(player)
end


---@param player LuaPlayer|nil
function model.open_mod_gui(player)
    if not model.player_has_access(player) then
        model.sync_mod_button(player)
        return
    end

    if player.gui.left[GUI_NAME] then
        player.gui.left[GUI_NAME].destroy()
        return
    end

    local left_gui = player.gui.left

    local root = left_gui.add{
        type = "frame",
        name = GUI_NAME,
        direction = "vertical"
    }

    local main_container = root.add{
        type = "frame",
        name = "main-container",
        direction = "vertical",
        style = "inside_shallow_frame"
    }

    do -- Chargers
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries-emt.mod-gui-chargers-title"},
            style = "subheader_caption_label",
        }

        local chargers_flow = main_container.add{
            type = "flow",
            name = "chargers-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        -- toggle buton
        local toggle_flow = chargers_flow.add{
            type = "flow",
            name = "toggle-flow",
            direction = "horizontal",
        }

        toggle_flow.add{
            type = "label",
            caption = {"exotic-industries-emt.mod-gui-chargers-toggle"},
        }

        local toggle_button_frame = toggle_flow.add{
            type = "frame",
            name = "toggle-button-frame",
            style = "slot_button_deep_frame"
        }

        toggle_button_frame.add{
            type = "sprite-button",
            name = "toggle-button",
            sprite = "ei_emt-range-toggle",
            tags = {
                action = "toggle_range_highlight",
                parent_gui = GUI_NAME
            }
        }

    end

    do -- Trains
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries-emt.mod-gui-trains-title"},
            style = "subheader_caption_label",
        }

        local trains_flow = main_container.add{
            type = "flow",
            name = "trains-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        -- stats
        trains_flow.add{
            type = "label",
            name = "total-chargers-label",
            caption = {"exotic-industries-emt.total-chargers", 0},
            tooltip = {"exotic-industries-emt.total-chargers-tooltip"},
        }

        trains_flow.add{
            type = "label",
            name = "total-rails-label",
            caption = {"exotic-industries-emt.total-rails", 0},
            tooltip = {"exotic-industries-emt.total-rails-tooltip"},
        }

        trains_flow.add{
            type = "label",
            name = "total-trains-label",
            caption = {"exotic-industries-emt.total-trains", 0},
            tooltip = {"exotic-industries-emt.total-trains-tooltip"},
        }

    end

    do -- Stats
        main_container.add{
            type = "frame",
            style = "ei_subheader_frame",
        }.add{
            type = "label",
            caption = {"exotic-industries-emt.mod-gui-stats-title"},
            style = "subheader_caption_label",
        }

        local stats_flow = main_container.add{
            type = "flow",
            name = "stats-flow",
            direction = "vertical",
            style = "ei_inner_content_flow",
        }

        -- stats
        stats_flow.add{
            type = "label",
            name = "charger-efficiency-label",
            caption = {"exotic-industries-emt.charger-efficiency", 0},
            tooltip = {"exotic-industries-emt.charger-efficiency-tooltip"},
        }

        stats_flow.add{
            type = "label",
            name = "acc-level-label",
            caption = {"exotic-industries-emt.acc-level", 0},
            tooltip = {"exotic-industries-emt.acc-level-tooltip"},
        }
        --[[
        stats_flow.add{
            type = "label",
            name = "acc-total-label",
            caption = {"exotic-industries-emt.acc-total", 0},
        }
        ]]

        stats_flow.add{
            type = "label",
            name = "speed-level-label",
            caption = {"exotic-industries-emt.speed-level", 0},
            tooltip = {"exotic-industries-emt.speed-level-tooltip"},
        }
        stats_flow.add{
            type = "label",
            name = "speed-total-label",
            caption = {"exotic-industries-emt.speed-total", 0},
        }

    end

    model.update_mod_gui(player)

end


---@param player LuaPlayer|nil
function model.update_mod_gui(player)
    if not (player and player.valid) then
        return
    end

    if not model.player_has_access(player) then
        model.close_mod_gui(player)
        return
    end

    if not player.gui.left[GUI_NAME] then return end

    local data = model.get_data(player.surface)

    local root = player.gui.left[GUI_NAME]
    local chargers_flow = root["main-container"]["chargers-flow"]
    local trains_flow = root["main-container"]["trains-flow"]
    local stats_flow = root["main-container"]["stats-flow"]

    -- update stats
    trains_flow["total-chargers-label"].caption = {"exotic-industries-emt.total-chargers", data.chargers}
    trains_flow["total-rails-label"].caption = {"exotic-industries-emt.total-rails", data.rails}
    trains_flow["total-trains-label"].caption = {"exotic-industries-emt.total-trains", data.trains}

    -- update stats
    stats_flow["charger-efficiency-label"].caption = {"exotic-industries-emt.charger-efficiency", data.charger_efficiency}
    stats_flow["acc-level-label"].caption = {"exotic-industries-emt.acc-level", data.acc_level}
    stats_flow["speed-level-label"].caption = {"exotic-industries-emt.speed-level", data.speed_level}
    stats_flow["speed-total-label"].caption = {"exotic-industries-emt.speed-total", data.speed_total}
    

end


---@param surface LuaSurface|nil
---@return table
function model.get_data(surface)
    em_trains.check_global()

    surface = surface or game.get_surface(1)
    local data = {}
    
    -- charger info
    local surface_chargers = {}
    for charger_id, charger_data in pairs(storage.ei_emt.chargers) do
        if charger_data.surface == surface then
            table.insert(surface_chargers, charger_data)
        end
    end
    data.chargers = #surface_chargers

    -- train info
    local trains = {}
    for train_id, train_data in pairs(storage.ei_emt.trains) do
        if train_data.surface == surface then
            table.insert(trains, train_data)
        end
    end
    data.trains = #trains

    data.rails = 0
    for _, charger in ipairs(surface_chargers) do
        data.rails = data.rails + charger.rail_count
    end

    data.charger_efficiency = storage.ei_emt.buffs.charger_efficiency
    data.acc_level = storage.ei_emt.buffs.acc_level
    data.speed_level = storage.ei_emt.buffs.speed_level

    -- calc total speed
    local base_speed = 216 -- in km/h
    data.speed_total = base_speed*2*(1+0.1*storage.ei_emt.buffs.speed_level)

    -- game.print(serpent.block(storage.ei_emt.buffs))

    return data

end

--HANDLERS
------------------------------------------------------------------------------------------------------

function model.updater()

    if not model.has_tick_work() then
        return
    end

    for _, player in pairs(game.connected_players) do
        model.sync_mod_button(player)
        model.update_mod_gui(player)
    end

    storage.ei_emt.gui.dirty = false

end


function model.has_tick_work(_event)

    local gui_state = storage
        and storage.ei_emt
        and storage.ei_emt.gui

    return gui_state and gui_state.dirty == true or false

end


function model.mark_dirty()

    em_trains.check_global()

    storage.ei_emt.gui.dirty = true

end


function model.on_gui_click(event)
    local element = event and event.element or nil
    if not (element and element.valid) then
        return
    end

    local tags = element.tags
    if not tags then
        return
    end
    
    --[[
    if event.element.tags.action == "goto-informatron" then
        if game.forces["player"].technologies["ei_gate"].enabled == true then
            remote.call("informatron", "informatron_open_to_page", {
                player_index = event.player_index,
                interface = "exotic-industries-informatron",
                page_name = event.element.tags.page
            })
            return
        end
    end
    ]]

    if tags.action == "open_mod_gui" then
        model.open_mod_gui(game.get_player(event.player_index))
        return
    end

    if tags.action == "toggle_range_highlight" then
      em_trains.toggle_range_highlight(game.get_player(event.player_index))
        return
    end
end


return model

