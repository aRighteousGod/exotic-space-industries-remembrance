--==============================================================================
-- ESIR FILE MAP
-- owns: ecological observations, drill membership and finite maintenance reports
-- loaded_by: terrain-evolution.lua
-- cadence: owner-budgeted service; lifecycle membership admission
-- forwarded_events: owner-routed callbacks only
-- storage_roots: storage.ei.terrain_evolution.work
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration changes and legacy state adoption
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
local lib=require("lib/lib")
local policy=require("lib/terrain-policy")
local scheduler=require("lib/runtime-scheduler")
local terrain_index=require("lib/terrain-index")
local model={}
model.entity_causes={regrowth=true,tree=true,rot=true,aging=true,ignite=true,cliff=true}
---@alias EcologyServiceResult "applied"|"ineligible"|"retry"|"budget"
---@param changed boolean?
---@param progressed boolean
---@return EcologyServiceResult
function model.result(changed,progressed)
    if changed==true then return "applied" end
    if changed==false then return "ineligible" end
    return progressed and "retry" or "budget"
end
function model.count_record(root,record,kind)
    if kind=="pending" and not record.pending_class then
        record.pending_class=model.entity_causes[record.cause] and "E" or "T"
        root.pending[record.pending_class]=(root.pending[record.pending_class] or 0)+1
    end
    if record.counted or not kind then return end
    local entry=record.owner or (record.surface and record.surface.valid and root.surfaces[record.surface.index])
    if not entry then return end
    record.counted=entry;record.counted_kind=kind;entry.counts=entry.counts or {};entry.counts[kind]=(entry.counts[kind] or 0)+1
end
function model.uncount_record(record)
    local entry=record.counted;if not entry then return end
    local kind=record.counted_kind;entry.counts[kind]=math.max(0,(entry.counts[kind] or 0)-1);record.counted=nil
