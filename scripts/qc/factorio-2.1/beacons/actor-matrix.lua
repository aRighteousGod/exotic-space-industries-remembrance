-- Private full-ESIR native actor matrix: both families and quality directions.
---@class BeaconActorCase
---@field kind "robot"|"platform"
---@field old LuaEntity
---@field built LuaEntity|nil
---@field target string
---@field quality string
---@field inventory LuaInventory
---@field before table
---@field done boolean|nil
local M = {}
local function check(ok, message) assert(ok, "ESIR ACTOR MATRIX: " .. message) end
local function record(entity) return remote.call("nonstandard-beacons", "get-beacon-data", entity.unit_number) end
local function snapshot(entity)
    local data = record(entity)
    local source = data.source
    return {fuel = source.burner and source.get_fuel_inventory().get_contents(),
        remaining = source.burner and source.burner.remaining_burning_fuel,
        burning = source.burner and source.burner.currently_burning and source.burner.currently_burning.name.name,
        burning_quality = source.burner and source.burner.currently_burning and source.burner.currently_burning.quality.name,
        fluid = source.fluids_count > 0 and source.get_fluid(1) or nil,
        energy = source.energy + (data.energy_reserve or 0),
        direction = source.direction, mirrored = source.mirroring,
        modules = entity.get_module_inventory().get_contents()}
end
local function start(tick)
    local cases = {}
    for _, pair in ipairs{{"ei-copper-beacon", "ei-iron-beacon"}, {"ei-alien-beacon", "ei-warp-beacon"}} do
        cases[#cases + 1] = {pair[1], pair[2], "normal", "rare"}
        cases[#cases + 1] = {pair[2], pair[1], "rare", "normal"}
        for _, name in ipairs(pair) do
            cases[#cases + 1] = {name, name, "normal", "rare"}
            cases[#cases + 1] = {name, name, "rare", "normal"}
        end
    end
    storage.actor_matrix = {cases = {}, start = tick}
    local force = game.forces.player
    force.unlock_quality("rare")
    for _, kind in ipairs{"robot", "platform"} do
        for i, case in ipairs(cases) do
            local surface, inventory, platform, port
            if kind == "robot" then
                surface = game.create_surface("nsbc-matrix-robot-" .. i, {width=64,height=64,
                    autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
                surface.request_to_generate_chunks({0,0},1); surface.force_generate_chunk_requests()
                local tiles={}
                for x=-25,25 do for y=-25,25 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
                surface.set_tiles(tiles)
                port=surface.create_entity{name="roboport",position={0,0},force=force}
                surface.create_entity{name="substation",position={6,0},force=force}
                surface.create_entity{name="hidden-electric-energy-interface",position={6,0},force=force}
                port.energy=port.electric_buffer_size
                port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=4}
                inventory=surface.create_entity{name="storage-chest",position={6,3},force=force}.get_inventory(defines.inventory.chest)
            else
                platform=force.create_space_platform{name="NSBC matrix " .. i,planet="nauvis",starter_pack="space-platform-starter-pack"}
                local hub=platform.apply_starter_pack(true)
                platform.paused=true; hub.request_missing_construction_materials=false
                surface=platform.surface
                local tiles={}
                for x=-15,15 do for y=-15,15 do tiles[#tiles+1]={name="space-platform-foundation",position={x,y}} end end
                surface.set_tiles(tiles)
                inventory=hub.get_inventory(defines.inventory.hub_main)
            end
            inventory.insert{name=case[2],quality=case[4],count=1}
            local body=assert(surface.create_entity{name=case[1],quality=case[3],position={12.5,0.5},force=force,raise_built=true})
            body.get_module_inventory().insert{name="speed-module",quality="rare",count=4}
            local source=record(body).source
            source.disabled_by_script=true
            if source.burner then
                source.get_fuel_inventory().insert{name="ei-bio-matter",quality="rare",count=9}
                source.burner.currently_burning={name="ei-bio-matter",quality="rare"}
                source.burner.remaining_burning_fuel=12345
            else source.set_fluid(1,{name="ei-liquid-nitrogen",amount=77,temperature=43}) end
            check(remote.call("nonstandard-beacons","set-beacon-orientation",body,12,true),"seed orientation")
            storage.actor_matrix.cases[#storage.actor_matrix.cases+1]={kind=kind,old=body,name=case[1],old_quality=case[3],
                target=case[2],quality=case[4],surface=surface,position=body.position,platform=platform,port=port,
                inventory=inventory,before=snapshot(body),events={}}
        end
    end
end
---@param event EventData.on_robot_built_entity|EventData.on_space_platform_built_entity
function M.event(event)
    local entity=event.entity
    if not storage.actor_matrix or not entity or not entity.valid then return end
    for _, case in ipairs(storage.actor_matrix.cases) do
        if not case.done and entity.surface==case.surface and entity.position.x==case.position.x and entity.position.y==case.position.y then
            case.events[#case.events+1]={name=event.name,tick=event.tick,entity=entity.name}
            if event.name==defines.events.on_robot_built_entity or event.name==defines.events.on_space_platform_built_entity then
                check((case.kind=="robot" and event.robot and event.robot.valid)
                    or (case.kind=="platform" and event.platform==case.platform),"native actor identity")
                case.built=entity
            end
        end
    end
end
---@param tick MapTick Relative fixture tick.
function M.tick(tick)
    if tick==200 then start(tick) end
    local matrix=storage.actor_matrix
    if not matrix or matrix.done then return end
    local done=true
    for _, case in ipairs(matrix.cases) do
        if not case.ordered then
            check(case.old.order_upgrade{target={name=case.target,quality=case.quality},force=case.old.force},"native order")
            case.ordered=true
        end
        if case.built and not case.checked then
            local data=record(case.built)
            check(not case.old.valid and case.built.name==case.target and case.built.quality.name==case.quality,"successor identity")
            check(data.phase=="attached" and data.source.disabled_by_script,"attached paused successor")
            local after=snapshot(case.built)
            for key,before in pairs(case.before) do
                if key=="energy" then check(math.abs(after.energy-before)<0.000001,"buffer/reserve conservation")
                else check(helpers.table_to_json{before}==helpers.table_to_json{after[key]},case.kind .. " " .. key .. " conservation") end
            end
            check(case.surface.count_entities_filtered{name=case.target .. "-source",position=case.position}==1,"unique successor source")
            case.checked=true
        end
        if case.checked and not case.done and case.inventory.get_item_count{name=case.name,quality=case.old_quality}==1 then
            check(case.inventory.get_item_count{name=case.target,quality=case.quality}==0,"target item consumption")
            case.done=true
        end
        done=done and case.done
        check(tick-matrix.start<3400 or case.done,"actor timeout " .. case.kind .. " " .. case.name .. " -> " .. case.target)
    end
    if done then
        matrix.done=true
        local rows={}
        for _,case in ipairs(matrix.cases) do rows[#rows+1]={kind=case.kind,from=case.name,from_quality=case.old_quality,
            target=case.target,quality=case.quality,events=case.events,passed=case.done} end
        helpers.write_file("beacon-actor-matrix.json",helpers.table_to_json{passed=true,cases=rows,tick=tick},false)
    end
end
return M
