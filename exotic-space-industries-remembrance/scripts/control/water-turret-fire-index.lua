--==============================================================================
-- ESIR FILE MAP
-- owns: covered-chunk fire index, lifecycle seeding, stable search views
-- loaded_by: control/water-turret
-- cadence: event admission; bounded wake, bootstrap and cold maintenance service
-- storage_roots: storage.ei.water_turret.index
--==============================================================================
-- blueprint: .codex/esir/blueprints/firefighting-and-water-turret.md#contract
local lib=require("lib/lib")
local scheduler=require("lib/runtime-scheduler")
local config=require("lib/firefighting-config")
local flames=require("lib/flamethrower-fuels")
local model={}
local CELL=8

---@class ESIRWaterIndexList
---@field items table<integer,integer|false>
---@field slots table<integer,integer>
---@field tail integer
---@field count integer
---@field bucket ESIRWaterChunk
---@field builder table?
---@class ESIRWaterChunk
---@field surface integer
---@field x integer
---@field y integer
---@field key string
---@field active boolean
---@field thermal ESIRWaterIndexList
---@field weapon ESIRWaterIndexList
---@field watchers ESIRWaterIndexList
---@field weapon_count integer
---@field generation integer
---@field coverage_generation integer
---@field seeded_thermal boolean?
---@field seeded_weapon boolean?
---@field seed_pending boolean?
---@field wake table?
---@field cells table<string,table> Exact circle coverage, refined only for birth rejection.
---@class ESIRWaterFireIndex
---@field surfaces table<integer,table<string,ESIRWaterChunk>>
---@field fires table<integer,table>
---@field count integer
---@field wakes table
---@field seeds table
---@field maintenance table
---@return ESIRWaterFireIndex
function model.new()
    return {surfaces={},fires={},count=0,wakes=scheduler.ensure_queue(),
        seeds=scheduler.ensure_queue(),maintenance=scheduler.ensure_queue()}
end

---@param bucket ESIRWaterChunk
---@return ESIRWaterIndexList
local function new_list(bucket)
    return {items={},slots={},tail=0,count=0,bucket=bucket}
end

