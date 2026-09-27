local config=require("test-config")
local fuels=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local variants={"short-burst","retarget","moving-crowd","overlap","mixed-fuels","minimum-range","maximum-range","resistance","starvation"}
local function report()
    local result={profile=config.profile,cases={},all_pass=true}
    for _,case in ipairs(storage.cases) do
        local row={kind=case.kind,scenario=case.scenario,damage=case.damage,events=case.events,first_hit=case.first_hit,
            last_direct_hit=case.last_direct_hit,post_stop_damage=case.post_stop_damage,
            recovered_damage=case.recovered_damage,second_target_damage=case.second_target_damage,peak_stickers=case.peak_stickers}
        local passed=row.damage>0
        if case.scenario=="starvation" then passed=passed and row.recovered_damage>0 end
        if case.scenario=="retarget" then passed=passed and row.second_target_damage>0 end
        row.passed=passed
        if not passed then result.all_pass=false end
        result.cases[#result.cases+1]=row
    end
    helpers.write_file("thrower-behavior.json",helpers.table_to_json(result),false)
    assert(result.all_pass,"Behavior fixture failed")
end
script.on_init(function()
    storage.start=game.tick;storage.cases={};storage.targets={}
    local surface=game.create_surface("thrower-behavior",{width=1200,height=600,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    storage.surface=surface
    for _,kind in ipairs{"flame","acid"} do for _,scenario in ipairs(variants) do
        local i=#storage.cases
        local x,y=(i%9)*120-500,math.floor(i/9)*160-100
        surface.request_to_generate_chunks({x,y},2);surface.force_generate_chunk_requests()
        local tiles={}
        for tx=x-15,x+15 do for ty=y-45,y+12 do tiles[#tiles+1]={name="refined-concrete",position={tx,ty}} end end
        surface.set_tiles(tiles)
        local case={kind=kind,scenario=scenario,x=x,y=y,turrets={},targets={},damage=0,events=0,post_stop_damage=0,recovered_damage=0,second_target_damage=0,peak_stickers=0}
        local distance=scenario=="minimum-range" and 9.5 or scenario=="maximum-range" and 37.5 or 20
        local target_name=scenario=="resistance" and "esir-thrower-qc-resistant" or scenario=="moving-crowd" and "esir-thrower-qc-moving" or "esir-thrower-qc-target"
        for n=1,(scenario=="moving-crowd" and 6 or 1) do
            local target=surface.create_entity{name=target_name,position={x+(n-1)*3,y-distance},force="enemy"}
            if scenario=="moving-crowd" then target.commandable.set_command{type=defines.command.go_to_location,destination={x+(n-1)*3,y+10},distraction=defines.distraction.none} else target.active=false end
            case.targets[#case.targets+1]=target;storage.targets[target.unit_number]={case=case,second=false}
        end
        for n=1,((scenario=="overlap" or scenario=="mixed-fuels") and 2 or 1) do
            local fuel=fuels.by_fluid[scenario=="mixed-fuels" and n==2 and "heavy-oil" or "crude-oil"]
            local fluid=kind=="acid" and (n==2 and "ei-nitric-acid" or "sulfuric-acid") or fuel.fluid
            local name=kind=="acid" and "ei-acidthrower-turret" or (config.adaptation and fuel.turret or fuels.base_turret)
            local turret=surface.create_entity{name=name,position={x+(n-1)*4,y},force="player",raise_built=true}
            turret.set_fluid(1,{name=fluid,amount=100});turret.set_fluid(2,{name=fluid,amount=100});turret.shooting_target=case.targets[1]
            case.turrets[#case.turrets+1]={entity=turret,fluid=fluid}
        end
        storage.cases[#storage.cases+1]=case
    end end
end)
script.on_event(defines.events.on_entity_damaged,function(event)
    local record=storage.targets[event.entity.unit_number]
    if not record then return end
    local case=record.case
    local tick=event.tick-storage.start
    case.first_hit=case.first_hit or tick;case.damage=case.damage+event.final_damage_amount;case.events=case.events+1
    local factor=config.profile=="original" and 1 or tonumber(config.profile:match("%d+"))
    if math.abs(event.original_damage_amount-(case.kind=="acid" and 3.3 or 3)*factor)<0.0001 then case.last_direct_hit=tick end
    if case.scenario=="short-burst" and tick>150 then case.post_stop_damage=case.post_stop_damage+event.final_damage_amount end
    if case.scenario=="starvation" and tick>1300 then case.recovered_damage=case.recovered_damage+event.final_damage_amount end
    if record.second then case.second_target_damage=case.second_target_damage+event.final_damage_amount end
end)
script.on_event(defines.events.on_tick,function(event)
    local tick=event.tick-storage.start
    for _,case in ipairs(storage.cases) do
        if tick==150 and case.scenario=="short-burst" then for _,turret in ipairs(case.turrets) do turret.entity.active=false end end
        if tick==300 and case.scenario=="retarget" then
            case.targets[1].teleport({case.x,case.y-70})
            local target=storage.surface.create_entity{name="esir-thrower-qc-target",position={case.x+8,case.y-20},force="enemy"}
            target.active=false;case.targets[#case.targets+1]=target;storage.targets[target.unit_number]={case=case,second=true}
            case.turrets[1].entity.shooting_target=target
        end
        if tick%60==0 then
            for _,target in ipairs(case.targets) do case.peak_stickers=math.max(case.peak_stickers,#(target.stickers or {})) end
            if case.scenario~="starvation" or tick>=1200 then
                for _,turret in ipairs(case.turrets) do
                    turret.entity.set_fluid(1,{name=turret.fluid,amount=100});turret.entity.set_fluid(2,{name=turret.fluid,amount=100})
                end
            end
        end
    end
    if tick==3600 then report() end
end)
