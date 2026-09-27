-- Native firing benchmark. Timed runs install no damage-event listener.
-- A separate diagnostic replay records event counts without contaminating timings.
local config = require("test-config")
local fuels = require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local warmup, duration = 600, 1800
local scenarios={}
for _,population in ipairs{100,500,1000} do
    for _,kind in ipairs{"flame","acid","mixed"} do scenarios[#scenarios+1]={population=population,kind=kind} end
end
local function begin_phase(index)
    local surface=storage.surface
    for _,entity in pairs(surface.find_entities()) do if entity.valid then entity.destroy() end end
    storage.cases={};storage.by_target={};storage.events=0
    local scenario=scenarios[index]
    for i=1,scenario.population do
        local acid=scenario.kind=="acid" or scenario.kind=="mixed" and i%2==0
        local fuel=fuels.fuels[(i-1)%#fuels.fuels+1]
        local name=acid and "ei-acidthrower-turret" or (config.adaptation and fuel.turret or fuels.base_turret)
        local fluid=acid and "sulfuric-acid" or fuel.fluid
        local x,y=((i-1)%32)*64-1000,math.floor((i-1)/32)*64-1000
        local turret=surface.create_entity{name=name,position={x,y},force="player",raise_built=true}
        local target=surface.create_entity{name="esir-thrower-qc-target",position={x,y-20},force="enemy"}
        target.active=false
        turret.set_fluid(1,{name=fluid,amount=100});turret.set_fluid(2,{name=fluid,amount=100})
        turret.shooting_target=target
        storage.cases[#storage.cases+1]={turret=turret,target=target,fluid=fluid}
        storage.by_target[target.unit_number]=true
    end
end
script.on_init(function()
    storage.start=game.tick;storage.phase=1;storage.reports={}
    local surface=game.create_surface("thrower-performance",{width=2200,height=2200,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},34);surface.force_generate_chunk_requests()
    storage.surface=surface
    local tiles={}
    for i=1,1000 do
        local x,y=((i-1)%32)*64-1000,math.floor((i-1)/32)*64-1000
        for tx=x-3,x+3 do for ty=y-22,y+3 do tiles[#tiles+1]={name="refined-concrete",position={tx,ty}} end end
    end
    surface.set_tiles(tiles)
    begin_phase(1)
end)
if config.diagnostic then
    script.on_event(defines.events.on_entity_damaged,function(event)
        local elapsed=(event.tick-storage.start)%(warmup+duration)
        if elapsed>warmup and storage.by_target[event.entity.unit_number] then storage.events=storage.events+1 end
    end)
end
script.on_event(defines.events.on_tick,function(event)
    if storage.phase>#scenarios or event.tick<=storage.start then return end
    local elapsed=(event.tick-storage.start-1)%(warmup+duration)+1
    if elapsed%60==0 then
        for _,case in ipairs(storage.cases) do
            case.turret.set_fluid(1,{name=case.fluid,amount=100});case.turret.set_fluid(2,{name=case.fluid,amount=100})
        end
    end
    if elapsed==warmup then
        for _,case in ipairs(storage.cases) do case.initial=case.target.health end
    elseif elapsed==warmup+duration then
        local scenario=scenarios[storage.phase]
        local damage,firing,idle=0,0,{}
        for _,case in ipairs(storage.cases) do
            local loss=case.initial-case.target.health
            damage=damage+loss
            if loss>0 then firing=firing+1 else
                idle[#idle+1]={name=case.turret.name,position=case.turret.position,status=case.turret.status,
                    fluid=case.turret.get_fluid(1),active=case.turret.active}
            end
        end
        local report={population=scenario.population,kind=scenario.kind,damage=damage,firing=firing,idle=idle,
            damage_events=config.diagnostic and storage.events or nil,
            first_timed_tick=(storage.phase-1)*(warmup+duration)+warmup+1,last_timed_tick=storage.phase*(warmup+duration)-1,effects={}}
        for _,kind in ipairs{"stream","fire","sticker"} do report.effects[kind]=storage.surface.count_entities_filtered{type=kind} end
        storage.reports[#storage.reports+1]=report
        helpers.write_file("thrower-performance.json",helpers.table_to_json({profile=config.profile,diagnostic=config.diagnostic,scenarios=storage.reports}),false)
        assert(firing==scenario.population,"Not every benchmark turret was firing: "..scenario.kind.." "..firing.."/"..scenario.population)
        storage.phase=storage.phase+1
        if storage.phase<=#scenarios then begin_phase(storage.phase) end
    end
end)
