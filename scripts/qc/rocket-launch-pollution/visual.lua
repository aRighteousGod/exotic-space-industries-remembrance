-- Graphical-only observer: real rocket frames and the native production window.
local previous = script.get_event_handler(defines.events.on_tick)
script.on_event(defines.events.on_tick, function(event)
  local player = game.get_player(1)
  if not (player and player.connected) then previous(event); return end
  game.speed = 1
  previous(event)
  local row = storage.cases[1]
  if not storage.visual_viewer then
    player.set_controller{type = defines.controllers.spectator}
    player.teleport({0, 0}, row.surface)
    player.zoom = .8
    storage.visual_viewer = true
    storage.visual_frames = {}
  end
  local age = row.ignition_tick and event.tick - row.ignition_tick
  if age == 0 or age == 1 or age == 30 or age == 150 or age == 570 then
    local file = "rocket-visual/ignition-" .. age .. ".png"
    game.take_screenshot{player = player, surface = row.surface, position = {0, -5},
      path = file, resolution = {1280, 720}, zoom = .8, show_gui = false,
      hide_clouds = true, hide_fog = true, force_render = true}
    storage.visual_frames[#storage.visual_frames + 1] = file
  end
  if row.confirm_tick and event.tick > row.confirm_tick + 2 then
    game.speed = .25
    if not storage.visual_graph then
      player.opened = defines.gui_type.production
      storage.visual_graph = true
    end
    if event.tick % 15 == 0 then
      game.take_screenshot{player = player, path = "rocket-visual/graph.png", resolution = {1280, 720}, show_gui = true, force_render = true}
      helpers.write_file("rocket-visual/ready.json", helpers.table_to_json{tick = event.tick,
        ignition = row.ignition_tick, confirmed = row.confirm_tick, frames = storage.visual_frames,
        graph_total = row.surface.pollution_statistics.get_input_count("ei-rocket-launch-pollution")}, false)
    end
  end
end)
