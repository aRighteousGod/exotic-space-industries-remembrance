-- Populated native donor. Runtime state belongs to this fixture; ESIR private
-- storage is inspected only through the explicitly staged test-only hook.
local loaded = false
local function check(value, message) assert(value, "MIGRATION QC: " .. message) end
local function modern() return script.active_mods.base:sub(1,3) == "2.1" end
local function disabled(entity)
    if modern() then return entity.disabled_by_script end
    return not entity.active
end
local function minable(entity)
    if modern() then return entity.minable_flag end
    return entity.minable
end
local function inventory(entity, index)
    local inv = entity.get_inventory(index)
    local rows = {}
    if inv then
        for _, item in pairs(inv.get_contents()) do rows[#rows+1]=item.name .. "/" .. item.quality .. "/" .. item.count end
    end
    table.sort(rows)
    return rows
end
local function capture()
    local tank = storage.tank
    local fluid = modern() and tank.get_fluid(1) or tank.fluidbox[1]
    local machine = storage.machine
    local input = modern() and defines.inventory.crafter_input or defines.inventory.assembling_machine_input
    local output = modern() and defines.inventory.crafter_output or defines.inventory.assembling_machine_output
    local recipe, quality = machine.get_recipe()
    local beacons={}
    for _,beacon in ipairs(storage.beacons or {}) do
        local data=remote.call("nonstandard-beacons","get-beacon-data",beacon.unit_number)
        check(data and data.source.valid and data.manager.valid,"beacon helpers exist " .. beacon.name)
        local source=data.source
        local fluid=source.fluids_count>0 and source.get_fluid(1) or nil
        if fluid and not modern() then
            local segment=source.fluidbox.get_fluid_segment_contents(1)
            fluid.amount=fluid.amount+(segment and segment[fluid.name] or 0)
        end
        beacons[#beacons+1]={name=beacon.name,quality=beacon.quality.name,unit=beacon.unit_number,
            modules=inventory(beacon,defines.inventory.beacon_modules),source_quality=source.quality.name,
            direction=source.direction,mirrored=source.mirroring,
            energy=source.energy+(data.energy_reserve or 0),fluid=fluid,
            fuel=source.burner and inventory(source,defines.inventory.fuel),
            burning=source.burner and source.burner.currently_burning and source.burner.currently_burning.name,
            remaining=source.burner and source.burner.remaining_burning_fuel,
            disabled=disabled(source)}
    end
    return {chest=inventory(storage.chest,defines.inventory.chest), fluid=fluid,
        beacons=beacons,logistics=game.forces.player.character_logistic_requests,
        platforms=game.forces.player.is_space_platforms_unlocked(),
        input=inventory(machine,input), output=inventory(machine,output), recipe=recipe and recipe.name,
        recipe_quality=quality and quality.name, progress=machine.crafting_progress, bonus=machine.bonus_progress,
        products=machine.products_finished, health=machine.health, machine_quality=machine.quality.name,
        minable=minable(machine), disabled=disabled(machine),
        research=game.forces.player.technologies.recycling.researched,
        terra_tile=game.surfaces[1].get_tile(260,4).name,
        gaia_pressure=storage.gaia.get_property("pressure"), gaia_gravity=storage.gaia.get_property("gravity"),
        private=remote.call("esir-qc-migration-private", "snapshot")}
end
local function verify_adopted()
    local after, before = capture(), storage.before
    for key, value in pairs(before) do
        if key ~= "private" then check(helpers.table_to_json{value} == helpers.table_to_json{after[key]}, "changed " .. key) end
    end
    check(after.private.compatibility == nil, "stale external ecology flag retained")
    check(after.private.ecology_enabled == true, "ecology remains disabled")
    check(helpers.table_to_json(before.private.overrides) == helpers.table_to_json(after.private.overrides), "ecology overrides changed")
    check(storage.gaia.get_property("robot-energy-usage") == 1.5, "custom Gaia robot cost changed")
    if storage.beacons then
        check(game.forces.player.unlock_logistic_network,"new logistic network unlock stranded researched force")
        local expected_travel=false
        for _,technology in pairs(game.forces.player.technologies) do
            if technology.researched then
                for _,effect in pairs(technology.prototype.effects) do
                    if effect.type=="unlock-travel-to-space-platforms" and effect.modifier then expected_travel=true end
                end
            end
        end
        check(game.forces.player.unlock_travel_to_space_platforms==expected_travel,"native discovered-planet travel permission")
    end
    return after
end
script.on_init(function()
    check(not modern(), "Create the donor on actual Factorio 2.0")
    game.speed=10
    local force, surface = game.forces.player, game.surfaces[1]
    surface.request_to_generate_chunks({256,0},2)
    surface.force_generate_chunk_requests()
    for _, entity in ipairs(surface.find_entities_filtered{area={{248,-8},{318,12}}}) do entity.destroy() end
    local tiles={}
    for x=248,318 do for y=-8,12 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    storage.chest=surface.create_entity{name="steel-chest",position={250,0},force=force}
    storage.chest.insert{name="iron-plate",count=123}
    storage.chest.insert{name="ei-energy-crystal",count=17,quality="rare"}
    storage.tank=surface.create_entity{name="storage-tank",position={256,0},force=force}
    storage.tank.fluidbox[1]={name="water",amount=1234,temperature=87}
    force.recipes["ei-iron-mechanical-parts"].enabled=true
    storage.machine=surface.create_entity{name="assembling-machine-3",position={264,0},force=force,quality="rare"}
    storage.machine.set_recipe("ei-iron-mechanical-parts")
    for _, ingredient in pairs(prototypes.recipe["ei-iron-mechanical-parts"].ingredients) do
        check(ingredient.type=="item", "Donor recipe changed; review fixture")
        storage.machine.insert{name=ingredient.name,count=ingredient.amount*4}
    end
    force.technologies.recycling.researched=true
    force.technologies["logistic-robotics"].researched=true
    force.technologies["rocket-silo"].researched=true
    storage.beacons={}
    for index,name in ipairs{"ei-copper-beacon","ei-alien-beacon"} do
        local beacon=surface.create_entity{name=name,position={280+index*12,0},force=force,quality="rare",raise_built=true}
        local metadata=remote.call("nonstandard-beacons","get-beacon-data",beacon.unit_number)
        check(metadata and metadata.source.valid,"old library registers donor beacon")
        local source=metadata.source
        source.active=false
        source.direction=defines.direction.east
        source.mirroring=true
        beacon.get_module_inventory().insert{name="speed-module",count=4,quality="rare"}
        if source.burner then source.get_fuel_inventory().insert{name="ei-bio-matter",count=17,quality="rare"}
        else source.fluidbox[1]={name="ei-liquid-nitrogen",amount=77,temperature=43} end
        storage.beacons[#storage.beacons+1]=beacon
    end
    storage.gaia=game.create_surface("esir-migration-gaia",{width=64,height=64})
    storage.gaia.set_property("pressure",800)
    storage.gaia.set_property("gravity",12)
    remote.call("esir-qc-migration-private","seed",storage.gaia)
end)
script.on_load(function() loaded=true end)
script.on_event(defines.events.on_tick,function(event)
    if storage.donor_saved then
        if not modern() then return end
        if storage.accepted and loaded then
            helpers.write_file("migration-second-reload.json",helpers.table_to_json{passed=true,snapshot=verify_adopted()},false)
            if game.is_multiplayer() then game.server_save("migration-reloaded") end
            loaded=false
            return
        end
        if storage.accepted then return end
        local after=verify_adopted()
        local before=storage.before
        storage.accepted=true
        helpers.write_file("migration-adopted.json",helpers.table_to_json{passed=true,before=before,after=after,
            robot_energy=storage.gaia.get_property("robot-energy-usage"),engine=script.active_mods.base,
            limits={"Core-only donor with two populated legacy beacons", "No native player inventory, GUI, circuits or client/rejoin claim"}},false)
        game.server_save("migration-adopted")
        loaded=false
        return
    end
    loaded=false
    storage.machine.energy=1e9
    if storage.machine.crafting_progress>0 then
        storage.machine.active=false
        storage.machine.minable=false
        storage.machine.health=storage.machine.health*0.7
        storage.machine.bonus_progress=0.375
        storage.before=capture()
        storage.donor_saved=true
        helpers.write_file("migration-donor.json",helpers.table_to_json{engine=script.active_mods.base,main=script.active_mods["exotic-space-industries-remembrance"],snapshot=storage.before},false)
        game.server_save("migration-donor")
    end
    check(event.tick<300,"Donor machine did not start")
end)
