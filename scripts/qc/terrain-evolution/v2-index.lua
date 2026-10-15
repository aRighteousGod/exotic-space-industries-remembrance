-- Supplemental Lua5.4 screening; native metatable persistence still needs Factorio.
local registered={}
script={register_metatable=function(name,value) assert(not registered[name]);registered[name]=value end}
local index=dofile("exotic-space-industries-remembrance/lib/terrain-index.lua")
package.loaded["lib/terrain-index"]=index
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
local function set() return {items={},index={}} end
local function add(s,id) s.items[#s.items+1]={id=id};s.index[id]=#s.items end
local function remove(s,id)
    local position=s.index[id];if not position then return end
    local last=s.items[#s.items]
    s.items[position]=last;s.items[#s.items]=nil
    s.index[id]=nil
    if last and last.id~=id then s.index[last.id]=position end
end
local s=set();for i=1,1024 do add(s,"1:"..i..":0") end
local legacy=s.index
check(index.adopt(s)==1024 and s.index~=legacy,"O1 adoption replaces facade pointer")
check(rawget(legacy,"buckets")==nil and rawget(legacy,"legacy")==nil and rawget(legacy,"remaining")==nil,"adoption never writes metadata into full legacy hash")
check(s.index["1:123:0"]==123 and index.remaining(s.index)==1024,"old lookup fallback")
s.index["1:123:0"]=124
check(legacy["1:123:0"]==nil and s.index["1:123:0"]==124 and index.remaining(s.index)==1023,"old position update migrates once")
s.index["new"]=9000
check(legacy.new==nil and s.index.new==9000 and index.remaining(s.index)==1023,"new keys never enter legacy")
s.index["1:124:0"]=nil;s.index["1:124:0"]=nil
check(legacy["1:124:0"]==nil and index.remaining(s.index)==1022,"legacy removal decrements once")
s.index.new=nil
check(s.index.new==nil and index.remaining(s.index)==1022,"new-key removal leaves legacy count")
local before=s.index
check(index.adopt(s)==0 and s.index==before and index.remaining(s.index)==1022,"reinitialize preserves adoption progress")
for i=1,1024 do index.migrate(s.index,"1:"..i..":0") end
check(index.remaining(s.index)==0 and rawget(s.index,"legacy")==nil,"last conversion releases legacy table")
check(registered["ei-terrain-index-v1"]==getmetatable(s.index),"facade uses registered metatable")
check(index.is_facade(index.new()),"factory facade starts ready")

-- Large flat population and repeated remove/swap/add churn retain exact positions.
s=set();for i=1,32768 do add(s,"1:"..(i%128)..":"..math.floor(i/128)) end
index.adopt(s)
for i=1,#s.items do index.migrate(s.index,s.items[i].id) end
check(index.remaining(s.index)==0,"32768-index migration completes")
for i=1,1024 do
    local old=s.items[(i*17)%#s.items+1].id
    remove(s,old);add(s,"2:"..i..":churn")
    check(s.index[old]==nil,"removed ID not revived")
end
local bucket_count,largest,count=0,0,0
for _,bucket in pairs(rawget(s.index,"buckets")) do
    bucket_count=bucket_count+1;local n=0
    for id,position in pairs(bucket) do
        n=n+1;count=count+1;check(s.items[position].id==id,"bucket position matches dense member")
    end
    largest=math.max(largest,n)
end
check(count==32768 and bucket_count<=256,"bounded facade population after churn")
for i,r in ipairs(s.items) do check(s.index[r.id]==i,"dense position lookup exact after swaps") end

-- Simulate serializer-owned table copying and registered metatable restoration.
local function copy(value,seen)
    if type(value)~="table" then check(type(value)~="function","stored state contains no functions");return value end
    seen=seen or {};if seen[value] then return seen[value] end
    local result={};seen[value]=result
    for k,v in pairs(value) do result[copy(k,seen)]=copy(v,seen) end
    local mt=getmetatable(value)
    if mt then
        check(mt==registered["ei-terrain-index-v1"],"known registered metatable")
        setmetatable(result,registered["ei-terrain-index-v1"])
    end
    return result
end
local partial=set();for i=1,20 do add(partial,"saved:"..i) end
index.adopt(partial);partial.index["saved:1"]=1;remove(partial,"saved:2")
local restored=copy(partial)
check(index.remaining(restored.index)==index.remaining(partial.index),"reload shape preserves remaining count")
for i,r in ipairs(restored.items) do check(restored.index[r.id]==i,"reload facade resolves both old/new positions") end
check(index.adopt(restored)==0,"reload adoption is idempotent")
print(("PASS %d facade checks; occupied buckets=%d largest_fixture_bucket=%d"):format(checks,bucket_count,largest))

-- Use actual work module and owner functions with native seams from current QC.
local file=assert(io.open("scripts/qc/terrain-evolution/v2-static.lua","r"))
local source=file:read("*a");file:close()
source=source:sub(1,assert(source:find("local saved={}",1,true))-1)
assert(load(source..[===[
local index=require("lib/terrain-index")
local next_record=up(update,"next_record")
local attach=up(update,"attach_patch")
-- Actual fresh-set and read-only load-adoption integration.
local integrated=dofile(pack.."scripts/control/terrain-evolution.lua")
storage={ei={}}
local created=up(integrated.initialize,"state")()
for _,name in ipairs{"history","trees","pending","active"} do check(index.is_facade(created[name].index),"factory indexed "..name) end
check(not index.is_facade(created.fires.index),"small fire set stays plain")
created.config={};created.work={};created.hazard_surfaces=1;created.natural_exclusions={};created.next_tick=1000000
integrated.on_load();check(not integrated.has_tick_work(0),"normal facade load requires no adoption")
created.history.index={};local plain=created.history.index
integrated.on_load();check(integrated.has_tick_work(0) and created.history.index==plain,"V2 plain-index load requests adoption without on_load writes")
local root,entry=fresh(nil,nil,true)
local old_id=root.work.jobs.migration.id
check(root.work.jobs.migration.total==8,"V1 record plus index migration counts eight finite steps")
local published=scheduler.peek_rebuild_state().active[old_id]
check(published.total==8 and published.unit=="steps","initial public report includes index steps immediately")
root.pending.items[1].surface=entry.surface;root.pending.items[1].owner=entry;root.pending.items[1].generation=0
root.pending.items[1].x=0;root.pending.items[1].y=0;root.pending.items[1].cause="thermal"
local b=budget();work.migrate(root,b,1,next_record,attach)
check(b.histories==0 and b.migration_inspections==4,"combined conversion keeps four-inspection allowance")
check(root.work.jobs.migration==nil,"V1 combined migration completes")
local done
for _,r in pairs(scheduler.peek_rebuild_state().history) do if r.id==old_id then done=r end end
check(done and done.completed==8 and done.total==8 and done.unit=="steps","finished report totals include both obligations")

-- Removal of an old victim also migrates an old swap-tail index, but the tail
-- still owes its separate record conversion. No obligation may be lost/doubled.
root,entry=fresh();root.history={items={},index={},cursor=1}
for _,id in ipairs{"victim","tail"} do
    local r={id=id,surface=entry.surface,owner=entry}
    root.history.items[#root.history.items+1]=r;root.history.index[id]=#root.history.items
end
root.work=nil;work.initialize(root,0)
local combined=root.work.jobs.migration;old_id=combined.id
check(combined.total==4,"two V1 records plus two old lookups")
up(update,"remove")(root.history,"victim")
check(index.remaining(root.history.index)==0 and root.history.items[1].ecology_version~=2,"swap-tail index moves without claiming tail schema conversion")
work.initialize(root,1)
check(combined.id==old_id and combined.completed==3 and combined.remaining==1,"victim schema and two index obligations reconcile once")
b=budget();work.migrate(root,b,2,next_record,attach)
check(not root.work.jobs.migration and root.history.items[1].ecology_version==2,"remaining tail schema conversion closes generation")
for _,r in pairs(scheduler.peek_rebuild_state().history) do if r.id==old_id then done=r end end
check(done.total==4 and done.completed==4,"swap-tail migration final total exact")

-- Startup-disable cleanup of old fires is outside the four-set denominator.
root,entry=fresh();root.history={items={{id="owned",surface=entry.surface,owner=entry}},index={owned=1},cursor=1}
root.work=nil;work.initialize(root,0);local fire_job=root.work.jobs.migration
for i=1,2 do
    local entity={valid=true,name="ei-ecology-fire"};entity.destroy=function() entity.valid=false end
    local r={id="old-fire:"..i,entity=entity,surface=entry.surface}
    root.fires.items[i]=r;root.fires.index[r.id]=i
end
up(integrated.initialize,"release_contained")(root)
check(#root.fires.items==0 and fire_job.completed==0 and fire_job.remaining==2,"legacy fire release never credits domain migration")
b=budget();work.migrate(root,b,1,next_record,attach)
check(not root.work.jobs.migration and index.remaining(root.history.index)==0,"owned history still converts after legacy fire cleanup")

-- Existing V2 intermediate save: every record is current, only flat index needs adoption.
root,entry=fresh()
root.history.index={}
for i=1,12 do
    local r={id="v2:"..i,ecology_version=2,surface=entry.surface,owner=entry}
    root.history.items[i]=r;root.history.index[r.id]=i
end
work.initialize(root,10)
local job=root.work.jobs.migration;old_id=job.id
check(job.total==12 and job.remaining==12 and job.index_remaining==12,"V2 flat index creates finite index-only report")
work.initialize(root,11)
check(root.work.jobs.migration.id==old_id and job.total==12,"reinitialize preserves generation and denominator")
-- A swap-style old-key update/removal retires only index obligations.
root.history.index["v2:2"]=nil;root.history.index["v2:12"]=2
root.history.items[2]=root.history.items[12];root.history.items[12]=nil
root.history.items[12]={id="post-adoption",ecology_version=2,surface=entry.surface,owner=entry}
root.history.index["post-adoption"]=12
check(job.total==12 and index.remaining(root.history.index)==10,"new admission excluded from index denominator")
for tick=12,100 do
    b=budget();work.migrate(root,b,tick,next_record,attach)
    check((b.migration_inspections or 0)<=4 and b.histories>=0,"bounded index drain")
    if not root.work.jobs.migration then break end
end
check(not root.work.jobs.migration and index.remaining(root.history.index)==0,"swap removal cannot strand index-only migration")
for _,r in pairs(scheduler.peek_rebuild_state().history) do if r.id==old_id then done=r end end
check(done.completed==12 and done.total==12,"outside-service migration reconciles exactly once")
check(root.history.index["post-adoption"]==12,"new lookup survives old-index retirement")

-- Startup-disabled owner still executes only finite maintenance until the index drains.
root,entry=fresh();root.history.index={}
for i=1,8 do
    local cell=i..":0";local token={references=1};entry.chunk_tokens[cell]=token
    local r={id="disabled:"..i,ecology_version=2,surface=entry.surface,owner=entry,x=i*32,y=0,
        chunk_cell=cell,chunk_token=token,expected="grass-1",next_tick=1000000}
    root.history.items[i]=r;root.history.index[r.id]=i
end
work.initialize(root,0);root.config.enabled=false;entry.config.enabled=false;root.enabled_surfaces=0
for tick=0,1024,16 do update{tick=tick} end
check(not root.work.jobs.migration and not terrain.has_tick_work(1040),"disabled owner drains finite index migration then idles")
print("PASS "..checks.." actual-module migration checks")
]===],"index-migration-regressions","t",_ENV))()
