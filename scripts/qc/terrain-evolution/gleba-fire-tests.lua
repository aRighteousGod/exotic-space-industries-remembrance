-- Additional native species/habitat/fire contract fixture; staged private exports only.
local tests={}
local species={"cuttlepop","slipstack","funneltrunk","hairyclubnub","teflilly","lickmaw","stingfrond","boompuff","sunnycomb","water-cane"}
local habitats={"wetland-light-green-slime","wetland-green-slime","wetland-light-dead-skin","wetland-dead-skin",
    "wetland-pink-tentacle","wetland-red-tentacle","wetland-blue-slime","gleba-deep-lake","highland-dark-rock"}
local function budget()
    return {candidates=32,writes=8,searches=4,samples=4,events=8,histories=16,used_candidates=0,
        used_writes=0,used_searches=0,used_events=0,batches={},positions={}}
end
function tests.run(terrain,policy)
    assert(script.active_mods["zzz-esir-terrain-qc"] and terrain._qc,"Private native QC export required")
    local qc=terrain._qc
    local original=storage.ei.terrain_evolution
    local gleba=game.planets.gleba.surface or game.planets.gleba.create_surface()
    local nauvis=game.surfaces.nauvis
    local results,created={},{}
    local function check(name,value,detail) results[name]={pass=value==true,detail=detail} end
    local tick=game.tick+10000
    local root,entry
    local function fresh(surface)
        storage.ei.terrain_evolution=nil;terrain.initialize(tick)
        root=storage.ei.terrain_evolution;entry=root.surfaces[surface.index]
        root.surface_order={surface.index};root.surface_registered={[surface.index]=1};root.enabled_surfaces=1
        root.config.cold_chunks=0;root.next_tick=tick+10000
        for index,e in pairs(root.surfaces) do
            local c=e.config;c.enabled=index==surface.index;c.seasonal_daylight=false;c.seasonal_ecology=false
            c.degradation=false;c.recovery=false;c.tree_stress=false;c.tree_regrowth=false;c.aging=false;c.rot=false
            c.cliffs=false;c.blood=false;c.flood=false;c.drought=false;c.wildfire="off";c.protection_buffer=0
            c.dirty_seconds=1;c.clean_seconds=1;c.intensity_multiplier=1;c.tree_density_limit=16
        end
    end
    local function patch(surface,x,y,tile)
        surface.request_to_generate_chunks({x=x,y=y},1);surface.force_generate_chunk_requests()
        for _,e in ipairs(surface.find_entities_filtered{area={{x-20,y-20},{x+20,y+20}}}) do if e.valid and e.type~="character" then e.destroy() end end
        local tiles={}
        for dx=-12,12 do for dy=-12,12 do tiles[#tiles+1]={name=tile,position={x+dx,y+dy}} end end
        surface.set_tiles(tiles,false,false,false,true)
    end
    local function action(surface,x,y,cause,extra)
        tick=tick+1
        local result
        for _=1,3 do
            result=qc.entity_event(root,budget(),{surface=surface,x=x,y=y,cause=cause,extra=extra or {}},tick)
            if result~=nil then break end
        end
        return result
    end
    local function find(surface,name,x,y)
        return surface.find_entities_filtered{name=name,area={{x,y},{x+1,y+1}}}[1]
    end
    local function create(surface,name,x,y)
        local e=surface.create_entity{name=name,position={x+.5,y+.5},force="neutral"}
        if e then created[#created+1]=e end
        return e
    end
    local function habitat_for(surface,name,x,y)
        for _,tile in ipairs(habitats) do
            patch(surface,x,y,tile)
            if surface.can_place_entity{name=name,position={x+.5,y+.5},force="neutral"} then return tile end
        end
    end
    local function change(surface,x,y,cause,target,recover)
        tick=tick+1;local b=budget()
        local result=qc.propose(root,b,surface,x,y,cause,tick,target,recover);qc.commit(root,b)
        return result
    end
    local ok,message=pcall(function()
        for i,name in ipairs(species) do
            fresh(gleba);local x,y=20000+i*64,20000
            check("gleba-species-"..name,prototypes.entity[name] and prototypes.entity[name].type=="tree"
                and policy.native_tree(name,"gleba") and not policy.native_tree(name,"nauvis"))
            local habitat=habitat_for(gleba,name,x,y)
            check("gleba-native-habitat-"..name,habitat~=nil,habitat)
            if habitat then
                entry.config.tree_regrowth=true
                action(gleba,x,y,"regrowth",{name=name})
                local tree=find(gleba,name,x,y)
                check("gleba-native-regrowth-"..name,tree~=nil,habitat)
                if tree then
                    created[#created+1]=tree
                    local gray,max=tree.tree_gray_stage_index,tree.tree_gray_stage_index_max
                    entry.config.tree_stress=true
                    -- Synthetic dirty payload tests this action only; Gleba spores are not pollution toxicity.
                    action(gleba,x,y,"tree",{tree=tree,pollution=entry.config.pollution_high,dirty_since=tick-601})
                    check("gleba-native-gray-stage-"..name,tree.tree_gray_stage_index==math.min(max,gray+1)
                        and ((max==gray and #root.trees.items==0) or (max>gray and #root.trees.items==1)),{initial=gray,max=max})
                    if max>gray then
                        action(gleba,x,y,"tree",{tree=tree,pollution=0,clean_since=tick-601})
                        check("gleba-native-gray-recovery-"..name,tree.tree_gray_stage_index==gray and #root.trees.items==0)
                    end
                    tree.destroy() -- No .die(): boompuff death effects are outside this fixture.
                end
            end
            fresh(nauvis);patch(nauvis,x,y,"grass-1")
            entry.config.tree_regrowth=true;entry.config.tree_stress=true
            check("gleba-wrong-planet-regrowth-"..name,action(nauvis,x,y,"regrowth",{name=name})==false
                and not find(nauvis,name,x,y))
            local foreign=create(nauvis,name,x,y)
            check("gleba-wrong-planet-native-tree-created-"..name,foreign~=nil)
            if foreign then
                local gray=foreign.tree_gray_stage_index
                check("gleba-wrong-planet-stress-"..name,action(nauvis,x,y,"tree",{tree=foreign,pollution=entry.config.pollution_high,dirty_since=tick-601})==false
                    and foreign.valid and foreign.tree_gray_stage_index==gray and #root.trees.items==0)
                foreign.destroy()
            end
        end
        -- Every approved wetland, including terminal habitat-only tiles, permits an actually placeable native parent species.
        for i,tile in ipairs(habitats) do
            fresh(gleba);local x,y=21000+i*64,21000;patch(gleba,x,y,tile)
            local selected
            for _,name in ipairs(species) do if gleba.can_place_entity{name=name,position={x+.5,y+.5},force="neutral"} then selected=name;break end end
            check("gleba-habitat-native-placement-"..tile,selected~=nil,selected)
            if selected then
                entry.config.tree_regrowth=true;action(gleba,x,y,"regrowth",{name=selected})
                local tree=find(gleba,selected,x,y)
                check("gleba-habitat-regrowth-"..tile,tree~=nil)
                if tree then created[#created+1]=tree;tree.destroy() end
            end
        end
        for i,pair in ipairs({{"wetland-light-green-slime","wetland-green-slime"},{"wetland-light-dead-skin","wetland-dead-skin"},{"wetland-pink-tentacle","wetland-red-tentacle"}}) do
            fresh(gleba);local x,y=22000+i*64,22000;patch(gleba,x,y,pair[1])
            check("gleba-wetland-forward-"..i,change(gleba,x,y,"thermal")==true and gleba.get_tile(x,y).name==pair[2])
            check("gleba-wetland-exact-recovery-"..i,change(gleba,x,y,"thermal",pair[1],true)==true
                and gleba.get_tile(x,y).name==pair[1] and #root.history.items==0)
        end
        for i,tile in ipairs({"wetland-yumako","wetland-jellynut"}) do
            fresh(gleba);local x,y=22500+i*64,22500;patch(gleba,x,y,tile)
            entry.config.tree_regrowth=true;entry.config.tree_stress=true
            check("cultivated-soil-no-regrowth-"..tile,action(gleba,x,y,"regrowth",{name="water-cane"})==false)
            local tree=create(gleba,"water-cane",x,y)
            check("cultivated-soil-native-guard-fixture-"..tile,tree~=nil)
            if tree then
                local gray=tree.tree_gray_stage_index
                check("cultivated-soil-no-stress-"..tile,action(gleba,x,y,"tree",{tree=tree,pollution=entry.config.pollution_high,dirty_since=tick-601})==false
                    and tree.tree_gray_stage_index==gray and #root.trees.items==0)
                tree.destroy()
            end
        end
        for i,name in ipairs({"yumako-tree","jellystem","tree-01","ei-gaia-tree-01","ashland-lichen-tree"}) do
            fresh(gleba);local x,y=23000+i*64,23000;patch(gleba,x,y,"highland-dark-rock")
            entry.config.tree_regrowth=true
            check("gleba-rejects-cultivated-or-foreign-"..name,action(gleba,x,y,"regrowth",{name=name})==false
                and not find(gleba,name,x,y))
        end
        for i,spec in ipairs({{"vulcanus","lava"},{"fulgora","oil-ocean-deep"},{"aquilo","ammoniacal-ocean"}}) do
            local s=game.planets[spec[1]].surface or game.planets[spec[1]].create_surface()
            fresh(s);local x,y=24000+i*64,24000;patch(s,x,y,spec[2])
            check("foreign-liquid-kept-"..spec[1],change(s,x,y,"thermal")==false and s.get_tile(x,y).name==spec[2] and #root.history.items==0)
        end

        -- Native flames, not mocks. World time does not advance inside this action fixture.
        fresh(nauvis);local fx,fy=25000,25000;patch(nauvis,fx,fy,"grass-1")
        entry.config.wildfire="contained"
        check("contained-fire-native-create",action(nauvis,fx,fy,"ignite")==true and #root.fires.items==1
            and root.fires.items[1].entity.name=="ei-ecology-fire")
        for _,r in ipairs(root.fires.items) do created[#created+1]=r.entity end
        local before=#root.fires.items
        patch(nauvis,fx+64,fy,"grass-1")
        check("fire-600-tick-throttle",action(nauvis,fx+64,fy,"ignite")==false and #root.fires.items==before)
        entry.config.wildfire="off";tick=tick+601
        check("fire-runtime-off-blocks-new-ignition",action(nauvis,fx+64,fy,"ignite")==false and #root.fires.items==before)
        entry.config.wildfire="spreading"
        check("spreading-fire-native-create",action(nauvis,fx+64,fy,"ignite")==true and #root.fires.items==2
            and root.fires.items[2].entity.name=="fire-flame-on-tree")
        created[#created+1]=root.fires.items[2].entity
        entry.config.wildfire="contained"
        for i=3,16 do
            local px,py=fx+((i-1)%4)*64,fy+math.floor((i-1)/4)*64
            patch(nauvis,px,py,"grass-1");tick=tick+601;action(nauvis,px,py,"ignite")
        end
        for _,r in ipairs(root.fires.items) do created[#created+1]=r.entity end
        check("fire-native-token-cap-filled",#root.fires.items==16)
        patch(nauvis,fx+320,fy+320,"grass-1")
        tick=tick+601;check("fire-16-token-cap-refuses",action(nauvis,fx+320,fy+320,"ignite")==false and #root.fires.items==16)
        local combat=create(nauvis,"fire-flame",fx+320,fy+320)
        check("unrelated-combat-fire-created",combat~=nil)
        if combat then
            local owned=false;for _,r in ipairs(root.fires.items) do if r.entity==combat then owned=true end end
            check("unrelated-combat-fire-not-adopted",not owned)
            entry.config.wildfire="off";tick=tick+10000;root.next_tick=tick
            terrain.updater{tick=tick}
            check("unrelated-combat-fire-survives-owner-maintenance",combat.valid)
        end
    end)
    if not ok then check("gleba-fire-fixture-execution",false,tostring(message)) end
    for _,e in ipairs(created) do if e.valid then e.destroy() end end
    storage.ei.terrain_evolution=original
    local all,count=true,0;for _,r in pairs(results) do count=count+1;all=all and r.pass end
    return {all_pass=all,count=count,cases=results}
end
return tests
