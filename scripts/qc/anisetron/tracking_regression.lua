-- Isolated helper-mod regression profile. Native payments and unit commands;
-- no paid records or gameplay packets are manufactured by this fixture.
local module={}
local INTERFACE="anisetron-qc-v2"
local VEHICLE="ei-anisetron"
local AMMO="ei-anisetron-crystal-charge"
local TAU=math.pi*2
local TURN_BOUND=6*math.pi/180
local config

local function valid(entity) return entity and entity.valid end
local function copy_pos(value) return {x=value.x,y=value.y} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function angle_delta(a,b) return (a-b+math.pi)%TAU-math.pi end
local function bearing(origin,point) return math.atan2(point.x-origin.x,origin.y-point.y) end

local function check(name,passed,detail)
    storage.regression.results[name]={pass=passed==true,detail=detail}
end

local function violation(actor,name,detail)
    actor.violations[name]=(actor.violations[name] or 0)+1
    actor.examples[name]=actor.examples[name] or {}
    local examples=actor.examples[name]
    if #examples<6 then examples[#examples+1]=detail end
end

local function hostile_eligible(source,target,emitter)
    if not valid(target) or not target.health or target.health<=0
        or target.force~=game.forces.enemy then return false end
    if emitter=="crown" then
        local a,b=source.bounding_box,target.bounding_box
        local dx=math.max(0,a.left_top.x-b.right_bottom.x,b.left_top.x-a.right_bottom.x)
        local dy=math.max(0,a.left_top.y-b.right_bottom.y,b.left_top.y-a.right_bottom.y)
        if dx*dx+dy*dy>(85*source.quality.range_multiplier)^2 then return false end
    elseif distance(source.position,target.position)>30 then return false end
    return emitter=="crown" or math.abs(angle_delta(bearing(source.position,target.position),
        source.torso_orientation*TAU))<=math.pi/3+.000001
end

local function actor(surface,name,position,ammo,automatic)
    local state=storage.regression
    local entity=surface.create_entity{name=VEHICLE,position=position,force=state.force,raise_built=true}
    entity.orientation=0;entity.torso_orientation=0
    entity.vehicle_automatic_targeting_parameters={auto_target_with_gunner=automatic,auto_target_without_gunner=automatic}
    if ammo>0 then entity.get_inventory(defines.inventory.spider_ammo)[1].set_stack{name=AMMO,count=ammo} end
    local value={entity=entity,name=name,initial=copy_pos(entity.position),ammo=ammo,
        violations={},examples={},last={},payments=0,hits={crown=0,facade=0},last_hit={},
        incoming_hits=0,incoming_damage=0,acid_hits=0,sticker_ticks=0,path_length=0,
        previous=copy_pos(entity.position),trail_motion_ticks=0,trail_handle_ticks=0,
        gaps=0,max_stall=0,stall=0,windows={},beam_samples={crown=0,facade=0},
        max_step={crown=0,facade=0},target_changes={crown=0,facade=0}}
    state.actors[name]=value;state.by_source[entity.unit_number]=name
    return value
end

local function enemy(surface,name,position)
    local state=storage.regression
    local entity=surface.create_entity{name=name,position=position,force="enemy"}
    assert(entity and entity.valid,"Could not create native regression enemy")
    entity.active=true
    state.targets[entity.unit_number]=entity
    return entity
end

local function command_to(entity,position)
    assert(entity.commandable,"Active native regression unit needs commandable")
    entity.commandable.set_command{type=defines.command.go_to_location,destination=position,
        distraction=defines.distraction.none,radius=.1}
end

