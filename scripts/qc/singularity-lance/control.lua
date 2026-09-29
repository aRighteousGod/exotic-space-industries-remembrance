local config = require("test-config")
local sweep_cases = require("sweep-cases")
local angular_cases = require("angular-cases")
local NAME = "ei-singularity-lance"
local upgrades = {"axial-rupture","wound-memory","terminal-collapse","black-hole-testament"}
local function call(method, ...) return remote.call("lance-fixture", method, ...) end
local function check(condition, name)
    if not condition then error("LANCE_QC FAIL " .. name) end
    log("LANCE_QC PASS " .. name)
end
local function close(actual, expected, name)
    check(math.abs(actual - expected) < 0.01, name .. " actual=" .. actual .. " expected=" .. expected)
end
local function entity(name, p, force, quality)
    local e = assert(storage.surface.create_entity{name=name,position=p,force=force or storage.enemy,
        quality=quality or "normal",raise_built=true})
    e.active = false
    return e
end
local function target(x,y,name,force) return entity(name or "lance-qc-target",{x,y},force) end
local function level(n, force)
    force = force or storage.force
    force.technologies[NAME].researched = true
    for i,key in ipairs(upgrades) do if force.technologies[NAME.."-"..key] then force.technologies[NAME.."-"..key].researched = i<=n end end
    call("sync",force)
end
local function shot(source,victim,tick,position)
    local before = victim and victim.valid and victim.health or 0
    call("shot",source,victim,position,tick)
    return before - (victim and victim.valid and victim.health or 0)
end
local function clean()
    for _, e in pairs(storage.surface.find_entities()) do if e.valid then e.destroy{raise_destroy=true} end end
    call("service",1000000)
end
-- These helpers serve only the inherited synchronous geometry/damage cases.
-- Arrival, native dispatch, save/reload and benchmarks always use literal ticks.
local last_settled_delay = 8
local function settled_shot(source, victim, tick, position)
    local before = victim and victim.valid and victim.health or 0
    shot(source, victim, tick, position)
    local contact = call("latest_contact", source.unit_number)
    last_settled_delay = contact.due - tick
    call("service", contact.due)
    return before - (victim and victim.valid and victim.health or 0)
end
-- Only inherited one-sequence damage cases use this translated firing timeline.
-- The literal angular/sweep cases and real dispatcher never use this adapter.
local function service_after_contact(tick) return call("service", tick + last_settled_delay) end
local function rig(n)
    clean(); level(n)
    return entity(NAME,{0,0},storage.force), target(10,0)
end
local function meter(source) return call("snapshot").meters[source.unit_number] end

-- Fixture-only synchronous damage reactions reproduce entities disappearing
-- between primary resolution and visual presentation. Never enabled in benchmarks.
if config.mode == "mechanics" then
    script.on_event(defines.events.on_entity_damaged, function(event)
        local admission=storage.angular_reentrant
        if admission and event.entity==admission.trigger then
            storage.angular_reentrant=nil
            call("shot",admission.source,nil,admission.aim,admission.tick)
        end
        if event.entity == storage.watch_damage_target then
            storage.watch_damage_cause = event.cause ~= nil
        end
        if event.entity == storage.reentrant_secondary then
            storage.reentrant_secondary = nil
            local victim = storage.reentrant_destroy
            storage.reentrant_destroy = nil
            if victim and victim.valid then victim.destroy{raise_destroy=true} end
        end
    end)
end

local function presentation_checks(tick)
    local s,t=rig(1)
    settled_shot(s,t,tick)
    local cue=call("cues",s.unit_number)
    check(cue.beam.valid and cue.beam.type=="beam" and cue.beam.name:find(NAME.."-beam-axial-light-",1,true)==1,"native axial beam")
    settled_shot(s,t,tick)
    check(call("cues",s.unit_number).beam==cue.beam,"same geometry reuses native beam without TTL setter")
    local other=target(10,4)
    settled_shot(s,other,tick)
    check(cue.beam.valid,"retarget preserves native beam animation")
    check(storage.surface.count_entities_filtered{type="beam"}==4,"four bounded native core beams per upgraded lance")
    s,t=rig(2); settled_shot(s,t,tick)
    cue=call("cues",s.unit_number)
    check(cue.mark.type=="animation" and cue.mark.animation==NAME.."-wound-1","animated first wound band")
    local mark=cue.mark
    settled_shot(s,t,tick); settled_shot(s,t,tick)
    cue=call("cues",s.unit_number)
    check(cue.mark==mark and cue.mark.animation==NAME.."-wound-2","same mark changes to branching animation")
    settled_shot(s,t,tick); settled_shot(s,t,tick)
    cue=call("cues",s.unit_number)
    check(cue.mark==mark and cue.mark.animation==NAME.."-wound-3","same mark changes to broken halo")
    t.teleport{12,3}
    check(cue.mark.target.entity==t,"wound uses engine-followed entity target")
    s,t=rig(4)
    for _=1,7 do settled_shot(s,t,tick) end
    local before=call("snapshot")
    local old=call("old_presentation",s.unit_number,60)
    call("check")
    local migrated=call("snapshot"); cue=call("cues",s.unit_number)
    check(migrated.version==14 and migrated.presentation_revision==4,"independent presentation revision")
    check(meter(s).counter==7 and meter(s).stacks==5 and meter(s).wound_tick==old.wound_tick,"presentation migration preserves meters and wound timestamp")
    check(migrated.pending==before.pending and migrated.impact_next_due_tick==before.impact_next_due_tick,"presentation migration preserves paid queues and due tick")
    check(not old.beam.valid and not old.mark.valid,"migration destroys old Sprite handles")
    check(cue.mark.type=="animation" and cue.mark.time_to_live==60,"migration restores remaining wound lifetime")
    call("check")
    check(call("cues",s.unit_number).mark==cue.mark,"presentation migration is idempotent")
    close(settled_shot(s,t,tick),4000,"eighth after presentation migration keeps full wound damage")
    cue=call("cues",s.unit_number)
    check(cue.shape=="testament" and cue.beam.name:find(NAME.."-beam-testament-light-",1,true)==1,"native testament silhouette")
    close(settled_shot(s,t,tick+1),1000,"ordinary shot during testament hold keeps ordinary damage")
    check(call("cues",s.unit_number).beam==cue.beam,"same geometry preserves testament presentation hold")
    other=target(15,3); settled_shot(s,other,tick+2)
    check(not cue.beam.valid,"new geometry interrupts testament hold")
    local area=target(10,2)
    service_after_contact(tick+30)
    close(10000000-area.health,6200,"migrated seven collapses and eighth resolve separately once")
    service_after_contact(tick+30)
    close(10000000-area.health,6200,"repeat service cannot repeat migrated collapses")
    s,t=rig(4); settled_shot(s,t,tick)
    call("old_presentation",s.unit_number,120); call("check")
    check(meter(s).stacks==0 and call("cues",s.unit_number).mark==nil,"expired wound is not resurrected by presentation migration")
    s,t=rig(4); settled_shot(s,t,tick)
    call("old_presentation",s.unit_number,30)
    t.force=storage.force; call("check")
    check(meter(s).stacks==0 and call("cues",s.unit_number).mark==nil,"newly protected wound is not recreated by migration")
    s,t=rig(4); settled_shot(s,t,tick)
    call("old_presentation",s.unit_number,60); call("check",tick+15)
    check(call("cues",s.unit_number).mark.time_to_live==45,"presentation rebuild uses supplied event tick instead of game tick")
    call("old_presentation",s.unit_number,60); call("check",tick+60)
    check(meter(s).stacks==0 and call("cues",s.unit_number).mark==nil,"event-tick rebuild expires wound at exact timeout")
    s,t=rig(3); settled_shot(s,t,tick)
    check(call("snapshot",tick+37).pending_due==0,"status uses supplied tick before packet is due")
    check(call("snapshot",tick+38).pending_due==1,"status uses supplied tick on packet due tick")
