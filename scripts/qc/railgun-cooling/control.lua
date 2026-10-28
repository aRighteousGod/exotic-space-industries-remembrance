-- Native inserters at every perimeter tile, all eight turret directions, both build orders.
-- Separate fluid rigs exercise real pipe flow and the production shot callback.
local config = require("test-config")
local modern = script.active_mods.base:match("^2%.1%.") ~= nil
local function connections(entity, index)
    return modern and entity.get_fluid_box_pipe_connections(index) or entity.fluidbox.get_pipe_connections(index)
end
local function connected(entity, index, peer)
    local connection = connections(entity, index)[1]
    return connection.target == (modern and peer or peer.fluidbox)
end
local function segment(entity, index)
    if modern then
        if entity.has_fluid_segment(index) then return entity.get_fluid_segment_fluid(index) end
        return entity.get_fluid(index)
    end
    return entity.fluidbox[index]
end
local function amount(entity, index)
    local fluid = segment(entity, index)
    return fluid and fluid.amount or 0
end
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
        -- ESIR's live fluid-safety owner requires insulated fluoroketone lines.
        local input = build(surface, "ei-insulated-pipe", connections(proxy, 1)[1].target_position, nil, true)
        local output = build(surface, "ei-insulated-pipe", connections(proxy, 2)[1].target_position, nil, true)
        local fluid = {name = "fluoroketone-cold", amount = 100, temperature = -150}
        if modern then input.set_fluid(1, fluid) else input.fluidbox[1] = fluid end
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
    if storage.completed then
        if config.reload and event.tick == storage.completed + 600 then
            local report = storage.final_report
            report.reload = inspect("second-reload")
            assert(report.reload.wrong_target_count == 0 and report.reload.empty_turrets == 0)
            for _, rig in ipairs(storage.fluids) do
                assert(rig.proxy.valid and rig.proxy == remote.call("esir-railgun-qc", "proxy", rig.turret), "Reload replaced fluid proxy")
                assert(connected(rig.proxy, 1, rig.input) and connected(rig.proxy, 2, rig.output))
                assert(math.abs(amount(rig.proxy, 1) - rig.saved_cold) < 0.001 and math.abs(amount(rig.proxy, 2) - rig.saved_hot) < 0.001)
            end
            report.reload_pass = true
            helpers.write_file("railgun-qc.json", helpers.table_to_json(report), false)
            log("RAILGUN RELOAD COMPLETE")
            game.server_save("railgun-reloaded")
        end
        return
    end
    if event.tick == 1 then discover() end
    if event.tick == 3 then setup() end
    if config.load_baseline and event.tick == 301 and storage.donor_snapshot then
        local actual = remote.call("esir-railgun-qc", "snapshot")
        local fields, records = 0, 0
        for unit, expected in pairs(storage.donor_snapshot) do
            assert(actual[unit], "Missing migrated railgun record")
            records = records + 1
            for key, value in pairs(expected) do
                assert(actual[unit][key] == value, "Migrated railgun state differs: "..unit.." / "..key)
                fields = fields + 1
            end
        end
        assert(records == #storage.cases + #storage.fluids)
        storage.migration_state = {passed=true, records=records, fields=fields,
            debt_case=storage.donor_snapshot[storage.cases[1].turret.unit_number]}
    end
    for _, case in ipairs(storage.cases or {}) do case.inserter.energy = 1000000 end
    if event.tick == 90 then
        for _, rig in ipairs(storage.fluids) do
            rig.cold_before = amount(rig.proxy, 1)
            rig.cold_capacity = modern and rig.proxy.get_fluid_capacity(1) or rig.proxy.fluidbox.get_capacity(1)
            rig.hot_capacity = modern and rig.proxy.get_fluid_capacity(2) or rig.proxy.fluidbox.get_capacity(2)
            rig.connected = connected(rig.proxy, 1, rig.input) and connected(rig.proxy, 2, rig.output)
            remote.call("esir-railgun-qc", "shot", rig.turret)
            rig.cold_after = amount(rig.proxy, 1)
            rig.hot_after = amount(rig.proxy, 2)
        end
    elseif event.tick == 180 then
        storage.fluid_results = {}
        for _, rig in ipairs(storage.fluids) do
            local hot_output = amount(rig.output, 1)
            storage.fluid_results[#storage.fluid_results + 1] = {direction = rig.turret.direction,
                connected = rig.connected, cold_before = rig.cold_before, cold_after = rig.cold_after,
                hot_after = rig.hot_after, hot_output = hot_output,
                cold_capacity = rig.cold_capacity, hot_capacity = rig.hot_capacity,
                pass = rig.connected and rig.cold_capacity == 30 and rig.hot_capacity == 60
                    and rig.cold_before >= 10 and math.abs(rig.cold_before - rig.cold_after - 10) < 0.01
                    and math.abs(rig.hot_after - 10) < 0.01 and hot_output > 0}
        end
    elseif event.tick == 299 and config.save_baseline then
        -- Preserve real pending heat-debt work, not just idle full coolant rigs.
        remote.call("esir-railgun-qc", "shot", storage.cases[1].turret)
    elseif event.tick == 300 then
        storage.initial = inspect("initial")
        if config.save_baseline then
            storage.donor_snapshot = remote.call("esir-railgun-qc", "snapshot")
            helpers.write_file("railgun-qc.json", helpers.table_to_json({initial=storage.initial,
                fluids=storage.fluid_results,snapshot=storage.donor_snapshot}), false)
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
                local connected = preserved and connected(rig.proxy, 1, rig.input) and connected(rig.proxy, 2, rig.output)
                local cold = preserved and amount(rig.proxy, 1) or 0
                local hot = rig.output.valid and amount(rig.output, 1) or 0
                storage.loaded_fluids[#storage.loaded_fluids + 1] = {direction = rig.turret.direction,
                    proxy_preserved = preserved, connected = connected, cold_buffer = cold, hot_output = hot,
                    input_valid = rig.input.valid, output_valid = rig.output.valid,
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
            loaded_fluids = storage.loaded_fluids, migration_state=storage.migration_state, all_pass = true}
        local checks = {report.loaded, report.rebuilt, report.recovered}
        if not config.load_baseline then checks[#checks + 1] = report.initial end
        for _, result in pairs(checks) do
            if #result.wrong_targets > 0 or result.empty_turrets > 0 then report.all_pass = false end
        end
        for _, result in ipairs(report.fluids) do if not result.pass then report.all_pass = false end end
        for _, result in ipairs(report.loaded_fluids or {}) do if not result.pass then report.all_pass = false end end
        helpers.write_file("railgun-qc.json", helpers.table_to_json(report), false)
        assert(report.all_pass, "Railgun native acceptance failed")
        storage.completed = event.tick
        storage.final_report = report
        for _, rig in ipairs(storage.fluids) do
            rig.proxy = remote.call("esir-railgun-qc", "proxy", rig.turret)
            rig.saved_cold, rig.saved_hot = amount(rig.proxy, 1), amount(rig.proxy, 2)
        end
        log("RAILGUN NATIVE COMPLETE")
        if config.checkpoint then game.server_save("railgun-accepted") end
    end
end)
