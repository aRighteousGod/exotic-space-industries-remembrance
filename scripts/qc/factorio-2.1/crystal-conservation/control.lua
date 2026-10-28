-- Native per-craft evidence with one exact input batch supplied at a time.
-- Original recipes retain productivity eligibility; stress copies enable it.
-- A real server freezes the 501st craft after native consumption, saves, and
-- requires an actual load before continuing. Benchmark mode records no save claim.
local loaded = false
local HIGH, LOW = "ei-high-energy-crystal", "ei-energy-crystal"
local function check(ok, message) assert(ok, "CRYSTAL QC: " .. message) end
local function inventory_rows(inventory)
    local rows = {}
    for _, item in pairs(inventory.get_contents()) do
        rows[#rows + 1] = item.name .. "/" .. item.quality .. "/" .. item.count
    end
    table.sort(rows)
    return rows
end
local function snapshot(machine)
    local fluids = {}
    for i = 1, machine.fluids_count do fluids[i] = machine.get_fluid(i) or false end
    return {input = inventory_rows(machine.get_inventory(defines.inventory.crafter_input)),
        output = inventory_rows(machine.get_inventory(defines.inventory.crafter_output)), fluids = fluids,
        progress = machine.crafting_progress, bonus = machine.bonus_progress,
        result_quality = machine.result_quality and machine.result_quality.name,
        products = machine.products_finished}
end
local function crystal_counts(inventory)
    local high, low, quality = 0, 0, 0
    for _, stack in pairs(inventory.get_contents()) do
        if stack.name == HIGH then high = high + stack.count end
        if stack.name == LOW then low = low + stack.count end
        if (stack.name == HIGH or stack.name == LOW) and stack.quality ~= "normal" then quality = quality + stack.count end
    end
    return high, low, quality
end
local function seed(job)
    local machine, input = job.machine, job.machine.get_inventory(defines.inventory.crafter_input)
    check(input.is_empty(), job.name .. " input residue before next batch")
    local fluid_index = 0
    for _, ingredient in pairs(prototypes.recipe[job.recipe].ingredients) do
        if ingredient.type == "item" then
            check(input.insert{name = ingredient.name, count = ingredient.amount, quality = "normal"} == ingredient.amount, job.name .. " input insertion")
        else
            fluid_index = fluid_index + 1
            local temperature = ingredient.minimum_temperature or prototypes.fluid[ingredient.name].default_temperature
            check(machine.set_fluid(fluid_index, {name = ingredient.name, amount = ingredient.amount, temperature = temperature}) == ingredient.amount, job.name .. " fluid insertion")
        end
    end
    job.phase = "crafting"
    job.started = game.tick
end
script.on_init(function()
    game.speed = 20
    -- Inserted modules do not unlock quality progression for a fresh force.
    -- Unlock all native tiers so the fixture exercises actual quality rolls.
    for name in pairs(prototypes.quality) do game.forces.player.unlock_quality(name) end
    local names = {}
    for name in pairs(prototypes.recipe) do
        if name:find("^esir%-qc%-productivity%-") then names[#names + 1] = name:sub(#"esir-qc-productivity-" + 1) end
    end
    table.sort(names)
    storage.jobs = {}
    local surface = game.create_surface("esir-crystal-qc", {width = 256, height = 256})
    surface.request_to_generate_chunks({0, 0}, 4)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities_filtered{force = "enemy"}) do entity.destroy() end
    for index, name in ipairs(names) do
        for mode_index, mode in ipairs({"original", "productivity"}) do
            local recipe = mode == "original" and name or ("esir-qc-productivity-" .. name)
            game.forces.player.recipes[recipe].enabled = true
            local position = {x = (index % 6) * 10 - 30, y = math.floor((index - 1) / 6) * 20 + mode_index * 8 - 45}
            local machine = surface.create_entity{name = "esir-qc-crystal-" .. mode .. "-" .. index, position = position, force = "player"}
            check(machine ~= nil, "create " .. name)
            machine.set_recipe(recipe)
            local modules = machine.get_module_inventory()
            local productivity = modules.insert{name = "productivity-module-3", count = 2}
            check(modules.insert{name = "quality-module-3", count = 2} == 2, name .. " quality module insertion")
            if mode == "productivity" then check(productivity == 2, name .. " productivity module insertion") end
            machine.bonus_progress = 0.95
            local job = {name = name, recipe = recipe, mode = mode, machine = machine, crafts = 0,
                high = 0, ordinary = 0, quality_returns = 0, phase = "ready", productivity_modules = productivity}
            storage.jobs[#storage.jobs + 1] = job
        end
    end
    storage.version = script.active_mods.base
end)
script.on_load(function() loaded = true end)
script.on_event(defines.events.on_tick, function(event)
    if not storage.started then game.speed = 20; storage.started = true end
    if storage.done then
        if loaded then
            helpers.write_file("crystal-second-reload.json", helpers.table_to_json{passed = true, tick = event.tick, jobs = #storage.jobs}, false)
        end
        loaded = false
        return
    end
    if storage.awaiting_checkpoint then
        if not loaded then return end
        for _, job in ipairs(storage.jobs) do
            check(helpers.table_to_json(snapshot(job.machine)) == job.snapshot, job.name .. " native in-progress state changed on reload")
            job.machine.disabled_by_script = false
            job.phase = "crafting"
            job.started = event.tick
        end
        storage.awaiting_checkpoint = false
        storage.reloaded_midcraft = true
    end
    loaded = false
    local completed, checkpoint = 0, 0
    for _, job in ipairs(storage.jobs) do
        local machine, output = job.machine, job.machine.get_inventory(defines.inventory.crafter_output)
        if job.phase == "ready" then
            seed(job)
            if job.crafts == 100 then
                for i = 1, #output do output[i].set_stack{name = HIGH, count = prototypes.item[HIGH].stack_size} end
                job.blocked_count = crystal_counts(output)
                job.phase = "blocked"
            end
        elseif job.phase == "blocked" then
            if event.tick - job.started >= 15 then
                check(crystal_counts(output) == job.blocked_count, job.name .. " blocked output changed")
                output.clear()
                job.blocking_passed = true
                job.phase = "crafting"
            end
        elseif job.phase == "crafting" then
            if job.crafts == 500 and game.is_multiplayer() and not storage.reloaded_midcraft and machine.crafting_progress > 0 then
                machine.disabled_by_script = true
                job.snapshot = helpers.table_to_json(snapshot(machine))
                job.phase = "checkpoint"
            else
                local high, low = crystal_counts(output)
                check(high + low <= 1, job.name .. " duplicated crystal return")
                if high + low == 1 and machine.crafting_progress == 0 then job.phase = "settling"; job.settled_at = event.tick end
                check(event.tick - job.started < 120, job.name .. " craft timeout")
            end
        elseif job.phase == "settling" and event.tick - job.settled_at >= 2 then
            local high, low, quality = crystal_counts(output)
            check(high + low == 1, job.name .. " must return exactly one crystal per ordinary craft")
            check(machine.get_inventory(defines.inventory.crafter_input).is_empty(), job.name .. " input batch not consumed")
            job.high, job.ordinary, job.quality_returns = job.high + high, job.ordinary + low, job.quality_returns + quality
            job.crafts = job.crafts + 1
            output.clear()
            for i = 1, machine.fluids_count do machine.clear_fluid(i) end
            job.phase = job.crafts == 1000 and "complete" or "ready"
        end
        if job.phase == "checkpoint" then checkpoint = checkpoint + 1 end
        if job.phase == "complete" then completed = completed + 1 end
    end
    if checkpoint == #storage.jobs then
        storage.awaiting_checkpoint = true
        game.server_save("crystal-midpoint")
        log("CRYSTAL QC MIDPOINT SAVE REQUESTED")
    end
    if completed == #storage.jobs then
        local report = {version = storage.version, passed = true, midcraft_reload = storage.reloaded_midcraft or false, cases = {}}
        for _, job in ipairs(storage.jobs) do
            local split = job.name == "ei-uranium-extraction" and 0.9 or job.name == "ei-neodym-extraction-morphium" and 0.92 or 0.98
            local tolerance = 6 * math.sqrt(job.crafts * split * (1 - split)) + 2
            check(math.abs(job.high - job.crafts * split) <= tolerance, job.name .. " probability tolerance")
            check(job.quality_returns > 0, job.name .. " quality never exercised")
            report.cases[#report.cases + 1] = {name = job.name, mode = job.mode, crafts = job.crafts, high = job.high,
                ordinary = job.ordinary, quality_returns = job.quality_returns, productivity_modules = job.productivity_modules,
                output_blocking_passed = job.blocking_passed, expected_high_probability = split, six_sigma_tolerance = tolerance}
        end
        storage.done = true
        helpers.write_file("crystal-conservation.json", helpers.table_to_json(report), false)
        log("CRYSTAL QC COMPLETE " .. #report.cases .. " cases / 48000 crafts")
        if game.is_multiplayer() then game.server_save("crystal-complete") end
    end
end)
