local fixture=require("fixture-config")
local layouts=require("layouts")
local own=not script.active_mods["exotic-space-industries-remembrance"]
local passage=own and require("scripts/control/factory-passage") or nil
local build=layouts.build
local actors=require("actors")
local burst=require("burst")
local administration=require("administration")
local loaded=false
local loaded_checkpoint=false
local function api(name,...)
    if own then return passage[name](...) end
    return remote.call("ei_factory_passage",name,...)
end
local function check(condition,name,detail)
    storage.checks[#storage.checks+1]={name=name,passed=not not condition,detail=detail}
    assert(condition,"Factory passage QC: "..name.." "..serpent.line(detail or {}))
end
local function status() return api("status") end
local function refresh(entity)
    if own then passage.refresh_entity(entity,game.tick) else api("refresh_entity",entity) end
end
local function receipt(name,extra)
    extra=extra or {};extra.passed=true;extra.checks=storage.checks;extra.status=status()
    extra.mode=fixture.mode;extra.enabled=fixture.enabled;extra.engine=script.active_mods.base;extra.tick=game.tick
    extra.transition=storage.transition;extra.loaded=loaded
    extra.from_mode=storage.from_mode;extra.from_enabled=storage.from_enabled
    helpers.write_file("factory-passage/"..name..".json",helpers.table_to_json(extra),false)
end
local function expected_barrier(entry)
    if entry.kind=="open" then return false end
    if entry.kind=="production" or entry.kind=="power" or entry.kind=="turrets" then return not fixture.enabled or fixture.disabled_category==entry.kind end
    if entry.kind=="lane" then return false end
    if entry.kind=="mouth" then return fixture.enabled and fixture.mode=="esir" end
    return not fixture.enabled or fixture.mode~="squeak-through"
end
local function surface()
    local result=game.create_surface("factory-passage-qc",{width=4096,height=1024,seed=137013,
        autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    result.request_to_generate_chunks({30,100},7);result.force_generate_chunk_requests()
    for _,entity in pairs(result.find_entities()) do entity.destroy() end
    local tiles={}
    for x=-32,210 do for y=-100,255 do tiles[#tiles+1]={name="stone-path",position={x,y}} end end
    result.set_tiles(tiles);result.freeze_daytime=true;result.daytime=0.5
    return result
end
local function assert_prototypes()
    local catalog=prototypes.mod_data["ei-factory-passage"].data
    if script.active_mods["squeak-through-2"] then check(next(catalog.changed)==nil,"actual Squeak Through 2 overrides every ESIR collision mutation");return end
    local count=0
    for name,change in pairs(catalog.changed) do
        local before,after=change.before,change.after
        check(after[1][1]>=before[1][1] and after[1][2]>=before[1][2] and after[2][1]<=before[2][1] and after[2][2]<=before[2][2],"shrink-only "..name)
        local native=prototypes.entity[name]
        local function fixed(v)return math.floor(math.abs(v)*256)/256*(v<0 and -1 or 1) end
        local actual=native.collision_box
        check(actual.left_top.x==fixed(after[1][1]) and actual.left_top.y==fixed(after[1][2]) and actual.right_bottom.x==fixed(after[2][1]) and actual.right_bottom.y==fixed(after[2][2]),"final engine collision "..name)
        check(native.tile_width==change.width and native.tile_height==change.height,"final engine grid "..name)
        count=count+1
    end
    check(not catalog.changed["ei-passage-qc-opt-out"],"author opt-out")
    check(not catalog.changed["ei-passage-qc-off-grid"],"off-grid exclusion")
    if fixture.mode=="esir" then check(not catalog.changed["ei-passage-qc-unsupported"],"unsupported geometry retains original collision") end
    check(prototypes.entity["ei-passage-qc-grid-boundary"].tile_width==2,"native fixed-point grid width preserved")
    check(not catalog.changed["ei-passage-qc-upgrade"] and not catalog.changed["ei-passage-qc-upgrade-opt-out"],"upgrade family respects opt-out")
    check(not catalog.changed["stone-wall"] and not catalog.changed.gate and not catalog.changed.character and not catalog.changed.car,"walls gates character vehicles excluded")
    local enabled=fixture.enabled and not script.active_mods["squeak-through-2"]
    for category,name in pairs{production="assembling-machine-2",power="boiler",logistics="steel-chest",turrets="gun-turret"} do
        check((catalog.changed[name]~=nil)==(enabled and fixture.disabled_category~=category),"representative category switch "..category)
    end
    check((catalog.changed["ei-passage-qc-hidden-operating-body"]~=nil)==(enabled and fixture.disabled_category~="production"),"hidden operational body follows Production")
    check((catalog.changed["ei-passage-qc-eight-way"]~=nil)==(enabled and fixture.disabled_category~="turrets"),"eight-way solid turret follows Turrets")
    if prototypes.entity["ei-passage-qc-walkable-receiver"] then check(catalog.walkable["ei-passage-qc-walkable-receiver"],"walkable receiver outside category registry") end
    for _,category in ipairs{"production","power","logistics","turrets"} do
        for _,change in pairs(catalog.changed) do if change.category==category then check(enabled and fixture.disabled_category~=category,"category switch "..category);break end end
    end
    if not enabled then check(count==0,"master or companion override removes all mutations") end
end
script.on_init(function()
    if remote.interfaces.freeplay then remote.call("freeplay","set_skip_intro",true);remote.call("freeplay","set_disable_crashsite",true) end
    storage.checks={};storage.started=game.tick
    if own then passage.rebuild_runtime_state("init",game.tick) end
    local s=surface();storage.surface=s.index
    assert_prototypes()
    if fixture.performance>0 then
        s.request_to_generate_chunks({500,50},17);s.force_generate_chunk_requests()
        for _,entity in pairs(s.find_entities()) do entity.destroy() end
        for index=1,fixture.performance do build(s,"pipe",(index-1)%1000,math.floor((index-1)/1000)) end
    elseif not fixture.actors and not fixture.administration and not script.active_mods["squeak-through-2"] then storage.layout=layouts.create(s) end
    if own then passage.rebuild_runtime_state("fixture",game.tick)
    else for _,entity in pairs(s.find_entities()) do refresh(entity) end end
end)
script.on_load(function() loaded=true;loaded_checkpoint=storage.finished==true;administration.on_load() end)
script.on_configuration_changed(function()
    if own then passage.rebuild_runtime_state("configuration",game.tick) end
    storage.started=game.tick;storage.checks={};storage.transition=true;storage.finished=nil;storage.saved=nil
    storage.from_mode=storage.saved_mode;storage.from_enabled=storage.saved_enabled
    loaded_checkpoint=false;storage.reload_checked=nil
    storage.watchers_before_removal=nil
    assert_prototypes()
end)
script.on_event({defines.events.script_raised_built,defines.events.script_raised_revive,defines.events.on_built_entity,defines.events.on_robot_built_entity,defines.events.on_space_platform_built_entity},function(e)
    actors.event(e);if own then passage.on_built(e.entity,e) end
end)
script.on_event({defines.events.script_raised_destroy,defines.events.on_entity_died,defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,defines.events.on_space_platform_mined_entity},function(e)
    actors.event(e);if own then passage.on_removed(e.entity,e) end
end)
script.on_event({defines.events.on_player_rotated_entity,defines.events.on_player_flipped_entity,defines.events.on_entity_settings_pasted,defines.events.on_blueprint_settings_pasted},function(e)
    actors.event(e);if own then passage.on_changed(e) end
end)
if own then
    script.on_event(defines.events.on_object_destroyed,passage.on_object_destroyed)
    script.on_event(defines.events.script_raised_teleported,passage.on_teleported)
    script.on_event({defines.events.on_surface_deleted,defines.events.on_surface_cleared},passage.on_surface_removed)
    script.on_event(defines.events.on_surface_imported,passage.on_surface_imported)
end
script.on_event(defines.events.on_entity_cloned,function(e)actors.event(e);if own then passage.on_built(e.destination,e) end end)
local function collision_count(s)
    local names={}
    for name in pairs(prototypes.entity) do if name:find("ei-factory-passage-joint-",1,true)==1 then names[#names+1]=name end end
    return s.count_entities_filtered{name=names}
end
local function helper_ids(s)
    local ids={}
    for _,entity in pairs(s.find_entities_filtered{type="simple-entity-with-owner"}) do
        if entity.name:find("ei-factory-passage-joint-",1,true)==1 then ids[#ids+1]=entity.unit_number end
    end
    table.sort(ids);return ids
end
local function compare_checkpoint()
    local current=layouts.snapshot(game.surfaces[storage.surface])
    check(serpent.line(current)==serpent.line(storage.checkpoint),"placed identities fluids temperatures quality and connections survive reload/transition")
    if not storage.transition then
        check(serpent.line(helper_ids(game.surfaces[storage.surface]))==serpent.line(storage.checkpoint_helpers),"ordinary reload preserves helper identities")
        check(status().counters.topology==storage.checkpoint_topology,"ordinary reload performs no topology rebuild")
    end
end
script.on_event(defines.events.on_tick,function(event)
    if own and passage.has_work(event.tick) then passage.updater(passage.update_budget(),event) end
    local age=event.tick-storage.started
    local s=game.surfaces[storage.surface]
    if fixture.administration then administration.tick(event,check,receipt,loaded);return end
    if script.active_mods["squeak-through-2"] then
        if age==10 then check(status().mode=="vanilla" and status().helpers==0 and status().dirty==0,"installed companion owns collision and ESIR remains idle");receipt("companion") end
        return
    end
    if fixture.actors then actors.tick(event,check,receipt,status,refresh);return end
    if fixture.performance>0 then
        if fixture.burst and storage.saved then burst.tick(event,s,check,receipt,status,collision_count);return end
        if storage.saved then
            if not storage.idle_start then storage.idle_start={tick=event.tick,topology=status().counters.topology,created=status().counters.created,destroyed=status().counters.destroyed} end
            if event.tick-storage.idle_start.tick==5990 then
                local now=status();local before=storage.idle_start
                check(now.counters.topology==before.topology and now.counters.created==before.created and now.counters.destroyed==before.destroyed,"zero idle topology and helper churn")
                receipt("performance-idle",{count=fixture.performance})
            end
            return
        end
        local now=status()
        if age>10 and now.dirty==0 and now.pending==0 then
            storage.rebuild_ready_tick=storage.rebuild_ready_tick or age
            -- Match simulation age across baseline/candidate checkpoints while
            -- reporting observed readiness (the probe starts at tick 11).
            if age<512 then return end
            check(now.counters.unsupported==0,"supported performance geometry")
            check(now.helpers==collision_count(s),"no orphan or duplicate helpers")
            storage.saved=true;storage.idle_start=nil
            receipt("performance-ready",{count=fixture.performance,ticks=storage.rebuild_ready_tick,checkpoint_tick=event.tick,surface_seed=s.map_gen_settings.seed})
            if game.is_multiplayer() then game.server_save("factory-passage-performance") else game.auto_save("factory-passage-performance") end
        end
        return
    end
    if storage.finished and not storage.transition then
        if loaded_checkpoint and not storage.reload_checked then compare_checkpoint();storage.reload_checked=true;receipt("reload") end
        return
    end
    local layout=storage.layout
    if fixture.visual and age>=15 and age<=45 and age%2==1 then
        storage.frames=storage.frames or {}
        local scenes={{name="pipe-joint",position={0.5,0},zoom=3},{name="separate-parallel",position={40.5,-6},zoom=3},{name="occupied-joint",position={60.5,30},zoom=3}}
        for index,name in ipairs{"ei-steam-crusher","ei-burner-heater","ei-steam-assembler"} do
            if prototypes.entity[name] then scenes[#scenes+1]={name=name,position={2,190+index*16+0.5},zoom=2} end
        end
        for _,scene in ipairs(scenes) do
            local path="factory-passage/frames/"..scene.name.."-"..age..".png"
            game.take_screenshot{surface=s,position=scene.position,resolution={640,480},zoom=scene.zoom,path=path,daytime=0,show_gui=false,force_render=true}
            storage.frames[#storage.frames+1]={path=path,tick=event.tick,scene=scene.name}
        end
    end
    if age==1 and storage.transition then compare_checkpoint() end
    if age==10 then
        if not storage.transition then
            build(s,"pipe",60,30)
            storage.overlap_actor=build(s,"character",60.5,30)
            build(s,"pipe",61,30)
            storage.overlap_actor.walking_state={walking=false,direction=defines.direction.north}
        end
    elseif age==15 then
        if not storage.transition then
            if fixture.enabled and fixture.mode=="esir" then check(status().pending>0,"occupied helper is deferred") end
            storage.overlap_actor.walking_state={walking=true,direction=defines.direction.north}
        end
        for _,entry in ipairs(layout.walkers) do
            if entry.entity and entry.entity.valid then entry.entity.destroy() end
            entry.entity=build(s,"character",entry.start.x,entry.start.y)
            entry.entity.character_running_speed_modifier=entry.speed
            entry.entity.walking_state={walking=true,direction=entry.direction}
        end
        check(#layout.heat[17].heat_neighbours==2,"actual heat connections")
        check(layout.heat[18].temperature>15,"native heat transfer",layout.heat[18].temperature)
        check(layout.reactors[1].neighbour_bonus==layout.reactors[1].prototype.neighbour_bonus,"native reactor neighbour bonus",layout.reactors[1].neighbour_bonus)
        check(not s.can_place_entity{name="character",position=layout.walkers[1].entities[1].position,force="player"},"pipe centre stays solid")
        storage.receiver_geometry={}
        for _,coupling in ipairs(layout.couplings) do
            local found=false
            for _,connection in ipairs(coupling.pipe.get_fluid_box_pipe_connections(1)) do if connection.target==coupling.entity then found=true end end
            check(found,"actual connected coupling "..coupling.entity.name.." "..coupling.entity.direction)
            storage.receiver_geometry[#storage.receiver_geometry+1]={name=coupling.entity.name,direction=coupling.entity.direction,box=coupling.entity.bounding_box,pipe=coupling.pipe.position}
        end
        local underground=false
        for _,connection in ipairs(layout.underground[1].get_fluid_box_pipe_connections(1)) do
            if connection.connection_type=="underground" and connection.target==layout.underground[2] then underground=true end
        end
        check(underground,"actual underground span connection")
        if layout.pump_pipe.valid then check(layout.pump_pipe.get_fluid_box_pipe_connections(1)[1]~=nil,"pump native connection records") end
    elseif age==25 then
        for _,entry in ipairs(layout.walkers) do if entry.speed>0 then entry.entity.walking_state={walking=false,direction=entry.direction} end end
    elseif age==45 then
        if not storage.transition and fixture.enabled and fixture.mode~="vanilla" then check(storage.overlap_actor.position.y < 29,"occupied joint allows departure",storage.overlap_actor.position) end
        for _,entry in ipairs(layout.walkers) do
            local coordinate=entry.entity.position[entry.axis or "y"]
            local crossed=coordinate>entry.line+0.4
            local blocked=coordinate<entry.line-0.05
            check(expected_barrier(entry) and blocked or not expected_barrier(entry) and crossed,entry.name.." walking",{position=entry.entity.position,start=entry.start,barrier=expected_barrier(entry)})
            entry.entity.walking_state={walking=false,direction=entry.direction}
        end
        local total=0
        for _,entity in ipairs(layout.fluid) do local fluid=entity.get_fluid(1);if fluid then total=total+fluid.amount;check(math.abs(fluid.temperature-80)<0.001,"fluid temperature preserved") end end
        check(math.abs(total-200)<0.01,"fluid inventory preserved",total)
        if not storage.transition then
            layout.pump_pipe.destroy{raise_destroy=true}
            local clone=layout.tank.clone{position={75,12},surface=s,force="player"}
            check(clone and clone.valid,"native entity clone")
            local ghost=s.create_entity{name="entity-ghost",inner_name="pipe",position={70,12},force="player"}
            local _,revived=ghost.revive{raise_revive=true};check(revived and revived.valid,"native blueprint ghost revival")
            storage.recipe_before=status().joints
            layout.chemical.set_recipe(nil)
            layout.crafter.set_recipe("ei-passage-qc-fluid-crafting")
            refresh(layout.chemical);refresh(layout.crafter)
            local temporary=game.create_surface("passage-disposable",{width=32,height=32})
            build(temporary,"pipe",0,0);build(temporary,"pipe",1,0)
            storage.temporary=temporary.index
        end
    elseif age==60 and not storage.transition then
        if fixture.mode=="esir" and fixture.enabled then
            check(collision_count(game.surfaces[storage.temporary])==1,"surface owns active helper before cleanup")
            local function joints_at(x,y)
                local count=0
                for _,entity in pairs(s.find_entities_filtered{area={{x-0.05,y-0.05},{x+0.05,y+0.05}}}) do
                    if entity.name:find("ei-factory-passage-joint-",1,true)==1 then count=count+1 end
                end
                return count
            end
            check(joints_at(94.5,-1)==0,"notified recipe removal retires joint")
            check(joints_at(85.5,-1)==1,"notified initially recipe-less machine gains joint")
            storage.watchers_before_removal=status().watchers
        end
        layout.reserve_pipe.destroy()
        game.delete_surface(storage.temporary)
    elseif age==70 then
        local now=status()
        check(now.dirty==0 and now.pending==0,"bounded reconciliation drained",now)
        check(now.counters.max_processed<=(fixture.budget or 256),"selected budget total work cap",now.counters.max_processed)
        check(now.counters.unsupported==0,"all narrowed joint geometry supported",now.counters.unsupported)
        check(now.helpers==collision_count(s),"no orphan or duplicate helper entities",now)
        if storage.watchers_before_removal then check(now.watchers==0,"closed manual machines have no observers") end
        if fixture.mode~="esir" or not fixture.enabled then check(now.helpers==0 and now.joints==0,"inactive modes have no joint ownership") end
        storage.before_idle={topology=now.counters.topology,created=now.counters.created,destroyed=now.counters.destroyed}
    elseif age==100 then
        local now=status();local before=storage.before_idle
        check(now.counters.topology==before.topology and now.counters.created==before.created and now.counters.destroyed==before.destroyed,"no idle topology queries or churn")
        for _,entry in ipairs(layout.walkers) do entry.entity.destroy();entry.entity=nil end
        if storage.overlap_actor and storage.overlap_actor.valid then storage.overlap_actor.destroy() end
        for _,entity in ipairs(layout.heat) do entity.temperature=100 end
        storage.checkpoint=layouts.snapshot(s)
        storage.checkpoint_helpers=helper_ids(s);storage.checkpoint_topology=status().counters.topology
        storage.saved_mode=fixture.mode;storage.saved_enabled=fixture.enabled
        storage.finished=true
        receipt(storage.transition and "transition" or "functional",{prototypes=prototypes.mod_data["ei-factory-passage"].data,receivers=storage.receiver_geometry})
        if fixture.visual then game.set_wait_for_screenshots_to_finish();receipt("visual",{frames=storage.frames}) end
        storage.transition=false
        if game.is_multiplayer() then game.server_save("factory-passage-performance") end
    end
end)
