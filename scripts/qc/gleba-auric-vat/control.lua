local config = require("test-config")
local tech_name = "ei-productivity-auric-cyst-washing"
local recipe_name = "ei-auric-cyst-washing"
local target_crafts = 1000

local function check(value, message)
    storage.checks = (storage.checks or 0) + 1
    assert(value, "AURIC RUNTIME: "..message)
end
---@param force LuaForce
---@param name string
local function research_tree(force, name)
    local technology = force.technologies[name]
    if technology.researched then return end
    for prerequisite in pairs(technology.prerequisites) do research_tree(force, prerequisite) end
    technology.researched = true
end

script.on_init(function()
    if config.baseline then
        research_tree(game.forces.player, "ei-auric-marsh-inoculation")
        research_tree(game.forces.player, "agricultural-science-pack")
        storage.baseline = true
        remote.call("ei-gleba-vat-qc", "prepare")
    end
end)
script.on_configuration_changed(function() storage.configuration_changes = (storage.configuration_changes or 0) + 1 end)

local function setup()
    if game.is_multiplayer() then game.speed = 100 end
    local force = game.forces.player
    check(storage.baseline and (storage.configuration_changes or 0) > 0, "pre-feature save admitted")
    check(force.technologies["ei-auric-marsh-inoculation"].researched and force.technologies["agricultural-science-pack"].researched, "old research preserved")
    check(force.technologies[tech_name].level == 1 and not force.technologies[tech_name].researched, "new technology unresearched")
    check(force.add_research(tech_name), "available on existing save")
    force.cancel_current_research()
    local gate = game.create_force("auric-gate-qc")
    gate.technologies["ei-auric-marsh-inoculation"].researched = true
    check(not gate.add_research(tech_name), "agricultural prerequisite enforced")
    gate.technologies["ei-auric-marsh-inoculation"].researched = false
    gate.technologies["agricultural-science-pack"].researched = true
    check(not gate.add_research(tech_name), "auric prerequisite enforced")
    gate.technologies["ei-auric-marsh-inoculation"].researched = true
    check(gate.add_research(tech_name), "both prerequisites accepted")
    gate.research_progress = 1

    storage.fields = remote.call("ei-gleba-vat-qc", "run")
    local surface = game.create_surface("auric-productivity-qc", {width = 96, height = 64, autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.set_property("pressure", 2000)
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = -40, 40 do for y = -20, 20 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered({type = {"tree", "simple-entity", "unit", "unit-spawner"}})) do entity.destroy() end
    storage.cases = {}
    local module_bonus = prototypes.mod_data["auric-qc-final"].data.module_bonus
    for index, row in ipairs({{"zero", 0, 0}, {"ten", 10, 0}, {"cap", 30, 0}, {"above-cap", 40, 0}, {"modules", 0, 4}, {"stacked", 10, 4}, {"modules-cap", 29, 4}}) do
        local test_force = game.create_force("auric-"..row[1])
        test_force.technologies[tech_name].level = row[2] + 1
        test_force.recipes[recipe_name].enabled = true
        local machine = surface.create_entity({name = "auric-qc-purifier", position = {-35 + index * 10, 0}, force = test_force})
        check(machine and machine.valid, "machine "..row[1])
        machine.set_recipe(recipe_name)
        if row[3] > 0 then
            check(machine.get_module_inventory().insert({name = "productivity-module-3", count = row[3]}) == row[3], "modules admitted "..row[1])
        end
        storage.cases[#storage.cases + 1] = {name = row[1], machine = machine, levels = row[2], fed = 0,
            bonus = math.min(3, row[2] * 0.1 + row[3] * module_bonus), gold = 0, slag = 0, dirty = 0}
    end
    storage.started = game.tick
    helpers.write_file("auric-final-data.json", helpers.table_to_json(prototypes.mod_data["auric-qc-final"].data), false)
end

---@param case {machine: LuaEntity, gold: number, slag: number, dirty: number}
local function collect(case)
    local machine = case.machine
    local output = machine.get_output_inventory()
    case.gold = case.gold + output.get_item_count("ei-gold-chunk")
    case.slag = case.slag + output.get_item_count("spoilage")
    output.clear()
    case.dirty = case.dirty + machine.get_fluid_count("ei-dirty-water")
    machine.remove_fluid({name = "ei-dirty-water", amount = 100000})
end

---@param player LuaPlayer
local function show_research(player)
    player.set_controller({type = defines.controllers.god})
    player.gui.screen.clear()
    player.gui.center.clear()
    player.opened = nil
    player.open_technology_gui(tech_name)
    game.tick_paused = false
    local resolution = player.display_resolution
    log("AURIC VISUAL: research open; GUI="..tostring(player.opened_gui_type).."; display="..resolution.width.."x"..resolution.height)
    helpers.write_file("auric-visual.json", helpers.table_to_json({resolution = resolution, gui_type = player.opened_gui_type}), false)
end

script.on_event(defines.events.on_player_created, function(event)
    if config.visual then game.tick_paused = false end
end)
script.on_event(defines.events.on_player_joined_game, function(event)
    if config.visual then
        game.speed = 1
        game.tick_paused = false
        storage.visual_frames = 0
        game.get_player(event.player_index).set_controller({type = defines.controllers.god})
    end
end)

script.on_event(defines.events.on_tick, function(event)
    if config.baseline then return end
    if config.visual then
        local player = game.get_player(1)
        if not player then return end
        storage.visual_frames = (storage.visual_frames or 0) + 1
        game.tick_paused = false
        if storage.visual_frames == 60 then remote.call("ei-gleba-vat-qc", "visual", player.index) end
        if storage.visual_frames == 90 then game.take_screenshot({player = player, resolution = {player.display_resolution.width, player.display_resolution.height}, path = "auric-vat.png", show_gui = true, force_render = true}) end
        if storage.visual_frames == 120 then show_research(player) end
        if storage.visual_frames == 150 then game.take_screenshot({player = player, resolution = {player.display_resolution.width, player.display_resolution.height}, path = "auric-research.png", show_gui = true, force_render = true}) end
        return
    end
    if config.reload then
        if storage.reload_reported then return end
        check(storage.done and storage.save_requested, "native checkpoint loaded")
        check(remote.call("ei-gleba-vat-qc", "verify_checkpoint", storage.field_checkpoint), "field state retained")
        for _, case in ipairs(storage.cases) do
            check(case.machine.valid and case.machine.force.technologies[tech_name].level == case.levels + 1, "levels persist "..case.name)
            check(case.machine.get_module_inventory().get_item_count("productivity-module-3") == ((case.name == "modules" or case.name == "stacked" or case.name == "modules-cap") and 4 or 0), "modules persist "..case.name)
        end
        helpers.write_file("auric-reload.json", helpers.table_to_json({checks = storage.checks, retained = true}), false)
        storage.reload_reported = true
        return
    end
    if storage.done then
        if game.is_multiplayer() and not storage.save_requested then
            storage.save_requested = true
            storage.field_checkpoint = remote.call("ei-gleba-vat-qc", "checkpoint")
            game.server_save("gleba-auric-vat-checkpoint")
        end
        return
    end
    if not storage.started then setup() end
    local complete = remote.call("ei-gleba-vat-qc", "service_cycle")
    for _, case in ipairs(storage.cases) do
        collect(case)
        local machine = case.machine
        if case.fed < target_crafts and machine.get_inventory(defines.inventory.assembling_machine_input).is_empty() then
            machine.insert({name = "ei-auric-cyst", count = 1})
            machine.insert_fluid({name = "sulfuric-acid", amount = 15})
            machine.insert_fluid({name = "steam", amount = 100, temperature = 500})
            case.fed = case.fed + 1
        end
        if case.fed < target_crafts or machine.is_crafting() or not machine.get_inventory(defines.inventory.assembling_machine_input).is_empty() then complete = false end
    end
    if (event.tick - storage.started) % 1000 == 0 then
        local progress = {}
        for _, case in ipairs(storage.cases) do
            progress[#progress + 1] = {name = case.name, fed = case.fed, crafts = case.machine.products_finished,
                speed = case.machine.crafting_speed, status = case.machine.status, gold = case.gold, slag = case.slag, dirty = case.dirty}
        end
        helpers.write_file("auric-progress.json", helpers.table_to_json(progress), false)
    end
    assert(event.tick - storage.started < 29000, "AURIC RUNTIME: crafting timeout")
    if not complete then return end
    check(game.forces["auric-gate-qc"].technologies[tech_name].level == 2, "normal research completes")
    local results = {}
    for _, case in ipairs(storage.cases) do
        local expected_gold = target_crafts * 2 * (1 + case.bonus)
        -- products_finished includes bonus crafts; consumed batches establish the base count.
        check(case.fed == target_crafts and math.abs(case.machine.products_finished - target_crafts * (1 + case.bonus)) <= 1.000001, "base and bonus crafts "..case.name)
        check(math.abs(case.gold / expected_gold - 1) < 0.05, "gold mean within 5% "..case.name)
        check(case.slag >= 0 and case.slag <= 3000, "slag base range "..case.name)
        check(case.dirty >= 5000 and case.dirty <= 25000, "dirty water base range "..case.name)
        -- Spoilage is Bernoulli(0.5) times uniform 1..3: variance is 4/3 per batch.
        check(math.abs(case.slag - target_crafts) < 5 * math.sqrt(4 * target_crafts / 3)
            and math.abs(case.dirty / (target_crafts * 15) - 1) < 0.05, "waste means unchanged "..case.name)
        results[#results + 1] = {name = case.name, base_crafts = case.fed, total_crafts = case.machine.products_finished, expected_bonus = case.bonus,
            machine_bonus = case.machine.productivity_bonus, gold = case.gold, spoilage = case.slag, dirty_water = case.dirty}
    end
    storage.fields = remote.call("ei-gleba-vat-qc", "report")
    helpers.write_file("auric-runtime.json", helpers.table_to_json({checks = storage.checks, cases = results, fields = storage.fields, upgrade = true}), false)
    storage.done = true
end)
