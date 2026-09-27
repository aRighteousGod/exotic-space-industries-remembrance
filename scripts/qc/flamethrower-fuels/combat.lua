local catalog=require("__exotic-space-industries-remembrance__/lib/flamethrower-fuels")
local module={}
local function begin_case()
    local surface=storage.surface
    local player=storage.actor
    player.shooting_state={state=defines.shooting.not_shooting,position={0,0}}
    if player.driving then player.driving=false end
    if storage.weapon and storage.weapon.valid then storage.weapon.destroy() end
    if storage.target and storage.target.valid then storage.target.destroy() end
    for _,entity in pairs(surface.find_entities_filtered{type={"fire","sticker","stream"}}) do entity.destroy() end
    player.teleport({0,0},surface)
    local index=storage.case
    local fuel=catalog.fuels[(index-1)%10+1]
    local mode=({"handheld","vehicle","turret"})[math.floor((index-1)%30/10)+1]
    local research=index>30
    game.forces.player.set_ammo_damage_modifier("flamethrower",research and 0.5 or 0)
    game.forces.player.set_turret_attack_modifier(catalog.base_turret,research and 0.7 or 0)
    remote.call("esir-flame-qc","sync_force",game.forces.player.index)
    storage.fuel=fuel.id
    storage.mode=mode
    storage.research=research
    player.get_inventory(defines.inventory.character_guns).clear()
    player.get_inventory(defines.inventory.character_ammo).clear()
    local distance=mode=="turret" and 20 or (mode=="vehicle" and 5 or 10)
    storage.target=surface.create_entity{name="esir-flame-qc-target",position={0,-distance},force="enemy"}
    if mode=="handheld" then
        player.get_inventory(defines.inventory.character_guns).insert{name="flamethrower",count=1}
        player.get_inventory(defines.inventory.character_ammo).insert{name=fuel.ammo,count=10}
        player.selected_gun_index=1
    elseif mode=="vehicle" then
        local car=surface.create_entity{name="tank",position={0,0},force="player"}
        car.set_driver(player)
        car.get_inventory(defines.inventory.car_ammo)[3].set_stack{name=fuel.ammo,count=10}
        car.selected_gun_index=3
        storage.weapon=car
    else
        player.teleport({8,0},surface)
        storage.weapon=surface.create_entity{name=fuel.turret,position={0,0},force="player"}
        storage.weapon.set_fluid(1,{name=fuel.fluid,amount=100})
        storage.weapon.set_fluid(2,{name=fuel.fluid,amount=100})
        storage.weapon.shooting_target=storage.target
    end
    storage.damage_start=storage.target.health
    storage.first_damage=nil
end
function module.install()
    script.on_event(defines.events.on_entity_damaged,function(event)
        if event.entity==storage.target and not storage.first_damage then storage.first_damage=event.final_damage_amount end
    end)
    script.on_init(function()
        local surface=game.create_surface("flame-combat",{width=128,height=128,autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
        local tiles={}
        for x=-50,50 do for y=-50,50 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
        surface.set_tiles(tiles)
        local player=surface.create_entity{name="character",position={0,0},force="player"}
        storage.surface=surface
        storage.actor=player
        storage.case=1
        storage.report={cases={},checks={}}
        begin_case()
    end)
    script.on_event(defines.events.on_tick,function(event)
        local controller=game.get_player(1)
        if not controller then return end
        if not storage.started then
            controller.teleport({8,0},storage.surface)
            controller.character=storage.actor
            storage.started=event.tick
            begin_case()
            game.speed=10
        end
        if storage.case>60 then return end
        local player=storage.actor
        if storage.mode~="turret" then
            controller.shooting_state={state=defines.shooting.shooting_enemies,position=storage.target.position}
        else
            local fuel=catalog.fuels[(storage.case-1)%10+1]
            storage.weapon.set_fluid(1,{name=fuel.fluid,amount=100})
        end
        if (event.tick-storage.started+1)%360==0 then
            local loss=storage.damage_start-storage.target.health
            helpers.write_file("flamethrower-combat-progress.json",helpers.table_to_json({case=storage.case,loss=loss,can_shoot=player.can_shoot(storage.target,storage.target.position),ammo=player.get_inventory(defines.inventory.character_ammo).get_contents(),target_health=storage.target.health}),false)
            assert(loss>0,"No damage from "..storage.mode.."/"..storage.fuel)
            storage.report.cases[#storage.report.cases+1]={fuel=storage.fuel,mode=storage.mode,research=storage.research,damage=loss,first_damage=storage.first_damage}
            storage.case=storage.case+1
            if storage.case<=60 then begin_case()
            else
                for group=0,5 do
                    local reference=storage.report.cases[group*10+5].damage
                    local first_reference=storage.report.cases[group*10+5].first_damage
                    for i,fuel in ipairs(catalog.fuels) do
                        local row=storage.report.cases[group*10+i]
                        row.ratio=row.damage/reference
                        -- First impact isolates native scaling from intentionally
                        -- different ground-fire lifetimes and random stream spread.
                        row.first_ratio=row.first_damage/first_reference
                        local pass=math.abs(row.first_ratio-fuel.damage)<0.001
                        storage.report.checks[row.mode.."-"..tostring(row.research).."-"..fuel.id]=pass
                    end
                end
                for index=1,30 do
                    local base=storage.report.cases[index]
                    local researched=storage.report.cases[index+30]
                    local expected=base.mode=="turret" and 2.55 or 1.5
                    storage.report.checks["research-"..base.mode.."-"..base.fuel]=math.abs(researched.first_damage/base.first_damage-expected)<0.001
                end
                storage.report.all_pass=true
                for _,passed in pairs(storage.report.checks) do if not passed then storage.report.all_pass=false end end
                helpers.write_file("flamethrower-qc.json",helpers.table_to_json(storage.report),false)
                assert(storage.report.all_pass,"Native combat damage ratios differ; inspect report")
            end
        end
    end)
end
return module
