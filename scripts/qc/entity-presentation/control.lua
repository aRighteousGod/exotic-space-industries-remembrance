-- Exact native scene-content fixture; all non-QC runtime controls are isolated.
local fixture = require("test-config")
local scenes, report = {}, {validation = "pending", scenes = {}}
local visual_reported = false

local function init_scenes()
    local rows = prototypes.mod_data["esir-presentation-qc"].get("scenes")
    storage.scene_generation = (storage.scene_generation or 0) + 1
    for index, row in ipairs(rows) do
        local surface = game.create_surface("presentation-qc-" .. index .. "-" .. storage.scene_generation, {width = 64, height = 64})
        surface.request_to_generate_chunks({0, 0}, 1)
        surface.force_generate_chunk_requests()
        -- Preserve valid chunks for native spider legs; clearing the surface
        -- would remove the terrain and schedule another clear on a later tick.
        for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
        surface.destroy_decoratives{}
        local tiles = {}
        for x = -20, 20 do for y = -15, 15 do
            tiles[#tiles + 1] = {name = (x + y) % 2 == 0 and "lab-dark-1" or "lab-dark-2", position = {x, y}}
        end end
        surface.set_tiles(tiles)
        surface.daytime, surface.freeze_daytime = 0, true
        local camera = {}
        local game_facade = setmetatable({surfaces = {[1] = surface}, simulation = camera}, {__index = function(_, key) return game[key] end})
        local env = setmetatable({game = game_facade, storage = {}}, {__index = _G})
        local init = assert(load(row.simulation.init, "=presentation:" .. row.name, "t", env))
        init()
        local bodies = surface.find_entities_filtered{name = row.name}
        assert(#bodies == 1, "Initial body count " .. #bodies .. ": " .. row.name)
        local update = row.simulation.update and assert(load(row.simulation.update, "=presentation-update:" .. row.name, "t", env))
        scenes[#scenes + 1] = {name = row.name, surface = surface, camera = camera, update = update,
            preroll = row.simulation.init_update_count or 0, captured = false}
    end
end

local function inspect_scene(scene, steady)
    local entities = scene.surface.find_entities_filtered{name = scene.name}
    assert(#entities == 1 and entities[1].valid, "Body count " .. #entities .. ": " .. scene.name)
    local body = entities[1]
    local row = report.scenes[scene.name] or {name = scene.name}
    row.camera = {camera_zoom = scene.camera.camera_zoom,
        camera_position = {scene.camera.camera_position[1], scene.camera.camera_position[2]}}
    row.body = body.name
    row.position = body.position
    row.preroll = scene.preroll
    if scene.name == "ei-incinerator" then
        assert(body.time_to_live > 10000, "Robot preview expired")
        row.robot_remaining = body.time_to_live
    elseif scene.name == "ei-prediction-snare-mine" then
        assert(not body.to_be_deconstructed(), "Mine scene state")
    elseif scene.name == "ei-sweeping-radar" or scene.name == "ei-phased-array-radar" then
        local helper_name = scene.name == "ei-sweeping-radar" and "ei-sweeping-radar-visual-2" or "ei-phased-array-radar-visual-1-lit"
        local helpers = scene.surface.find_entities_filtered{name = helper_name}
        assert(#helpers == 1, "Radar art absent")
        local variation = scene.name == "ei-sweeping-radar" and 65 or 1
        assert(helpers[1].graphics_variation == variation and not helpers[1].destructible and not helpers[1].operable, "Radar frame")
        row.helper, row.variation = helper_name, variation
    end
    row[steady and "steady" or "preroll_passed"] = true
    report.scenes[scene.name] = row
    if fixture.visual and not steady then
        game.take_screenshot{surface = scene.surface, position = scene.camera.camera_position,
            zoom = scene.camera.camera_zoom, resolution = {512, 384}, path = "presentation/" .. scene.name .. ".png",
            daytime = 0, show_gui = false, show_entity_info = false, anti_alias = true, force_render = true}
    end
end

script.on_init(function()
    storage.started = game.tick
    init_scenes()
end)
script.on_load(function() scenes = {} end)
script.on_event(defines.events.on_tick, function(event)
    if #scenes == 0 then init_scenes() end
    local elapsed = event.tick - storage.started
    for _, scene in ipairs(scenes) do
        if scene.update then scene.update() end
        if not scene.captured and elapsed >= scene.preroll then
            inspect_scene(scene, false)
            scene.captured = true
        end
    end
    if fixture.visual and not visual_reported then
        local ready = true
        for _, scene in ipairs(scenes) do if not scene.captured then ready = false end end
        if ready then
            report.capture_validation = "passed"
            helpers.write_file("presentation-visual.json", helpers.table_to_json(report), false)
            game.set_wait_for_screenshots_to_finish()
            visual_reported = true
        end
    end
    if elapsed == fixture.ticks - 2 then
        for _, scene in ipairs(scenes) do inspect_scene(scene, true) end
        report.validation = "passed"
        report.elapsed_ticks = elapsed
        helpers.write_file("presentation-runtime.json", helpers.table_to_json(report), false)
        game.set_wait_for_screenshots_to_finish()
    end
end)
