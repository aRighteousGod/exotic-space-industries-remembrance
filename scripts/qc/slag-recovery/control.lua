-- Disposable acceptance mod: native crafting only, no shipping runtime changes.
local config = require("test-config")
local tech_name = "ei-productivity-slag-chunk-extraction"
local target = 2000

---@class SlagRecoveryCase
---@field machine LuaEntity
---@field recipe string
---@field levels integer
---@field fed integer
---@field totals table<string, number>
---@field previous_crafts integer
---@field researched boolean

local function check(value, message)
    storage.checks = (storage.checks or 0) + 1
    assert(value, "SLAG QC: "..message)
end

---@param case SlagRecoveryCase
local function check_retained(case)
    local machine = case.machine
    check(machine.valid and machine.get_recipe().name == case.recipe, "selected recipe retained "..case.recipe)
    local technology = machine.force.technologies[tech_name]
    local expected_level = case.levels == 5 and 5 or case.levels + 1
    check(technology.level == expected_level and technology.researched == case.researched, "research retained "..case.recipe.."/"..case.levels)
    local recipe_bonus = machine.force.recipes[case.recipe].productivity_bonus
    check(math.abs(recipe_bonus - case.levels * 0.1) < 0.00001,
        "native recipe research bonus "..case.recipe.."/"..case.levels.." actual="..recipe_bonus)
end

