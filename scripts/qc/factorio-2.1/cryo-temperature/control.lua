local function setup(tick)
    local config = prototypes.mod_data["esir-qc-cryo-temperature"].data
    local surface = game.surfaces[1]
    local tiles = {}
    for x=-90,90 do for y=-10,15 do tiles[#tiles+1]={name="lab-white",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.rows = {}
    for index, row in ipairs(config.rows) do
        game.forces.player.recipes[row.fill].enabled = true
        game.forces.player.recipes[row.empty].enabled = true
        local machine = assert(surface.create_entity{name="assembling-machine-3",position={-80+index*16,0},force="player"})
        machine.set_recipe(row.fill)
        assert(machine.get_recipe() and machine.get_recipe().name == row.fill, "recipe selected: "..row.suffix)
        assert(machine.insert{name="ei-empty-cryo-container",count=1} == 1)
        assert(math.abs(machine.insert_fluid{name=row.fluid,amount=row.capacity,temperature=row.temperature}-row.capacity)<0.001)
        local wrong
        if row.maximum > row.temperature then
            wrong = assert(surface.create_entity{name="assembling-machine-3",position={-80+index*16,8},force="player"})
            wrong.set_recipe(row.fill)
            wrong.insert{name="ei-empty-cryo-container",count=1}
            wrong.insert_fluid{name=row.fluid,amount=row.capacity,temperature=row.temperature+1}
        end
        storage.rows[#storage.rows+1] = {case=row,machine=machine,wrong=wrong}
    end
    storage.started = tick
end

script.on_event(defines.events.on_tick, function(event)
    if storage.done then return end
    if not storage.started then setup(event.tick) end
    for _, row in ipairs(storage.rows) do
        row.machine.energy = 1000000000
        if row.wrong then row.wrong.energy = 1000000000 end
    end
    local elapsed = event.tick-storage.started
    if elapsed == 240 then
        for _, row in ipairs(storage.rows) do
            local machine, case = row.machine, row.case
            assert(machine.products_finished == 1, "fill once: "..case.suffix.." status="..machine.status.." products="..machine.products_finished)
            assert(machine.get_output_inventory().remove{name="ei-cryo-container-"..case.suffix,count=1} == 1)
            assert(machine.get_fluid_count(case.fluid)<0.001)
            if row.wrong then assert(row.wrong.products_finished == 0, "wrong temperature rejected: "..case.suffix) end
            machine.set_recipe(case.empty)
            assert(machine.insert{name="ei-cryo-container-"..case.suffix,count=1} == 1)
        end
    elseif elapsed == 480 then
        local results = {}
        for _, row in ipairs(storage.rows) do
            local machine, case = row.machine, row.case
            assert(machine.products_finished == 2, "empty once: "..case.suffix)
            assert(machine.get_output_inventory().get_item_count("ei-empty-cryo-container") == 1)
            assert(math.abs(machine.get_fluid_count(case.fluid)-case.capacity)<0.001)
            local fluid
            for index=1,machine.fluids_count do fluid=machine.get_fluid(index) or fluid end
            assert(fluid and math.abs(fluid.temperature-case.temperature)<0.001, "temperature conserved: "..case.suffix)
            results[#results+1] = {fluid=case.fluid,amount=fluid.amount,temperature=fluid.temperature,wrong_temperature_checked=row.wrong~=nil}
        end
        helpers.write_file("cryo-temperature.json",helpers.table_to_json{passed=true,
            engine=script.active_mods.base,mutated=prototypes.mod_data["esir-qc-cryo-temperature"].data.mutated,
            galore=prototypes.mod_data["esir-qc-cryo-temperature"].data.galore,roundtrips=results},false)
        storage.done = true
    end
end)