---@param list ESIRWaterIndexList
---@param id integer
local function add(list,id)
    if list.slots[id] then return end
    list.tail=list.tail+1;list.items[list.tail]=id;list.slots[id]=list.tail;list.count=list.count+1
    local b=list.builder
    if b and not b.slots[id] then b.items[#b.items+1]=id;b.slots[id]=#b.items end
end

---@param root ESIRWaterState
---@param list ESIRWaterIndexList
---@param id integer
local function remove(root,list,id)
    local slot=list.slots[id]
    if not slot then return end
    list.items[slot]=false;list.slots[id]=nil;list.count=list.count-1
    local b=list.builder
    local at=b and b.slots[id]
    if at then
        local last=b.items[#b.items]
        b.items[at]=last;b.slots[last]=at;b.items[#b.items]=nil;b.slots[id]=nil
    end
    if list.tail>config.slice_size and list.count*2<list.tail then
        scheduler.queue_push_unique(root.index.maintenance,list)
    end
end

---@param root ESIRWaterState
---@param bucket ESIRWaterChunk
local function wake(root,bucket)
    bucket.generation=bucket.generation+1
    if not bucket.wake then
        bucket.wake={items=bucket.watchers.items,tail=bucket.watchers.tail,cursor=1,generation=bucket.generation}
        scheduler.queue_push(root.index.wakes,bucket)
    end
end

---@param root ESIRWaterState
---@param bucket ESIRWaterChunk
local function finish_seed_rebuild(root,bucket)
    local rebuild=root.rebuild
    if rebuild and bucket.rebuild_generation==rebuild.generation then
        bucket.rebuild_generation=nil;rebuild.completed=rebuild.completed+1
    end
end

local function seed(root,bucket)
    if bucket.seeded_thermal and (bucket.weapon_count==0 or bucket.seeded_weapon) then return end
    local rebuild=root.rebuild
    if rebuild and rebuild.accepting and bucket.rebuild_generation~=rebuild.generation then
        bucket.rebuild_generation=rebuild.generation;rebuild.total=rebuild.total+1
    end
    if bucket.seed_pending then return end
    bucket.seed_pending=true;scheduler.queue_push(root.index.seeds,bucket)
end

---@param root ESIRWaterState
---@param surface integer
---@param x integer
---@param y integer
---@param create boolean?
---@return ESIRWaterChunk?
local function chunk(root,surface,x,y,create)
    local index=root.index
    local map=index.surfaces[surface]
    if not map then
        if not create then return end
        map={};index.surfaces[surface]=map
    end
    local key=x..":"..y
    local b=map[key]
    if not b and create then
        b={surface=surface,x=x,y=y,key=key,active=true,weapon_count=0,generation=0,coverage_generation=0,cells={}}
        b.thermal=new_list(b);b.weapon=new_list(b);b.watchers=new_list(b);map[key]=b
    end
    return b
end

-- blueprint-ref: .codex/esir/blueprints/firefighting-and-water-turret.md#birth-coverage
-- Lifecycle work caches full cells and boundary circles. Births never fan out
-- through turret records: interior hits are O(1), edge hits test cached geometry.
---@param bucket ESIRWaterChunk
---@param record ESIRWaterRecord
---@param adding boolean
local function coverage_cells(bucket,record,adding)
    local a=record.position
    local radius2=record.range^2
    local circle={x=a.x,y=a.y,radius=record.range,radius2=radius2,weapon=record.weapon_fires}
    local expanded_thermal,expanded_weapon=false,false
    local n=config.chunk_size/CELL
    for x=bucket.x*n,(bucket.x+1)*n-1 do for y=bucket.y*n,(bucket.y+1)*n-1 do
        local dx=math.max(x*CELL-a.x,0,a.x-(x+1)*CELL)
        local dy=math.max(y*CELL-a.y,0,a.y-(y+1)*CELL)
        if dx*dx+dy*dy<=radius2 then
            local key=x..":"..y
            local c=bucket.cells[key]
            if adding and not c then c={count=0,full=0,weapon_full=0,boundary={}};bucket.cells[key]=c end
            if c then
                if adding then
                    local thermal,weapon=c.full>0,c.weapon_full>0
                    for _,prior in pairs(c.boundary) do
                        if prior.radius>=circle.radius and (a.x-prior.x)^2+(a.y-prior.y)^2<=(prior.radius-circle.radius)^2 then
                            thermal=true;if prior.weapon then weapon=true end
                        end
                    end
                    expanded_thermal=expanded_thermal or not thermal
                    expanded_weapon=expanded_weapon or (record.weapon_fires and not weapon)
                end
                local fx=math.max(math.abs(x*CELL-a.x),math.abs((x+1)*CELL-a.x))
                local fy=math.max(math.abs(y*CELL-a.y),math.abs((y+1)*CELL-a.y))
                local change=adding and 1 or -1
                c.count=c.count+change
                if fx*fx+fy*fy<=radius2 then
                    c.full=c.full+change
                    if record.weapon_fires then c.weapon_full=c.weapon_full+change end
                else c.boundary[record.id]=adding and circle or nil end
                if c.count==0 then bucket.cells[key]=nil end
            end
        end
    end end
    if expanded_thermal or expanded_weapon then
        bucket.coverage_generation=bucket.coverage_generation+1
        if expanded_thermal then bucket.seeded_thermal=nil end
        if expanded_weapon then bucket.seeded_weapon=nil end
    end
end

---@param bucket ESIRWaterChunk
---@param position MapPosition
---@param category string
---@return boolean
local function covered(bucket,position,category)
    local x,y=lib.get_chunk_coordinates(position,CELL)
    local c=bucket.cells[x..":"..y]
    if not c then return false end
    local weapon=category=="weapon"
    if (weapon and c.weapon_full or not weapon and c.full or 0)>0 then return true end
    for _,circle in pairs(c.boundary) do
        if (not weapon or circle.weapon) and (position.x-circle.x)^2+(position.y-circle.y)^2<=circle.radius2 then return true end
    end
    return false
end

---@param root ESIRWaterState
---@param id integer
function model.remove_fire(root,id)
    local fire=root.index.fires[id]
    if not fire then return end
    root.index.fires[id]=nil;root.index.count=root.index.count-1
    remove(root,fire.bucket[fire.category],id)
    if fire.bucket.active then wake(root,fire.bucket) end
end

---@param root ESIRWaterState
---@param entity LuaEntity
function model.admit(root,entity)
    if not lib.entity_check(entity) or entity.type~="fire" then return end
    local category=config.thermal_fires[entity.name] and "thermal" or flames.ground_fires[entity.name] and "weapon"
    if not category then return end
    local x,y=lib.get_chunk_coordinates(entity.position,config.chunk_size)
    local b=chunk(root,entity.surface.index,x,y)
    if not b or (category=="weapon" and b.weapon_count==0) or not covered(b,entity.position,category) then return end
    local id=script.register_on_object_destroyed(entity)
    local old=root.index.fires[id]
    if old and old.bucket==b then return end
    if old then model.remove_fire(root,id) end
    root.index.fires[id]={id=id,entity=entity,bucket=b,category=category}
    root.index.count=root.index.count+1
    add(b[category],id);wake(root,b)
    root.counters.fire_admissions=root.counters.fire_admissions+1
end

---@param root ESIRWaterState
---@param record ESIRWaterRecord
function model.cover(root,record)
    local entity=record.entity
    local position=entity.position
    local range=entity.prototype.attack_parameters.range*entity.quality.range_multiplier
    record.coverage={};record.range=range;record.position={x=position.x,y=position.y};record.surface=entity.surface.index
    local x0,x1,y0,y1=lib.get_chunk_coverage(position,range,config.chunk_size)
    for x=x0,x1 do for y=y0,y1 do
        local b=chunk(root,record.surface,x,y,true)
        local dx=math.max(x*32-position.x,0,position.x-(x+1)*32)
        local dy=math.max(y*32-position.y,0,position.y-(y+1)*32)
        if dx*dx+dy*dy<=range*range then
            record.coverage[#record.coverage+1]={bucket=b,distance=dx*dx+dy*dy}
            add(b.watchers,record.id)
            coverage_cells(b,record,true)
            if record.weapon_fires then b.weapon_count=b.weapon_count+1 end
            seed(root,b)
        elseif b.watchers.count==0 then root.index.surfaces[b.surface][b.key]=nil end
    end end
    table.sort(record.coverage,function(a,b)
        if a.distance~=b.distance then return a.distance<b.distance end
        if a.bucket.x~=b.bucket.x then return a.bucket.x<b.bucket.x end
        return a.bucket.y<b.bucket.y
    end)
end

---@param root ESIRWaterState
---@param bucket ESIRWaterChunk
local function retire(root,bucket)
    finish_seed_rebuild(root,bucket)
    bucket.active=false
    local map=root.index.surfaces[bucket.surface]
    if map and map[bucket.key]==bucket then
        map[bucket.key]=nil
        if next(map)==nil then root.index.surfaces[bucket.surface]=nil end
    end
    scheduler.queue_push(root.cold_queue,{kind="retire",bucket=bucket,category="thermal",cursor=1})
end

---@param root ESIRWaterState
---@param record ESIRWaterRecord
function model.uncover(root,record)
    for _,entry in ipairs(record.coverage or {}) do
        local b=entry.bucket
        coverage_cells(b,record,false)
        remove(root,b.watchers,record.id)
        if record.weapon_fires then b.weapon_count=math.max(0,b.weapon_count-1) end
        if b.active and b.watchers.count==0 then retire(root,b)
        elseif b.active and b.weapon_count==0 then
            b.seeded_weapon=nil
            if b.weapon.count>0 then
                scheduler.queue_push(root.cold_queue,{kind="purge-weapon",bucket=b,cursor=1,tail=b.weapon.tail,items=b.weapon.items})
            end
        end
    end
    record.coverage=nil
end

---@param root ESIRWaterState
---@param event EventData.on_chunk_deleted
function model.on_chunk_deleted(root,event)
    for _,p in ipairs(event.positions) do
        local b=chunk(root,event.surface_index,p.x,p.y)
        -- Neighboring turrets still cover this coordinate after deletion/regeneration.
        -- Destruction registrations remove its fires; retain their coverage subscriptions.
        if b then wake(root,b) end
    end
end

---@param root ESIRWaterState
---@param wake_record fun(record:ESIRWaterRecord,tick:MapTick)
---@param tick MapTick
function model.service_wakes(root,wake_record,tick)
    for _=1,config.wake_budget do
        local b=scheduler.queue_peek(root.index.wakes)
        if not b then break end
        local job=b.wake
        if not b.active or job.cursor>job.tail then
            scheduler.queue_pop(root.index.wakes);b.wake=nil
            if b.active and job.generation~=b.generation then wake(root,b) end
        else
            local id=job.items[job.cursor];job.cursor=job.cursor+1
            local record=id and b.watchers.slots[id] and root.records[id]
            if record then wake_record(record,tick) end
        end
        root.counters.wake_visits=root.counters.wake_visits+1
    end
end

---@param root ESIRWaterState
function model.bootstrap(root)
    local b=scheduler.queue_pop(root.index.seeds)
    if not b then return end
    if not b.active then finish_seed_rebuild(root,b);return end
    local surface=game.get_surface(b.surface)
    if not surface then b.seed_pending=nil;finish_seed_rebuild(root,b);return end
    -- One query per update. Result ingestion shares the cold slot budget.
    local entities=surface.find_entities_filtered{area={{b.x*32,b.y*32},{(b.x+1)*32,(b.y+1)*32}},type="fire"}
    root.counters.searches=root.counters.searches+1
    scheduler.queue_push(root.cold_queue,{kind="seed",bucket=b,entities=entities,cursor=1,
        weapon=b.weapon_count>0,coverage_generation=b.coverage_generation})
end

---@param root ESIRWaterState
---@param job table
---@param limit integer
---@return boolean complete
function model.cold_slice(root,job,limit)
    local b=job.bucket
    if job.kind=="seed" then
        if not b.active then finish_seed_rebuild(root,b);return true end
        local stop=math.min(#job.entities,job.cursor+limit-1)
        for i=job.cursor,stop do model.admit(root,job.entities[i]);root.counters.candidate_visits=root.counters.candidate_visits+1 end
        job.cursor=stop+1
        if job.cursor<=#job.entities then return false end
        b.seed_pending=nil
        if job.coverage_generation==b.coverage_generation then
            b.seeded_thermal=true
            if job.weapon then b.seeded_weapon=true end
        end
        seed(root,b)
        if not b.seed_pending then finish_seed_rebuild(root,b) end
        wake(root,b);return true
    end
    if job.kind=="purge-weapon" and (not b.active or b.weapon_count>0) then return true end
    local list=job.kind=="retire" and b[job.category] or b.weapon
    local items=job.items or list.items
    local tail=job.tail or list.tail
    for _=1,limit do
        if job.cursor>tail then
            if job.kind=="retire" and job.category=="thermal" then job.category="weapon";job.cursor=1;return false end
            return true
        end
        local id=items[job.cursor];job.cursor=job.cursor+1
        if id and root.index.fires[id] and root.index.fires[id].bucket==b then model.remove_fire(root,id) end
        root.counters.candidate_visits=root.counters.candidate_visits+1
    end
    return false
end

-- blueprint-ref: .codex/esir/blueprints/firefighting-and-water-turret.md#stable-views
-- Only the unpublished builder may swap-remove. Old readers keep their array/tail.
---@param root ESIRWaterState
---@param limit integer
---@return boolean serviced
function model.maintain(root,limit)
    local list=scheduler.queue_pop(root.index.maintenance)
    if not list then return false end
    if not list.bucket.active then list.builder=nil;return true end
    local b=list.builder
    if not b then b={source=list.items,tail=list.tail,cursor=1,items={},slots={}};list.builder=b end
    local stop=math.min(b.tail,b.cursor+limit-1)
    for i=b.cursor,stop do
        local id=b.source[i]
        if id and list.slots[id] and not b.slots[id] then b.items[#b.items+1]=id;b.slots[id]=#b.items end
        root.counters.maintenance_visits=root.counters.maintenance_visits+1
    end
    b.cursor=stop+1
    if b.cursor>b.tail then
        list.items=b.items;list.slots=b.slots;list.tail=#b.items;list.builder=nil
        root.counters.compactions=root.counters.compactions+1
    else scheduler.queue_push_unique(root.index.maintenance,list) end
    return true
end

---@param record ESIRWaterRecord
---@return table? search
function model.search(record)
    local views={}
    for _,entry in ipairs(record.coverage) do
        local b=entry.bucket
        if not b.active or not b.seeded_thermal or (record.weapon_fires and not b.seeded_weapon) then return end
        for _,category in ipairs(record.weapon_fires and {"thermal","weapon"} or {"thermal"}) do
            local list=b[category]
            views[#views+1]={items=list.items,tail=list.tail,bucket=b,category=category}
        end
    end
    return {views=views,view=1,cursor=1}
end

---@param root ESIRWaterState
---@param record ESIRWaterRecord
---@param limit integer
---@param nearest boolean
---@return boolean complete
---@return LuaEntity? target
function model.search_slice(root,record,limit,nearest)
    local search=record.search
    for _=1,limit do
        root.counters.candidate_visits=root.counters.candidate_visits+1
        local view=search.views[search.view]
        if not view then
            local best=search.best and root.index.fires[search.best]
            return true,best and lib.get_valid_entity(best.entity)
        end
        if search.cursor>view.tail then search.view=search.view+1;search.cursor=1
        else
            local id=view.items[search.cursor];search.cursor=search.cursor+1
            local fire=id and root.index.fires[id]
            if fire and fire.bucket==view.bucket and fire.bucket.active then
                local entity=lib.get_valid_entity(fire.entity)
                if entity and entity.surface.index==record.surface then
                    local a,b=record.position,entity.position
                    local distance=(a.x-b.x)^2+(a.y-b.y)^2
                    if distance<=record.range^2 then
                        if not nearest then return true,entity end
                        if not search.distance or distance<search.distance or (distance==search.distance and id<search.best) then
                            search.best=id;search.distance=distance
                        end
                    end
                elseif not entity then model.remove_fire(root,id) end
            end
        end
    end
    return false
end

return model
