--==============================================================================
-- ESIR FILE MAP
-- owns: bucketed dense-set lookups and constant-time legacy index adoption
-- loaded_by: terrain-evolution.lua, terrain-ecology-work.lua
-- cadence: owner calls; no event registration or scheduler
-- forwarded_events: none
-- storage_roots: storage.ei.terrain_evolution domain-set indexes
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: owner-budgeted legacy conversion
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
-- Dense arrays remain authoritative. Callers use index[id], never pairs(index).
-- Registered metadata restores lookups on load without storage mutation.
---@class EsirTerrainIndex
---@field buckets table<integer, table<string, integer>>
---@field legacy table<string, integer>?
---@field remaining integer Legacy positions still awaiting conversion.
local model={}
local function bucket_number(id)
    local hash=0
    for i=1,#id do hash=(hash*33+string.byte(id,i))%256 end
    return hash+1
end
local function read(index,id)
    local buckets=rawget(index,"buckets")
    local bucket=buckets[bucket_number(id)]
    local value=bucket and bucket[id]
    if value~=nil then return value end
    local legacy=rawget(index,"legacy")
    return legacy and legacy[id]
end
local function write(index,id,value)
    local legacy=rawget(index,"legacy")
    -- Never insert a new key into the former large flat hash table.
    if legacy and legacy[id]~=nil then
        legacy[id]=nil
        local remaining=rawget(index,"remaining")-1
        rawset(index,"remaining",remaining)
        if remaining==0 then rawset(index,"legacy",nil) end
    end
    local buckets=rawget(index,"buckets")
    local number=bucket_number(id)
    local bucket=buckets[number]
    if value~=nil then
        if not bucket then bucket={};buckets[number]=bucket end
        bucket[id]=value
    elseif bucket then bucket[id]=nil end
end
local metatable={__index=read,__newindex=write}
-- The production module is runtime-only; the nil-script branch supports Lua QC.
if script and script.register_metatable then script.register_metatable("ei-terrain-index-v1",metatable) end

---@return EsirTerrainIndex
function model.new()
    return setmetatable({buckets={},remaining=0},metatable)
end
function model.is_facade(index)
    return type(index)=="table" and type(rawget(index,"buckets"))=="table"
        and type(rawget(index,"remaining"))=="number"
end
-- O(1) adoption: retain the existing table, never add a marker to that full table.
-- Dense-set membership is authoritative; plain indexes have exactly one live
-- position per member. Already-adopted saves retain their original pending count.
---@param set EsirTerrainSet
---@return integer
function model.adopt(set)
    if model.is_facade(set.index) then
        setmetatable(set.index,metatable)
        return 0
    end
    local count=#set.items
    set.index=setmetatable({buckets={},legacy=count>0 and set.index or nil,remaining=count},metatable)
    return count
end
---@param index table
---@return integer
function model.remaining(index)
    return model.is_facade(index) and rawget(index,"remaining") or 0
end
-- One existing dense-record inspection converts at most one old lookup entry.
---@param index EsirTerrainIndex
---@param id string
---@return boolean
function model.migrate(index,id)
    local legacy=rawget(index,"legacy")
    local value=legacy and legacy[id]
    if value==nil then return false end
    write(index,id,value)
    return true
end
return model
