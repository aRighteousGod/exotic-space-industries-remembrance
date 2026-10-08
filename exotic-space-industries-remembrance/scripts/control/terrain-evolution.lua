--==============================================================================
-- ESIR FILE MAP
-- owns: bounded ecology admission, terrain protection, sparse recovery and seasons
-- loaded_by: control.lua
-- cadence: event admission; global service every 16 ticks, query grant every 32 by default
-- forwarded_events: on_entity_died, on_chunk_generated, on_resource_depleted
-- storage_roots: storage.ei.terrain_evolution
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration changes, supported surface lifecycle, live settings
--==============================================================================
-- blueprint: .codex/esir/blueprints/terrain-evolution.md#contract
---@class EsirTerrainChunkToken
---@field references integer
---@class EsirTerrainSet
---@field items table[]
---@field index table<string, integer>
---@field cursor integer
---@field tree_cursor integer? Independent active-chunk tree discovery cursor.
---@field entity_cursor integer? Independent pending entity-action cursor.
---@field tile_cursor integer? Independent pending tile-action cursor.
---@field terrain_cursor integer? Advances only when terrain queries can run.
---@field validation_cursor integer? Ownership checks without query allowance.
---@class EsirTerrainCadence
---@field next_tick MapTick
---@field next_search MapTick?
---@field next_fire_cleanup MapTick?
---@field query_pass integer? Advances on query grants, not service passes.
---@field history_tree_turn boolean? Alternates contested single-slot history turns.
---@class EsirTerrainSurface
---@field surface LuaSurface
---@field planet string
---@field config table
---@field overrides table<string, boolean|number|string>
---@field chunk_tokens table<string, EsirTerrainChunkToken>
---@field protected table<string, boolean>
---@field classified table<string, boolean>
---@field iterator LuaChunkIterator?
---@class EsirTerrainHistory
---@field id string
---@field surface LuaSurface
---@field owner EsirTerrainSurface
---@field x integer
---@field y integer
---@field origin string
---@field expected string
---@field path string[]
---@field cause string
---@field next_tick MapTick
---@field chunk_cell string
---@field chunk_token EsirTerrainChunkToken
---@class EsirTerrainBudget
---@field candidates integer
---@field writes integer
---@field searches integer
---@field samples integer
---@field events integer
---@field used_candidates integer
---@field used_writes integer
---@field used_searches integer
---@field used_events integer
---@field batches table<SurfaceIndex, table>
---@field positions table<string, boolean>
local lib=require("lib/lib")
local config=require("lib/terrain-evolution-config")
local policy=require("lib/terrain-policy")
local calendar=require("scripts/control/terrain-calendar")
local thermal=require("lib/firefighting-config")
local presets=require("lib/spawner-presets")
local model={}
local owners={}
local self_write=false
local function peek() return storage.ei and storage.ei.terrain_evolution end
local function key(surface,x,y) return surface..":"..x..":"..y end
local function bump(root,name,n) root.counters[name]=(root.counters[name] or 0)+(n or 1) end

-- Dense domain sets have constant-time swap removal; no queue-wide compaction.
local function new_set() return {items={},index={},cursor=1} end
local function attach_chunk(record)
    local entry=record.owner
    local cell=record.chunk_cell
    local token=entry.chunk_tokens[cell]
    if not token then token={references=0};entry.chunk_tokens[cell]=token end
    token.references=token.references+1;record.chunk_token=token
