-- Fixture-only v2 assertions. Native lifecycle checks remain in control.lua.
local config=require("test-config")
local module={}
local VEHICLE="ei-anisetron"
local INTERFACE="anisetron-qc-v2"
local LIMITS={
    off={interval=0,visits=0,strands=0,weapon=0},
    lean={interval=8,visits=8,strands=64,weapon=8},
    standard={interval=4,visits=32,strands=256,weapon=32},
    cinematic={interval=3,visits=64,strands=512,weapon=64},
    maximal={interval=2,visits=128,strands=1024,weapon=128},
    unbounded={interval=1},
}

local function snapshot(entity)
    return remote.call(INTERFACE,"snapshot",entity and entity.unit_number)
end

---@param event EventData.on_entity_damaged
function module.observe_damage(event)
    local source=event.cause
    if not(source and source.valid and source.name==VEHICLE) then return end
    storage.source_damage=storage.source_damage or {}
    local id=source.unit_number
    local record=storage.source_damage[id] or {crown={count=0,total=0,ticks={},targets={}},
        facade={count=0,total=0,ticks={},targets={}},legacy={count=0,total=0,ticks={},targets={}},unexpected=0}
    local amount=event.final_damage_amount
    local channel
    local owner=snapshot(source).owner
    local paid=owner and owner.burst
    local original=event.original_damage_amount
    if paid and (paid.contract_version==2 or paid.contract_version==3) then
        if math.abs(original-paid.crown_damage)<.001 then channel="crown"
        elseif math.abs(original-paid.facade_damage)<.001 then channel="facade" end
    elseif paid and math.abs(original-paid.damage)<.001 then channel="legacy" end
    if channel then
        local hits=record[channel]
        hits.count=hits.count+1;hits.total=hits.total+amount
        hits.ticks[#hits.ticks+1]=event.tick
        hits.targets[#hits.targets+1]=event.entity.unit_number
    else record.unexpected=record.unexpected+1 end
    storage.source_damage[id]=record
    return channel
end

function module.channel_count(entity,name)
    local record=storage.source_damage and storage.source_damage[entity.unit_number]
    return record and record[name] and record[name].count or 0
end

function module.channels_complete(entity,count)
    return module.channel_count(entity,"crown")==count
        and module.channel_count(entity,"facade")==count
        and module.channel_count(entity,"legacy")==0
end

-- The first acquired target is free to vary; every subsequent contact must
-- advance through the complete clockwise sequence, including the wrap.
function module.circular_sequence(sequence,pattern,count)
    if not sequence or #sequence~=count then return false end
    local start
    for i,value in ipairs(pattern) do if value==sequence[1] then start=i;break end end
    if not start then return false end
    for i,value in ipairs(sequence) do
        if value~=pattern[(start+i-2)%#pattern+1] then return false end
    end
    return true
end

function module.locked_sequence(sequence,count)
    if not sequence or #sequence~=count then return false end
    for _,value in ipairs(sequence) do if value~=sequence[1] then return false end end
    return true
end

function module.beams(surface,area)
    local result={}
    for _,entity in ipairs(surface.find_entities_filtered{type="beam",area=area}) do
        if entity.name:sub(1,#VEHICLE)==VEHICLE and entity.name~=VEHICLE.."-charge-trigger" then
            result[#result+1]=entity
        end
    end
    return result
end

function module.mark_paid_legacy(source)
    local converted=remote.call(INTERFACE,"mark_paid_queue_legacy",source.unit_number)
    assert(converted>0,"A legacy conversion must consume existing native-paid queued records")
end

local function exact_cadence(hits)
    for i=2,#hits.ticks do if hits.ticks[i]-hits.ticks[i-1]~=12 then return false end end
    return true
end

function module.final_combat_checks(check)
    for _,name in ipairs{"auto","manual","quality","reserve","rare_vehicle","arc","collinear"} do
        local source=storage[name]
        local record=storage.source_damage[source.unit_number]
        check(name.."-paired-channel-cadence",record and record.crown.count==100
            and record.facade.count==100 and exact_cadence(record.crown) and exact_cadence(record.facade),record)
        check(name.."-one-native-charge",storage.openers[source.unit_number]
            and storage.openers[source.unit_number].count==1,storage.openers[source.unit_number])
        check(name.."-no-decorative-damage",record and record.unexpected==0 and record.legacy.count==0)
    end
    check("rare-ammo-event-quality",storage.openers[storage.quality.unit_number].quality=="rare")
    check("single-charge-combined-48k",storage.source_damage[storage.auto.unit_number].crown.total==32000
        and storage.source_damage[storage.auto.unit_number].facade.total==16000)
end

-- Compare these native mechanical observations across presets. Visual counts,
-- entity handles, absolute timestamps and source coordinates are excluded.
function module.mechanics_metadata()
    local result={sources={},crown_sequence=storage.arc_sequence,facade_sequence=storage.arc_facade_sequence,
        collinear_crown_sequence=storage.collinear_sequence,collinear_facade_sequence=storage.collinear_facade_sequence}
    for _,name in ipairs{"auto","manual","quality","reserve","rare_vehicle","arc","collinear","retrigger","rear_only"} do
        local entity=storage[name]
        if entity and entity.valid then
            local record=storage.source_damage and storage.source_damage[entity.unit_number]
            local opener=storage.openers and storage.openers[entity.unit_number]
            local value={openers=opener and opener.count or 0,ammo_quality=opener and opener.quality,
                unexpected=record and record.unexpected or 0}
            for _,channel in ipairs{"crown","facade","legacy"} do
                value[channel]={count=record and record[channel].count or 0,total=record and record[channel].total or 0}
            end
            local stack=entity.get_inventory(defines.inventory.spider_ammo)[1]
            value.rounds=stack.valid_for_read and (stack.count-1)*stack.prototype.magazine_size+stack.ammo or 0
            result.sources[name]=value
        end
    end
    return result
end

---@param tick integer
---@param vehicle function
---@param target function
---@param check function
function module.setup(tick,vehicle,target,check)
    check("requested-startup-fidelity",settings.startup["ei-anisetron-visual-fidelity"].value==config.fidelity,
        {requested=config.fidelity,actual=settings.startup["ei-anisetron-visual-fidelity"].value})
    storage.fx_idle=vehicle(storage.surface,{-100,170},nil,false)
    storage.fx_mover=vehicle(storage.surface,{-70,170},nil,false)
    storage.fx_mover.autopilot_destination={30,170}
    storage.source_force=vehicle(storage.surface,{-220,40},1,true)
    storage.source_force_target=target(storage.surface,{-220,20})
    storage.source_transfer=vehicle(storage.surface,{-220,100},1,true)
    storage.source_transfer_target=target(storage.surface,{-220,80})
    storage.fx_seen={moving=false,strands=false,motes=false,halos=false,flashes=false}
    storage.visual_passes=0
end

local function no_repeat(pass)
    if not pass or type(pass.visited_units)~="table" then return false end
    local seen={}
    for _,id in ipairs(pass.visited_units) do
        if seen[id] then return false end
        seen[id]=true
    end
    return true
end

-- Repeated budget observations are latched: a later valid pass cannot hide an
-- earlier violation by overwriting the result table.
local function invariant(check,name,pass,detail)
    storage.fx_failures=storage.fx_failures or {}
    if pass~=true then storage.fx_failures[name]=detail or true end
    check(name,storage.fx_failures[name]==nil,storage.fx_failures[name] or detail)
end

local function native_paid_signature(owner)
    if not owner then return nil end
    local function paid(burst)
        if not burst then return nil end
        return {contract_version=burst.contract_version,quality=burst.quality,
            duration=burst.duration,damage=burst.damage,crown_damage=burst.crown_damage,research_multiplier=burst.research_multiplier,
            facade_damage=burst.facade_damage,start_tick=burst.start_tick,
            crown_range=burst.crown_range,facade_range=burst.facade_range,contact_ticks=burst.contact_ticks,lance=burst.lance,
            end_tick=burst.end_tick,next_contact=burst.next_contact}
    end
    local result={burst=paid(owner.burst),queue={}}
    for _,burst in ipairs(owner.queue or {}) do result.queue[#result.queue+1]=paid(burst) end
    return result
end

local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a) do if not same(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end

---@param event EventData.on_tick
---@param check function
function module.tick(event,check)
    local t=event.tick-storage.started
    local value=snapshot()
    local p=LIMITS[config.fidelity]
    assert(p,"Unknown fixture fidelity")
    local pass=value.visuals.last_pass
    if pass and pass.tick==event.tick then
        storage.visual_passes=storage.visual_passes+1
        invariant(check,"movement-service-distinct",no_repeat(pass),pass)
        invariant(check,"movement-service-preset-cap",not p.visits or #pass.visited_units<=p.visits,pass)
        invariant(check,"strand-creation-cap",not p.strands or pass.strands_created<=p.strands,pass)
        invariant(check,"movement-motes-removed",pass.motes_created==nil and value.visuals.live_motes==0,pass)
    end
    if value.visuals.weapon_tick==event.tick then
        invariant(check,"weapon-decoration-creation-cap",not p.weapon or value.visuals.weapon_created<=p.weapon,
            {created=value.visuals.weapon_created,cap=p.weapon})
    end
    local moving=value.visuals.per_vehicle[storage.fx_mover.unit_number]
    storage.fx_seen.moving=storage.fx_seen.moving or moving and moving.moving or false
    storage.fx_seen.strands=storage.fx_seen.strands or moving and moving.strands==8 or false
    storage.fx_seen.motes=storage.fx_seen.motes or value.visuals.live_motes>0
    storage.fx_seen.halos=storage.fx_seen.halos or value.visuals.live_halos>0
    storage.fx_seen.flashes=storage.fx_seen.flashes or value.visuals.live_flashes>0
    if t==120 then
        local idle=value.visuals.per_vehicle[storage.fx_idle.unit_number]
        check("idle-never-emits-movement",not idle or (not idle.moving and idle.strands==0),idle)
        local firing=value.visuals.per_vehicle[storage.auto.unit_number]
        check("stationary-fire-never-emits-movement",not firing or (not firing.moving and firing.strands==0),firing)
        check("unmanned-movement-admission",config.fidelity=="off" or
            (storage.fx_seen.moving and storage.fx_seen.strands
            and not storage.fx_mover.get_driver() and not storage.fx_mover.get_passenger()),storage.fx_seen)
        local owner=snapshot(storage.auto).owner
        check("both-core-beams-in-every-preset",owner and owner.crown_beam and owner.facade_beam,owner)
    elseif t==124 then
        -- A huge explicit override must terminate after one starting membership.
        local before=snapshot()
        local served=remote.call(INTERFACE,"service",1000000)
        local after=snapshot()
        local sampled=after.visuals.last_pass
        check("huge-limit-finite-membership",config.fidelity=="off" or
            (no_repeat(sampled) and served==#sampled.visited_units
            and served<=before.visuals.tracked_count),{served=served,before=before.visuals.tracked_count,pass=sampled})
    elseif t==150 then
        local before=native_paid_signature(snapshot(storage.auto).owner)
        remote.call(INTERFACE,"rebuild")
        local after=native_paid_signature(snapshot(storage.auto).owner)
        check("cosmetic-rebuild-preserves-paid-fifo",same(before,after),{before=before,after=after})
    elseif t==180 then
        storage.source_force.force=game.forces.neutral
        local transfer=game.create_surface("anisetron-source-transfer",{width=64,height=64,
            autoplace_controls={},autoplace_settings={entity={treat_missing_as_default=false}}})
        transfer.request_to_generate_chunks({0,0},1);transfer.force_generate_chunk_requests()
        assert(storage.source_transfer.teleport({0,0},transfer),"Native Spidertron surface teleport failed")
    elseif t==200 then
        storage.force_tail_health=storage.source_force_target.health
        storage.transfer_tail_health=storage.source_transfer_target.health
        check("force-change-paid-owner-cancelled",snapshot(storage.source_force).owner==nil)
        check("surface-change-paid-owner-cancelled",snapshot(storage.source_transfer).owner==nil)
    elseif t==300 then
        check("force-change-no-paid-tail",storage.source_force_target.health==storage.force_tail_health)
        check("surface-change-no-paid-tail",storage.source_transfer_target.health==storage.transfer_tail_health)
        -- Spidertron speed is observable, but the 2.0 setter is car/unit-only.
        -- Clearing its native route lets the hover anchors coast to rest.
        storage.fx_mover.autopilot_destination=nil
        storage.fx_idle.torso_orientation=.375
    elseif t==420 then
        local mover=value.visuals.per_vehicle[storage.fx_mover.unit_number]
        local idle=value.visuals.per_vehicle[storage.fx_idle.unit_number]
        check("movement-stop-clears-strands",not mover or (not mover.moving and mover.strands==0),mover)
        check("torso-only-turn-does-not-emit",not idle or (not idle.moving and idle.strands==0),idle)
        check("secondary-effects-enabled",config.fidelity=="off" or
            (not storage.fx_seen.motes and storage.fx_seen.halos and storage.fx_seen.flashes),storage.fx_seen)
    elseif t==800 then
        local snap=snapshot()
        if config.fidelity=="off" then
            local visual=snap.visuals
            check("off-zero-secondary-tracking",visual.tracked_count==0 and visual.live_strands==0
                and visual.live_motes==0 and visual.live_halos==0 and visual.live_flashes==0
                and visual.live_lights==0,visual)
        else check("movement-budget-observed",storage.visual_passes>0,{passes=storage.visual_passes}) end
    end
end

function module.before_save(event,check)
    local source=storage.persistence_source
    local value=snapshot(source)
    storage.paid_snapshot=native_paid_signature(value.owner)
    storage.saved_fidelity=settings.startup["ei-anisetron-visual-fidelity"].value
    check("rare-dual-burst-saved-at-25-per-channel",module.channels_complete(source,25)
        and storage.openers[source.unit_number].quality=="rare",storage.paid_snapshot)
end

function module.resume_started(event,check)
    check("resume-startup-fidelity",settings.startup["ei-anisetron-visual-fidelity"].value==config.fidelity,
        {saved=storage.saved_fidelity,current=settings.startup["ei-anisetron-visual-fidelity"].value})
    local owner=snapshot(storage.persistence_source).owner
    check("paid-deadlines-preserved-on-resume",same(storage.paid_snapshot,native_paid_signature(owner)),
        {before=storage.paid_snapshot,after=native_paid_signature(owner)})
    if config.fidelity=="off" then
        local value=snapshot().visuals
        check("off-resume-clears-all-secondary",value.tracked_count==0 and value.live_strands==0
            and value.live_motes==0 and value.live_halos==0 and value.live_flashes==0 and value.live_lights==0,value)
    end
end

function module.legacy_tick(event,check,report,health0,rounds)
    local source=storage.persistence_source
    if not config.loaded and not storage.legacy_resume_tick then
        storage.legacy_resume_tick=event.tick
    end
    -- The saved initial-stage clock is not the replay clock. Loaded checks must
    -- run once after loading, and allow the queued paid burst to finish.
    if config.loaded and not storage.legacy_loaded_tick then
        storage.legacy_loaded_tick=event.tick
        -- Historical v1 saves retained their packet count and target health,
        -- but predate the per-channel observer. Keep the observed replay tail
        -- distinct from the full persisted payment/damage accounting.
        local observed=storage.source_damage and storage.source_damage[source.unit_number]
        storage.legacy_loaded_packet_baseline={paid=storage.persistence_packets,
            count=observed and observed.legacy.count or 0,
            total=observed and observed.legacy.total or 0}
        check("legacy-native-metadata-preserved",storage.rebuilt and storage.rebuilt.valid
            and storage.rebuilt.quality.name=="rare")
        local current=snapshot(source).owner
        -- The expired first burst can be retired before this observer runs;
        -- its genuinely paid successor then remains queued until the next tick.
        local legacy=current and (current.burst~=nil or #current.queue>0)
        if current then
            if current.burst then
                legacy=legacy and current.burst.contract_version==nil and current.burst.damage==240
            end
            for _,paid in ipairs(current.queue) do
                legacy=legacy and paid.contract_version==nil and paid.damage==240
            end
        end
        check("legacy-versionless-paid-owner",legacy==true,current)
    end
    local opener=storage.openers and storage.openers[source.unit_number]
    if config.save and opener and opener.count==2 and not storage.transition_saved then
        local owner=snapshot(source).owner
        check("legacy-two-native-payments",rounds(source)==0 and opener.count==2,opener)
        -- Native opener timestamps can differ by 1199 or 1200 ticks. The first
        -- burst can finish at this boundary; the second must still be queued.
        check("legacy-versionless-paid-fifo",owner
            and (not owner.burst or (owner.burst.contract_version==nil and owner.burst.damage==240))
            and #owner.queue==1 and owner.queue[1].contract_version==nil
            and owner.queue[1].damage==240,owner)
        storage.transition_saved=true;storage.persisted=true
        storage.complete=true;report();game.server_save("anisetron-transition")
        return
    end
    local finish=config.loaded and 1250 or 2450
    local origin=config.loaded and storage.legacy_loaded_tick or storage.legacy_resume_tick
    if event.tick-origin==finish then
        local expected=config.historical_legacy and 100 or 200
        local record=storage.source_damage and storage.source_damage[source.unit_number]
        local baseline=storage.legacy_loaded_packet_baseline or {paid=0,count=0,total=0}
        local replay_packets=expected-baseline.paid
        check("legacy-paid-packets-remain-240-facade",storage.persistence_packets==expected
            and health0(storage.persistence_target)-storage.persistence_target.health==expected*240
            and record and record.legacy.count==baseline.count+replay_packets
            and record.legacy.total==baseline.total+replay_packets*240
            and snapshot(source).owner==nil
            and rounds(source)==0 and opener and opener.count==(config.historical_legacy and 1 or 2),
            {packets=storage.persistence_packets,expected=expected,replay_baseline=baseline,
                replay_packets=replay_packets,opener=opener,observed=record})
        check("legacy-no-free-crown-or-v2-facade",record and record.legacy.count>0
            and record.crown.count==0 and record.facade.count==0 and record.unexpected==0,record)
        storage.complete=true;report()
    end
end

-- Focused profile: three real native payments, with no added or discarded paid
-- records. Observe handoff contacts rather than inferring timing from openers.
function module.timing_tick(event,check,report,health0,rounds)
    local source=storage.persistence_source
    local t=event.tick-storage.started
    local owner=snapshot(source).owner
    local paid=storage.openers and storage.openers[source.unit_number]
    if paid and paid.count>0 then
        storage.timing_reserves=storage.timing_reserves or {}
        if storage.timing_reserves[paid.count]==nil then storage.timing_reserves[paid.count]=rounds(source) end
    end
    if owner then
        storage.timing_max_queue=math.max(storage.timing_max_queue or 0,#owner.queue)
        invariant(check,"three-charge-intake-queue-cap",#owner.queue<=1,
            {tick=event.tick,queue=#owner.queue,maximum=storage.timing_max_queue})
    end
    if t~=3650 then return end
    local opener=storage.openers[source.unit_number]
    local record=storage.source_damage[source.unit_number]
    check("three-native-upfront-payments",opener and opener.count==3 and rounds(source)==0
        and storage.timing_reserves[1]==2 and storage.timing_reserves[2]==1 and storage.timing_reserves[3]==0,
        {opener=opener,reserves_after_admission=storage.timing_reserves})
    check("three-charge100-per-channel-per-payment",record and record.crown.count==300
        and record.facade.count==300 and record.legacy.count==0 and record.unexpected==0,record)
    check("three-charge-combined144k",health0(storage.persistence_target)-storage.persistence_target.health==144000
        and record and record.crown.total==96000 and record.facade.total==48000)
    local paired=true
    local starts={}
    for _,channel in ipairs{"crown","facade"} do
        local hits=record and record[channel]
        local spacing=hits and #hits.ticks==300
        if spacing then
            starts[channel]={hits.ticks[1],hits.ticks[101],hits.ticks[201]}
            spacing=hits.ticks[101]-hits.ticks[1]==1200 and hits.ticks[201]-hits.ticks[101]==1200
        end
        check(channel.."-three-paid-starts1200-apart",spacing==true,starts[channel])
        check(channel.."-continuous12-tick-contacts",hits and exact_cadence(hits),hits and hits.ticks)
    end
    if record and record.crown.count==300 and record.facade.count==300 then
        for i=1,300 do paired=paired and record.crown.ticks[i]==record.facade.ticks[i] end
    else paired=false end
    check("three-charge-shared-channel-clock",paired,starts)
    check("three-charge-no-extra-paid-tail",snapshot(source).owner==nil and rounds(source)==0)
    storage.complete=true;report()
end

local function pose_metadata(entity,include_visuals)
    local value=snapshot(entity)
    local result={position=entity.position,orientation=entity.orientation,torso=entity.torso_orientation,
        speed=entity.speed,height=entity.prototype.height,owner=value.owner,
        channel_view=config.isolate or "all",direction_count=value.direction_count,
        camera={position={entity.position.x,entity.position.y-5},resolution={768,768},zoom=1}}
    if include_visuals then result.visuals=value.visuals end
    return result
end
module.visual_pose_metadata=pose_metadata

local function movement_probe(entity,name)
    local projection=remote.call(INTERFACE,"projection",entity)
    for _,offset in ipairs(projection.keel_tips) do
        for _,variant in ipairs{{lift=0,color={r=1,g=1,b=1}},{lift=1.8,color={r=1,g=0,b=0}},
            {world=true,lift=0,color={r=0,g=1,b=1}}} do
            local x,y=offset[1],offset[2]-variant.lift
            for _,axis in ipairs{{dx=.07,dy=0},{dx=0,dy=.07}} do
                local from,to={entity=entity,offset={x-axis.dx,y-axis.dy}},
                    {entity=entity,offset={x+axis.dx,y+axis.dy}}
                if variant.world then
                    from={entity.position.x+x-axis.dx,entity.position.y+y-axis.dy}
                    to={entity.position.x+x+axis.dx,entity.position.y+y+axis.dy}
                end
                rendering.draw_line{surface=entity.surface,
                    from=from,to=to,
                    color=variant.color,width=1.5,draw_on_ground=false,time_to_live=4}
            end
        end
    end
    game.take_screenshot{surface=entity.surface,position={entity.position.x,entity.position.y-5},
        resolution={768,768},zoom=1,path="anisetron-art/movement-probe-"..name..".png",
        show_gui=false,show_entity_info=false,daytime=0,anti_alias=true,force_render=true}
    helpers.write_file("anisetron-art/movement-probe-"..name..".json",helpers.table_to_json{
        colors={white="entity target with projected offset as-is",red="entity target with projected offset minus 1.8",
            cyan="fixed world target at entity position plus projected offset"},
        projection=projection,pose=pose_metadata(entity,true)},false)
end

function module.visual_tick(event,check,report,vehicle,target)
    local t=event.tick-storage.started
    if t==1 then
        check("visual-startup-fidelity",settings.startup["ei-anisetron-visual-fidelity"].value==config.fidelity)
    end
    if t==180 or t==220 then
        local poses={}
        for i,entity in ipairs(storage.poses) do poses[i]=pose_metadata(entity) end
        helpers.write_file("anisetron-art/twin-muzzles-"..t..".json",helpers.table_to_json(poses),false)
    end
    if t==10 then
        storage.fx_art=vehicle(storage.visual,{-70,80},nil,false)
        storage.fx_art.autopilot_destination={-10,80}
        storage.fx_front_art=vehicle(storage.visual,{70,170},nil,false)
        -- South is the facade view. North exposes the rear roof and occludes these tips.
        storage.fx_front_art.autopilot_destination={70,230}
    elseif t==160 or t==162 then
        local entity=storage.fx_art
        game.take_screenshot{surface=storage.visual,position={entity.position.x,entity.position.y-5},
            resolution={768,768},zoom=1,path="anisetron-art/movement-"..(t==160 and "day" or "night")..".png",
            show_gui=false,show_entity_info=false,daytime=t==160 and 0 or .5,anti_alias=true,force_render=true}
        helpers.write_file("anisetron-art/movement-"..t..".json",helpers.table_to_json(pose_metadata(entity,true)),false)
        local front=storage.fx_front_art
        game.take_screenshot{surface=storage.visual,position={front.position.x,front.position.y-5},
            resolution={768,768},zoom=1,path="anisetron-art/movement-front-"..(t==160 and "day" or "night")..".png",
            show_gui=false,show_entity_info=false,daytime=t==160 and 0 or .5,anti_alias=true,force_render=true}
        helpers.write_file("anisetron-art/movement-front-"..t..".json",helpers.table_to_json(pose_metadata(front,true)),false)
    elseif t==164 then
        -- Probe markers belong to the helper mod and expire before clean stop views.
        movement_probe(storage.fx_art,"east")
        movement_probe(storage.fx_front_art,"front")
    elseif t==170 then
        storage.fx_art.autopilot_destination=nil
        storage.fx_front_art.autopilot_destination=nil
    elseif t==210 then
        game.take_screenshot{surface=storage.visual,position={storage.fx_art.position.x,storage.fx_art.position.y-5},
            resolution={768,768},zoom=1,path="anisetron-art/movement-stopped.png",
            show_gui=false,show_entity_info=false,daytime=0,anti_alias=true,force_render=true}
        helpers.write_file("anisetron-art/movement-stopped.json",helpers.table_to_json(pose_metadata(storage.fx_art,true)),false)
        local front=storage.fx_front_art
        game.take_screenshot{surface=storage.visual,position={front.position.x,front.position.y-5},
            resolution={768,768},zoom=1,path="anisetron-art/movement-front-stopped.png",
            show_gui=false,show_entity_info=false,daytime=0,anti_alias=true,force_render=true}
        helpers.write_file("anisetron-art/movement-front-stopped.json",helpers.table_to_json(pose_metadata(front,true)),false)
    end
    if t==250 then
        -- Eight real hostile military targets cover front, sides and rear. Native
        -- payment starts the burst before the facade-side body is frozen at 300.
        storage.ring_art=vehicle(storage.visual,{-150,120},1,true)
        storage.ring_art.orientation=.5;storage.ring_art.torso_orientation=.5
        storage.ring_targets={}
        for index=0,7 do
            local angle=index/8*math.pi*2
            storage.ring_targets[index+1]=target(storage.visual,
                {-150+math.sin(angle)*16,120-math.cos(angle)*16})
        end
        storage.ring_frames={};storage.motion_frames={}
        storage.motion_art=vehicle(storage.visual,{100,80},nil,false)
        storage.motion_art.autopilot_destination={100,140}
    elseif t==300 then
        storage.ring_art.active=false
        storage.ring_art.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
        storage.ring_art.orientation=.5;storage.ring_art.torso_orientation=.5
    elseif t==350 then
        storage.motion_art.autopilot_destination={140,110}
    elseif t==440 then
        storage.motion_art.autopilot_destination=nil
    end
    if t>=312 and t<=588 and (t-312)%12==0 then
        local frame=(t-312)/12+1
        for _,kind in ipairs{"ring","motion"} do
            local entity=kind=="ring" and storage.ring_art or storage.motion_art
            local camera=kind=="ring" and {position={entity.position.x,entity.position.y-2},resolution={1024,1024},zoom=.75}
                or {position={entity.position.x,entity.position.y-5},resolution={768,768},zoom=1}
            for _,mode in ipairs{"day","night"} do
                game.take_screenshot{surface=storage.visual,position=camera.position,resolution=camera.resolution,
                    zoom=camera.zoom,path=string.format("anisetron-art/%s-%s/%03d.png",kind,mode,frame),
                    show_gui=false,show_entity_info=false,daytime=mode=="day" and 0 or .5,anti_alias=true,force_render=true}
            end
            local metadata=pose_metadata(entity,true)
            metadata.camera=camera;metadata.tick=event.tick
            if kind=="ring" then
                metadata.targets={}
                for index,enemy in ipairs(storage.ring_targets) do
                    metadata.targets[index]={unit_number=enemy.unit_number,position=enemy.position,health=enemy.health}
                end
                storage.ring_frames[frame]=metadata
            else storage.motion_frames[frame]=metadata end
        end
        if frame==24 then
            helpers.write_file("anisetron-art/ring-poses.json",helpers.table_to_json(storage.ring_frames),false)
            helpers.write_file("anisetron-art/motion-poses.json",helpers.table_to_json(storage.motion_frames),false)
        end
    end
    if t==650 then
        local ring=storage.source_damage[storage.ring_art.unit_number]
        local facade_locked=#storage.ring_frames==24
        local first_target
        local crown_targets={};local count=0
        for _,frame in ipairs(storage.ring_frames) do
            local facade=frame.owner and frame.owner.burst and frame.owner.burst.facade
            first_target=first_target or facade and facade.target
            facade_locked=facade_locked and facade and facade.target==first_target and first_target~=nil
            local enemy_position
            for _,enemy in ipairs(frame.targets) do
                if enemy.unit_number==first_target then enemy_position=enemy.position end
            end
            if enemy_position then
                local dx,dy=enemy_position.x-frame.position.x,enemy_position.y-frame.position.y
                local angle=frame.torso*math.pi*2
                local distance=math.sqrt(dx*dx+dy*dy)
                facade_locked=facade_locked and distance>0
                    and (dx*math.sin(angle)-dy*math.cos(angle))/distance>=.5-.0001
            else facade_locked=false end
        end
        if ring then
            for _,id in ipairs(ring.crown.targets) do if not crown_targets[id] then crown_targets[id]=true;count=count+1 end end
        end
        check("visual360-crown-retains-one-eligible-target",count==1 and #ring.crown.targets>0
            and module.locked_sequence(ring.crown.targets,#ring.crown.targets),{unique_targets=count})
        check("visual120-facade-holds-one-front-target",facade_locked==true,ring and ring.facade.targets)
        local first=storage.motion_frames[1];local last=storage.motion_frames[24]
        local turned=false
        for _,frame in ipairs(storage.motion_frames) do
            turned=turned or first and math.abs(frame.orientation-first.orientation)>.01
        end
        check("visual-native-move-turn-coast-stop",first and last and math.abs(first.speed)>0
            and math.abs(last.speed)<.001 and #storage.motion_frames==24 and turned
            and ((last.position.x-first.position.x)^2+(last.position.y-first.position.y)^2)>.01,
            {first_speed=first and first.speed,last_speed=last and last.speed,frames=#storage.motion_frames,turned=turned})
        helpers.write_file("anisetron-art/capture-manifest.json",helpers.table_to_json{
            fixture_version=2,channel_view=config.isolate or "all",fidelity=config.fidelity,
            direction_count=snapshot().direction_count,full_directions=config.full_directions==true,
            direction_camera={relative_position={0,-5},resolution={768,768},zoom=1},
            ring_camera={relative_position={0,-2},resolution={1024,1024},zoom=.75},
            clips={ring={frames=24,interval=12,lighting={"day","night"}},
                motion={frames=24,interval=12,lighting={"day","night"},route_change_tick=350,route_clear_tick=440}},
            note="Isolation changes only the nonmeasured beam appearance; both paid channels and damage remain active"},false)
        if not config.full_directions then storage.complete=true;report() end
    end
    if not config.full_directions then return end
    if t==1 then
        storage.full_pose=vehicle(storage.visual,{0,170},1,true)
        storage.full_target=target(storage.visual,{0,150})
        storage.full_metadata={}
    elseif t==40 then
        storage.full_pose.active=false
        storage.full_pose.vehicle_automatic_targeting_parameters={auto_target_with_gunner=false,auto_target_without_gunner=false}
    end
    if t>=300 and t<684 and (t-300)%3==0 then
        local index=(t-300)/3
        local angle=index/128*math.pi*2
        storage.full_pose.orientation=index/128;storage.full_pose.torso_orientation=index/128
        storage.full_target.teleport({math.sin(angle)*20,170-math.cos(angle)*20})
    elseif t>=301 and t<685 and (t-301)%3==0 then
        local index=(t-301)/3
        local entity=storage.full_pose
        for _,mode in ipairs{"day","night"} do
            game.take_screenshot{surface=storage.visual,position={entity.position.x,entity.position.y-5},
                resolution={768,768},zoom=1,path=string.format("anisetron-art/directions128/%03d-%s.png",index,mode),
                show_gui=false,show_entity_info=false,daytime=mode=="day" and 0 or .5,anti_alias=true,force_render=true}
        end
        storage.full_metadata[index+1]=pose_metadata(entity)
    elseif t==700 then
        helpers.write_file("anisetron-art/directions128/poses.json",helpers.table_to_json(storage.full_metadata),false)
        local aligned=#storage.full_metadata==128
        for index,pose in ipairs(storage.full_metadata) do
            local paid=pose.owner and pose.owner.burst
            aligned=aligned and paid and paid.crown and paid.facade
                and paid.crown.muzzle_index==index and paid.facade.muzzle_index==index
                and paid.crown.beam and paid.facade.beam
        end
        check("128-direction-twin-capture-metadata",aligned)
        storage.complete=true;report()
    end
end

return module
