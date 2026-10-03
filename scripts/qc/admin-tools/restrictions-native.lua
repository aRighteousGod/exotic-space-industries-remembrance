-- Connected-player 2.0.77 native restriction fixture; staged only.
do
    local restrictions=require("scripts/control/admin/restrictions")
    local checks={};local q
    local function check(name,ok,detail) checks[#checks+1]={name=name,ok=not not ok,detail=detail} end
    local function test(name,fn) local ok,result=pcall(fn);check(name,ok and result~=false,ok and nil or tostring(result)) end
    local integrated=type(ei_admin_tools.on_area_order)=="function"
    if not integrated then
    for _,name in ipairs{"on_marked_for_deconstruction","on_cancelled_deconstruction","on_marked_for_upgrade","on_cancelled_upgrade"} do
        local id=defines.events[name];local prior=script.get_event_handler(id)
        script.on_event(id,function(e) if not restrictions.on_area_order(e) and prior then prior(e) end end)
    end
    local prior_open=script.get_event_handler(defines.events.on_gui_opened)
    script.on_event(defines.events.on_gui_opened,function(e) if not restrictions.on_gui_opened(e) and prior_open then prior_open(e) end end)
    local prior_closed=script.get_event_handler(defines.events.on_gui_closed)
    script.on_event(defines.events.on_gui_closed,function(e) restrictions.on_gui_closed(e);if prior_closed then prior_closed(e) end end)
    local prior_destroyed=script.get_event_handler(defines.events.on_object_destroyed)
    script.on_event(defines.events.on_object_destroyed,function(e) restrictions.on_object_destroyed(e);if prior_destroyed then prior_destroyed(e) end end)
    end
    local previous=script.get_event_handler(defines.events.on_tick)
    local done=false
    local function create(name,x,y,last)
        local entity=q.surface.create_entity{name=name,position={x,y},force=q.player.force}
        entity.last_user=last
        return entity
    end
    local function finish()
        local p=q.player;local force=p.force
        test("census respects 64 records and one chunk per tick",function() return q.within_budget end)
        test("legacy native last_user attributed and unknown map instance excluded",function()
            local s=storage.ei.admin_tools.restriction_tracking
            return s.records[q.own.unit_number].owner_index==p.index and not s.records[q.unknown.unit_number]
        end)
        test("completed census enables natural and own area tools",function()
            p.selected=nil;restrictions.refresh(p,game.tick)
            return p.permission_group.allows_action(defines.input_action.deconstruct) and p.permission_group.allows_action(defines.input_action.upgrade)
        end)
        q.foreign=create("wooden-chest",4,0,nil)
        restrictions.on_built_entity{entity=q.foreign,name=defines.events.on_robot_built_entity,tick=game.tick}
        test("known robot-built entity without surviving owner is protected",function() return restrictions.is_protected(q.foreign,p) end)
        test("foreign deconstruction mark cancelled and prior last_user restored",function()
            q.foreign.order_deconstruction(force,p)
            return not q.foreign.to_be_deconstructed(force) and q.foreign.last_user==nil
        end)
        test("foreign deconstruction cancellation restores original order",function()
            q.foreign.order_deconstruction(force)
            q.foreign.cancel_deconstruction(force,p)
            return q.foreign.to_be_deconstructed(force) and q.foreign.last_user==nil
        end)
        q.foreign.cancel_deconstruction(force)
        test("foreign initial upgrade cancelled",function()
            q.foreign.order_upgrade{force=force,player=p,target="iron-chest"}
            return q.foreign.get_upgrade_target()==nil and q.foreign.last_user==nil
        end)
        test("foreign replacement upgrade preserves previous target",function()
            q.foreign.order_upgrade{force=force,target="iron-chest"}
            q.foreign.order_upgrade{force=force,player=p,target="steel-chest"}
            local target,quality=q.foreign.get_upgrade_target()
            return target and target.name=="iron-chest" and quality.name=="normal" and q.foreign.last_user==nil
        end)
        test("foreign upgrade cancellation restores original target",function()
            q.foreign.cancel_upgrade(force,p)
            local target=q.foreign.get_upgrade_target()
            return target and target.name=="iron-chest" and q.foreign.last_user==nil
        end)
        test("own deconstruction mark and cancellation remain native",function()
            q.own.order_deconstruction(force,p)
            local marked=q.own.to_be_deconstructed(force)
            q.own.cancel_deconstruction(force,p)
            return marked and not q.own.to_be_deconstructed(force) and q.own.last_user==p
        end)
        test("unknown script/map instance remains available",function()
            q.unknown.order_deconstruction(force,p)
            return q.unknown.to_be_deconstructed(force)
        end)
        test("natural tree remains available to area deconstruction",function()
            q.tree.order_deconstruction(force,p)
            return q.tree.to_be_deconstructed(force) and not restrictions.is_protected(q.tree,p)
        end)
        test("target-only permissions preserve natural shooting item use and wiring",function()
            p.selected=q.foreign;restrictions.refresh(p,game.tick)
            local foreign=not p.permission_group.allows_action(defines.input_action.use_item)
            p.selected=q.tree;restrictions.refresh(p,game.tick)
            return foreign and p.permission_group.allows_action(defines.input_action.use_item)
                and p.permission_group.allows_action(defines.input_action.change_shooting_state)
                and p.permission_group.allows_action(defines.input_action.wire_dragging)
        end)
        test("denied native entity GUI cannot recreate companion panel",function()
            local entity=create("ei-water-turret",0,8,nil)
            restrictions.on_built_entity{entity=entity,name=defines.events.on_robot_built_entity,tick=game.tick}
            p.teleport({0,4},q.surface);p.opened=entity
            return p.opened==nil and not p.gui.relative["ei-water-turret-console"]
        end)
        test("watcher notices another last user on stationary selection",function()
            p.selected=q.own;restrictions.refresh(p,game.tick)
            local allowed=p.permission_group.allows_action(defines.input_action.open_gui)
            q.own.last_user=nil
            restrictions.updater(game.tick+30)
            return allowed and not p.permission_group.allows_action(defines.input_action.open_gui)
        end)
        test("invalid direct entity handle retains native object name",function()
            local dead=create("wooden-chest",0,12,p);dead.destroy()
            local ok,name=pcall(function()return dead.object_name end)
            return ok and name=="LuaEntity" and not dead.valid
        end)
        test("removing final restriction leaves no census or watcher work",function()
            restrictions.set(p,false,game.tick)
            return not restrictions.has_tick_work(game.tick+60) and not storage.ei.admin_tools.restriction_tracking
        end)
        local pass=true;for _,c in ipairs(checks) do if not c.ok then pass=false end end
        helpers.write_file("restrictions-native.json",helpers.table_to_json{all_pass=pass,checks=checks,players=#game.players,connected=#game.connected_players,version=script.active_mods.base},false)
        log("RESTRICTIONS_NATIVE_COMPLETE "..tostring(pass))
    end
    script.on_event(defines.events.on_tick,function(e)
        local before=storage.ei and storage.ei.admin_tools and storage.ei.admin_tools.restriction_tracking
        local job=before and before.census
        local examined,chunks=job and job.examined or 0,job and job.chunks or 0
        if previous then previous(e) end
        if q and job then q.within_budget=q.within_budget and job.examined-examined<=64 and job.chunks-chunks<=1 end
        if done then return end
        if not q then
            local p=game.get_player(1)
            if p.controller_type==defines.controllers.editor then p.toggle_map_editor() end
            if not p.character then p.create_character() end
            local surface=game.create_surface("admin-restrictions-native",{width=64,height=64})
            surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities()) do entity.destroy() end
            local tiles={};for x=-32,31 do for y=-32,31 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
            q={player=p,surface=surface,start=e.tick,within_budget=true}
            p.teleport({0,-5},surface);p.opened=nil;p.selected=nil
            q.own=create("wooden-chest",0,0,p);q.unknown=create("wooden-chest",2,0,nil)
            q.tree=surface.create_entity{name="tree-01",position={8,0},force="neutral"}
            for x=1,16 do for y=1,10 do create("wooden-chest",x-24,y-24,p) end end
            restrictions.set(p,true,e.tick)
            -- Isolate the census lane from the unrelated pre-existing seed world.
            storage.ei.admin_tools.restriction_tracking.census.surfaces={surface}
            check("pending census temporarily gates area tools",not p.permission_group.allows_action(defines.input_action.deconstruct))
        end
        local state=storage.ei.admin_tools.restriction_tracking
        if (e.tick-q.start)%30==0 then helpers.write_file("restrictions-progress.json",helpers.table_to_json{elapsed=e.tick-q.start,state=restrictions.peek_summary(),surface_index=state and state.census and state.census.surface_index,batch=state and state.census and state.census.batch and #state.census.batch,cursor=state and state.census and state.census.cursor},false) end
        if state and state.census then
            local job=state.census;local examined,chunks=job.examined,job.chunks
            if not integrated then restrictions.updater(e.tick) end
            q.within_budget=q.within_budget and job.examined-examined<=64 and job.chunks-chunks<=1
        else done=true;finish() end
    end)
end