end
local function put(set,id,record)
    if set.index[id] then return false end
    record.id=id;set.items[#set.items+1]=record;set.index[id]=#set.items
    return true
end
local function remove(set,id)
    local i=set.index[id];if not i then return end
    local record=set.items[i]
    if record.chunk_token then
        local token=record.chunk_token;token.references=token.references-1
        if token.references==0 and record.owner.chunk_tokens[record.chunk_cell]==token then record.owner.chunk_tokens[record.chunk_cell]=nil end
    end
    local last=set.items[#set.items];set.items[i]=last;set.items[#set.items]=nil
    set.index[id]=nil;if last and last.id~=id then set.index[last.id]=i end
    if set.cursor>#set.items then set.cursor=1 end
end
---@param set EsirTerrainSet
---@param cursor_field string?
---@return table?
local function next_record(set,cursor_field)
    if #set.items==0 then return end
    local field=cursor_field or "cursor"
    local cursor=set[field] or 1
    if cursor>#set.items then cursor=1 end
    local record=set.items[cursor];set[field]=cursor+1
    return record
end
local function state()
    storage.ei=storage.ei or {}
    local root=peek()
    if not root then
        root={version=1,surfaces={},surface_order={},surface_cursor=1,active=new_set(),history=new_set(),
            trees=new_set(),pending=new_set(),fires=new_set(),counters={},next_tick=0,pass=0}
        storage.ei.terrain_evolution=root
    end
    return root
end
---@param context {vat: table, gaia: table}
function model.configure(context) owners=context end

local function effective(root,surface)
    local entry=root.surfaces[surface.index]
    return entry and entry.config
end
function model.resolve_config(surface)
    local root=peek()
    return root and effective(root,surface) or {enabled=false,seasonal_daylight=false}
end
local function add_surface(root,surface,refresh)
    local planet=policy.planet(surface)
    if not planet then return end
    local entry=root.surfaces[surface.index]
    if not entry or entry.surface~=surface then
        entry={surface=surface,planet=planet,overrides={},protected={},classified={},chunk_tokens={}}
        root.surfaces[surface.index]=entry
    end
    if refresh or not entry.config then entry.config=config.resolve_surface(root.config,planet,entry.overrides) end
    if root.compatibility then entry.config.enabled=false end
    if not entry.config.enabled then entry.iterator=nil end
end

---@param tick MapTick
function model.initialize(tick)
    local root=state()
    root.config,root.config_errors=config.resolve()
    root.compatibility=script.active_mods.TerrainEvolution2 and "TerrainEvolution2"
        or script.active_mods.TerrainEvolution and "TerrainEvolution" or nil
    root.transitions,root.missing=policy.compile(prototypes.tile)
    root.surface_order={};root.surface_registered={}
    for _,surface in pairs(game.surfaces) do
        add_surface(root,surface,true)
        if root.surfaces[surface.index] then root.surface_order[#root.surface_order+1]=surface.index end
    end
    table.sort(root.surface_order)
    for i,index in ipairs(root.surface_order) do root.surface_registered[index]=i end
    root.enabled_surfaces=0
    for _,entry in pairs(root.surfaces) do if entry.surface.valid and entry.config.enabled then root.enabled_surfaces=root.enabled_surfaces+1 end end
    root.surface_cursor=1;root.next_tick=tick+root.config.interval
    root.next_search=tick+root.config.search_interval
    root.drill_extent=0
    for _,name in ipairs(policy.drills) do
        local prototype=prototypes.entity[name]
        if prototype then
            for _,quality in pairs(prototypes.quality) do root.drill_extent=math.max(root.drill_extent,prototype.get_mining_drill_radius(quality)) end
        end
    end
    root.anchor_extent=4
    for _,preset in pairs(presets.entity_presets) do
        for _,group in ipairs({preset.structure or {},preset.tiles or {}}) do
            for _,value in pairs(group) do
                local p=value.position
                if p then root.anchor_extent=math.max(root.anchor_extent,math.abs(p.x or p[1])+8,math.abs(p.y or p[2])+8) end
            end
        end
    end
    calendar.initialize(root,tick)
    if not root.config.enabled or root.compatibility or root.enabled_surfaces==0 then
        calendar.release(root)
        root.pending=new_set()
        while #root.active.items>0 do remove(root.active,root.active.items[#root.active.items].id) end
        for _,entry in pairs(root.surfaces) do entry.iterator=nil end
    end
end
function model.on_load() self_write=false end
function model.on_settings_changed(event)
    if event.setting:find("^ei%-terrain%-") then model.initialize(event.tick) end
end
function model.on_surface_created(event)
    local surface=game.get_surface(event.surface_index)
    if not surface or not policy.planet(surface) then return end
    local root=peek()
    if not root or not root.transitions or not root.surface_registered then model.initialize(event.tick);return end
    local previous=root.surfaces[surface.index]
    local counted=previous and previous.config and previous.config.enabled and not previous.cleared
    add_surface(root,surface)
    local entry=root.surfaces[surface.index];entry.cleared=nil
    if entry.config.enabled and not counted then root.enabled_surfaces=root.enabled_surfaces+1 end
    if not root.surface_registered[surface.index] then
        root.surface_order[#root.surface_order+1]=surface.index;root.surface_registered[surface.index]=#root.surface_order
    end
    calendar.add_surface(root,surface,event.tick)
end
function model.on_surface_clearing(event)
    local root=peek();if not root then return end
    local entry=root.surfaces[event.surface_index]
    local orbit=root.calendar and root.calendar.records[event.surface_index]
    model.on_surface_deleted(event)
    -- Clearing terrain does not reset the surface's analytical orbital phase.
    if orbit then root.calendar.records[event.surface_index]=orbit end
    if entry then
        -- Clearing regenerates this surface; configuration belongs to its identity.
        root.surfaces[event.surface_index]={surface=entry.surface,planet=entry.planet,config=entry.config,
            overrides=entry.overrides,protected={},classified={},chunk_tokens={},cleared=true}
    end
end
function model.on_surface_deleted(event)
    local root=peek();if not root then return end
    local index=event.surface_index
    local entry=root.surfaces[index]
    if entry and entry.config.enabled then root.enabled_surfaces=math.max(0,(root.enabled_surfaces or 0)-1) end
    root.surfaces[index]=nil
    -- Swap removal keeps scheduler storage proportional to surviving surfaces.
    local i=root.surface_registered[index]
    if i then
        local last=root.surface_order[#root.surface_order]
        root.surface_order[i]=last;root.surface_order[#root.surface_order]=nil;root.surface_registered[index]=nil
        if last~=index then root.surface_registered[last]=i end
        if root.surface_cursor>#root.surface_order then root.surface_cursor=1 end
    end
    -- Invalidation is O(1); bounded services retire stale dense-set records.
    calendar.remove_surface(root,index)
end
function model.on_chunk_deleted(event)
    local root=peek();if not root then return end
    local entry=root.surfaces[event.surface_index];if not entry then return end
    entry.generation=(entry.generation or 0)+1
    for _,position in ipairs(event.positions or {}) do
        local cell=position.x..":"..position.y
        entry.chunk_tokens[cell]=nil
        if entry.protected[cell] then entry.protected_count=math.max(0,(entry.protected_count or 0)-1) end
        if entry.classified[cell] then entry.classified_count=math.max(0,(entry.classified_count or 0)-1) end
        entry.protected[cell]=nil;entry.classified[cell]=nil
    end
    -- Do not walk global history during a potentially large deletion event.
    -- Each record verifies chunk existence before any subsequent mutation.
end

local function admit(root,surface,position,cause,tick,extra)
    local cfg=effective(root,surface)
    if not cfg or not cfg.enabled then return false end
    if root.admit_tick~=tick then root.admit_tick=tick;root.admitted=0 end
    local x,y=math.floor(position.x),math.floor(position.y)
    local id=key(surface.index,math.floor(x/8),math.floor(y/8))..":"..cause
    if root.pending.index[id] then bump(root,"coalesced");return false end
    if root.admitted>=root.config.admissions or #root.pending.items>=root.config.pending_cap then bump(root,"saturated");return false end
    root.admitted=root.admitted+1
    local entry=root.surfaces[surface.index]
    return put(root.pending,id,{surface=surface,owner=entry,x=x,y=y,cause=cause,tick=tick,extra=extra,
        generation=entry.generation or 0,offset=0})
end
---@param surface LuaSurface
---@param position MapPosition
---@param cause string
---@param tick MapTick
---@param extra table?
---@return boolean
function model.enqueue_scar(surface,position,cause,tick,extra)
    local root=peek();if not root then return false end
    return admit(root,surface,position,cause,tick,extra)
end
function model.on_chunk_generated(event)
    local root=peek();if not root or not root.config.enabled then return end
    if not root.surfaces[event.surface.index] then add_surface(root,event.surface) end
    -- Cold discovery remains the backstop; event admission never enumerates tiles.
    admit(root,event.surface,{x=event.position.x*32+16,y=event.position.y*32+16},"wake",event.tick)
end
function model.on_entity_built(event)
    local root=peek();if not root or not root.config.enabled then return end
    local entity=lib.get_valid_entity(event.entity or event.created_entity or event.destination)
    if entity then admit(root,entity.surface,entity.position,"wake",event.tick) end
end
function model.on_entity_died(event)
    local root=peek();if not root or not root.config.enabled then return end
    local entity=lib.get_valid_entity(event.entity);if not entity then return end
    local cfg=effective(root,entity.surface);if not cfg or not cfg.enabled then return end
    if entity.type=="tree" and cfg.thermal_scars and event.damage_type and event.damage_type.name=="fire" then
        local cause=lib.get_valid_entity(event.cause)
        if not cause or thermal.thermal_fires[cause.name] or cause.type~="fire" then admit(root,entity.surface,entity.position,"thermal",event.tick) end
    elseif cfg.blood and (entity.type=="unit" or entity.type=="unit-spawner") and entity.force.name=="enemy"
        and math.random()<cfg.blood_probability then admit(root,entity.surface,entity.position,"blood",event.tick) end
end
function model.on_resource_depleted(event)
    local root=peek();if not root or not root.config.enabled then return end
    local resource=lib.get_valid_entity(event.entity)
    if not resource or resource.type~="resource" or resource.prototype.infinite_resource then return end
    local surface=resource.surface;local cfg=effective(root,surface)
    if not cfg or not cfg.enabled or not cfg.mining_scars then return end
    local tick=event.tick
    if root.mine_tick~=tick then root.mine_tick=tick;root.mine_queries=0 end
    if root.mine_queries>=root.config.mining_queries then bump(root,"mining_saturated");return end
    local window=math.floor(tick/60)
    if root.mine_window~=window then root.mine_window=window;root.mine_seen={} end
    local p=resource.position;local id=key(surface.index,math.floor(p.x/8),math.floor(p.y/8))
    if root.mine_seen[id] then bump(root,"coalesced");return end
    root.mine_seen[id]=true;root.mine_queries=root.mine_queries+1
    local radius=root.drill_extent
    local drills=surface.find_entities_filtered{name=policy.drills,area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},limit=root.config.mining_candidates}
    bump(root,"mining_queries")
    for _,drill in ipairs(drills) do
        if drill.valid and drill.prototype.resource_categories[resource.prototype.resource_category] then
            local box=drill.mining_area
            if p.x>=box.left_top.x and p.x<=box.right_bottom.x and p.y>=box.left_top.y and p.y<=box.right_bottom.y then
                local distance=cfg.mining_radius*(math.random()+math.random()-1);local angle=math.random()*math.pi*2
                admit(root,surface,{x=p.x+math.cos(angle)*distance,y=p.y+math.sin(angle)*distance},"mining",tick)
                return
            end
        end
    end
end

function model.protect_preset(preset,surface,position)
    local root=state()
    if not root.config then root.config=config.resolve() end
    add_surface(root,surface)
    local entry=root.surfaces[surface.index];if not entry or entry.planet~="gaia" then return end
    local minx,miny,maxx,maxy=0,0,0,0
    for _,group in ipairs({preset.structure or {},preset.tiles or {}}) do
        for _,value in pairs(group) do
            local p=value.position
            if p then minx=math.min(minx,p.x or p[1]);maxx=math.max(maxx,p.x or p[1]);miny=math.min(miny,p.y or p[2]);maxy=math.max(maxy,p.y or p[2]) end
        end
    end
    for x=math.floor((position.x+minx-4)/32),math.floor((position.x+maxx+4)/32) do
        for y=math.floor((position.y+miny-4)/32),math.floor((position.y+maxy+4)/32) do
            local cell=x..":"..y
            if not entry.protected[cell] then
                if (entry.protected_count or 0)>=root.config.active_cap then entry.protection_saturated=true;return end
                entry.protected[cell]=true;entry.protected_count=(entry.protected_count or 0)+1
            end
        end
    end
end
local function query(root,budget,surface,filter)
    if budget.searches<=0 then return nil end
    budget.searches=budget.searches-1;budget.used_searches=budget.used_searches+1
    filter.limit=math.min(filter.limit or root.config.result_limit,root.config.result_limit)
    return surface.find_entities_filtered(filter)
end
local function protected(root,budget,surface,x,y,cfg,water,ignore,density_limit)
    local entry=root.surfaces[surface.index];if not entry or entry.surface~=surface then return true end
    if not surface.is_chunk_generated({math.floor(x/32),math.floor(y/32)}) then return true end
    if owners.vat.is_terrain_claimed(surface.index,x,y) then return true end
    if entry.planet=="gaia" then
        local cell=math.floor(x/32)..":"..math.floor(y/32)
        if entry.protection_saturated or entry.protected[cell] then return true end
        if not entry.classified[cell] then
            local extent=root.anchor_extent
            local found=query(root,budget,surface,{name="ei-artifact-flag",area={{x-extent-32,y-extent-32},{x+extent+32,y+extent+32}},limit=1})
            if not found then return nil end
            -- Classification is a bounded cache; protected authored cells persist.
            if (entry.classified_count or 0)>=root.config.active_cap then entry.classified={};entry.classified_count=0 end
            entry.classified[cell]=true;entry.classified_count=(entry.classified_count or 0)+1
            if #found>0 then
                if (entry.protected_count or 0)>=root.config.active_cap then entry.protection_saturated=true
                else entry.protected[cell]=true;entry.protected_count=(entry.protected_count or 0)+1 end
                return true
            end
            return nil -- Remaining occupancy inspection gets its own bounded pass.
        end
    end
    local buffer=water and math.max(8,cfg.protection_buffer) or cfg.protection_buffer
    local found=query(root,budget,surface,{area={{x-buffer,y-buffer},{x+1+buffer,y+1+buffer}}})
    if not found then return nil end
    if #found>=root.config.result_limit then return true end
    local trees=0
    for _,entity in ipairs(found) do
        if entity.valid and entity.type=="tree" and policy.natural_trees[entity.name] then trees=trees+1 end
        if entity~=ignore and entity.valid and entity.type~="corpse" and entity.type~="fish"
            and not (entity.type=="tree" and policy.natural_trees[entity.name]) then return true end
    end
    if density_limit and trees>=density_limit then return true end
    return false
end
local function same_mask(a,b)
    for layer in pairs(a.layers) do if not b.layers[layer] then return false end end
    for layer in pairs(b.layers) do if not a.layers[layer] then return false end end
    for _,flag in ipairs({"not_colliding_with_itself","consider_tile_transitions","colliding_with_tiles_only"}) do
        if (a[flag]==true)~=(b[flag]==true) then return false end
    end
    return true
end

-- Returns nil only when bounded work must be resumed; false is a terminal skip.
local function propose(root,budget,surface,x,y,cause,tick,target,recover)
    if budget.candidates<=0 or budget.writes<=0 or budget.searches<=0 then return nil end
    budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
    local cfg=effective(root,surface);if not cfg or not cfg.enabled then return false end
    if not surface.is_chunk_generated({math.floor(x/32),math.floor(y/32)}) then return false end
    local tile=surface.get_tile(x,y)
    if not tile.valid then return false end
    local id=key(surface.index,x,y)
    if budget.positions[id] then return false end
    local history_index=root.history.index[id]
    local history=history_index and root.history.items[history_index]
    if history and (tile.name~=history.expected or history.owner~=root.surfaces[surface.index]
        or history.owner.chunk_tokens[history.chunk_cell]~=history.chunk_token) then
        remove(root.history,id);history=nil;bump(root,"ownership_lost")
    end
    if recover and not history then return false end
    if recover and history.cause=="mining" and not cfg.mining_recovery then return false end
    local next_name=target or root.transitions[tile.name]
    if not next_name or not prototypes.tile[next_name] then return false end
    local water
    if recover then water=policy.freshwater[tile.name] or policy.freshwater[next_name]
    else water=cause=="flood" or cause=="drought" end
    local wetland=cfg.planet=="gleba" and tile.name:find("^wetland%-") and next_name:find("^wetland%-")
    local paving=cause=="blood" and cfg.paving and (tile.name=="stone-path" or tile.name:find("concrete",1,true))
    if (tile.hidden_tile and not paving) or tile.double_hidden_tile or tile.prototype.is_foundation then return false end
    if not water and not wetland and tile.collides_with("water_tile") then return false end
    if water and (cfg.planet~="nauvis" or not
        ((policy.coast[tile.name] and policy.freshwater[next_name]) or
         (policy.freshwater[tile.name] and policy.coast[next_name]))) then return false end
    if not water and not paving and policy.family(tile.name)~=cfg.planet then return false end
    if not water and not paving and not same_mask(tile.prototype.collision_mask,prototypes.tile[next_name].collision_mask) then return false end
    if not recover and not water and not paving and not root.transitions[tile.name] then return false end
    local mining_takeover=cause=="mining" and not recover and (not cfg.mining_recovery or (history and history.cause~="mining"))
    if history and not recover and not mining_takeover and #history.path>=cfg.max_depth then return false end
    local protect=protected(root,budget,surface,x,y,cfg,water)
    if protect==nil then return nil end
    if protect then bump(root,"protected");return false end
    if tile.name==next_name then return false end
    local permanent=cause=="mining" and not cfg.mining_recovery
    if not history and not permanent and not paving and #root.history.items>=root.config.tile_history_cap then bump(root,"history_full");return false end
    -- Reserve recovery state before enqueueing a tile write.
    if permanent or paving then remove(root.history,id);history=nil
    elseif not history then
        local entry=root.surfaces[surface.index]
        history={surface=surface,owner=entry,x=x,y=y,origin=tile.name,expected=tile.name,path={},cause=cause,next_tick=tick,
            generation=entry.generation or 0}
        history.chunk_cell=math.floor(x/32)..":"..math.floor(y/32);attach_chunk(history)
        put(root.history,id,history)
    end
    if history then
        if cause=="mining" and history.cause~="mining" and not recover then
            history.origin=tile.name;history.path={};history.cause="mining"
        end
        if recover then history.path[#history.path]=nil
        else history.path[#history.path+1]=tile.name end
        history.expected=next_name;history.next_tick=tick+cfg.recovery_seconds*60/cfg.intensity_multiplier
        if #history.path==0 then remove(root.history,id) end
    end
    budget.positions[id]=true
    local batch=budget.batches[surface.index]
    if not batch then batch={surface=surface,tiles={}};budget.batches[surface.index]=batch end
    batch.tiles[#batch.tiles+1]={name=next_name,position={x,y}}
    batch.expected=batch.expected or {};batch.expected[#batch.expected+1]=tile.name
    budget.writes=budget.writes-1;budget.used_writes=budget.used_writes+1
    bump(root,recover and "recovered" or "changed")
    return true
end
local function commit(root,budget)
    for _,batch in pairs(budget.batches) do
        local accepted={}
        for i,tile in ipairs(batch.tiles) do
            local actual=batch.surface.get_tile(tile.position)
            if actual.valid and actual.name==batch.expected[i] then accepted[#accepted+1]=tile
            else remove(root.history,key(batch.surface.index,tile.position[1],tile.position[2]));bump(root,"ownership_lost") end
        end
        self_write=true
        if #accepted>0 then batch.surface.set_tiles(accepted,false,false,false,true) end
        self_write=false
        for _,tile in ipairs(accepted) do
            if not policy.freshwater[tile.name] then
                batch.surface.destroy_decoratives{position=tile.position,name={"green-pita","green-pita-mini","green-bush-mini"},exclude_soft=false}
            end
        end
    end
end
function model.on_tiles_changed(event)
    if self_write then return end
    local root=peek();if not root then return end
    local index=event.surface_index or (event.surface and event.surface.index)
    if not index then return end
    -- Event-sized invalidation is required even when disabled; never scan history.
    for _,tile in ipairs(event.tiles or {}) do
        local p=tile.position;remove(root.history,key(index,math.floor(p.x or p[1]),math.floor(p.y or p[2])))
    end
end

local function sample(root,record,tick)
    local surface=record.surface;local cfg=surface.valid and effective(root,surface)
    if not cfg or not cfg.enabled or not surface.is_chunk_generated({record.x,record.y}) then return false end
    local entry=root.surfaces[surface.index]
    if record.owner and record.owner~=entry then return false end
    if record.chunk_token and entry.chunk_tokens[record.chunk_cell]~=record.chunk_token then return false end
    local pollution=0
    if surface.pollutant_type and surface.pollutant_type.name=="pollution" then pollution=surface.get_pollution({record.x*32+16,record.y*32+16}) end
    record.pollution=pollution;record.sample_tick=tick
    if pollution>=cfg.pollution_high then record.dirty_since=record.dirty_since or tick;record.clean_since=nil
    elseif pollution<=cfg.pollution_low then record.clean_since=record.clean_since or tick;record.dirty_since=nil
    else record.clean_since=nil;record.dirty_since=nil end
    bump(root,"samples")
    return true
end
local function active(root,surface,x,y,tick)
    local id=key(surface.index,x,y);local i=root.active.index[id]
    if i then return root.active.items[i],false end
    if #root.active.items>=root.config.active_cap then return nil end
    local entry=root.surfaces[surface.index]
    local record={surface=surface,owner=entry,generation=entry.generation or 0,x=x,y=y,resident_since=tick,next_soil=tick,next_tree=tick,next_hazard=tick}
    record.chunk_cell=x..":"..y;attach_chunk(record)
    put(root.active,id,record)
    return record,true
end
-- A cached sample can drive due work on later turns. Tying work to a fresh
-- 600-tick sample aliases short service intervals with query-priority rotation.
local function visit_active(root,budget,record,tick)
    if not record then return end
    local entry=record.surface.valid and root.surfaces[record.surface.index]
    if not entry or not entry.config.enabled or record.owner~=entry
        or entry.chunk_tokens[record.chunk_cell]~=record.chunk_token then
        remove(root.active,record.id);return
    end
    if not record.sample_tick or tick-record.sample_tick>=600 then
        if budget.samples<=0 then return end
        budget.samples=budget.samples-1
        if not sample(root,record,tick) then remove(root.active,record.id);return end
    end
    return record
end
local function discover(root,tick)
    for _=1,root.config.cold_chunks do
        if #root.surface_order==0 then break end
        if root.surface_cursor>#root.surface_order then root.surface_cursor=1 end
        local entry=root.surfaces[root.surface_order[root.surface_cursor]]
        root.surface_cursor=root.surface_cursor+1
        if entry and entry.surface.valid and entry.config.enabled then
            if not entry.iterator or not entry.iterator.valid then entry.iterator=entry.surface.get_chunks() end
            local chunk=entry.iterator()
            if not chunk then entry.iterator=nil
            else
                local record,created=active(root,entry.surface,chunk.x,chunk.y,tick)
                if record and created then sample(root,record,tick) end
            end
        end
    end
end
local function climate_rate(root,surface,cfg,tick)
    if not cfg.seasonal_ecology then return cfg.intensity_multiplier end
    local snapshot=calendar.snapshot(root,surface,tick)
    return cfg.intensity_multiplier*(1+cfg.season_strength*math.sin(2*math.pi*(snapshot.phase or 0)))
end
local function recover_tiles(root,budget,tick)
    local count=math.min(budget.histories,#root.history.items)
    local recovery_turn=budget.searches>0
    for _=1,count do
        if recovery_turn and budget.searches<=0 then break end
        local record=next_record(root.history,recovery_turn and "cursor" or "validation_cursor");if not record then break end
        budget.histories=budget.histories-1
        local surface=record.surface
        local entry=surface.valid and root.surfaces[surface.index]
        local cell=math.floor(record.x/32)..":"..math.floor(record.y/32)
        if not entry or entry~=record.owner or entry.chunk_tokens[record.chunk_cell]~=record.chunk_token or not surface.is_chunk_generated({math.floor(record.x/32),math.floor(record.y/32)}) then remove(root.history,record.id)
        elseif surface.get_tile(record.x,record.y).name~=record.expected then remove(root.history,record.id);bump(root,"ownership_lost")
        else
            local cfg=effective(root,surface)
            if recovery_turn and cfg and cfg.enabled and cfg.recovery and (record.cause~="mining" or cfg.mining_recovery) and tick>=record.next_tick then
                local index=root.active.index[key(surface.index,math.floor(record.x/32),math.floor(record.y/32))]
                local c=index and root.active.items[index]
                if not c then
                    record.climate=record.climate or {surface=surface,owner=record.owner,chunk_cell=record.chunk_cell,chunk_token=record.chunk_token,x=math.floor(record.x/32),y=math.floor(record.y/32)}
                    c=record.climate
                end
                if budget.samples>0 and (not c.sample_tick or tick-c.sample_tick>=600) then
                    sample(root,c,tick);budget.samples=budget.samples-1
                end
                if c and c.clean_since and c.sample_tick and tick-c.sample_tick<=1200 and tick-c.clean_since>=cfg.clean_seconds*60 then
                    local result=propose(root,budget,surface,record.x,record.y,record.cause,tick,record.path[#record.path],true)
                    if result==nil then return end
                end
            end
        end
    end
end
local function service_events(root,budget,tick)
    local tile_turn=budget.searches>0
    for _=1,math.min(budget.events,#root.pending.items) do
        if tile_turn and budget.searches<=0 then break end
        local record=next_record(root.pending,tile_turn and "tile_cursor" or "cursor");if not record then break end
        budget.events=budget.events-1;budget.used_events=budget.used_events+1
        local surface=record.surface;local entry=surface.valid and root.surfaces[surface.index]
        local cfg=entry and entry.config
        if not cfg or not cfg.enabled or record.owner~=entry or record.generation~=(entry.generation or 0) then remove(root.pending,record.id)
        elseif (record.cause=="mining" and not cfg.mining_scars)
            or (record.cause=="thermal" and not cfg.thermal_scars)
            or (record.cause=="blood" and not cfg.blood) then remove(root.pending,record.id)
        elseif record.cause=="wake" then
            active(root,surface,math.floor(record.x/32),math.floor(record.y/32),tick);remove(root.pending,record.id)
        elseif tile_turn and record.cause~="regrowth" and record.cause~="tree" and record.cause~="aging" and record.cause~="rot" and record.cause~="ignite" and record.cause~="cliff" then
            local radius=record.cause=="mining" and cfg.mining_patch_radius or cfg.hazard_radius
            local width=radius*2+1
            local x=record.offset%width-radius;local y=math.floor(record.offset/width)-radius
            if record.offset>=width*width then remove(root.pending,record.id)
            else
                local result=false
                if x*x+y*y<radius*radius+1 and (record.cause~="mining" or math.random()<cfg.mining_probability) then
                    local target
                    if record.cause=="blood" then
                        local h=root.history.index[key(surface.index,record.x+x,record.y+y)]
                        if h then target=root.history.items[h].path[#root.history.items[h].path]
                        elseif cfg.paving and math.random()<cfg.paving_probability then
                            local tile=surface.get_tile(record.x+x,record.y+y)
                            -- Concrete corrosion is an explicit destructive opt-in.
                            if tile.valid and (tile.name=="stone-path" or tile.name:find("concrete",1,true)) then
                                target=tile.hidden_tile
                            end
                        end
                        if not target then result=false
                        else result=propose(root,budget,surface,record.x+x,record.y+y,"blood",tick,target,h~=nil) end
                    else result=propose(root,budget,surface,record.x+x,record.y+y,record.cause,tick) end
                end
                if result==nil then return end
                record.offset=record.offset+1
            end
        end
    end
end

local function tree_service(root,budget,record,tick)
    local surface=record.surface;local cfg=effective(root,surface)
    if not (cfg.tree_stress or cfg.tree_regrowth or cfg.aging or cfg.rot) or tick<record.next_tree then return end
    local x,y=record.x*32+math.random(0,31),record.y*32+math.random(0,31)
    local radius=cfg.tree_neighborhood
    local trees=query(root,budget,surface,{type="tree",area={{x-radius,y-radius},{x+1+radius,y+1+radius}}})
    if not trees then return end
    record.next_tree=tick+math.min(cfg.tree_stress_seconds,cfg.tree_growth_seconds)*60/climate_rate(root,surface,cfg,tick)
    local tree=trees[1];if not tree or not tree.valid or not policy.native_tree(tree.name,cfg.planet) then return end
    local p=tree.position;local id=key(surface.index,p.x,p.y)
    if cfg.tree_stress then admit(root,surface,p,"tree",tick,{tree=tree,pollution=record.pollution,dirty_since=record.dirty_since,clean_since=record.clean_since}) end
    if cfg.rot and policy.dead_trees[tree.name] and math.random()<cfg.tree_stress_seconds/cfg.tree_rot_seconds then
        admit(root,surface,p,"rot",tick,{tree=tree});return
    end
    if cfg.aging and not policy.dead_trees[tree.name] and math.random()<cfg.tree_stress_seconds/cfg.tree_aging_seconds then
        admit(root,surface,p,"aging",tick,{tree=tree});return
    end
    if cfg.tree_regrowth and tick>=(record.next_growth or 0) and record.clean_since and tick-record.clean_since>=cfg.clean_seconds*60
        and #trees<cfg.tree_density_limit and not policy.dead_trees[tree.name] then
        record.next_growth=tick+cfg.tree_growth_seconds*60/climate_rate(root,surface,cfg,tick)
        admit(root,surface,{x=p.x+math.random(-cfg.seed_distance,cfg.seed_distance),y=p.y+math.random(-cfg.seed_distance,cfg.seed_distance)},"regrowth",tick,{name=tree.name})
    end
end

local function entity_event(root,budget,record,tick)
    local surface=record.surface;local cfg=effective(root,surface)
    local p={x=record.x+0.5,y=record.y+0.5}
    if budget.candidates<=0 or budget.searches<=0 then return nil end
    budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
    local tile=surface.get_tile(record.x,record.y)
    local wetland_tree=cfg.planet=="gleba" and (record.cause=="tree" or record.cause=="regrowth")
    if not tile.valid or tile.hidden_tile or tile.double_hidden_tile or tile.prototype.is_foundation
        or (tile.collides_with("water_tile") and not wetland_tree)
        or not policy.natural_tiles[tile.name] or policy.family(tile.name)~=cfg.planet then return false end
    local blocked=protected(root,budget,surface,record.x,record.y,cfg,true,record.extra and record.extra.entity,record.cause=="regrowth" and cfg.tree_density_limit or nil)
    if blocked==nil then return nil end
    if blocked then return false end
    if record.cause=="tree" then
        local tree=lib.get_valid_entity(record.extra.tree)
        if not cfg.tree_stress or not tree or not policy.native_tree(tree.name,cfg.planet) then return false end
        local id=key(surface.index,tree.position.x,tree.position.y)
        local index=root.trees.index[id];local history=index and root.trees.items[index]
        if history and history.entity~=tree then remove(root.trees,id);history=nil end
        if history and history.expected and tree.tree_gray_stage_index~=history.expected then remove(root.trees,id);return false end
        if record.extra.pollution>=cfg.pollution_high and record.extra.dirty_since and tick-record.extra.dirty_since>=cfg.dirty_seconds*60 then
            local next_gray=math.min(tree.tree_gray_stage_index_max,tree.tree_gray_stage_index+1)
            if next_gray==tree.tree_gray_stage_index then return false end
            if not history and #root.trees.items<root.config.tree_history_cap then
                history={surface=surface,entity=tree,stage=tree.tree_stage_index,gray=tree.tree_gray_stage_index,next_tick=tick+cfg.recovery_seconds*60}
                put(root.trees,id,history)
            end
            if history then tree.tree_gray_stage_index=next_gray;history.expected=next_gray;bump(root,"tree_stressed") end
        elseif history and record.extra.pollution<=cfg.pollution_low and record.extra.clean_since and tick-record.extra.clean_since>=cfg.clean_seconds*60 then
            if tree.tree_gray_stage_index~=history.expected then remove(root.trees,id)
            else
                tree.tree_gray_stage_index=math.max(history.gray,tree.tree_gray_stage_index-1);history.expected=tree.tree_gray_stage_index
                if history.expected==history.gray then remove(root.trees,id) end
            end
        end
    elseif record.cause=="regrowth" then
        if not cfg.tree_regrowth or (cfg.planet~="gleba" and not root.transitions[tile.name]) then return false end
        local name=record.extra.name
        if cfg.planet=="gaia" then
            if budget.candidates<26 then return nil end
            budget.candidates=budget.candidates-26;budget.used_candidates=budget.used_candidates+26
            name=owners.gaia.resolve_gaia_tree_name(surface,p)
        end
        if not policy.native_tree(name,cfg.planet) or not prototypes.entity[name] or not surface.can_place_entity{name=name,position=p} then return false end
        if root.last_tree_created and tick-root.last_tree_created<600 then return false end
        local entity=surface.create_entity{name=name,position=p,force="neutral",raise_built=true}
        if entity then root.last_tree_created=tick;bump(root,"trees_grown") end
    elseif record.cause=="rot" or record.cause=="aging" then
        local tree=lib.get_valid_entity(record.extra.tree)
        if not tree or not policy.native_tree(tree.name,cfg.planet) then return false end
        if record.cause=="rot" and cfg.rot and policy.dead_trees[tree.name] then tree.destroy{raise_destroy=true};bump(root,"trees_rotted")
        elseif record.cause=="aging" and cfg.aging and not policy.dead_trees[tree.name] then
            -- Only Nauvis has an approved deadwood replacement family.
            local dead
            if cfg.planet=="nauvis" then dead="dry-tree" end
            if dead then
                local position=tree.position
                tree.destroy{raise_destroy=true};surface.create_entity{name=dead,position=position,force="neutral"};bump(root,"trees_aged")
            end
        end
    elseif record.cause=="ignite" then
        if cfg.wildfire=="off" or #root.fires.items>=16 or tick<(root.next_fire or 0) then return false end
        local name=cfg.wildfire=="contained" and "ei-ecology-fire" or "fire-flame-on-tree"
        local flame=surface.create_entity{name=name,position=p,force="neutral"}
        if flame then put(root.fires,key(surface.index,tick,#root.fires.items),{surface=surface,entity=flame,expires=tick+660});root.next_fire=tick+600;bump(root,"ignitions") end
    elseif record.cause=="cliff" then
        local entity=lib.get_valid_entity(record.extra.entity)
        if cfg.cliffs and entity and entity.type=="cliff" and entity.name=="cliff" then entity.destroy{do_cliff_correction=true,raise_destroy=true};bump(root,"cliffs_eroded") end
    end
    return true
end
local function recover_trees(root,budget,tick)
    local share=math.min(4,math.max(1,math.floor(root.config.histories/2)))
    for _=1,math.min(share,budget.histories,#root.trees.items) do
        local r=next_record(root.trees)
        budget.histories=budget.histories-1
        local tree=lib.get_valid_entity(r.entity)
        if not tree or (r.expected and tree.tree_gray_stage_index~=r.expected) then remove(root.trees,r.id)
        else
            local cfg=effective(root,r.surface)
            if cfg and cfg.enabled and cfg.tree_stress and tick>=(r.next_tick or 0) then
                local p=tree.position
                r.climate=r.climate or {surface=r.surface,x=math.floor(p.x/32),y=math.floor(p.y/32)}
                if budget.samples>0 and (not r.climate.sample_tick or tick-r.climate.sample_tick>=600) then
                    sample(root,r.climate,tick);budget.samples=budget.samples-1
                end
                local c=r.climate
                if c.sample_tick and tick-c.sample_tick<=1200 and c.clean_since and tick-c.clean_since>=cfg.clean_seconds*60 then
                    admit(root,r.surface,p,"tree",tick,{tree=tree,pollution=c.pollution,clean_since=c.clean_since})
                    r.next_tick=tick+cfg.recovery_seconds*60/cfg.intensity_multiplier
                end
            end
        end
    end
end
local entity_causes={regrowth=true,tree=true,rot=true,aging=true,ignite=true,cliff=true}
local function service_entity_events(root,budget,tick)
    for _=1,math.min(budget.events,#root.pending.items) do
        if budget.searches<=0 then break end
        local record=next_record(root.pending,"entity_cursor")
        budget.events=budget.events-1;budget.used_events=budget.used_events+1
        if record and entity_causes[record.cause] then
            local entry=record.surface.valid and root.surfaces[record.surface.index]
            if not entry or not entry.config.enabled or record.owner~=entry or record.generation~=(entry.generation or 0) then remove(root.pending,record.id)
            else
                local result=entity_event(root,budget,record,tick)
                if result==nil then return end
                remove(root.pending,record.id)
            end
        end
    end
end
local function hazards(root,budget,record,tick)
    if budget.searches<=0 then return end
    local cfg=effective(root,record.surface)
    if tick<record.next_hazard then return end
    record.next_hazard=tick+cfg.hazard_seconds*60/climate_rate(root,record.surface,cfg,tick)
    local p={x=record.x*32+math.random(0,31),y=record.y*32+math.random(0,31)}
    if cfg.wildfire~="off" and record.pollution>=cfg.pollution_high and math.random()<cfg.wildfire_probability then
        admit(root,record.surface,{x=p.x+math.random(-cfg.wildfire_radius,cfg.wildfire_radius),y=p.y+math.random(-cfg.wildfire_radius,cfg.wildfire_radius)},"ignite",tick)
    end
    if cfg.cliffs and math.random()<cfg.cliff_probability then
        local cliffs=query(root,budget,record.surface,{name="cliff",area={{p.x-4,p.y-4},{p.x+4,p.y+4}},limit=1})
        if cliffs and cliffs[1] then admit(root,record.surface,cliffs[1].position,"cliff",tick,{entity=cliffs[1]}) end
    end
    if cfg.planet~="nauvis" or not (cfg.flood or cfg.drought) then return end
    if budget.candidates<5 then return end
    budget.candidates=budget.candidates-5;budget.used_candidates=budget.used_candidates+5
    local tile=record.surface.get_tile(p)
    if not tile.valid then return end
    local flood=cfg.flood and policy.coast[tile.name] and math.random()<cfg.flood_probability
    local drought=cfg.drought and policy.freshwater[tile.name] and math.random()<cfg.drought_probability
    if not flood and not drought then return end
    local coastal=false
    for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local neighbor=record.surface.get_tile(p.x+delta[1],p.y+delta[2])
        if neighbor.valid and ((flood and policy.freshwater[neighbor.name]) or (drought and policy.coast[neighbor.name])) then coastal=true end
    end
    if coastal then propose(root,budget,record.surface,p.x,p.y,flood and "flood" or "drought",tick,flood and "water" or "sand-1") end
end
---@param tick MapTick
---@return boolean?
function model.has_tick_work(tick)
    local root=peek()
    return root and root.config and root.config.enabled and not root.compatibility and (root.enabled_surfaces or 0)>0 and tick>=root.next_tick
end
---@param event EventData.on_tick
function model.updater(event)
    local root=peek();if not model.has_tick_work(event.tick) then return end
    local tick=event.tick;local cfg=root.config
    root.next_tick=tick+cfg.interval;root.pass=root.pass+1
    local searches=0
    if tick>=(root.next_search or 0) then
        searches=cfg.searches;root.next_search=tick+(cfg.search_interval or cfg.interval)
        root.query_pass=(root.query_pass or 0)+1
    end
    local query_lane=(root.query_pass or 0)%3
    local budget={candidates=cfg.candidates,writes=cfg.writes,searches=searches,samples=cfg.active_chunks,events=cfg.events,histories=cfg.histories,batches={},positions={},used_candidates=0,used_writes=0,used_searches=0,used_events=0}
    calendar.service(root,tick,model.resolve_config)
    discover(root,tick)
    local visited={}
    for _=1,math.min(math.max(0,cfg.active_chunks-1),#root.active.items) do
        local record=visit_active(root,budget,next_record(root.active),tick)
        if record then visited[#visited+1]=record end
    end
    -- Query grants and discovery each have independent cursors: neither a Custom
    -- interval ratio nor a particular active/queue size can pin one priority.
    if searches>0 and query_lane==0 then service_entity_events(root,budget,tick) end
    if searches>0 and query_lane==1 then
        local record=visit_active(root,budget,next_record(root.active,"tree_cursor"),tick)
        if record then tree_service(root,budget,record,tick) end
    end
    local write_allowance=budget.writes
    budget.writes=math.min(budget.writes,cfg.recovery_reserved)
    if root.pass%4==0 then
        local tree_turn=true
        if cfg.histories==1 and #root.history.items>0 and #root.trees.items>0 and budget.searches>0 then
            root.history_tree_turn=not root.history_tree_turn;tree_turn=root.history_tree_turn
        end
        if tree_turn then recover_trees(root,budget,tick) end
    end
    recover_tiles(root,budget,tick)
    budget.writes=write_allowance-budget.used_writes
    service_events(root,budget,tick)
    -- Advance mutation coverage only while a query is available. Pollution polling
    -- on intervening services must not skip the same terrain on every query turn.
    for _=1,math.min(math.max(0,cfg.active_chunks-1),#root.active.items) do
        if budget.searches<=0 then break end
        local record=visit_active(root,budget,next_record(root.active,"terrain_cursor"),tick)
        if record then
            local c=effective(root,record.surface)
            if c and c.degradation and record.dirty_since and tick-record.dirty_since>=c.dirty_seconds*60 and tick>=record.next_soil then
                local result=propose(root,budget,record.surface,record.x*32+math.random(0,31),record.y*32+math.random(0,31),"pollution",tick)
                if result~=nil then record.next_soil=tick+c.soil_seconds*60/climate_rate(root,record.surface,c,tick) end
            end
            if c then hazards(root,budget,record,tick) end
        end
    end
    for _,record in ipairs(visited) do
        local c=effective(root,record.surface)
        -- Rotate clean cache entries when full; history does not depend on this cache.
        if c and #root.active.items>=cfg.active_cap and
            ((record.clean_since and tick-record.clean_since>c.clean_seconds*120) or tick-(record.resident_since or tick)>=36000) then remove(root.active,record.id) end
    end
    if #root.fires.items>0 and tick>=(root.next_fire_cleanup or 0) then
        root.next_fire_cleanup=tick+32
        for _=1,math.min(16,#root.fires.items) do
            local r=next_record(root.fires);if not lib.get_valid_entity(r.entity) or tick>=r.expires then remove(root.fires,r.id) end
        end
    end
    commit(root,budget)
    root.last_service={tick=tick,candidates=budget.used_candidates,writes=budget.used_writes,searches=budget.used_searches,search_allowance=searches,query_lane=query_lane,events=budget.used_events,active_samples=cfg.active_chunks-budget.samples,histories=cfg.histories-budget.histories}
    bump(root,"services")
    -- No telemetry serialization or status payload on the release hot path.
end
function model.get_overrides(surface)
    local root=peek();local entry=root and root.surfaces[surface.index]
    return entry and lib.copy_preset(nil,entry.overrides) or {}
end
---@param surface LuaSurface
---@param name string
---@param value boolean|number|string|nil
---@param tick MapTick
---@return boolean, LocalisedString
function model.set_override(surface,name,value,tick)
    local root=peek();local entry=root and root.surfaces[surface.index]
    if not entry then return false,{"ei-terrain.unsupported"} end
    local values={};for k,v in pairs(entry.overrides) do values[k]=v end
    values[name]=value
    local resolved,errors=config.resolve_surface(root.config,entry.planet,values)
    if #errors>0 then return false,{"ei-terrain.invalid-value"} end
    entry.overrides=values;entry.config=resolved
    if root.compatibility then entry.config.enabled=false end
    entry.iterator=nil;calendar.configure(root,tick)
    root.enabled_surfaces=0
    for _,s in pairs(root.surfaces) do if s.surface.valid and s.config.enabled then root.enabled_surfaces=root.enabled_surfaces+1 end end
    if root.enabled_surfaces==0 then calendar.release(root) end
    return true,{"ei-terrain.updated"}
end
function model.reset_overrides(surface,tick)
    local root=peek();local entry=root and root.surfaces[surface.index]
    if not entry then return false,{"ei-terrain.unsupported"} end
    entry.overrides={};entry.config=config.resolve_surface(root.config,entry.planet)
    if root.compatibility then entry.config.enabled=false end
    calendar.configure(root,tick)
    root.enabled_surfaces=0
    for _,s in pairs(root.surfaces) do if s.surface.valid and s.config.enabled then root.enabled_surfaces=root.enabled_surfaces+1 end end
    if root.enabled_surfaces==0 then calendar.release(root) end
    return true,{"ei-terrain.updated"}
end
function model.set_season_phase(surface,phase,tick)
    local root=peek();if not root then return false,{"ei-terrain.unsupported"} end
    return calendar.set_phase(root,surface,phase,tick)
end
---@param surface LuaSurface?
---@param tick MapTick
---@return table
function model.snapshot(surface,tick)
    local root=peek();if not root then return {status="disabled"} end
    local result={status=root.compatibility or (root.config.enabled and "enabled" or "disabled"),counters=root.counters,
        active=#root.active.items,pending=#root.pending.items,history=#root.history.items,tree_history=#root.trees.items,last_service=root.last_service}
    -- Explicit diagnostic/UI request only; closed panels never call this scan.
    result.sample_age=0;result.backlog_age=0;result.history_limit=root.config.tile_history_cap
    for _,record in ipairs(root.active.items) do
        if (not surface or record.surface==surface) and record.sample_tick then result.sample_age=math.max(result.sample_age,tick-record.sample_tick) end
    end
    for _,record in ipairs(root.pending.items) do
        if not surface or record.surface==surface then result.backlog_age=math.max(result.backlog_age,tick-record.tick) end
    end
    if surface then
        result.effective=effective(root,surface)
        if not root.compatibility and (not result.effective or not result.effective.enabled) then result.status="disabled" end
        result.calendar=calendar.snapshot(root,surface,tick)
        result.phase=result.calendar.phase
    end
    return result
end
return model
