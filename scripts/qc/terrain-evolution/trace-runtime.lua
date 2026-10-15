-- Staged inside the terrain owner only for diagnostic attribution. These nested
-- timers/logs add overhead and must never be used as release timing evidence.
local function ecology_trace(name,operation)
    return function(root,...)
        if not root.__qc_trace_until or (root.__qc_trace_tick or 0)>root.__qc_trace_until
            or (root.__qc_trace_tick or 0)<(root.__qc_trace_from or 0) then return operation(root,...) end
        local timer=helpers.create_profiler()
        local result=operation(root,...)
        timer.stop()
        log({"","ECOLOGY_COMPONENT name="..name.." tick="..root.__qc_trace_tick.." elapsed=",timer})
        return result
    end
end
query=ecology_trace("query",query)
propose=ecology_trace("propose",propose)
commit=ecology_trace("commit",commit)
service_class=ecology_trace("class",service_class)
recover_tiles=ecology_trace("tile_history",recover_tiles)
recover_trees=ecology_trace("tree_history",recover_trees)
service_events=ecology_trace("events",service_events)
discover=ecology_trace("discovery",discover)
work.ready=ecology_trace("ready",work.ready)
work.service_drills=ecology_trace("drills",work.service_drills)
work.sample_observation=ecology_trace("observation",work.sample_observation)
work.cleanup=ecology_trace("cleanup",work.cleanup)

-- Split the large owned-history insertion without rebuilding or walking it.
-- Logging is delayed until all three operations finish so sibling log calls
-- cannot be charged to the array/index/count_record timers.
local ecology_original_put=put
put=function(set,id,record)
    local root=peek()
    if not root or set~=root.history or not root.__qc_trace_until
        or (root.__qc_trace_tick or 0)>root.__qc_trace_until or (root.__qc_trace_tick or 0)<(root.__qc_trace_from or 0) then
        return ecology_original_put(set,id,record)
    end
    if set.index[id] then return false end
    local before=#set.items
    record.id=id;record.ecology_version=2
    local array=helpers.create_profiler()
    set.items[#set.items+1]=record
    array.stop()
    local index=helpers.create_profiler()
    set.index[id]=#set.items
    index.stop()
    local counted=helpers.create_profiler()
    work.count_record(root,record,set.kind)
    counted.stop()
    local suffix=" size_before="..before.." id="..id
    log({"","ECOLOGY_COMPONENT name=history_array tick="..root.__qc_trace_tick.." elapsed=",array,suffix})
    log({"","ECOLOGY_COMPONENT name=history_index tick="..root.__qc_trace_tick.." elapsed=",index,suffix})
    log({"","ECOLOGY_COMPONENT name=history_count_record tick="..root.__qc_trace_tick.." elapsed=",counted,suffix})
    return true
end

local ecology_original_attach=attach_chunk
attach_chunk=function(record)
    local root=peek()
    if not root or not root.__qc_trace_until
        or (root.__qc_trace_tick or 0)>root.__qc_trace_until or (root.__qc_trace_tick or 0)<(root.__qc_trace_from or 0) then return ecology_original_attach(record) end
    local existed=record.owner.chunk_tokens[record.chunk_cell]~=nil
    local timer=helpers.create_profiler()
    ecology_original_attach(record)
    timer.stop()
    log({"","ECOLOGY_COMPONENT name=attach_chunk tick="..root.__qc_trace_tick.." elapsed=",timer,
        " surface="..record.owner.surface.index.." cell="..record.chunk_cell.." existing="..tostring(existed)})
end

work.discovery_visit=ecology_trace("discovery_visit",work.discovery_visit)
work.observe=ecology_trace("observe",work.observe)
-- active returns TWO values; the generic one-result trace wrapper is unsuitable.
local ecology_original_active=active
active=function(root,...)
    if not root.__qc_trace_until or (root.__qc_trace_tick or 0)>root.__qc_trace_until or (root.__qc_trace_tick or 0)<(root.__qc_trace_from or 0) then
        return ecology_original_active(root,...)
    end
    local timer=helpers.create_profiler()
    local record,created=ecology_original_active(root,...)
    timer.stop()
    log({"","ECOLOGY_COMPONENT name=active_admission tick="..root.__qc_trace_tick.." elapsed=",timer,
        " active="..#root.active.items.." created="..tostring(created==true)})
    return record,created
end
