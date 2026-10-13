-- Native launch/expiry probe. A case completes before any fixture cleanup.
local test=require('test-config')
local spiders=require('__exotic-space-industries-remembrance__/lib/spider-vehicles')
local magazines={'firearm-magazine','piercing-rounds-magazine','uranium-rounds-magazine','ei-compound-ammo',
    'ei-corrosive-ammo','ei-cryo-ammo','ei-oxyfluoride-ammo','ei-morphium-ammo','ei-hexafluoride-ammo','ei-arc-ammo','ei-neutron-ammo'}
local shells={'shotgun-shell','piercing-shotgun-shell','ei-uranium-shotgun-shell','ei-dragons-breath-shotgun-shell'}
local qualities={'normal','uncommon','rare','epic','legendary'}
local function list(v) return v and (v.type and {v} or v) or {} end
local function check(name,pass,detail)
    storage.report.checks[#storage.report.checks+1]={name=name,pass=pass==true,detail=detail}
end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function deliveries(c)
    local kind=c.mode=='defender' and prototypes.entity.defender.attack_parameters.ammo_type
        or prototypes.item[c.ammo].get_ammo_type(c.mode=='spider' and 'vehicle' or c.mode=='character' and 'player' or 'turret')
    local count,lower,upper,speed=0,math.huge,0,math.huge
    for _,a in ipairs(list(kind.action)) do for _,d in ipairs(list(a.action_delivery)) do
        if d.type=='projectile' then
            count=count+(a.repeat_count or 1)
            lower=math.min(lower,d.max_range*(1-(d.range_deviation or 0)/2))
            upper=math.max(upper,d.max_range*(1+(d.range_deviation or 0)/2))
            speed=math.min(speed,d.starting_speed-(d.starting_speed_deviation or 0))
        end
    end end
    local quality=prototypes.quality[c.quality or 'normal'].range_multiplier
    return count,lower*quality,upper*quality,speed
end
local function begin(tick)
    -- Only completed cases reach here; never destroy live rounds to pass a test.
    assert(#storage.surface.find_entities_filtered{type='projectile'}==0,'Cleanup encountered a live missed round')
    for _,e in pairs(storage.surface.find_entities_filtered{type={'ammo-turret','combat-robot','character','spider-vehicle','unit-spawner','simple-entity-with-owner','fire','sticker'}}) do e.destroy() end
    local c=storage.queue[storage.index]
    c.started=tick;c.rounds={};c.launches=0;c.flashes=0;c.observations=0;c.impacts=0;c.remote_damage=0
    c.expected,c.lower,c.upper,c.min_speed=deliveries(c)
    storage.current=c
    local target=storage.surface.create_entity{name='ei-combat-doctrines-qc-target',position={c.distance or 8,0},force='enemy'}
    c.target=target
    c.receiver=storage.surface.create_entity{name='ei-combat-doctrines-qc-range-target',position={c.upper+32,0},force='enemy'}
    c.nest=storage.surface.create_entity{name='biter-spawner',position={c.upper+64,0},force='enemy'}
    c.nest.active=false;c.receiver_health=c.receiver.health;c.nest_health=c.nest.health
    if c.mode=='character' then
        c.weapon=storage.surface.create_entity{name='character',position={0,0},force='player'}
        c.weapon.get_inventory(defines.inventory.character_guns)[1].set_stack{name=c.gun_name or 'submachine-gun',quality=c.quality}
        local stack=c.weapon.get_inventory(defines.inventory.character_ammo)[1]
        stack.set_stack{name=c.ammo,count=1,quality=c.ammo_quality or c.quality};stack.ammo=1
        c.weapon.shooting_state={state=defines.shooting.shooting_enemies,position=target.position}
    elseif c.mode=='defender' then
        local owner=storage.surface.create_entity{name='character',position={0,0},force='player'}
        c.weapon=storage.surface.create_entity{name='defender',position={0,0},force='player',quality=c.quality}
        c.weapon.combat_robot_owner=owner
    elseif c.mode=='spider' then
        c.weapon=storage.surface.create_entity{name=spiders.variant_name('assault',{mg=c.tier or 0}),position={0,0},force='player',quality=c.quality}
        c.weapon.get_inventory(defines.inventory.fuel).insert{name='coal',count=10}
        c.weapon.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=true}
        local stack=c.weapon.get_inventory(defines.inventory.spider_ammo)[2]
        stack.set_stack{name=c.ammo,count=1,quality=c.ammo_quality or c.quality};stack.ammo=1
    else
        c.weapon=storage.surface.create_entity{name=c.weapon_name or 'gun-turret',position={0,0},force='player',quality=c.quality}
        c.weapon.orientation=.25
        if c.weapon_name=='ei-auto-shotgun-turret' then c.weapon.energy=1000000000 end
        local stack=c.weapon.get_inventory(defines.inventory.turret_ammo)[1]
        stack.set_stack{name=c.ammo,count=1,quality=c.ammo_quality or c.quality};stack.ammo=1
        c.weapon.shooting_target=target
    end
end
local function setup(tick)
    local s=game.create_surface('combat-range-limits',{autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    s.request_to_generate_chunks({100,0},8);s.force_generate_chunk_requests()
    local tiles={};for x=-32,350 do for y=-96,96 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end;s.set_tiles(tiles)
    storage.surface=s;storage.queue={};storage.index=1;storage.report={phase=test.phase,cases={},checks={}}
    local function add(c) c.quality=c.quality or 'normal';storage.queue[#storage.queue+1]=c end
    for _,quality in ipairs{'normal','legendary'} do
        for _,name in ipairs(magazines) do add{ammo=name,quality=quality} end
        for _,name in ipairs(shells) do
            for _,weapon in ipairs{'ei-shotgun-turret','ei-auto-shotgun-turret'} do add{ammo=name,quality=quality,weapon_name=weapon} end
        end
    end
    for _,name in ipairs(magazines) do add{mode='spider',ammo=name,tier=0} end
    for _,weapon in ipairs{'gun-turret','ei-auto-shotgun-turret'} do
        local ammo=weapon=='gun-turret' and 'firearm-magazine' or 'shotgun-shell'
        add{ammo=ammo,weapon_name=weapon,quality='legendary',ammo_quality='normal'}
        add{ammo=ammo,weapon_name=weapon,quality='normal',ammo_quality='legendary'}
    end
    for _,gun in ipairs{'submachine-gun','combat-shotgun'} do
        local ammo=gun=='submachine-gun' and 'firearm-magazine' or 'shotgun-shell'
        add{mode='character',ammo=ammo,gun_name=gun,quality='legendary',ammo_quality='normal'}
        add{mode='character',ammo=ammo,gun_name=gun,quality='normal',ammo_quality='legendary'}
    end
    for _,quality in ipairs(qualities) do
        add{mode='defender',quality=quality}
        for tier=0,4 do add{mode='spider',ammo='firearm-magazine',quality=quality,tier=tier} end
        for _,weapon in ipairs{'gun-turret','ei-auto-shotgun-turret'} do
            local range=prototypes.entity[weapon].attack_parameters.range*prototypes.quality[quality].range_multiplier
            local ammo=weapon=='gun-turret' and 'firearm-magazine' or 'shotgun-shell'
            add{ammo=ammo,weapon_name=weapon,quality=quality,distance=range-.25}
            add{ammo=ammo,weapon_name=weapon,quality=quality,distance=range+4,no_launch=true}
        end
        local range=45*prototypes.quality[quality].range_multiplier
        add{mode='spider',tier=4,ammo='firearm-magazine',quality=quality,distance=range-.25}
        add{mode='spider',tier=4,ammo='firearm-magazine',quality=quality,distance=range+4,no_launch=true}
    end
    begin(tick)
end
script.on_init(function() storage.pending=true end)
script.on_event(defines.events.on_entity_damaged,function(e)
    local c=storage.current
    if c and (e.entity==c.receiver or e.entity==c.nest) then c.remote_damage=c.remote_damage+e.final_damage_amount end
end)
script.on_event(defines.events.on_script_trigger_effect,function(e)
    local c=storage.current;if not c then return end
    if e.effect_id:find('ei-combat-qc-launch:',1,true)==1 then
        c.launches=c.launches+1;c.launch_tick=e.tick
        if c.mode=='defender' then c.weapon.disabled_by_script=true end
    elseif e.effect_id=='ei-combat-qc-created' then
        local p=e.source_entity
        if not p or not p.valid or p.type~='projectile' then p=e.target_entity end
        assert(p and p.valid and p.type=='projectile','Creation observation needs its native projectile')
        c.rounds[#c.rounds+1]={entity=p,origin=p.position,last=p.position,created=e.tick,travel=0,max_step=0}
    elseif e.effect_id=='ei-combat-qc-impact' then c.impacts=c.impacts+1
    elseif e.effect_id=='ei-combat-qc-flash' then c.flashes=c.flashes+1
    elseif e.effect_id:find('ei-spider-shot:',1,true)==1 then c.observations=c.observations+1;c.observation_tick=e.tick end
end)
script.on_event(defines.events.on_tick,function(e)
    if storage.pending then storage.pending=nil;setup(e.tick) end
    if storage.finished then return end
    local c=storage.current
    if #c.rounds>0 and c.target.valid then c.target.destroy();c.removed_after_launch=e.tick>=c.launch_tick end
    local live=0
    for _,r in ipairs(c.rounds) do
        if r.entity.valid then
            live=live+1
            local position=r.entity.position
            local step=distance(position,r.last)
            r.travel=r.travel+step;r.max_step=math.max(r.max_step,step);r.last=position
        elseif not r.expired then r.expired=e.tick end
    end
    local timeout=math.ceil(c.upper/c.min_speed)+180
    assert(e.tick-c.started<timeout,'Missed projectile failed native expiry')
    if c.no_launch then if e.tick-c.started<120 then return end
    elseif #c.rounds==0 or live>0 then return end
    check('one discharge',c.launches==(c.no_launch and 0 or 1),c.launches)
    check('pellet count',#c.rounds==(c.no_launch and 0 or c.expected),#c.rounds)
    check('distant receiver protected',c.receiver.valid and c.receiver.health==c.receiver_health,c.receiver.health)
    check('distant nest protected',c.nest.valid and c.remote_damage==0,c.remote_damage)
    check('one terminal payload per missed round',c.impacts==(c.no_launch and 0 or c.expected),c.impacts)
    if not c.no_launch then
        check('target removed after launch',c.removed_after_launch,true)
        if c.mode=='spider' then check('immediate spider observation',c.observations==1 and c.observation_tick==c.launch_tick,c.observations)
        elseif c.mode~='defender' then check('one source flash',c.flashes==1,c.flashes) end
    end
    local distances={}
    for _,r in ipairs(c.rounds) do
        -- The final engine movement can occur between the last sample and expiry.
        check('native travel interval',r.travel>=c.lower-1.1 and r.travel<=c.upper+1.1,{travel=r.travel,lower=c.lower,upper=c.upper})
        check('native lifetime',r.expired-r.created<=math.ceil(c.upper/c.min_speed)+2,r.expired-r.created)
        if c.expected==1 then check('constant bullet movement',r.max_step<=1.01,r.max_step) end
        distances[#distances+1]={travel=r.travel,lifetime=r.expired-r.created,origin=r.origin,max_step=r.max_step}
    end
    storage.report.cases[#storage.report.cases+1]={ammo=c.ammo,mode=c.mode or 'turret',tier=c.tier,quality=c.quality,ammo_quality=c.ammo_quality,weapon=c.weapon_name,
        distance=c.distance,no_launch=c.no_launch,lower=c.lower,upper=c.upper,rounds=distances,extinct_before_cleanup=live==0}
    storage.index=storage.index+1
    if storage.index>#storage.queue then
        storage.report.all_pass=true
        for _,row in ipairs(storage.report.checks) do if not row.pass then storage.report.all_pass=false end end
        helpers.write_file('combat-doctrines-range.json',helpers.table_to_json(storage.report),false)
        storage.finished=true;assert(storage.report.all_pass,'Native range assertions failed; inspect range JSON')
    else begin(e.tick) end
end)
