local config=require("test-config")
local fuels=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
script.on_init(function()
    -- A fresh single-player save otherwise pauses at Freeplay's intro dialog.
    if remote.interfaces.freeplay then
        remote.call("freeplay","set_skip_intro",true)
        remote.call("freeplay","set_disable_crashsite",true)
    end
    local surface=game.create_surface("thrower-visual",{width=160,height=160,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    local tiles={}
    for x=-40,40 do for y=-35,35 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    game.forces.player.chart(surface,{{-80,-80},{80,80}})
    rendering.draw_text{text="Thrower performance: "..config.profile,surface=surface,target={0,-31},color={1,1,1},alignment="center"}
    storage.surface=surface;storage.cases={};storage.start=game.tick
    for i=1,14 do
        local fuel=fuels.fuels[i]
        local x,y=fuel and (i-5.5)*6 or (i-12.5)*12,fuel and -2 or 28
        local fluid=fuel and fuel.fluid or ({"ei-acidic-water","sulfuric-acid","ei-nitric-acid","ei-hydrofluoric-acid"})[i-10]
        rendering.draw_text{text={"fluid-name."..fluid},surface=surface,target={x,y+4},color={1,1,1},scale=0.65,alignment="center"}
        local turret=surface.create_entity{name=fuel and fuel.turret or "ei-acidthrower-turret",position={x,y},force="player"}
        local target=surface.create_entity{name="esir-thrower-qc-target",position={x,y-20},force="enemy"};target.active=false
        turret.set_fluid(1,{name=fluid,amount=100});turret.set_fluid(2,{name=fluid,amount=100});turret.shooting_target=target
        storage.cases[#storage.cases+1]={turret=turret,fluid=fluid}
    end
end)
script.on_event(defines.events.on_tick,function(event)
    local tick=event.tick-storage.start
    if tick%60==0 then
        for _,case in ipairs(storage.cases) do case.turret.set_fluid(1,{name=case.fluid,amount=100});case.turret.set_fluid(2,{name=case.fluid,amount=100}) end
    end
    if tick==1201 then
        for _,case in ipairs(storage.cases) do case.turret.active=false end
    end
    if tick==600 or tick==1200 or tick==1230 or tick==1300 or tick==1380 then
        log("THROWER_QC_VISUAL profile="..config.profile.." tick="..tick)
        for _,daytime in ipairs{0,0.5} do
            game.take_screenshot{surface=storage.surface,position={0,0},resolution={1440,1280},zoom=0.6,daytime=daytime,
                path="thrower-"..config.profile.."-"..tick.."-"..daytime..".png",show_gui=false,force_render=true}
        end
    end
end)
