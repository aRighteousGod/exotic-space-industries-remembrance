local config = require("test-config")
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
local function rig(n)
    clean(); level(n)
    return entity(NAME,{0,0},storage.force), target(10,0)
end
local function meter(source) return call("snapshot").meters[source.unit_number] end

-- Fixture-only synchronous damage reactions reproduce entities disappearing
-- between primary resolution and visual presentation. Never enabled in benchmarks.
if config.mode == "mechanics" then
    script.on_event(defines.events.on_entity_damaged, function(event)
        if event.entity == storage.reentrant_secondary then
            storage.reentrant_secondary = nil
            local victim = storage.reentrant_destroy
            storage.reentrant_destroy = nil
            if victim and victim.valid then victim.destroy{raise_destroy=true} end
        end
    end)
end

local function mechanics()
    call("configure",{qc_enabled=true,profiling_enabled=false})
    local s,t = rig(0)
    local secondary=target(10,1)
    local friend=target(10,-1,nil,storage.force)
    local neutral=target(11,0,nil,game.forces.neutral)
    close(shot(s,t,1),500,"base primary")
    close(10000000-secondary.health,125,"guaranteed base splash")
    close(friend.health,10000000,"same-force protected")
    close(neutral.health,10000000,"neutral protected")
    storage.force.set_ammo_damage_modifier(NAME,1); call("sync",storage.force)
    close(shot(s,t,2),1000,"category multiplier")
    close(10000000-secondary.health,375,"splash multiplier")
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)
    s,t=rig(2)
    for index,value in ipairs({500,550,600,650,700,750,750}) do close(shot(s,t,index),value,"wound ramp "..index) end
    close(shot(s,t,126),750,"wound below timeout")
    close(shot(s,t,246),500,"wound exact timeout")
    local other=target(20,4)
    close(shot(s,other,247),500,"retarget resets")
    close(shot(s,t,248),500,"return target resets")
    local immune=target(20,10,"lance-qc-immune")
    close(shot(s,immune,249),0,"immune primary")
    check(meter(s).stacks==0,"zero damage builds no wound")
    local sec=target(7,0)
    shot(s,t,250)
    close(10000000-sec.health,250,"secondary has no wound multiplier")
    s,t=rig(2); shot(s,t,1)
    storage.force.set_ammo_damage_modifier(NAME,-1); call("sync",storage.force)
    close(shot(s,t,2),0,"zero multiplier primary")
    check(meter(s).stacks==1 and meter(s).wound_tick==1,"zero damage neither builds nor refreshes existing wound")
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)
    close(shot(s,t,3),550,"positive hit resumes unexpired wound")
    storage.force.set_ammo_damage_modifier(NAME,-1); call("sync",storage.force); shot(s,t,100)
    storage.force.set_ammo_damage_modifier(NAME,0); call("sync",storage.force)
    close(shot(s,t,123),500,"zero hit does not postpone exact expiry")
    s,t=rig(3)
    storage.reentrant_secondary,storage.reentrant_destroy=target(6,0),t
    shot(s,t,1)
    check(not t.valid and meter(s).stacks==0,"secondary reaction removes primary before wound cue")
    check(call("snapshot").pending==1,"primary reaction preserves paid collapse")
    call("service",31)
    s,t=rig(3)
    local cue_count=call("snapshot").counters.wound_cues or 0
    storage.reentrant_secondary,storage.reentrant_destroy=target(6,0),s
    local reaction_area=target(10,2)
    shot(s,t,1)
    check(not s.valid,"secondary reaction removes source before wound cue")
    check((call("snapshot").counters.wound_cues or 0)==cue_count,"destroyed source creates no wound cue")
    call("service",31)
    close(10000000-reaction_area.health,250,"source reaction preserves paid collapse")
    s,t=rig(1)
    local victims={target(4,0),target(6,.7),target(12,0),target(14,0),target(23,0),target(8,1)}
    shot(s,t,1)
    for i=1,3 do close(10000000-victims[i].health,250,"nearest axial "..i) end
    for i=4,6 do close(victims[i].health,10000000,"axial cap/width/endpoint "..i) end
    close(10000000-t.health,500,"primary excluded from axial and area")
    s,t=rig(1); t.teleport{10,10}
    local diagonal=target(6,6); local miss=target(6,8)
    shot(s,t,1)
    close(10000000-diagonal.health,250,"diagonal inclusion")
    close(miss.health,10000000,"diagonal exact corridor")
    s,t=rig(1)
    local large=target(6,3.3,"lance-qc-large"); large.orientation=0
    shot(s,t,1); close(10000000-large.health,250,"large bounding box intersects despite center miss")
    large.orientation=.25
    shot(s,t,2); close(10000000-large.health,250,"rotated box excludes false intersection")
    s,t=rig(1)
    large=target(5,3.3,"lance-qc-large"); large.orientation=.125
    local near={target(2,0),target(3,0),target(4,0)}
    shot(s,t,1)
    for i=1,3 do close(10000000-near[i].health,250,"nearest actual corridor entry "..i) end
    close(large.health,10000000,"off-ray corner cannot consume nearer victim cap")
    s,t=rig(1); t.teleport{84,0}
    local edge=target(86,0); shot(s,t,1)
    close(edge.health,10000000,"ordinary range cap")
    s.destroy{raise_destroy=true}; s=entity(NAME,{0,0},storage.force,"legendary")
    shot(s,t,2); close(10000000-edge.health,250,"quality overpenetration")
    local quality_range=s.prototype.attack_parameters.range*s.quality.range_multiplier
    local beyond=target(quality_range+1,0)
    t.teleport{139,0}; close(shot(s,t,3),500,"native-approved direct has no script clamp")
    close(beyond.health,10000000,"bounding-box primary does not extend secondary range")
    s,t=rig(3)
    local area=target(10,2)
    shot(s,t,100)
    close(area.health,10000000,"collapse replaces immediate splash")
    check(call("snapshot").pending==1,"one collapse per shot")
    call("service",129); close(area.health,10000000,"collapse not early")
    t.teleport{30,30}; s.destroy{raise_destroy=true}; level(0)
    call("service",130); close(10000000-area.health,250,"fixed collapse survives source and research loss")
    check(call("snapshot").pending==0,"collapse consumed once")
    s,t=rig(3); area=target(10,2)
    shot(s,t,200); storage.enemy.set_friend(storage.force,true)
    call("service",230); close(area.health,10000000,"reverse friendship after firing")
    storage.enemy.set_friend(storage.force,false)
    shot(s,t,231); storage.force.set_cease_fire(storage.enemy,true)
    call("service",261); close(area.health,10000000,"cease-fire after firing")
    close(shot(s,t,262),0,"protected primary")
    storage.force.set_cease_fire(storage.enemy,false)
    s,t=rig(4); area=target(10,2)
    for i=1,7 do shot(s,t,i) end
    check(meter(s).counter==7,"testament counter seven")
    close(shot(s,t,8),1500,"eighth doubles full wound primary")
    check(meter(s).counter==0,"eighth consumed")
    call("service",38); close(10000000-area.health,2250,"seven ordinary plus one testament collapse")
    for i=9,15 do shot(s,t,i) end
    storage.enemy.set_friend(storage.force,true); shot(s,t,16)
    check(meter(s).counter==0,"protected eighth consumed")
    storage.enemy.set_friend(storage.force,false)
    s,t=rig(4)
    for i=1,7 do shot(s,t,i) end
    local axial={}
    for i=1,7 do axial[i]=target(1+i,0) end
    shot(s,t,8)
    for i=1,6 do close(10000000-axial[i].health,250,"testament axial cap "..i) end
    close(axial[7].health,10000000,"testament axial seventh excluded")
    s,t=rig(4)
    for i=1,7 do shot(s,t,i) end
    call("service",37)
    local area_targets={}
    for i=1,13 do area_targets[i]=target(10,1+i*.1) end
    shot(s,t,8); call("service",38)
    for i=1,12 do close(10000000-area_targets[i].health,500,"testament collapse cap "..i) end
    close(area_targets[13].health,10000000,"testament collapse thirteenth excluded")
    s,t=rig(4)
    for i=1,7 do shot(s,t,i) end
    call("service",37)
    t.destroy(); area=target(10,2)
    shot(s,nil,8,{x=10,y=0}); call("service",38)
    check(meter(s).counter==0,"invalid primary consumes eighth")
    close(10000000-area.health,500,"paid collapse survives invalid primary")
    s,t=rig(3)
    local friendly_ray=target(6,0,nil,storage.force)
    local friendly_area=target(10,2,nil,storage.force)
    local neutral_ray=target(7,0,nil,game.forces.neutral)
    shot(s,t,1); call("service",31)
    close(friendly_ray.health,10000000,"friendly penetration protected")
    close(friendly_area.health,10000000,"friendly collapse protected")
    close(neutral_ray.health,10000000,"neutral penetration protected")
    s,t=rig(0)
    area_targets={}
    for i=1,9 do area_targets[i]=target(10,.5+i*.05) end
    shot(s,t,1)
    for i=1,8 do close(10000000-area_targets[i].health,125,"base splash nearest cap "..i) end
    close(area_targets[9].health,10000000,"base splash ninth excluded")
    s,t=rig(4); shot(s,t,1)
    local owner=game.create_force("lance-qc-new-owner"); level(4,owner)
    s.force=owner
    close(shot(s,t,2),500,"ownership change resets wound before next shot")
    check(meter(s).counter==1,"ownership change resets paid-shot counter")
    t.destructible=false
    close(shot(s,t,3),0,"indestructible primary protected")
    t.destructible=true
    s,t=rig(0); t.destroy(); t=target(10,0,"lance-qc-resistant")
    close(shot(s,t,1)+shot(s,t,1),800,"separate shots preserve flat resistance")
    s,t=rig(4); shot(s,t,1)
    storage.force.technologies[NAME.."-axial-rupture"].researched=false; call("sync",storage.force)
    check(call("snapshot").force_cache[storage.force.index].level==0,"capabilities require earlier upgrades")
    check(meter(s).counter==0 and meter(s).stacks==0,"loss resets meters")
    level(4); shot(s,t,2)
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
    shot(s,t,1); storage.force.reset()
    check(meter(s).counter==0 and meter(s).stacks==0,"force reset clears lost capabilities")
    s,t=rig(3); area=target(10,2); shot(s,t,1)
    local destination=game.create_force("lance-qc-merged"); level(3,destination)
    game.merge_forces(storage.force,destination); storage.force=destination
    call("service",31); close(10000000-area.health,250,"merge transfers paid collapse attribution")
    local old_surface=storage.surface
    local doomed=game.create_surface("lance-qc-doomed",{width=32,height=32})
    doomed.request_to_generate_chunks({0,0},1); doomed.force_generate_chunk_requests()
    storage.surface=doomed
    s=entity(NAME,{0,0},storage.force); t=target(10,0)
    shot(s,t,1); check(call("snapshot").pending==1,"doomed surface has packet")
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
    if config.scene~="no-lance" then
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
    log("LANCE_BENCH mode="..config.scene.." baseline="..tostring(config.baseline).." power="..(config.scene=="normal-power" and "shipped" or "artificial"))
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
        level(4); storage.reload_source=entity(NAME,{0,0},storage.force); storage.reload_target=target(10,0)
        for _=1,7 do shot(storage.reload_source,storage.reload_target,game.tick) end
    end
