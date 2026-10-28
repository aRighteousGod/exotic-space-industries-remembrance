-- Real native AI groups colonise a clear fixture surface in both supported modes.
script.on_init(function()
    local surface=game.create_surface("esir-armoured-qc",{width=320,height=512})
    surface.request_to_generate_chunks({0,0},8)
    surface.force_generate_chunk_requests()
    for _, entity in pairs(surface.find_entities()) do entity.destroy() end
    local tiles={}
    for x=-110,130 do for y=-160,160 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles)
    game.forces.enemy.set_evolution_factor(1,surface)
    storage.surface=surface
    storage.groups={}
    for index,tier in ipairs{"small","medium","big","behemoth","leviathan"} do
        local y=(index-3)*60
        local group=surface.create_unit_group{position={-60,y},force="enemy"}
        for number=1,50 do
            local entity=surface.create_entity{name=tier .. "-armoured-biter",position={-80+(number%10)*2,y+math.floor(number/10)*2},force="enemy"}
            assert(entity and entity.commandable,"Native Armoured entity is commandable")
            group.add_member(entity)
        end
        assert(#group.commandable_members==50,"Native group membership")
        group.set_command{type=defines.command.build_base,destination={70,y},distraction=defines.distraction.none}
        group.start_moving()
        storage.groups[#storage.groups+1]={tier=tier,group=group,y=y}
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.done or event.tick<3600 then return end
    local rows={}
    for _,entry in ipairs(storage.groups) do
        local built=storage.surface.find_entities_filtered{type={"unit-spawner","turret"},force="enemy",area={{35,entry.y-28},{110,entry.y+28}}}
        local names={}
        for _,entity in ipairs(built) do
            names[#names+1]=entity.name
            if settings.startup["ab-enable-nest"].value then assert(entity.name=="armoured-biter-spawner","Separate nest native expansion identity") end
        end
        table.sort(names)
        rows[#rows+1]={tier=entry.tier,buildings=names,group_valid=entry.group.valid,
            members=entry.group.valid and #entry.group.commandable_members or 0}
    end
    local passed=true
    for _,entry in ipairs(rows) do if #entry.buildings==0 then passed=false end end
    helpers.write_file("armoured-native.json",helpers.table_to_json{passed=passed,engine=script.active_mods.base,
        package=script.active_mods.ArmouredBiters21Compat,separate_nests=settings.startup["ab-enable-nest"].value,groups=rows},false)
    for _,entry in ipairs(rows) do assert(#entry.buildings>0,"Native expansion did not build for tier " .. entry.tier) end
    storage.done=true
    log("ESIR ARMOURED NATIVE EXPANSION PASS")
end)
