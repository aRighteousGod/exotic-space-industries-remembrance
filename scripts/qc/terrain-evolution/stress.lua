-- Private native stress fixture. Setup is excluded from attribution.
local model={}
local profile
local terrain
function model.configure(owner)
terrain=owner
local original=owner.updater
terrain.updater=function(event)
    if not profile then return original(event) end
    local timer=helpers.create_profiler()
    original(event)
    timer.stop()
    log({"","TERRAIN_ECOLOGY_PROFILE lane="..profile.name.." tick="..event.tick.." elapsed=",timer})
    profile.services=profile.services+1
    local r=storage.ei.terrain_evolution
    local v=r.last_service
    profile.caps=profile.caps and v.candidates<=32 and v.writes<=4 and v.searches<=1 and v.events<=4 and v.active_samples<=2 and (v.histories or 0)<=4
    if v.search_allowance>0 then
        profile.caps=profile.caps and (not profile.last_search or event.tick-profile.last_search>=32)
        profile.last_search=event.tick
    end
    profile.history=math.min(profile.history,#r.history.items)
end
end
function model.prepare()
    for _,name in ipairs{"gaia","vulcanus","gleba","fulgora","aquilo"} do
        if not game.planets[name].surface then game.planets[name].create_surface() end
    end
    terrain.initialize(game.tick)
    local surface=game.surfaces.nauvis
    -- Complete native generation before seeding ownership, and keep the owned
    -- rectangle away from synthetic chunk/water boundaries.
    surface.request_to_generate_chunks({4224,4160},7)
    surface.request_to_generate_chunks({4672,4160},4)
    surface.force_generate_chunk_requests()
    local apron={}
    for x=4064,4383 do for y=4064,4255 do apron[#apron+1]={name="grass-3",position={x,y}} end end
    surface.set_tiles(apron,false,false,false,false)
    local root=storage.ei.terrain_evolution
    local entry=root.surfaces[surface.index]
    root.history={items={},index={},cursor=1}
    local tiles={}
    for i=0,32767 do
        local x,y=4096+i%256,4096+math.floor(i/256)
        tiles[#tiles+1]={name="grass-3",position={x,y}}
        local cell=math.floor(x/32)..":"..math.floor(y/32)
        local token=entry.chunk_tokens[cell]
        if not token then token={references=0};entry.chunk_tokens[cell]=token end
        token.references=token.references+1
        local id=surface.index..":"..x..":"..y
        root.history.items[i+1]={id=id,surface=surface,owner=entry,x=x,y=y,origin="grass-1",expected="grass-3",path={"grass-1"},cause="pollution",next_tick=game.tick+1000000,chunk_cell=cell,chunk_token=token}
        root.history.index[id]=i+1
    end
    surface.set_tiles(tiles,false,false,false,false)
    for x=128,135 do for y=128,131 do surface.set_chunk_generated_status({x,y},defines.chunk_generated_status.entities) end end
    local trees={}
    for i=0,4095 do
        local p={x=4608+(i%64)*2,y=4096+math.floor(i/64)*2}
        trees[#trees+1]={name="grass-1",position=p}
    end
    surface.set_tiles(trees,false,false,false,false)
    for x=144,147 do for y=128,131 do surface.set_chunk_generated_status({x,y},defines.chunk_generated_status.entities) end end
    for _,tile in ipairs(trees) do
        local tree=surface.create_entity{name="tree-01",position=tile.position,force="neutral"}
        if tree then
            local id=surface.index..":"..tree.position.x..":"..tree.position.y
            local gray=tree.tree_gray_stage_index
            tree.tree_gray_stage_index=math.min(tree.tree_gray_stage_index_max,gray+1)
            root.trees.items[#root.trees.items+1]={id=id,surface=surface,entity=tree,gray=gray,expected=tree.tree_gray_stage_index,next_tick=game.tick+1000000}
            root.trees.index[id]=#root.trees.items
        end
    end
    surface.pollute({4650,4150},10000)
    return {history=#root.history.items,trees=#root.trees.items,seed=surface.map_gen_settings.seed}
end
function model.chunks(first,count)
    local names={"nauvis","gaia","vulcanus","gleba","fulgora","aquilo"}
    for i=first,first+count-1 do
        local surface=game.planets[names[i%6+1]].surface
        local n=math.floor(i/6)
        surface.set_chunk_generated_status({1000+n%200,1000+math.floor(n/200)},defines.chunk_generated_status.entities)
    end
end
function model.burst()
    local s=game.surfaces.nauvis
    local root=storage.ei.terrain_evolution
    for i=1,100 do
        if i%4==0 then terrain.enqueue_scar(s,{x=4096+(i%32)*8,y=4096+(game.tick%16)*8},"thermal",game.tick)
        else
            local record=root.trees.items[(game.tick*100+i)%#root.trees.items+1]
            local tree=record and record.entity
            if tree and tree.valid then
                local cause=({"tree","regrowth","ignite"})[i%4]
                terrain.enqueue_scar(s,tree.position,cause,game.tick,{tree=tree,name=tree.name,pollution=1000,dirty_since=0})
            end
        end
    end
end
function model.fill_active()
    local root=storage.ei.terrain_evolution
    assert(#root.active.items==0,"Seed before the first scheduled service")
    local names={"nauvis","gaia","vulcanus","gleba","fulgora","aquilo"}
    for i=0,2047 do
        local surface=game.planets[names[i%6+1]].surface
        local n=math.floor(i/6)
        local x,y=1000+n%200,1000+math.floor(n/200)
        if i==0 then x=144;y=128 end
        local entry=root.surfaces[surface.index]
        local cell=x..":"..y
        local token=entry.chunk_tokens[cell]
        if not token then token={references=0};entry.chunk_tokens[cell]=token end
        token.references=token.references+1
        local id=surface.index..":"..cell
        root.active.items[i+1]={id=id,surface=surface,owner=entry,x=x,y=y,chunk_cell=cell,chunk_token=token,
            resident_since=game.tick,next_soil=0,next_tree=0,next_hazard=0}
        root.active.index[id]=i+1
    end
end
function model.start(name)
    profile={start=game.tick,name=name,services=0,caps=true,history=32768}
end
function model.stop()
    local p=profile;profile=nil
    return {caps=p.caps,history_retained=p.history,services=p.services,ticks=game.tick-p.start,
        counters=storage.ei.terrain_evolution.counters,
        trees=#storage.ei.terrain_evolution.trees.items,
        active=#storage.ei.terrain_evolution.active.items,pending=#storage.ei.terrain_evolution.pending.items}
end
return model
