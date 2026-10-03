--==============================================================================
-- ESIR FILE MAP
-- owns: admin world policies, bounded creation and terrain jobs
-- loaded_by: scripts/control/admin-tools
-- cadence: requested work only, through control.lua
-- forwarded_events: configure, configure_cleanup, execute, get_catalog, get_policy, has_tick_work, on_biter_base_built, on_chunk_charted, on_chunk_generated, on_surface_created, on_surface_deleted, peek_summary, updater
-- storage_roots: storage.ei.admin_tools.world
-- gui_ids: none
-- remote_interfaces: none
-- rebuild_on: configuration changes; native settings remain authoritative
--==============================================================================
-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
local lib = require("lib/lib")
local scheduler = require("lib/runtime-scheduler")
local model = {}
local context
local catalogs = {}
local TYPES = {"unit", "spider-unit", "unit-spawner", "turret", "ammo-turret",
    "electric-turret", "fluid-turret", "artillery-turret", "combat-robot"}
local CATALOG_TYPES = {}
for _, name in ipairs(TYPES) do CATALOG_TYPES[name] = true end
CATALOG_TYPES["segmented-unit"] = true
local FIRE = {oil="ei-oil-fire-flame", gas="ei-gas-fire-flame",
    exotic="ei-exotic-fire-flame", lava="ei-lava-fire-flame"}
local CAP = {jobs=64, create=25, destroy=25, visit=64, chart=4,
    generation=16, generation_interval=30, chart_pending=32, timeout=3600}
---@class ESIRAdminWorldJob
---@field id integer
---@field kind string
---@field actor_index integer
---@field surface LuaSurface
---@field force LuaForce
---@field completed integer
---@field failed integer
---@field cursor integer
---@field wait table|nil
---@field iterator LuaChunkIterator|nil
---@class ESIRAdminWorldContext
---@field enabled fun():boolean
---@field state fun():table
---@field notify fun(player_index:integer,message:LocalisedString)
---@field changed fun(page:string,target:any)
---@field resolve_surface fun(target:any,create:boolean):LuaSurface|nil
---@field rupture_effects table
---@field fluid_safety table
---@field fulgora table
---@param ctx ESIRAdminWorldContext
function model.configure(ctx)
    context = ctx
    catalogs = {}
end

local function peek_state()
    return storage and storage.ei and storage.ei.admin_tools and storage.ei.admin_tools.world
end

local function state()
    local root = context.state()
    root.world = root.world or {jobs={}, policies={}, next_id=0, active=0,
        queue=scheduler.ensure_queue(nil), generation={}, generation_count=0, next_generation_tick=0}
    root.world.charting = root.world.charting or {}
    root.world.charting_count = root.world.charting_count or 0
    return root.world
end

local function authorized(actor)
    return context and context.enabled() and actor and actor.valid and actor.admin
end

local function number(value, low, high, integer)
    value = tonumber(value)
    if not lib.is_valid_number(value) or value < low or value > high
        or (integer and value ~= math.floor(value)) then return nil end
    return value
end

local function position(value)
    if type(value) ~= "table" then return nil end
    local x = number(value.x or value[1], -999999, 999999)
    local y = number(value.y or value[2], -999999, 999999)
    if not x or not y then return nil end
    return {x=x,y=y}
end

local function policy_key(surface)
    return surface.planet and ("planet:"..surface.planet.name) or ("surface:"..surface.name)
end

local function resolve_surface(args, actor)
    if args.surface_index then return game.surfaces[args.surface_index] end
    if args.planet then return context.resolve_surface(args.planet, false) end
    return actor.surface
end

local function force_for(args, actor, default_enemy)
    local force
    if args.force_index~=nil then force=game.forces[args.force_index]
    else force=default_enemy and game.forces.enemy or actor.force end
    if not force or not force.valid then return nil end
    return force
end

local function chunk_key(surface, p)
    return surface.index..":"..p.x..":"..p.y
end

local function clear_force_error(force, actor)
    if force.name=="neutral" or force==actor.force or #force.players>0 then
        return "Select an enemy force without players."
    end
    if force~=game.forces.enemy and (actor.force.get_friend(force) or actor.force.get_cease_fire(force)
        or force.get_friend(actor.force) or force.get_cease_fire(actor.force)) then
        return "The selected additional force is not hostile."
    end
end

local function generated(surface, p)
    return surface.is_chunk_generated({math.floor(p.x/32),math.floor(p.y/32)})
end

local function changed(surface)
    if context.changed then context.changed("planet", surface and surface.index) end
end

local function enemy_candidate(proto)
    if not proto or proto.hidden or not CATALOG_TYPES[proto.type]
        or proto.name == "dummy-spider-unit" then return false end
    return proto.has_flag("placeable-enemy")
        or (proto.subgroup and proto.subgroup.name == "enemies")
end

