-- Native supplements: moving-target eligibility, FIFO fairness and teleport reset.
local module={}
local INTERFACE="anisetron-qc-v2"
local CAPS={lean=8,standard=32,cinematic=64,maximal=128}
local VOICES={"ei-anisetron-crown-voice","ei-anisetron-facade-voice"}

local function same(left,right)
    if type(left)~=type(right) then return false end
    if type(left)~="table" then return left==right end
    for key,value in pairs(left) do if not same(value,right[key]) then return false end end
    for key in pairs(right) do if left[key]==nil then return false end end
    return true
end

local function paid_signature(owner)
    if not owner then return nil end
    local function paid(burst)
        if not burst then return nil end
        return {contract_version=burst.contract_version,quality=burst.quality,
            duration=burst.duration,damage=burst.damage,crown_damage=burst.crown_damage,research_multiplier=burst.research_multiplier,
            facade_damage=burst.facade_damage,start_tick=burst.start_tick,end_tick=burst.end_tick,
            crown_range=burst.crown_range,facade_range=burst.facade_range,contact_ticks=burst.contact_ticks,lance=burst.lance,
            next_contact=burst.next_contact,force_index=burst.force_index,
            surface_index=burst.surface_index,opening_target=burst.opening_target}
    end
    local result={burst=paid(owner.burst),queue={}}
    for _,burst in ipairs(owner.queue or {}) do result.queue[#result.queue+1]=paid(burst) end
    return result
end

local function snapshot(source)
    return remote.call(INTERFACE,"snapshot",source and source.unit_number)
end

local function presence(source)
    local paid=snapshot(source).owner
    local burst=paid and paid.burst
    local crown=burst and burst.crown and burst.crown.beam or false
    local facade=burst and burst.facade and burst.facade.beam or false
    local count={crown=0,facade=0}
    for _,voice in ipairs(source.surface.find_entities_filtered{name=VOICES,
        position=source.position,radius=.75}) do
        local emitter=voice.name==VOICES[1] and "crown" or "facade"
        count[emitter]=count[emitter]+1
    end
    return {crown=crown,facade=facade,voices=count,owner=paid}
end

function module.setup(tick,vehicle,target)
    local tiles={}
    for x=196,315 do for y=-205,-120 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    for x=235,280 do for y=-8,42 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end end
    storage.surface.set_tiles(tiles)
    local value={fleet={},started=tick}
    storage.coverage_qc=value
    for index=1,9 do
        local y=-200+index*8
        local source=vehicle(storage.surface,{205,y},nil,false)
        source.autopilot_destination={305,y}
        value.fleet[index]=source
    end
    value.source=vehicle(storage.surface,{250,30},1,true)
    value.target=target(storage.surface,{250,10})
end

function module.on_teleported(event)
    local value=storage.coverage_qc
    if value and value.source==event.entity then
        value.teleport_events=(value.teleport_events or 0)+1
        value.teleport_event_tick=event.tick
    end
end

function module.tick(event,check)
    local value=storage.coverage_qc
    if not value then return end
    local t=event.tick-storage.started
    local source=value.source
    if t==100 then
        source.active=false
        source.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        source.orientation=0;source.torso_orientation=0
    elseif t==220 then
        local angle=61/180*math.pi
        value.target.teleport({250+math.sin(angle)*25,30-math.cos(angle)*25})
        value.arc_health=value.target.health
    elseif t==250 then
        local shown=presence(source)
        check("locked-facade-outside61-degrees-stops",shown.crown and not shown.facade
            and shown.voices.crown==1 and shown.voices.facade==0,shown)
        check("crown-continues-outside-front-arc",value.target.health<value.arc_health)
    elseif t==260 then
        value.target.teleport({250,-1}) -- Outside facade reach, inside the inherited crown reach.
        value.range_health=value.target.health
    elseif t==290 then
        local shown=presence(source)
        check("crown-only-beyond31-tiles",shown.crown and not shown.facade
            and shown.voices.crown==1 and shown.voices.facade==0,shown)
        check("crown-contact-beyond-facade-range",value.target.health<value.range_health)
        value.target.teleport({250,-70})
        value.range_health=value.target.health
    elseif t==315 then
        local shown=presence(source)
        local paid=shown.owner and shown.owner.burst
        check("out-of-range-target-dropped-by-both-channels",paid and paid.crown.target~=value.target.unit_number
            and paid.facade.target~=value.target.unit_number,shown)
        check("beyond-range-no-contact-tail",value.target.health==value.range_health)
    elseif t==320 then
        value.target.teleport({250,10})
        value.reacquire_health=value.target.health
    elseif t==355 then
        local shown=presence(source)
        check("front-target-reacquired-by-both-paid-channels",shown.crown and shown.facade
            and shown.voices.crown==1 and shown.voices.facade==1,shown)
        check("eligibility-changes-no-second-payment",value.target.health<value.reacquire_health
            and storage.openers[source.unit_number].count==1)
    elseif t==400 then
        source.active=true
        source.autopilot_destination={280,30}
    elseif t==500 then
        local tier=settings.startup["ei-anisetron-visual-fidelity"].value
        local before=snapshot(source)
        local state=remote.call(INTERFACE,"movement_state",source.unit_number)
        check("native-paid-teleport-source-really-moving",source.speed>0
            and (tier=="off" or state and state.moving and state.strands>0),state)
        local signature=paid_signature(before.owner)
        local teleported=source.teleport({255,35},source.surface,true)
        local reset=remote.call(INTERFACE,"movement_state",source.unit_number)
        check("native-same-surface-teleport-event-observed",teleported
            and value.teleport_events==1 and value.teleport_event_tick==event.tick)
        if tier=="off" then
            check("off-teleport-remains-untracked",reset==nil)
        else
            check("teleport-immediately-resets-attached-sample",reset and reset.strands==0
                and not reset.attached and not reset.moving and reset.last_tick==event.tick
                and reset.surface_index==source.surface.index
                and reset.last_position.x==source.position.x and reset.last_position.y==source.position.y,
                reset)
            -- Native physics has not advanced after this instantly raised event.
            -- Sampling the new position now must not admit the teleport delta.
            remote.call(INTERFACE,"service",1000000)
            local sampled=remote.call(INTERFACE,"movement_state",source.unit_number)
            check("teleport-first-post-event-sample-no-false-strands",sampled
                and not sampled.moving and sampled.strands==0,sampled)
        end
        local after=paid_signature(snapshot(source).owner)
        check("native-teleport-preserves-paid-snapshot",signature~=nil and signature.burst~=nil
            and same(signature,after) and storage.openers[source.unit_number].count==1,
            {before=signature,after=after})
    elseif t==800 then
        -- Keep real native motion present during the fairness window even when
        -- the first hundred-tile route has already completed.
        for _,entity in ipairs(value.fleet) do
            entity.autopilot_destination={205,entity.position.y}
        end
    elseif t==899 then
        local visual=snapshot().visuals
        local tier=settings.startup["ei-anisetron-visual-fidelity"].value
        value.fairness={tier=tier,passes=0,members={},seen={},fleet={},size=0}
        local fair=value.fairness
        if tier=="off" then
            check("off-fleet-remains-untracked",visual.tracked_count==0)
            fair.done=true
        else
            for id in pairs(visual.per_vehicle) do fair.members[id]=true;fair.size=fair.size+1 end
            local all=true
            local movers={}
            for _,entity in ipairs(value.fleet) do
                fair.fleet[entity.unit_number]=true
                movers[#movers+1]={unit_number=entity.unit_number,position=entity.position,
                    speed=entity.speed,tracked=fair.members[entity.unit_number]==true}
                all=all and fair.members[entity.unit_number] and entity.speed>0
                    and not entity.get_driver() and not entity.get_passenger()
            end
            check("native-nine-movers-exceed-lean-cap",all and #value.fleet==9,
                {fleet=#value.fleet,starting_membership=fair.size,lean_cap=8,movers=movers})
            local cap=CAPS[tier] or fair.size
            fair.required_passes=math.ceil(fair.size/cap)
        end
    end
    local fair=value.fairness
    if fair and not fair.done and t>=900 then
        local visual=snapshot().visuals
        local pass=visual.last_pass
        if pass and pass.tick==event.tick then
            fair.passes=fair.passes+1
            for _,id in ipairs(pass.visited_units) do if fair.members[id] then fair.seen[id]=true end end
            if fair.passes==fair.required_passes then
                local complete=true;local missed={}
                for id in pairs(fair.members) do
                    if not fair.seen[id] then complete=false;missed[#missed+1]=id end
                end
                local fleet_complete=true
                for id in pairs(fair.fleet) do fleet_complete=fleet_complete and fair.seen[id]==true end
                check("movement-round-robin-entire-membership-within-bound",complete,
                    {starting_membership=fair.size,passes=fair.passes,bound=fair.required_passes,missed=missed})
                check("movement-round-robin-nine-native-movers-served",fleet_complete)
                fair.done=true
            end
        end
    end
    if t==1150 then check("movement-fairness-window-completed",fair and fair.done==true) end
end

return module
