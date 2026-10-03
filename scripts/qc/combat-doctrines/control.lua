local test=require("test-config")
if test.mode=="overlap" then require("overlap");return end
if test.mode=="visual" then require("visual");return end
if test.mode=="performance" or test.mode=="rendering" then require("performance");return end
if test.mode=="transition" then require("transition");return end
local magazines={"firearm-magazine","piercing-rounds-magazine","uranium-rounds-magazine","ei-compound-ammo",
    "ei-corrosive-ammo","ei-cryo-ammo","ei-oxyfluoride-ammo","ei-morphium-ammo","ei-hexafluoride-ammo","ei-arc-ammo","ei-neutron-ammo"}
local shells={"shotgun-shell","piercing-shotgun-shell","ei-uranium-shotgun-shell","ei-dragons-breath-shotgun-shell"}
local catalog=require("__exotic-space-industries-remembrance__/lib/spider-vehicles")
local function list(node) return node and (node.type and {node} or node) or {} end
local function damage(actions,multiplier,physical_only)
    local total=0
    for _,a in ipairs(list(actions)) do
        if a.type=="direct" then
            for _,d in ipairs(list(a.action_delivery)) do
                for _,e in ipairs(list(d.target_effects)) do
                    if e.type=="damage" and (not physical_only or e.damage.type=="physical") then
                        total=total+e.damage.amount*(a.repeat_count or 1)*(multiplier or 1)
                    end
                end
            end
        end
    end
    return total
end
local function expectation(ammo)
    local total,pellets=0,0
    for _,a in ipairs(list(prototypes.item[ammo].get_ammo_type("turret").action)) do
        for _,d in ipairs(list(a.action_delivery)) do
            if d.type=="projectile" then
                total=total+damage(prototypes.entity[d.projectile].attack_result,a.repeat_count or 1,ammo=="ei-dragons-breath-shotgun-shell")
                pellets=pellets+(a.repeat_count or 1)
            elseif d.type=="instant" then
                total=total+damage({a})
            end
        end
    end
    return total,pellets