---@param kind string enemies|advanced_enemies|fires|resources|entities|items|fluids
---@return table[] entries Name is a prototype name; entity entries additionally identify the placing item.
function model.get_catalog(kind)
    if catalogs[kind] then return catalogs[kind] end
    local entries, included = {}, {}
    local function add(proto, extra)
        if included[proto.name] then return end
        included[proto.name] = true
        local entry = {name=proto.name,caption=proto.localised_name,type=proto.type}
        if extra then entry.entity = extra end
        entries[#entries+1] = entry
    end
    if kind == "advanced_enemies" then
        for _, proto in pairs(prototypes.entity) do
            if CATALOG_TYPES[proto.type] and proto.name ~= "dummy-spider-unit" then add(proto) end
        end
    elseif kind == "enemies" then
        for _, proto in pairs(prototypes.entity) do
            if enemy_candidate(proto) then add(proto) end
        end
        for _, proto in pairs(prototypes.get_entity_filtered{{filter="type",type="unit-spawner"}}) do
            if enemy_candidate(proto) then
                for _, spawn in pairs(proto.result_units or {}) do
                    local unit = prototypes.entity[spawn.unit]
                    if unit and not unit.hidden and unit.name ~= "dummy-spider-unit"
                        and (unit.type=="unit" or unit.type=="spider-unit") then add(unit) end
                end
            end
        end
    elseif kind == "fires" or kind == "resources" then
        local entity_type = kind == "fires" and "fire" or "resource"
        for _, proto in pairs(prototypes.get_entity_filtered{{filter="type",type=entity_type}}) do
            -- Environmental fires are normally hidden from crafting/Factoriopedia.
            if kind == "fires" or not proto.hidden then add(proto) end
        end
    elseif kind == "items" or kind == "entities" then
        for _, proto in pairs(prototypes.item) do
            if not proto.hidden and (kind == "items" or proto.place_result) then
                add(proto, proto.place_result and proto.place_result.name)
            end
        end
    elseif kind == "fluids" then
        for _, proto in pairs(prototypes.fluid) do if not proto.hidden then add(proto) end end
    end
    table.sort(entries,function(a,b) return a.name<b.name end)
    catalogs[kind] = entries
    return entries
end

local function catalog_contains(kind, name)
    for _, entry in ipairs(model.get_catalog(kind)) do
        if entry.name == name then return true end
    end
    return false
end

function model.peek_rupture_radius(energy_mj)
    local effects=context and context.rupture_effects
    return effects and effects.peek_location_radius and effects.peek_location_radius(energy_mj) or nil
end

---@param surface LuaSurface
---@return table
function model.get_policy(surface)
    if not (surface and surface.valid) then return {} end
    local root = peek_state()
    local policy = root and root.policies[policy_key(surface)] or {}
    return {spawning=not surface.no_enemies_mode,peaceful=surface.peaceful_mode,peaceful_override=policy.peaceful,
        expansion=policy.expansion~=false,daytime=surface.daytime,
        freeze=surface.freeze_daytime,evolution=game.forces.enemy.get_evolution_factor(surface)}
end

local function remove_generation_wait(root, job)
    local wait = job.wait
    if not wait or wait.kind ~= "generation" then return end
    local pending = root.generation[wait.key]
    if pending then
        pending.jobs[job.id] = nil
        -- A submitted native request is still real work even after every watcher cancels.
        -- Retain its admission slot until completion/timeout; never cancel unrelated terrain.
    end
end

local function finish(root, job, status)
    if not root.jobs[job.id] then return end
    remove_generation_wait(root, job)
    if job.group and job.group.valid then
        -- Submitted members survive cancellation. Finish their already-selected
        -- native order while cancelling only future scripted creation work.
        job.group.start_moving()
    end
    root.jobs[job.id] = nil
    root.active = math.max(0,root.active-1)
    job.iterator, job.batch, job.segmented = nil,nil,nil
    root.last_result = {id=job.id,kind=job.kind,status=status,
        completed=job.completed,failed=job.failed,actor_index=job.actor_index}
    log("[ESIR admin job] "..serpent.line({id=job.id,kind=job.kind,actor_index=job.actor_index,
        surface_index=job.surface.valid and job.surface.index or nil,
        force_index=job.force.valid and job.force.index or nil,status=status,
        completed=job.completed,failed=job.failed,started_tick=job.started_tick}))
    if context.notify then
        context.notify(job.actor_index, "Admin job "..job.id.." "..status..": "
            ..job.completed.." completed, "..job.failed.." skipped.")
    end
    if context.changed then context.changed("jobs",job.actor_index) end
end

local function enqueue(actor, kind, surface, force, fields, tick)
    local root = state()
    if root.active >= CAP.jobs then return false,"The admin job limit (64) is reached." end
    for _, job in pairs(root.jobs) do
        if job.actor_index==actor.index and job.kind==kind then
            return false,"You already have a "..kind.." job. Cancel or finish it first."
        end
    end
    root.next_id = root.next_id+1
    local job = fields or {}
    job.id,job.kind,job.actor_index = root.next_id,kind,actor.index
    job.surface,job.force,job.started_tick = surface,force,tick
    job.completed,job.failed,job.cursor = 0,0,1
    root.jobs[job.id],root.active = job,root.active+1
    scheduler.queue_push(root.queue,job.id)
    if context.changed then context.changed("jobs",actor.index) end
    return true,"Queued admin job "..job.id..".",job.id
end

local function make_region(args, origin, unit, max_radius)
    if args.area then
        local a,b = position(args.area.left_top),position(args.area.right_bottom)
        if not a or not b or b.x<=a.x or b.y<=a.y then return nil end
        local region = {min_x=math.floor(a.x/unit), min_y=math.floor(a.y/unit),
            max_x=math.ceil(b.x/unit)-1,max_y=math.ceil(b.y/unit)-1}
        if (region.max_x-region.min_x+1)*(region.max_y-region.min_y+1)>4096 then return nil end
        return region
    end
    local radius = number(args.radius or 0,0,max_radius,true)
    if not radius or not origin then return nil end
    local x,y=math.floor(origin.x/unit),math.floor(origin.y/unit)
    return {min_x=x-radius,max_x=x+radius,min_y=y-radius,max_y=y+radius}
end

local function next_region(job)
    local r=job.region
    local width=r.max_x-r.min_x+1
    local offset=job.cursor-1
    local y=r.min_y+math.floor(offset/width)
    if y>r.max_y then return nil end
    job.cursor=job.cursor+1
    return {x=r.min_x+offset%width,y=y}
end

local function within_map(surface, chunk)
    local settings=surface.map_gen_settings
    local width,height=settings.width or 0,settings.height or 0
    return (width==0 or (chunk.x*32<width/2 and chunk.x*32+32>-width/2))
        and (height==0 or (chunk.y*32<height/2 and chunk.y*32+32>-height/2))
end

local function next_chunk(job)
    if job.mode=="all_generated" or job.kind=="clear_enemies" then
        if not job.iterator then job.iterator=job.surface.get_chunks() end
        if not job.iterator.valid then return nil,"Surface chunk iterator is invalid." end
        return job.iterator()
    end
    return next_region(job)
end

local function chart_key(surface_index, force_index, p)
    return surface_index..":"..force_index..":"..p.x..":"..p.y
end

local function chart_chunk(root, job, p, tick, budget)
    if job.force.is_chunk_charted(job.surface,p) then
        job.completed=job.completed+1
        job.wait=nil
        return
    end
    local key=chart_key(job.surface.index,job.force.index,p)
    local requested=job.force.is_chunk_requested_for_charting(job.surface,p)
    if not requested then
        if budget.chart<=0 or (not root.charting[key] and root.charting_count>=CAP.chart_pending) then
            job.wait={kind="chart_ready",position=p};return
        end
        budget.chart=budget.chart-1
        if not root.charting[key] then
            root.charting[key]={surface=job.surface,force=job.force,position=p,tick=tick}
            root.charting_count=root.charting_count+1
        end
        -- Native requests survive cancellation; retain their slots until completion/timeout.
        job.force.chart(job.surface,{{p.x*32,p.y*32},{p.x*32+31.99,p.y*32+31.99}})
    end
    job.wait={kind="chart",position=p,tick=tick}
end

local function request_chunk(root,job,p,tick,budget)
    local key=chunk_key(job.surface,p)
    local pending=root.generation[key]
    if not pending then
        if root.generation_count>=CAP.generation or tick<root.next_generation_tick then
            job.wait={kind="generation_ready",position=p};return
        end
        pending={surface=job.surface,position=p,tick=tick,jobs={}}
        root.generation[key]=pending
        root.generation_count=root.generation_count+1
        root.next_generation_tick=tick+CAP.generation_interval
        pending.jobs[job.id]=true
        job.wait={kind="generation",position=p,key=key,tick=tick}
        job.surface.request_to_generate_chunks({p.x*32+16,p.y*32+16},0)
    else
        pending.jobs[job.id]=true
        job.wait={kind="generation",position=p,key=key,tick=pending.tick}
    end
end

local function service_chunks(root,job,tick,budget)
    if budget.visit<=0 then return end
    budget.visit=budget.visit-1
    local wait=job.wait
    if wait then
        local p=wait.position
        if wait.kind=="chart" then
            if wait.done or job.force.is_chunk_charted(job.surface,p) then
                job.completed=job.completed+1;job.wait=nil
            elseif tick-wait.tick>=CAP.timeout then
                job.failed=job.failed+1;job.wait=nil
            end
            return
        end
        if wait.kind=="chart_ready" then
            if job.surface.is_chunk_generated(p) then chart_chunk(root,job,p,tick,budget)
            else job.failed=job.failed+1;job.wait=nil end
            return
        end
        if job.surface.is_chunk_generated(p) then
            remove_generation_wait(root,job)
            job.wait=nil
            if job.mode=="both" then chart_chunk(root,job,p,tick,budget)
            else job.completed=job.completed+1 end
        elseif wait.kind=="generation_ready" then request_chunk(root,job,p,tick,budget)
        elseif tick-wait.tick>=CAP.timeout then
            remove_generation_wait(root,job);job.wait=nil;job.failed=job.failed+1
        end
        return
    end
    local p,err=next_chunk(job)
    if err then finish(root,job,err);return end
    if not p then finish(root,job,"finished");return end
    if not within_map(job.surface,p) then job.failed=job.failed+1;return end
    if job.surface.is_chunk_generated(p) then
        if job.mode=="generate" then job.completed=job.completed+1
        else chart_chunk(root,job,p,tick,budget) end
    elseif job.mode=="reveal" or job.mode=="all_generated" then
        job.failed=job.failed+1
    else request_chunk(root,job,p,tick,budget) end
end

local function placement_position(job,index)
    local origin=job.position
    if job.kind=="start_fire" then
        local width=job.pattern
        local offset=index-1
        return {x=origin.x+(offset%width)-math.floor(width/2),
            y=origin.y+math.floor(offset/width)-math.floor(width/2)}
    end
    if index==1 then return {x=origin.x,y=origin.y} end
    local angle=index*2.399963229728653
    local radius=math.sqrt(index-1)*job.spacing
    return {x=origin.x+math.cos(angle)*radius,y=origin.y+math.sin(angle)*radius}
end

local function create_one(job, tick, budget)
    local surface=job.surface
    local name,p
    if job.kind=="add_pollution" then
        p=next_region(job)
        if not p then return "finished" end
        budget.create=budget.create-1
        if surface.is_chunk_generated(p) then
            surface.pollute({x=p.x*32+16,y=p.y*32+16},job.amount_per_chunk)
            job.completed=job.completed+1
        else job.failed=job.failed+1 end
        return
    elseif job.kind=="place_resources" then
        p=next_region(job)
        if not p then return "finished" end
        if (p.x-job.position.x)^2+(p.y-job.position.y)^2>job.radius^2 and job.radius>0 then return end
        p={x=p.x+0.5,y=p.y+0.5};name=job.name
    elseif job.kind=="spawn_enemies" then
        local row=job.mix[job.mix_index]
        if not row then return "finished" end
        name=row.name
        local proto=prototypes.entity[name]
        if not proto then job.failed=job.failed+1;return "Prototype removed" end
        if proto.type=="segmented-unit" and budget.demolisher<=0 then return "blocked" end
        p=placement_position(job,job.cursor)
        job.cursor=job.cursor+1
        job.mix_remaining=job.mix_remaining-1
        if job.mix_remaining<=0 then
            job.mix_index=job.mix_index+1
            local next_row=job.mix[job.mix_index]
            job.mix_remaining=next_row and next_row.count or 0
        end
    else
        if job.cursor>job.quantity then return "finished" end
        p=placement_position(job,job.cursor);job.cursor=job.cursor+1;name=job.name
    end
    budget.create=budget.create-1
    if not generated(surface,p) then job.failed=job.failed+1;return end
    local proto=prototypes.entity[name]
    if not proto then job.failed=job.failed+1;return end
    if job.kind=="place_resources" then
        local existing=surface.find_entities_filtered{position=p,type="resource",limit=1}[1]
        if existing then
            job.failed=job.failed+1
            return
        end
    end
    local create_position=p
    if job.kind=="place_entities" or job.kind=="spawn_enemies" then
        if not surface.can_place_entity{name=name,position=p,force=job.force,
            direction=job.direction,build_check_type=defines.build_check_type.manual} then
            -- Rolling stock must fit the selected rail position. This includes the
            -- steam locomotive's native locomotive placement wrapper.
            if proto.type=="locomotive" or proto.type=="cargo-wagon"
                or proto.type=="fluid-wagon" or proto.type=="artillery-wagon" then
                job.failed=job.failed+1;return
            end
            create_position=surface.find_non_colliding_position(name,p,8,0.5)
            if not create_position or not generated(surface,create_position)
                or not surface.can_place_entity{name=name,position=create_position,force=job.force,
                    direction=job.direction,build_check_type=defines.build_check_type.manual} then
                job.failed=job.failed+1;return
            end
        end
    elseif job.kind=="place_resources" and not surface.can_place_entity{name=name,position=p,force=job.force} then
        job.failed=job.failed+1;return
    end
    local entity
    if proto.type=="segmented-unit" then
        budget.demolisher=budget.demolisher-1
        entity=surface.create_segmented_unit{name=name,position=create_position,force=job.force,quality=job.quality}
    else
        entity=surface.create_entity{name=name,position=create_position,force=job.force,
            direction=job.direction,quality=job.quality,amount=job.amount,
            player=job.kind=="place_entities" and job.actor_index or nil,raise_built=true,
            enable_tree_removal=false,enable_cliff_removal=false}
    end
    if not entity then job.failed=job.failed+1;return end
    if not entity.valid then
        -- Raised-build owners can replace a successfully created temporary item wrapper.
        if job.kind=="place_entities" then job.completed=job.completed+1
        else job.failed=job.failed+1 end
        return
    end
    job.completed=job.completed+1
    if job.kind=="spawn_enemies" and (proto.type=="unit" or proto.type=="spider-unit") then
        local commandable=entity.commandable
        if commandable and commandable.valid then
            if not (job.group and job.group.valid) then
                job.group=surface.create_unit_group{position=create_position,force=job.force}
                if job.attack_position then
                    job.group.set_command{type=defines.command.attack_area,destination=job.attack_position,
                        radius=16,distraction=defines.distraction.by_enemy}
                else job.group.set_autonomous() end
            end
            job.group.add_member(commandable)
        end
    end
end

local function clear_one(root,job,budget,actor)
    local eligibility_error=clear_force_error(job.force,actor)
    if eligibility_error then finish(root,job,"cancelled: "..eligibility_error);return end
    if budget.destroy<=0 or budget.visit<=0 then return end
    budget.visit=budget.visit-1
    if job.segmented then
        local unit=job.segmented[job.segment_index]
        if not unit then finish(root,job,"finished");return end
        job.segment_index=job.segment_index+1
        if unit.valid and unit.force==job.force then
            budget.destroy=budget.destroy-1
            unit.destroy{raise_destroy=true};job.completed=job.completed+1
        end
        return
    end
    if not job.clear_chunk then
        local chunk,err=next_chunk(job)
        if err then finish(root,job,err);return end
        if not chunk then
            -- Native API provides only a whole-unit snapshot; subsequent removals stay bounded.
            job.segmented=job.surface.get_segmented_units();job.segment_index=1;return
        end
        if not job.surface.is_chunk_generated(chunk) then return end
        job.clear_chunk=chunk
    end
    local p=job.clear_chunk
    local targets=job.surface.find_entities_filtered{
        area={{p.x*32,p.y*32},{p.x*32+32,p.y*32+32}},force=job.force,type=TYPES,
        limit=math.min(budget.destroy,25)}
    if #targets==0 then job.clear_chunk=nil;return end
    for _,entity in ipairs(targets) do
        if not root.jobs[job.id] then return end
        if not authorized(actor) or not job.force.valid or not job.surface.valid then
            finish(root,job,"cancelled: administrator or world target changed");return
        end
        eligibility_error=clear_force_error(job.force,actor)
        if eligibility_error then finish(root,job,"cancelled: "..eligibility_error);return end
        -- An earlier raised destroy callback may transfer later batch members.
        if lib.entity_check(entity) and entity.force==job.force and entity.surface==job.surface then
            budget.destroy=budget.destroy-1
            if entity.destroy{raise_destroy=true} then job.completed=job.completed+1
            else job.failed=job.failed+1;finish(root,job,"stopped: an enemy could not be removed");return end
        end
    end
end

local function fill_fluid(actor,args)
    local entity=args.entity
    local amount=number(args.amount,0.000001,1000000)
    local proto=type(args.fluid)=="string" and prototypes.fluid[args.fluid]
    if not lib.entity_check(entity) or not amount or not proto then return false,"Select a valid fluid target, fluid, and amount." end
    if entity.fluids_count==0 then return false,"The selected entity has no fluid storage." end
    local temperature=proto.default_temperature
    local inserted=0
    local box_count=#entity.fluidbox
    local index=args.fluidbox_index and number(args.fluidbox_index,1,entity.fluids_count,true) or nil
    if args.fluidbox_index and not index then return false,"Fluid storage index is invalid." end
    if index and index>box_count then return false,"Use automatic insertion for this special fluid storage." end
    if not index and box_count>0 then
        for candidate=1,box_count do
            local current=entity.get_fluid(candidate)
            local locked=entity.fluidbox.get_locked_fluid(candidate)
            local filter=entity.fluidbox.get_filter(candidate)
            local candidate_temperature=current and current.temperature or proto.default_temperature
            if not current and filter then candidate_temperature=math.max(filter.minimum_temperature,math.min(filter.maximum_temperature,candidate_temperature)) end
            local compatible=(not current or current.name==proto.name)
                and (not locked or locked==proto.name)
                and (not filter or (filter.name==proto.name
                    and candidate_temperature>=filter.minimum_temperature and candidate_temperature<=filter.maximum_temperature))
            if compatible and entity.fluidbox.get_capacity(candidate)>(current and current.amount or 0) then
                index=candidate;temperature=candidate_temperature;break
            end
        end
        if not index then return false,"No compatible ordinary fluid storage has room." end
    end
    if index then
        local current=entity.get_fluid(index)
        if current and current.name~=proto.name then return false,"The storage contains another fluid." end
        local locked=entity.fluidbox.get_locked_fluid(index)
        local filter=entity.fluidbox.get_filter(index)
        temperature=current and current.temperature or proto.default_temperature
        if not current and filter then temperature=math.max(filter.minimum_temperature,math.min(filter.maximum_temperature,temperature)) end
        if (locked and locked~=proto.name) or (filter and (filter.name~=proto.name
            or temperature<filter.minimum_temperature or temperature>filter.maximum_temperature)) then
            return false,"The requested fluid is incompatible with the storage filter."
        end
        local before=current and current.amount or 0
        local addition=math.min(amount,math.max(0,entity.fluidbox.get_capacity(index)-before))
        if addition<=0 then return false,"The selected storage is full." end
        local result=entity.set_fluid(index,{name=proto.name,amount=before+addition,temperature=temperature})
        inserted=math.max(0,(result and result.amount or 0)-before)
    else
        for slot=1,entity.fluids_count do
            local current=entity.get_fluid(slot)
            if current and current.name==proto.name then temperature=current.temperature;break end
        end
        inserted=entity.insert_fluid{name=proto.name,amount=amount,temperature=temperature}
    end
    if inserted>0 and context.fluid_safety and context.fluid_safety.touch_entity then
        context.fluid_safety.touch_entity(entity)
    end
    return inserted>0,"Inserted "..inserted.." / "..amount.." fluid."
end

---@param actor LuaPlayer
---@param action string
---@param args table
---@param tick MapTick
---@return boolean,string,integer|nil
local function execute(actor,action,args,tick)
    if not authorized(actor) then return false,"Administrator access is required." end
    args=args or {}
    if action=="cancel_job" then
        local job=state().jobs[tonumber(args.job_id)]
        if not job then return false,"That job is no longer active." end
        finish(state(),job,"cancelled; submitted native work may still finish")
        return true,"Job cancelled."
    end
    if action=="global_expansion" then
        if type(args.enabled)~="boolean" then return false,"A boolean value is required." end
        game.map_settings.enemy_expansion.enabled=args.enabled;changed()
        return true,"Global enemy expansion updated."
    end
    if action=="give_items" then
        local target=game.get_player(args.player_index or actor.index)
        local item=args.item
        local count=number(args.quantity or args.amount,1,10000,true)
        if not (target and target.valid and item and prototypes.item[item.name]
            and not prototypes.item[item.name].hidden and count
            and prototypes.quality[item.quality or "normal"]) then return false,"Invalid item, player, quality, or count." end
        local inventory
        local character=target.character
        if character and character.valid then
            inventory=character.get_inventory(defines.inventory.character_main)
        elseif target.controller_type==defines.controllers.god then
            inventory=target.get_inventory(defines.inventory.god_main)
        end
        if not (inventory and inventory.valid) then
            return false,"The target has no accessible physical character or god inventory."
        end
        local inserted=inventory.insert{name=item.name,quality=item.quality or "normal",count=count}
        return inserted>0,"Inserted "..inserted.." / "..count.." items; overflow was not spilled."
    end
    if action=="fill_fluid" then return fill_fluid(actor,args) end
    local surface=resolve_surface(args,actor)
    if not (surface and surface.valid) then return false,"The selected planet surface has not been created." end
    local policy=state().policies[policy_key(surface)] or {}
    if action=="planet_peaceful" or action=="planet_spawning" or action=="planet_expansion" or action=="planet_freeze" then
        if type(args.enabled)~="boolean" then return false,"A boolean value is required." end
        if action=="planet_peaceful" then surface.peaceful_mode=args.enabled;policy.peaceful=args.enabled
        elseif action=="planet_spawning" then surface.no_enemies_mode=not args.enabled;policy.spawning=args.enabled
        elseif action=="planet_expansion" then policy.expansion=args.enabled
        else surface.freeze_daytime=args.enabled end
        state().policies[policy_key(surface)]=policy
        if action=="planet_freeze" and context.fulgora and context.fulgora.on_admin_daytime_changed then
            context.fulgora.on_admin_daytime_changed(surface,tick)
        end
        changed(surface);return true,"Planet setting updated."
    elseif action=="planet_evolution" then
        local value=number(args.evolution or args.value,0,1)
        if not value then return false,"Evolution must be between 0 and 1." end
        game.forces.enemy.set_evolution_factor(value,surface)
        changed(surface);return true,"Current evolution set; natural evolution and Nauvis grace continue."
    elseif action=="planet_daytime" then
        local value=number(args.daytime or args.value,0,1)
        if not value or value==1 then return false,"Daytime must be in [0, 1)." end
        surface.daytime=value
        if context.fulgora and context.fulgora.on_admin_daytime_changed then
            context.fulgora.on_admin_daytime_changed(surface,tick)
        end
        changed(surface);return true,"Planet daytime updated."
    elseif action=="clear_pollution" then
        surface.clear_pollution();changed(surface);return true,"Planet pollution/spores cleared."
    end
    local force=force_for(args,actor,action=="spawn_enemies" or action=="clear_enemies")
    if not force then return false,"The selected force no longer exists." end
    if action=="clear_enemies" then
        local eligibility_error=clear_force_error(force,actor)
        if eligibility_error then return false,eligibility_error end
        return enqueue(actor,action,surface,force,{},tick)
    end
    local origin=position(args.position)
    if not origin and surface==actor.surface then origin=position(actor.position) end
    if not origin and not ((action=="chunks" and (args.mode=="all_generated" or args.area))
        or (action=="add_pollution" and args.area)) then return false,"A valid target position is required." end
    if action=="chunks" then
        local mode=args.mode
        if mode~="reveal" and mode~="generate" and mode~="both" and mode~="all_generated" then return false,"Invalid chunk operation." end
        local region=mode~="all_generated" and make_region(args,origin,32,31) or nil
        if mode~="all_generated" and not region then return false,"Choose a rectangle up to 4096 chunks or radius 0-31 chunks." end
        return enqueue(actor,action,surface,force,{mode=mode,region=region},tick)
    elseif action=="add_pollution" then
        local amount=number(args.amount,0.000001,1000000)
        if not amount then return false,"Choose an amount above 0 through 1000000." end
        if not surface.pollutant_type then return false,"This surface has no pollutant." end
        if args.area then
            local region=make_region(args,origin,32,31)
            if not region then return false,"Choose a rectangle up to 4096 chunks." end
            local count=(region.max_x-region.min_x+1)*(region.max_y-region.min_y+1)
            return enqueue(actor,action,surface,force,{region=region,amount_per_chunk=amount/count},tick)
        end
        if not origin or not generated(surface,origin) then return false,"Choose generated terrain." end
        surface.pollute(origin,amount);return true,"Added "..amount.." pollution/spores."
    elseif action=="rupture" then
        local energy=tonumber(args.energy)
        local family=args.rupture_family
        if energy~=20 and energy~=100 and energy~=500 then return false,"Choose a 20, 100, or 500 MJ rupture." end
        if not ({oil=true,gas=true,exotic=true,lava=true,thermal=true,chemical=true,cryo=true,data=true})[family] then return false,"Invalid rupture family." end
        if not generated(surface,origin) then return false,"The target chunk must already exist." end
        local effects=context.rupture_effects
        if not effects or not effects.queue_effect_at then return false,"The rupture service is unavailable." end
        if effects.admin_has_work and effects.admin_has_work() then return false,"An admin rupture is already active." end
        local accepted,id,reason=effects.queue_effect_at(surface,origin,{effect_family=family=="lava" and "thermal" or family,
            effect_variant=family=="lava" and "lava" or nil,energy_mj=energy,total_energy_mj=energy,
            source_force_name="neutral",severity=energy==20 and "small" or (energy==100 and "medium" or "large")},tick)
        return accepted==true,accepted and ("Queued rupture "..tostring(id)..".") or reason or "Rupture was not accepted."
    elseif action=="place_entities" then
        local item=args.item
        local proto=item and prototypes.item[item.name]
        local quantity=number(args.quantity,1,100,true)
        local direction=number(args.direction or 0,0,15,true)
        if not proto or proto.hidden or not proto.place_result or not quantity or not direction
            or not prototypes.quality[item.quality or "normal"] then return false,"Invalid placeable item, quantity, quality, or direction." end
        local box=proto.place_result.collision_box
        local spacing=math.max(2,box.right_bottom.x-box.left_top.x+1,box.right_bottom.y-box.left_top.y+1)
        return enqueue(actor,action,surface,force,{name=proto.place_result.name,quantity=quantity,
            quality=item.quality or "normal",position=origin,direction=direction,spacing=spacing},tick)
    elseif action=="place_resources" then
        local proto=prototypes.entity[args.resource or ""]
        local amount=number(args.amount,1,1000000000,true)
        local radius=tonumber(args.radius or 0)
        if not proto or proto.type~="resource" or proto.hidden or not amount
            or not ({[0]=true,[2]=true,[5]=true,[10]=true})[radius] then return false,"Invalid resource, amount, or patch radius." end
        local center={x=math.floor(origin.x),y=math.floor(origin.y)}
        return enqueue(actor,action,surface,game.forces.neutral,{name=proto.name,amount=amount,
            radius=radius,position=center,region=make_region({radius=radius},center,1,10)},tick)
    elseif action=="spawn_enemies" then
        if type(args.enemy_mix)~="table" or #args.enemy_mix==0 or #args.enemy_mix>64 then return false,"Choose 1-64 enemy mix rows." end
        local mix,ordinary,demolishers={},0,0
        for _, row in ipairs(args.enemy_mix) do
            local count=number(row.count,1,1000,true)
            local proto=prototypes.entity[row.name or ""]
            local catalog=args.advanced==true and "advanced_enemies" or "enemies"
            if not count or not proto or not catalog_contains(catalog,row.name) then return false,"Invalid enemy mix row." end
            if proto.type=="segmented-unit" then demolishers=demolishers+count else ordinary=ordinary+count end
            mix[#mix+1]={name=row.name,count=count}
        end
        if ordinary>1000 or demolishers>16 then return false,"Wave limit: 1000 ordinary enemies and 16 demolishers." end
        local attack=args.attack_position and position(args.attack_position) or nil
        if args.attack_position and not attack then return false,"Invalid attack destination." end
        return enqueue(actor,action,surface,force,{mix=mix,mix_index=1,mix_remaining=mix[1].count,total_requested=ordinary+demolishers,
            position=origin,attack_position=attack,spacing=2,quality="normal"},tick)
    elseif action=="start_fire" then
        local name=args.advanced_fire or FIRE[args.fire_family or "oil"]
        local proto=name and prototypes.entity[name]
        local pattern=tonumber(args.pattern or 1)
        if not proto or proto.type~="fire" or not ({[1]=true,[3]=true,[5]=true})[pattern] then return false,"Invalid fire or grid size." end
        return enqueue(actor,action,surface,game.forces.neutral,{name=name,position=origin,
            quantity=pattern*pattern,pattern=pattern},tick)
    end
    return false,"Unknown world action: "..tostring(action)
end

---@param actor LuaPlayer
---@param action string
---@param args table
---@param tick MapTick
---@return boolean,string,integer|nil
function model.execute(actor,action,args,tick)
    local ok,accepted,message,id=pcall(execute,actor,action,args,lib.get_event_tick(tick))
    if not ok then return false,"Admin action failed: "..tostring(accepted) end
    return accepted,message,id
end

---@param tick MapTick
function model.updater(tick)
    if not context or not context.enabled() then return end
    local root=state()
    for key,pending in pairs(root.generation) do
        if not pending.surface.valid or pending.surface.is_chunk_generated(pending.position)
            or tick-pending.tick>=CAP.timeout then
            root.generation[key]=nil;root.generation_count=math.max(0,root.generation_count-1)
        end
    end
    for key,pending in pairs(root.charting) do
        if not pending.surface.valid or not pending.force.valid
            or pending.force.is_chunk_charted(pending.surface,pending.position)
            or tick-pending.tick>=CAP.timeout then
            root.charting[key]=nil;root.charting_count=math.max(0,root.charting_count-1)
        end
    end
    local budget={create=CAP.create,destroy=CAP.destroy,visit=CAP.visit,chart=CAP.chart,demolisher=1}
    -- Each visit admits at most one creation operation, and all jobs share these ceilings.
    local turns=math.min(scheduler.queue_length(root.queue),CAP.jobs)
    for _=1,turns do
        local id=scheduler.queue_pop(root.queue)
        local job=id and root.jobs[id]
        if job then
            local actor=game.get_player(job.actor_index)
            if not authorized(actor) then finish(root,job,"cancelled: administrator access lost")
            elseif not job.surface.valid or not job.force.valid then finish(root,job,"cancelled: world target removed")
            else
                local ok,err=pcall(function()
                    if job.kind=="chunks" then service_chunks(root,job,tick,budget)
                    elseif job.kind=="clear_enemies" then clear_one(root,job,budget,actor)
                    else
                        local allowance=math.min(4,budget.create)
                        for _=1,allowance do
                            -- Raised-build owners run synchronously and may cancel
                            -- this job, revoke its actor or remove its exact targets.
                            if root.jobs[id]~=job then break end
                            actor=game.get_player(job.actor_index)
                            if not authorized(actor) then finish(root,job,"cancelled: administrator access lost");break end
                            if not job.surface.valid or not job.force.valid then finish(root,job,"cancelled: world target removed");break end
                            local result=create_one(job,tick,budget)
                            if result=="blocked" then break end
                            if result then finish(root,job,result);break end
                        end
                    end
                end)
                if not ok then job.failed=job.failed+1;finish(root,job,"stopped: "..tostring(err)) end
                if root.jobs[id] then scheduler.queue_push(root.queue,id) end
            end
        end
    end
end

---@return boolean
function model.has_tick_work()
    if not context or not context.enabled() then return false end
    local root=peek_state()
    return root~=nil and (root.active>0 or root.generation_count>0 or (root.charting_count or 0)>0)
end

---@param event EventData.on_chunk_generated
function model.on_chunk_generated(event)
    if not context or not context.enabled() then return end
    local root=peek_state()
    if not root then return end
    local key=chunk_key(event.surface,event.position)
    if root.generation[key] then
        root.generation[key]=nil;root.generation_count=math.max(0,root.generation_count-1)
    end
end

---@param event EventData.on_chunk_charted
function model.on_chunk_charted(event)
    if not context or not context.enabled() then return end
    local root=peek_state()
    if not root then return end
    local key=chart_key(event.surface_index,event.force.index,event.position)
    if root.charting and root.charting[key] then
        root.charting[key]=nil;root.charting_count=math.max(0,root.charting_count-1)
    end
    if root.active==0 then return end
    -- At most 64 admitted admin jobs; never inspect world populations here.
    for _,job in pairs(root.jobs) do
        local wait=job.wait
        if wait and wait.kind=="chart" and job.surface.valid and job.force.valid
            and job.surface.index==event.surface_index
            and job.force==event.force and wait.position.x==event.position.x
            and wait.position.y==event.position.y then wait.done=true end
    end
end

---@param surface LuaSurface
function model.apply_policy(surface)
    if not context or not context.enabled() or not (surface and surface.valid) then return end
    local root=peek_state()
    local policy=root and root.policies[policy_key(surface)]
    if not policy then return end
    if policy.spawning~=nil then surface.no_enemies_mode=not policy.spawning end
    if policy.peaceful~=nil then surface.peaceful_mode=policy.peaceful end
end

---@param event EventData.on_surface_created
function model.on_surface_created(event)
    local surface=game.surfaces[event.surface_index]
    if surface then model.apply_policy(surface) end
end

---@param event EventData.on_surface_deleted|EventData.on_surface_cleared
function model.on_surface_deleted(event)
    if not context then return end
    local root=peek_state()
    if not root then return end
    local ids={}
    for id,job in pairs(root.jobs) do
        if not job.surface.valid or job.surface.index==event.surface_index then ids[#ids+1]=id end
    end
    for _,id in ipairs(ids) do finish(root,root.jobs[id],"cancelled: surface removed or cleared") end
    for key,pending in pairs(root.charting or {}) do
        if not pending.surface.valid or pending.surface.index==event.surface_index then
            root.charting[key]=nil;root.charting_count=math.max(0,root.charting_count-1)
        end
    end
    for key,pending in pairs(root.generation) do
        if not pending.surface.valid or pending.surface.index==event.surface_index then
            root.generation[key]=nil;root.generation_count=math.max(0,root.generation_count-1)
        end
    end
end

---@param event EventData.on_biter_base_built
function model.on_biter_base_built(event)
    if not context or not context.enabled() or not lib.entity_check(event.entity) then return end
    local root=peek_state()
    local policy=root and root.policies[policy_key(event.entity.surface)]
    if policy and policy.expansion==false and event.entity.force==game.forces.enemy then
        event.entity.destroy{raise_destroy=true}
    end
end

---@param tick MapTick
---@param enabled boolean
function model.configure_cleanup(tick,enabled)
    catalogs={}
    local root=peek_state()
    if not root then return end
    if not enabled then
        local ids={}
        for id in pairs(root.jobs) do ids[#ids+1]=id end
        for _,id in ipairs(ids) do finish(root,root.jobs[id],"cancelled: admin tools disabled") end
        scheduler.clear_queue(root.queue)
        root.generation={};root.generation_count=0
        root.charting={};root.charting_count=0
        return
    end
    root.charting=root.charting or {};root.charting_count=root.charting_count or 0
    -- Rebuild only the bounded admission queue; job cursors and native wait ownership survive.
    root.queue=scheduler.ensure_queue(nil);root.active=0
    local ids={}
    for id in pairs(root.jobs) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do scheduler.queue_push(root.queue,id);root.active=root.active+1 end
    for _,surface in pairs(game.surfaces) do model.apply_policy(surface) end
end

---@return table
function model.peek_summary()
    local root=peek_state()
    if not root then return {active=0,jobs={},generation_pending=0,chart_pending=0} end
    local jobs={}
    for _,job in pairs(root.jobs) do
        local total=job.total_requested or job.quantity
        local visited=job.completed+job.failed
        if job.region then
            total=(job.region.max_x-job.region.min_x+1)*(job.region.max_y-job.region.min_y+1)
            visited=math.max(0,job.cursor-1)
        end
        jobs[#jobs+1]={id=job.id,kind=job.kind,actor_index=job.actor_index,
            surface_index=job.surface.valid and job.surface.index or nil,
            force_index=job.force.valid and job.force.index or nil,started_tick=job.started_tick,
            completed=job.completed,failed=job.failed,visited=visited,total=total,
            waiting=job.wait and job.wait.kind}
    end
    table.sort(jobs,function(a,b) return a.id<b.id end)
    return {active=root.active,jobs=jobs,generation_pending=root.generation_count,chart_pending=root.charting_count or 0,last_result=root.last_result}
end
return model
