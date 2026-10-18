local config = require("test-config")
if config.visual then require("visual"); return end
local cases = require("cases")

local function research_tree(force, name)
    local technology = force.technologies[name]
    if technology.researched then return end
    for prerequisite in pairs(technology.prerequisites) do research_tree(force, prerequisite) end
    technology.researched = true
end

local function check(value, message)
    storage.checks = (storage.checks or 0) + 1
    assert(value, "CRYO RUNTIME: "..message)
end

local function setup()
    local force = game.forces.player
    if config.upgrade then
        check(storage.cryo_baseline, "loaded the pre-change save")
        check(force.technologies["ei-oxygen-cryo-container"].researched and force.technologies["ei-cryo-container"].researched, "legacy nitrogen/oxygen research preserved")
        check(force.recipes["ei-fill-cryo-container-nitrogen"].enabled and force.recipes["ei-fill-cryo-container-oxygen"].enabled, "legacy recipes preserved")
    end
    for _, family in ipairs(cases.families) do
        local name = "ei-"..family[1].."-cryo-container"
        check(not force.technologies[name].researched, "new technology remains unresearched: "..name)
        research_tree(force, family[2])
        research_tree(force, "ei-cryo-container")
        check(force.add_research(name), "research available with both prerequisites: "..name)
        force.cancel_current_research()
        force.technologies[name].researched = true
        local fresh = game.create_force("cryo-test-"..family[1])
        fresh.technologies["ei-cryo-container"].researched = true
        check(not fresh.add_research(name), "milestone gate: "..name)
        fresh.technologies["ei-cryo-container"].researched = false
        research_tree(fresh, family[2])
        fresh.technologies["ei-cryo-container"].researched = false
        check(not fresh.add_research(name), "container gate: "..name)
    end
    local surface = game.create_surface("cryo-qc", {width = 128, height = 128, autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = -48, 48 do for y = -40, 40 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered({type = {"tree", "simple-entity", "unit", "unit-spawner"}})) do entity.destroy() end
    storage.machines = {}
    for index, row in ipairs(cases.fluids) do
        local name = "ei-fill-cryo-container-"..row[2]
        check(force.recipes[name].enabled, "fill unlock: "..row[2])
        check(force.recipes["ei-empty-cryo-container-"..row[2]].enabled, "empty unlock: "..row[2])
        local pair = {row = row}
        for side, wrong in ipairs({false, true}) do
            -- The engine clamps fluids whose maximum equals their default temperature.
            -- Only inject a distinct temperature when the fluid can actually represent it.
            if not wrong or prototypes.fluid[row[1]].max_temperature > row[3] then
                local machine = surface.create_entity({name = "assembling-machine-3", position = {-40 + index * 8, wrong and 12 or 0}, force = force})
                check(machine ~= nil, "native assembler created")
                machine.set_recipe(name)
                machine.insert({name = "ei-empty-cryo-container", count = 1})
                local input
                for i = 1, #machine.fluidbox do
                    if machine.fluidbox.get_prototype(i).production_type == "input" then input = i; break end
                end
                check(input ~= nil, "assembler fluid input")
                machine.fluidbox[input] = {name = row[1], amount = config.capacity, temperature = row[3] + (wrong and 1 or 0)}
                if not wrong then
                    check(machine.fluidbox[input] and math.abs(machine.fluidbox[input].amount - config.capacity) < 0.001,
                        "assembler accepts complete capacity: "..row[2].." actual="..tostring(machine.fluidbox[input] and machine.fluidbox[input].amount))
                end
                pair[side] = machine
            end
        end
        storage.machines[#storage.machines + 1] = pair
    end
    storage.started = game.tick
    helpers.write_file("cryo-final-data.json", helpers.table_to_json(prototypes.mod_data["cryo-qc-final"].data), false)
end

script.on_init(function()
    if config.baseline then
        for _, name in ipairs({"ei-oxygen-cryo-container", "space-platform-thruster", "electromagnetic-plant", "planet-discovery-aquilo", "ei-auric-precipitation"}) do
            research_tree(game.forces.player, name)
        end
        storage.cryo_baseline = true
        helpers.write_file("cryo-baseline.json", helpers.table_to_json({baseline = true, tick = game.tick}), false)
    end
end)

script.on_configuration_changed(function() storage.started = nil end)
script.on_event(defines.events.on_tick, function(event)
    if config.baseline or storage.done then return end
    if not storage.started then setup() end
    local elapsed = event.tick - storage.started
    for _, pair in ipairs(storage.machines) do
        pair[1].energy = 1000000000
        if pair[2] then pair[2].energy = 1000000000 end
    end
    if elapsed == 240 then
        for _, pair in ipairs(storage.machines) do
            local row, machine, wrong = pair.row, pair[1], pair[2]
            check(machine.products_finished == 1, "filled exactly once: "..row[2])
            if wrong then check(wrong.products_finished == 0 and wrong.get_item_count("ei-empty-cryo-container") == 1, "wrong temperature rejected: "..row[2]) end
            check(machine.get_output_inventory().remove({name = "ei-cryo-container-"..row[2], count = 1}) == 1, "filled container output: "..row[2])
            check(machine.get_fluid_count(row[1]) < 0.001, "all input fluid consumed: "..row[2])
            machine.set_recipe("ei-empty-cryo-container-"..row[2])
            machine.insert({name = "ei-cryo-container-"..row[2], count = 1})
        end
    elseif elapsed == 480 then
        local roundtrips = {}
        for _, pair in ipairs(storage.machines) do
            local row, machine = pair.row, pair[1]
            check(machine.products_finished == 2, "emptied exactly once: "..row[2])
            check(machine.get_output_inventory().get_item_count("ei-empty-cryo-container") == 1, "one empty returned: "..row[2])
            check(math.abs(machine.get_fluid_count(row[1]) - config.capacity) < 0.001, "fluid quantity conserved: "..row[2])
            local temperature
            for i = 1, #machine.fluidbox do if machine.fluidbox[i] then temperature = machine.fluidbox[i].temperature end end
            check(math.abs(temperature - row[3]) < 0.001, "fluid temperature conserved: "..row[2])
            roundtrips[#roundtrips + 1] = {fluid = row[1], amount = config.capacity, temperature = temperature}
        end
        helpers.write_file("cryo-runtime.json", helpers.table_to_json({checks = storage.checks, capacity = config.capacity, upgrade = config.upgrade, roundtrips = roundtrips}), false)
        storage.done = true
    end
end)