end
local drill_names={};for _,name in ipairs(policy.drills) do drill_names[name]=true end
local operations={"migration","bootstrap","revalidation","maintenance"}
---@class EsirEcologyObservation
---@field owner EsirTerrainSurface
---@field surface LuaSurface
---@field x integer
---@field y integer
---@field kind string
---@field expires MapTick
---@field sample_tick MapTick?
---@field clean_since MapTick?
---@field dirty_since MapTick?
---@field ready_until MapTick?
---@class EsirEcologyDrill
---@field entity LuaEntity
---@field id integer
---@field registration integer
---@field owner EsirTerrainSurface
---@field next_tick MapTick
---@field epoch integer
---@class EsirEcologyGeneration
---@field id integer?
---@field completed integer
---@field remaining integer?
---@field total integer|false
---@field phase string
---@field reason string
---@field report_details EiRebuildDetails? Reused scalar publication payload.
---@field report_tick MapTick?
---@field report_id integer?
local function report(root,operation,tick,state)
    local job=root.work.jobs[operation];if not job then return end
    state=state or job.state or "running"
    local unit=job.unit or "records";local blocked=job.blocked or false
    local waiting=state=="waiting" and "surface-disabled" or false;local synchronous=job.synchronous or false
    local details=job.report_details
    local unchanged=details and details.state==state and details.phase==job.phase and details.reason==job.reason
        and details.completed==job.completed and details.total==job.total and details.unit==unit
        and details.eta_blocked==blocked and details.waiting_reason==waiting and details.synchronous==synchronous
    -- Discovery may publish before cleanup in the same service. Reuse one small
    -- payload and suppress identical publications, keeping the shared ETA's
    -- 60-tick sample cadence and all actual progress/state transitions immediate.
    if unchanged and job.report_id==job.id then
        local registry=scheduler.peek_rebuild_state()
        local live=registry and registry.active[job.id]
        local samples=live and live.samples
        local sampled=samples and samples[#samples] and samples[#samples].tick or job.report_tick or 0
        local prune_due=samples and #samples>1 and tick-samples[1].tick>300
        if live and tick-sampled<60 and not prune_due then return end
    end
    details=details or {};job.report_details=details
    details.state=state;details.phase=job.phase;details.reason=job.reason;details.completed=job.completed
    details.total=job.total;details.unit=unit;details.eta_blocked=blocked;details.waiting_reason=waiting;details.synchronous=synchronous
    job.id=scheduler.report_rebuild("terrain-evolution",operation,"global",job.id,details,tick)
    job.report_tick=tick;job.report_id=job.id
end
local function finish(root,operation,tick,outcome)
    local job=root.work.jobs[operation];if not job then return end
    if job.id then
        scheduler.update_rebuild(job.id,{completed=job.completed,total=job.total,phase=job.phase,unit=job.unit or "records"},tick)
        scheduler.finish_rebuild(job.id,outcome or "completed",tick)
    end
    root.work.jobs[operation]=nil
end
local function begin(root,operation,tick,details)
    finish(root,operation,tick,"superseded")
    root.work.jobs[operation]=details;report(root,operation,tick,"queued")
end
-- Progress boundaries update one member's cached state; presentation only sees
-- these scalar counts. Configuration events may reconcile the finite membership.
local function member_state(root,operation,entry,tick)
    local job=root.work.jobs[operation];if not job then return end
    job.members=job.members or {};job.running=job.running or 0;job.waiting=job.waiting or 0
    local index=entry.surface.index;local previous=job.members[index]
    if previous then job[previous]=job[previous]-1 end
    local belongs=not entry.retired and (operation=="bootstrap" and entry.bootstrap
        and (not entry.bootstrap.closed or entry.drill_discovery and entry.drill_discovery.bootstrap)
        or operation=="revalidation" and (entry.revalidation_remaining or 0)>0)
    local state=belongs and (entry.config.enabled and "running" or "waiting") or nil
    job.members[index]=state;if state then job[state]=job[state]+1 end
    job.blocked=job.waiting>0;job.state=job.running==0 and job.waiting>0 and "waiting" or "running"
    report(root,operation,tick)
end
local index_sets={"history","trees","pending","active"}
local function index_remaining(root)
    local count=0
    for _,name in ipairs(index_sets) do count=count+terrain_index.remaining(root[name].index) end
    return count
end
-- Normal swap removal/updates can migrate old keys outside this service.
-- Reconcile four scalar counts; never enumerate either index representation.
local function report_index_progress(root,tick)
    local remaining=index_remaining(root)
    local job=root.work.jobs.migration
    if not job then
        if remaining>0 then
            begin(root,"migration",tick,{phase="records",reason="ecology-index-v1",
                completed=0,total=remaining,remaining=remaining,index_remaining=remaining,
                set_cursor=0,unit="steps"})
        end
        return
    end
    local previous=job.index_remaining or 0
    if remaining>previous then
        job.total=job.total+remaining-previous
        job.remaining=job.remaining+remaining-previous
    elseif remaining<previous then
        job.completed=job.completed+previous-remaining
        job.remaining=math.max(0,job.remaining-previous+remaining)
    end
    job.index_remaining=remaining
    if remaining>0 or previous>0 then job.unit="steps" end
end
---@param root table
---@param tick MapTick
function model.initialize(root,tick,reason)
    local w=root.work
    if not w then
        w={observations={},observation_keys={},observation_cursor=0,observation_count=0,
            recovery_observations=0,drills={},registrations={},drill_count=0,drill_surface_cursor=0,
            jobs={},epoch=0,query_cursor=0,bootstrap_pending=0,coverage_limited=0}
        root.work=w
        root.protected_count=0
        for _,entry in pairs(root.surfaces) do root.protected_count=root.protected_count+(entry.protected_count or 0) end
        local total=0
        for _,name in ipairs({"history","trees","pending","active"}) do
            local set=root[name];set.kind=name;total=total+#set.items
        end
        if total>0 then begin(root,"migration",tick,{phase="records",reason="ecology-v2",completed=0,total=total,remaining=total,set_cursor=0}) end
        local count=0
        for _,index in ipairs(root.surface_order) do
            local entry=root.surfaces[index]
            entry.bootstrap={visits=0,closed=false};count=count+1
        end
        if count>0 then begin(root,"bootstrap",tick,{phase="discovering",reason="ecology-v2",completed=0,total=false,remaining=count,unit="chunks"}) end
    end
    for _,name in ipairs(index_sets) do
        root[name].kind=name;terrain_index.adopt(root[name])
    end
    report_index_progress(root,tick)
    if w.jobs.migration then
        if w.jobs.migration.remaining==0 then finish(root,"migration",tick) else report(root,"migration",tick) end
    end
    local capacity=math.min(64,math.max(1,math.floor(1024/root.config.interval)))
    -- At most 64 observations exist; shrinking never removes terrain lineage.
    for i=64,1,-1 do
        local r=w.observations[i]
        if r and w.observation_count>capacity then
            w.observations[i]=nil;w.observation_keys[r.id]=nil;w.observation_count=w.observation_count-1
            if r.kind=="recovery" then w.recovery_observations=w.recovery_observations-1 end
        end
    end
    if reason=="configuration" then
        w.epoch=w.epoch+1
        for _,entry in pairs(root.surfaces) do entry.revalidation_remaining=entry.drills and #entry.drills or 0 end
        begin(root,"revalidation",tick,{phase="drills",reason="configuration",completed=0,total=w.drill_count,remaining=w.drill_count,synchronous=w.drill_count==0})
        if w.drill_count==0 then finish(root,"revalidation",tick) end
    end
    root.version=2
end
function model.refresh_reports(root,tick)
    if not root.work then return end
    for _,operation in ipairs({"bootstrap","revalidation"}) do
        local job=root.work.jobs[operation]
        if job then
            job.members={};job.running=0;job.waiting=0
            for _,entry in pairs(root.surfaces) do
                member_state(root,operation,entry,tick)
            end
        end
    end
end
-- Removal and conversion share the original denominator; new admissions never
-- join an existing migration generation. This handles swap removal mid-pass.
function model.retire_legacy(root,record)
    if not root.work or record.ecology_version==2 then return end
    local job=root.work.jobs.migration
    if job then job.remaining=math.max(0,job.remaining-1);job.completed=job.completed+1 end
    record.ecology_version=2
end
function model.migrate(root,budget,tick,next_record,attach,limit)
    local job=root.work.jobs.migration;if not job then return end
    for _=1,math.min(4-(budget.migration_inspections or 0),limit or 4,budget.histories) do
        budget.migration_inspections=(budget.migration_inspections or 0)+1
        job.set_cursor=job.set_cursor%4+1
        local name=({"history","trees","pending","active"})[job.set_cursor]
        local set=root[name]
        local r=next_record(set,"migration_cursor")
        budget.histories=budget.histories-1
        if r then terrain_index.migrate(set.index,r.id) end
        if r and r.ecology_version~=2 then
            r.climate=nil -- Historical sample gaps never become sustained exposure.
            if name=="pending" and not r.chunks and r.surface and r.surface.valid and r.owner==root.surfaces[r.surface.index] and r.generation==(r.owner.generation or 0) then attach(r) end
            model.count_record(root,r,name)
            model.retire_legacy(root,r)
        end
    end
    report_index_progress(root,tick)
    if job.remaining==0 then finish(root,"migration",tick) else report(root,"migration",tick) end
end
local function observation_id(entry,x,y) return entry.surface.index..":"..x..":"..y end
local function release_observation(w,slot)
    local r=w.observations[slot];if not r then return end
    w.observation_keys[r.id]=nil;w.observations[slot]=nil;w.observation_count=w.observation_count-1
    if r.kind=="recovery" then w.recovery_observations=w.recovery_observations-1 end
end
---@return EsirEcologyObservation?
function model.observe(root,entry,x,y,kind,tick)
    local w=root.work;local id=observation_id(entry,x,y)
    local slot=w.observation_keys[id];local existing=slot and w.observations[slot]
    if existing and existing.owner==entry then
        if kind=="recovery" and existing.kind~="recovery" then existing.kind=kind;w.recovery_observations=w.recovery_observations+1 end
        return existing
    end
    local capacity=math.min(64,math.max(1,math.floor(1024/root.config.interval)))
    if w.observation_count>=capacity then return end
    -- Reserve half the slots for recoveries when authoritative history exists.
    if kind~="recovery" and (#root.history.items+#root.trees.items)>0
        and w.observation_count-w.recovery_observations>=math.ceil(capacity/2) then return end
    for i=1,64 do
        if not w.observations[i] then
            local cfg=entry.config
            local dwell=kind=="recovery" and cfg.clean_seconds or math.max(cfg.clean_seconds,cfg.dirty_seconds)
            local index=root.active.index[id];local active=index and root.active.items[index]
            -- Observation turnover never grants another immediate roll. The
            -- discovery entry retains deadlines, independently of sample time.
            local schedule=active and active.schedule
            if not schedule then
                local phase=math.abs(x*31+y*17)%64
                schedule={next_soil=tick,tree_due={tree=tick+phase,
                    regrowth=tick+cfg.tree_growth_seconds*60/cfg.intensity_multiplier+phase,
                    aging=tick+cfg.tree_aging_seconds*60/cfg.intensity_multiplier+phase,
                    rot=tick+cfg.tree_rot_seconds*60/cfg.intensity_multiplier+phase},
                    hazard_epoch=entry.hazard_epoch,hazard_due={}}
                for hazard=1,4 do schedule.hazard_due[hazard]=tick+cfg.hazard_seconds*60/cfg.intensity_multiplier+phase end
                if active then active.schedule=schedule end
            end
            local r={id=id,owner=entry,surface=entry.surface,x=x,y=y,kind=kind,dwell=dwell,attempts=0,schedule=schedule,schedule_owner=active}
            w.observations[i]=r;w.observation_keys[id]=i;w.observation_count=w.observation_count+1
            if kind=="recovery" then w.recovery_observations=w.recovery_observations+1 end
            return r
        end
    end
end
-- Ready observations are the bounded execution set. Walking the much larger
-- discovery/history populations again could miss every matured lease.
-- Inspect eight slots per class and resume; empty-ready fallbacks must stay
-- small even when all 64 observations are waiting for sustained exposure.
-- blueprint-ref: .codex/esir/blueprints/terrain-evolution.md#scheduling
function model.ready(root,lane,tick)
    local w=root.work;w.ready_cursors=w.ready_cursors or {}
    for _=1,8 do
        w.observation_checks=(w.observation_checks or 0)+1
        local slot=(w.ready_cursors[lane] or 0)%64+1;w.ready_cursors[lane]=slot
        local r=w.observations[slot]
        if r and r.sample_tick and tick-r.sample_tick<=1200 and tick<=(r.ready_until or r.expires or tick)
            and r.surface.valid and root.surfaces[r.surface.index]==r.owner and r.owner.config.enabled then
            local cfg=r.owner.config
            if lane=="R" then
                if r.recovery_records and #r.recovery_records>0 and r.attempts<8 and r.clean_since and tick-r.clean_since>=cfg.clean_seconds*60 then return r end
            elseif lane=="S" then
                if r.schedule_owner and r.dirty_since and tick-r.dirty_since>=cfg.dirty_seconds*60 and tick>=(r.schedule.next_soil or 0) then return r end
            elseif r.schedule_owner then return r end
        end
    end
end
function model.request_recovery(root,entry,record,tick)
    local x,y=record.x,record.y
    if record.entity then local entity=lib.get_valid_entity(record.entity);if not entity then return end;x=entity.position.x;y=entity.position.y end
    local observation=model.observe(root,entry,math.floor(x/32),math.floor(y/32),"recovery",tick)
    if not observation then return end
    observation.recovery_records=observation.recovery_records or {};observation.recovery_keys=observation.recovery_keys or {}
    local identity=(record.entity and "tree:" or "tile:")..record.id
    if not observation.recovery_keys[identity] and #observation.recovery_records<8 then
        observation.recovery_records[#observation.recovery_records+1]=record;observation.recovery_keys[identity]=true
    end
    return observation
end
function model.observation(root,entry,x,y,tick)
    local w=root.work;local i=w.observation_keys[observation_id(entry,x,y)];local r=i and w.observations[i]
    if r and r.owner==entry and r.sample_tick and tick-r.sample_tick<=1200 and tick<=(r.ready_until or r.expires or tick) and r.attempts<8 then return r end
end
function model.sample_observation(root,budget,tick,sample)
    local w=root.work
    if w.observation_count==0 or budget.samples==0 then return end
    for _=1,64 do
        w.observation_cursor=w.observation_cursor%64+1
        local r=w.observations[w.observation_cursor]
        if r then
            local entry=r.surface.valid and root.surfaces[r.surface.index]
            if entry~=r.owner or not entry.config.enabled or tick>(r.ready_until or r.expires or tick) or r.attempts>=8 then
                release_observation(w,w.observation_cursor);return
            end
            budget.samples=budget.samples-1
            r.expires=r.expires or tick+r.dwell*60+1200
            if r.sample_tick and tick-r.sample_tick>1200 then r.clean_since=nil;r.dirty_since=nil;r.ready_until=nil end
            if not sample(root,r,tick) then release_observation(w,w.observation_cursor);return end
            local cfg=entry.config
            if r.schedule.draining and r.clean_since and tick-r.clean_since>=cfg.clean_seconds*60 then r.schedule.draining.soil=nil end
            if not r.clean_since and not r.dirty_since then
                r.neutral_since=r.neutral_since or tick
                if r.schedule.draining and (r.pollution==nil or tick-r.neutral_since>=math.max(cfg.clean_seconds,cfg.dirty_seconds)*60) then r.schedule.draining.soil=nil end
            else r.neutral_since=nil end
            if r.ready_kind and ((r.ready_kind=="clean" and not r.clean_since) or (r.ready_kind=="dirty" and not r.dirty_since)) then release_observation(w,w.observation_cursor);return end
            if not r.ready_until and ((r.clean_since and tick-r.clean_since>=cfg.clean_seconds*60)
                or (r.kind~="recovery" and r.dirty_since and tick-r.dirty_since>=cfg.dirty_seconds*60)) then
                local capacity=math.min(64,math.max(1,math.floor(1024/root.config.interval)))
                local gap=24*math.max(root.config.interval,root.config.search_interval)
                r.ready_until=tick+capacity*gap+1200
                r.ready_kind=r.clean_since and "clean" or "dirty"
            end
            return
        end
    end
end
function model.invalidate_chunk(root,entry,cell)
    local slot=root.work and root.work.observation_keys[entry.surface.index..":"..cell]
    if slot then release_observation(root.work,slot) end
end
function model.backoff(record,tick)
    record.retries=math.min(5,(record.retries or 0)+1)
    record.retry_tick=tick+math.min(3600,300*2^(record.retries-1))+math.abs((record.x or 0)*31+(record.y or 0)*17)%64
end
function model.remove_drill(root,id,tick)
    local w=root.work;local r=w and w.drills[id];if not r then return end
    local list=r.owner.drills;local n=r.slot;local last=list[#list]
    list[n]=last;list[#list]=nil
    if last and last~=id and w.drills[last] then w.drills[last].slot=n end
    w.drills[id]=nil;w.registrations[r.registration]=nil;w.drill_count=w.drill_count-1
    local job=w.jobs.revalidation
    if job and r.check_epoch~=w.epoch then job.remaining=job.remaining-1;job.completed=job.completed+1;r.owner.revalidation_remaining=math.max(0,(r.owner.revalidation_remaining or 0)-1) end
    if job and tick then
        if job.remaining<=0 then finish(root,"revalidation",tick) else member_state(root,"revalidation",r.owner,tick) end
    end
end
function model.register_drill(root,entity,tick)
    entity=lib.get_valid_entity(entity)
    if not entity or not drill_names[entity.name] then return false end
    local entry=root.surfaces[entity.surface.index];if not entry or entry.surface~=entity.surface then return false end
    local w=root.work;local id=entity.unit_number
    if not id or w.drills[id] then return false end
    if w.drill_count>=4096 then w.coverage_limited=w.coverage_limited+1;return false end
    entry.drills=entry.drills or {};entry.drills[#entry.drills+1]=id
    local registration=script.register_on_object_destroyed(entity)
    w.drills[id]={entity=entity,id=id,owner=entry,slot=#entry.drills,registration=registration,
        next_tick=tick+entry.config.periodic_mining_seconds*60/entry.config.intensity_multiplier+id%64,epoch=w.epoch,check_epoch=w.epoch,enable_epoch=entry.drill_epoch or 0}
    w.registrations[registration]=id;w.drill_count=w.drill_count+1
    return true
end
function model.relocate_drill(root,entity,tick)
    local id=lib.get_entity_unit_number(entity);local r=id and root.work.drills[id]
    if not r then return model.register_drill(root,entity,tick) end
    local entry=root.surfaces[entity.surface.index]
    if entry==r.owner then return end
    -- Reuse the existing native registration, including for silent teleports.
    local registration=r.registration;local deadline=r.next_tick
    model.remove_drill(root,id,tick)
    if not entry then return end
    entry.drills=entry.drills or {};entry.drills[#entry.drills+1]=id
    r.owner=entry;r.slot=#entry.drills;r.next_tick=deadline;r.check_epoch=root.work.epoch
    root.work.drills[id]=r;root.work.registrations[registration]=id;root.work.drill_count=root.work.drill_count+1
end
function model.service_drills(root,budget,tick,rate,scar)
    local w=root.work
    for _=1,math.min(4,root.config.histories,budget.candidates) do
        if #root.surface_order==0 or w.drill_count==0 then break end
        w.drill_surface_cursor=w.drill_surface_cursor%#root.surface_order+1
        local entry=root.surfaces[root.surface_order[w.drill_surface_cursor]]
        local list=entry and entry.drills
        if list and #list>0 and entry.config.enabled then
            entry.drill_cursor=(entry.drill_cursor or 0)%#list+1
            local r=w.drills[list[entry.drill_cursor]]
            budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
            local entity=lib.get_valid_entity(r.entity)
            if not entity or not drill_names[entity.name] or root.surfaces[r.owner.surface.index]~=r.owner then model.remove_drill(root,r.id,tick)
            else
                local job=w.jobs.revalidation
                if job and r.check_epoch~=w.epoch then r.check_epoch=w.epoch;job.remaining=job.remaining-1;job.completed=job.completed+1;entry.revalidation_remaining=math.max(0,(entry.revalidation_remaining or 0)-1);member_state(root,"revalidation",entry,tick) end
                if entity.surface~=r.owner.surface then model.relocate_drill(root,entity,tick)
                elseif entry.config.enabled then
                    local cfg=entry.config
                    if r.enable_epoch~=(entry.drill_epoch or 0) then
                        local interval=cfg.periodic_mining_seconds*60/rate(root,entity.surface,cfg,tick)
                        r.enable_epoch=entry.drill_epoch or 0;r.next_tick=tick+interval+r.id%64
                    elseif cfg.mining_scars and cfg.periodic_mining_scars and tick>=r.next_tick then
                        local interval=cfg.periodic_mining_seconds*60/rate(root,entity.surface,cfg,tick)
                        r.next_tick=tick+interval
                        local target=lib.get_valid_entity(entity.mining_target)
                        if entity.active and entity.status==defines.entity_status.working and target and target.surface==entity.surface
                            and target.type=="resource" and not target.prototype.infinite_resource
                            and math.random()<cfg.periodic_mining_probability then scar(root,entity.surface,target.position,tick,"working") end
                    end
                end
            end
        end
    end
    local job=w.jobs.revalidation
    if job then if job.remaining<=0 then finish(root,"revalidation",tick) else report(root,"revalidation",tick) end end
end
function model.discovery_visit(root,entry,chunk,tick)
    local bootstrap=entry.bootstrap;local job=root.work.jobs.bootstrap
    local member=bootstrap and not bootstrap.closed and job~=nil
    if member then
        if chunk then bootstrap.visits=bootstrap.visits+1;job.completed=job.completed+1 end
        if not chunk or bootstrap.visits>=100000 then
            bootstrap.closed=true;job.remaining=job.remaining-1
            if chunk then entry.coverage_status="visit-limit" end
        end
    end
    if chunk and entry.surface.is_chunk_generated(chunk) and not entry.drill_discovery then
            entry.drill_discovery={x=chunk.x,y=chunk.y,bootstrap=member}
        root.work.bootstrap_pending=root.work.bootstrap_pending+1
            if entry.drill_discovery.bootstrap then job.pending=(job.pending or 0)+1 end
    end
    if job then
        if job.remaining==0 and (job.pending or 0)==0 then finish(root,"bootstrap",tick)
        else member_state(root,"bootstrap",entry,tick) end
    end
end
function model.discovery_query(root,budget,tick,query,classify)
    local w=root.work
    for _=1,math.min(6,#root.surface_order) do
        w.discovery_cursor=(w.discovery_cursor or 0)%#root.surface_order+1
        local entry=root.surfaces[root.surface_order[w.discovery_cursor]];local pending=entry and entry.drill_discovery
        if pending and entry.config.enabled then
            if pending.classify then
                if not classify(root,budget,entry,pending.x,pending.y) then return false end
            else
            local found=query(root,budget,entry.surface,{name=policy.drills,area={{pending.x*32,pending.y*32},{pending.x*32+32,pending.y*32+32}}})
            if not found then return false end
            if #found>=root.config.result_limit then entry.coverage_status="dense-chunk";w.coverage_limited=w.coverage_limited+1 end
            for _,entity in ipairs(found) do
                if budget.candidates==0 then entry.coverage_status="candidate-limit";break end
                budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
                model.register_drill(root,entity,tick)
            end
            if entry.planet=="gaia" then pending.classify=true;return true end
            end
            entry.drill_discovery=nil;w.bootstrap_pending=math.max(0,w.bootstrap_pending-1)
            local job=w.jobs.bootstrap
            if job and pending.bootstrap then job.pending=math.max(0,(job.pending or 0)-1) end
            if job and job.remaining==0 and (job.pending or 0)==0 then finish(root,"bootstrap",tick) end
            if w.jobs.bootstrap then member_state(root,"bootstrap",entry,tick) end
            return true
        end
    end
    return false
end
function model.surface_removed(root,entry,tick)
    local w=root.work;if not w then return end
    for i=1,64 do if w.observations[i] and w.observations[i].owner==entry then release_observation(w,i) end end
    if entry.drill_discovery then
        w.bootstrap_pending=math.max(0,w.bootstrap_pending-1)
        if w.jobs.bootstrap and entry.drill_discovery.bootstrap then w.jobs.bootstrap.pending=math.max(0,(w.jobs.bootstrap.pending or 0)-1) end
        entry.drill_discovery=nil
    end
    local job=w.jobs.bootstrap
    if job and entry.bootstrap and not entry.bootstrap.closed then entry.bootstrap.closed=true;job.remaining=math.max(0,job.remaining-1) end
    if job then
        if job.remaining==0 and (job.pending or 0)==0 then finish(root,"bootstrap",tick)
        else member_state(root,"bootstrap",entry,tick) end
    end
    -- Drill handles are retired by the bounded global validation cursor below.
    if entry.drills and #entry.drills>0 and not entry.retired then
        entry.retired=true;w.retired_surfaces=w.retired_surfaces or {};w.retired_tail=(w.retired_tail or 0)+1;w.retired_head=w.retired_head or 1;w.retired_surfaces[w.retired_tail]=entry
    end
    if w.jobs.revalidation then member_state(root,"revalidation",entry,tick) end
end
function model.cleanup(root,budget,tick)
    local w=root.work;local retired=w.retired_surfaces
    if not w.jobs.maintenance and (w.external_maintenance or retired and w.retired_head<=w.retired_tail) then
        local sources={};for key,source in pairs(w.external_maintenance or {}) do sources[#sources+1]=source;w.external_maintenance[key]=nil end
        w.external_maintenance=nil
        local synchronous=not retired or w.retired_head>w.retired_tail
        for _,source in ipairs(sources) do if not source.done then synchronous=false end end
        begin(root,"maintenance",tick,{phase="records",reason="state-maintenance",completed=0,total=false,last_member=w.retired_tail or 0,sources=sources,synchronous=synchronous})
    end
    if retired and w.retired_head<=w.retired_tail then
        local job=w.jobs.maintenance
        local entry=retired[w.retired_head]
        for _=1,math.min(4,budget.candidates) do
            if w.retired_head>job.last_member then break end
            if not entry.drills or #entry.drills==0 then retired[w.retired_head]=nil;w.retired_head=w.retired_head+1;break end
            budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
            model.remove_drill(root,entry.drills[#entry.drills],tick);w.jobs.maintenance.completed=w.jobs.maintenance.completed+1
        end
    end
    local maintenance=w.jobs.maintenance
    if maintenance then
        local done=(w.retired_head or 1)>maintenance.last_member
        for _,source in ipairs(maintenance.sources or {}) do
            maintenance.completed=maintenance.completed+source.completed-(source.reported or 0);source.reported=source.completed
            if not source.done then done=false end
        end
        if done then finish(root,"maintenance",tick) else report(root,"maintenance",tick) end
        if done and retired and w.retired_head>w.retired_tail then w.retired_head=1;w.retired_tail=0 end
    end
    local job=w.jobs.bootstrap
    if job then
        if job.remaining==0 and (job.pending or 0)==0 then finish(root,"bootstrap",tick)
        else report(root,"bootstrap",tick) end
    end
    local validation=w.jobs.revalidation
    if validation and validation.remaining<=0 then finish(root,"revalidation",tick) end
end
-- Callers own finite cursors; reporting receives scalars and never inspects them.
function model.maintenance_begin(root,name,total,tick)
    local source={name=name,total=total,completed=0,done=total==0}
    local w=root.work;w.external_maintenance=w.external_maintenance or {};w.external_maintenance[name]=source
    return source
end
function model.maintenance_update(root,source,completed,done,tick)
    if not source or source.done then return end
    source.completed=completed;source.done=done
end
function model.has_maintenance(root)
    local w=root and root.work
    return w and (w.jobs.migration~=nil or w.jobs.maintenance~=nil or w.external_maintenance~=nil or (w.retired_surfaces and w.retired_head<=w.retired_tail)) or false
end
function model.jobs(root)
    local result={};if not root.work then return result end
    for _,operation in ipairs(operations) do local job=root.work.jobs[operation];if job then result[#result+1]={operation=operation,phase=job.phase,completed=job.completed,total=job.total,state=job.state or "running",blocked=job.blocked} end end
    return result
end
return model
