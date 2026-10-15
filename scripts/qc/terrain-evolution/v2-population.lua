-- Standalone V2 population screen. Run from the repository root with Lua 5.4.
-- Native boundaries are mocked: this is NOT Factorio API, UPS, or save evidence.
-- Real production updater, registry, observations, recovery, and limits are used.
dofile('scripts/qc/terrain-evolution/v2-static.lua')
local config=require('lib/terrain-evolution-config')
local policy=require('lib/terrain-policy')
local work=require('scripts/control/terrain-ecology-work')
local terrain=require('scripts/control/terrain-evolution')
local function set(kind) return {items={},index={},cursor=1,kind=kind} end
local function add(s,r) r.ecology_version=2;s.items[#s.items+1]=r;s.index[r.id]=#s.items end
local function token(entry,cell)
    local t=entry.chunk_tokens[cell]
    if not t then t={references=0};entry.chunk_tokens[cell]=t end
    t.references=t.references+1;return t
end
local names={'nauvis','gaia','vulcanus','gleba','fulgora','aquilo'}
local tiles={{'grass-1','grass-3'},{'ei-gaia-grass-2','ei-gaia-grass-1'},
    {'volcanic-smooth-stone','volcanic-smooth-stone-warm'},
    {'midland-cracked-lichen','midland-cracked-lichen-dark'},
    {'fulgoran-rock','fulgoran-sand'},{'snow-crests','snow-flat'}}
prototypes={tile={},entity={}};defines={entity_status={working=1}}
for _,pair in ipairs(tiles) do
    for _,name in ipairs(pair) do prototypes.tile[name]={is_foundation=false,collision_mask={layers={}}} end
end
script={register_on_object_destroyed=function(e)return e.unit_number end}
terrain.configure{vat={is_terrain_claimed=function()return false end},
    gaia={resolve_gaia_tree_name=function()return 'ei-gaia-tree-01' end}}
local function budget()
    return {candidates=32,writes=4,searches=1,samples=2,histories=4,events=4,
        used_candidates=0,used_searches=0,used_writes=0,used_events=0,batches={},positions={}}
end
local function build(chunks)
    storage={ei={}}
    local cfg=config.resolve({performance='lean'},{});cfg.seasonal_ecology=false
    local r={config=cfg,surfaces={},surface_order={},surface_registered={},surface_cursor=1,
        active=set('active'),history=set('history'),trees=set('trees'),pending=set('pending'),fires=set('fires'),
        counters={},pass=0,next_tick=0,next_search=0,enabled_surfaces=6,hazard_surfaces=0,
        transitions=policy.transitions,natural_exclusions={},anchor_extent=4,drill_extent=40}
    local counts={queries=0,iterations=0,writes=0}
    storage.ei.terrain_evolution=r
    for i,planet in ipairs(names) do
        local source=tiles[i][1];local tilemap={}
        local surface={valid=true,index=i,planet={name=planet},pollutant_type={name=i==4 and 'spores' or 'pollution'}}
        surface.get_tile=function(x,y)
            if type(x)=='table' then y=x.y or x[2];x=x.x or x[1] end
            local name=tilemap[x..':'..y] or source
            return {valid=true,name=name,prototype=prototypes.tile[name],collides_with=function()return false end}
        end
        surface.is_chunk_generated=function()return true end
        surface.get_pollution=function()return 0 end
        surface.find_entities_filtered=function()counts.queries=counts.queries+1;return {} end
        surface.set_tiles=function(list)
            for _,tile in ipairs(list)do
                local p=tile.position;tilemap[(p.x or p[1])..':'..(p.y or p[2])]=tile.name
                counts.writes=counts.writes+1
            end
        end
        surface.destroy_decoratives=function()end
        local n=math.floor(chunks/6)+(i<=chunks%6 and 1 or 0)
        surface.get_chunks=function()
            local cursor=0
            return setmetatable({valid=true},{__call=function()
                counts.iterations=counts.iterations+1
                if cursor>=n then return nil end
                local p={x=1000+cursor%200,y=1000+math.floor(cursor/200)};cursor=cursor+1;return p
            end})
        end
        local ec=config.resolve_surface(cfg,planet);ec.seasonal_ecology=false;ec.seasonal_daylight=false
        for _,k in ipairs{'degradation','tree_stress','tree_regrowth','aging','rot','flood','drought','cliffs','blood'}do ec[k]=false end
        ec.wildfire='off';ec.recovery=true;ec.clean_seconds=1;ec.recovery_seconds=1;ec.protection_buffer=0
        local e={surface=surface,config=ec,planet=planet,overrides={},chunk_tokens={},protected={},classified={},
            hazard_epoch=1,drill_epoch=1,tilemap=tilemap}
        r.surfaces[i]=e;r.surface_order[i]=i;r.surface_registered[i]=i
    end
    work.initialize(r,0)
    for n=0,32767 do
        local si=n%6+1;local e=r.surfaces[si];local q=math.floor(n/6)
        local x,y=q%128,math.floor(q/128);local cell=math.floor(x/32)..':'..math.floor(y/32);local id=si..':'..x..':'..y
        e.tilemap[x..':'..y]=tiles[si][2]
        add(r.history,{id=id,surface=e.surface,owner=e,x=x,y=y,origin=tiles[si][1],expected=tiles[si][2],
            path={tiles[si][1]},cause='pollution',next_tick=10000000,chunk_cell=cell,chunk_token=token(e,cell)})
    end
    for n=1,4096 do
        local si=(n-1)%6+1;local e=r.surfaces[si]
        local entity={valid=true,surface=e.surface,position={x=10000+n,y=10000},tree_gray_stage_index=1}
        add(r.trees,{id='tree:'..n,surface=e.surface,entity=entity,gray=0,expected=1,next_tick=10000000})
        local drill={valid=true,name=policy.drills[(n-1)%4+1],surface=e.surface,unit_number=n,active=false,status=0}
        assert(work.register_drill(r,drill,0))
    end
    assert(not work.register_drill(r,{valid=true,name=policy.drills[1],surface=r.surfaces[1].surface,unit_number=4097},0))
    for n=0,2047 do
        local si=n%6+1;local e=r.surfaces[si];local q=math.floor(n/6)
        local x,y=1000+q%200,1000+math.floor(q/200);local cell=x..':'..y
        add(r.active,{id=si..':'..cell,surface=e.surface,owner=e,x=x,y=y,chunk_cell=cell,chunk_token=token(e,cell),
            resident_since=0,next_soil=0,next_tree=0,next_hazard=0})
    end
    return r,counts
end
for _,chunks in ipairs{10000,100000} do
    local r,c=build(chunks)
    local maximum={candidates=0,writes=0,searches=0,histories=0,observations=0}
    for tick=16,32000,16 do
        local before_q,before_i=c.queries,c.iterations
        terrain.updater{tick=tick};local v=assert(r.last_service)
        assert(v.candidates<=32 and v.writes<=4 and v.searches<=1 and v.histories<=4 and v.events<=4 and v.active_samples<=2,'operation budget exceeded')
        assert(c.queries-before_q<=1 and c.iterations-before_i<=1,'native boundary budget exceeded')
        assert(r.work.observation_count<=64 and r.work.drill_count==4096 and #r.history.items==32768 and #r.trees.items==4096,'population retention/cap')
        for _,k in ipairs{'candidates','writes','searches','histories'} do maximum[k]=math.max(maximum[k],v[k])end
        maximum.observations=math.max(maximum.observations,r.work.observation_count)
    end
    print('PASS population='..chunks..' six_surfaces=6 services=2000 history=32768 tree_history=4096 drills=4096 queries='..c.queries..' iterators='..c.iterations..' max_candidates='..maximum.candidates..' max_histories='..maximum.histories..' max_observations='..maximum.observations)
    -- Explicit native-mocked recovery cohort: all other histories remain deferred.
    local due=0
    for _,h in ipairs(r.history.items)do
        if h.surface.index==1 then
            h.next_tick=32000;work.request_recovery(r,r.surfaces[1],h,32000);due=due+1
            if due==8 then break end
        end
    end
    local old_writes=c.writes
    for tick=32016,38000,16 do
        terrain.updater{tick=tick};local v=r.last_service
        assert(v.candidates<=32 and v.writes<=4 and v.searches<=1 and v.histories<=4,'recovery budget exceeded')
    end
    assert(c.writes-old_writes==8 and #r.history.items==32760,'bounded due cohort did not recover exactly eight records')
    print('PASS due_cohort='..due..' recovered='..(32768-#r.history.items)..' observation_count='..r.work.observation_count)
end
-- Boundary test only: this does not claim to traverse 100,000 native chunks.
local r,c=build(100000);local e=r.surfaces[1];local job=r.work.jobs.bootstrap
for i,entry in pairs(r.surfaces)do entry.bootstrap.closed=i~=1 end
job.remaining=1;job.pending=0;e.bootstrap.visits=99999
work.discovery_visit(r,e,{x=1000,y=1000},1)
assert(e.bootstrap.closed and e.bootstrap.visits==100000 and e.coverage_status=='visit-limit')
assert(job.remaining==0 and job.pending==1 and r.work.jobs.bootstrap==job,'bootstrap completed before admitted query')
work.discovery_query(r,budget(),2,function(root,b,surface,filter)
    b.searches=b.searches-1;b.used_searches=b.used_searches+1
    return surface.find_entities_filtered(filter)
end)
assert(not r.work.jobs.bootstrap and not e.drill_discovery and r.work.bootstrap_pending==0,'bootstrap did not finish')
work.discovery_visit(r,e,{x=1001,y=1000},3)
assert(not r.work.jobs.bootstrap and e.bootstrap.visits==100000,'completed bootstrap reopened')
print('PASS bootstrap_visit_limit=100000 final_descriptor_drained=true completed_generation_stays_closed=true')
