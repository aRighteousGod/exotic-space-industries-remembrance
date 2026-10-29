-- Private native-player replacement matrix; separate from physical input evidence.
---@class NSBCPlayerMatrix
local M = {}
---@param entity LuaEntity
---@return NSBRecord
local function record(entity) return remote.call("nonstandard-beacons", "get-beacon-data", entity.unit_number) end
---@param player LuaPlayer
function M.run(player)
    local cases, results = {}, {}
    for _, pair in ipairs{{"ei-copper-beacon", "ei-iron-beacon"}, {"ei-alien-beacon", "ei-warp-beacon"}} do
        cases[#cases+1]={pair[1],pair[2],"normal","rare"}
        cases[#cases+1]={pair[2],pair[1],"rare","normal"}
        for _,name in ipairs(pair) do
            cases[#cases+1]={name,name,"normal","rare"}
            cases[#cases+1]={name,name,"rare","normal"}
        end
    end
    local surface=game.create_surface("nsbc-player-matrix",{width=64,height=64})
    surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles={}
    for x=-25,25 do for y=-25,25 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    player.set_controller{type=defines.controllers.god}
    player.teleport({0,0},surface)
    player.force.unlock_quality("rare")
    for _,case in ipairs(cases) do
        local body=assert(surface.create_entity{name=case[1],quality=case[3],position={0.5,0.5},force=player.force,raise_built=true})
        body.get_module_inventory().insert{name="speed-module",quality="rare",count=4}
        local source=record(body).source
        source.disabled_by_script=true
        if source.burner then
            source.get_fuel_inventory().insert{name="ei-bio-matter",quality="rare",count=9}
            source.burner.currently_burning={name="ei-bio-matter",quality="rare"}
            source.burner.remaining_burning_fuel=12345
        else source.set_fluid(1,{name="ei-liquid-nitrogen",amount=77,temperature=43}) end
        -- Setting the burning item can reset its heat. Snapshot the actual
        -- engine-accepted energy after seeding all fuel, rather than the request.
        source.energy=123
        local energy_before=source.energy+(record(body).energy_reserve or 0)
        assert(remote.call("nonstandard-beacons","set-beacon-orientation",body,12,true))
        -- Portless burner helpers can normalize mirroring. Their actual source
        -- orientation is authoritative, just as in the robot/platform matrix.
        local direction_before, mirrored_before=source.direction, source.mirroring
        player.cursor_stack.set_stack{name=case[2],quality=case[4],count=1}
        player.build_from_cursor{position={0.5,0.5}}
        assert(not body.valid,"Player replacement failed: " .. table.concat(case,"/"))
        local successor=assert(surface.find_entities_filtered{name=case[2],position={0.5,0.5}}[1])
        local data=record(successor);source=data.source
        assert(data.phase=="attached" and source.disabled_by_script and successor.quality.name==case[4])
        assert(source.direction==direction_before and source.mirroring==mirrored_before,
            "Player orientation custody: " .. table.concat(case,"/"))
        assert(math.abs(source.energy+(data.energy_reserve or 0)-energy_before)<0.000001,
            "Player energy custody: " .. table.concat(case,"/"))
        assert(successor.get_module_inventory().get_item_count{name="speed-module",quality="rare"}==4)
        if source.burner then
            assert(source.get_fuel_inventory().get_item_count{name="ei-bio-matter",quality="rare"}==9)
            assert(source.burner.remaining_burning_fuel==12345 and source.burner.currently_burning.quality.name=="rare")
        else
            local fluid=source.get_fluid(1)
            assert(fluid.name=="ei-liquid-nitrogen" and fluid.amount==77 and fluid.temperature==43)
        end
        results[#results+1]={from=case[1],target=case[2],from_quality=case[3],quality=case[4],passed=true}
        successor.destroy{raise_destroy=true}
    end
    player.cursor_stack.clear()
    helpers.write_file("beacon-player-matrix.json",helpers.table_to_json{passed=true,cases=results,physical_input=false},false)
end
return M
