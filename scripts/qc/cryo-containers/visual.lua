local cases = require("cases")
local function setup(player)
    log("CRYO VISUAL: setup")
    local surface = game.create_surface("cryo-visual", {width = 64, height = 64, autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 1)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = -20, 20 do for y = -20, 20 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    player.set_controller({type = defines.controllers.god})
    player.teleport({0, 0}, surface)
    for _, family in ipairs(cases.families) do player.force.technologies["ei-"..family[1].."-cryo-container"].researched = true end
    storage.visual_machine = surface.create_entity({name = "assembling-machine-3", position = {0, 0}, force = player.force})
    local frame = player.gui.screen.add({type = "frame", name = "cryo_icon_review", caption = "Cryo containers: item / fill / empty", direction = "vertical"})
    frame.auto_center = true
    local grid = frame.add({type = "table", column_count = 4})
    for _, row in ipairs(cases.fluids) do
        grid.add({type = "label", caption = {"fluid-name."..row[1]}}).style.width = 210
        for _, sprite in ipairs({"item/ei-cryo-container-", "recipe/ei-fill-cryo-container-", "recipe/ei-empty-cryo-container-"}) do
            local button = grid.add({type = "sprite-button", sprite = sprite..row[2]})
            button.style.size = 64
        end
    end
    player.opened = frame
    storage.visual_start = game.tick
    game.tick_paused = false
    log("CRYO VISUAL: icons open")
end
script.on_event(defines.events.on_player_created, function(event)
    if not storage.visual_start then setup(game.get_player(event.player_index)) end
    game.tick_paused = false
end)
script.on_event(defines.events.on_tick, function(event)
    local player = game.get_player(1)
    if not player then return end
    if not storage.visual_start then setup(player) end
    storage.visual_frames = (storage.visual_frames or 0) + 1
    local elapsed = storage.visual_frames
    if elapsed <= 2 then log("CRYO VISUAL: update "..elapsed.." tick="..event.tick.." paused="..tostring(game.tick_paused)) end
    if elapsed == 50 then
        player.gui.screen.cryo_icon_review.destroy()
        player.opened = storage.visual_machine
    elseif elapsed == 100 then
        player.open_factoriopedia_gui({type = "item", name = "ei-cryo-container-auric-vapor"})
    elseif elapsed == 150 then
        player.open_factoriopedia_gui({type = "recipe", name = "ei-empty-cryo-container-ammonia"})
    elseif elapsed == 200 then
        player.open_technology_gui("ei-aquilan-cryo-container")
    end
    local paths = {[30] = "icons", [80] = "crafting", [130] = "factoriopedia-auric", [180] = "factoriopedia-ammonia", [230] = "research-aquilan"}
    if paths[elapsed] then
        log("CRYO VISUAL: capture "..paths[elapsed])
        game.take_screenshot({player = player, resolution = {1600, 1000}, path = "cryo-"..paths[elapsed]..".png", show_gui = true, force_render = true})
    end
end)
