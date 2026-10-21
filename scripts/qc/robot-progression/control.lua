-- Native robot acceptance fixture. State survives a real server checkpoint;
-- only ports and assemblers receive fixture power, never working robots.
local config = require("test-config")
local visual = require("visual")
local targets = {"ei-advanced-logistic-bot", "ei-advanced-construction-bot"}
local donors = {"ei-cargo-bot", "ei-construction-bot"}
local loaded = false
script.on_load(function() loaded = true end)
script.on_event(defines.events.on_player_created, function(event)
    if config.visual then
        visual.tick(event)
        game.tick_paused = false
        log("ROBOT VISUAL: initialized native player")
    end
end)

local function check(ok, message)
    storage.checks = (storage.checks or 0) + 1
    assert(ok, "ROBOT QC: "..message)
end

local function write(name, value)
    helpers.write_file(name..".json", helpers.table_to_json(value), false)
end

local function recipe_name(i)
    return targets[i].."-from-"..donors[i]:sub(4)
end

local function surface(name, distance)
    local s = game.create_surface(name, {seed = 71829, width = 384, height = 128,
        autoplace_settings = {entity = {treat_missing_as_default = false}, decorative = {treat_missing_as_default = false}}})
    s.request_to_generate_chunks({distance / 2, 0}, 4)
    s.force_generate_chunk_requests()
    for _, entity in pairs(s.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -24, distance + 32 do for y = -24, 32 do tiles[#tiles + 1] = {name = "lab-dark-1", position = {x, y}} end end
    s.set_tiles(tiles)
    s.daytime = 0
    s.freeze_daytime = true
    return s
end

local function ports(s, force, distance)
    local result = {}
    for _, x in ipairs(distance > 100 and {0, 96} or {0}) do
        local port = assert(s.create_entity{name = "ei-advanced-port", position = {x, -12}, force = force})
        port.energy = 1000000000
        result[#result + 1] = port
    end
    return result
end

local function add_case(kind, distance, name, force, profile)
    local id = profile.."-"..kind.."-"..distance.."-"..name
    local s = surface(id, distance)
    local case = {id = id, kind = kind, distance = distance, name = name, profile = profile, surface = s,
        ports = ports(s, force, distance), jobs = {}, start = game.tick}
    case.ports[1].get_inventory(defines.inventory.roboport_robot).insert{name = name, count = 20}
    local provider = assert(s.create_entity{name = "passive-provider-chest", position = {0, 0}, force = force})
    if kind == "logistics" then
        case.sink = assert(s.create_entity{name = "requester-chest", position = {distance, 0}, force = force})
        case.target = 2000
        check(provider.insert{name = "iron-plate", count = case.target} == case.target, "logistics source inventory")
        case.sink.get_logistic_sections().add_section().set_slot(1,
            {value = {name = "iron-plate", quality = "normal", comparator = "="}, min = case.target, max = case.target})
    else
        s.create_entity{name = "storage-chest", position = {0, 3}, force = force}
        local count = kind == "repair" and 40 or 200
        provider.insert{name = "stone-wall", count = count}
        case.ports[1].get_inventory(defines.inventory.roboport_material).insert{name = "repair-pack", count = 100}
        for i = 1, count do
            local position = {distance + (i - 1) % 10, math.floor((i - 1) / 10)}
            local entity
            if kind == "construction" then
                entity = s.create_entity{name = "entity-ghost", inner_name = "stone-wall", position = position, force = force}
            else
                entity = s.create_entity{name = "stone-wall", position = position, force = force}
                if kind == "deconstruction" then entity.order_deconstruction(force)
                else entity.damage(entity.health * 0.5, game.forces.neutral, "physical") end
            end
            case.jobs[#case.jobs + 1] = assert(entity)
        end
    end
    storage.cases[#storage.cases + 1] = case
end

local function setup()
    game.speed = 100
    check(storage.baseline, "pre-change save loaded")
    local force = game.forces.player
    check(force.technologies["ei-advanced-bots"].researched, "existing research preserved")
    for i = 1, 2 do check(force.recipes[recipe_name(i)].enabled, "native existing-save unlock "..i) end
    check(storage.legacy.valid and storage.legacy.unit_number == storage.legacy_number, "placed bot identity preserved")
    check(storage.legacy.name == targets[1], "placed bot prototype preserved")
    storage.legacy.destroy()
    write("robot-candidate-final", prototypes.mod_data["robot-qc-final"].data)
    local fresh = game.create_force("robot-qc-fresh")
    for i = 1, 2 do check(not fresh.recipes[recipe_name(i)].enabled, "fresh recipe locked "..i) end
    fresh.technologies["ei-advanced-bots"].researched = true
    for i = 1, 2 do check(fresh.recipes[recipe_name(i)].enabled, "fresh research unlock "..i) end

    storage.machines = {}
    local s = surface("robot-crafting-qc", 32)
    for i = 1, 2 do
        for q, quality in ipairs{"normal", "rare"} do
            local machine = assert(s.create_entity{name = "assembling-machine-3", position = {i * 6, q * 6}, force = force})
            machine.set_recipe(recipe_name(i), quality)
            check(machine.get_recipe().name == recipe_name(i), "machine selects conversion")
            check(machine.insert{name = donors[i], quality = quality, count = 1} == 1, "donor inserted")
            check(machine.insert{name = "processing-unit", quality = quality, count = 4} == 4, "circuits inserted")
            check(machine.insert{name = "ei-advanced-bot-engine", quality = quality, count = 4} == 4, "engines inserted")
            check(machine.get_module_inventory().insert{name = "productivity-module-3", count = 1} == 0, "productivity rejected")
            storage.machines[#storage.machines + 1] = {entity = machine, target = targets[i], quality = quality}
        end
    end
    storage.cases = {}
    storage.charging = {}
    storage.started = game.tick
    -- The server checkpoint exercises crafting persistence without rerunning
    -- the already completed fleet timing matrix.
    if config.save_only then return end
    for _, profile in ipairs{"base", "researched"} do
        local fleet = game.create_force("robot-fleet-"..profile)
        fleet.worker_robots_speed_modifier = profile == "base" and 0 or 1
        fleet.worker_robots_storage_bonus = profile == "base" and 0 or 3
        for _, distance in ipairs{32, 128} do
            for _, name in ipairs{donors[1], targets[1]} do add_case("logistics", distance, name, fleet, profile) end
            for _, kind in ipairs{"construction", "deconstruction", "repair"} do
                for _, name in ipairs{donors[2], targets[2]} do add_case(kind, distance, name, fleet, profile) end
            end
        end
    end
    for i, name in ipairs{donors[1], targets[1], donors[2], targets[2]} do
        local charge_surface = surface("robot-charge-"..i, 32)
        local case = {name = name, ports = ports(charge_surface, fresh, 32), robots = {}, observed = false}
        for n = 1, 20 do
            local bot = assert(charge_surface.create_entity{name = name, position = {n * 0.2, 0}, force = fresh})
            bot.energy = 1000
            case.robots[#case.robots + 1] = bot
        end
        storage.charging[#storage.charging + 1] = case
    end
    storage.started = game.tick
end

script.on_init(function()
    if not config.baseline then return end
    game.forces.player.technologies["ei-advanced-bots"].researched = true
    for i = 1, 2 do check(game.forces.player.recipes[recipe_name(i)] == nil, "baseline excludes conversions") end
    storage.baseline = true
    storage.legacy = game.surfaces.nauvis.create_entity{name = targets[1], position = {0, 0}, force = "player"}
    storage.legacy_number = storage.legacy.unit_number
    write("robot-baseline-final", prototypes.mod_data["robot-qc-final"].data)
end)

local function finish_case(case, tick)
    if case.finished then return end
    local done = true
    if case.kind == "logistics" then done = case.sink.get_item_count("iron-plate") == case.target
    else
        for _, entity in ipairs(case.jobs) do
            if entity.valid and (case.kind ~= "repair" or entity.health < entity.max_health) then done = false; break end
        end
        if done and case.kind == "construction" then
            check(case.surface.count_entities_filtered{name = "stone-wall"} == #case.jobs, "all ghosts built")
        end
    end
    if done then case.finished = tick - case.start end
end

script.on_event(defines.events.on_tick, function(event)
    if config.visual then visual.tick(event); return end
    if config.baseline then return end
    if config.reload then
        if storage.reload_reported then return end
        check(loaded and storage.done and storage.save_requested, "real checkpoint reloaded")
        for i = 1, 2 do check(game.forces.player.recipes[recipe_name(i)].enabled, "unlock survives reload "..i) end
        for _, row in ipairs(storage.machines) do
            check(row.entity.get_output_inventory().get_item_count{name = row.target, quality = row.quality} == 1, "crafted quality survives reload")
        end
        write("robot-reload", {checks = storage.checks, retained = true})
        storage.reload_reported = true
        return
    end
    if storage.done then
        if game.is_multiplayer() and not storage.save_requested then
            storage.save_requested = true
            game.server_save("robot-progression-checkpoint")
        end
        return
    end
    if not storage.started then setup() end
    local complete = true
    for _, row in ipairs(storage.machines) do
        row.entity.energy = 1000000000
        if row.entity.products_finished < 1 then complete = false end
    end
    for _, case in ipairs(storage.cases) do
        for _, port in ipairs(case.ports) do port.energy = 1000000000 end
        if event.tick % 30 == 0 then finish_case(case, event.tick) end
        if not case.finished then complete = false end
    end
    for _, case in ipairs(storage.charging) do
        local port = case.ports[1]
        port.energy = 1000000000
        for _, bot in ipairs(case.robots) do if bot.valid and bot.energy > 100000 then case.observed = true end end
        if not case.finished and port.get_inventory(defines.inventory.roboport_robot).get_item_count(case.name) == 20 then
            check(case.observed, "native recharge observed "..case.name)
            case.finished = event.tick - storage.started
        end
        if not case.finished then complete = false end
    end
    if event.tick % 600 == 0 then
        local pending = {}
        for _, case in ipairs(storage.cases) do if not case.finished then pending[#pending + 1] = case.id end end
        write("robot-progress", {tick = event.tick, pending = pending})
    end
    assert(event.tick - storage.started < 59000, "ROBOT QC: timeout")
    if not complete then return end
    local report = {checks = 0, cases = {}, charging = {}, comparisons = {}, crafting = {}}
    local times = {}
    for _, case in ipairs(storage.cases) do
        times[case.id] = case.finished
        report.cases[#report.cases + 1] = {id = case.id, ticks = case.finished, robots = 20, quality = "normal"}
    end
    for _, profile in ipairs(config.save_only and {} or {"base", "researched"}) do for _, distance in ipairs{32, 128} do
        for _, kind in ipairs{"logistics", "construction", "deconstruction", "repair"} do
            local i = kind == "logistics" and 1 or 2
            local prefix = profile.."-"..kind.."-"..distance.."-"
            local before, after = times[prefix..donors[i]], times[prefix..targets[i]]
            check(after < before, "advanced fleet faster: "..prefix..before.." -> "..after)
            report.comparisons[#report.comparisons + 1] = {profile = profile, kind = kind, distance = distance,
                previous_ticks = before, advanced_ticks = after, speedup = before / after}
        end
    end end
    for _, case in ipairs(storage.charging) do report.charging[#report.charging + 1] = {name = case.name, ticks = case.finished, robots = 20} end
    for _, row in ipairs(storage.machines) do
        check(row.entity.products_finished == 1, "exactly one conversion craft")
        check(row.entity.get_output_inventory().get_item_count{name = row.target, quality = row.quality} == 1, "one matching quality output")
        check(row.entity.get_inventory(defines.inventory.assembling_machine_input).is_empty(), "all inputs consumed")
        report.crafting[#report.crafting + 1] = {target = row.target, quality = row.quality, count = 1}
    end
    report.checks = storage.checks
    write(config.save_only and "robot-save" or "robot-runtime", report)
    storage.done = true
end)
