-- Native inserters at every perimeter tile, all eight turret directions, both build orders.
-- Separate fluid rigs exercise real pipe flow and the production shot callback.
local config = require("test-config")
local function build(surface, name, position, direction, raise)
    return assert(surface.create_entity{name = name, position = position,
        direction = direction, force = "player", raise_built = raise})
end

local function discover()
    local surface = game.create_surface("railgun-qc", {width = 512, height = 512})
    surface.request_to_generate_chunks({0, 0}, 8)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles = {}
    for x = -240, 240 do
        for y = -240, 240 do tiles[#tiles + 1] = {name = "landfill", position = {x, y}} end
    end
    surface.set_tiles(tiles)
    storage.probes = {}
    for direction = 0, 14, 2 do
        local origin = direction * 12
        local probe = build(surface, "railgun-turret", {origin + 0.5, 0.5}, direction)
        local box = probe.bounding_box
        local points = {}
        local left, right = math.floor(box.left_top.x), math.ceil(box.right_bottom.x) - 1
        local top, bottom = math.floor(box.left_top.y), math.ceil(box.right_bottom.y) - 1
        -- Ask the engine which tiles can feed the helper-free turret. A rotated
        -- bounding rectangle includes empty corners and misses indented edges.
        for x = left - 1, right + 1 do
            for y = top - 1, bottom + 1 do
                local position = {x + 0.5, y + 0.5}
                local placeable = surface.can_place_entity{name = "fast-inserter", position = position, force = "player"}
                for _, side in ipairs{
                    {dx = 0, dy = 1, direction = defines.direction.north},
                    {dx = 0, dy = -1, direction = defines.direction.south},
                    {dx = 1, dy = 0, direction = defines.direction.west},
                    {dx = -1, dy = 0, direction = defines.direction.east},
                } do
                    if placeable then
                        local inserter = build(surface, "fast-inserter", position, side.direction)
                        points[#points + 1] = {x = x - origin, y = y, dx = side.dx, dy = side.dy, direction = side.direction, inserter = inserter}
                    end
                end
            end
        end
        storage.probes[#storage.probes + 1] = {turret = probe, points = points, direction = direction}
    end
end

local function setup()
    local surface = game.surfaces["railgun-qc"]
    storage.cases, storage.fluids = {}, {}
    local index = 0
    for _, probe in ipairs(storage.probes) do
        local points = {}
        local direction = probe.direction
        for _, point in ipairs(probe.points) do
            if point.inserter.drop_target == probe.turret then points[#points + 1] = point end
            point.inserter.destroy()
        end
        probe.turret.destroy()
        assert(#points > 0, "No native insertion positions found for direction " .. direction)
        for order = 1, 2 do
            for _, point in ipairs(points) do
                index = index + 1
                local x, y = -220 + ((index - 1) % 26) * 17, -210 + math.floor((index - 1) / 26) * 17
                local turret
                if order == 1 then turret = build(surface, "railgun-turret", {x + 0.5, y + 0.5}, direction, true) end
                local inserter = build(surface, "fast-inserter", {x + point.x + 0.5, y + point.y + 0.5}, point.direction)
                local chest = build(surface, "steel-chest", {x + point.x - point.dx + 0.5, y + point.y - point.dy + 0.5})
                chest.insert{name = "railgun-ammo", count = 10}
                if order == 2 then turret = build(surface, "railgun-turret", {x + 0.5, y + 0.5}, direction, true) end
                storage.cases[#storage.cases + 1] = {turret = turret, inserter = inserter,
                    direction = direction, order = order, offset = {point.x, point.y}}
            end
        end
        local turret = build(surface, "railgun-turret", {-210 + direction * 25, 100.5}, direction, true)
        local proxy = remote.call("esir-railgun-qc", "proxy", turret)
        local input = build(surface, "pipe", proxy.fluidbox.get_pipe_connections(1)[1].target_position)
        local output = build(surface, "pipe", proxy.fluidbox.get_pipe_connections(2)[1].target_position)
        input.fluidbox[1] = {name = "fluoroketone-cold", amount = 100, temperature = -150}
        storage.fluids[#storage.fluids + 1] = {turret = turret, proxy = proxy, input = input, output = output}
    end
end

local function inspect(label)
    local result = {label = label, cases = #storage.cases, wrong_targets = {}, empty_turrets = 0}
    for _, case in ipairs(storage.cases) do
        local target = case.inserter.drop_target
        if target ~= case.turret then
            result.wrong_targets[#result.wrong_targets + 1] = {direction = case.direction,
                order = case.order, offset = case.offset, target = target and target.name or "nil"}
        end
        if case.turret.get_item_count("railgun-ammo") == 0 then result.empty_turrets = result.empty_turrets + 1 end
    end
    result.wrong_target_count = #result.wrong_targets
    return result
end

script.on_event(defines.events.on_tick, function(event)
    if event.tick == 1 then discover() end
    if event.tick == 3 then setup() end
    for _, case in ipairs(storage.cases or {}) do case.inserter.energy = 1000000 end
    if event.tick == 90 then
        for _, rig in ipairs(storage.fluids) do
            rig.cold_before = rig.proxy.get_fluid_count("fluoroketone-cold")
            rig.connected = rig.proxy.fluidbox.get_pipe_connections(1)[1].target == rig.input.fluidbox
                and rig.proxy.fluidbox.get_pipe_connections(2)[1].target == rig.output.fluidbox
            remote.call("esir-railgun-qc", "shot", rig.turret)
            rig.cold_after = rig.proxy.get_fluid_count("fluoroketone-cold")
            rig.hot_after = rig.proxy.get_fluid_count("fluoroketone-hot")
        end
    elseif event.tick == 180 then
        storage.fluid_results = {}
        for _, rig in ipairs(storage.fluids) do
            local hot_output = rig.output.get_fluid_count("fluoroketone-hot")
            storage.fluid_results[#storage.fluid_results + 1] = {direction = rig.turret.direction,
                connected = rig.connected, cold_before = rig.cold_before, cold_after = rig.cold_after,
                hot_after = rig.hot_after, hot_output = hot_output,
                pass = rig.connected and rig.cold_before >= 10 and math.abs(rig.cold_before - rig.cold_after - 10) < 0.01
                    and math.abs(rig.hot_after - 10) < 0.01 and hot_output > 0}
        end
    elseif event.tick == 300 then
        storage.initial = inspect("initial")
        if config.save_baseline then
            game.server_save("railgun-baseline")
            return
        end
        -- Exercise the same helper recreation used by configuration changes.
        remote.call("esir-railgun-qc", "rebuild")
    elseif event.tick == 360 and not config.save_baseline then
        storage.loaded = inspect("loaded-or-rebuilt")
        if config.load_baseline then
            storage.loaded_fluids = {}
            for _, rig in ipairs(storage.fluids) do
                local preserved = rig.proxy.valid and rig.proxy == remote.call("esir-railgun-qc", "proxy", rig.turret)
                local connected = preserved and rig.proxy.fluidbox.get_pipe_connections(1)[1].target == rig.input.fluidbox
                    and rig.proxy.fluidbox.get_pipe_connections(2)[1].target == rig.output.fluidbox
                local cold = preserved and rig.proxy.get_fluid_count("fluoroketone-cold") or 0
                local hot = rig.output.get_fluid_count("fluoroketone-hot")
                storage.loaded_fluids[#storage.loaded_fluids + 1] = {direction = rig.turret.direction,
                    proxy_preserved = preserved, connected = connected, cold_buffer = cold, hot_output = hot,
                    pass = preserved and connected and cold >= 10 and math.abs(hot - 10) < 0.01}
            end
        end
    elseif event.tick == 420 then
        storage.rebuilt = inspect("rebuilt")
        for _, case in ipairs(storage.cases) do
            local proxy = remote.call("esir-railgun-qc", "proxy", case.turret)
            proxy.destroy() -- Production on_object_destroyed must restore it without stealing targets.
        end
    elseif event.tick == 600 then
        local report = {initial = storage.initial, rebuilt = storage.rebuilt,
            loaded = storage.loaded, recovered = inspect("recovered"), fluids = storage.fluid_results,
            loaded_fluids = storage.loaded_fluids, all_pass = true}
        local checks = {report.loaded, report.rebuilt, report.recovered}
        if not config.load_baseline then checks[#checks + 1] = report.initial end
        for _, result in pairs(checks) do
            if #result.wrong_targets > 0 or result.empty_turrets > 0 then report.all_pass = false end
        end
        for _, result in ipairs(report.fluids) do if not result.pass then report.all_pass = false end end
        for _, result in ipairs(report.loaded_fluids or {}) do if not result.pass then report.all_pass = false end end
        helpers.write_file("railgun-qc.json", helpers.table_to_json(report), false)
    end
end)