end)
script.on_event(defines.events.on_tick,function(event)
    if config.mode=="save" then
        if not storage.save_requested then storage.save_requested=true; game.server_save("lance-seven") end
        return
    end
    if config.mode=="reload" then
        if not storage.reload_checked then
            storage.reload_checked=true
            check(meter(storage.reload_source).counter==7,"counter seven survives save/load")
            close(shot(storage.reload_source,storage.reload_target,event.tick),1500,"reloaded eighth includes wound")
            check(meter(storage.reload_source).counter==0,"reloaded eighth consumed once")
            log("LANCE_QC RELOAD_COMPLETE")
        end
        return
    end
    if config.mode=="visual" then visual_tick(event.tick); return end
    if config.mode=="benchmark" then
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
        return
    end
    if event.tick==1 and config.mode=="mechanics" then mechanics() end
    if storage.phase=="surface-delete" and event.tick==2 then
        check(call("snapshot").pending==0,"surface deletion cancels packet")
        local s,t=rig(3); storage.delayed_area=target(10,2); shot(s,t,event.tick)
        storage.delay_due=event.tick+30; storage.phase="real-delay"
    end
    if storage.phase=="real-delay" and event.tick==storage.delay_due-1 then close(storage.delayed_area.health,10000000,"central dispatcher waits until due tick") end
    if storage.phase=="real-delay" and event.tick==storage.delay_due then
        close(10000000-storage.delayed_area.health,250,"central dispatcher executes exact due tick")
        local s,t=rig(0)
        s.energy=700000000; s.active=true
        storage.native_source,storage.native_target=s,t
        storage.native_energy=s.energy
        storage.phase="native"
    end
    if storage.phase=="native" and storage.native_target.health<10000000 then
        storage.native_source.active=false
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
    if storage.phase=="native-range" and storage.range_target.health<10000000 then
        storage.range_source.active=false
        close(10000000-storage.range_target.health,500,"native quality and bounding-box attack beyond center range")
        storage.phase="complete"; log("LANCE_QC ALL_COMPLETE")
    end
end)