end

local function crystal_origin_checks(tick)
    for _, n in ipairs({0,1,4}) do
        for direction, delta in ipairs({{10,0},{6,8},{0,10},{-6,8},{-10,0},{-6,-8},{0,-10},{6,-8}}) do
            local s,t=rig(n)
            s.teleport{41,-27}
            local base=s.position -- The turret snaps placement to its tile grid.
            t.teleport{base.x+delta[1],base.y+delta[2]}
            for _=1,n==4 and 8 or 1 do settled_shot(s,t,tick) end
            local beam=call("cues",s.unit_number).beam
            local source, destination=beam.get_beam_source().position,beam.get_beam_target().position
            local label="crystal muzzle level "..n.." direction "..direction
            -- Compare the engine endpoints with the original approved crystal
            -- eye and ground-space aim, independently of the production config.
            close(source.x,base.x,label.." x")
            close(source.y,base.y-3.35,label.." y")
            local reach=1
            close(destination.x,base.x+delta[1]*reach,label.." unchanged endpoint x")
            close(destination.y,base.y+delta[2]*reach,label.." unchanged endpoint y")
            if n>=1 then
                local extensions=call("cues",s.unit_number).extensions
                check(#extensions==3,label.." has forward incision and two branches")
                for index,segment in ipairs(extensions) do
                    local start=segment.beam.get_beam_source().position
                    close(start.x,t.position.x,label.." joined fork "..index.." x")
                    close(start.y,t.position.y,label.." joined fork "..index.." y")
                end
                local ending=extensions[1].beam.get_beam_target().position
                close(ending.x,base.x+delta[1]*3.4,label.." forward reach x")
                close(ending.y,base.y+delta[2]*3.4,label.." forward reach y")
            end
        end
    end
end


-- Hybrid geometry fixtures position relative to the actual source after the
-- engine snaps its placement; teleport targets to exact fixed-point positions.
local function exact_target(x,y,name,force)
    local e=target(x,y,name or "lance-qc-precise",force)
    assert(e.teleport{x,y})
    return e
end
local function relative_target(source,x,y,name,force)
    local p=source.position
    return exact_target(p.x+x,p.y+y,name,force)
end
local function hybrid_rig(n)
    local s,t=rig(n)
    t.destroy()
    t=relative_target(s,10,0)
    return s,t
end
local function prime_testament()
    local s,t=hybrid_rig(4)
    for i=1,7 do settled_shot(s,t,i) end
    service_after_contact(37)
    return s,t
end
local function hybrid_checks()
    local s,t=hybrid_rig(1)
    local nearest={}
    for i=1,5 do nearest[i]=relative_target(s,i+1,0) end
    local overlap=relative_target(s,12,.9)
    local branch=relative_target(s,17,2)
    local queries=call("snapshot").counters.penetration_queries or 0
    settled_shot(s,t,1)
    for i=1,5 do close(10000000-nearest[i].health,500,"hybrid central nearest "..i) end
    close(overlap.health,10000000,"central eligibility beyond cap cannot fall back to branch")
    close(10000000-branch.health,250,"branch-only target receives weaker distinct packet")
    check(call("snapshot").counters.penetration_queries==queries+1,"three incision rays use one spatial query")

    s,t=hybrid_rig(1)
    local cosine,sine=math.cos(math.pi/12),math.sin(math.pi/12)
    local branches={}
    for i=1,4 do
        local distance,sign=i+5,i%2==1 and 1 or -1
        branches[i]=relative_target(s,10+distance*cosine,sign*distance*sine)
    end
    settled_shot(s,t,1)
    for i=1,3 do close(10000000-branches[i].health,250,"nearest shared branch cap "..i) end
    close(branches[4].health,10000000,"fourth branch target excluded across both sides")

    s,t=hybrid_rig(1)
    relative_target(s,10+6*cosine,6*sine)
    relative_target(s,10+7*cosine,-7*sine)
    local first=relative_target(s,10+9*cosine,9*sine)
    local tied=relative_target(s,10+9*cosine,9*sine)
    settled_shot(s,t,1)
    close(10000000-first.health,250,"equal branch travel uses lower unit-number tie")
    close(tied.health,10000000,"equal branch travel excludes later entity")

    s,t=hybrid_rig(1)
    local grazing=relative_target(s,6,1.2)
    local missed=relative_target(s,6,1.6)
    local ending=relative_target(s,34,0)
    local beyond=relative_target(s,35,0)
    settled_shot(s,t,1)
    close(10000000-grazing.health,500,"two-tile central strip includes bounding-box graze")
    close(missed.health,10000000,"central strip excludes wider miss")
    close(10000000-ending.health,500,"central incision reaches twenty-four tiles past aim")
    close(beyond.health,10000000,"central incision stops at configured endpoint")

    for index,unit in ipairs({{1,0},{.6,.8},{0,1},{-.6,.8},{-1,0},{-.6,-.8},{0,-1},{.6,-.8}}) do
        s,t=hybrid_rig(1)
        local ux,uy=unit[1],unit[2]
        t.teleport{s.position.x+10*ux,s.position.y+10*uy}
        local central=relative_target(s,6*ux,6*uy)
        local bx,by=ux*cosine-uy*sine,uy*cosine+ux*sine
        local forked=relative_target(s,10*ux+8*bx,10*uy+8*by)
        settled_shot(s,t,1)
        close(10000000-central.health,500,"central mechanical ray direction "..index)
        close(10000000-forked.health,250,"branch mechanical ray direction "..index)
    end

    s,t=prime_testament()
    branches={}
    for i=1,7 do
        local distance,sign=i+5,i%2==1 and 1 or -1
        branches[i]=relative_target(s,10+distance*cosine,sign*distance*sine)
    end
    settled_shot(s,t,100)
    for i=1,6 do close(10000000-branches[i].health,250,"testament shared branch cap "..i) end
    close(branches[7].health,10000000,"testament seventh branch candidate excluded")

    s,t=hybrid_rig(1)
    local friend_branch=relative_target(s,18,2,nil,storage.force)
    local neutral_branch=relative_target(s,18,-2,nil,game.forces.neutral)
    settled_shot(s,t,1)
    close(friend_branch.health,10000000,"friendly branch target protected")
    close(neutral_branch.health,10000000,"neutral branch target protected")

    s,t=hybrid_rig(1)
    t.teleport{s.position.x+84,s.position.y}
    local range=s.prototype.attack_parameters.range*s.quality.range_multiplier
    settled_shot(s,t,1)
    local cue=call("cues",s.unit_number)
    for _,segment in pairs(cue.extensions) do
        local p=segment.beam.get_beam_target().position
        check((p.x-s.position.x)^2+(p.y-s.position.y)^2<=range^2+.02,"all secondary endpoints remain in effective-range circle")
    end
    t.teleport{s.position.x+range+2,s.position.y}
    settled_shot(s,t,2)
    check(next(call("cues",s.unit_number).extensions)==nil,"native-approved outside-center aim creates no out-of-range extensions")

    s,t=hybrid_rig(3)
    close(settled_shot(s,t,100),500,"first hit prepares next-hit wound bonus")
    local center=t.position
    local core=exact_target(center.x,center.y+1.5)
    local shell=exact_target(center.x,center.y+1.6)
    local edge=exact_target(center.x,center.y+4)
    local outside=exact_target(center.x,center.y+4.1)
    service_after_contact(129)
    close(core.health,10000000,"core damage waits thirty ticks")
    service_after_contact(130)
    close(10000000-core.health,1000,"core boundary receives only core damage")
    close(10000000-shell.health,600,"outside core receives only shell damage")
    close(10000000-edge.health,600,"outer boundary included")
    close(outside.health,10000000,"outside shell excluded")
    close(10000000-t.health,1500,"primary receives reserved core packet")
    service_after_contact(130)
    close(10000000-core.health,1000,"collapse cannot be serviced twice")

    s,t=hybrid_rig(3)
    settled_shot(s,t,100)
    local area={}
    for i=1,11 do area[i]=exact_target(t.position.x,t.position.y+2+i*.1) end
    service_after_contact(130)
    for i=1,10 do close(10000000-area[i].health,600,"terminal secondary cap "..i) end
    close(area[11].health,10000000,"terminal eleventh secondary excluded")
    close(10000000-t.health,1500,"primary slot does not consume secondary cap")

    s,t=hybrid_rig(3)
    settled_shot(s,t,100); settled_shot(s,t,100)
    local resisted=exact_target(t.position.x,t.position.y+2,"lance-qc-resistant")
    service_after_contact(130)
    close(10000000-resisted.health,1000,"two paid shell packets preserve two flat resistances")

    s,t=prime_testament()
    local primary_before=t.health
    close(settled_shot(s,t,100),4000,"isolated fully wounded eighth primary")
    local packets=call("packets")
    check(#packets==2 and packets[1].due==138 and packets[2].due==168,"both paid pulses queued immediately at fixed ticks")
    check(packets[1].echo_is_queued and packets[2].phase=="echo","first pulse links the already queued echo")
    check(packets[1].include_primary and packets[2].include_primary,"both new pulses reserve the primary")
    core=exact_target(t.position.x,t.position.y+2)
    shell=exact_target(t.position.x,t.position.y+4)
    edge=exact_target(t.position.x,t.position.y+5)
    outside=exact_target(t.position.x,t.position.y+6.1)
    service_after_contact(129); close(core.health,10000000,"testament first pulse not early")
    service_after_contact(130)
    close(10000000-core.health,2000,"testament concentrated core")
    close(10000000-shell.health,1200,"testament outer shell")
    close(10000000-edge.health,1200,"testament first shell reaches echo edge")
    close(outside.health,10000000,"testament radius excludes outside target")
    close(primary_before-t.health,6000,"testament primary plus first core")
    check(call("snapshot").pending==1,"only paid echo remains after first impact")
    packets=call("packets")
    check(packets[1].warning.valid and packets[1].warning.time_to_live==30,"echo warning begins after first impact")
    service_after_contact(159); close(10000000-core.health,2000,"echo not early")
    service_after_contact(160)
    close(primary_before-t.health,7000,"stationary full-wound testament sequence totals seven thousand")
    close(10000000-core.health,3000,"echo adds one flat core packet")
    close(10000000-shell.health,2200,"echo adds one flat shell packet")
    close(10000000-edge.health,2200,"echo radius-five boundary included")
    check(call("snapshot").pending==0,"echo consumed once")
    service_after_contact(160); close(primary_before-t.health,7000,"repeat echo service does not repeat damage")

    s,t=prime_testament(); settled_shot(s,t,100)
    service_after_contact(145)
    packets=call("packets")
    check(#packets==1 and packets[1].warning.valid,"late first service keeps queued echo")
    close(packets[1].warning.time_to_live,15,"late warning keeps original echo deadline")
    close(packets[1].warning.animation_offset,15,"late warning joins existing animation phase")
    service_after_contact(160)
    s,t=prime_testament(); primary_before=t.health; settled_shot(s,t,100)
    local cues_before=call("snapshot").counters.core_cues
    service_after_contact(175)
    close(primary_before-t.health,7000,"overdue service settles both paid packets")
    check(call("snapshot").counters.core_cues==cues_before+2,"overdue pair creates impacts without resurrected warning")
    check(#call("packets")==0,"overdue pair clears both buckets")

    s,t=prime_testament(); primary_before=t.health; settled_shot(s,t,100)
    local aim={x=t.position.x,y=t.position.y}
    t.teleport{aim.x+20,aim.y+20}
    service_after_contact(130)
    close(primary_before-t.health,4000,"moving primary escapes fixed first collapse")
    t.teleport(aim); service_after_contact(160)
    close(primary_before-t.health,5000,"returning primary can enter independently paid echo")

    s,t=prime_testament(); primary_before=t.health; settled_shot(s,t,100)
    local friendly=exact_target(t.position.x,t.position.y+2,nil,storage.force)
    local neutral=exact_target(t.position.x,t.position.y-2,nil,game.forces.neutral)
    storage.enemy.set_friend(storage.force,true); service_after_contact(130)
    close(primary_before-t.health,4000,"changed reverse friendship protects first pulse")
    storage.enemy.set_friend(storage.force,false); service_after_contact(160)
    close(primary_before-t.health,5000,"echo rechecks diplomacy independently")
    close(friendly.health,10000000,"friendly protected from both testament pulses")
    close(neutral.health,10000000,"neutral protected from both testament pulses")

    s,t=prime_testament(); primary_before=t.health; settled_shot(s,t,100)
    service_after_contact(130)
    storage.enemy.set_cease_fire(storage.force,true)
    service_after_contact(160)
    close(primary_before-t.health,6000,"new reverse cease-fire protects echo after first impact")
    storage.enemy.set_cease_fire(storage.force,false)

    s,t=prime_testament(); primary_before=t.health; settled_shot(s,t,100)
    service_after_contact(130)
    s.destroy{raise_destroy=true}; level(0)
    storage.force.set_ammo_damage_modifier(NAME,1); call("sync",storage.force)
    service_after_contact(160)
    close(primary_before-t.health,7000,"echo snapshots survive source removal research loss and multiplier change")
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)

    s,t=hybrid_rig(4)
    for i=1,7 do settled_shot(s,t,i) end
    local before=call("snapshot")
    local identity=call("migrate_schema11")
    check(identity.runtime and identity.lances and identity.registrations and identity.buckets,"schema-eleven migration is in-place")
    check(meter(s).counter==7 and meter(s).stacks==5 and meter(s).wound_tick==15,"schema-eleven migration preserves all meters")
    check(call("snapshot").pending==before.pending and call("snapshot").impact_next_due_tick==before.impact_next_due_tick,"schema-eleven migration preserves paid counts and due tick")
    primary_before=t.health
    local legacy_area=exact_target(t.position.x,t.position.y+2)
    service_after_contact(37)
    close(10000000-legacy_area.health,1750,"migrated legacy packets retain old damage and count")
    close(t.health,primary_before,"migrated legacy packets retain primary exclusion")
    close(settled_shot(s,t,100),4000,"counter-seven migration uses hybrid rules only on new shot")
    check(#call("packets")==2,"new eighth after migration alone schedules echo")
    call("check"); service_after_contact(160)
    close(10000000-legacy_area.health,4750,"legacy and new transactions keep separate snapshot rules")

    s,t=hybrid_rig(4)
    local crowded={s}
    for i=2,96 do crowded[i]=entity(NAME,s.position,storage.force) end
    for _,source in ipairs(crowded) do for _=1,8 do settled_shot(source,t,100) end end
    close(10000000-t.health,912000,"ninety-six overlapping lances retain separate primary packets")
    check(call("snapshot").pending==864,"visual overload retains every first pulse and echo")
    check(storage.surface.count_entities_filtered{type="beam"}==384,"rapid-fire overload remains bounded to four beams per lance")
    local packets_before=call("snapshot").counters.secondary_packets
    service_after_contact(130)
    -- Engine health arithmetic accumulates sub-point rounding at this scale;
    -- count packets exactly and allow less than one tenth of a single packet.
    check(math.abs(10000000-t.health-1824000)<64,"visual overload first damage within engine rounding "..(10000000-t.health))
    check(call("snapshot").counters.secondary_packets-packets_before==768,"visual overload retains every first collapse")
    service_after_contact(160)
    check(math.abs(10000000-t.health-1920000)<64,"visual overload total damage within engine rounding "..(10000000-t.health))
    check(call("snapshot").counters.secondary_packets-packets_before==864,"visual overload retains every echo")
    check(call("snapshot").pending==0,"overloaded mechanics drain completely")
end

local function mechanics(tick)
    call("configure",{qc_enabled=true,profiling_enabled=false})
    sweep_cases{call=call,check=check,close=close,rig=rig,target=target,level=level,entity=entity,clean=clean}
    angular_cases{call=call,check=check,close=close,rig=rig,target=target,level=level,entity=entity,clean=clean}
    crystal_origin_checks(tick)
    presentation_checks(tick)
    hybrid_checks()
    local s,t = rig(0)
    local secondary=target(10,1)
    local friend=target(10,-1,nil,storage.force)
    local neutral=target(11,0,nil,game.forces.neutral)
    close(settled_shot(s,t,1),500,"base primary")
    check(call("cues",s.unit_number).beam.name:find(NAME.."-beam-light-",1,true)==1,"baseline restores original native prismatic beam")
    close(10000000-secondary.health,125,"guaranteed base splash")
    close(friend.health,10000000,"same-force protected")
    close(neutral.health,10000000,"neutral protected")
    storage.force.set_ammo_damage_modifier(NAME,1); call("sync",storage.force)
    close(settled_shot(s,t,2),1000,"category multiplier")
    close(10000000-secondary.health,375,"splash multiplier")
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)
    s,t=rig(2)
    for index,value in ipairs({500,600,700,800,900,1000,1000}) do close(settled_shot(s,t,index),value,"wound ramp "..index) end
    close(settled_shot(s,t,126),1000,"wound below timeout")
    close(settled_shot(s,t,246),500,"wound exact timeout")
    local other=target(20,4)
    close(settled_shot(s,other,247),500,"retarget resets")
    close(settled_shot(s,t,248),500,"return target resets")
    local immune=target(20,10,"lance-qc-immune")
    close(settled_shot(s,immune,249),0,"immune primary")
    check(meter(s).stacks==0,"zero damage builds no wound")
    local sec=target(7,0)
    settled_shot(s,t,250)
    close(10000000-sec.health,500,"secondary has no wound multiplier")
    s,t=rig(2); settled_shot(s,t,1)
    storage.force.set_ammo_damage_modifier(NAME,-1); call("sync",storage.force)
    close(settled_shot(s,t,2),0,"zero multiplier primary")
    check(meter(s).stacks==1 and meter(s).wound_tick==9,"zero damage neither builds nor refreshes existing wound")
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)
    close(settled_shot(s,t,3),600,"positive hit resumes unexpired wound")
    storage.force.set_ammo_damage_modifier(NAME,-1); call("sync",storage.force); settled_shot(s,t,100)
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)
    close(settled_shot(s,t,123),500,"zero hit does not postpone exact expiry")
    s,t=rig(3)
    storage.reentrant_secondary,storage.reentrant_destroy=target(6,0),t
    settled_shot(s,t,1)
    check(not t.valid and meter(s).stacks==0,"secondary reaction removes primary before wound cue")
    check(call("snapshot").pending==1,"primary reaction preserves paid collapse")
    service_after_contact(31)
    s,t=rig(3)
    local cue_count=call("snapshot").counters.wound_cues or 0
    storage.reentrant_secondary,storage.reentrant_destroy=target(6,0),s
    local reaction_area=target(10,2)
    settled_shot(s,t,1)
    check(not s.valid,"secondary reaction removes source before wound cue")
    check((call("snapshot").counters.wound_cues or 0)==cue_count,"destroyed source creates no wound cue")
    service_after_contact(31)
    close(10000000-reaction_area.health,600,"source reaction preserves paid collapse")
    s,t=rig(1)
    local victims={target(2,0),target(3,0),target(4,0),target(5,0),target(6,0),target(14,0)}
    settled_shot(s,t,1)
    for i=1,5 do close(10000000-victims[i].health,500,"nearest axial "..i) end
    close(victims[6].health,10000000,"central cap excludes sixth candidate")
    close(10000000-t.health,500,"primary excluded from axial and area")
    s,t=rig(1); t.teleport{10,10}
    local diagonal=target(6,6); local miss=target(6,8)
    settled_shot(s,t,1)
    close(10000000-diagonal.health,500,"diagonal inclusion")
    close(miss.health,10000000,"diagonal exact corridor")
    s,t=rig(1)
    local large=target(6,3.3,"lance-qc-large"); large.orientation=0
    settled_shot(s,t,1); close(10000000-large.health,500,"large bounding box intersects despite center miss")
    large.orientation=.25
    settled_shot(s,t,2); close(10000000-large.health,500,"rotated box excludes false intersection")
    s,t=rig(1)
    large=target(7,3.3,"lance-qc-large"); large.orientation=.125
    local near={target(2,0),target(3,0),target(4,0),target(5,0),target(6,0)}
    settled_shot(s,t,1)
    for i=1,5 do close(10000000-near[i].health,500,"nearest actual corridor entry "..i) end
    close(large.health,10000000,"off-ray corner cannot consume nearer victim cap")
    s,t=rig(1); t.teleport{84,0}
    local edge=target(86,0); settled_shot(s,t,1)
    close(edge.health,10000000,"ordinary range cap")
    s.destroy{raise_destroy=true}; s=entity(NAME,{0,0},storage.force,"legendary")
    settled_shot(s,t,2); close(10000000-edge.health,500,"quality overpenetration")
    local quality_range=s.prototype.attack_parameters.range*s.quality.range_multiplier
    local beyond=target(quality_range+1,0)
    t.teleport{139,0}; close(settled_shot(s,t,3),500,"native-approved direct has no script clamp")
    close(beyond.health,10000000,"bounding-box primary does not extend secondary range")
    s,t=rig(3)
    local area=target(10,2)
    settled_shot(s,t,100)
    close(area.health,10000000,"collapse replaces immediate splash")
    check(call("snapshot").pending==1,"one collapse per shot")
    service_after_contact(129); close(area.health,10000000,"collapse not early")
    t.teleport{30,30}; s.destroy{raise_destroy=true}; level(0)
    service_after_contact(130); close(10000000-area.health,600,"fixed collapse survives source and research loss")
    check(call("snapshot").pending==0,"collapse consumed once")
    s,t=rig(3); area=target(10,2)
    settled_shot(s,t,200); storage.enemy.set_friend(storage.force,true)
    service_after_contact(230); close(area.health,10000000,"reverse friendship after firing")
    storage.enemy.set_friend(storage.force,false)
    settled_shot(s,t,231); storage.force.set_cease_fire(storage.enemy,true)
    service_after_contact(261); close(area.health,10000000,"cease-fire after firing")
    close(settled_shot(s,t,262),0,"protected primary")
    storage.force.set_cease_fire(storage.enemy,false)
    s,t=rig(4); area=target(10,2)
    for i=1,7 do settled_shot(s,t,i) end
    check(meter(s).counter==7,"testament counter seven")
    close(settled_shot(s,t,8),4000,"eighth quadruples full wound primary")
    check(meter(s).counter==0,"eighth consumed")
    service_after_contact(38); close(10000000-area.health,6200,"seven ordinary plus one testament collapse")
    for i=9,15 do settled_shot(s,t,i) end
    storage.enemy.set_friend(storage.force,true); settled_shot(s,t,16)
    check(meter(s).counter==0,"protected eighth consumed")
    storage.enemy.set_friend(storage.force,false)
    s,t=rig(4)
    for i=1,7 do settled_shot(s,t,i) end
    local axial={}
    for i=1,11 do axial[i]=target(2+i*.5,0) end
    settled_shot(s,t,8)
    for i=1,10 do close(10000000-axial[i].health,500,"testament axial cap "..i) end
    close(axial[11].health,10000000,"testament axial eleventh excluded")
    s,t=rig(4)
    for i=1,7 do settled_shot(s,t,i) end
    service_after_contact(37)
    local area_targets={}
    settled_shot(s,t,8)
    for i=1,17 do area_targets[i]=exact_target(t.position.x,t.position.y+3.2+i*.1) end
    service_after_contact(38)
    for i=1,16 do close(10000000-area_targets[i].health,1200,"testament collapse cap "..i) end
    close(area_targets[17].health,10000000,"testament collapse seventeenth excluded")
    service_after_contact(68)
    for i=1,12 do close(10000000-area_targets[i].health,2200,"testament echo shared nearest cap "..i) end
    for i=13,16 do close(10000000-area_targets[i].health,1200,"testament echo excludes farther target "..i) end
    s,t=rig(4)
    for i=1,7 do settled_shot(s,t,i) end
    service_after_contact(37)
    t.destroy(); area=target(10,2)
    settled_shot(s,nil,8,{x=10,y=0}); service_after_contact(38)
    check(meter(s).counter==0,"invalid primary consumes eighth")
    close(10000000-area.health,2000,"paid collapse survives invalid primary")
    s,t=rig(3)
    local friendly_ray=target(6,0,nil,storage.force)
    local friendly_area=target(10,2,nil,storage.force)
    local neutral_ray=target(7,0,nil,game.forces.neutral)
    settled_shot(s,t,1); service_after_contact(31)
    close(friendly_ray.health,10000000,"friendly penetration protected")
    close(friendly_area.health,10000000,"friendly collapse protected")
    close(neutral_ray.health,10000000,"neutral penetration protected")
    s,t=rig(0)
    area_targets={}
    for i=1,9 do area_targets[i]=target(10,.5+i*.05) end
    settled_shot(s,t,1)
    for i=1,8 do close(10000000-area_targets[i].health,125,"base splash nearest cap "..i) end
    close(area_targets[9].health,10000000,"base splash ninth excluded")
    s,t=rig(4); settled_shot(s,t,1)
    local owner=game.create_force("lance-qc-new-owner"); level(4,owner)
    s.force=owner
    close(settled_shot(s,t,2),500,"ownership change resets wound before next shot")
    check(meter(s).counter==1,"ownership change resets paid-shot counter")
    t.destructible=false
    close(settled_shot(s,t,3),0,"indestructible primary protected")
    t.destructible=true
    s,t=rig(0); t.destroy(); t=target(10,0,"lance-qc-resistant")
    close(settled_shot(s,t,1)+settled_shot(s,t,1),800,"separate shots preserve flat resistance")
    s,t=rig(4); settled_shot(s,t,1)
    storage.force.technologies[NAME.."-axial-rupture"].researched=false; call("sync",storage.force)
    check(call("snapshot").force_cache[storage.force.index].level==0,"capabilities require earlier upgrades")
    check(meter(s).counter==0 and meter(s).stacks==0,"loss resets meters")
    level(4); settled_shot(s,t,2)
    local clone=s.clone{position={0,8},surface=storage.surface,force=storage.force}
    check(meter(clone).counter==0,"clone starts empty")
    local before=call("snapshot").counters.status_refreshes or 0
    for _=1,100 do call("normal_research",storage.force.technologies.automation) end
    check((call("snapshot").counters.status_refreshes or 0)==before,"unrelated research does not refresh entities")
    clean()
    s,t=rig(0)
    local payload={direct_target=t,direct_target_unit_number=t.unit_number,damage_count=2}
    local job={source_unit_number=s.unit_number,force_index=storage.force.index,pending_impact=payload}
    call("legacy",{version=10,visual_queue={items={job}},active_visual_by_unit={[s.unit_number]=job}})
    close(10000000-t.health,1000,"legacy payload settles once without merging")
    call("check"); close(10000000-t.health,1000,"migration idempotence")
    s,t=rig(4)
    storage.force.set_ammo_damage_modifier(NAME,1); call("sync",storage.force)
    storage.force.reset_technology_effects()
    close(call("snapshot").force_cache[storage.force.index].direct_damage,500,"technology effects reset")
    settled_shot(s,t,1); storage.force.reset()
    check(meter(s).counter==0 and meter(s).stacks==0,"force reset clears lost capabilities")
    s,t=rig(3); area=target(10,2); settled_shot(s,t,1)
    local destination=game.create_force("lance-qc-merged"); level(3,destination)
    game.merge_forces(storage.force,destination); storage.force=destination
    service_after_contact(31); close(10000000-area.health,600,"merge transfers paid collapse attribution")
    local old_surface=storage.surface
    local doomed=game.create_surface("lance-qc-doomed",{width=32,height=32})
    doomed.request_to_generate_chunks({0,0},1); doomed.force_generate_chunk_requests()
    storage.surface=doomed
    level(4)
    s=entity(NAME,{0,0},storage.force); t=target(10,0)
    for i=1,7 do settled_shot(s,t,i) end
    service_after_contact(37)
    settled_shot(s,t,100); check(call("snapshot").pending==2,"doomed surface has first pulse and paid echo")
    game.delete_surface(doomed)
    storage.surface=old_surface
    storage.phase="surface-delete"
    log("LANCE_QC MECHANICS_COMPLETE")
    storage.completed=true
end

local function benchmark_setup()
    call("configure",{qc_enabled=not config.baseline and not config.no_counters,profiling_enabled=config.profile})
    storage.lances={}
    storage.targets={}
    if config.scene=="wide-native" or config.scene=="wide-burst" then
        level(4); storage.wide_pairs={}
        for _,p in ipairs({{-64,-64},{64,-64},{-64,64},{64,64}}) do
            local x,y=p[1],p[2]
            local s=entity(NAME,{x,y},storage.force)
            s.energy=700000000; s.active=config.scene=="wide-native"
            storage.lances[#storage.lances+1]=s
            local a=target(x+32,y-3.35,"lance-qc-precise")
            local b=target(x-32,y-3.35,"lance-qc-precise")
            storage.wide_pairs[#storage.wide_pairs+1]={a,b}
            if s.active then b.force=game.forces.neutral end
            storage.surface.create_entity{name="lance-qc-pole",position={x,y+8},force=storage.force}
            storage.surface.create_entity{name="lance-qc-power",position={x,y+12},force=storage.force}
        end
    elseif config.scene~="no-lance" then
        local n=config.scene=="direct" and 1 or 96
        if not config.baseline then level((config.scene=="dense" or config.scene=="diagonal" or config.scene=="normal-power") and 4 or 0) end
        for i=1,n do
            local x,y=-44+((i-1)%12)*8,-28+math.floor((i-1)/12)*8
            local s=entity(NAME,{x,y},storage.force)
            s.energy=700000000; s.active=config.scene=="normal-power"
            storage.lances[#storage.lances+1]=s
            if config.scene~="idle" and config.scene~="research" then
                local dy=config.scene=="diagonal" and 4 or 0
                storage.targets[#storage.targets+1]=target(x+4,y+dy)
                if config.scene=="dense" or config.scene=="normal-power" then
                    for j=1,9 do target(x+4+(j%3)*.65,y+math.floor(j/3)*.6) end
                end
            end
        end
    end
    storage.surface.create_entity{name="lance-qc-power",position={-60,-45},force=storage.force}
    storage.surface.create_entity{name="lance-qc-pole",position={0,0},force=storage.force}
    storage.benchmark_population=storage.surface.count_entities_filtered{name={"lance-qc-target","lance-qc-precise"}}
    log("LANCE_BENCH mode="..config.scene.." baseline="..tostring(config.baseline).." power="..((config.scene=="normal-power" or config.scene=="wide-native") and "shipped" or "artificial"))
end

local function visual_setup()
    storage.visual_rows={}
    for i=0,4 do
        local force=game.create_force("lance-visual-"..i); level(i,force)
        local y=(i-2)*8
        local source=entity(NAME,{-18,y},force)
        local name=i==2 and "lance-qc-behemoth-biter" or i==3 and "lance-qc-behemoth-worm-turret" or "lance-qc-biter-spawner"
        local victim=target(4,y,name)
        storage.visual_rows[#storage.visual_rows+1]={source=source,target=victim,force=force}
        rendering.draw_text{text=i==0 and "BASELINE" or {"technology-name."..NAME.."-"..upgrades[i]},
            surface=storage.surface,target={-18,y-3.5},color={1,1,1},scale=1,alignment="left"}
        if i==2 then victim.active=true; victim.commandable.set_command{type=defines.command.go_to_location,destination={9,y+2},distraction=defines.distraction.none} end
    end
end

local function capture(name, night, position, zoom)
    game.take_screenshot{surface=storage.surface,position=position or {-1,0},resolution={1600,1280},zoom=zoom or 1,
        path="lance-visual/"..config.fidelity.."-"..name..".png",daytime=night and .5 or 0,
        show_gui=false,anti_alias=true,force_render=true,hide_clouds=true,hide_fog=true}
    log("LANCE_VISUAL "..name)
end

local function visual_tick(tick)
    if tick==30 then
        for _, player in pairs(game.players) do
            player.teleport({-5,0},storage.surface)
            player.set_controller{type=defines.controllers.god}
        end
    end
    if tick==60 or tick==70 or tick==80 or tick==90 or tick==100 or tick==110 or tick==120 or tick==140 then
        for _,row in ipairs(storage.visual_rows) do shot(row.source,row.target,tick) end
    end
    if tick==61 then capture("split-day",false) end
    if tick==81 then capture("branch-day",false) end
    if tick==101 then capture("full-wound-night",true) end
    if tick==121 then
        capture("seven-day",false)
        game.auto_save("lance-counter-seven")
    end
    if tick==141 then capture("testament-day",false); capture("testament-night",true) end
    if tick==155 then capture("contraction-day",false) end
    if tick==170 then capture("impact-day",false); capture("impact-night",true) end
    if tick==280 then capture("wound-expired",false) end
    if tick==300 then log("LANCE_VISUAL COMPLETE") end
end

script.on_init(function()
    storage.surface=game.create_surface("lance-upgrade-qc",{width=256,height=256})
    storage.surface.request_to_generate_chunks({0,0},5); storage.surface.force_generate_chunk_requests()
    for _,e in pairs(storage.surface.find_entities()) do e.destroy() end
    local tiles={}
    for x=-120,120 do for y=-120,120 do tiles[#tiles+1]={name="landfill",position={x,y}} end end
    storage.surface.set_tiles(tiles)
    storage.surface.freeze_daytime=true; storage.surface.daytime=.5
    storage.force=game.create_force("lance-qc-force")
    storage.enemy=game.create_force("lance-qc-hostile")
    storage.phase=0
    if config.mode=="benchmark" then benchmark_setup() end
    if config.mode=="visual" then visual_setup() end
    if config.mode=="save" then
        storage.save_schema=call("snapshot").version
        level(4); storage.reload_source=entity(NAME,{0,0},storage.force); storage.reload_target=target(10,0)
        storage.saved_wound_first_damage=call("snapshot").force_cache[storage.force.index].wound_first_damage
        for _=1,7 do shot(storage.reload_source,storage.reload_target,game.tick) end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if config.mode=="save" then
        if config.wide_flight and event.tick==16 then
            local s,t=storage.reload_source,storage.reload_target
            storage.wide_target=target(2*s.position.x-t.position.x,2*(s.position.y-3.35)-t.position.y,"lance-qc-precise")
            shot(s,storage.wide_target,event.tick)
            storage.wide_head_due=call("latest_contact",s.unit_number).due
        elseif config.wide_flight and event.tick==17 then
            shot(storage.reload_source,storage.reload_target,event.tick)
            storage.wide_tail_due=call("latest_contact",storage.reload_source.unit_number).due
        elseif config.in_flight and event.tick==16 then shot(storage.reload_source,storage.reload_target,event.tick) end
        if event.tick==(config.wide_flight and 18 or config.in_flight and 17 or 15) and not storage.save_requested then
            storage.save_requested=true; game.server_save("lance-seven")
        end
        return
    end
    if config.mode=="reload" then
        if not storage.reload_checked then
            storage.reload_checked=true
            local s,t=storage.reload_source,storage.reload_target
            local state=call("snapshot")
            check(state.version==14 and state.presentation_revision==4,"saved lance runs schema and presentation migrations")
            if storage.wide_target then
                local other=storage.wide_target
                local head,tail=storage.wide_head_due,storage.wide_tail_due
                check(head==46 and tail==76 and call("latest_contact",s.unit_number).due==tail,
                    "angular reload preserves long reservations and cached tail")
                check(state.pending_contacts==2 and meter(s).counter==1,"angular reload preserves two paid contacts and counter")
                call("service",31)
                local p=call("cues",s.unit_number).endpoint
                local dx,dy=p.x-s.position.x,p.y-(s.position.y-3.35)
                check(dx*dx+dy*dy>100 and other.health==10000000,"serialized angular transition stays outside crystal before damage")
                local first_damage=4*(storage.saved_wound_first_damage or 600)
                call("service",head); close(10000000-other.health,first_damage,"angular saved eighth lands at original deadline")
                call("service",tail); check(call("cues",s.unit_number).queued==0,"angular saved successor retains ordered contact")
                call("service",tail+30)
                close(10000000-other.health,first_damage+3000,"angular reload preserves first and echo snapshots")
                check(call("snapshot").pending==0,"angular reload drains all linked paid work")
                log("LANCE_QC RELOAD_COMPLETE")
                return
            end
            if storage.legacy_turn_target then
                local other=storage.legacy_turn_target
                local old=call("latest_contact",s.unit_number)
                check(old.due==18 and not old.angular and old.collapse_due==48 and old.echo_due==78,
                    "actual schema13 angular migration preserves legacy contact and linked deadlines")
                call("service",14)
                local cue=call("cues",s.unit_number)
                close(cue.endpoint.x,(t.position.x+other.position.x)/2,"actual schema13 contact retains Cartesian interpolation x")
                close(cue.endpoint.y,(t.position.y+other.position.y)/2,"actual schema13 contact retains Cartesian interpolation y")
                call("service",18); close(10000000-other.health,2400,"legacy retargeted eighth retains first Wound bonus")
                local post=target(-30,0)
                shot(s,post,19)
                local fresh=call("latest_contact",s.unit_number)
                check(fresh.angular and fresh.due>27,"new shot after schema13 reload uses angular acquisition")
                call("service",78)
                close(10000000-other.health,5400,"legacy first and echo paid snapshots survive mixed new work")
                check(meter(s).counter==1,"mixed legacy/new transactions preserve paid counter")
                log("LANCE_QC RELOAD_COMPLETE")
                return
            end
            if config.in_flight then
                check(meter(s).counter==0 and meter(s).stacks==5,"in-flight eighth preserves paid counter and precontact Wound")
                check(state.pending==10 and state.pending_contacts==1,"save preserves contact plus all nine paid pulses")
                local before=t.health
                local due=storage.save_schema==14 and 24 or 18
                call("service",due-1); close(before-t.health,0,"reloaded contact is not early")
                call("service",due); close(before-t.health,4000,"reloaded pending contact keeps eighth-shot Wound context")
                call("service",storage.save_schema==14 and 44 or 38); close(before-t.health,11000,"pre-save paid pulses keep original deadlines")
                call("service",due+30); close(before-t.health,13000,"reloaded first Testament pulse retains contact-relative deadline")
                call("service",due+60); close(before-t.health,14000,"reloaded echo retains contact-relative deadline")
                check(call("snapshot").pending==0 and call("cues",s.unit_number).queued==0,"reload drains serialized paid FIFO exactly once")
                log("LANCE_QC RELOAD_COMPLETE")
                return
            end
            check(meter(s).counter==7 and meter(s).stacks==5,"counter seven and full wound survive save/load")
            check(state.pending==7,"save preserves seven paid pending collapses")
            check(call("cues",s.unit_number).mark.type=="animation","save retains valid animated wound")
            local packets=call("packets")
            check(#packets==7,"reload keeps every separate paid packet")
            local legacy=not packets[1].include_primary
            local due=packets[#packets].due
            check(meter(s).wound_tick==due-30,"reload preserves original successful-hit timestamp")
            for _,packet in ipairs(packets) do
                check(packet.damage==(legacy and 250 or 600) and packet.radius==(legacy and 3 or 4)
                    and not packet.echo_is_queued and packet.phase~="echo","reload preserves original packet snapshot")
            end
            call("check")
            check(call("snapshot").pending==7 and meter(s).counter==7,"reload migration is idempotent")
            local before=t.health
            local area=exact_target(t.position.x,t.position.y+2)
            call("service",due)
            close(before-t.health,legacy and 0 or 7000,"saved packet primary eligibility preserved")
            close(10000000-area.health,legacy and 1750 or 4200,"saved packet secondary damage preserved")
            close(settled_shot(s,t,due+1),4000,"reloaded eighth includes full hybrid wound")
            check(meter(s).counter==0 and call("snapshot").pending==2,"reloaded eighth consumes counter and prepays echo")
            call("service",due+69)
            close(10000000-area.health,(legacy and 1750 or 4200)+3000,"old and new queued rules remain distinct")
            check(call("snapshot").pending==0,"reloaded paid pulses settle exactly once")
            log("LANCE_QC RELOAD_COMPLETE")
        end
        return
    end
    if config.mode=="visual" then visual_tick(event.tick); return end
    if config.mode=="benchmark" then
        if config.scene=="wide-native" and event.tick%40==0 then
            local which=math.floor(event.tick/40)%2+1
            for _,pair in ipairs(storage.wide_pairs) do
                pair[which].force=storage.enemy; pair[3-which].force=game.forces.neutral
            end
        elseif config.scene=="wide-burst" then
            for i,source in ipairs(storage.lances) do call("shot",source,storage.wide_pairs[i][event.tick%2+1],nil,event.tick) end
        end
        if config.scene=="direct" or config.scene=="dense" or config.scene=="diagonal" then
            for i, source in ipairs(storage.lances) do call("shot",source,storage.targets[i],nil,event.tick) end
        end
        if config.scene=="research" and event.tick%60==0 then
            for _=1,100 do call("normal_research",storage.force.technologies.automation) end
            call("sync",storage.force)
        end
        if event.tick==120 then
            call("configure",{reset=true,qc_enabled=not config.baseline and not config.no_counters,profiling_enabled=config.profile})
            log("LANCE_BENCH WARMUP_COMPLETE")
        end
        if event.tick%300==0 then log("LANCE_BENCH SNAPSHOT "..helpers.table_to_json(call("snapshot"))) end
        if config.profile and event.tick==config.ticks then call("snapshot") end -- flush final measured tick
        if event.tick==config.ticks-1 then
            local population=storage.surface.count_entities_filtered{name={"lance-qc-target","lance-qc-precise"}}
            check(population==storage.benchmark_population,"benchmark target population preserved "..population)
        end
        return
    end
    if event.tick==1 and config.mode=="mechanics" then mechanics(event.tick) end
    if storage.phase=="surface-delete" and event.tick==2 then
        check(call("snapshot").pending==0,"surface deletion cancels packet")
        local s,t=hybrid_rig(4)
        for _=1,8 do shot(s,t,event.tick) end
        storage.merge_source,storage.merge_target=s,t
        local last=call("latest_contact",s.unit_number)
        storage.merge_first_due,storage.merge_echo_due=last.collapse_due,last.echo_due
        storage.phase="merge-first"
    end
    if storage.phase=="merge-first" and event.tick==storage.merge_first_due then
        check(call("snapshot").pending==1,"real dispatcher leaves one paid echo after first impacts")
        storage.merge_health=storage.merge_target.health
        local merged=game.create_force("lance-qc-hybrid-merged"); level(4,merged)
        game.merge_forces(storage.force,merged); storage.force=merged
        storage.phase="merge-await"
    end
    if storage.phase=="merge-await" and event.tick==storage.merge_first_due+1 then
        check(call("packets")[1].force_index==storage.force.index,"real force merge transfers queued echo attribution")
        storage.phase="merge-echo"
    end
    if storage.phase=="merge-echo" and event.tick==storage.merge_echo_due then
        close(storage.merge_health-storage.merge_target.health,1000,"real merged echo retains snapshot damage")
        check(call("snapshot").pending==0,"real echo consumes exact sixty-tick packet")
        local s,t=rig(3); storage.delayed_area=target(10,2); shot(s,t,event.tick)
        storage.expiring_source,storage.expiring_target=s,t
        storage.delay_due=event.tick+38; storage.phase="real-delay"
    end
    if storage.phase=="real-delay" and event.tick==storage.delay_due-30 then
        local cues=call("cues",storage.expiring_source.unit_number)
        storage.expiring_beam,storage.contact_flash,storage.contact_glow=cues.beam,cues.flash,cues.afterglow
        storage.light_start=event.tick
        storage.glow_ticks=({lean=14,standard=30,cinematic=45,maximal=90,unbounded=180})[config.fidelity]
        check(cues.flash.valid and cues.afterglow.valid,"real contact creates flash and afterglow")
    end
    if storage.light_start and event.tick==storage.light_start+4 then
        check(storage.contact_flash.valid,"cyan flash remains through fourth tick")
    end
    if storage.light_start and event.tick==storage.light_start+6 then
        check(not storage.contact_flash.valid,"five-tick cyan flash expires natively")
    end
    if storage.light_start and event.tick==storage.light_start+storage.glow_ticks+1 then
        check(not storage.contact_glow.valid,"preset afterglow expires natively")
    end
    if storage.light_start and event.tick==storage.light_start+storage.glow_ticks-1 then
        check(storage.contact_glow.valid,"preset afterglow persists through its penultimate tick")
    end
    if storage.phase=="real-delay" and event.tick==storage.delay_due-1 then
        close(storage.delayed_area.health,10000000,"central dispatcher waits until due tick")
        if config.fidelity=="lean" or config.fidelity=="standard" then
            check(not storage.expiring_beam.valid,"native beam expires without polling")
            shot(storage.expiring_source,storage.expiring_target,event.tick)
        end
    end
    if storage.phase=="real-delay" and event.tick==storage.delay_due then
        close(10000000-storage.delayed_area.health,600,"central dispatcher executes exact due tick")
        storage.phase="light-wait"
    end
    if storage.phase=="light-wait" and event.tick==storage.light_start+math.max(31,storage.glow_ticks+2) then
        local s,t=rig(0)
        s.energy=700000000; s.active=true
        storage.native_source,storage.native_target=s,t
        storage.native_energy=s.energy
        storage.phase="native"
    end
    if storage.phase=="native" and not storage.native_paid_tick and call("snapshot").pending_contacts>0 then
        storage.native_paid_tick=call("packets")[1].due-8; storage.native_source.active=false
        close(storage.native_target.health,10000000,"native energy is paid before contact damage")
    end
    if storage.phase=="native" and storage.native_target.health<10000000 then
        storage.native_source.active=false
        check(event.tick==storage.native_paid_tick+8,"native primary arrives exactly eight ticks after paid callback")
        close(10000000-storage.native_target.health,500,"native carrier emits exactly one primary")
        check(storage.native_source.energy<storage.native_energy,"native shot pays energy")
        level(0)
        local tech=storage.force.technologies[NAME.."-axial-rupture"]
        tech.researched=true; call("normal_research",tech)
        check(call("snapshot").force_cache[storage.force.index].level==1,"normal research refresh")
        for i=2,4 do storage.force.technologies[NAME.."-"..upgrades[i]].researched=true end
        storage.phase,storage.research_due="scripted-research",event.tick+2
    end
    if storage.phase=="scripted-research" and event.tick==storage.research_due then
        check(call("snapshot").force_cache[storage.force.index].level==4,"real scripted burst refresh")
        storage.force.technologies[NAME.."-axial-rupture"].researched=false
        check(call("snapshot").force_cache[storage.force.index].level==0,"real research reversal")
        clean(); level(1)
        local reach=prototypes.entity[NAME].attack_parameters.range * prototypes.quality.legendary.range_multiplier
        storage.range_source=entity(NAME,{100-reach-1,0},storage.force,"legendary")
        storage.range_target=target(100,0,"lance-qc-large"); storage.range_target.orientation=.25
        storage.range_source.energy=700000000; storage.range_source.active=true
        check(storage.range_target.position.x-storage.range_source.position.x>reach,"quality fixture center outside effective range")
        storage.phase="native-range"
    end
    if storage.phase=="native-range" and call("snapshot").pending_contacts>0 then storage.range_source.active=false end
    if storage.phase=="native-range" and storage.range_target.health<10000000 then
        storage.range_source.active=false
        close(10000000-storage.range_target.health,500,"native quality and bounding-box attack beyond center range")
        local cue=call("cues",storage.range_source.unit_number)
        check(cue.beam.valid and cue.endpoint.x>=storage.range_target.position.x,"native core beam retains approved reach beyond center range")
        storage.phase="complete"; log("LANCE_QC ALL_COMPLETE")
    end
end)
