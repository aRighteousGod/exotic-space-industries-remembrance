local config=require("test-config")
local fuels=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local function sticker_names(target)
    local names={}
    for _,sticker in pairs(target.stickers or {}) do names[#names+1]=sticker.name end
    return names
end
script.on_init(function()
    storage.start=game.tick;storage.cases={};storage.checks={};storage.history={}
    local surface=game.create_surface("thrower-transition",{width=1600,height=200,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface=surface
    for i=1,14 do
        local fuel=fuels.fuels[i]
        local fluid=fuel and fuel.fluid or ({"ei-acidic-water","sulfuric-acid","ei-nitric-acid","ei-hydrofluoric-acid"})[i-10]
        local name=fuel and (config.adaptation and fuel.turret or fuels.base_turret) or "ei-acidthrower-turret"
        local x=(i-1)*100-650
        surface.request_to_generate_chunks({x,0},1);surface.force_generate_chunk_requests()
        local tiles={}
        for tx=x-3,x+3 do for ty=-25,4 do tiles[#tiles+1]={name="refined-concrete",position={tx,ty}} end end
        surface.set_tiles(tiles)
        local turret=surface.create_entity{name=name,position={x,0},force="player",quality="legendary",raise_built=true}
        local target=surface.create_entity{name="esir-thrower-qc-target",position={x,-20},force="enemy"};target.active=false
        turret.health=turret.health*0.8
        turret.set_fluid(1,{name=fluid,amount=100});turret.set_fluid(2,{name=fluid,amount=100});turret.shooting_target=target
        storage.cases[#storage.cases+1]={turret=turret,target=target,fluid=fluid,peak_stickers=0}
    end
end)
script.on_configuration_changed(function()
    storage.start=game.tick
    for i,case in ipairs(storage.cases) do
        local old=storage.saved[i]
        local turret=case.turret
        storage.checks[#storage.checks+1]={name="state-"..config.profile.."-"..i,passed=turret.valid and turret.unit_number==old.unit and turret.name==old.name and turret.quality.name==old.quality and math.abs(turret.health-old.health)<0.01}
        case.peak_stickers=0
        case.loaded_stickers=sticker_names(case.target)
    end
end)
script.on_event(defines.events.on_tick,function(event)
    local elapsed=event.tick-storage.start
    for _,case in ipairs(storage.cases) do
        case.peak_stickers=math.max(case.peak_stickers,#(case.target.stickers or {}))
    end
    if elapsed%60==0 then
        for _,case in ipairs(storage.cases) do
            case.turret.set_fluid(1,{name=case.fluid,amount=100});case.turret.set_fluid(2,{name=case.fluid,amount=100})
        end
    end
    if elapsed==900 then
        storage.saved={}
        local phase={profile=config.profile,tick=event.tick,cases={}}
        for i,case in ipairs(storage.cases) do
            local turret=case.turret
            storage.saved[i]={unit=turret.unit_number,name=turret.name,quality=turret.quality.name,health=turret.health}
            phase.cases[#phase.cases+1]={fluid=case.fluid,peak_stickers=case.peak_stickers,stickers=#(case.target.stickers or {}),
                loaded_stickers=case.loaded_stickers,sticker_names=sticker_names(case.target)}
        end
        storage.history[#storage.history+1]=phase
        local report={all_pass=true,checks=storage.checks,history=storage.history,tick=event.tick}
        for _,check in ipairs(storage.checks) do if not check.passed then report.all_pass=false end end
        helpers.write_file("thrower-transition.json",helpers.table_to_json(report),false)
        assert(report.all_pass,"Transition changed turret state")
        game.server_save("thrower-transition-"..config.profile)
    end
end)
