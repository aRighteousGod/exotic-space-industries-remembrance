-- Private native entity fixtures. Production services run with a one-slot budget.
-- The checkpoint hold is injected only to freeze a pending native iterator at save.
local fixture = {}
local LIMIT = 20000
local owner_storage, pending_delete

---@param check fun(name:string, passed:boolean, detail:any?):boolean
---@param fluid table Actual production fluid owner with private observers.
---@param tick uint
---@param predicate function|nil
---@return uint calls
local function service_until(check,fluid,tick,predicate,label)
    local probe=owner_storage.esir_native_options_fluid_probe
    local bounded,one_query=true,true
    local calls=0
    while calls<LIMIT do
        local job=fluid.ensure_fluid_runtime().ignore_reconcile
        if not job or (predicate and predicate(job)) then break end
        local before=probe.queries
        local used=fluid.service_fluid_runtime(1,tick)
        calls=calls+1
        bounded=bounded and used>=0 and used<=1
        one_query=one_query and probe.queries-before<=1
    end
    check(label.."-terminates",calls<LIMIT,calls)
    check(label.."-one-slot-budget",bounded)
    check(label.."-at-most-one-chunk-query",one_query)
    return calls
end

---@param name string
---@return LuaSurface
local function surface(name)
    local created=game.create_surface(name,{width=128,height=128,peaceful_mode=true,
        autoplace_settings={entity={treat_missing_as_default=false,settings={}},
            decorative={treat_missing_as_default=false,settings={}}}})
    created.request_to_generate_chunks({0,0},2)
    created.force_generate_chunk_requests()
    return created
end

