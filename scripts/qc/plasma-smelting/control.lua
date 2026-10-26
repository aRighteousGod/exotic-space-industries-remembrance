local config = require("test-config")
local rows = require("cases")
local util = require("__core__.lualib.util")
local target_crafts = 100

local function check(value, label)
    storage.checks = (storage.checks or 0) + 1
    assert(value, "PLASMA RUNTIME: "..label)
end
local equal = util.table.compare
---@param force LuaForce
local function research_tree(force, name)
    local technology = force.technologies[name]
    if technology.researched then return end
    for prerequisite in pairs(technology.prerequisites) do research_tree(force, prerequisite) end
    technology.researched = true
end
local function write(name, value)
    helpers.write_file(name, helpers.table_to_json(value), false)
end
local function create_case(surface, force, row, plasma, index)
    local machine = surface.create_entity({name = plasma and "ei-plasma-heater" or "ei-arc-furnace",
        position = {-48 + (index % 12) * 8, -32 + math.floor(index / 12) * 10}, force = force})
    check(machine and machine.valid, "create native furnace")
    return {machine = machine, row = row, plasma = plasma, output = 0, slag = 0, fed = 0, before = machine.products_finished}
end
local function collect(case)
    local machine, row = case.machine, case.row
    local amount = machine.get_fluid_count(row[3])
    if amount > 0 then
        for index = 1, #machine.fluidbox do
            local fluid = machine.fluidbox[index]
            if fluid and fluid.name == row[3] then check(math.abs(fluid.temperature - row[9]) < 0.001, "output temperature "..row[1]) end
        end
    end
    case.output = case.output + amount
    machine.remove_fluid({name = row[3], amount = amount})
    local output = machine.get_output_inventory()
    case.slag = case.slag + output.get_item_count("ei-slag")
    output.clear()
end
local function feed(case, target)
    local machine, row = case.machine, case.row
    machine.energy = 1000000000
    collect(case)
    if case.fed < target and machine.get_inventory(defines.inventory.furnace_source).is_empty() then
        check(machine.insert({name = row[2], count = row[4]}) == row[4], "feed "..row[1])
        case.fed = case.fed + 1
    end
    local recipe = machine.get_recipe()
    if recipe then
        local upgraded = "ei-plasma-molten-"..row[1]
        local expected = case.plasma and prototypes.recipe[upgraded] and upgraded or "ei-molten-"..row[1]
        check(recipe.name == expected, "automatic selection "..expected.." got "..recipe.name)
        case.selected = true
    end
    return case.fed == target and not machine.is_crafting() and machine.get_inventory(defines.inventory.furnace_source).is_empty()
end

