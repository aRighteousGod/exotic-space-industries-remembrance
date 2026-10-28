-- Actual ESIR prototypes, NSBC lifecycle and central ESIR dispatcher; no mocked
-- power sources, copied ESIR runtime owners or disabled overload implementation.
local function check(value, message) assert(value, "ESIR BEACON QC: " .. message) end
local function record(entity) return remote.call("nonstandard-beacons", "get-beacon-data", entity.unit_number) end
local function fill(entity)
    local data = record(entity)
    check(data and data.source.valid and data.manager.valid, "live source and manager " .. entity.name)
    local source = data.source
    if source.burner then
        source.get_fuel_inventory().insert{name="ei-bio-matter", count=30, quality="rare"}
    else
        local index = source.prototype.fluid_energy_source_prototype.fluid_box.index
        source.set_fluid(index,{name="ei-liquid-nitrogen",amount=100,temperature=25})
    end
end
local function contents(inventory)
    local rows={}
    if inventory then for _, item in pairs(inventory.get_contents()) do rows[#rows+1]=item.name .. "/" .. item.quality .. "/" .. item.count end end
    table.sort(rows)
    return rows
end
local function snapshot(entity)
    local data=record(entity)
    local source=data.source
    local fluid=source.fluids_count>0 and source.get_fluid(1) or nil
    return {name=entity.name, quality=entity.quality.name, modules=contents(entity.get_module_inventory()),
        energy=source.energy+(data.energy_reserve or 0),
        fuel=source.burner and contents(source.get_fuel_inventory()),
        burning=source.burner and source.burner.currently_burning and source.burner.currently_burning.name,
        remaining=source.burner and source.burner.remaining_burning_fuel,
        fluid=fluid, direction=source.direction, mirrored=source.mirroring}
end
local function upgrade(entity, name, quality, expected_overflow)
    local before=snapshot(entity)
    local buffer=game.create_inventory(100)
    check(entity.order_upgrade{target={name=name,quality=quality},force=entity.force},"upgrade marking " .. name)
    local successor=entity.apply_upgrade(nil,buffer)
    check(successor and successor.valid and not entity.valid,"native upgrade " .. name)
    local metadata=record(successor)
    check(metadata and metadata.phase=="attached" and metadata.source.valid and metadata.manager.valid,"attached successor " .. name)
    local after=snapshot(successor)
    check(math.abs(after.energy-before.energy)<0.000001,"energy custody " .. name)
    for _, key in ipairs({"fuel","burning","remaining","fluid","direction","mirrored"}) do
        check(helpers.table_to_json{before[key]}==helpers.table_to_json{after[key]},"source custody " .. name .. "/" .. key)
    end
    local returned=buffer.get_item_count("speed-module")
    check(returned==expected_overflow,"module overflow custody " .. name .. " expected " .. expected_overflow .. " got " .. returned)
    local count=successor.get_module_inventory().get_item_count("speed-module")+returned
    local original=0
    for _, row in ipairs(before.modules) do original=original+tonumber(row:match("/(%d+)$")) end
    check(count==original,"module conservation " .. name)
    storage.results[#storage.results+1]={before=before,after=after,overflow=contents(buffer),passed=true}
    buffer.destroy()
    return successor
end
local function overload()
    return remote.call("exotic-industries-qc","get_beacon_overload_qc_snapshot",storage.machine.unit_number)
end
script.on_init(function()
    game.speed=10
    remote.call("exotic-industries-qc","set_beacon_overload_enabled_for_qc",true)
    local surface=game.create_surface("esir-beacon-qc",{width=256,height=256})
    surface.request_to_generate_chunks({0,0},4)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities()) do entity.destroy() end
    storage.surface=surface
    storage.results={}
    storage.machine=surface.create_entity{name="assembling-machine-3",position={0,0},force="player",raise_built=true}
    storage.copper={}
    for index, position in ipairs({{-4,0},{4,0},{0,-4},{0,4}}) do
        local entity=surface.create_entity{name="ei-copper-beacon",position=position,force="player",raise_built=true}
        check(#entity.get_module_inventory()==4,"Copper has four slots")
        entity.get_module_inventory().insert{name="speed-module",count=4}
        fill(entity)
        storage.copper[index]=entity
    end
    storage.alien=surface.create_entity{name="ei-alien-beacon",position={70,0},force="player",raise_built=true}
    check(#storage.alien.get_module_inventory()==8,"Alien has eight slots")
    storage.alien.get_module_inventory().insert{name="speed-module",count=8}
    fill(storage.alien)
    local ok=remote.call("nonstandard-beacons","set-beacon-orientation",storage.copper[1],defines.direction.east,true)
    check(ok,"guarded orientation API")
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    if event.tick==30 then
        local state=overload()
        check(state.machine.weighted_count==4 and not state.machine.overloaded and not storage.machine.disabled_by_script,"four Copper do not overload")
        storage.copper[1]=upgrade(storage.copper[1],"ei-iron-beacon","normal",0)
        check(#storage.copper[1].get_module_inventory()==6,"Iron has six slots")
        storage.copper[1].get_module_inventory().insert{name="speed-module",count=2}
        storage.alien=upgrade(storage.alien,"ei-warp-beacon","normal",0)
        check(#storage.alien.get_module_inventory()==10,"Warp has ten slots")
        storage.alien.get_module_inventory().insert{name="speed-module",count=2}
    elseif event.tick==60 then
        local state=overload()
        check(state.machine.weighted_count==5 and state.machine.overloaded and storage.machine.disabled_by_script,"Iron weight triggers actual overload")
        storage.copper[1]=upgrade(storage.copper[1],"ei-copper-beacon","normal",2)
        storage.alien=upgrade(storage.alien,"ei-alien-beacon","normal",2)
    elseif event.tick==90 then
        local state=overload()
        check(state.machine.weighted_count==4 and not state.machine.overloaded and not storage.machine.disabled_by_script,"downgrade releases owned overload")
        storage.copper[1]=upgrade(storage.copper[1],"ei-iron-beacon","rare",0)
        storage.alien=upgrade(storage.alien,"ei-warp-beacon","rare",0)
    elseif event.tick==120 then
        storage.copper[1]=upgrade(storage.copper[1],"ei-copper-beacon","normal",0)
        storage.alien=upgrade(storage.alien,"ei-alien-beacon","normal",0)
    elseif event.tick==150 then
        check(not storage.machine.disabled_by_script,"final overload recovery")
        storage.done=true
        helpers.write_file("beacons.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,
            overload=overload(),upgrades=storage.results,
            limits={"No native player, GUI, blueprint, robot, platform or multiplayer-client acceptance claim"}},false)
        if game.is_multiplayer() then game.server_save("beacons-complete") end
        log("FULL ESIR BEACON QC COMPLETE")
    end
end)
