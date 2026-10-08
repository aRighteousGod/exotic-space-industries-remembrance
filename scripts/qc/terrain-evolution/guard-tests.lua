-- Native guard fixture: isolated profile only, imported into the staged ESIR state.
-- The private export points to production functions; no shipping test interface.
local tests={}
local function same_daylight(a,b)
    for _,key in ipairs({"dusk","evening","morning","dawn"}) do if math.abs(a[key]-b[key])>1e-8 then return false end end
    return true
end
local function same_path(actual,expected)
    if #actual~=#expected then return false end
    for i,value in ipairs(expected) do if actual[i]~=value then return false end end
    return true
end
function tests.run(terrain,calendar,vat)
    assert(script.active_mods["zzz-esir-terrain-qc"],"Disposable terrain QC profile required")
    local qc=assert(terrain._qc,"Stage the private production-function export first")
    local results={}
    local function check(name,pass,detail) results[name]={pass=pass==true,detail=detail} end
    local original=storage.ei.terrain_evolution
    local original_vat=storage.ei.auric_inoculation_vat
    local surface=game.surfaces.nauvis
    local gleba=game.planets.gleba.create_surface()
    local saved_daylight={}
    for _,s in pairs(game.surfaces) do saved_daylight[#saved_daylight+1]={surface=s,parameters=s.daytime_parameters,freeze=s.freeze_daytime,always=s.always_day} end
    local tick=game.tick+1000
    local root,entry
    local deferred=false
    local created={}
    local seeded_claims={}
    local function budget()
        return {candidates=32,writes=8,searches=4,samples=4,events=8,histories=16,
            used_candidates=0,used_writes=0,used_searches=0,used_events=0,batches={},positions={}}
    end
    local function fresh(target)
        target=target or surface
        storage.ei.terrain_evolution=nil;terrain.initialize(tick)
        root=storage.ei.terrain_evolution;entry=root.surfaces[target.index]
        root.surface_order={target.index};root.surface_registered={[target.index]=1};root.surface_cursor=1;root.enabled_surfaces=1
        root.config.cold_chunks=0;root.config.enabled=true;root.compatibility=nil
        for index,e in pairs(root.surfaces) do
            local c=e.config;c.enabled=index==target.index
            c.seasonal_daylight=false;c.seasonal_ecology=false;c.degradation=false
            c.tree_stress=false;c.tree_regrowth=false;c.aging=false;c.rot=false
            c.flood=false;c.drought=false;c.cliffs=false;c.blood=false;c.wildfire="off"
            c.recovery=false;c.mining_scars=true;c.mining_recovery=false
            c.protection_buffer=0;c.intensity_multiplier=1;c.max_depth=32
            c.clean_seconds=1;c.recovery_seconds=1;c.flood_probability=1;c.drought_probability=1
        end
        target.clear_pollution()
        return root,entry
    end
    local function patch(target,x,y,name,radius)
        radius=radius or 12
        target.request_to_generate_chunks({x=x,y=y},math.ceil(radius/32)+1);target.force_generate_chunk_requests()
        for _,e in ipairs(target.find_entities_filtered{area={{x-radius-12,y-radius-12},{x+radius+12,y+radius+12}}}) do
            if e.valid and e.type~="character" then e.destroy() end
        end
        local tiles={}
        for dx=-radius,radius do for dy=-radius,radius do tiles[#tiles+1]={name=name,position={x+dx,y+dy}} end end
        target.set_tiles(tiles,false,false,false,true)
    end
    local function entity(target,name,x,y)
        local e=target.create_entity{name=name,position={x=x+.5,y=y+.5},force="player"}
        assert(e,"Native fixture could not create "..name)
        created[#created+1]=e;return e
    end
    local function history(target,x,y)
        local index=root.history.index[target.index..":"..x..":"..y]
        return index and root.history.items[index]
    end
    local function change(target,x,y,cause,to,recover)
        tick=tick+1
        local b=budget()
        local changed=qc.propose(root,b,target,x,y,cause,tick,to,recover)
        qc.commit(root,b)
        return changed,b
    end
    local function entity_action(target,x,y,cause,extra)
        tick=tick+1
        local result
        for _=1,3 do
            result=qc.entity_event(root,budget(),{surface=target,x=x,y=y,cause=cause,extra=extra or {}},tick)
            if result~=nil then break end
        end
        return result
    end
    local function blood(target,x,y)
        entry.config.blood=true
        tick=tick+1;assert(terrain.enqueue_scar(target,{x=x,y=y},"blood",tick))
        for _=1,12 do tick=tick+1;local b=budget();qc.service_events(root,b,tick);qc.commit(root,b) end
    end
    local function recover_step()
        tick=tick+601
        local b=budget();b.writes=1
        qc.recover_tiles(root,b,tick);qc.commit(root,b)
        return b.used_writes
    end
    local function drain_recovery(max)
        entry.config.recovery=true
        for _=1,max or 20 do recover_step() end
    end
    local ok,message=pcall(function()
        -- Real native cultivated plant vs allowed natural tree occupancy.
        local x,y=4096,4096
        fresh(gleba);patch(gleba,x,y,"highland-dark-rock")
        local plant=entity(gleba,"yumako-tree",x,y)
        check("cultivated-yumako-native-type",plant.type=="plant" or plant.type=="tree",plant.type)
        check("cultivated-yumako-protects-ground",change(gleba,x,y,"thermal")==false
            and gleba.get_tile(x,y).name=="highland-dark-rock" and not history(gleba,x,y))
        plant.destroy()
        check("cultivated-cleared-control-can-degrade",change(gleba,x,y,"thermal")==true)
        fresh(gleba);patch(gleba,x+64,y,"highland-dark-rock")
        local jelly=entity(gleba,"jellystem",x+64,y)
        check("cultivated-jellystem-protects-ground",change(gleba,x+64,y,"thermal")==false
            and gleba.get_tile(x+64,y).name=="highland-dark-rock")
        jelly.destroy()
        fresh();patch(surface,x,y,"grass-1")
        local tree=entity(surface,"tree-01",x,y)
        check("natural-tree-allows-soil-control",change(surface,x,y,"thermal")==true and tree.valid)
        tree.destroy()

        -- Claim map is seeded with a native vat unit, then the actual pure owner probe is exercised.
        -- This tests the integration boundary, not the vat's independent basin-discovery lifecycle.
        fresh(gleba);patch(gleba,x+128,y,"highland-dark-rock",56)
        local v=entity(gleba,"ei-auric-inoculation-vat",x+176,y)
        assert(original_vat and original_vat.claims_by_tile,"Native vat runtime must be initialized")
        local claim_key=gleba.index..":"..(x+128)..":"..y
        seeded_claims[claim_key]={value=original_vat.claims_by_tile[claim_key]}
        original_vat.claims_by_tile[claim_key]=v.unit_number
        check("auric-native-owner-probe",vat.is_terrain_claimed(gleba.index,x+128,y))
        check("auric-claim-protects-ground",change(gleba,x+128,y,"thermal")==false
            and gleba.get_tile(x+128,y).name=="highland-dark-rock" and #root.history.items==0)
        original_vat.claims_by_tile[claim_key]=nil
        check("auric-released-control-can-degrade",change(gleba,x+128,y,"thermal")==true)
        storage.ei.auric_inoculation_vat=original_vat;v.destroy()

        -- The exact three-step path must restore in reverse, one write at a time.
        fresh();patch(surface,x+256,y,"grass-1")
        local px=x+256
        for _,name in ipairs({"grass-3","grass-4","dirt-4"}) do
            check("multistep-degrades-to-"..name,change(surface,px,y,"thermal")==true
                and surface.get_tile(px,y).name==name)
        end
        check("multistep-stores-exact-path",same_path(history(surface,px,y).path,{"grass-1","grass-3","grass-4"}))
        entry.config.recovery=true
        check("multistep-clean-dwell-first",recover_step()==0)
        for _,name in ipairs({"grass-4","grass-3","grass-1"}) do
            check("multistep-recovers-to-"..name,recover_step()==1 and surface.get_tile(px,y).name==name)
        end
        check("multistep-frees-history",#root.history.items==0)

        -- Permanent mining supersedes older ecology; opt-in recovery rebases at pre-mining terrain.
        for _,recover_mining in ipairs({false,true}) do
            fresh();patch(surface,x+320,y,"grass-1")
            local mx=x+320;entry.config.mining_recovery=recover_mining
            change(surface,mx,y,"thermal");change(surface,mx,y,"thermal")
            check((recover_mining and "rebase" or "permanent").."-mining-applies",change(surface,mx,y,"mining")==true)
            local h=history(surface,mx,y)
            if recover_mining then
                check("mining-rebases-pre-mining-tile",h and h.origin=="grass-4" and h.cause=="mining"
                    and same_path(h.path,{"grass-4"}))
                drain_recovery(4)
                check("mining-recovery-stops-at-rebased-tile",surface.get_tile(mx,y).name=="grass-4" and not history(surface,mx,y))
            else
                check("default-mining-removes-ecology-history",h==nil)
                drain_recovery(4)
                check("default-mining-remains-permanent",surface.get_tile(mx,y).name=="dirt-4" and #root.history.items==0)
                entry.config.recovery=false
                check("post-mining-ecology-gets-new-baseline",change(surface,mx,y,"thermal")==true
                    and history(surface,mx,y).origin=="dirt-4")
                drain_recovery(4)
                check("post-mining-ecology-preserves-permanent-scar",surface.get_tile(mx,y).name=="dirt-4")
            end
        end
        -- Explicit mining recovery remains authoritative over optional blood healing.
        fresh();patch(surface,x+352,y,"grass-1");entry.config.mining_recovery=true
        assert(change(surface,x+352,y,"mining"))
        local mining_path=history(surface,x+352,y)
        entry.config.mining_recovery=false;blood(surface,x+352,y)
        check("blood-respects-disabled-mining-recovery",surface.get_tile(x+352,y).name=="grass-3"
            and history(surface,x+352,y)==mining_path and same_path(mining_path.path,{"grass-1"}))
        entry.config.mining_recovery=true;blood(surface,x+352,y)
        check("blood-resumes-reenabled-mining-recovery",surface.get_tile(x+352,y).name=="grass-1"
            and not history(surface,x+352,y))
        -- Regression: replacing a full ecological path must not inherit its old depth debt.
        for _,recover_mining in ipairs({false,true}) do
            fresh();patch(surface,x+384,y,"grass-1")
            entry.config.max_depth=1;entry.config.mining_recovery=recover_mining
            change(surface,x+384,y,"thermal")
            check((recover_mining and "rebased" or "permanent").."-mining-takes-over-at-depth-cap",
                change(surface,x+384,y,"mining")==true)
        end

        -- Lowering capacity preserves committed records and refuses new obligations until recovery frees room.
        fresh();patch(surface,x+448,y,"grass-1")
        root.config.tile_history_cap=3
        for dx=0,2 do change(surface,x+448+dx,y,"thermal") end
        root.config.tile_history_cap=1
        check("reduced-cap-keeps-existing-records",#root.history.items==3)
        check("reduced-cap-refuses-new-history",change(surface,x+452,y,"thermal")==false
            and surface.get_tile(x+452,y).name=="grass-1" and #root.history.items==3)
        check("reduced-cap-allows-existing-path",change(surface,x+448,y,"thermal")==true
            and #root.history.items==3 and #history(surface,x+448,y).path==2)
        drain_recovery(16)
        check("reduced-cap-recovers-all-records",#root.history.items==0
            and surface.get_tile(x+448,y).name=="grass-1" and surface.get_tile(x+449,y).name=="grass-1"
            and surface.get_tile(x+450,y).name=="grass-1")
        check("reduced-cap-resumes-admission",change(surface,x+452,y,"thermal")==true and #root.history.items==1)
        root.config.active_cap=3
        for dx=0,2 do
            local ax=math.floor((x+448)/32)+dx
            surface.request_to_generate_chunks({x=ax*32,y=y},0);surface.force_generate_chunk_requests()
            qc.active(root,surface,ax,math.floor(y/32),tick)
        end
        root.config.active_cap=1
        check("reduced-active-cap-refuses-growth",qc.active(root,surface,math.floor((x+448)/32)+3,math.floor(y/32),tick)==nil
            and #root.active.items==3)
        for _=1,12 do tick=tick+601;root.next_tick=tick;terrain.updater{tick=tick} end
        check("reduced-active-cap-drains-boundedly",#root.active.items<=1)

        -- Explicit water-pair proposals exercise native collision-changing writes plus the eight-tile guard.
        fresh();patch(surface,x+576,y,"sand-1")
        local sx=x+576
        surface.set_tiles({{name="water",position={sx+1,y}}},false,false,false,true)
        local chest=entity(surface,"iron-chest",sx+7,y)
        check("flood-infrastructure-buffer-protected",change(surface,sx,y,"flood","water")==false
            and surface.get_tile(sx,y).name=="sand-1" and chest.valid)
        chest.destroy()
        check("flood-unoccupied-control-writes",change(surface,sx,y,"flood","water")==true
            and surface.get_tile(sx,y).name=="water")
        entry.config.recovery=true;drain_recovery(4)
        check("flood-exact-coast-recovery",surface.get_tile(sx,y).name=="sand-1" and #root.history.items==0)
        fresh();patch(surface,sx,y,"sand-1")
        surface.set_tiles({{name="water",position={sx,y}}},false,false,false,true)
        chest=entity(surface,"iron-chest",sx+7,y)
        check("drought-infrastructure-buffer-protected",change(surface,sx,y,"drought","sand-1")==false
            and surface.get_tile(sx,y).name=="water" and chest.valid)
        chest.destroy()
        check("drought-unoccupied-control-writes",change(surface,sx,y,"drought","sand-1")==true)
        drain_recovery(4)
        check("drought-exact-water-recovery",surface.get_tile(sx,y).name=="water" and #root.history.items==0)
        fresh(gleba);patch(gleba,sx,y,"sand-1")
        check("shoreline-excludes-other-planets",change(gleba,sx,y,"flood","water")==false)

        -- Recovery ownership cannot be recreated from a target captured before an external write.
        fresh();patch(surface,x+640,y,"grass-1")
        local ox=x+640
        change(surface,ox,y,"thermal")
        surface.set_tiles({{name="grass-4",position={ox,y}}},false,false,false,false)
        blood(surface,ox,y)
        check("blood-preserves-unraised-external-replacement",surface.get_tile(ox,y).name=="grass-4"
            and history(surface,ox,y)==nil)
        check("unowned-recovery-cannot-adopt-tile",change(surface,ox,y,"thermal","grass-1",true)==false
            and surface.get_tile(ox,y).name=="grass-4" and #root.history.items==0)
        -- Native deletion/regeneration ownership is checked after the asynchronous clear stage below.

        -- Mixed paths require per-step collision semantics, independent of the record's original cause.
        fresh();patch(surface,x+704,y,"sand-3")
        local mix=x+704
        check("mixed-path-soil-step",change(surface,mix,y,"thermal")==true)
        check("mixed-path-flood-step",change(surface,mix,y,"flood","water")==true)
        check("mixed-path-drought-step",change(surface,mix,y,"drought","sand-1")==true)
        check("mixed-path-exact-history",history(surface,mix,y)
            and same_path(history(surface,mix,y).path,{"sand-3","sand-2","water"}))
        entry.config.recovery=true;recover_step()
        for _,name in ipairs({"water","sand-2","sand-3"}) do
            check("mixed-path-recovers-to-"..name,recover_step()==1 and surface.get_tile(mix,y).name==name)
        end
        check("mixed-path-history-freed",#root.history.items==0)

        -- Entity effects share tile-layer exclusions, even if a native entity survives the tile edit.
        for i,spec in ipairs({{id="hidden",tile="grass-1",hidden=true},{id="paved",tile="concrete"},{id="foundation",tile="foundation"}}) do
            for j,cause in ipairs({"tree","aging","rot","ignite","regrowth","cliff"}) do
                fresh();local ex,ey=5376+i*96,y+j*64
                patch(surface,ex,ey,"grass-1")
                local c=entry.config;c.tree_stress=true;c.aging=true;c.rot=true;c.tree_regrowth=true
                c.cliffs=true;c.wildfire="contained";c.dirty_seconds=1
                local target,extra,initial_gray
                if cause=="tree" or cause=="aging" or cause=="rot" then
                    target=entity(surface,cause=="rot" and "dry-tree" or "tree-01",ex,ey)
                    initial_gray=target.tree_gray_stage_index
                    extra={tree=target,pollution=c.pollution_high,dirty_since=tick-601}
                elseif cause=="cliff" then
                    target=surface.create_entity{name="cliff",position={ex+.5,ey+.5},force="neutral",cliff_orientation="west-to-east"}
                    assert(target,"Native cliff fixture could not be created");created[#created+1]=target;extra={entity=target}
                elseif cause=="regrowth" then extra={name="tree-01"} end
                surface.set_tiles({{name=spec.tile,position={ex,ey}}},false,false,false,true)
                if spec.hidden then surface.set_hidden_tile({ex,ey},"dirt-1") end
                local action=entity_action(surface,ex,ey,cause,extra)
                local unchanged=not target or (target.valid and (cause~="tree" or target.tree_gray_stage_index==initial_gray))
                check(spec.id.."-blocks-entity-"..cause,action==false and unchanged
                    and #root.fires.items==0 and (root.counters.trees_grown or 0)==0)
                if target and target.valid then target.destroy() end
            end
        end
        local gaia=game.planets.gaia.surface or game.planets.gaia.create_surface()
        fresh(gaia);patch(gaia,16384,16384,"ei-gaia-grass-1")
        entry.config.aging=true
        local gaia_tree=entity(gaia,"ei-gaia-tree-01",16384,16384)
        entity_action(gaia,16384,16384,"aging",{tree=gaia_tree})
        check("gaia-aging-does-not-create-offplanet-dry-tree",gaia_tree.valid
            and gaia.count_entities_filtered{name="dry-tree",area={{16380,16380},{16390,16390}}}==0)
        if gaia_tree.valid then gaia_tree.destroy() end

        -- Run the real opt-in hazard selector on a checkerboard coast, without replacing its RNG.
        -- At 128 bounded attempts, this fixed deterministic fixture must encounter both tile classes.
        local hx,hy=4864,4352
        local function coast()
            fresh();patch(surface,hx+16,hy+16,"sand-1",28)
            local tiles={}
            for dx=-1,32 do for dy=-1,32 do
                tiles[#tiles+1]={name=(dx+dy)%2==0 and "sand-1" or "water",position={hx+dx,hy+dy}}
            end end
            surface.set_tiles(tiles,false,false,false,true)
        end
        local function hazards()
            local writes=0
            for _=1,128 do
                tick=tick+1
                local b=budget()
                qc.hazards(root,b,{surface=surface,x=hx/32,y=hy/32,next_hazard=0,pollution=0},tick)
                qc.commit(root,b);writes=writes+b.used_writes
            end
            return writes
        end
        coast();check("shoreline-default-off-no-writes",hazards()==0 and #root.history.items==0)
        coast();entry.config.flood=true
        check("opt-in-flood-native-selector-writes",hazards()>0 and #root.history.items>0)
        coast();entry.config.drought=true
        check("opt-in-drought-native-selector-writes",hazards()>0 and #root.history.items>0)

        -- Native tiles at a generated boundary must be probed safely without growing neighboring chunks.
        fresh();local edge_x,edge_y=500000,500000
        edge_x=math.floor(edge_x/32)*32;edge_y=math.floor(edge_y/32)*32
        surface.request_to_generate_chunks({x=edge_x,y=edge_y},0);surface.force_generate_chunk_requests()
        local tiles={}
        for dx=0,31 do for dy=0,31 do tiles[#tiles+1]={name=(dx+dy)%2==0 and "sand-1" or "water",position={edge_x+dx,edge_y+dy}} end end
        surface.set_tiles(tiles,false,false,false,true)
        local cx,cy=edge_x/32,edge_y/32
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do surface.delete_chunk{x=cx+d[1],y=cy+d[2]} end
        check("edge-neighbor-native-chunk-absent",not surface.is_chunk_generated{x=cx+1,y=cy})
        entry.config.flood=true;entry.config.drought=true
        local safe,error_message=pcall(function()
            for _=1,256 do
                tick=tick+1;local b=budget()
                qc.hazards(root,b,{surface=surface,x=cx,y=cy,next_hazard=0,pollution=0},tick)
                qc.commit(root,b)
            end
        end)
        check("edge-native-hazard-probes-safe",safe,tostring(error_message or ""))
        check("edge-probes-do-not-generate-neighbors",not surface.is_chunk_generated{x=cx+1,y=cy})
        check("ungenerated-candidate-rejected",change(surface,edge_x+32,edge_y,"thermal")==false)

        -- Clear is asynchronous and keeps surface identity, orbital phase, overrides, and external ownership.
        fresh();root.surfaces[gleba.index].config.enabled=true;root.enabled_surfaces=2
        root.surface_order={surface.index,gleba.index};root.surface_registered={[surface.index]=1,[gleba.index]=2}
        local baseline={dusk=.25,evening=.45,morning=.55,dawn=.75}
        local function acquire(s)
            s.freeze_daytime=false;s.always_day=false;s.daytime_parameters=baseline
            root.surfaces[s.index].config.seasonal_daylight=true
            calendar.set_phase(root,s,.25,game.tick)
            root.calendar.order={s.index};root.calendar.cursor=1;root.calendar.records[s.index].next_tick=0
            calendar.service(root,game.tick,terrain.resolve_config)
        end
        acquire(surface);acquire(gleba)
        local external=gleba.daytime_parameters;external.evening=external.evening+.001;gleba.daytime_parameters=external
        root.calendar.records[gleba.index].next_tick=0;calendar.service(root,game.tick,terrain.resolve_config)
        calendar.initialize(root,game.tick)
        root.next_tick=game.tick+1000
        root.surfaces[surface.index].overrides.max_depth=7
        root.surfaces[surface.index].config.max_depth=7
        local now=calendar.snapshot(root,surface,game.tick)
        storage.__terrain_guard_pending={stage="clear",results=results,old_root=original,saved_daylight=saved_daylight,
            surface=surface,gleba=gleba,phase=now.phase,period=now.period_ticks,at=game.tick,
            owned_tuple=surface.daytime_parameters,external=external,owned_orbit=root.calendar.records[surface.index],
            external_orbit=root.calendar.records[gleba.index],old_entry=root.surfaces[surface.index]}
        check("clear-calendar-owned-fixture",now.owns_daylight)
        check("clear-calendar-external-fixture",calendar.snapshot(root,gleba,game.tick).status=="external-control")
        surface.clear();gleba.clear();deferred=true
    end)
    if not ok then check("guard-fixture-execution",false,tostring(message)) end
    for _,e in ipairs(created) do if e.valid then e.destroy() end end
    for key,prior in pairs(seeded_claims) do original_vat.claims_by_tile[key]=prior.value end
    storage.ei.auric_inoculation_vat=original_vat
    if deferred and ok then return {pending=true,cases=results} end
    for _,saved in ipairs(saved_daylight) do
        if saved.surface.valid then saved.surface.daytime_parameters=saved.parameters;saved.surface.freeze_daytime=saved.freeze;saved.surface.always_day=saved.always end
    end
    storage.ei.terrain_evolution=original
    local all,count=true,0
    for _,r in pairs(results) do count=count+1;all=all and r.pass end
    return {all_pass=all,count=count,cases=results}
end
function tests.finish(terrain,calendar)
    local p=assert(storage.__terrain_guard_pending,"No pending native clear fixture")
    local results=p.results
    local function check(name,pass,detail) results[name]={pass=pass==true,detail=detail} end
    local root=storage.ei.terrain_evolution
    local pending=false
    local function next_stage(stage) p.stage=stage;pending=true end
    local function budget()
        return {candidates=32,writes=8,searches=4,samples=4,events=8,histories=16,
            used_candidates=0,used_writes=0,used_searches=0,used_events=0,batches={},positions={}}
    end
    local function dense(order,index)
        local n=0
        for key,value in pairs(index) do n=n+1;if order[value]~=key then return false end end
        if n~=#order then return false end
        for i,value in ipairs(order) do if index[value]~=i then return false end end
        return true
    end
    local function order_check(extra)
        local pass=#root.surface_order==p.base_surface+extra and #root.calendar.order==p.base_calendar+extra
            and dense(root.surface_order,root.surface_registered) and dense(root.calendar.order,root.calendar.order_index)
        if not pass then p.churn_errors[#p.churn_errors+1]={round=p.round,stage=p.stage,surfaces=#root.surface_order,calendar=#root.calendar.order} end
        p.bounded=p.bounded and pass
    end
    local ok,message=pcall(function()
        if p.stage=="regenerate" then
            check("native-delete-completed-before-regeneration",not p.surface.is_chunk_generated{x=32,y=32})
            p.surface.request_to_generate_chunks({1024,1024},0);p.surface.force_generate_chunk_requests()
            for _,e in ipairs(p.surface.find_entities_filtered{area={{1014,1014},{1034,1034}}}) do if e.valid and e.type~="character" then e.destroy() end end
            p.surface.set_tiles({{name="grass-3",position={1024,1024}}},false,false,false,false)
            root.pending={items={},index={},cursor=1};root.surfaces[p.surface.index].config.blood=true
            assert(terrain.enqueue_scar(p.surface,{x=1024,y=1024},"blood",game.tick+1000))
            for i=1,12 do local b=budget();terrain._qc.service_events(root,b,game.tick+1000+i);terrain._qc.commit(root,b) end
            local id=p.surface.index..":1024:1024"
            check("blood-rejects-regenerated-same-name-history",p.surface.get_tile(1024,1024).name=="grass-3" and not root.history.index[id])
            if game.planets.aquilo.surface then game.delete_surface(game.planets.aquilo.surface) end
            next_stage("churn-start");return
        elseif p.stage=="churn-start" then
            p.base_surface=#root.surface_order;p.base_calendar=#root.calendar.order;p.round=1;p.bounded=true;p.churn_errors={}
            p.churn_surface=game.planets.aquilo.create_surface();next_stage("churn-created");return
        elseif p.stage=="churn-created" then
            order_check(1);assert(game.delete_surface(p.churn_surface));next_stage("churn-deleted");return
        elseif p.stage=="churn-deleted" then
            order_check(0)
            if p.round<8 then
                p.round=p.round+1;p.churn_surface=game.planets.aquilo.create_surface();next_stage("churn-created")
            else check("native-surface-churn-keeps-dense-bounded-orders",p.bounded,p.churn_errors) end
            return
        end
        local now=calendar.snapshot(root,p.surface,game.tick)
        check("native-clear-retains-orbit-identity",root.calendar.records[p.surface.index]==p.owned_orbit)
        check("native-clear-retains-season-phase",math.abs(now.phase-(p.phase+(game.tick-p.at)/p.period)%1)<1e-10)
        check("native-clear-retains-owned-boundaries",same_daylight(p.surface.daytime_parameters,p.owned_tuple) and now.owns_daylight)
        check("native-clear-retains-external-orbit",root.calendar.records[p.gleba.index]==p.external_orbit
            and calendar.snapshot(root,p.gleba,game.tick).status=="external-control")
        check("native-clear-retains-external-tuple",same_daylight(p.gleba.daytime_parameters,p.external))
        check("native-clear-replaces-terrain-owner-only",root.surfaces[p.surface.index]~=p.old_entry
            and root.surfaces[p.surface.index].overrides.max_depth==7 and root.surfaces[p.surface.index].config.max_depth==7)
        root.calendar.records[p.gleba.index].next_tick=0
        root.calendar.cursor=root.calendar.order_index[p.gleba.index]
        calendar.service(root,game.tick,terrain.resolve_config)
        check("native-clear-does-not-reacquire-external-control",same_daylight(p.gleba.daytime_parameters,p.external)
            and not calendar.snapshot(root,p.gleba,game.tick).owns_daylight)
        -- The engine queues chunk deletion; do not regenerate or inspect ownership in this call.
        root.next_tick=game.tick+10000
        local c=root.surfaces[p.surface.index].config;c.recovery=false;c.max_depth=32;c.blood=true
        p.surface.request_to_generate_chunks({1024,1024},1);p.surface.force_generate_chunk_requests()
        for _,e in ipairs(p.surface.find_entities_filtered{area={{1010,1010},{1038,1038}}}) do if e.valid and e.type~="character" then e.destroy() end end
        p.surface.set_tiles({{name="grass-1",position={1024,1024}}},false,false,false,true)
        local b=budget();assert(terrain._qc.propose(root,b,p.surface,1024,1024,"thermal",game.tick)==true);terrain._qc.commit(root,b)
        p.surface.delete_chunk{x=32,y=32}
        next_stage("regenerate")
    end)
    if not ok then check("guard-clear-fixture-execution",false,tostring(message)) end
    if pending and ok then return {pending=true,cases=results} end
    for _,saved in ipairs(p.saved_daylight) do
        if saved.surface.valid then saved.surface.daytime_parameters=saved.parameters;saved.surface.freeze_daytime=saved.freeze;saved.surface.always_day=saved.always end
    end
    storage.ei.terrain_evolution=p.old_root;storage.__terrain_guard_pending=nil
    local all,count=true,0
    for _,r in pairs(results) do count=count+1;all=all and r.pass end
    return {all_pass=all,count=count,cases=results}
end
return tests
