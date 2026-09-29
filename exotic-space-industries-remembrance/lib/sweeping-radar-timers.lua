--==============================================================================
-- ESIR FILE MAP
-- owns: indexed radar deadlines, one entry per owner/purpose, no stale history
-- loaded_by: sweeping-radar runtime
-- cadence: bounded admission by caller; heap updates are logarithmic in population
-- Shared scheduler delayed buckets append entries. Radar circuit churn needs
-- cancellation/rescheduling in place, so this feature owns an indexed deadline heap.
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local timers={}
function timers.new() return {heap={},entries={}} end
local function before(a,b) return a.tick<b.tick or (a.tick==b.tick and a.key<b.key) end
local function swap(heap,a,b)
    heap[a],heap[b]=heap[b],heap[a];heap[a].index=a;heap[b].index=b
end
local function repair(heap,index)
    while index>1 do
        local parent=math.floor(index/2)
        if not before(heap[index],heap[parent]) then break end
        swap(heap,index,parent);index=parent
    end
    while index*2<=#heap do
        local child=index*2
        if child<#heap and before(heap[child+1],heap[child]) then child=child+1 end
        if not before(heap[child],heap[index]) then break end
        swap(heap,index,child);index=child
    end
end
function timers.cancel(state,key)
    local entry=state.entries[key]
    if not entry then return end
    local heap,index=state.heap,entry.index
    state.entries[key]=nil
    if index==#heap then heap[index]=nil
    else heap[index]=heap[#heap];heap[#heap]=nil;heap[index].index=index;repair(heap,index) end
end
function timers.set(state,id,kind,tick)
    local key=id..":"..kind
    if not tick then timers.cancel(state,key);return end
    local entry=state.entries[key]
    if entry then
        if entry.tick==tick then return end
        entry.tick=tick;repair(state.heap,entry.index)
    else
        entry={id=id,kind=kind,tick=tick,key=key,index=#state.heap+1}
        state.entries[key]=entry;state.heap[entry.index]=entry;repair(state.heap,entry.index)
    end
end
function timers.take_due(state,tick)
    local entry=state.heap[1]
    if not entry or entry.tick>tick then return nil end
    timers.cancel(state,entry.key)
    return entry
end
return timers
