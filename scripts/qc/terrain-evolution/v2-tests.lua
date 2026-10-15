local model={}
local function budget() return {candidates=32,writes=4,searches=1,samples=2,histories=4,events=4,used_candidates=0,used_searches=0,used_writes=0,used_events=0,batches={},positions={}} end
local function prepare(surface,x,y)
    surface.request_to_generate_chunks({x,y},3);surface.force_generate_chunk_requests()
    for _,e in ipairs(surface.find_entities_filtered{area={{x-72,y-72},{x+72,y+72}}}) do if e.type~="character" then e.destroy() end end
    local tiles={};for dx=-64,64 do for dy=-64,64 do tiles[#tiles+1]={name="grass-1",position={x+dx,y+dy}} end end
    surface.set_tiles(tiles,false,false,false,true)
end
function model.step(ctx,phase,tick)
    local cases={};local function check(name,pass,detail) cases[name]={pass=not not pass,detail=detail} end
    local root=storage.ei.terrain_evolution;local s=game.surfaces.nauvis;local entry=root.surfaces[s.index]
    local w=root.work
    if phase==0 then
        prepare(s,4096,2048)
        for _,name in ipairs{"degradation","tree_stress","tree_regrowth","aging","rot","flood","drought","cliffs","seasonal_ecology"} do ctx.terrain.set_override(s,name,false,tick) end
        ctx.terrain.set_override(s,"wildfire","off",tick)
        ctx.terrain.set_override(s,"periodic_mining_probability",1,tick)
        ctx.terrain.set_override(s,"mining_probability",1,tick)
        ctx.terrain.set_override(s,"protection_buffer",0,tick)
        local resource_name
        for name,p in pairs(prototypes.entity) do if p.type=="resource" and not p.infinite_resource and not p.mineable_properties.required_fluid and prototypes.entity["ei-burner-quarry"].resource_categories[p.resource_category] then resource_name=name;break end end
        assert(resource_name,"No native finite quarry resource")
        storage.ecology_v2_fixture={drills={},resource=s.create_entity{name=resource_name,position={4106.5,2048.5},amount=100000},start=tick}
        local f=storage.ecology_v2_fixture
        for i,name in ipairs(ctx.policy.drills) do
            local drill=assert(s.create_entity{name=name,position={4096+(i-1)*24,2048},force="player",raise_built=true})
            f.drills[i]=drill
            check("event-registers-"..name,w.drills[drill.unit_number]~=nil)
            local registration=w.drills[drill.unit_number].registration;local deadline=w.drills[drill.unit_number].next_tick
            script.raise_script_built{entity=drill}
            check("duplicate-keeps-deadline-"..name,w.drills[drill.unit_number].registration==registration and w.drills[drill.unit_number].next_tick==deadline)
            if name=="ei-burner-quarry" then
                f.working=drill
                f.chest=s.create_entity{name="iron-chest",position=drill.drop_position,force="player"}
                assert(drill.burner.inventory.insert{name="coal",count=40}>0)
            else drill.active=false end
        end
        check("all-four-cached",w.drill_count>=4)
        local big=f.drills[4]
        f.clone=assert(big.clone{position={4168,2072},surface=s})
        check("native-clone-event-registers",w.drills[f.clone.unit_number]~=nil)
        f.clone_id=f.clone.unit_number;f.clone.destroy()
        check("registry-global-cap-fixed",w.drill_count<=4096)
    elseif phase==1 then
        local f=storage.ecology_v2_fixture
        check("registered-destruction-retires-silent-destroy",not w.drills[f.clone_id])
        local drill=f.working
        check("native-quarry-working",drill.status==defines.entity_status.working and drill.mining_target and drill.mining_target.valid,{status=drill.status,target=drill.mining_target and drill.mining_target.name})
        local before=#root.pending.items;local searches=0;local calls=0
        for _,r in pairs(w.drills) do r.next_tick=tick;r.enable_epoch=entry.drill_epoch end
        for _=1,8 do local b=budget();ctx.work.service_drills(root,b,tick,function() return 1 end,function(r,surface,position,now,trigger) calls=calls+1;check("working-trigger-distinct",trigger=="working");ctx.terrain.enqueue_scar(surface,position,"mining",now,{trigger=trigger}) end);searches=searches+b.used_searches;check("cached-check-candidate-cap",b.used_candidates<=4) end
        check("working-drill-periodic-opportunity",calls==1)
        check("idle-drills-stay-cached",w.drill_count>=4)
        check("cached-check-no-entity-search",searches==0)
        check("working-scar-request-admitted",#root.pending.items>before)
        local accepted
        for _,r in ipairs(root.pending.items) do if r.cause=="mining" then accepted=r;break end end
        assert(accepted,"No accepted mining request");f.accepted=accepted
        ctx.terrain.set_override(s,"active",false,tick)
        local offset=accepted.offset
        ctx.terrain._qc.service_events(root,budget(),tick+10000000)
        check("disabled-surface-retains-old-accepted-request",root.pending.items[root.pending.index[accepted.id]]==accepted and accepted.offset==offset)
        calls=0;ctx.work.service_drills(root,budget(),tick+10000000,function() return 1 end,function() calls=calls+1 end)
        check("disabled-surface-does-no-periodic-check",calls==0)
        local count=#root.pending.items;check("disabled-surface-rejects-new-scar",not ctx.terrain.enqueue_scar(s,{x=4140,y=2060},"mining",tick) and #root.pending.items==count)
        ctx.terrain.set_override(s,"active",true,tick)
        local b=budget();ctx.terrain._qc.service_events(root,b,tick+10000001);ctx.terrain._qc.commit(root,b)
        check("reenabled-old-request-progresses",accepted.offset>offset or not root.pending.index[accepted.id])
        f.destroy_id=f.drills[2].unit_number;f.drills[2].destroy{raise_destroy=true}
    elseif phase==2 then
        local f=storage.ecology_v2_fixture
        check("committed-script-removal-retires-drill",not w.drills[f.destroy_id])
        local drill=f.working;local id=drill.unit_number;local registration=w.drills[id].registration
        local moved=drill.teleport({4096,2072},nil,true)
        check("teleport-keeps-single-membership",moved and w.drills[id] and w.drills[id].registration==registration)
        local ghost=s.create_entity{name="entity-ghost",inner_name="ei-electric-quarry",position={4120,2072},force="player"}
        local _,revived=ghost.revive{raise_revive=true}
        check("revival-registers-native-drill",revived and w.drills[revived.unit_number])
        local infinite
        for name,p in pairs(prototypes.entity) do if p.type=="resource" and p.infinite_resource then infinite=s.create_entity{name=name,position={4150,2050},amount=math.max(10000,p.minimum_resource_amount or 0)};break end end
        if infinite then local count=#root.pending.items;ctx.terrain.on_resource_depleted{entity=infinite,tick=tick};check("infinite-depletion-is-excluded",#root.pending.items==count);infinite.destroy() end
        local gleba=game.planets.gleba.surface or game.planets.gleba.create_surface()
        gleba.request_to_generate_chunks({0,0},0);gleba.force_generate_chunk_requests()
        local ge=root.surfaces[gleba.index];local r=ctx.work.observe(root,ge,0,0,"recovery",tick)
        for _=1,64 do ctx.terrain._qc.sample_observation(root,budget(),tick) end
        check("Gleba-spores-not-clean-zero",r and r.sample_tick and r.pollution==nil and r.clean_since==nil and r.dirty_since==nil)
        check("bounded-live-registry",w.drill_count<=4096)
    elseif phase==3 then
        check("native-default-periodic-mining-enabled",settings.global["ei-terrain-periodic-mining-scars"].value)
        check("native-default-mining-probability",settings.global["ei-terrain-periodic-mining-probability"].value==0.1)
        check("native-default-contained-fire",settings.global["ei-terrain-wildfire"].value=="contained")
        check("native-default-lean-processing",root.config.performance=="lean")
        check("native-operation-caps",root.last_service.candidates<=32 and root.last_service.histories<=4 and root.last_service.writes<=4 and root.last_service.searches<=1)
        check("query-rotation-is-V2",type(root.last_service.query_lane)=="string" or root.last_service.search_allowance==0)
    end
    return cases
end
return model
