-- Actual production work/scheduler; native entities and engine are not involved.
local pack='exotic-space-industries-remembrance/'
local function mod(name) local m=dofile(pack..name..'.lua');package.loaded[name]=m;return m end
storage={ei={}};package.loaded['lib/lib']={}
mod('lib/terrain-policy');mod('lib/terrain-index')
local scheduler=mod('lib/runtime-scheduler')
local reports,unique,payloads=0,0,{}
local original=scheduler.report_rebuild
scheduler.report_rebuild=function(owner,operation,scope,id,details,tick)
    reports=reports+1
    if details and not payloads[details] then payloads[details]=true;unique=unique+1 end
    return original(owner,operation,scope,id,details,tick)
end
local work=mod('scripts/control/terrain-ecology-work')
local function set() return {items={},index={}} end
local function fresh()
    storage={ei={}};reports=0;unique=0;payloads={}
    local entry={surface={index=1},config={enabled=true}}
    local root={surfaces={[1]=entry},surface_order={1},config={interval=16},history=set(),trees=set(),pending=set(),active=set()}
    work.initialize(root,0);return root,entry
end
local budget={candidates=32,used_candidates=0}
local root,entry=fresh();local job=root.work.jobs.bootstrap;local id=job.id
local registry=scheduler.peek_rebuild_state();local record=registry.active[id]
assert(record.state=='queued')
local revision=registry.revision;local transitions=registry.transition_revision
local samples,created,maxcount={},0,0
local function count_samples()
    for _,s in ipairs(record.samples) do if not samples[s] then samples[s]=true;created=created+1 end end
    maxcount=math.max(maxcount,#record.samples)
end
count_samples()
for n=1,1000 do work.cleanup(root,budget,n*16);count_samples() end
assert(job.completed==0 and job.remaining==1 and record.state=='running')
assert(record.progress_tick==0 and registry.transition_revision==transitions)
assert(unique==1 and reports<1000 and registry.revision-revision==reports-1 and created==251 and maxcount==5)
print(('CURRENT reports=%d distinct_payloads=%d revision_delta=%d sample_tables=%d max_live_samples=%d'):format(reports,unique,registry.revision-revision,created,maxcount))
local checks=0
local function check(ok,label) checks=checks+1;assert(ok,label) end
entry.config.enabled=false;work.refresh_reports(root,16001)
check(record.state=='waiting' and record.waiting_reason=='surface-disabled' and record.eta_blocked and registry.public_count==0,'waiting')
entry.config.enabled=true;work.refresh_reports(root,16002)
check(record.state=='running' and record.waiting_reason==nil and not record.eta_blocked and registry.public_count==1,'resume')
local changes={{'completed',1,'completed'},{'phase','classifying','phase'},{'unit','entries','unit'},{'blocked',true,'eta_blocked'},{'reason','reconfigured','reason'},{'synchronous',true,'synchronous'}}
local tick=16016
for _,c in ipairs(changes) do
    local before=registry.revision;job[c[1]]=c[2];work.cleanup(root,budget,tick)
    check(registry.revision==before+1 and record[c[3]]==c[2],c[1]..' immediate')
    work.cleanup(root,budget,tick+1);check(registry.revision==before+1,c[1]..' dedup')
    tick=tick+16
end
job.total=100;work.cleanup(root,budget,16200);check(record.total==100,'known total immediate')
job.total=false;work.cleanup(root,budget,16201);check(record.total==nil,'total false immediate')
local replacement=scheduler.begin_rebuild('terrain-evolution','bootstrap','global',{state='running',completed=17,total=false},16202)
local nextid=registry.next_id;revision=registry.revision
work.cleanup(root,budget,16203)
check(job.id==id and registry.active[id]==nil and registry.active[replacement]~=nil and registry.next_id==nextid and registry.revision==revision,'retired nonnil ID stays stale')
storage={ei={}};work.cleanup(root,budget,16204);registry=scheduler.peek_rebuild_state()
check(registry.active[job.id]~=nil,'absent registry adopts retained ID')
id=job.id;job.remaining=0;job.pending=0;work.cleanup(root,budget,16205)
check(root.work.jobs.bootstrap==nil and registry.active[id]==nil and registry.history_count==1 and registry.history[1].outcome=='completed','terminal finish')
root,entry=fresh();job=root.work.jobs.bootstrap;job.total=100
work.cleanup(root,budget,16);job.completed=1;work.cleanup(root,budget,32)
for sample_tick=48,80,16 do work.cleanup(root,budget,sample_tick) end
record=scheduler.peek_rebuild_state().active[job.id]
local sample80=record.samples[#record.samples].tick
work.cleanup(root,budget,96)
check(sample80==80 and record.samples[#record.samples].tick==80,'last-sample gate preserves ETA cadence after intervening progress')
root,entry=fresh();job=root.work.jobs.bootstrap;job.total=1000
for sample_tick=16,272,16 do job.completed=sample_tick/16;work.cleanup(root,budget,sample_tick) end
registry=scheduler.peek_rebuild_state();record=registry.active[job.id]
check(record.samples[1].tick==16 and record.samples[#record.samples].tick==272,'known ETA pruning fixture endpoints')
revision=registry.revision
for sample_tick=288,320,16 do work.cleanup(root,budget,sample_tick) end
check(registry.revision==revision+1 and record.samples[1].tick==80 and record.samples[#record.samples].tick==272,
    'oldest sample pruning publishes before next sample is due')
check(scheduler.peek_rebuilds(320).active[1].eta_ticks~=nil,'prune-only publication keeps ETA visible')
print('PASS '..checks..' owner-report lifecycle checks')
