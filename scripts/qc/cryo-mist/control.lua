-- Focused native fixture: real NSB lifecycle, otherwise isolated mod controls.
local config = require("test-config")
local scenes = {}
local loaded_checkpoint = false
local final_written = false
local status_names = {}
for name, id in pairs(defines.entity_status) do status_names[id] = name end
local function write(name, value)
    helpers.write_file("cryo-mist/" .. name .. ".json", helpers.table_to_json(value), false)
end

local function surface(name, width, height)
    local s = game.create_surface(name, {width = width, height = height,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    s.request_to_generate_chunks({0, 0}, 3)
    s.force_generate_chunk_requests()
    for _, e in ipairs(s.find_entities()) do e.destroy() end
    s.destroy_decoratives{}
    local tiles = {}
    for x = -width / 2 + 1, width / 2 - 2 do for y = -height / 2 + 1, height / 2 - 2 do
        tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}}
    end end
    s.set_tiles(tiles)
    s.daytime, s.freeze_daytime = 0, true
    return s
end

local function add_row(name, state, position, direction, no_modules)
    local s = storage.surface
    local entity = assert(s.create_entity{name = name, position = position, direction = direction or 0,
        force = "player", raise_built = true})
    local row = {name = name, state = state, entity = entity, previous = 0, advanced = false, no_modules = no_modules}
    if name == "ei-cooler" then
        s.create_entity{name = "cryo-qc-pole", position = position, force = "player"}
        row.supply = s.create_entity{name = "cryo-qc-supply", position = position, force = "player"}
        if state == "unpowered" then row.supply.power_production = 0; row.supply.energy = 0 end
    else
        row.source = assert(s.find_entity(name .. "-source", position), "NSB build did not create source")
        if not no_modules then entity.get_module_inventory().insert{name = "speed-module", count = 2} end
    end
    if state == "disabled" then entity.disabled_by_script = true end
    if state == "deconstruction" then assert(entity.order_deconstruction("player")) end
    storage.rows[#storage.rows + 1] = row
    return row
end

local function feed(row)
    if row.removed then return end
    local entity = row.source or row.entity
    if row.name == "ei-cooler" then
        if row.state ~= "starved" then entity.fluidbox[1] = {name = "ei-nitrogen-gas", amount = 200} end
        if row.state == "blocked" then entity.fluidbox[2] = {name = "ei-liquid-nitrogen", amount = 200}
        else entity.fluidbox[2] = nil end
        if row.state == "unpowered" then entity.energy = 0; row.supply.energy = 0 end
    elseif row.state ~= "starved" then
        entity.insert_fluid{name = "ei-liquid-nitrogen", amount = 100}
    end
    local progress = entity.products_finished + entity.crafting_progress
    if progress > row.previous then row.advanced = true end
    row.previous = progress
end

local function inspect(row, phase)
    local entity = row.source or row.entity
    local state = status_names[entity.status]
    local expected = {
        working = {working = true}, starved = {no_ingredients = true, fluid_ingredient_shortage = true, no_input_fluid = true},
        blocked = {fluid_production_overload = true, full_output = true}, unpowered = {no_power = true},
        disabled = {disabled_by_script = true}, deconstruction = {marked_for_deconstruction = true, disabled_by_script = true},
    }
    assert(expected[row.state][state], row.name .. " " .. row.state .. " got " .. state)
    if row.state == "working" then assert(row.advanced, row.name .. " did not advance") end
    if row.source then
        assert(row.entity.disabled_by_script == (row.state ~= "working"), "NSB beacon enable state")
    end
    return {name = row.name, phase = phase, expected = row.state, status = state, advanced = row.advanced,
        direction = row.entity.direction, no_modules = row.no_modules or false, unit = entity.unit_number}
end

local function screenshot(s, position, path, zoom, resolution)
    if not config.visual then return end
    for _, light in ipairs{{"day", 0}, {"night", 0.5}} do
        game.take_screenshot{surface = s, position = position, path = "cryo-mist/" .. path .. "-" .. light[1] .. ".png",
            zoom = zoom or 1.5, resolution = resolution or {384, 384}, daytime = light[2],
            show_gui = false, show_entity_info = false, hide_clouds = true, hide_fog = true,
            anti_alias = true, force_render = true}
    end
end

local function initialise()
    write(config.mode .. "-final", prototypes.mod_data["cryo-mist-qc"].data)
    if config.mode == "baseline" then return end
    storage.started, storage.rows, storage.results = game.tick, {}, {}
    storage.surface = surface("cryo-mist-qc", 192, 128)
    storage.primary = {}
    for i, name in ipairs{"ei-cooler", "ei-copper-beacon", "ei-iron-beacon"} do
        local states = name == "ei-cooler" and {"working", "starved", "blocked", "unpowered", "disabled"}
            or {"working", "starved", "deconstruction"}
        for j, state in ipairs(states) do
            local row = add_row(name, state, {-65 + (j - 1) * 18, -35 + (i - 1) * 20})
            if j == 1 then storage.primary[#storage.primary + 1] = row end
        end
        for j, direction in ipairs{4, 8, 12} do add_row(name, "working", {30 + j * 15, -35 + (i - 1) * 20}, direction) end
        if name ~= "ei-cooler" then add_row(name, "working", {5, -35 + (i - 1) * 20}, 0, true) end
    end
    for y = 0, 1 do for x = 0, 2 do
        add_row(x % 2 == 0 and "ei-copper-beacon" or "ei-iron-beacon", "working", {-8 + x * 4, 32 + y * 4})
    end end
    for _, row in ipairs(storage.rows) do feed(row) end
end
script.on_init(initialise)

local function init_scenes()
    storage.scene_generation = (storage.scene_generation or 0) + 1
    local snapshot = prototypes.mod_data["cryo-mist-qc"].data
    for i, name in ipairs{"ei-cooler", "ei-copper-beacon", "ei-iron-beacon"} do
        local s = surface("cryo-preview-" .. storage.scene_generation .. "-" .. i, 64, 64)
        local sim = snapshot[name][name == "ei-cooler" and "furnace" or "beacon"].factoriopedia_simulation
        local camera = {}
        local facade = setmetatable({surfaces = {[1] = s}, simulation = camera}, {__index = function(_, key) return game[key] end})
        local env = setmetatable({game = facade, storage = {}}, {__index = _G})
        assert(load(sim.init, "=cryo-scene:" .. name, "t", env))()
        scenes[#scenes + 1] = {name = name, surface = s, camera = camera,
            update = sim.update and assert(load(sim.update, "=cryo-update:" .. name, "t", env)),
            init_tick = game.tick, preroll = sim.init_update_count or 0}
    end
end

local function scene_check(scene)
    local body = assert(scene.surface.find_entity(scene.name, {0, 0}))
    local source = scene.name ~= "ei-cooler" and scene.surface.find_entity(scene.name .. "-source", {0, 0}) or body
    assert(source and source.valid, "Missing preview source")
    local recipe = source.get_recipe()
    assert(source.status == defines.entity_status.working, "Preview not working: " .. scene.name .. " " .. status_names[source.status]
        .. " recipe=" .. (recipe and recipe.name or "none") .. " fluids=" .. helpers.table_to_json(source.get_fluid_contents()))
    storage.results[#storage.results + 1] = {phase = "preview", name = scene.name, status = "working", helper = source.name}
    screenshot(scene.surface, scene.camera.camera_position, "preview/" .. scene.name, scene.camera.camera_zoom, {512, 384})
end

local function transition_report(phase)
    for _, row in ipairs(storage.primary) do
        storage.results[#storage.results + 1] = inspect(row, phase)
        screenshot(storage.surface, row.entity.position, "transitions/" .. row.name .. "-" .. phase)
    end
end

script.on_load(function() scenes = {} end)
local function tick(event)
    if config.mode == "baseline" then return end
    if not final_written then
        write(config.mode .. "-final", prototypes.mod_data["cryo-mist-qc"].data)
        game.forces.player.recipes["ei-liquid-nitrogen"].enabled = true
        final_written = true
    end
    if config.mode == "reload" and not loaded_checkpoint then
        assert(storage.reload_marker == "cold-mist-working-checkpoint", "Checkpoint marker lost")
        for _, row in ipairs(storage.primary) do inspect(row, "reload") end
        write("reload", {marker = storage.reload_marker, tick = event.tick})
        loaded_checkpoint = true
    end
    if #scenes == 0 then init_scenes() end
    local elapsed = event.tick - storage.started
    if config.visual and elapsed % 100 == 0 then write("visual-progress", {tick = event.tick, elapsed = elapsed}) end
    for _, row in ipairs(storage.rows) do feed(row) end
    for _, scene in ipairs(scenes) do
        if scene.update then scene.update() end
        if not scene.checked and event.tick - scene.init_tick == scene.preroll then
            scene_check(scene); scene.checked = true
        end
    end
    if elapsed == 200 then
        for i, row in ipairs(storage.rows) do
            storage.results[#storage.results + 1] = inspect(row, "steady")
            screenshot(storage.surface, row.entity.position, "states/" .. i .. "-" .. row.name .. "-" .. row.state)
        end
    end
    -- 61 samples cover every animation frame and the return to frame zero.
    if elapsed >= 300 and elapsed <= 700 then
        local index = math.floor((elapsed - 300) * 0.15)
        if index ~= storage.last_frame then
            storage.last_frame = index
            for _, row in ipairs(storage.primary) do
                screenshot(storage.surface, row.entity.position, string.format("loop/%s-%02d", row.name, index))
            end
            screenshot(storage.surface, {-4, 34}, string.format("loop/group-%02d", index), 1.5, {768, 512})
        end
    end
    if elapsed == 700 and not config.visual then
        storage.reload_marker = "cold-mist-working-checkpoint"
        if game.is_multiplayer() then game.server_save("cryo-mist-reload") end
    elseif elapsed == 701 and storage.reload_marker then
        transition_report("checkpoint")
    elseif elapsed == 750 then
        for _, row in ipairs(storage.primary) do
            row.state = "starved"
            local entity = row.source or row.entity
            entity.clear_fluid_inside(); entity.energy = 0
        end
    elseif elapsed == 810 then transition_report("input-lost")
    elseif elapsed == 811 then
        for _, row in ipairs(storage.primary) do row.state, row.advanced = "working", false end
    elseif elapsed == 900 then transition_report("input-restored")
    elseif elapsed == 901 then
        for _, row in ipairs(storage.primary) do
            if row.source then row.state = "deconstruction"; assert(row.entity.order_deconstruction("player"))
            else row.state = "disabled"; row.entity.disabled_by_script = true end
        end
    elseif elapsed == 950 then transition_report("disabled")
    elseif elapsed == 951 then
        for _, row in ipairs(storage.primary) do
            if row.source then
                row.entity.cancel_deconstruction("player")
                assert(not row.entity.to_be_deconstructed(), "Deconstruction did not cancel")
            else row.entity.disabled_by_script = false end
            row.state, row.advanced = "working", false
        end
    elseif elapsed == 1000 then transition_report("resumed")
    elseif elapsed == 1001 then
        local row = storage.primary[1]
        row.state, row.supply.power_production, row.supply.energy, row.entity.energy = "unpowered", 0, 0, 0
    elseif elapsed == 1050 then transition_report("power-lost")
    elseif elapsed == 1051 then
        local row = storage.primary[1]
        row.state, row.advanced, row.supply.power_production = "working", false, 1e9
    elseif elapsed == 1100 then transition_report("power-restored")
    elseif elapsed == 1101 then
        for i = 2, 3 do
            local row = storage.primary[i]
            row.removed = true
            row.entity.destroy{raise_destroy = true}
            assert(not row.source.valid, "Orphan source after beacon destruction")
            storage.results[#storage.results + 1] = {phase = "cleanup", name = row.name, helper_removed = true}
        end
    elseif elapsed == 1150 then
        write(config.mode .. "-runtime", {passed = true, checks = #storage.results, results = storage.results,
            reload_marker = storage.reload_marker, frames = (storage.last_frame or -1) + 1})
        if config.visual then game.set_wait_for_screenshots_to_finish() end
    end
end
script.on_event(defines.events.on_tick, function(event)
    local ok, message = pcall(tick, event)
    if not ok then
        write(config.mode .. "-error", {tick = event.tick, message = tostring(message)})
        error(message)
    end
end)
