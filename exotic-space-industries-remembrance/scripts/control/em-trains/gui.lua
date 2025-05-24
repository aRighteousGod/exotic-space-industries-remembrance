local mod_gui = require("mod-gui")
local model = {}

--====================================================================================================
--MAIN
--====================================================================================================

--MOD GUI
------------------------------------------------------------------------------------------------------

function model.make_mod_button(player)

  em_trains.check_global()

    -- if button already exists, return
    if mod_gui.get_button_flow(player)["ei_emt_button"] then
        return
    end

    local button = mod_gui.get_button_flow(player).add{
        type = "sprite-button",
        name = "ei_emt_button",
        sprite = "ei_emt-logo",
        style = mod_gui.button_style,
        tags = {
            action = "open_mod_gui",
            parent_gui = "mod_gui"
        }
    }

end


function model.open_mod_gui(player)
    if player.gui.left["ei_mod-gui"] then
        player.gui.left["ei_mod-gui"].destroy()
        return
    end

    local left_gui = player.gui.left

    local root = left_gui.add{
        type = "frame",
        name = "ei_mod-gui",
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
                parent_gui = "ei_mod-gui"
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

    model.mark_dirty()

end


function model.update_mod_gui(player)

    if not player.gui.left["ei_mod-gui"] then return end

    local data = model.get_data(player.surface)

    local root = player.gui.left["ei_mod-gui"]
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


function model.get_data(surface)

    surface = surface or game.get_surface(1)
    data = {}
    
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

    if not storage.ei_emt.gui.dirty then
        return
    end

    for _, player in pairs(game.players) do
        model.make_mod_button(player)
        model.update_mod_gui(player)
    end

    storage.ei_emt.gui.dirty = false

end


function model.mark_dirty()

  em_trains.check_global()

    storage.ei_emt.gui.dirty = true

end


function model.on_gui_click(event)
    
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

    if event.element.tags.action == "open_mod_gui" then
        model.open_mod_gui(game.get_player(event.player_index))
        return
    end

    if event.element.tags.action == "toggle_range_highlight" then
      em_trains.toggle_range_highlight(game.get_player(event.player_index))
        return
    end
end


return model