end
local function check(name,pass,detail)
    storage.report.checks[#storage.report.checks+1]={name=name,pass=pass==true,detail=detail}
end
local function begin_case(tick)
    for _,e in pairs(storage.surface.find_entities_filtered{type={"ammo-turret","combat-robot","character","spider-vehicle","projectile","fire","sticker","simple-entity-with-owner","tree","simple-entity"}}) do e.destroy() end
    local c=storage.queue[storage.index]
    c.started=tick;c.damage={};c.launches=0;c.created=0;c.impacts=0;c.flashes=0;c.spider_observations=0
    storage.current=c
    local force=game.forces.player
    force.set_ammo_damage_modifier("bullet",c.research and .5 or 0)
    force.set_ammo_damage_modifier("shotgun-shell",c.research and .5 or 0)
    force.set_turret_attack_modifier("ei-combat-doctrines-qc-bullet",c.turret_research and .5 or 0)
    force.set_turret_attack_modifier("ei-shotgun-turret",c.turret_research and .5 or 0)
    local target=storage.surface.create_entity{name=c.distance and c.distance>50 and "ei-combat-doctrines-qc-range-target"
        or "ei-combat-doctrines-qc-target",position={c.distance or 8,0},force="enemy"}
    c.target=target;c.target_health=target.health
    if c.mode=="defender" then
        local owner=storage.surface.create_entity{name="character",position={0,0},force=force}
        c.weapon=storage.surface.create_entity{name="defender",position={2,0},force=force,quality=c.quality or "normal"}
        c.weapon.combat_robot_owner=owner
    elseif c.mode=="spider" then
        c.weapon=storage.surface.create_entity{name=catalog.variant_name("assault",{mg=c.tier or 0}),position={0,0},force=force,quality=c.quality or "normal"}
        c.weapon.get_inventory(defines.inventory.fuel).insert{name="coal",count=10}
        c.weapon.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=true}
        local stack=c.weapon.get_inventory(defines.inventory.spider_ammo)[2]
        stack.set_stack{name=c.ammo,count=1,quality=c.quality or "normal"};stack.ammo=1
    elseif c.mode=="character" then
        c.weapon=storage.surface.create_entity{name="character",position={0,0},force=force}
        c.weapon.get_inventory(defines.inventory.character_guns)[1].set_stack{name=c.gun_name}
        local stack=c.weapon.get_inventory(defines.inventory.character_ammo)[1]
        stack.set_stack{name=c.ammo,count=1};stack.ammo=1
        c.weapon.shooting_state={state=defines.shooting.shooting_enemies,position=c.target.position}
    else
        c.weapon=storage.surface.create_entity{name=c.weapon_name or "ei-combat-doctrines-qc-"..c.category,position={0,0},force=force,quality=c.quality or "normal"}
        if c.weapon_name=="ei-auto-shotgun-turret" then c.weapon.energy=1000000000 end
        c.weapon.orientation=.25
        local stack=c.weapon.get_inventory(defines.inventory.turret_ammo)[1]
        stack.set_stack{name=c.ammo,count=1,quality=c.quality or "normal"};stack.ammo=1
        c.weapon.shooting_target=target
    end
    if c.intercept then
        c.blocker=storage.surface.create_entity{name="ei-combat-doctrines-qc-target",position={4,0},force=c.intercept}
        c.blocker_health=c.blocker.health
    end
    if c.chain then
        c.target.teleport({12,0})
        c.blockers={}
        for _,x in ipairs{4,8,16} do
            -- Neutral interceptors keep native turret acquisition on the far
            -- enemy; automatic retargeting to the first enemy shortens the shot.
            local block=storage.surface.create_entity{name=x==16 and "ei-combat-doctrines-qc-target" or "ei-combat-doctrines-qc-fragile-target",position={x,0},force="neutral"}
            block.health=x==16 and 1000 or 5
            c.blockers[#c.blockers+1]={entity=block,health=block.health}
        end
        c.target.health=1000
        c.weapon.shooting_target=c.target
    end
end
local function setup(tick)
    local surface=game.create_surface("combat-doctrines-qc",{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},3);surface.force_generate_chunk_requests()
    local tiles={};for x=-40,150 do for y=-16,16 do tiles[#tiles+1]={name="refined-concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    game.create_force("combat-qc-ally")
    game.forces.player.set_friend("combat-qc-ally",true)
    game.forces["combat-qc-ally"].set_friend("player",true)
    storage.surface=surface;storage.queue={};storage.index=1
    storage.report={phase=test.phase,cases={},checks={},headless_flash_visibility_override=true}
    for _,mode in ipairs{"normal","research","quality"} do
        for _,name in ipairs(magazines) do storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo=name,research=mode=="research",quality=mode=="quality" and "legendary" or "normal"} end
        for _,name in ipairs(shells) do storage.queue[#storage.queue+1]={mode="turret",category="shotgun-shell",ammo=name,research=mode=="research",quality=mode=="quality" and "legendary" or "normal"} end
    end
    for _,quality in ipairs{"normal","legendary"} do storage.queue[#storage.queue+1]={mode="defender",quality=quality} end
    for _,name in ipairs(magazines) do storage.queue[#storage.queue+1]={mode="spider",ammo=name} end
    storage.queue[#storage.queue+1]={mode="spider",ammo="firearm-magazine",tier=4,distance=44}
    storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo="firearm-magazine",quality="legendary",distance=134}
    for _,force in ipairs{"player","combat-qc-ally","neutral"} do storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo="firearm-magazine",intercept=force} end
    for _,name in ipairs(magazines) do storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo=name,chain=true} end
    for _,quality in ipairs{"normal","uncommon","rare","epic","legendary"} do
        local range=90*prototypes.quality[quality].range_multiplier
        storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo="firearm-magazine",quality=quality,distance=range-.25}
        storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo="firearm-magazine",quality=quality,distance=range+3,no_launch=true}
    end
    for _,name in ipairs(shells) do
        for _,weapon in ipairs{"ei-shotgun-turret","ei-auto-shotgun-turret"} do
            storage.queue[#storage.queue+1]={mode="turret",category="shotgun-shell",ammo=name,weapon_name=weapon}
        end
    end
    storage.queue[#storage.queue+1]={mode="turret",category="bullet",ammo="firearm-magazine",research=true,turret_research=true}
    storage.queue[#storage.queue+1]={mode="turret",category="shotgun-shell",ammo="piercing-shotgun-shell",weapon_name="ei-shotgun-turret",research=true,turret_research=true}
    for _,name in ipairs(magazines) do storage.queue[#storage.queue+1]={mode="character",category="bullet",ammo=name,gun_name="submachine-gun"} end
    for _,name in ipairs(shells) do storage.queue[#storage.queue+1]={mode="character",category="shotgun-shell",ammo=name,gun_name="combat-shotgun"} end
    begin_case(tick)
end
script.on_init(function() storage.pending=true end)
script.on_event(defines.events.on_entity_damaged,function(event)
    local c=storage.current
    if c and event.entity==c.target then
        c.damage[#c.damage+1]={tick=event.tick,amount=event.final_damage_amount,type=event.damage_type.name}
    end
end)
script.on_event(defines.events.on_trigger_created_entity,function(event)
    local c=storage.current
    if c and event.entity and event.entity.valid and event.entity.type=="explosion" then c.flashes=c.flashes+1 end
end)
script.on_event(defines.events.on_script_trigger_effect,function(event)
    local c=storage.current
    if not c then return end
    if event.effect_id:sub(1,#"ei-combat-qc-launch:")=="ei-combat-qc-launch:" then
        c.launches=c.launches+1;c.launch_tick=event.tick
        if c.mode=="defender" then c.weapon.disabled_by_script=true end
    elseif event.effect_id=="ei-combat-qc-created" then c.created=c.created+1
    elseif event.effect_id=="ei-combat-qc-impact" then c.impacts=c.impacts+1;c.impact_tick=event.tick
    elseif event.effect_id=="ei-combat-qc-flash" then c.flashes=c.flashes+1
    elseif event.effect_id:sub(1,#"ei-spider-shot:")=="ei-spider-shot:" and c.mode=="spider" then
        c.spider_observations=c.spider_observations+1;c.spider_tick=event.tick
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if storage.pending then storage.pending=nil;setup(event.tick) end
    if storage.finished then return end
    local c=storage.current
    if c.chain and event.tick-c.started<35 then
        c.trace=c.trace or {}
        local positions={}
        for _,p in pairs(storage.surface.find_entities_filtered{type="projectile"}) do positions[#positions+1]={name=p.name,position=p.position,speed=p.speed} end
        local aim=c.weapon.shooting_target
        c.trace[#c.trace+1]={tick=event.tick-c.started,aim=aim and aim.valid and aim.position,projectiles=positions,
            first_health=c.blockers[1].entity.valid and c.blockers[1].entity.health,
            first_max=c.blockers[1].entity.valid and c.blockers[1].entity.prototype.get_max_health()}
        if c.launches==0 then c.weapon.shooting_target=c.target end
    end
    if event.tick-c.started<240 then return end
    local total=0
    for _,e in ipairs(c.damage) do
        if (not c.impact_tick or e.tick<=c.impact_tick+1)
            and (c.ammo~="ei-dragons-breath-shotgun-shell" or e.type=="physical") then total=total+e.amount end
    end
    c.total=total
    check(storage.index.." launch",c.launches==(c.no_launch and 0 or 1),c.launches)
    if c.no_launch then check(storage.index.." outside acquisition",total==0,total)
    elseif c.chain then
        local losses={}
        for _,block in ipairs(c.blockers) do losses[#losses+1]=block.entity.valid and block.health-block.entity.health or block.health end
        local pierces=c.ammo=="piercing-rounds-magazine" or c.ammo=="uranium-rounds-magazine"
        check(c.ammo.." continuation",pierces and losses[1]>0 and losses[2]>0 and total>0 and losses[3]==0
            or not pierces and losses[1]>0 and losses[2]==0 and total==0 and losses[3]==0,losses)
        check(c.ammo.." impact multiplicity",c.impacts==(pierces and 3 or 1),c.impacts)
    elseif c.intercept then
        local loss=c.blocker_health-c.blocker.health
        check(c.intercept.." interception",c.intercept=="player" and total>0 and loss==0 or c.intercept~="player" and total==0 and loss>0,{target=total,blocker=loss})
    else
        check(storage.index.." native damage",total>0,total)
        if c.mode~="defender" then
            local base,pellets=expectation(c.ammo)
            local quality=prototypes.quality[c.quality or "normal"].default_multiplier
            local multiplier=(c.research and 1.5 or 1)*quality*(c.turret_research and 1.5 or 1)
            -- Spider guns retain their own authored native damage modifier.
            local gunmod=c.weapon.prototype.attack_parameters and c.weapon.prototype.attack_parameters.damage_modifier or 1
            if c.mode=="character" then gunmod=prototypes.item[c.gun_name].attack_parameters.damage_modifier or 1 end
            if c.mode=="spider" then
                local guns=c.weapon.prototype.guns
                for name,gun in pairs(guns) do
                    if name:find("mg",1,true) then gunmod=gun.attack_parameters.damage_modifier or 1 end
                end
                check(storage.index.." immediate spider observation",c.spider_observations==1 and c.spider_tick==c.launch_tick,c.spider_observations)
            end
            check(storage.index.." damage scaling",math.abs(total-base*multiplier*gunmod)<.01,{actual=total,expected=base*multiplier*gunmod})
            if test["ballistic-divergence-enabled"] then check(storage.index.." native projectile count",c.created==pellets,{actual=c.created,expected=pellets}) end
        end
        if c.mode=="turret" or c.mode=="character" then check(storage.index.." one source flash",c.flashes==1,c.flashes) end
    end
    storage.report.cases[#storage.report.cases+1]={ammo=c.ammo,mode=c.mode,quality=c.quality,research=c.research,damage=total,launches=c.launches,created=c.created,impacts=c.impacts,flashes=c.flashes,distance=c.distance,trace=c.trace}
    storage.index=storage.index+1
    if storage.index>#storage.queue then
        storage.report.all_pass=true
        for _,row in ipairs(storage.report.checks) do if not row.pass then storage.report.all_pass=false end end
        helpers.write_file("combat-doctrines-runtime.json",helpers.table_to_json(storage.report),false)
        storage.finished=true
        assert(storage.report.all_pass,"Combat doctrine firing checks failed; inspect runtime JSON")
    else begin_case(event.tick) end
end)
