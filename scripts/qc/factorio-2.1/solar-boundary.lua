-- Exact native consumer boundary, independent of the mirror owner's fluid supply.
-- Tick-one placement avoids configuration-change discovery of these private rigs.
local modern = script.active_mods.base:match("^2%.1%.") ~= nil

local function read_fluid(entity)
    return modern and entity.get_fluid(1) or entity.fluidbox[1]
end

script.on_event(defines.events.on_tick, function(event)
    if event.tick == 1 then
        local surface = game.create_surface("solar-boundary-qc", {width=256, height=128})
        surface.request_to_generate_chunks({0,0}, 4)
        surface.force_generate_chunk_requests()
        for _, entity in pairs(surface.find_entities()) do entity.destroy() end
        storage.cases = {}
        storage.report = {version=script.active_mods.base, cases={}, assertions=0}
        for _, initial_heat in ipairs{20, 900} do
            for _, connected in ipairs{false, true} do
                for _, temperature in ipairs{9, 10, 11} do
                    local index = #storage.cases + 1
                    local position = {x=(index-1)%6*30-80, y=math.floor((index-1)/6)*30-15}
                    local tower = assert(surface.create_entity{name="chcs-solar-power-tower",
                        position=position, force="player"})
                    tower.temperature = initial_heat
                    local pipe
                    if connected then
                        pipe = assert(surface.create_entity{name="heat-pipe",
                            position={position.x, position.y+3}, force="player"})
                        pipe.temperature = 20
                        assert(#tower.heat_neighbours == 1, "Heat pipe not connected")
                    end
                    local fluid = {name="chcs-solar-fluid", amount=100, temperature=temperature}
                    if modern then tower.set_fluid(1, fluid) else tower.fluidbox[1] = fluid end
                    local accepted = read_fluid(tower)
                    local seeded_amount = accepted and accepted.amount or 0
                    -- 2.0 rejects below-floor contents at the storage boundary;
                    -- 2.1 retains them but prevents the consumer from running.
                    assert(seeded_amount == 100 or (not modern and temperature < 10 and seeded_amount == 0))
                    storage.cases[index] = {tower=tower, pipe=pipe, initial_heat=initial_heat,
                        temperature=temperature, connected=connected, seeded_amount=seeded_amount}
                    storage.report.cases[index] = {initial_heat=initial_heat,
                        input_temperature=temperature, connected=connected,
                        seeded_amount=seeded_amount, samples={}}
                end
            end
        end
    elseif event.tick == 61 or event.tick == 601 or event.tick == 6001 then
        for index, case in ipairs(storage.cases) do
            local fluid = read_fluid(case.tower)
            local sample = {tick=event.tick-1, amount=fluid and fluid.amount or 0,
                fluid_temperature=fluid and fluid.temperature,
                tower_temperature=case.tower.temperature,
                pipe_temperature=case.pipe and case.pipe.temperature,
                energy=case.tower.energy, status=case.tower.status,
                heat_neighbours=#case.tower.heat_neighbours}
            local consumed = case.seeded_amount-sample.amount
            if case.temperature < 10 then
                assert(math.abs(consumed)<1e-9, "Below-floor solar fluid was consumed")
            else
                assert(consumed>0, "Admitted solar fluid was not consumed")
            end
            storage.report.assertions = storage.report.assertions+1
            table.insert(storage.report.cases[index].samples, sample)
        end
        helpers.write_file("solar-boundary.json", helpers.table_to_json(storage.report), false)
        if event.tick == 6001 then log("SOLAR BOUNDARY COMPLETE") end
    end
end)
