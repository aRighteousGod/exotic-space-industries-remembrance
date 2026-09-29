-- Literal-tick regression cases. Never use the inherited settled-shot adapter.
return function(h)
    local call, check, close, rig, target, level, entity = h.call,h.check,h.close,h.rig,h.target,h.level,h.entity
    local function fire(s,t,tick,p) return call("shot",s,t,p,tick) end
    local function service(tick) call("service",tick) end
    local function meter(s) return call("snapshot").meters[s.unit_number] end
    local function health(t) return t.valid and t.health or 0 end
    local function primed()
        local s,t=rig(4)
        for tick=1,7 do fire(s,t,tick) end
        service(15); service(45)
        check(meter(s).stacks==5 and meter(s).counter==7,"FIFO burst builds full Wound before Testament")
        return s,t
    end

    local s,t=rig(1)
    local secondary=target(6,0)
    fire(s,t,100)
    check(call("snapshot").pending_contacts==1 and health(t)==10000000,"paid shot queues without damage")
    service(104)
    local cue=call("cues",s.unit_number)
    local beam=cue.beam
    local origin=beam.get_beam_source().position
    close(origin.x,s.position.x,"mid-sweep crystal x")
    close(origin.y,s.position.y-3.35,"mid-sweep crystal y")
    check(beam.get_beam_target().position.x<t.position.x,"first acquisition grows from crystal")
    t.teleport{12,2}
    service(107)
    check(health(t)==10000000 and health(secondary)==10000000,"no primary or incision before eighth tick")
    service(108)
    cue=call("cues",s.unit_number)
    check(cue.beam==beam,"sweep preserves native animation handle")
    close(cue.beam.get_beam_target().position.x,t.position.x,"moving primary contact x")
    close(cue.beam.get_beam_target().position.y,t.position.y,"moving primary contact y")
    close(10000000-health(t),500,"primary resolves exactly at eighth tick")
    check(call("snapshot").active_visual_jobs==0 and cue.queued==0,"contact drains active FIFO")
    check(cue.flash.valid and cue.afterglow.valid,"contact creates bounded cyan native lights")

    fire(s,t,110); t.teleport{14,4}; service(111)
    cue=call("cues",s.unit_number)
    close(cue.endpoint.x,t.position.x,"same moving primary remains visually locked during acquisition")
    t.teleport{15,5}; service(112)
    close(call("cues",s.unit_number).endpoint.y,t.position.y,"same-target lock follows subsequent movement")
    close(10000000-health(t),500,"visual lock cannot advance the paid damage deadline")
    service(118); close(10000000-health(t),1000,"locked primary still resolves at its eighth tick")

    s,t=primed()
    local before=health(t)
    fire(s,t,100)
    local packets=call("packets")
    check(#packets==3 and packets[1].due==108 and packets[2].due==138 and packets[3].due==168,
        "contact and both pulses prepaid at immutable 8/38/68 deadlines")
    check(meter(s).counter==0,"eighth paid shot consumed before contact")
    service(107); close(before-health(t),0,"Testament primary not early")
    service(108); close(before-health(t),4000,"Testament contact includes full Wound")
    service(137); close(before-health(t),4000,"first pulse waits full contact-relative warning")
    service(138); close(before-health(t),6000,"first pulse at firing plus38")
    service(167); close(before-health(t),6000,"echo not early")
    service(168); close(before-health(t),7000,"stationary Testament sequence totals7000")
    service(168); close(before-health(t),7000,"paid packets resolve once")

    s,t=rig(3); fire(s,t,100); t.teleport{20,10}; service(108)
    packets=call("packets")
    close(packets[1].position.x,t.position.x,"collapse center finalized on moving contact")
    local contact_x,contact_y=t.position.x,t.position.y
    t.teleport{40,40}; local blast=target(contact_x,contact_y)
    service(138); close(10000000-health(blast),1000,"collapse remains at contact after target moves away")
    close(10000000-health(t),500,"primary escapes delayed blast")

    s,t=primed(); before=health(t); fire(s,t,100); s.destroy{raise_destroy=true}
    level(0); service(108); close(before-health(t),4000,"paid Wound context survives source removal and research loss")
    service(168); close(before-health(t),7000,"source removal preserves both snapshotted pulses")

    s,t=rig(2); fire(s,t,100); fire(s,t,101)
    service(108); close(10000000-health(t),500,"queued Wound first primary")
    service(109); close(10000000-health(t),1100,"queued Wound second builds on first positive contact")
    local other=target(10,8)
    fire(s,other,110); fire(s,t,111); service(118); service(126)
    close(10000000-health(other),500,"FIFO retarget starts without bonus")
    close(10000000-health(t),1600,"FIFO return resets Wound")

    s,t=rig(2); storage.force.set_ammo_damage_modifier("ei-singularity-lance",-1); call("sync",storage.force)
    fire(s,t,100); storage.force.set_ammo_damage_modifier("ei-singularity-lance",0); call("sync",storage.force)
    fire(s,t,101); service(109)
    close(10000000-health(t),500,"zero-damage queued hit cannot advance following Wound")
    check(meter(s).stacks==1 and meter(s).wound_tick==109,"only positive contact refreshes Wound")

    s,t=rig(2); fire(s,t,100); fire(s,t,101); level(0); service(109)
    close(10000000-health(t),1100,"research loss keeps paid Wound coefficients")
    check(meter(s).stacks==0 and not call("cues",s.unit_number).mark,"old Wound context cannot resurrect live meter")

    s,t=rig(3); fire(s,t,100); storage.enemy.set_friend(storage.force,true); service(108)
    close(health(t),10000000,"reverse friendship before contact protects primary")
    service(138); close(health(t),10000000,"reverse friendship also protects collapse")
    storage.enemy.set_friend(storage.force,false)

    s,t=rig(1); fire(s,t,100); service(104); local p=t.position
    t.destroy(); local survivor=target(p.x+2,p.y); service(108)
    close(10000000-health(survivor),500,"invalid primary leaves paid incision at last observed point")

    s,t=rig(1); fire(s,t,100)
    local newforce=game.create_force("lance-sweep-owner"); level(1,newforce)
    s.force=newforce; local newtarget=target(12,6); fire(s,newtarget,104)
    service(105); service(108); service(114)
    cue=call("cues",s.unit_number)
    check(call("snapshot").active_visual_jobs>0 and cue.beam.valid and cue.endpoint.y>0 and cue.endpoint.y<6
        and health(newtarget)==10000000,"new-owner pending sweep resumes before its paid contact")
    service(116)
    close(10000000-health(newtarget),500,"new-owner contact survives older-owner FIFO head")
    check(call("cues",s.unit_number).beam.valid and call("cues",s.unit_number).queued==0,"new-owner sweep reactivated and drained")

    s,t=rig(1)
    local transient=game.create_surface("lance-sweep-transient",{width=64,height=64})
    local oldsource=transient.create_entity{name="ei-singularity-lance",position={0,0},force=storage.force,raise_built=true}
    oldsource.active=false
    local oldtarget=transient.create_entity{name="lance-qc-target",position={10,0},force=storage.enemy}
    fire(oldsource,oldtarget,100)
    local clone=oldsource.clone{position={-30,0},surface=storage.surface,force=storage.force}
    check(clone and clone.valid,"clone onto surviving surface")
    clone.active=false
    fire(clone,t,101); game.delete_surface(transient)
    service(109)
    close(10000000-health(t),500,"surface deletion preserves surviving-surface contact")
    check(call("cues",clone.unit_number).queued==0,"surviving clone drains its independent FIFO")

    s,t=rig(2); fire(s,t,100); fire(s,t,101); call("presentation_refresh",103)
    service(109); check(meter(s).stacks==2,"cosmetic migration preserves an unlanded Wound context")
    fire(s,t,110); service(118)
    close(10000000-health(t),1800,"postmigration contact continues500600700 Wound sequence")

    s,t=rig(3); fire(s,t,100); service(108)
    s.force=newforce; storage.watch_damage_target=t; storage.watch_damage_cause=true
    service(138)
    check(storage.watch_damage_cause==false,"delayed damage omits a source transferred to another force")
    storage.watch_damage_target=nil

    s,t=rig(1); t.destroy(); t=target(10,0,"lance-qc-large")
    fire(s,t,100); service(104)
    local away=game.create_surface("lance-sweep-target-away",{width=64,height=64})
    t.teleport({20,0},away)
    local leftbehind=target(12,0); service(108)
    close(health(t),10000000,"primary leaving its original surface receives no direct damage")
    close(10000000-health(leftbehind),500,"surface-transferred primary leaves incision at last observed position")
    game.delete_surface(away)

    for _,sample in ipairs({{0,"0"},{999,"999"},{999.99,"999.99"},{1000,"1k"},{3648,"3.65k"},
        {999999,"1000k"},{1e6,"1M"},{1e9,"1G"},{1e12,"1.00e+12"},{1e30,"1.00e+30"}}) do
        check(call("compact",sample[1])==sample[2],"compact status number "..sample[2])
    end
    s,t=rig(4); s.destroy{raise_destroy=true}
    s=entity("ei-singularity-lance",{0,0},storage.force,"legendary")
    storage.force.set_ammo_damage_modifier("ei-singularity-lance",1.4); call("sync",storage.force)
    check(s.custom_status.label[1]=="lance-upgrades.status" and s.custom_status.label[2]=="3.65k"
        and #s.custom_status.label==2,"Legendary/full-upgrade screenshot status is one compact field")
    s.custom_status={diode=defines.entity_status_diode.green,label="old overflowing status"}; call("check")
    check(s.custom_status.label[2]=="3.65k","configuration refresh replaces old status without research change")
    storage.force.set_ammo_damage_modifier("ei-singularity-lance",0); call("sync",storage.force)
    h.clean(); call("configure",{reset=true})
    call("unrelated_effect",1000001)
    service(1000001)
    check((call("snapshot").counters.contact_target_reads or 0)==0,"idle service reads no targets")
    check((call("snapshot").counters.shots or 0)==0 and (call("snapshot").counters.invalid_events or 0)==0,
        "unrelated effect returns before lance transaction or entity validation")
    log("LANCE_SWEEP RAW_CASES_COMPLETE")
end
