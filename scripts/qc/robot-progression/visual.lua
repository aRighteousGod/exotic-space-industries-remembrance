-- Native recipe selector and Factoriopedia windows, captured by a real client.
local model = {}
local targets = {"ei-advanced-logistic-bot", "ei-advanced-construction-bot"}
local recipes = {"ei-advanced-logistic-bot-from-cargo-bot", "ei-advanced-construction-bot-from-construction-bot"}
function model.tick(event)
    local player = game.get_player(1)
    if not player then return end
    if not storage.visual_start then
        game.speed = 1
        storage.visual_start = event.tick
        player.set_controller{type = defines.controllers.god}
        player.teleport({8, 8}, game.surfaces["robot-crafting-qc"])
        player.force.technologies["ei-advanced-bots"].researched = true
        player.game_view_settings.show_entity_info = true
        local frame = player.gui.screen.add{type = "frame", name = "robot_icon_review", direction = "vertical", caption = "Advanced bot conversions"}
        frame.auto_center = true
        for _, name in ipairs(recipes) do
            local row = frame.add{type = "flow"}
            row.add{type = "sprite-button", sprite = "recipe/"..name, tooltip = prototypes.recipe[name].localised_name}
            row.add{type = "label", caption = prototypes.recipe[name].localised_name}
        end
    end
    local t = event.tick - storage.visual_start
    if t == 1 then log("ROBOT VISUAL: ticking") end
    if t == 90 then player.gui.screen.robot_icon_review.destroy(); player.opened = storage.machines[1].entity end
    if t == 180 then player.opened = nil; player.open_factoriopedia_gui{type = "entity", name = targets[1]} end
    if t == 300 then player.open_factoriopedia_gui{type = "entity", name = targets[2]} end
    if t == 420 then player.open_factoriopedia_gui{type = "recipe", name = recipes[1]} end
    if t == 510 then player.open_factoriopedia_gui{type = "recipe", name = recipes[2]} end
    local paths = {[60] = "icons", [150] = "machine", [270] = "wraithline", [390] = "architectum", [480] = "logistic-recipe", [570] = "construction-recipe"}
    if paths[t] then
        log("ROBOT VISUAL: capture "..paths[t])
        game.take_screenshot{player = player, resolution = {1600, 1000}, path = "robot-"..paths[t]..".png", show_gui = true, force_render = true}
    end
    if t == 600 then helpers.write_file("robot-visual.json", helpers.table_to_json{captured = true}, false) end
end
return model