---@param target LuaSurface
---@param name string
---@param x number
---@param y number
---@return LuaEntity
local function create(target,name,x,y)
    local tiles={}
    for dx=-2,2 do for dy=-2,2 do
        tiles[#tiles+1]={name="refined-concrete",position={x+dx,y+dy}}
    end end
    target.set_tiles(tiles)
    local entity=target.create_entity{name=name,position={x,y},force="player",raise_built=true}
    assert(entity,"Native fluid fixture creation failed")
    return entity
end

---@param check function
---@param apply function
---@param options table
---@param catalog table
---@param fluid table
---@param tick uint
function fixture.candidate(check,apply,options,catalog,fluid,tick,native_storage)
    owner_storage=native_storage
    local id=catalog.runtime_name("ei-fluid-safety-ignored-entities")
    local original,probe,target,doomed,after,anchor,survivor,pipes,after_pipe,runtime,anchor_unit,tail_unit
    local anchor_index,survivor_entry,survivor_segment,aftermath_stats,job,late,query_before
    if not pending_delete then
    original=settings.global[id].value
    probe={queries=0,rebuilds=0,hold=false}
    owner_storage.esir_native_options_fluid_probe=probe
    apply({[id]=""},tick,"fluid-test-eligible")
    service_until(check,fluid,tick,nil,"fluid-prior-edit-drain")
    target=surface("esir-options-fluid-world")
    doomed=surface("esir-options-fluid-deleted")
    after=surface("esir-options-fluid-after-deleted")
    anchor=create(target,"storage-tank",-40,-20)
    survivor=create(target,"storage-tank",-30,-20)
    pipes={create(target,"pipe",-40,10),create(target,"pipe",0,10),create(target,"pipe",40,10)}
    after_pipe=create(after,"pipe",40,10)
    runtime=fluid.ensure_fluid_runtime()
    anchor_unit,tail_unit=anchor.unit_number,after_pipe.unit_number
    anchor_index=assert(runtime.entries_by_unit[anchor_unit]).dense_index
    survivor_entry=assert(runtime.entries_by_unit[survivor.unit_number])
    survivor_segment=runtime.segments[survivor_entry.last_segment_id]
    aftermath_stats=runtime.aftermath_stats
    check("fluid-native-build-events-register",runtime.entries_by_unit[pipes[1].unit_number]~=nil
        and runtime.scan_units[#runtime.scan_units]==tail_unit)
    apply({[id]="pipe"},tick,"fluid-ignore-native-pipes")
    service_until(check,fluid,tick,function(job) return job.scan and job.scan>anchor_index end,"fluid-partial-removal")
    job=assert(runtime.ignore_reconcile)
    check("fluid-partial-removal-cursor-passed-anchor",job.scan and job.scan>anchor_index)
    check("fluid-unvisited-ignored-tail-present",runtime.entries_by_unit[tail_unit]~=nil)
    anchor.destroy{raise_destroy=true}
    check("fluid-native-destroy-removes-visited-anchor",runtime.entries_by_unit[anchor_unit]==nil)
    check("fluid-dense-swap-moves-ignored-tail",runtime.scan_units[anchor_index]==tail_unit)
    check("fluid-dense-swap-rewinds-live-cursor",job.scan and job.scan<=anchor_index)
    service_until(check,fluid,tick,nil,"fluid-removal-after-dense-swap")
    local none=true
    for _,entry in pairs(runtime.entries_by_unit) do
        if entry.entity.valid and entry.entity.name=="pipe" then none=false end
    end
    check("fluid-all-ignored-native-pipes-removed",none and runtime.entries_by_unit[tail_unit]==nil)
    check("fluid-live-edit-preserves-runtime-owner",fluid.ensure_fluid_runtime()==runtime and probe.rebuilds==0)
    check("fluid-live-edit-preserves-unrelated-segment",runtime.entries_by_unit[survivor.unit_number]==survivor_entry
        and runtime.segments[survivor_entry.last_segment_id]==survivor_segment)
    check("fluid-live-edit-preserves-aftermath-ledger",runtime.aftermath_stats==aftermath_stats)

    late=create(target,"pipe",40,20)
    check("fluid-build-while-ignored-not-admitted",runtime.entries_by_unit[late.unit_number]==nil)
    apply({[id]=""},tick,"fluid-unignore-pending")
    fluid.service_fluid_runtime(1,tick)
    apply({[id]="pipe"},tick,"fluid-reignore-before-discovery")
    service_until(check,fluid,tick,nil,"fluid-coalesced-removal")
    check("fluid-coalesced-edit-does-not-admit-stale-names",runtime.entries_by_unit[late.unit_number]==nil
        and runtime.entries_by_unit[tail_unit]==nil)

    query_before=probe.queries
    apply({[id]=""},tick,"fluid-unignore-across-chunks")
    service_until(check,fluid,tick,function(pending) return pending.surface_index==doomed.index end,"fluid-select-deleted-surface")
    check("fluid-selected-native-chunk-iterator",runtime.ignore_reconcile and runtime.ignore_reconcile.iterator
        and runtime.ignore_reconcile.iterator.valid)
    local doomed_index=doomed.index
    check("fluid-selected-surface-deletion-queued",game.delete_surface(doomed))
    probe.hold=true
    pending_delete={original=original,probe=probe,target=target,pipes=pipes,late=late,tail_unit=tail_unit,
        runtime=runtime,doomed_index=doomed_index,query_before=query_before,requested_tick=tick}
    return false
    end
    local pending=pending_delete
    if game.get_surface(pending.doomed_index) and tick-pending.requested_tick<120 then return false end
    check("fluid-selected-surface-deleted",game.get_surface(pending.doomed_index)==nil)
    original,probe,target,pipes,late,tail_unit,runtime,query_before=pending.original,pending.probe,pending.target,
        pending.pipes,pending.late,pending.tail_unit,pending.runtime,pending.query_before
    probe.hold=false
    service_until(check,fluid,tick,nil,"fluid-discovery-after-surface-delete")
    local all=true
    for index,entity in ipairs(pipes) do
        local admitted=entity.valid and runtime.entries_by_unit[entity.unit_number]~=nil
        check("fluid-unignore-discovers-native-pipe-"..index,admitted)
        all=all and admitted
    end
    check("fluid-unignore-discovers-existing-pipes-across-chunks",all)
    check("fluid-unignore-observes-multiple-chunk-queries",probe.queries-query_before>=3,probe.queries-query_before)
    check("fluid-unignore-discovers-build-while-ignored",runtime.entries_by_unit[late.unit_number]~=nil)
    check("fluid-deleted-surface-does-not-block-later-surface",runtime.entries_by_unit[tail_unit]~=nil)
    check("fluid-discovery-does-not-rebuild-world",probe.rebuilds==0 and fluid.ensure_fluid_runtime()==runtime)

    -- Leave a real LuaChunkIterator and native entity queue pending for checkpoint.
    apply({[id]="pipe"},tick,"fluid-checkpoint-ignore")
    service_until(check,fluid,tick,nil,"fluid-checkpoint-removal")
    apply({[id]=""},tick,"fluid-checkpoint-unignore")
    service_until(check,fluid,tick,function(pending) return pending.surface_index==target.index end,"fluid-checkpoint-select-surface")
    fluid.service_fluid_runtime(1,tick)
    job=assert(runtime.ignore_reconcile)
    check("fluid-checkpoint-pending-native-iterator",job.iterator and job.iterator.valid and job.surface_index==target.index)
    local units={late.unit_number,tail_unit}
    for _,entity in ipairs(pipes) do units[#units+1]=entity.unit_number end
    owner_storage.esir_native_options_fluid_saved={original=original,id=id,units=units,
        surface_index=job.surface_index,queries=probe.queries,rebuilds=probe.rebuilds}
    probe.hold=true
    check("fluid-checkpoint-hold-preserves-pending-work",runtime.ignore_reconcile~=nil)
    return true
end

---@param check function
---@param fluid table
---@param tick uint
---@param phase string
function fixture.reload(check,fluid,tick,phase,native_storage)
    owner_storage=native_storage
    local saved=assert(owner_storage.esir_native_options_fluid_saved,"Missing native fluid checkpoint")
    local probe=assert(owner_storage.esir_native_options_fluid_probe)
    local runtime=fluid.ensure_fluid_runtime()
    if phase=="reload" then
        local job=runtime.ignore_reconcile
        check("fluid-ordinary-reload-preserves-pending-iterator",job and job.surface_index==saved.surface_index
            and job.iterator and job.iterator.valid)
        check("fluid-ordinary-reload-did-not-rebuild",probe.rebuilds==saved.rebuilds)
        check("fluid-checkpoint-hold-blocked-background-queries",probe.queries==saved.queries)
    else
        check("fluid-configuration-rebuilds-with-new-ignore-values",probe.rebuilds>saved.rebuilds
            and not runtime.ignored_names.pipe)
    end
    probe.hold=false
    service_until(check,fluid,tick,nil,"fluid-reload-discovery-resumes")
    local all=true
    for _,unit in ipairs(saved.units) do all=all and runtime.entries_by_unit[unit]~=nil end
    check("fluid-reload-discovers-every-pending-native-pipe",all)
    check("fluid-reload-finishes-pending-job",runtime.ignore_reconcile==nil)
end

return fixture
