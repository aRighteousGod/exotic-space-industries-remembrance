-- Schema14 literal-deadline and engine-beam geometry checks. Fixture-only bridge.
return function(h)
    local call,check,close,rig,target=h.call,h.check,h.close,h.rig,h.target
    local function fire(s,t,tick,p)
        call("shot",s,t,p,tick)
        return call("latest_contact",s.unit_number)
    end
    local function service(tick) call("service",tick) end
    local pivot={x=.5,y=.5-3.35}
    local function point(degrees,radius)
        local a=degrees*math.pi/180
        return {x=pivot.x+math.cos(a)*radius,y=pivot.y+math.sin(a)*radius}
    end
    local function at(degrees,radius)
        local p=point(degrees,radius or 30)
        return target(p.x,p.y,"lance-qc-precise")
    end
    local function prime(degrees,n)
        local s,t=rig(n or 0); t.destroy(); t=at(degrees)
        local p=fire(s,t,100)
        check(p.due==108 and p.first,"unknown bearing reserves eight ticks")
        service(108)
        return s,t
    end
    local function radius(p) return math.sqrt((p.x-pivot.x)^2+(p.y-pivot.y)^2) end
    for _,sample in ipairs({{0,8},{30,8},{45,8},{60,10},{90,15},{120,20},{180,30},
        {-60,10},{-90,15},{-120,20},{-180,30}}) do
        -- Exact mathematical angles use positional shots: engine entities round
        -- their positions to 1/256 tile, legitimately adding a ceil tick at60°.
        local s=rig(0); fire(s,nil,100,point(0,30)); service(108)
        local p=fire(s,nil,200,point(sample[1],40))
        local q=point(sample[1],40)
        local measured=math.atan2(q.y-pivot.y,q.x-pivot.x)*180/math.pi
        check(p.due==200+sample[2] and p.nominal==sample[2],"angular reservation "..sample[1].." due="..p.due.." nominal="..p.nominal.." measured="..string.format("%.12f",measured))
        service(p.due-1); check(call("cues",s.unit_number).queued==1,"angular contact waits for reserved deadline")
        service(p.due); check(call("cues",s.unit_number).queued==0,"angular contact resolves on deadline")
    end
    for _,start in ipairs({0,90,180,270}) do
        local s=rig(0); fire(s,nil,100,point(start,30)); service(108)
        local p=fire(s,nil,200,point(start+180,30)); service(215)
        local cue=call("cues",s.unit_number); local expected=point(start+90,30)
        close(cue.endpoint.x,expected.x,"clockwise half-turn midpoint x quadrant"..start)
        close(cue.endpoint.y,expected.y,"clockwise half-turn midpoint y quadrant"..start)
        close(radius(cue.endpoint),30,"half-turn never crosses crystal")
        local beam=cue.beam
        service(229); check(call("cues",s.unit_number).beam==beam,"long transition keeps native beam handle")
        service(p.due)
    end
    local s,t=prime(170); local other=at(-170)
    check(fire(s,other,200).due==208,"angle wrap selects short arc")
    service(204); local cue=call("cues",s.unit_number)
    close(cue.endpoint.x,pivot.x-30,"wrapped midpoint stays on outer arc")
    close(cue.endpoint.y,pivot.y,"wrapped midpoint crosses negative bearing smoothly")
    service(208)

    s,t=prime(0); other=at(170)
    local p=fire(s,other,200); check(p.due==229,"moving target starts with reserved 170-degree turn")
    service(214); local before=call("cues",s.unit_number).endpoint
    other.teleport(point(-170,30)); service(215)
    local after=call("cues",s.unit_number).endpoint
    check(after.x<before.x and after.y>pivot.y,"moving goal unwraps through opposite bearing without reversing")
    other.teleport(point(-80,45)); service(229)
    close(call("cues",s.unit_number).endpoint.x,other.position.x,"abrupt movement still reaches fixed deadline")

    s,t=prime(0); other=at(90,50); fire(s,other,200); service(205)
    cue=call("cues",s.unit_number)
    local u=(1/3)^2*(3-2/3)
    close(radius(cue.endpoint),30+20*u,"radius interpolates independently with smoothstep")
    close(math.atan2(cue.endpoint.y-pivot.y,cue.endpoint.x-pivot.x)*180/math.pi,90*u,"angular smoothstep easing")
    service(215)
    -- A presentation rebuild cannot change either the timing anchor or arc.
    call("presentation_refresh",216); t.teleport(point(180,50))
    p=fire(s,t,220); check(p.due==235,"cosmetic rebuild preserves logical timing bearing")
    service(227); check(radius(call("cues",s.unit_number).endpoint)>49,"cosmetic rebuild preserves nonradial arc")
    service(235)

    s,t=prime(0,4); other=at(180)
    local expected={230,260,262,263,264,265,266,267}
    local victims={}
    for i=1,8 do
        local victim=i%2==1 and other or t
        victims[i]=victim
        p=fire(s,victim,199+i)
        check(p.due==expected[i],"wide-turn queue full then bounded "..i)
        check(p.collapse_due==p.due+30,"collapse reserved relative to angular contact")
        if p.echo_due then check(p.echo_due==p.due+60,"echo reserved relative to angular contact") end
        check(p.compressed==(i>=3),"compression classification "..i)
    end
    -- Contact-time Wound retargets on each alternating shot, independent of payment.
    service(229); close(other.health,10000000,"wide queue has no early contact")
    service(230); close(10000000-other.health,500,"first wide contact prepares Wound")
    service(267); check(call("cues",s.unit_number).queued==0,"burst drains by final sixty-tick budget")
    check(call("snapshot").meters[s.unit_number].counter==1,"Testament counts payment not queue completion")
    service(400)

    s,t=prime(0); other=at(180)
    fire(s,other,200)
    p=fire(s,other,201); check(p.same and p.due==231,"same target follows prior paid contact without another turn")
    p=fire(s,nil,202,point(180,30)); check(not p.same and p.due==239,"position-only shot cannot use same-target shortcut")
    p=fire(s,nil,203,point(180,30)); check(not p.same and p.due==247,"two null targets remain separate acquisitions")
    service(300)

    s,t=prime(0); other=at(180)
    local prior=0
    for i=1,80 do
        p=fire(s,i%2==1 and other or t,200)
        check(p.due>=prior and p.due<=260,"same-tick saturation preserves ordered bounded reservations "..i)
        prior=p.due
    end
    service(260); check(call("cues",s.unit_number).queued==0,"same-tick saturation drains every independent packet")
    close(10000000-t.health,20500,"same-deadline shots remain separate primary packets")
    close(10000000-other.health,20000,"same-deadline alternating primary packets retained")

    s,t=prime(0,2); fire(s,t,219); service(227)
    close(10000000-t.health,1100,"119 contact ticks retains Wound")
    fire(s,t,339); service(347)
    close(10000000-t.health,1600,"120 contact ticks expires Wound with variable acquisition")
    s,t=prime(0); other=at(90)
    p=fire(s,other,200)
    other.teleport(point(180,30))
    storage.angular_reentrant={source=s,trigger=other,aim=point(0,30),tick=p.due}
    service(p.due)
    local successor=call("latest_contact",s.unit_number)
    check(successor and successor.due==p.due+30,"reentrant admission uses reached aim and retains new tail")
    check(call("cues",s.unit_number).queued==1,"resolving callback cannot discard reentrant successor")
    service(successor.due); check(call("cues",s.unit_number).queued==0,"reentrant successor drains once")

    h.clean(); call("configure",{reset=true})
    service(1000001)
    check((call("snapshot").counters.contact_target_reads or 0)==0,"angular idle has zero target reads")
    log("LANCE_ANGULAR RAW_CASES_COMPLETE")
end
