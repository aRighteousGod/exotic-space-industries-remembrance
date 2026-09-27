local config = require("test-config")
if config.mode == "performance" then require("performance"); return end
if config.mode == "behavior" then require("behavior"); return end
if config.mode == "transition" then require("transition"); return end
if config.mode == "expiry" then require("expiry"); return end
if config.mode == "visual" then require("visual"); return end
local fuels = require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local warmup, measured = 3600, 7200
local function finish()
    local report = {profile=config.profile,adaptation=config.adaptation,mode=config.mode,cases={},all_fired=true}
    for _,case in ipairs(storage.cases) do
        local row = {key=case.key,damage=case.damage,events=case.events,fluid=case.fluid,first_hit=case.first_hit,
            dps=case.damage/(measured/60),fluid_per_second=case.fluid/(measured/60),stickers=#(case.target.stickers or {}),
            warmup_damage_per_second=case.warmup_damage}
        if case.component~="ground" or case.kind~="acid" then
            if row.damage<=0 then report.all_fired=false end
        end
        report.cases[#report.cases+1]=row
    end
    report.effects={}
    for _,kind in ipairs{"stream","fire","sticker"} do report.effects[kind]=storage.surface.count_entities_filtered{type=kind} end
    helpers.write_file("thrower-report.json",helpers.table_to_json(report),false)
    assert(report.all_fired,"An expected damage component did not fire")
end
script.on_init(function()
    local surface = game.create_surface("thrower-qc",{width=2048,height=2048,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.daytime=0.3;surface.freeze_daytime=true
    storage.surface=surface;storage.cases={};storage.by_target={};storage.start=game.tick
    local fluid_rows={}
    for _,fuel in ipairs(fuels.fuels) do fluid_rows[#fluid_rows+1]={fuel=fuel.fluid,turret=config.adaptation and fuel.turret or fuels.base_turret,kind="flame"} end
    for _,name in ipairs{"ei-acidic-water","sulfuric-acid","ei-nitric-acid","ei-hydrofluoric-acid"} do
        fluid_rows[#fluid_rows+1]={fuel=name,turret="ei-acidthrower-turret",kind="acid"}
    end
    for research=0,1 do
        local force=game.create_force("thrower-qc-"..research)
        force.set_ammo_damage_modifier("flamethrower",research*0.5)
        for name in pairs(prototypes.entity) do
            if name:find("esir-thrower-qc-",1,true)==1 and prototypes.entity[name].type=="fluid-turret" then force.set_turret_attack_modifier(name,research*0.7) end
        end
        for _,quality in ipairs{"normal","legendary"} do
            for _,row in ipairs(fluid_rows) do
                for _,component in ipairs{"direct","sticker","ground","combined"} do
                    if row.kind~="acid" or component~="ground" then
                        local index=#storage.cases
                        local x,y=(index%16)*100-800,math.floor(index/16)*100-800
                        surface.request_to_generate_chunks({x,y},1);surface.force_generate_chunk_requests()
                        local tiles={}
                        for tx=x-4,x+4 do for ty=y-25,y+4 do tiles[#tiles+1]={name="refined-concrete",position={tx,ty}} end end
                        surface.set_tiles(tiles)
                        local turret=surface.create_entity{name="esir-thrower-qc-"..component.."-"..row.turret,position={x,y},force=force,quality=quality}
                        local target=surface.create_entity{name="esir-thrower-qc-target",position={x,y-20},force="enemy"}
                        target.active=false
                        turret.set_fluid(1,{name=row.fuel,amount=100});turret.set_fluid(2,{name=row.fuel,amount=100})
                        turret.shooting_target=target
                        local case={turret=turret,target=target,fuel=row.fuel,component=component,kind=row.kind,damage=0,events=0,fluid=0,warmup_damage={},
                            key=row.fuel.."/"..quality.."/"..research.."/"..component}
                        for second=1,warmup/60 do case.warmup_damage[second]=0 end
                        storage.cases[#storage.cases+1]=case;storage.by_target[target.unit_number]=case
                    end
                end
            end
        end
    end
end)
script.on_event(defines.events.on_entity_damaged,function(event)
    local case=storage.by_target[event.entity.unit_number]
    if not case then return end
    case.first_hit=case.first_hit or event.tick-storage.start
    local elapsed=event.tick-storage.start
    if elapsed>warmup and elapsed<=warmup+measured then
        case.damage=case.damage+event.final_damage_amount;case.events=case.events+1
    elseif elapsed>0 and elapsed<=warmup then
        local second=math.ceil(elapsed/60)
        case.warmup_damage[second]=(case.warmup_damage[second] or 0)+event.final_damage_amount
    end
end)
script.on_event(defines.events.on_tick,function(event)
    local elapsed=event.tick-storage.start
    if elapsed%60==0 then
        for _,case in ipairs(storage.cases) do
            local amount=0
            for i=1,2 do local fluid=case.turret.get_fluid(i);amount=amount+(fluid and fluid.amount or 0) end
            if elapsed>warmup and elapsed<=warmup+measured then case.fluid=case.fluid+200-amount end
            case.turret.set_fluid(1,{name=case.fuel,amount=100});case.turret.set_fluid(2,{name=case.fuel,amount=100})
        end
    end
    if elapsed==warmup+measured then finish() end
end)