script.on_init(function()
    if not config.baseline then return end
    local force = game.forces.player
    research_tree(force, "ei-plasma-heater")
    research_tree(force, "ei-neodym-refining")
    force.technologies["ei-productivity-pure-ore-smelting"].level = 2
    local surface = game.create_surface("plasma-smelting-qc", {width = 128, height = 128,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = -60, 60 do for y = -60, 60 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered({type = {"tree", "simple-entity", "unit", "unit-spawner"}})) do entity.destroy() end
    storage.cases = {}
    for _, plasma in ipairs({false, true}) do
        for _, row in ipairs(rows) do storage.cases[#storage.cases + 1] = create_case(surface, force, row, plasma, #storage.cases) end
    end
    storage.original = table.deepcopy(prototypes.mod_data["plasma-qc-final"].data.snapshot)
    storage.baseline = true
end)
script.on_configuration_changed(function() storage.configuration_changes = (storage.configuration_changes or 0) + 1 end)

local function compare_final_data()
    local final = prototypes.mod_data["plasma-qc-final"].data
    local old = storage.original
    for name, recipe in pairs(old.recipes) do
        local expected = table.deepcopy(recipe)
        if prototypes.recipe["ei-plasma-"..name:sub(4)] then expected.category = "ei-arc-smelting" end
        check(equal(expected, final.snapshot.recipes[name]), "preserved recipe "..name)
    end
    for name, machine in pairs(old.machines) do
        local expected = table.deepcopy(machine)
        local category = name == "ei-arc-furnace" and "ei-arc-smelting" or "ei-plasma-smelting"
        local present = false
        for _, existing in ipairs(expected.crafting_categories) do if existing == category then present = true end end
        if not present then expected.crafting_categories[#expected.crafting_categories + 1] = category end
        check(equal(expected, final.snapshot.machines[name]), "machine stats and presentation "..name)
    end
    for name, technology in pairs(old.technologies) do
        local current = table.deepcopy(final.snapshot.technologies[name])
        local effects = {}
        for _, effect in ipairs(current.effects) do
            if not (effect.recipe and effect.recipe:find("^ei%-plasma%-molten%-") and not old.recipes[effect.recipe]) then effects[#effects + 1] = effect end
        end
        current.effects = effects
        check(equal(technology, current), "research unchanged "..name)
    end
    write("plasma-final-data.json", final)
end

local function setup_candidate(tick)
    check(storage.baseline_saved and (storage.configuration_changes or 0) > 0, "pre-change save loaded")
    check(game.forces.player.technologies["ei-plasma-heater"].researched, "heater research retained")
    check(game.forces.player.technologies["ei-productivity-pure-ore-smelting"].level == 2, "productivity research retained")
    compare_final_data()
    for _, case in ipairs(storage.cases) do
        local machine, row = case.machine, case.row
        check(machine.valid and machine.unit_number == case.identity, "existing identity")
        check(machine.get_inventory(defines.inventory.furnace_source).get_item_count(row[2]) == row[4] * 3, "existing input retained")
        check(machine.get_output_inventory().get_item_count("ei-slag") == 2, "existing slag retained")
        local temperature
        for index = 1, #machine.fluidbox do
            local fluid = machine.fluidbox[index]
            if fluid and fluid.name == row[3] then temperature = fluid.temperature end
        end
        check(math.abs(machine.get_fluid_count(row[3]) - 7) < 0.001 and temperature == row[9], "existing fluid retained")
        check(machine.force.recipes["ei-plasma-molten-"..row[1]].enabled, "existing research unlock refreshed")
        machine.get_inventory(defines.inventory.furnace_source).clear()
        collect(case)
        machine.active = true
        case.fed, case.output, case.slag, case.selected = 0, 0, 0, false
        case.before = machine.products_finished
        case.bonus = row[8]
    end
    local surface = game.surfaces["plasma-smelting-qc"]
    for _, level in ipairs({0, 100}) do
        local force = game.create_force("plasma-qc-"..level)
        research_tree(force, "ei-arc-furnace")
        research_tree(force, "ei-neodym-refining")
        for _, row in ipairs(rows) do check(not force.recipes["ei-plasma-molten-"..row[1]].enabled, "locked before heater research") end
        research_tree(force, "ei-plasma-heater")
        if level > 0 then force.technologies["ei-productivity-pure-ore-smelting-black-hole"].level = level + 1 end
        for _, plasma in ipairs({false, true}) do
            for _, row in ipairs(rows) do
                check(force.recipes["ei-plasma-molten-"..row[1]].enabled, "new research unlock")
                local case = create_case(surface, force, row, plasma, #storage.cases)
                case.bonus = level > 0 and 3 or 0
                storage.cases[#storage.cases + 1] = case
            end
        end
    end
    storage.started = tick
end

script.on_event(defines.events.on_tick, function(event)
    if game.is_multiplayer() then game.speed = 20 end
    if config.baseline then
        if storage.baseline_saved then return end
        local done = true
        for _, case in ipairs(storage.cases) do if not feed(case, 1) then done = false end end
        if not done then assert(event.tick < 600, "baseline crafting timeout"); return end
        for _, case in ipairs(storage.cases) do
            local machine, row = case.machine, case.row
            check(case.selected and machine.products_finished > 0, "pre-change machine operated")
            machine.active = false
            collect(case)
            machine.insert({name = row[2], count = row[4] * 3})
            machine.get_output_inventory().insert({name = "ei-slag", count = 2})
            machine.insert_fluid({name = row[3], amount = 7, temperature = row[9]})
            case.identity = machine.unit_number
        end
        storage.baseline_saved = true
        write("plasma-baseline.json", {passed = true, checks = storage.checks, machines = #storage.cases})
        game.server_save("plasma-baseline")
        return
    end
    if config.reload then
        if storage.reload_reported then return end
        check(storage.done and storage.save_requested, "checkpoint loaded")
        for _, case in ipairs(storage.cases) do
            check(case.machine.valid and case.machine.products_finished == case.finished, "machine and production retained")
            check(case.machine.force.recipes["ei-plasma-molten-"..case.row[1]].enabled, "unlock retained on reload")
            local recipe_name = (case.plasma and "ei-plasma-molten-" or "ei-molten-")..case.row[1]
            check(math.abs(math.min(3, case.machine.force.recipes[recipe_name].productivity_bonus) - case.bonus) < 0.00001, "productivity retained on reload")
        end
        check(game.forces.player.technologies["ei-productivity-pure-ore-smelting"].level == 2, "research retained on reload")
        write("plasma-reload.json", {passed = true, checks = storage.checks, machines = #storage.cases})
        storage.reload_reported = true
        return
    end
    if storage.done then
        if game.is_multiplayer() and not storage.save_requested then
            storage.save_requested = true
            game.server_save("plasma-checkpoint")
        end
        return
    end
    if not storage.started then setup_candidate(event.tick) end
    local done = true
    for _, case in ipairs(storage.cases) do if not feed(case, target_crafts) then done = false end end
    if not done then
        if (event.tick - storage.started) % 500 == 0 then
            local progress = {}
            for _, case in ipairs(storage.cases) do progress[#progress + 1] = {recipe = case.row[1], machine = case.machine.name, fed = case.fed, output = case.output, status = case.machine.status} end
            write("plasma-progress.json", progress)
        end
        assert(event.tick - storage.started < 16000, "native crafting timeout")
        return
    end
    local results = {}
    for _, case in ipairs(storage.cases) do
        collect(case)
        local amount = case.plasma and case.row[6] or case.row[5]
        local expected = target_crafts * amount * (1 + case.bonus)
        -- A fractional bonus bar may carry over from the pre-change craft.
        check(math.abs(case.output - expected) <= amount + 0.01, "measured yield "..case.machine.name.." "..case.row[1])
        check(case.selected, "native selection observed")
        if case.plasma then check(case.slag == 0, "no plasma slag") end
        local recipe_name = (case.plasma and "ei-plasma-molten-" or "ei-molten-")..case.row[1]
        local research_bonus = case.machine.force.recipes[recipe_name].productivity_bonus
        check(math.abs(math.min(3, research_bonus) - case.bonus) < 0.00001, "native recipe productivity bonus")
        case.finished = case.machine.products_finished
        results[#results + 1] = {machine = case.machine.name, recipe = case.row[1], bonus = case.bonus, output = case.output, expected = expected, slag = case.slag}
    end
    storage.done = true
    write("plasma-runtime.json", {passed = true, checks = storage.checks, cases = results, prechange_machines = #rows * 2, data_checks = prototypes.mod_data["plasma-qc-final"].data.checks})
end)
