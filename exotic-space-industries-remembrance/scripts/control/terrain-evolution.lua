--==============================================================================
-- ESIR FILE MAP
-- owns: bounded ecology admission, terrain protection, sparse recovery and seasons
-- loaded_by: control.lua
-- cadence: event admission; global service every 16 ticks, query grant every 32 by default
-- forwarded_events: entity/drill lifecycle, depletion, chunk/surface lifecycle, tile changes, global settings
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
---@field index EsirTerrainIndex|table<string, integer> Bucketed lookup, or a small plain fire index.
---@field cursor integer
---@field tree_cursor integer? Independent active-chunk tree discovery cursor.
---@field entity_cursor integer? Independent pending entity-action cursor.
---@field tile_cursor integer? Independent pending tile-action cursor.
---@field terrain_cursor integer? Advances only when terrain queries can run.
---@field hazard_cursor integer? Independent optional-hazard admission coverage.
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
---@field hazard_epoch integer? Rearms changed optional hazard settings lazily.
---@field effects table<string, integer>? Cumulative committed changes in the finite effect category set.
---@field effect_ticks table<string, MapTick>? Last committed change; absent historical times stay unknown.
---@field pollution_supported boolean? Native pollutant capability, independent of sample coverage.
---@class EsirTerrainFire
---@field entity LuaEntity
---@field surface LuaSurface
---@field started MapTick
---@field expires MapTick
---@field mode string
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
local work=require("scripts/control/terrain-ecology-work")
local terrain_index=require("lib/terrain-index")
local model={}
local owners={}
local self_write=false
local refresh_after_load=false
local entity_causes=work.entity_causes
local function peek() return storage.ei and storage.ei.terrain_evolution end
local function key(surface,x,y) return surface..":"..x..":"..y end
local function bump(root,name,n) root.counters[name]=(root.counters[name] or 0)+(n or 1) end

-- Dense domain sets have constant-time swap removal; no queue-wide compaction.
local function new_set(indexed) return {items={},index=indexed==false and {} or terrain_index.new(),cursor=1} end
local function attach_chunk(record)
    local entry=record.owner
    local cell=record.chunk_cell
    local token=entry.chunk_tokens[cell]
    if not token then token={references=0};entry.chunk_tokens[cell]=token end
    token.references=token.references+1;record.chunk_token=token