---@param tick integer
local function setup(tick)
    local state={started=tick,results={},actors={},by_source={},targets={},trace={},captures={},
        deaths=0,moving_target_distance=0,attackers={}}
    storage.regression=state
    state.force=game.create_force("anisetron-tracking-qc")
    local surface=game.create_surface("anisetron-tracking-regression",{width=640,height=640,
        autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
    surface.request_to_generate_chunks({0,0},9);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities()) do entity.destroy() end
    surface.destroy_decoratives{}
    local tiles={}
    for x=-240,240 do for y=-100,225 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
    surface.set_tiles(tiles);surface.always_day=false;surface.freeze_daytime=true;surface.daytime=0
    state.surface=surface
    local player=assert(game.get_player(1),"Use the copied player seed")
    if player.controller_type==defines.controllers.remote then player.exit_remote_view() end
    player.driving=false;player.force=state.force;player.teleport({-220,-80},surface)
    state.player=player.index
    actor(surface,"tracking",{-130,0},3,true)
    actor(surface,"lethal",{0,0},3,true)
    actor(surface,"facade-lethal",{110,0},1,true)
    local moving=actor(surface,"battle",{-180,110},3,true)
    moving.entity.autopilot_destination={220,110}
    local reference=actor(surface,"reference",{-180,195},0,false)
    reference.entity.autopilot_destination={220,195}
    state.walker=enemy(surface,"anisetron-qc-tracking-target",{-139,-23})
    state.walker_start=copy_pos(state.walker.position)
    command_to(state.walker,{-121,-23})
    state.distractor=enemy(surface,"anisetron-qc-tracking-target",{-106,-12})
    command_to(state.distractor,{-108,-15})
    state.rear=enemy(surface,"anisetron-qc-tracking-target",{-130,28})
    command_to(state.rear,{-125,27})
    state.facade_crown_lock=enemy(surface,"anisetron-qc-tracking-target",{110,-20})
    command_to(state.facade_crown_lock,{110,-20})
    check("regression-unbonused-combat-force",state.force.get_ammo_damage_modifier("ei-anisetron-crystal")==0)
end

---@param event EventData.on_script_trigger_effect
local function on_paid(event)
    if event.effect_id~="ei-anisetron-charge" or not storage.regression then return end
    local source=event.source_entity
    local name=valid(source) and storage.regression.by_source[source.unit_number]
    if name then
        local value=storage.regression.actors[name]
        value.payments=value.payments+1
        value.payment_ticks=value.payment_ticks or {}
        value.payment_ticks[#value.payment_ticks+1]=event.tick
    end
end

---@param event EventData.on_entity_damaged
local function on_damage(event)
    local state=storage.regression
    if not state then return end
    local victim=event.entity
    local incoming=valid(victim) and state.by_source[victim.unit_number]
    if incoming and valid(event.cause) and event.cause.force==game.forces.enemy then
        local actor=state.actors[incoming]
        actor.incoming_hits=actor.incoming_hits+1
        actor.incoming_damage=actor.incoming_damage+event.final_damage_amount
        if event.damage_type.name=="acid" then actor.acid_hits=actor.acid_hits+1 end
    end
    local source=event.cause
    local name=valid(source) and state.by_source[source.unit_number]
    if not name then return end
    local actor=state.actors[name]
    local amount=event.original_damage_amount
    local emitter=math.abs(amount-320)<.001 and "crown" or math.abs(amount-160)<.001 and "facade" or nil
    if not emitter then violation(actor,"unexpected-packet",{tick=event.tick,amount=amount});return end
    actor.hits[emitter]=actor.hits[emitter]+1
    actor.last_hit[emitter]={tick=event.tick,point=copy_pos(victim.position),id=victim.unit_number,
        killed=victim.health and victim.health<=0 or false}
    -- Native damage arrives during the shipping owner's tick; inspect the
    -- final visual state later in this helper's on_tick callback.
    if not hostile_eligible(source,victim,emitter) and victim.health and victim.health>0 then
        violation(actor,"damage-outside-eligibility",{tick=event.tick,emitter=emitter,target=victim.unit_number})
    end
end

---@param event EventData.on_entity_died
local function on_died(event)
    local state=storage.regression
    if not state or not valid(event.cause) then return end
    local name=state.by_source[event.cause.unit_number]
    if name then
        state.deaths=state.deaths+1
        local actor=state.actors[name]
        for _,hit in pairs(actor.last_hit) do if hit.id==event.entity.unit_number then hit.killed=true end end
    end
end

local function sample_actor(actor,tick)
    local entity=actor.entity
    if not valid(entity) then violation(actor,"source-died",{tick=tick});return end
    local state=storage.regression
    local value=remote.call(INTERFACE,"snapshot",entity.unit_number)
    local owner=value.owner
    local burst=owner and owner.burst
    local moved=distance(entity.position,actor.previous)
    actor.path_length=actor.path_length+moved;actor.previous=copy_pos(entity.position)
    if entity.autopilot_destination and moved<.001 then actor.stall=actor.stall+1 else actor.stall=0 end
    actor.max_stall=math.max(actor.max_stall,actor.stall)
    actor.sticker_ticks=actor.sticker_ticks+((entity.stickers and #entity.stickers>0) and 1 or 0)
    local motion=remote.call(INTERFACE,"movement_state",entity.unit_number)
    if moved>=.01 then
        actor.trail_motion_ticks=actor.trail_motion_ticks+1
        if motion and motion.strands==8 then actor.trail_handle_ticks=actor.trail_handle_ticks+1 end
    end
    local row={tick=tick,actor=actor.name,position=copy_pos(entity.position),speed=entity.speed,
        torso=entity.torso_orientation,motion=motion,paid=burst~=nil,channels={}}
    for _,emitter in ipairs{"crown","facade"} do
        local channel=burst and burst[emitter]
        local previous=actor.last[emitter]
        local target=channel and channel.target and state.targets[channel.target]
        local eligible=hostile_eligible(entity,target,emitter)
        local endpoint=channel and channel.endpoint
        local hit=actor.last_hit[emitter]
        if channel and eligible and tick>burst.start_tick+2 then
            actor.beam_samples[emitter]=actor.beam_samples[emitter]+1
            if not channel.beam then violation(actor,"eligible-core-gap",{tick=tick,emitter=emitter,target=channel.target}) end
        end
        if burst and hit and hit.killed and tick-hit.tick>=0 and tick-hit.tick<12 and not(channel and channel.beam) then
            violation(actor,"lethal-contact-invisible",{tick=tick,hit=hit.tick,emitter=emitter})
        end
        if channel and endpoint then
            local angle=bearing(entity.position,endpoint)
            if previous and previous.endpoint and previous.tick==tick-1 then
                local step=math.abs(angle_delta(angle,previous.angle))
                actor.max_step[emitter]=math.max(actor.max_step[emitter],step)
                local radius=math.max(.25,math.min(distance(entity.position,endpoint),distance(previous.position,previous.endpoint)))
                local translation_allowance=math.asin(math.min(1,moved/radius))
                local torso_allowance=emitter=="facade" and math.abs(angle_delta(entity.torso_orientation*TAU,previous.torso*TAU)) or 0
                if step>TURN_BOUND+translation_allowance+torso_allowance+.002 then
                    violation(actor,"aim-step-exceeds-bound",{tick=tick,emitter=emitter,degrees=step*180/math.pi,
                        before=previous.target,after=channel.target,source_displacement=moved})
                end
                if previous.target and channel.target~=previous.target then
                    actor.target_changes[emitter]=actor.target_changes[emitter]+1
                    local old=state.targets[previous.target]
                    if hostile_eligible(entity,old,emitter) then
                        violation(actor,"eligible-lock-abandoned",{tick=tick,emitter=emitter,before=previous.target,after=channel.target})
                    end
                end
            end
            actor.last[emitter]={tick=tick,angle=angle,endpoint=copy_pos(endpoint),
                target=channel.target,position=copy_pos(entity.position),torso=entity.torso_orientation}
        else actor.last[emitter]=nil end
        row.channels[emitter]=channel
    end
    state.trace[#state.trace+1]=row
    if (tick-state.started)%300==0 then
        actor.windows[#actor.windows+1]={tick=tick,position=copy_pos(entity.position),path=actor.path_length,
            speed=entity.speed,stalled=actor.stall,stickers=entity.stickers and #entity.stickers or 0}
    end
end

local function attackers(tick)
    local state=storage.regression
    local source=state.actors.battle.entity
    if not valid(source) then return end
    for index,kind in ipairs{"behemoth-biter","big-spitter"} do
        local offset=index==1 and 2.5 or 12
        local unit=enemy(state.surface,kind,{source.position.x+offset,source.position.y+index*2})
        unit.commandable.set_command{type=defines.command.attack,target=source,distraction=defines.distraction.none}
        state.attackers[#state.attackers+1]=unit
    end
end

local function capture(actor,kind,frame,daytime)
    local state=storage.regression
    local entity=actor.entity
    if not valid(entity) then return end
    local path=string.format("anisetron-regression/%s/%03d.png",kind,frame)
    local camera={position={x=entity.position.x,y=entity.position.y-5},resolution={768,768},zoom=1}
    game.take_screenshot{surface=entity.surface,position=camera.position,resolution=camera.resolution,
        zoom=1,path=path,show_gui=false,show_entity_info=false,daytime=daytime,
        anti_alias=true,force_render=true}
    state.captures[#state.captures+1]={path=path,tick=state.current_tick,actor=actor.name,
        camera=camera,position=copy_pos(entity.position),torso=entity.torso_orientation,
        projection=remote.call(INTERFACE,"projection",entity),darkness=entity.surface.darkness,
        visual=remote.call(INTERFACE,"movement_state",entity.unit_number)}
end

local function finish()
    local state=storage.regression
    for name,actor in pairs(state.actors) do
        check(name.."-survives",valid(actor.entity))
        check(name.."-no-unexpected-packets",not actor.violations["unexpected-packet"],actor.examples["unexpected-packet"])
        check(name.."-scheduled-eligible-damage",not actor.violations["damage-outside-eligibility"],actor.examples["damage-outside-eligibility"])
        if actor.ammo>0 then
            check(name.."-real-native-payments",actor.payments>0 and actor.payments<=actor.ammo,actor.payment_ticks)
            check(name.."-channel-contact-budgets",actor.hits.crown<=actor.payments*100 and actor.hits.facade<=actor.payments*100,actor.hits)
            check(name.."-core-continuity",not actor.violations["eligible-core-gap"],actor.examples["eligible-core-gap"])
            check(name.."-smooth-tracking",not actor.violations["aim-step-exceeds-bound"],actor.examples["aim-step-exceeds-bound"])
            check(name.."-holds-eligible-target",not actor.violations["eligible-lock-abandoned"],actor.examples["eligible-lock-abandoned"])
        end
    end
    local tracker=state.actors.tracking
    check("native-walking-target-crosses-north",state.moving_target_distance>20,{distance=state.moving_target_distance})
    check("tracking-both-channels-observed",tracker.beam_samples.crown>100 and tracker.beam_samples.facade>100,tracker.beam_samples)
    local lethal=state.actors.lethal
    check("real-low-health-enemies-killed",state.deaths>=10,{deaths=state.deaths})
    check("lethal-packets-have-visible-core",not lethal.violations["lethal-contact-invisible"],lethal.examples["lethal-contact-invisible"])
    local facade_lethal=state.actors["facade-lethal"]
    check("facade-lethal-contacts-observed",facade_lethal.hits.facade>=10,facade_lethal.hits)
    check("facade-lethal-packets-have-visible-core",not facade_lethal.violations["lethal-contact-invisible"],
        facade_lethal.examples["lethal-contact-invisible"])
    local battle,reference=state.actors.battle,state.actors.reference
    check("sustained-native-route",reference.path_length>150 and battle.path_length>100,{battle=battle.windows,reference=reference.windows})
    check("real-enemy-attack-exposure",battle.incoming_hits>0,{hits=battle.incoming_hits,damage=battle.incoming_damage})
    check("real-acid-exposure",battle.acid_hits>0 or battle.sticker_ticks>0,{acid=battle.acid_hits,sticker_ticks=battle.sticker_ticks})
    check("no-prolonged-open-route-stall",battle.max_stall<180,{max_stall=battle.max_stall,windows=battle.windows})
    if config.fidelity~="off" then
        check("moving-reference-strands-continuous",reference.trail_motion_ticks>1200
            and reference.trail_handle_ticks/reference.trail_motion_ticks>.95,
            {moving=reference.trail_motion_ticks,three_handles=reference.trail_handle_ticks})
    end
    local passed,count=true,0
    for _,value in pairs(state.results) do count=count+1;passed=passed and value.pass end
    state.complete=true
    helpers.write_file("anisetron-regression/trace.json",helpers.table_to_json(state.trace),false)
    helpers.write_file("anisetron-regression/captures.json",helpers.table_to_json{frames=state.captures,
        note="Consecutive tick captures at zoom 1; terrain and source pixels are engine rendered. Keel visibility requires pixel review."},false)
    local summary={}
    for name,actor in pairs(state.actors) do summary[name]={payments=actor.payments,hits=actor.hits,
        incoming_hits=actor.incoming_hits,acid_hits=actor.acid_hits,sticker_ticks=actor.sticker_ticks,
        path_length=actor.path_length,max_stall=actor.max_stall,max_step=actor.max_step,
        target_changes=actor.target_changes,violations=actor.violations,windows=actor.windows} end
    helpers.write_file("anisetron-qc.json",helpers.table_to_json{all_pass=passed,count=count,complete=true,
        profile="tracking-regression",fixture_version=3,fidelity=config.fidelity,channel_view="all",
        cases=state.results,actors=summary},false)
end

---@param event EventData.on_tick
local function on_tick(event)
    if not storage.regression then setup(event.tick) end
    local state=storage.regression
    if state.complete then return end
    local t=event.tick-state.started
    state.current_tick=event.tick
    if valid(state.walker) then
        local position=state.walker.position
        state.moving_target_distance=state.moving_target_distance+distance(position,state.walker_start)
        state.walker_start=copy_pos(position)
        if t%300==0 then command_to(state.walker,{x=t%600==0 and -121 or -139,y=-23}) end
    end
    if t>=20 and t<3300 and (not valid(state.lethal_target)) then
        local source=state.actors.lethal.entity
        if valid(source) then
            local side=(math.floor(t/100)%2==0) and -1 or 1
            state.lethal_target=enemy(state.surface,"small-biter",{side*10,-18})
            state.lethal_target.commandable.set_command{type=defines.command.attack,target=source,distraction=defines.distraction.none}
        end
    end
    if t==60 then
        -- Separate visual regression: preserve a genuinely acquired crown lock
        -- behind a frozen north facade, leaving real small biters for facade
        -- lethal contacts. Body-turn coverage uses the unfrozen tracking actor.
        local source=state.actors["facade-lethal"].entity
        source.active=false
        source.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        source.orientation=0;source.torso_orientation=0
        state.facade_crown_lock.teleport({110,25})
        state.facade_crown_lock.active=false
    end
    if t>=80 and t<1100 and not valid(state.facade_lethal_target) then
        local source=state.actors["facade-lethal"].entity
        local side=(math.floor(t/100)%2==0) and -1 or 1
        state.facade_lethal_target=enemy(state.surface,"small-biter",{110+side*8,-17})
        state.facade_lethal_target.commandable.set_command{type=defines.command.attack,target=source,distraction=defines.distraction.none}
    end
    if t>=240 and t<2700 and t%120==0 then attackers(event.tick) end
    -- Sustain the native encounter while retaining real attack damage events.
    -- This fixture-only heal never modifies speed, stickers, input or paid state.
    local battle=state.actors.battle.entity
    if valid(battle) and battle.health<1000 then battle.health=battle.prototype.get_max_health(battle.quality) end
    if t==800 then state.actors.tracking.entity.autopilot_destination={-120,0}
    elseif t==950 then state.actors.tracking.entity.autopilot_destination={-130,0}
    elseif t==1150 then state.actors.tracking.entity.autopilot_destination=nil
    elseif t==1200 then if valid(state.walker) then state.walker.die() end
    elseif t==1500 then if valid(state.distractor) then state.distractor.die() end
    elseif t==2700 then
        for _,unit in ipairs(state.attackers) do if valid(unit) then unit.destroy() end end
    end
    for _,actor in pairs(state.actors) do sample_actor(actor,event.tick) end
    if config.visual then
        -- Screenshot overrides alone do not establish actual surface lighting.
        -- Separate day/night requests by ticks so each sees its own light pass.
        if t==181 or t==601 or t==1301 or t==2401 or t==3001 or t==817 then state.surface.daytime=.5 end
        if t==184 or t==604 or t==1304 or t==2404 or t==3004 or t==881 then state.surface.daytime=0 end
        if t>=300 and t<420 then
            capture(state.actors.lethal,"lethal-dense",t-299,0)
            capture(state.actors["facade-lethal"],"facade-lethal-dense",t-299,0)
            capture(state.actors.tracking,"tracking-dense",t-299,0)
        end
        if t>=820 and t<880 then capture(state.actors.tracking,"turning-dense",t-819,.5) end
        if t==180 or t==600 or t==1300 or t==2400 or t==3000 then
            capture(state.actors.reference,"trail-day",t,0)
            capture(state.actors.battle,"battle-day",t,0)
        end
        if t==183 or t==603 or t==1303 or t==2403 or t==3003 then
            capture(state.actors.reference,"trail-night",t-3,.5)
        end
    end
    if t==3600 then finish() end
end

---@param options table
function module.register(options)
    config=options
    script.on_event(defines.events.on_tick,on_tick)
    script.on_event(defines.events.on_script_trigger_effect,on_paid)
    script.on_event(defines.events.on_entity_damaged,on_damage)
    script.on_event(defines.events.on_entity_died,on_died)
end

return module
