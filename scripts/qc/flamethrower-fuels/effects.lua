local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local module={}
function module.install(config)
    script.on_init(function()
        local surface=game.create_surface("flame-effects",{width=256,height=128,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-110,110 do for y=-45,45 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
        surface.set_tiles(tiles)
        surface.freeze_daytime=true;surface.daytime=0
        storage.surface=surface
        storage.started=game.tick
        storage.cases={}
        for index,fuel in ipairs(catalog.fuels) do
            local x=(index-5.5)*20
            local name="ei-flame-"..fuel.id.."-ammo-fire"
            storage.cases[index]={name=name,fuel=fuel.id,x=x,
                single=surface.create_entity{name=name,position={x,0},force="player"},
                fed=surface.create_entity{name=name,position={x,20},force="player"}}
            rendering.draw_text{text=fuel.id,surface=surface,target={x,-8},color={1,1,1},alignment="center",scale=1.5}
        end
        for _,fuel in ipairs(catalog.fuels) do
            surface.create_entity{name="ei-flame-"..fuel.id.."-handheld-flamethrower-fire-stream",position={0,-35},source_position={0,-35},target_position={0,-30},force="player"}
            surface.create_entity{name="ei-flame-crude-oil-handheld-flamethrower-fire-stream",position={20,-35},source_position={20,-35},target_position={20,-30},force="player"}
        end
    end)
    script.on_event(defines.events.on_tick,function(event)
        local elapsed=event.tick-storage.started
        for _,case in ipairs(storage.cases) do
            if not case.single.valid and not case.single_expired then case.single_expired=elapsed end
            if elapsed<=400 and elapsed%5==0 then
                storage.surface.create_entity{name="ei-flame-"..case.fuel.."-handheld-flamethrower-fire-stream",position={case.x,15},source_position={case.x,15},target_position={case.x,20},force="player"}
            elseif not case.fed.valid and not case.fed_expired then case.fed_expired=elapsed end
        end
        if elapsed==60 then
            storage.overlap=storage.surface.count_entities_filtered{area={{-4,-34},{4,-26}},type="fire"}
            storage.same_fuel_overlap=storage.surface.count_entities_filtered{area={{16,-34},{24,-26}},type="fire"}
        end
        if config.visual and (elapsed==90 or elapsed==95) then
            storage.surface.daytime=elapsed==90 and 0 or 0.5
            game.take_screenshot{surface=storage.surface,position={0,4},resolution={2400,900},zoom=0.35,
                show_gui=false,path=elapsed==90 and "flame-day.png" or "flame-night.png"}
        end
        if elapsed==6500 then
            local report={all_pass=true,overlap=storage.overlap,same_fuel_overlap=storage.same_fuel_overlap,cases={}}
            assert(storage.overlap==1 and storage.same_fuel_overlap==1,"Newest ground fire must replace overlapping fuels")
            local crude=storage.cases[5]
            for index,case in ipairs(storage.cases) do
                report.cases[#report.cases+1]={fuel=case.fuel,single=case.single_expired,fed=case.fed_expired}
                if not case.single_expired or not case.fed_expired or case.fed_expired<=case.single_expired then report.all_pass=false end
                -- Entity validity includes the unchanged 1,800-tick burnt patch.
                -- Compare lifetimes relative to crude to remove that shared tail.
                local delta=catalog.fuels[index].lifetime-1
                if math.abs(case.single_expired-crude.single_expired-120*delta)>10 then report.all_pass=false end
                if math.abs(case.fed_expired-crude.fed_expired-1800*delta)>10 then report.all_pass=false end
            end
            helpers.write_file("flamethrower-qc.json",helpers.table_to_json(report),false)
            assert(report.all_pass,"Ground-fire lifetime test failed")
        end
    end)
end
return module
