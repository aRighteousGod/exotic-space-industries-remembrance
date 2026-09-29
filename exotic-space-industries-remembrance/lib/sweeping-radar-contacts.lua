--==============================================================================
-- ESIR FILE MAP
-- owns: bounded last-seen contact summaries with indexed expiry/distance heaps
-- loaded_by: scripts/control/sweeping-radar; isolated contact QC
-- cadence: one record operation; each heap repair is at most log2(2048) levels
--==============================================================================
-- blueprint: .codex/esir/blueprints/sweeping-radar.md#contract
local contacts={}
---@class ESIRRadarContact
---@field id string
---@field x number
---@field y number
---@field distance2 number
---@field bearing number
---@field tick integer
---@field expires number
---@field ei integer Expiry heap index.
---@field ni integer Nearest heap index.

---@class ESIRRadarContactSet
---@field records table<string,ESIRRadarContact>
---@field expiry ESIRRadarContact[]
---@field nearest ESIRRadarContact[]
---@field count integer
---@field incomplete boolean
---@field incomplete_until integer?
---@field valid boolean
---@field tick integer Latest sample tick.
---@field published_tick integer?
local LIMIT=require("lib/sweeping-radar-config").contact_limit

---@return ESIRRadarContactSet
function contacts.new()
    return {records={},expiry={},nearest={},count=0,incomplete=false,tick=0,valid=false}
end

local function less(a,b,key)
    local x,y=a[key],b[key]
    return x<y or (x==y and a.id<b.id)
end

local function swap(heap,a,b,index)
    heap[a],heap[b]=heap[b],heap[a]
    heap[a][index],heap[b][index]=a,b
end

local function repair(heap,i,key,index)
    while i>1 do
        local parent=math.floor(i/2)
        if not less(heap[i],heap[parent],key) then break end
        swap(heap,i,parent,index);i=parent
    end
    while i*2<=#heap do
        local child=i*2
        if child+1<=#heap and less(heap[child+1],heap[child],key) then child=child+1 end
        if not less(heap[child],heap[i],key) then break end
        swap(heap,i,child,index);i=child
    end
end

local function remove(heap,i,key,index)
    local last=#heap
    if i==last then heap[last]=nil;return end
    heap[i]=heap[last];heap[last]=nil;heap[i][index]=i
    repair(heap,i,key,index)
end

function contacts.delete(set,record)
    remove(set.expiry,record.ei,"expires","ei")
    remove(set.nearest,record.ni,"distance2","ni")
    set.records[record.id]=nil
    set.count=set.count-1
end

---@param set table
---@param sample table Primitive snapshot; never a live LuaEntity.
---@param expiry_tick integer
---@return boolean
function contacts.observe(set,sample,expiry_tick)
    local record=set.records[sample.id]
    if not record then
        if set.count>=LIMIT then set.incomplete=true;return false end
        record={id=sample.id}
        set.records[sample.id]=record
        set.count=set.count+1
        record.ei=#set.expiry+1;set.expiry[record.ei]=record
        record.ni=#set.nearest+1;set.nearest[record.ni]=record
    end
    record.x,record.y=sample.x,sample.y
    record.distance2,record.bearing=sample.distance2,sample.bearing
    record.tick,record.expires=sample.tick,expiry_tick
    repair(set.expiry,record.ei,"expires","ei")
    repair(set.nearest,record.ni,"distance2","ni")
    set.tick=math.max(set.tick,sample.tick)
    return true
end

function contacts.has_expired(set,tick)
    return set and set.expiry[1] and set.expiry[1].expires<=tick or false
end

---A complete two-heap deletion is one bounded record operation.
function contacts.expire_one(set,tick)
    if not contacts.has_expired(set,tick) then return false end
    contacts.delete(set,set.expiry[1])
    return true
end

function contacts.retire_one(set)
    if not set or set.count==0 then return false end
    contacts.delete(set,set.expiry[1])
    return true
end

function contacts.snapshot(set,tick)
    local nearest=set.nearest[1]
    return {valid=set.valid,count=set.count,incomplete=set.incomplete,
        bearing=nearest and math.floor(nearest.bearing+0.5)%360 or 0,
        distance=nearest and math.floor(math.sqrt(nearest.distance2)+0.5) or 0,
        age=math.max(0,math.floor((tick-(set.published_tick or set.tick))/60)),
        sample_age=math.max(0,math.floor((tick-set.tick)/60)),
        contact_age=nearest and math.max(0,math.floor((tick-nearest.tick)/60)) or 0}
end
return contacts