script.on_init(function()
    assert(config.baseline, "Create the baseline save first")
    local surface = game.create_surface("slag-recovery-qc", {width = 128, height = 128,
        autoplace_controls = {}, autoplace_settings = {entity = {treat_missing_as_default = false}}})
    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()
    local tiles = {}
    for x = -50, 50 do for y = -40, 40 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    surface.set_tiles(tiles)
    for _, entity in pairs(surface.find_entities_filtered({type = {"tree", "simple-entity", "unit", "unit-spawner"}})) do entity.destroy() end
    storage.cases = {}
    for column, level in ipairs({0, 1, 5}) do
        local force = game.create_force("slag-qc-"..level)
        local technology = force.technologies[tech_name]
        technology.level = level == 5 and 5 or level + 1
        if level == 5 then technology.researched = true end
        local row = 0
        for _, tier in ipairs({"sulfuric", "nitric", "morphium"}) do
            for _, suffix in ipairs({"", "-crushed"}) do
                row = row + 1
                local name = "ei-slag-extraction-"..tier..suffix
                force.recipes[name].enabled = true
                local machine = surface.create_entity({name = "slag-qc-purifier", position = {-40 + column * 20, -35 + row * 10}, force = force})
                check(machine and machine.valid, "created "..name)
                machine.set_recipe(name)
                machine.active = false
                local case = {machine = machine, recipe = name, levels = level, researched = technology.researched,
                    fed = 0, totals = {}, previous_crafts = 0}
                storage.cases[#storage.cases + 1] = case
                check_retained(case)
            end
        end
    end
    storage.baseline = true
    helpers.write_file("slag-final-data.json", helpers.table_to_json(prototypes.mod_data["slag-qc-final"].data), false)
end)

script.on_configuration_changed(function()
    storage.configuration_changes = (storage.configuration_changes or 0) + 1
end)

---@param case SlagRecoveryCase
local function collect(case)
    local machine = case.machine
    local recipe = prototypes.mod_data["slag-qc-final"].data.recipes[case.recipe]
    local output = machine.get_output_inventory()
    local crafts = machine.products_finished
    for _, product in ipairs(recipe.results) do
        local amount
        if product.type == "fluid" then
            amount = machine.get_fluid_count(product.name)
            machine.remove_fluid({name = product.name, amount = 100000})
        else
            amount = output.get_item_count(product.name)
            if product.name:find("-chunk$", 1) and (product.probability or 1) == 1 then
                local delta = crafts - case.previous_crafts
                check(amount >= delta * (product.amount or product.amount_min), "guaranteed common floor "..case.recipe.."/"..product.name)
            end
        end
        case.totals[product.name] = (case.totals[product.name] or 0) + amount
    end
    output.clear()
    case.previous_crafts = crafts
end

local function finish()
    local results = {}
    for _, case in ipairs(storage.cases) do
        local machine = case.machine
        local total_crafts = machine.products_finished
        check(case.fed == target and math.abs(total_crafts - target * (1 + case.levels * 0.1)) <= 1, "native bonus crafts "..case.recipe)
        for _, product in ipairs(prototypes.mod_data["slag-qc-final"].data.recipes[case.recipe].results) do
            local chunks = product.name:find("-chunk$", 1) ~= nil
            local samples = chunks and total_crafts or target
            local lo, hi = product.amount or product.amount_min, product.amount or product.amount_max
            local p = product.probability or 1
            local mean = p * (lo + hi) / 2
            local variance = p * (((hi - lo + 1)^2 - 1) / 12 + ((lo + hi) / 2)^2) - mean^2
            local tolerance = 6 * math.sqrt(samples * variance) + 2
            check(math.abs(case.totals[product.name] - samples * mean) <= tolerance, "product mean / no waste bonus "..case.recipe.."/"..product.name.."/"..case.levels)
        end
        results[#results + 1] = {recipe = case.recipe, levels = case.levels, base_crafts = case.fed,
            total_crafts = total_crafts, recipe_bonus = machine.force.recipes[case.recipe].productivity_bonus,
            machine_bonus = machine.productivity_bonus, products = case.totals}
    end
    storage.done = true
    helpers.write_file("slag-runtime.json", helpers.table_to_json({checks = storage.checks, cases = results, upgrade = true}), false)
end

script.on_event(defines.events.on_tick, function(event)
    if config.baseline then return end
    if config.reload then
        if storage.reload_reported then return end
        check(storage.done and storage.save_requested, "candidate checkpoint loaded")
        for _, case in ipairs(storage.cases) do check_retained(case) end
        helpers.write_file("slag-reload.json", helpers.table_to_json({checks = storage.checks, retained = true, cases = #storage.cases}), false)
        storage.reload_reported = true
        return
    end
    if storage.done then
        if game.is_multiplayer() and not storage.save_requested then
            storage.save_requested = true
            game.server_save("slag-recovery-checkpoint")
        end
        return
    end
    if not storage.started then
        check(storage.baseline and (storage.configuration_changes or 0) > 0, "pre-change save admitted")
        for _, case in ipairs(storage.cases) do
            check_retained(case)
            check(case.machine.get_module_inventory().insert({name = "productivity-module-3", count = 1}) == 0, "productivity module rejected "..case.recipe)
            case.machine.active = true
        end
        storage.started = event.tick
        if game.is_multiplayer() then game.speed = 100 end
        helpers.write_file("slag-final-data.json", helpers.table_to_json(prototypes.mod_data["slag-qc-final"].data), false)
    end
    local complete = true
    for _, case in ipairs(storage.cases) do
        collect(case)
        local machine = case.machine
        local input = machine.get_inventory(defines.inventory.assembling_machine_input)
        if case.fed < target and not machine.is_crafting() and input.is_empty() then
            for _, ingredient in ipairs(prototypes.mod_data["slag-qc-final"].data.recipes[case.recipe].ingredients) do
                local amount = ingredient.type == "fluid" and machine.insert_fluid({name = ingredient.name, amount = ingredient.amount})
                    or machine.insert({name = ingredient.name, count = ingredient.amount})
                check(amount == ingredient.amount, "exact batch feed "..case.recipe.."/"..ingredient.name)
            end
            case.fed = case.fed + 1
        end
        if case.fed < target or machine.is_crafting() or not input.is_empty() then complete = false end
    end
    assert(event.tick - storage.started < 29000, "SLAG QC: crafting timeout")
    if complete then finish() end
end)
