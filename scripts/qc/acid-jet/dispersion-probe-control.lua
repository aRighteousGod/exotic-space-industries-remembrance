local function setup(tick)
    local s=game.create_surface("acid-dispersion-probe",{width=768,height=768,autoplace_controls={},
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    s.freeze_daytime=true;s.daytime=0
    local root={start=tick,cases={},by_unit={},captures={}};storage.dispersion=root
    for row,kind in ipairs{"fixed","scale","playback","flecks"} do for column,distance in ipairs{9.02,24,37.98} do
        local p={x=(column-2)*160+.5,y=(row-2.5)*128+.5}
        s.request_to_generate_chunks(p,2);s.force_generate_chunk_requests()
        for _,e in pairs(s.find_entities_filtered{area={{p.x-64,p.y-64},{p.x+64,p.y+64}},type={"unit","unit-spawner","turret","tree"}}) do e.destroy() end
        local tiles={};for x=p.x-5,p.x+46 do for y=p.y-5,p.y+5 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end;s.set_tiles(tiles)
        local turret=s.create_entity{name="acid-dispersion-"..kind,position=p,direction=defines.direction.east,force="player"}
        p=turret.position
        local target=s.create_entity{name="acid-dispersion-target",position={p.x+distance,p.y},force="enemy"};target.active=false
        turret.set_fluid(1,{name="sulfuric-acid",amount=100});turret.set_fluid(2,{name="sulfuric-acid",amount=100});turret.shooting_target=target
        local case={turret=turret,p=p,q=target.position,kind=kind,distance=distance,launches={},lands={}}
        root.cases[#root.cases+1]=case;root.by_unit[turret.unit_number]=case
    end end
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    local root=storage.dispersion;if not root then return end
    local case=event.source_entity and event.source_entity.valid and root.by_unit[event.source_entity.unit_number]
    if event.effect_id=="acid-dispersion-source" and case then
        case.launches[#case.launches+1]=event.tick;case.source=event.source_position
    elseif event.effect_id=="acid-dispersion-land" then
        local point=event.target_position or event.source_position
        if point then for _,candidate in ipairs(root.cases) do
            if (candidate.q.x-point.x)^2+(candidate.q.y-point.y)^2<4 then candidate.lands[#candidate.lands+1]=event.tick;break end
        end end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if not storage.dispersion then setup(event.tick) end
    local root=storage.dispersion
    for _,case in ipairs(root.cases) do
        local first=case.launches[1]
        local age=first and event.tick-first
        if age and (age==2 or age==6 or age==12 or age==18 or age==24 or age==32 or age==40 or age==48 or age==60 or age==248 or age==264) then
            local name=case.kind.."-"..case.distance.."-"..age
            game.take_screenshot{surface=case.turret.surface,position={(case.p.x+case.q.x)/2,case.p.y-1},
                resolution={1600,384},zoom=1,path="captures/"..name..".png",show_gui=false,show_entity_info=false,
                anti_alias=false,force_render=true,daytime=0}
            root.captures[#root.captures+1]=name
        end
    end
    if event.tick-root.start==350 then
        local result={cases={},captures=root.captures}
        for _,case in ipairs(root.cases) do result.cases[#result.cases+1]={kind=case.kind,distance=case.distance,
            source=case.source,p=case.p,q=case.q,launches=case.launches,lands=case.lands} end
        helpers.write_file("dispersion-probe.json",helpers.table_to_json(result),false)
    end
end)