end
local function put(set,id,record)
    if set.index[id] then return false end
    record.id=id;record.ecology_version=2;set.items[#set.items+1]=record;set.index[id]=#set.items
    local root=peek();if root then work.count_record(root,record,set.kind) end
    return true
end
local function remove(set,id)
    local i=set.index[id];if not i then return end
    local record=set.items[i]
    local root=peek();if root and root.work and set.kind then work.retire_legacy(root,record) end
    work.uncount_record(record)
    if record.pending_class then set[record.pending_class]=math.max(0,(set[record.pending_class] or 0)-1) end
    if record.chunk_token then
        local token=record.chunk_token;token.references=token.references-1
        if token.references==0 and record.owner.chunk_tokens[record.chunk_cell]==token then record.owner.chunk_tokens[record.chunk_cell]=nil end
    end
    for _,part in ipairs(record.chunks or {}) do
        part.token.references=part.token.references-1
        if part.token.references==0 and record.owner.chunk_tokens[part.cell]==part.token then record.owner.chunk_tokens[part.cell]=nil end
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
-- Patch provenance is independent of unrelated chunk deletion on the surface.
local function attach_patch(record)
    if record.chunks or not record.owner then return end
    record.chunks={}
    local cfg=record.owner.config
    local radius=record.radius or (record.cause=="mining" and cfg.mining_patch_radius or cfg.hazard_radius)
    record.radius=radius
    for x=math.floor((record.x-radius)/32),math.floor((record.x+radius)/32) do
        for y=math.floor((record.y-radius)/32),math.floor((record.y+radius)/32) do
            local part={owner=record.owner,chunk_cell=x..":"..y};attach_chunk(part)
            record.chunks[#record.chunks+1]={cell=part.chunk_cell,token=part.chunk_token}
        end
    end
end
local function valid_patch(record,entry)
    if not entry or record.owner~=entry then return false end
    if not record.chunks and record.generation~=(entry.generation or 0) then return false end
    for _,part in ipairs(record.chunks or {}) do if entry.chunk_tokens[part.cell]~=part.token then return false end end
    return true
end
---@class EffectReceipt
---@field category string
---@field surface LuaSurface
---@field owner EsirTerrainSurface
---@field position MapPosition
---@field generation integer
---@field tick MapTick
---@field count integer
local function effect(root,surface,category,position,tick,count)
    local entry=root.surfaces[surface.index];if not entry then return end
    entry.effects=entry.effects or {};entry.effects[category]=(entry.effects[category] or 0)+(count or 1)
    -- One optional timestamp per committed category, not a retained event log.
    -- Old-save totals stay intact; absent historical times are never invented.
    entry.effect_ticks=entry.effect_ticks or {};entry.effect_ticks[category]=tick
    entry.last_effect_tick=tick;entry.last_effect=category
    if owners.effect then owners.effect{surface=surface,owner=entry,position=position,category=category,tick=tick,count=count or 1,generation=entry.generation or 0} end
end
local function state()
    storage.ei=storage.ei or {}
    local root=peek()
    if not root then
        root={version=1,surfaces={},surface_order={},surface_cursor=1,active=new_set(),history=new_set(),
            trees=new_set(),pending=new_set(),fires=new_set(false),counters={},next_tick=0,pass=0}
        storage.ei.terrain_evolution=root
    end
    return root
end
---@param context {vat: table, gaia: table}
function model.configure(context) owners=context end

---@param root table
---@param surface LuaSurface?
local function release_contained(root,surface)
    for i=math.min(16,#root.fires.items),1,-1 do
        local r=root.fires.items[i];local entity=lib.get_valid_entity(r.entity)
        if (not surface or r.surface==surface) and (not entity or entity.name=="ei-ecology-fire") then
            if entity then entity.destroy() end
            remove(root.fires,r.id)
        end
    end
end

local function effective(root,surface)
    local entry=root.surfaces[surface.index]
    return entry and entry.config
end
function model.resolve_config(surface)
    local root=peek()
    return root and effective(root,surface) or {enabled=false,seasonal_daylight=false}
end
---@param cfg table?
---@return boolean
local function hazards_enabled(cfg)
    return cfg~=nil and cfg.enabled and (cfg.wildfire~="off" or cfg.cliffs or cfg.flood or cfg.drought) or false
end
local function refresh_hazard_epoch(entry,previous)
    local cfg=entry.config
    if not previous or previous.enabled~=cfg.enabled or previous.periodic_mining_scars~=cfg.periodic_mining_scars
        or previous.periodic_mining_seconds~=cfg.periodic_mining_seconds or previous.intensity_multiplier~=cfg.intensity_multiplier then
        entry.drill_epoch=(entry.drill_epoch or 0)+1
    end
    if not previous or previous.enabled~=cfg.enabled or previous.wildfire~=cfg.wildfire
        or previous.cliffs~=cfg.cliffs or previous.flood~=cfg.flood or previous.drought~=cfg.drought
        or previous.hazard_seconds~=cfg.hazard_seconds or previous.wildfire_probability~=cfg.wildfire_probability
        or previous.pollution_high~=cfg.pollution_high or previous.wildfire_radius~=cfg.wildfire_radius
        or previous.cliff_probability~=cfg.cliff_probability or previous.flood_probability~=cfg.flood_probability
        or previous.drought_probability~=cfg.drought_probability
        or previous.intensity_multiplier~=cfg.intensity_multiplier then
        entry.hazard_epoch=(entry.hazard_epoch or 0)+1
    end
end
local function refresh_surface_counts(root)
    root.enabled_surfaces=0;root.hazard_surfaces=0
    for _,entry in pairs(root.surfaces) do
        if entry.surface.valid and entry.config.enabled and not entry.cleared then
            root.enabled_surfaces=root.enabled_surfaces+1
            if hazards_enabled(entry.config) then root.hazard_surfaces=root.hazard_surfaces+1 end
        end
    end
end
local function add_surface(root,surface,refresh)
    local planet=policy.planet(surface)
    if not planet then return end
    local entry=root.surfaces[surface.index]
    if not entry or entry.surface~=surface then
        entry={surface=surface,planet=planet,overrides={},protected={},classified={},chunk_tokens={}}
        root.surfaces[surface.index]=entry
    end
    local previous=entry.config
    -- Capability is known before the first observation; it is not a measured zero.
    entry.pollution_supported=surface.pollutant_type and surface.pollutant_type.name=="pollution" or false
    if refresh or not entry.config then entry.config=config.resolve_surface(root.config,planet,entry.overrides) end
    refresh_hazard_epoch(entry,previous)
end

---@param tick MapTick
function model.initialize(tick,reason)
    local root=state()
    local previous_interval=root.config and root.config.interval
    local previous_next_tick=root.next_tick
    root.config,root.config_errors=config.resolve()
    if previous_interval and previous_interval~=root.config.interval then release_contained(root) end
    -- Both external implementations conflict with ESIR 1.4. Re-resolve each
    -- surface from its retained preferences instead of keeping a stale disabled
    -- compatibility cache from a supported 2.0 save.
    root.compatibility=nil
    root.transitions,root.missing=policy.compile(prototypes.tile)
    root.surface_order={};root.surface_registered={}
    for _,surface in pairs(game.surfaces) do
        add_surface(root,surface,true)
        if root.surfaces[surface.index] then root.surface_order[#root.surface_order+1]=surface.index end
    end
    table.sort(root.surface_order)
    for i,index in ipairs(root.surface_order) do root.surface_registered[index]=i end
    refresh_surface_counts(root)
    -- Wildfire occupancy excludes approved natural trees before the capped query.
    -- Cultivated/unsupported tree names, resources and infrastructure remain visible.
    root.natural_exclusions={}
    root.native_tree_names={}
    for planet in pairs(policy.planets) do root.native_tree_names[planet]={} end
    for name,prototype in pairs(prototypes.entity) do
        -- Only dense natural forests need pre-query exclusion. Expanding every
        -- corpse prototype into this filter adds hundreds of native name lookups
        -- to each occupancy query; sparse remains/fish are ignored below.
        if name=="ei-ecology-alert-anchor" or policy.natural_trees[name] then
            root.natural_exclusions[#root.natural_exclusions+1]=name
        end
        if prototype.type=="tree" and policy.natural_trees[name] then
            for planet,names in pairs(root.native_tree_names) do if policy.native_tree(name,planet) then names[#names+1]=name end end
        end
    end
    table.sort(root.natural_exclusions)
    for _,names in pairs(root.native_tree_names) do table.sort(names) end
    root.surface_cursor=1;root.next_tick=tick+root.config.interval
    -- Unrelated settings must not postpone cleanup of an already-owned flame.
    if previous_interval==root.config.interval then root.next_tick=math.min(root.next_tick,previous_next_tick) end
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
    work.initialize(root,tick,reason)
    work.refresh_reports(root,tick)
    if not root.config.enabled or root.enabled_surfaces==0 then
        calendar.release(root)
        for _=1,math.min(16,#root.fires.items) do
            local r=root.fires.items[#root.fires.items]
            local entity=lib.get_valid_entity(r.entity)
            if entity and entity.name=="ei-ecology-fire" then entity.destroy() end
            remove(root.fires,r.id)
        end
        -- Disablement suspends accepted requests and lineage; it never discards them.
    end
end
function model.on_load()
    self_write=false
    local root=peek()
    refresh_after_load=root and root.config and (root.work==nil or root.hazard_surfaces==nil or root.natural_exclusions==nil
        or not terrain_index.is_facade(root.history.index) or not terrain_index.is_facade(root.trees.index)
        or not terrain_index.is_facade(root.pending.index) or not terrain_index.is_facade(root.active.index)) or false
end
function model.on_settings_changed(event)
    if event.setting_type~="runtime-global" then return end
    for _,row in ipairs(config.schema) do if row.setting_name==event.setting then model.initialize(event.tick);return end end
end
function model.on_surface_created(event)
    local surface=game.get_surface(event.surface_index)
    if not surface or not policy.planet(surface) then return end
    local root=peek()
    if not root or not root.transitions or not root.surface_registered then model.initialize(event.tick);return end
    local previous=root.surfaces[surface.index]
    local counted=previous and previous.config and previous.config.enabled and not previous.cleared
    local hazard_counted=counted and hazards_enabled(previous.config)
    add_surface(root,surface)
    local entry=root.surfaces[surface.index];entry.cleared=nil
    if entry.config.enabled and not counted then root.enabled_surfaces=root.enabled_surfaces+1 end
    if hazards_enabled(entry.config) and not hazard_counted then root.hazard_surfaces=(root.hazard_surfaces or 0)+1 end
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
    if entry then release_contained(root,entry.surface) end
    if entry then work.surface_removed(root,entry,event.tick) end
    if entry then root.protected_count=math.max(0,(root.protected_count or 0)-(entry.protected_count or 0)) end
    if entry and entry.config.enabled then root.enabled_surfaces=math.max(0,(root.enabled_surfaces or 0)-1) end
    if entry and hazards_enabled(entry.config) and not entry.cleared then root.hazard_surfaces=math.max(0,(root.hazard_surfaces or 0)-1) end
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
        work.invalidate_chunk(root,entry,cell)
        entry.chunk_tokens[cell]=nil
        if entry.protected[cell] then entry.protected_count=math.max(0,(entry.protected_count or 0)-1);root.protected_count=math.max(0,(root.protected_count or 0)-1) end
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
    local record={surface=surface,owner=entry,x=x,y=y,cause=cause,tick=tick,extra=extra,
        generation=entry.generation or 0,offset=0}
    attach_patch(record)
    return put(root.pending,id,record)
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
    local root=peek();if not root or not root.work then return end
    local entity=lib.get_valid_entity(event.entity or event.created_entity or event.destination)
    if entity then work.register_drill(root,entity,event.tick);admit(root,entity.surface,entity.position,"wake",event.tick) end
end
function model.on_entity_removed(event)
    local root=peek();if not root or not root.work then return end
    local id=lib.get_entity_unit_number(event.entity)
    if id then work.remove_drill(root,id,event.tick) end
end
function model.on_object_destroyed(event)
    local root=peek();if not root or not root.work then return end
    local id=root.work.registrations[event.registration_number]
    if id then work.remove_drill(root,id,event.tick) end
end
function model.on_teleported(event)
    local root=peek();local entity=lib.get_valid_entity(event.entity)
    if root and root.work and entity then work.relocate_drill(root,entity,event.tick) end
end
function model.on_entity_died(event)
    model.on_entity_removed(event)
    local root=peek();if not root or not root.config.enabled then return end
    local entity=lib.get_valid_entity(event.entity);if not entity then return end
    local cfg=effective(root,entity.surface);if not cfg or not cfg.enabled then return end
    if entity.type=="tree" and cfg.thermal_scars and event.damage_type and event.damage_type.name=="fire" then
        local cause=lib.get_valid_entity(event.cause)
        if not cause or thermal.thermal_fires[cause.name] or cause.type~="fire" then admit(root,entity.surface,entity.position,"thermal",event.tick) end
    elseif cfg.blood and (entity.type=="unit" or entity.type=="unit-spawner") and entity.force.name=="enemy"
        and math.random()<cfg.blood_probability then admit(root,entity.surface,entity.position,"blood",event.tick) end
end
local function mining_scar(root,surface,p,tick,trigger)
    local cfg=effective(root,surface)
    if not cfg or not cfg.enabled or not cfg.mining_scars then return false end
    local distance=cfg.mining_radius*(math.random()+math.random()-1);local angle=math.random()*math.pi*2
    return admit(root,surface,{x=p.x+math.cos(angle)*distance,y=p.y+math.sin(angle)*distance},"mining",tick,{trigger=trigger or "depletion"})
end
function model.on_resource_depleted(event)
    local root=peek();if not root or not root.config.enabled then return end
    local resource=lib.get_valid_entity(event.entity)
    if not resource or resource.type~="resource" or resource.prototype.infinite_resource then return end
    local surface=resource.surface;local cfg=effective(root,surface)
    if not cfg or not cfg.enabled or not cfg.mining_scars then return end
    local tick=event.tick
    if root.mine_tick~=tick then root.mine_tick=tick;root.mine_queries=0 end
    if root.mine_queries>=root.config.mining_queries then
        bump(root,"mining_saturated")
        admit(root,surface,resource.position,"mining-coverage",tick,{category=resource.prototype.resource_category,position=resource.position})
        return
    end
    local p=resource.position
    root.mine_queries=root.mine_queries+1
    local radius=root.drill_extent
    local drills=surface.find_entities_filtered{name=policy.drills,area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},limit=root.config.mining_candidates}
    bump(root,"mining_queries")
    for _,drill in ipairs(drills) do
        if drill.valid and drill.prototype.resource_categories[resource.prototype.resource_category] then
            local box=drill.mining_area
            if p.x>=box.left_top.x and p.x<=box.right_bottom.x and p.y>=box.left_top.y and p.y<=box.right_bottom.y then
                mining_scar(root,surface,p,tick,"depletion")
                return
            end
        end
    end
    if #drills>=root.config.mining_candidates then admit(root,surface,p,"mining-coverage",tick,{category=resource.prototype.resource_category,position=p}) end
end

local function protect_bounds(root,entry,minx,miny,maxx,maxy)
    root.protected_count=root.protected_count or 0
    entry.overflow_bounds=entry.overflow_bounds or {}
    local count=(maxx-minx+1)*(maxy-miny+1)
    if root.protected_count+count<=4096 then
        for x=minx,maxx do for y=miny,maxy do
            local cell=x..":"..y
            if not entry.protected[cell] then entry.protected[cell]=true;entry.protected_count=(entry.protected_count or 0)+1;root.protected_count=root.protected_count+1 end
        end end
        return
    end
    local rect={minx,miny,maxx,maxy};local bounds=entry.overflow_bounds
    if #bounds<16 then bounds[#bounds+1]=rect;return end
    local best,expansion
    for i,old in ipairs(bounds) do
        local area=(math.max(old[3],maxx)-math.min(old[1],minx)+1)*(math.max(old[4],maxy)-math.min(old[2],miny)+1)
        local increase=area-(old[3]-old[1]+1)*(old[4]-old[2]+1)
        if not expansion or increase<expansion then best=i;expansion=increase end
    end
    local old=bounds[best];bounds[best]={math.min(old[1],minx),math.min(old[2],miny),math.max(old[3],maxx),math.max(old[4],maxy)}
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
    protect_bounds(root,entry,math.floor((position.x+minx-4)/32),math.floor((position.y+miny-4)/32),math.floor((position.x+maxx+4)/32),math.floor((position.y+maxy+4)/32))
end
local function query(root,budget,surface,filter)
    if budget.searches<=0 then return nil end
    budget.searches=budget.searches-1;budget.used_searches=budget.used_searches+1
    filter.limit=math.min(filter.limit or root.config.result_limit,root.config.result_limit)
    return surface.find_entities_filtered(filter)
end
local function mining_query(root,budget,surface,filter,tick)
    if root.mine_tick~=tick then root.mine_tick=tick;root.mine_queries=0 end
    if root.mine_queries>=1 or budget.searches<=0 then return nil end
    root.mine_queries=root.mine_queries+1;bump(root,"mining_queries")
    return query(root,budget,surface,filter)
end
local function classify_chunk(root,budget,entry,cx,cy)
    if entry.planet~="gaia" or entry.protection_saturated then return true end
    local cell=cx..":"..cy
    if entry.classified[cell] or entry.protected[cell] then return true end
    local extent=root.anchor_extent+48
    local found=query(root,budget,entry.surface,{name="ei-artifact-flag",area={{cx*32-extent,cy*32-extent},{cx*32+extent,cy*32+extent}},limit=1})
    if not found then return nil end
    entry.classified_order=entry.classified_order or {};entry.classified_cursor=(entry.classified_cursor or 0)%math.min(4096,root.config.active_cap)+1
    local old=entry.classified_order[entry.classified_cursor]
    if old and entry.classified[old] then entry.classified[old]=nil;entry.classified_count=math.max(0,(entry.classified_count or 0)-1) end
    entry.classified_order[entry.classified_cursor]=cell;entry.classified[cell]=true;entry.classified_count=(entry.classified_count or 0)+1
    if #found>0 then protect_bounds(root,entry,cx,cy,cx,cy) end
    return true
end
local function protected(root,budget,surface,x,y,cfg,water,ignore,density_limit,natural_exclusions)
    local entry=root.surfaces[surface.index];if not entry or entry.surface~=surface then return true end
    if not surface.is_chunk_generated({math.floor(x/32),math.floor(y/32)}) then return true end
    if owners.vat.is_terrain_claimed(surface.index,x,y) then return true end
    if entry.planet=="gaia" then
        local cell=math.floor(x/32)..":"..math.floor(y/32)
        if entry.protection_saturated or entry.protected[cell] then return true end
        local cx,cy=math.floor(x/32),math.floor(y/32)
        for _,rect in ipairs(entry.overflow_bounds or {}) do if cx>=rect[1] and cy>=rect[2] and cx<=rect[3] and cy<=rect[4] then return true end end
        if not entry.classified[cell] then
            if not classify_chunk(root,budget,entry,cx,cy) then return nil end
            if entry.protected[cell] then return true end
            return nil -- Remaining occupancy inspection gets its own bounded pass.
        end
    end
    local buffer=water and math.max(8,cfg.protection_buffer) or cfg.protection_buffer
    local filter={area={{x-buffer,y-buffer},{x+1+buffer,y+1+buffer}}}
    filter.name=root.natural_exclusions;filter.invert=true
    local found=query(root,budget,surface,filter)
    if not found then return nil end
    if #found>=root.config.result_limit then bump(root,"occupancy_limited");return true end
    local trees=0
    for _,entity in ipairs(found) do
        if entity.valid and entity.type=="tree" and policy.natural_trees[entity.name] then trees=trees+1 end
        if entity~=ignore and entity.valid and entity.type~="corpse" and entity.type~="fish"
            and not (entity.type=="tree" and policy.natural_trees[entity.name]) then return true end
    end
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
local function propose(root,budget,surface,x,y,cause,tick,target,recover,request)
    if budget.candidates<=0 or budget.writes<=0 or budget.searches<=0 then return nil end
    if not recover and budget.writes<=(budget.recovery_reserved or 0) then return nil end
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
    local permanent=cause=="mining" and not cfg.mining_recovery
    if not history and not permanent and not paving and #root.history.items>=root.config.tile_history_cap then bump(root,"history_full");return false end
    if tile.name==next_name then return false end
    local protect=protected(root,budget,surface,x,y,cfg,water)
    if protect==nil then return nil end
    if protect then bump(root,"protected");local entry=root.surfaces[surface.index];entry.protection_skips=(entry.protection_skips or 0)+1;return false end
    -- Reserve a slot before the write, but leave any committed lineage intact.
    -- The receipt applies its delta only after the native tile has changed.
    local new_history=false
    if not permanent and not paving and not history then
        local entry=root.surfaces[surface.index]
        history={surface=surface,owner=entry,x=x,y=y,origin=tile.name,expected=tile.name,path={},cause=cause,next_tick=tick,
            generation=entry.generation or 0}
        history.chunk_cell=math.floor(x/32)..":"..math.floor(y/32);attach_chunk(history)
        put(root.history,id,history)
        new_history=true
    end
    budget.positions[id]=true
    local batch=budget.batches[surface.index]
    if not batch then batch={surface=surface,tiles={}};budget.batches[surface.index]=batch end
    batch.tiles[#batch.tiles+1]={name=next_name,position={x,y}}
    batch.expected=batch.expected or {};batch.expected[#batch.expected+1]=tile.name
    batch.receipts=batch.receipts or {};batch.receipts[#batch.receipts+1]={cause=cause,recover=recover,paving=paving,tick=tick,
        trigger=budget.mining_trigger,request=request,history=history,new_history=new_history,retire=permanent or paving,
        previous=tile.name,next_recovery=tick+cfg.recovery_seconds*60/cfg.intensity_multiplier}
    budget.writes=budget.writes-1;budget.used_writes=budget.used_writes+1
    if recover then budget.recovery_reserved=math.max(0,(budget.recovery_reserved or 0)-1) end
    return true
end
local function commit(root,budget)
    for _,batch in pairs(budget.batches) do
        local accepted={};local receipts={}
        for i,tile in ipairs(batch.tiles) do
            local actual=batch.surface.get_tile(tile.position)
            if actual.valid and actual.name==batch.expected[i] then accepted[#accepted+1]=tile;receipts[#receipts+1]=batch.receipts[i]
            else
                if batch.receipts[i].request then batch.receipts[i].request.last_result="ineligible" end
                remove(root.history,key(batch.surface.index,tile.position[1],tile.position[2]));bump(root,"ownership_lost")
            end
        end
        self_write=true
        if #accepted>0 then batch.surface.set_tiles(accepted,false,false,false,true) end
        self_write=false
        for i,tile in ipairs(accepted) do
            local receipt=receipts[i]
            if batch.surface.get_tile(tile.position).name==tile.name then
                local history=receipt.history
                if receipt.retire then remove(root.history,key(batch.surface.index,tile.position[1],tile.position[2]))
                elseif history then
                    if receipt.cause=="mining" and history.cause~="mining" and not receipt.recover then
                        history.origin=receipt.previous;history.path={};history.cause="mining"
                    end
                    if receipt.recover then history.path[#history.path]=nil else history.path[#history.path+1]=receipt.previous end
                    history.expected=tile.name;history.next_tick=receipt.next_recovery
                    if #history.path==0 then remove(root.history,history.id) end
                end
                if receipt.request then receipt.request.last_result="applied" end
                bump(root,receipt.recover and "recovered" or "changed")
                local category=receipt.paving and "paving" or receipt.cause
                if receipt.recover then category=receipt.cause=="mining" and "mining-restoration" or (receipt.cause=="blood" and "blood" or "restoration")
                elseif receipt.cause=="mining" then category=receipt.trigger=="working" and "working-scars" or "depletion-scars" end
                effect(root,batch.surface,category,{x=tile.position[1],y=tile.position[2]},receipt.tick)
                if not policy.freshwater[tile.name] then
                    batch.surface.destroy_decoratives{position=tile.position,name={"green-pita","green-pita-mini","green-bush-mini"},exclude_soft=false}
                end
            else
                if receipt.request then receipt.request.last_result="ineligible" end
                if receipt.new_history or batch.surface.get_tile(tile.position).name~=receipt.previous then
                    remove(root.history,key(batch.surface.index,tile.position[1],tile.position[2]));bump(root,"ownership_lost")
                end
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
    local pollution
    if surface.pollutant_type and surface.pollutant_type.name=="pollution" then pollution=surface.get_pollution({record.x*32+16,record.y*32+16}) end
    if record.sample_tick and tick-record.sample_tick>1200 then record.clean_since=nil;record.dirty_since=nil end
    record.pollution=pollution;record.sample_tick=tick
    entry.last_sample_tick=tick;entry.last_pollution=pollution
    entry.pollution_supported=surface.pollutant_type and surface.pollutant_type.name=="pollution" or false
    if pollution==nil then record.clean_since=nil;record.dirty_since=nil;bump(root,"unsupported_samples");return true end
    if pollution>=cfg.pollution_high then record.dirty_since=record.dirty_since or tick;record.clean_since=nil
    elseif pollution<=cfg.pollution_low then record.clean_since=record.clean_since or tick;record.dirty_since=nil
    else record.clean_since=nil;record.dirty_since=nil end
    entry.last_dirty_since=record.dirty_since;entry.last_clean_since=record.clean_since
    bump(root,"samples")
    return true
end
local function active(root,surface,x,y,tick)
    local id=key(surface.index,x,y);local i=root.active.index[id]
    if i then return root.active.items[i],false end
    if #root.active.items>=root.config.active_cap then return nil end
    local entry=root.surfaces[surface.index]
    local record={surface=surface,owner=entry,generation=entry.generation or 0,x=x,y=y,resident_since=tick,next_soil=tick,next_tree=tick,next_hazard=tick}
    local slot=root.work and root.work.observation_keys[id];local observation=slot and root.work.observations[slot]
    if observation then record.schedule=observation.schedule;observation.schedule_owner=record end
    record.chunk_cell=x..":"..y;attach_chunk(record)
    put(root.active,id,record)
    return record,true
end
-- A cached sample can drive due work on later turns. Tying work to a fresh
-- 600-tick sample aliases short service intervals with query-priority rotation.
local function visit_active(root,budget,record,tick)
    if not record then return end
    local entry=record.surface.valid and root.surfaces[record.surface.index]
    if not entry or record.owner~=entry
        or entry.chunk_tokens[record.chunk_cell]~=record.chunk_token then
        remove(root.active,record.id);return
    end
    if not entry.config.enabled then return end
    work.observe(root,entry,record.x,record.y,"ecology",tick)
    local climate=work.observation(root,entry,record.x,record.y,tick)
    if not climate then return end
    return climate
end
local function discover(root,tick)
    for _=1,root.config.cold_chunks do
        if #root.surface_order==0 then break end
        if root.surface_cursor>#root.surface_order then root.surface_cursor=1 end
        local entry=root.surfaces[root.surface_order[root.surface_cursor]]
        root.surface_cursor=root.surface_cursor+1
        if entry and entry.surface.valid and entry.config.enabled then
            if entry.drill_discovery then return end
            if not entry.iterator or not entry.iterator.valid then entry.iterator=entry.surface.get_chunks() end
            local chunk=entry.iterator()
            work.discovery_visit(root,entry,chunk,tick)
            if not chunk then entry.iterator=nil
            else
                local record,created=active(root,entry.surface,chunk.x,chunk.y,tick)
                if record and created then work.observe(root,entry,chunk.x,chunk.y,"ecology",tick) end
            end
        end
    end
end
local function climate_rate(root,surface,cfg,tick)
    if not cfg.seasonal_ecology then return cfg.intensity_multiplier end
    local phase=calendar.phase(root,surface,tick)
    return cfg.intensity_multiplier*(1+cfg.season_strength*math.sin(2*math.pi*(phase or 0)))
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
        elseif budget.positions[record.id] then
            -- The current batch owns this slot until final write validation.
        elseif surface.get_tile(record.x,record.y).name~=record.expected then remove(root.history,record.id);bump(root,"ownership_lost")
        else
            local cfg=effective(root,surface)
            if cfg and cfg.enabled and cfg.recovery and (record.cause~="mining" or cfg.mining_recovery) and tick>=record.next_tick and tick>=(record.retry_tick or 0) then
                work.request_recovery(root,entry,record,tick)
                local c=work.observation(root,entry,math.floor(record.x/32),math.floor(record.y/32),tick)
                if recovery_turn and c and c.clean_since and tick-c.clean_since>=cfg.clean_seconds*60 then
                    local result=propose(root,budget,surface,record.x,record.y,record.cause,tick,record.path[#record.path],true)
                    if result==nil then return end
                    c.attempts=c.attempts+1
                    if result==false then work.backoff(record,tick) else record.retries=nil;record.retry_tick=nil end
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
        if entry then entry.last_pending_age=tick-record.tick;entry.last_pending_tick=tick end
        if not valid_patch(record,entry) then remove(root.pending,record.id)
        elseif not cfg.enabled or ((record.cause=="mining" or record.cause=="mining-coverage") and not cfg.mining_scars) or tick<(record.retry_tick or 0) then
            -- Accepted mining requests pause without expiry or re-rolling.
        elseif (record.cause=="mining" and not cfg.mining_scars)
            or (record.cause=="thermal" and not cfg.thermal_scars)
            or (record.cause=="blood" and not cfg.blood) then remove(root.pending,record.id)
        elseif record.cause=="wake" then
            active(root,surface,math.floor(record.x/32),math.floor(record.y/32),tick);remove(root.pending,record.id)
        elseif tile_turn and record.cause=="mining-coverage" then
            local p=record.extra.position or {x=record.x,y=record.y};local radius=root.drill_extent
            local limit=math.min(root.config.mining_candidates,budget.candidates)
            if limit==0 then return end
            record.extra.areas=record.extra.areas or {{p.x-radius,p.y-radius,p.x+radius,p.y+radius,0}}
            local area=record.extra.areas[#record.extra.areas]
            local found=mining_query(root,budget,surface,{name=policy.drills,area={{area[1],area[2]},{area[3],area[4]}},limit=limit},tick)
            if not found then return end
            budget.candidates=budget.candidates-#found;budget.used_candidates=budget.used_candidates+#found
            local qualified=false
            for _,drill in ipairs(found) do
                if drill.valid and drill.prototype.resource_categories[record.extra.category] then
                    local box=drill.mining_area
                    if p.x>=box.left_top.x and p.x<=box.right_bottom.x and p.y>=box.left_top.y and p.y<=box.right_bottom.y then qualified=true;break end
                end
            end
            if qualified then
                for _,part in ipairs(record.chunks or {}) do part.token.references=part.token.references-1;if part.token.references==0 and entry.chunk_tokens[part.cell]==part.token then entry.chunk_tokens[part.cell]=nil end end
                local distance=cfg.mining_radius*(math.random()+math.random()-1);local angle=math.random()*math.pi*2
                record.x=math.floor(p.x+math.cos(angle)*distance);record.y=math.floor(p.y+math.sin(angle)*distance)
                record.cause="mining";record.extra={trigger="depletion"};record.chunks=nil;record.radius=cfg.mining_patch_radius;attach_patch(record)
            elseif #found>=limit then
                if area[5]<16 then
                    record.extra.areas[#record.extra.areas]=nil
                    if area[3]-area[1]>=area[4]-area[2] then
                        local mid=(area[1]+area[3])/2
                        record.extra.areas[#record.extra.areas+1]={area[1],area[2],mid,area[4],area[5]+1}
                        record.extra.areas[#record.extra.areas+1]={mid,area[2],area[3],area[4],area[5]+1}
                    else
                        local mid=(area[2]+area[4])/2
                        record.extra.areas[#record.extra.areas+1]={area[1],area[2],area[3],mid,area[5]+1}
                        record.extra.areas[#record.extra.areas+1]={area[1],mid,area[3],area[4],area[5]+1}
                    end
                else work.backoff(record,tick);bump(root,"mining_coverage_limited") end
            else
                record.extra.areas[#record.extra.areas]=nil
                if #record.extra.areas==0 then remove(root.pending,record.id) end
            end
        elseif tile_turn and record.cause~="regrowth" and record.cause~="tree" and record.cause~="aging" and record.cause~="rot" and record.cause~="ignite" and record.cause~="cliff" then
            local radius=record.radius or (record.cause=="mining" and cfg.mining_patch_radius or cfg.hazard_radius)
            local width=radius*2+1
            local x=record.offset%width-radius;local y=math.floor(record.offset/width)-radius
            if record.offset>=width*width then remove(root.pending,record.id)
            else
                local result=false
                if record.roll==nil then record.roll=record.cause~="mining" or math.random()<cfg.mining_probability end
                if x*x+y*y<radius*radius+1 and record.roll then
                    local target
                    if record.cause=="blood" then
                        local h=root.history.index[key(surface.index,record.x+x,record.y+y)]
                        if h then target=root.history.items[h].path[#root.history.items[h].path]
                        elseif cfg.paving then
                            if record.paving_roll==nil then record.paving_roll=math.random()<cfg.paving_probability end
                            local tile=surface.get_tile(record.x+x,record.y+y)
                            -- Concrete corrosion is an explicit destructive opt-in.
                            if record.paving_roll and tile.valid and (tile.name=="stone-path" or tile.name:find("concrete",1,true)) then
                                target=tile.hidden_tile
                            end
                        end
                        if not target then result=false
                        else result=propose(root,budget,surface,record.x+x,record.y+y,"blood",tick,target,h~=nil,record) end
                    else
                        budget.mining_trigger=record.extra and record.extra.trigger
                        result=propose(root,budget,surface,record.x+x,record.y+y,record.cause,tick,record.extra and record.extra.target,false,record)
                        budget.mining_trigger=nil
                    end
                end
                -- Staging reserves lineage; only the guarded commit can report
                -- an applied effect after the actual tile write succeeds.
                record.last_result=result==true and "retry" or work.result(result,budget.searches==0)
                if result==nil then if budget.searches==0 then record.retry_tick=tick+root.config.interval end;return end
                record.offset=record.offset+1;record.roll=nil;record.paving_roll=nil
            end
        end
    end
end

local function tree_service(root,budget,record,tick)
    local surface=record.surface;local cfg=effective(root,surface)
    local schedule=record.schedule or record
    local names=root.native_tree_names and root.native_tree_names[cfg.planet]
    if names and #names==0 then
        if schedule.draining then for _,kind in ipairs({"tree","regrowth","aging","rot"}) do schedule.draining[kind]=nil end end
        return
    end
    local kinds={{"tree",cfg.tree_stress,cfg.tree_stress_seconds},{"regrowth",cfg.tree_regrowth,cfg.tree_growth_seconds},
        {"aging",cfg.aging,cfg.tree_aging_seconds},{"rot",cfg.rot,cfg.tree_rot_seconds}}
    local kind,seconds
    schedule.tree_due=schedule.tree_due or {}
    for n=1,4 do
        local i=((schedule.tree_kind or 0)+n-1)%4+1;local k=kinds[i]
        if k[2] and (not schedule.draining or schedule.draining[k[1]]) and tick>=(schedule.tree_due[k[1]] or 0) then kind=k[1];seconds=k[3];schedule.tree_kind=i;break end
    end
    if not kind then return end
    local x,y=record.x*32+math.random(0,31),record.y*32+math.random(0,31)
    local radius=cfg.tree_neighborhood
    local trees=query(root,budget,surface,{type="tree",name=names,area={{x-radius,y-radius},{x+1+radius,y+1+radius}}})
    if not trees then return end
    if schedule.draining then schedule.draining[kind]=nil end
    schedule.tree_due[kind]=tick+seconds*60/climate_rate(root,surface,cfg,tick)
    local tree
    for _,candidate in ipairs(trees) do
        if candidate.valid and policy.native_tree(candidate.name,cfg.planet)
            and (policy.dead_trees[candidate.name]==true)==(kind=="rot") then tree=candidate;break end
    end
    if not tree then return end
    local p=tree.position;local id=key(surface.index,p.x,p.y)
    if kind=="tree" then admit(root,surface,p,"tree",tick,{tree=tree,pollution=record.pollution,dirty_since=record.dirty_since,clean_since=record.clean_since,sample_tick=record.sample_tick}) end
    if kind=="rot" and policy.dead_trees[tree.name] then
        admit(root,surface,p,"rot",tick,{tree=tree});return
    end
    if kind=="aging" and not policy.dead_trees[tree.name] then
        admit(root,surface,p,"aging",tick,{tree=tree});return
    end
    if kind=="regrowth" and record.clean_since and tick-record.clean_since>=cfg.clean_seconds*60
        and #trees<cfg.tree_density_limit and not policy.dead_trees[tree.name] then
        admit(root,surface,{x=p.x+math.random(-cfg.seed_distance,cfg.seed_distance),y=p.y+math.random(-cfg.seed_distance,cfg.seed_distance)},"regrowth",tick,{name=tree.name})
    end
end

local function entity_event(root,budget,record,tick)
    local surface=record.surface;local cfg=effective(root,surface)
    local p={x=record.x+0.5,y=record.y+0.5}
    local ignition_tree=record.cause=="ignite" and record.extra and lib.get_valid_entity(record.extra.tree)
    if record.cause=="ignite" and record.extra and record.extra.tree and not ignition_tree then return false end
    if ignition_tree then
        if ignition_tree.surface~=surface or not policy.native_tree(ignition_tree.name,cfg.planet) then return false end
        p=ignition_tree.position
        if math.floor(p.x)~=record.x or math.floor(p.y)~=record.y then return false end
    end
    if budget.searches>0 and record.cause=="regrowth" and cfg.planet=="gaia" and budget.candidates<27 then budget.deferred_entity=record;return nil end
    if budget.candidates<=0 or budget.searches<=0 then return nil end
    if record.cause=="regrowth" and (not record.density_checked or tick-record.density_checked>3600) then
        local r=cfg.tree_neighborhood
        local names=root.native_tree_names and root.native_tree_names[cfg.planet]
        if names and #names==0 then return false end
        local trees=query(root,budget,surface,{type="tree",name=names,area={{p.x-r,p.y-r},{p.x+r,p.y+r}},limit=cfg.tree_density_limit})
        if not trees then return nil end
        if #trees>=cfg.tree_density_limit then return false end
        record.density_checked=tick;return nil,"retry"
    end
    -- This indivisible Gaia operation must receive its entire allowance before
    -- protection or optional work spends any of it. A deferred grant runs first.
    if record.cause=="regrowth" and cfg.planet=="gaia" and budget.candidates<27 then
        budget.deferred_entity=record;return nil
    end
    budget.candidates=budget.candidates-1;budget.used_candidates=budget.used_candidates+1
    local tile=surface.get_tile(record.x,record.y)
    local wetland_tree=cfg.planet=="gleba" and (record.cause=="tree" or record.cause=="regrowth")
    if not tile.valid or tile.hidden_tile or tile.double_hidden_tile or tile.prototype.is_foundation
        or (tile.collides_with("water_tile") and not wetland_tree)
        or not policy.natural_tiles[tile.name] or policy.family(tile.name)~=cfg.planet then return false end
    local blocked=protected(root,budget,surface,record.x,record.y,cfg,true,record.extra and record.extra.entity,record.cause=="regrowth" and cfg.tree_density_limit or nil,record.cause=="ignite")
    if blocked==nil then return nil end
    if blocked then if record.cause=="ignite" then bump(root,"wildfire_protected") end;return false end
    if record.cause=="tree" then
        local tree=lib.get_valid_entity(record.extra.tree)
        if not cfg.tree_stress or not tree or not policy.native_tree(tree.name,cfg.planet) then return false end
        local id=key(surface.index,tree.position.x,tree.position.y)
        local index=root.trees.index[id];local history=index and root.trees.items[index]
        if history and history.entity~=tree then remove(root.trees,id);history=nil end
        if history and history.expected and tree.tree_gray_stage_index~=history.expected then remove(root.trees,id);return false end
        local climate=work.observation(root,root.surfaces[surface.index],math.floor(record.x/32),math.floor(record.y/32),tick)
        if not climate then work.observe(root,root.surfaces[surface.index],math.floor(record.x/32),math.floor(record.y/32),"recovery",tick);return nil,"retry" end
        if climate.pollution and climate.pollution>=cfg.pollution_high and climate.dirty_since and tick-climate.dirty_since>=cfg.dirty_seconds*60 then
            local next_gray=math.min(tree.tree_gray_stage_index_max,tree.tree_gray_stage_index+1)
            if next_gray==tree.tree_gray_stage_index then return false end
            if not history and #root.trees.items<root.config.tree_history_cap then
                history={surface=surface,entity=tree,stage=tree.tree_stage_index,gray=tree.tree_gray_stage_index,next_tick=tick+cfg.recovery_seconds*60}
                put(root.trees,id,history)
            end
            if history then tree.tree_gray_stage_index=next_gray;history.expected=next_gray;bump(root,"tree_stressed");effect(root,surface,"tree-stress",p,tick);return true end
        elseif history and climate.pollution and climate.pollution<=cfg.pollution_low and climate.clean_since and tick-climate.clean_since>=cfg.clean_seconds*60 then
            if tree.tree_gray_stage_index~=history.expected then remove(root.trees,id)
            else
                tree.tree_gray_stage_index=math.max(history.gray,tree.tree_gray_stage_index-1);history.expected=tree.tree_gray_stage_index
                effect(root,surface,"tree-recovery",p,tick)
                if history.expected==history.gray then remove(root.trees,id) end
                return true
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
        if root.last_tree_created and tick-root.last_tree_created<600 then return nil,"retry" end
        local entity=surface.create_entity{name=name,position=p,force="neutral",raise_built=true}
        if entity then root.last_tree_created=tick;bump(root,"trees_grown");effect(root,surface,"regrowth",p,tick);return true end
    elseif record.cause=="rot" or record.cause=="aging" then
        local tree=lib.get_valid_entity(record.extra.tree)
        if not tree or not policy.native_tree(tree.name,cfg.planet) then return false end
        if record.cause=="rot" and cfg.rot and policy.dead_trees[tree.name] then
            if tree.destroy{raise_destroy=true} then bump(root,"trees_rotted");effect(root,surface,"rot",p,tick);return true end
        elseif record.cause=="aging" and cfg.aging and not policy.dead_trees[tree.name] then
            -- Only Nauvis has an approved deadwood replacement family.
            local dead
            if cfg.planet=="nauvis" then dead="dry-tree" end
            if dead and prototypes.entity[dead] then
                local position=tree.position
                if tree.destroy{raise_destroy=true} then
                    local replacement=surface.create_entity{name=dead,position=position,force="neutral"}
                    if not replacement then bump(root,"tree_replacement_failed") end
                    -- Aging records the committed loss of the living tree;
                    -- a failed deadwood replacement is separate diagnostics.
                    bump(root,"trees_aged");effect(root,surface,"aging",position,tick);return true
                end
            end
        end
    elseif record.cause=="ignite" then
        if cfg.wildfire=="off" then return false end
        if #root.fires.items>=16 or tick<(root.next_fire or 0) then return nil,"retry" end
        local name=cfg.wildfire=="contained" and "ei-ecology-fire" or "fire-flame-on-tree"
        local flame=surface.create_entity{name=name,position=p,target=ignition_tree,force="neutral",initial_ground_flame_count=1}
        if flame then
            -- Reserve worst-case cleanup cadence so even Custom intervals stay
            -- within the contained mode's ten-second upper lifetime.
            local lifetime=cfg.wildfire=="contained" and math.max(1,600-32-math.max(0,root.config.interval-1)) or 660
            put(root.fires,key(surface.index,tick,#root.fires.items),{surface=surface,entity=flame,started=tick,expires=tick+lifetime,mode=cfg.wildfire})
            root.next_fire=tick+600;bump(root,"ignitions")
            effect(root,surface,"wildfire",p,tick)
            return true
        end
        if not flame then bump(root,"wildfire_creation_failed");return false end
    elseif record.cause=="cliff" then
        local entity=lib.get_valid_entity(record.extra.entity)
        if cfg.cliffs and entity and entity.type=="cliff" and entity.name=="cliff" and entity.destroy{do_cliff_correction=true,raise_destroy=true} then bump(root,"cliffs_eroded");effect(root,surface,"cliff",p,tick);return true end
    end
    return false
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
                local entry=root.surfaces[r.surface.index]
                work.request_recovery(root,entry,r,tick)
                local c=work.observation(root,entry,math.floor(p.x/32),math.floor(p.y/32),tick)
                if c and c.clean_since and tick-c.clean_since>=cfg.clean_seconds*60 then
                    admit(root,r.surface,p,"tree",tick,{tree=tree,pollution=c.pollution,clean_since=c.clean_since})
                    r.next_tick=tick+cfg.recovery_seconds*60/cfg.intensity_multiplier
                end
            end
        end
    end
end
local function service_entity_events(root,budget,tick)
    for _=1,math.min(budget.events,#root.pending.items) do
        if budget.searches<=0 then break end
        local record=root.work.deferred_entity
        root.work.deferred_entity=nil
        if not record or root.pending.items[root.pending.index[record.id] or 0]~=record then record=next_record(root.pending,"entity_cursor") end
        budget.events=budget.events-1;budget.used_events=budget.used_events+1
        if record and entity_causes[record.cause] then
            local entry=record.surface.valid and root.surfaces[record.surface.index]
            if not valid_patch(record,entry) then remove(root.pending,record.id)
            elseif entry.config.enabled and tick>=(record.retry_tick or 0) then
                local result,waiting=entity_event(root,budget,record,tick)
                record.last_result=waiting or work.result(result,false)
                if result==nil then
                    if waiting=="retry" then work.backoff(record,tick) end
                    return
                end
                remove(root.pending,record.id)
            end
        end
    end
end
local function hazards(root,budget,record,tick)
    if budget.searches<=0 then return end
    local cfg=effective(root,record.surface)
    if not hazards_enabled(cfg) then return end
    local epoch=root.surfaces[record.surface.index].hazard_epoch or 0
    local schedule=record.schedule or record
    if schedule.hazard_epoch~=epoch then schedule.hazard_epoch=epoch;schedule.hazard_due={} end
    schedule.hazard_due=schedule.hazard_due or {}
    local p={x=record.x*32+math.random(0,31),y=record.y*32+math.random(0,31)}
    -- One due opportunity selects one enabled hazard family. A successful tree
    -- query cannot silently consume the other families' only search allowance.
    local kind
    local names={"wildfire","cliff","flood","drought"}
    for offset=1,4 do
        local candidate=((schedule.hazard_kind or 0)+offset-1)%4+1
        if (not schedule.draining or schedule.draining[names[candidate]]) and tick>=(schedule.hazard_due[candidate] or 0) and ((candidate==1 and cfg.wildfire~="off" and cfg.wildfire_probability>0)
            or (candidate==2 and cfg.cliffs and cfg.cliff_probability>0)
            or (candidate==3 and cfg.planet=="nauvis" and cfg.flood and cfg.flood_probability>0)
            or (candidate==4 and cfg.planet=="nauvis" and cfg.drought and cfg.drought_probability>0)) then
            kind=candidate;schedule.hazard_kind=candidate;break
        end
    end
    if not kind then return end
    if kind>=3 and budget.candidates<5 then budget.deferred_lane="H";return end
    if schedule.draining then schedule.draining[names[kind]]=nil end
    schedule.hazard_due[kind]=tick+cfg.hazard_seconds*60/climate_rate(root,record.surface,cfg,tick)
    if kind==1 then
        if not record.pollution or record.pollution<cfg.pollution_high then return end
        bump(root,"wildfire_attempts")
        if math.random()<cfg.wildfire_probability then
            local radius=cfg.wildfire_radius
            local names=root.native_tree_names and root.native_tree_names[cfg.planet]
            if names and #names==0 then bump(root,"wildfire_no_fuel");return end
            local trees=query(root,budget,record.surface,{type="tree",name=names,area={{p.x-radius,p.y-radius},{p.x+1+radius,p.y+1+radius}}})
            local tree
            for _,candidate in ipairs(trees or {}) do
                if candidate.valid and policy.native_tree(candidate.name,cfg.planet) then tree=candidate;break end
            end
            if tree then
                if admit(root,record.surface,tree.position,"ignite",tick,{tree=tree}) then bump(root,"wildfire_candidates") end
            else bump(root,"wildfire_no_fuel") end
        end
    elseif kind==2 and math.random()<cfg.cliff_probability then
        local cliffs=query(root,budget,record.surface,{name="cliff",area={{p.x-4,p.y-4},{p.x+4,p.y+4}},limit=1})
        if cliffs and cliffs[1] then admit(root,record.surface,cliffs[1].position,"cliff",tick,{entity=cliffs[1]}) end
    end
    if kind<3 then return end
    if budget.candidates<5 then return end
    budget.candidates=budget.candidates-5;budget.used_candidates=budget.used_candidates+5
    local tile=record.surface.get_tile(p)
    if not tile.valid then return end
    local flood=kind==3 and policy.coast[tile.name] and math.random()<cfg.flood_probability
    local drought=kind==4 and policy.freshwater[tile.name] and math.random()<cfg.drought_probability
    if not flood and not drought then return end
    local coastal=false
    for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local neighbor=record.surface.get_tile(p.x+delta[1],p.y+delta[2])
        if neighbor.valid and ((flood and policy.freshwater[neighbor.name]) or (drought and policy.coast[neighbor.name])) then coastal=true end
    end
    if coastal then admit(root,record.surface,p,flood and "flood" or "drought",tick,{target=flood and "water" or "sand-1"}) end
end
local query_order={"R","T","R","E","R","S","R","T","R","G","R","H"}
local fallback_order={"R","T","E","S","G","H"}
local function service_class(root,budget,lane,tick)
    if lane=="T" or lane=="S" then
        -- A selected tile operation needs a writable quantum even when the
        -- preset has only one write. Recovery owns its separate weighted turns.
        budget.recovery_reserved=math.min(budget.recovery_reserved or 0,math.max(0,budget.writes-1))
    end
    -- A granted class also owns the inspection needed to reach its operation.
    -- Lower-priority scans cannot repeatedly spend that companion allowance.
    if budget.primary_lane==lane and (lane=="E" or lane=="T") and budget.events==0 and (root.pending[lane] or 0)>0 then budget.deferred_lane=lane;return end
    if budget.primary_lane==lane and (lane=="E" or lane=="T") and (root.pending[lane] or 0)>0
        and (budget.candidates==0 or lane=="T" and budget.writes==0) then budget.deferred_lane=lane;return end
    if budget.primary_lane==lane and lane=="R" and budget.histories==0 and (#root.history.items+#root.trees.items)>0 then budget.deferred_lane=lane;return end
    if lane=="R" then
        local before_writes=budget.writes
        local observation=work.ready(root,"R",tick)
        if observation and budget.histories>0 then
            observation.recovery_cursor=(observation.recovery_cursor or 0)%#observation.recovery_records+1
            local record=observation.recovery_records[observation.recovery_cursor]
            budget.histories=budget.histories-1
            if record.entity then
                local tree=lib.get_valid_entity(record.entity)
                local i=root.trees.index[record.id]
                if tree and i and root.trees.items[i]==record and observation.owner.config.tree_stress and tick>=(record.next_tick or 0) then
                    admit(root,tree.surface,tree.position,"tree",tick,{tree=tree})
                    record.next_tick=tick+observation.owner.config.recovery_seconds*60/observation.owner.config.intensity_multiplier
                end
            elseif root.history.index[record.id] and root.history.items[root.history.index[record.id]]==record
                and record.owner==observation.owner and record.owner.chunk_tokens[record.chunk_cell]==record.chunk_token
                and observation.owner.config.recovery and (record.cause~="mining" or observation.owner.config.mining_recovery)
                and tick>=(record.next_tick or 0) and tick>=(record.retry_tick or 0) then
                local result=propose(root,budget,record.surface,record.x,record.y,record.cause,tick,record.path[#record.path],true)
                if result~=nil then observation.attempts=observation.attempts+1;if result==false then work.backoff(record,tick) else record.retries=nil;record.retry_tick=nil end end
            end
            if budget.searches==0 then if budget.writes==before_writes then budget.recovery_reserved=0 end;return end
        end
        root.history_tree_turn=not root.history_tree_turn
        if root.history_tree_turn then recover_trees(root,budget,tick) end
        recover_tiles(root,budget,tick)
        if not root.history_tree_turn then recover_trees(root,budget,tick) end
        if budget.writes==before_writes then budget.recovery_reserved=0 end
    elseif lane=="T" then service_events(root,budget,tick)
    elseif lane=="E" then service_entity_events(root,budget,tick)
    elseif lane=="H" then
        if root.work.bootstrap_pending>0 then
            root.work.discovery_turn=not root.work.discovery_turn
            if root.work.discovery_turn and work.discovery_query(root,budget,tick,function(r,b,s,f) return mining_query(r,b,s,f,tick) end,classify_chunk) then return end
        end
        local record=work.ready(root,"H",tick) or visit_active(root,budget,next_record(root.active,"hazard_cursor"),tick)
        if record then hazards(root,budget,record,tick) end
    elseif lane=="G" then
        local record=work.ready(root,"G",tick) or visit_active(root,budget,next_record(root.active,"tree_cursor"),tick)
        if record then tree_service(root,budget,record,tick) end
    elseif lane=="S" then
        local record=work.ready(root,"S",tick) or visit_active(root,budget,next_record(root.active,"terrain_cursor"),tick)
        if record then
            local cfg=effective(root,record.surface)
            local schedule=record.schedule or record
            if cfg.degradation and (not schedule.draining or schedule.draining.soil) and record.dirty_since and tick-record.dirty_since>=cfg.dirty_seconds*60 and tick>=(schedule.next_soil or 0) then
                if budget.primary_lane==lane and (budget.candidates==0 or budget.writes==0) then budget.deferred_lane=lane;return end
                schedule.soil_position=schedule.soil_position or {x=record.x*32+math.random(0,31),y=record.y*32+math.random(0,31)}
                local p=schedule.soil_position
                local result=propose(root,budget,record.surface,p.x,p.y,"pollution",tick)
                if result~=nil then schedule.next_soil=tick+cfg.soil_seconds*60/climate_rate(root,record.surface,cfg,tick);schedule.soil_position=nil;if schedule.draining then schedule.draining.soil=nil end end
            end
        end
    end
end
---@param tick MapTick
---@return boolean?
function model.has_tick_work(tick)
    if refresh_after_load then return true end
    local root=peek()
    return root and root.config and tick>=root.next_tick and (work.has_maintenance(root)
        or (root.config.enabled and (root.enabled_surfaces or 0)>0))
end
---@param event EventData.on_tick
function model.updater(event)
    if refresh_after_load then refresh_after_load=false;model.initialize(event.tick,"load-adoption") end
    local root=peek();if not model.has_tick_work(event.tick) then return end
    local tick=event.tick;local cfg=root.config
    local observation_checks=root.work.observation_checks or 0
    root.next_tick=tick+cfg.interval;root.pass=root.pass+1
    local searches=0
    if tick>=(root.next_search or 0) then
        searches=cfg.searches;root.next_search=tick+(cfg.search_interval or cfg.interval)
        root.query_pass=(root.query_pass or 0)+1
    end
    local budget={candidates=cfg.candidates,writes=cfg.writes,searches=searches,samples=cfg.active_chunks,events=cfg.events,histories=cfg.histories,batches={},positions={},used_candidates=0,used_writes=0,used_searches=0,used_events=0}
    budget.recovery_reserved=#root.history.items>0 and cfg.recovery_reserved or 0
    calendar.service(root,tick,model.resolve_config)
    work.sample_observation(root,budget,tick,sample)
    -- A finite migration owns one inspection every fourth service, independent
    -- of query phase. Recovery cannot consume every conversion opportunity.
    if root.pass%4==1 then work.migrate(root,budget,tick,next_record,attach_patch,1) end
    local query_lane;local granted_lanes={}
    -- One query quantum belongs to one selected class; failed eligibility can
    -- lend it to at most six other classes. No service-time priority aliasing.
    for _=1,searches do
        if root.work.deferred_lane then query_lane=root.work.deferred_lane;root.work.deferred_lane=nil
        else root.work.query_cursor=root.work.query_cursor%#query_order+1;query_lane=query_order[root.work.query_cursor] end
        granted_lanes[query_lane]=true
        budget.primary_lane=query_lane
        budget.searches=1
        local before=budget.used_searches
        service_class(root,budget,query_lane,tick)
        if budget.deferred_entity or budget.deferred_lane then
            root.work.deferred_entity=budget.deferred_entity
            root.work.deferred_lane=budget.deferred_entity and "E" or budget.deferred_lane
            break
        end
        if budget.used_searches==before then
            for _,lane in ipairs(fallback_order) do
                if lane~=query_lane then service_class(root,budget,lane,tick) end
                if budget.deferred_entity or budget.deferred_lane then
                    root.work.deferred_entity=budget.deferred_entity;root.work.deferred_lane=budget.deferred_entity and "E" or budget.deferred_lane;break
                end
                if budget.used_searches>before then break end
            end
        end
        if root.work.deferred_lane then break end
    end
    budget.searches=0
    -- Non-query turns seed recovery observations, then spend remaining allowance
    -- on finite conversion. Neither migration nor optional drill polling can
    -- consume the selected query operation's resources first.
    if root.pass%2==0 then work.migrate(root,budget,tick,next_record,attach_patch) end
    recover_tiles(root,budget,tick);recover_trees(root,budget,tick)
    service_events(root,budget,tick)
    if root.pass%2~=0 then work.migrate(root,budget,tick,next_record,attach_patch) end
    work.service_drills(root,budget,tick,climate_rate,mining_scar)
    work.cleanup(root,budget,tick)
    discover(root,tick)
    local visited=next_record(root.active)
    if visited then
        local entry=visited.surface.valid and root.surfaces[visited.surface.index]
        if not entry or entry~=visited.owner or not entry.config.enabled then remove(root.active,visited.id)
        elseif (visited.schedule and visited.schedule.draining) or (#root.active.items>=cfg.active_cap and tick-(visited.resident_since or tick)>36000) then
            local schedule=visited.schedule;local c=entry.config
            if not schedule then remove(root.active,visited.id)
            else
                -- Finite draining preserves admitted long aging/decay deadlines.
                -- No replacement roll is scheduled once a family has drained.
                schedule.draining=schedule.draining or {soil=c.degradation,tree=c.tree_stress,regrowth=c.tree_regrowth,
                    aging=c.aging and c.planet=="nauvis",rot=c.rot,wildfire=c.wildfire~="off",cliff=c.cliffs,flood=c.flood and c.planet=="nauvis",drought=c.drought and c.planet=="nauvis"}
                local enabled={soil=c.degradation,tree=c.tree_stress,regrowth=c.tree_regrowth,aging=c.aging,rot=c.rot,wildfire=c.wildfire~="off" and c.wildfire_probability>0,cliff=c.cliffs and c.cliff_probability>0,flood=c.flood and c.flood_probability>0,drought=c.drought and c.drought_probability>0}
                for name,value in pairs(schedule.draining) do if not value or not enabled[name] then schedule.draining[name]=nil end end
                if next(schedule.draining)==nil then
                    work.invalidate_chunk(root,entry,visited.chunk_cell);remove(root.active,visited.id)
                end
            end
        end
    end
    if #root.fires.items>0 and tick>=(root.next_fire_cleanup or 0) then
        root.next_fire_cleanup=tick+32
        for i=math.min(16,#root.fires.items),1,-1 do
            local r=root.fires.items[i];local entity=lib.get_valid_entity(r.entity)
            if not entity or tick>=r.expires then
                if entity and entity.name=="ei-ecology-fire" then entity.destroy() end
                remove(root.fires,r.id)
            end
        end
    end
    commit(root,budget)
    root.last_service={tick=tick,candidates=budget.used_candidates,writes=budget.used_writes,searches=budget.used_searches,search_allowance=searches,query_lane=query_lane,events=budget.used_events,active_samples=cfg.active_chunks-budget.samples,histories=cfg.histories-budget.histories,observation_checks=(root.work.observation_checks or 0)-observation_checks}
    root.last_service.granted_lanes=granted_lanes
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
    local previous=entry.config
    entry.overrides=values;entry.config=resolved
    refresh_hazard_epoch(entry,previous)
    calendar.configure(root,tick)
    refresh_surface_counts(root)
    work.refresh_reports(root,tick)
    if previous.enabled and not entry.config.enabled then release_contained(root,surface) end
    if root.enabled_surfaces==0 then calendar.release(root) end
    return true,{"ei-terrain.updated"}
end
function model.reset_overrides(surface,tick)
    local root=peek();local entry=root and root.surfaces[surface.index]
    if not entry then return false,{"ei-terrain.unsupported"} end
    local previous=entry.config
    entry.overrides={};entry.config=config.resolve_surface(root.config,entry.planet)
    refresh_hazard_epoch(entry,previous)
    calendar.configure(root,tick)
    refresh_surface_counts(root)
    work.refresh_reports(root,tick)
    if previous.enabled and not entry.config.enabled then release_contained(root,surface) end
    if root.enabled_surfaces==0 then calendar.release(root) end
    return true,{"ei-terrain.updated"}
end
function model.set_season_phase(surface,phase,tick)
    local root=peek();if not root then return false,{"ei-terrain.unsupported"} end
    return calendar.set_phase(root,surface,phase,tick)
end
---@param surface LuaSurface
---@param tick MapTick
---@return integer Zero means no supported calendar; 1..4 match the field report.
function model.season_index(surface,tick)
    local root=peek();local phase=root and calendar.phase(root,surface,tick)
    return phase and math.floor(phase*4)+1 or 0
end
---@param surface LuaSurface?
---@param tick MapTick
---@return table
function model.snapshot(surface,tick)
    local root=peek();if not root then return {status="disabled"} end
    local result={status=root.config.enabled and "enabled" or "disabled",counters=root.counters,
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
        if not result.effective or not result.effective.enabled then result.status="disabled" end
        result.calendar=calendar.snapshot(root,surface,tick)
        result.phase=result.calendar.phase
    end
    return result
end
---@class SurfaceEcologyReport
---@field status string
---@field effective table?
---@field sample_age integer?
---@field pollution number?
---@field pollution_supported boolean?
---@field effects table<string, integer>
---@field effect_ticks table<string, MapTick>? Last committed activity; absent on old saves.
---@field woodland_supported boolean? Loaded approved native tree family exists.
---@field global table
---Cached scalar/finite state only: no world search or population walk.
---@param surface LuaSurface
---@param tick MapTick
---@return SurfaceEcologyReport|table
function model.public_snapshot(surface,tick)
    local root=peek();local entry=root and root.surfaces[surface.index]
    if not root or not entry or entry.surface~=surface then return {status="unsupported",effects={},global={}} end
    -- Older unobserved entries have no capability cache. Read the native type
    -- without inventing a sample or mutating state, including on disabled worlds.
    local pollution_supported=entry.pollution_supported
    if pollution_supported==nil then pollution_supported=surface.pollutant_type and surface.pollutant_type.name=="pollution" or false end
    return {status=entry.config.enabled and "enabled" or "disabled",effective=entry.config,
        sample_age=entry.last_sample_tick and tick-entry.last_sample_tick,pollution=entry.last_pollution,
        pollution_supported=pollution_supported==true,effects=entry.effects or {},effect_ticks=entry.effect_ticks or {},last_effect=entry.last_effect,
        woodland_supported=root.native_tree_names and #(root.native_tree_names[entry.planet] or {})>0 or false,
        counts=entry.counts or {},protection_skips=entry.protection_skips or 0,last_pending_age=entry.last_pending_age,
        dirty_age=entry.last_dirty_since and tick-entry.last_dirty_since,clean_age=entry.last_clean_since and tick-entry.last_clean_since,
        calendar=calendar.snapshot(root,surface,tick),drills=entry.drills and #entry.drills or 0,
        coverage=entry.coverage_status or (entry.bootstrap and (not entry.bootstrap.closed or entry.drill_discovery and entry.drill_discovery.bootstrap) and "discovering" or entry.bootstrap and "observed" or "unknown"),
        global={active=#root.active.items,pending=#root.pending.items,history=#root.history.items,tree_history=#root.trees.items,
            observations=root.work and root.work.observation_count or 0,drills=root.work and root.work.drill_count or 0,
            counters=root.counters,last_service=root.last_service,jobs=work.jobs(root)}}
end
function model.receipt_valid(receipt)
    local root=peek();local entry=root and receipt.surface.valid and root.surfaces[receipt.surface.index]
    return entry~=nil and entry==receipt.owner and receipt.chunk_token~=nil and entry.chunk_tokens[receipt.chunk_cell]==receipt.chunk_token
end
function model.retain_receipt(receipt)
    receipt.chunk_cell=math.floor(receipt.position.x/32)..":"..math.floor(receipt.position.y/32)
    attach_chunk(receipt)
end
function model.release_receipt(receipt)
    local token=receipt.chunk_token;if not token then return end
    token.references=token.references-1
    if token.references==0 and receipt.owner.chunk_tokens[receipt.chunk_cell]==token then receipt.owner.chunk_tokens[receipt.chunk_cell]=nil end
    receipt.chunk_token=nil
end
function model.maintenance_begin(name,total,tick)
    local root=peek();if root and root.work then return work.maintenance_begin(root,name,total,tick) end
end
function model.maintenance_update(handle,completed,done,tick)
    local root=peek();if root and root.work then work.maintenance_update(root,handle,completed,done,tick) end
end
return model
