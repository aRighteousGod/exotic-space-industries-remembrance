-- blueprint: .codex/esir/blueprints/admin-tools.md#contract
-- Administration owns authorization and reversible state; gameplay owners retain
-- their queues and repairs. control.lua is the only event/tick dispatcher.
local lib=require("lib/lib")
local scheduler=require("lib/runtime-scheduler")
local common=require("scripts/control/admin/common")
local config=require("lib/admin-tools-config")
local gui=require("scripts/control/admin/gui")
local players=require("scripts/control/admin/players")
local world=require("scripts/control/admin/world")
local registry=require("scripts/control/admin/registry")
local targeting=require("scripts/control/admin/targeting")
local restrictions=require("scripts/control/admin/restrictions")
local model={}
local owners
local PLAYER_ACTIONS={travel=true,set_spawn=true,cheat=true,invulnerable=true,god=true,kick=true,ban=true,unban=true,promote=true,demote=true,jail=true,release=true}

function model.planets()
    local result={}
    for name,planet in pairs(game.planets) do
        if not name:find("^ei%-admin%-") then result[#result+1]={name=name,localised_name=planet.prototype.localised_name} end
    end
    table.sort(result,function(a,b)return a.name<b.name end)
    return result
end

function model.resolve_surface(target,create)
    local surface=game.get_surface(target)
    if surface and surface.valid then return surface end
    local planet=type(target)=="string" and game.planets[target]
    if not planet then return nil end
    surface=planet.surface
    if not surface and create then
        if target=="gaia" then surface=owners.gaia.create_gaia() or planet.surface
        else surface=planet.create_surface() end
        if surface then world.apply_policy(surface) end
    end
    return surface
end

local function changed(page,target)
    local state=common.peek();if not state then return end
    if page=="players" then state.restriction_dirty=state.restriction_dirty or {};state.restriction_dirty[target]=true end
    state.dirty=state.dirty or {}
    for index,session in pairs(state.sessions) do
        if session.root and session.root.valid and session.root.visible
            and (session.page==page or (page=="planet" and session.page=="planets") or session.page=="diagnostics") then state.dirty[index]=true end
    end
end

function model.diagnostics(id,tick,player_index)
    local result
    if id then result=registry.peek(id,tick) or {status="Not sampled"}
    else
        result={snapshot_tick=tick,owners={}}
        for _,entry in ipairs(registry.list()) do result.owners[#result.owners+1]=registry.peek(entry.id,tick) end
    end
    local inspection=player_index and registry.get_inspection(player_index)
    if inspection and (not id or inspection.id==id) then result.inspection=inspection end
    return result
end

function model.configure(modules)
    owners=modules
    modules.gaia.set_surface_ready_handler(model.on_planet_surface_ready)
    local ctx={enabled=common.enabled,state=common.state,valid_entity=lib.get_valid_entity,scheduler=scheduler,
        notify=common.notify,changed=changed,resolve_surface=model.resolve_surface,modules=modules,
        rupture_effects=modules["rupture-effects"],fluid_safety=modules["fluid-safety"],fulgora=modules["fulgora-day-length"]}
    players.configure(ctx);world.configure(ctx);registry.configure(ctx)
    targeting.configure{resolve_surface=model.resolve_surface,hidden=function(player) gui.close(player.index) end,
        finished=function(player,tick) if common.authorize(player) then gui.open(player,nil,tick) end end}
    gui.configure{planets=model.planets,world=world,registry=registry,execute=model.execute,diagnostics=model.diagnostics,
        begin_target=function(player,kind,session,tick) local ok,message=targeting.begin(player,kind,session,tick);if not ok then common.notify(player.index,message) end end,
        cancel_target=targeting.cancel,
        inspect=function(player,id,tick) local ok,message=registry.start_inspection(player,id,tick);common.notify(player.index,message);gui.result(player.index,message,tick) end,
        cancel_inspection=function(player,tick) local ok,message=registry.cancel_inspection(player);gui.result(player.index,message,tick) end,
        export=function(player,id,tick) log("[ESIR admin diagnostics] "..serpent.block(model.diagnostics(id,tick,player.index),{comment=false}));common.notify(player.index,{"ei-admin.exported"}) end}
end

local function finish_research(force)
    local tech=force.current_research
    if not tech then return false,"No research is selected." end
    if not tech.enabled then return false,"This technology is disabled." end
    if tech.prototype.max_level==4294967295 then
        local root=common.state();root.infinite_completed=root.infinite_completed or {}
        root.infinite_completed[force.index..":"..tech.name]=true
    end
    tech.researched=true
    return true,"Finished one research level: "..tech.name.."."
end

---@param actor LuaPlayer|nil Server console may request repairs only.
---@param action string
---@param args table
---@param tick MapTick
---@return boolean,LocalisedString
function model.execute(actor,action,args,tick)
    args=args or {}
    local allowed,message=common.authorize(actor,action=="repair")
    if not allowed then common.notify(actor and actor.index,message);return false,message end
    local ok,job
    if action=="repair" then ok,message=registry.repair(actor,args.module_id,tick)
    elseif PLAYER_ACTIONS[action] then
        targeting.cancel(actor,tick,true)
        ok,message=players.execute(actor,action,args,tick)
    elseif action=="restrict" then ok,message=restrictions.set(game.get_player(args.player_index),args.enabled,tick)
    elseif action=="restrict_new" then
        settings.global[config.restricted_setting]={value=args.enabled==true}
        ok=true;message=args.enabled and "New-player interaction restriction: On." or "New-player interaction restriction: Off."
    elseif action=="speed" then
        local speed=common.number(args.speed,0.01,64)
        if speed then local state=common.state();if state.speed_before==nil then state.speed_before=game.speed end;game.speed=speed;ok=true;message="Game speed: "..speed.."x."
        else ok=false;message="Speed must be between 0.01 and 64." end
    elseif action=="instant_research" or action=="finish_research" or action=="research_all" then
        local force=game.forces[args.force_index or actor.force.index]
        if not force then ok=false;message="The force no longer exists."
        elseif action=="instant_research" then
            common.state().instant_research[force.index]=args.enabled and {actor_index=actor.index} or nil
            if args.enabled and force.current_research then model.on_research_started{research=force.current_research,tick=tick} end
            ok=true;message=args.enabled and "Instant research: On. Infinite research stops after one level." or "Instant research: Off."
        elseif action=="finish_research" then ok,message=finish_research(force)
        else force.research_all_technologies(false);ok=true;message="Enabled technologies researched." end
    elseif action=="camera-player" or action=="camera-entity" then
        local target_index=action=="camera-player" and common.number(args.player_index,1,65536)
        local target=target_index and target_index%1==0 and game.get_player(target_index)
        local entity=action=="camera-entity" and lib.get_valid_entity(args.entity)
        if action=="camera-player" and not (target and target.valid) then
            ok=false;message="The selected player no longer exists."
        elseif action=="camera-entity" and not entity then
            ok=false;message="Select an existing entity first."
        else
            local frame,error=lib.camera_open(actor,{owner="admin",id=action=="camera-player" and "player" or "entity",
                player_index=target and target.index or nil,entity=entity or nil,
                zoom=args.zoom,follow_view=args.follow_view},tick)
            ok=frame~=nil;message=error or "Camera opened."
        end
    elseif action=="camera-close" then lib.camera_close_owner("admin",actor.index);ok=true;message="Administration cameras closed."
    elseif action=="gaia-reforge" then owners.gaia.reforge_gaia_surface{player_index=actor.index,tick=tick};ok=true;message="Gaia reforge requested."
    elseif action=="victory-reset" then
        local force=game.forces[args.force_index or actor.force.index]
        if not (force and force.valid) then ok=false;message="The selected force no longer exists."
        else
            storage.ei.victory=storage.ei.victory or {}
            storage.ei.victory[force.name]=false
            ok=true;message="Victory notification reset for "..force.name.."."
        end
    else
        if action=="planet_evolution" then args.evolution=(tonumber(args.evolution) or -100)/100 end
        if action=="place_entities" then args.item=args.place_item end
        if action=="cancel_job" and not args.job_id then local session=common.state().sessions[actor.index];args.job_id=session and session.drafts.active_job end
        if action=="clear_enemies" and not args.explicit_hostile_force then args.force_index=game.forces.enemy.index end
        if action=="spawn_enemies" then args.force_index=game.forces.enemy.index end
        ok,message,job=world.execute(actor,action,args,tick)
        if job and actor then local session=common.state().sessions[actor.index];if session then session.last_job=job end end
    end
    common.audit(actor,action,args,ok)
    common.notify(actor and actor.index,message or "Action completed.")
    if actor then gui.result(actor.index,message or "",tick) end
    return ok,message
end

function model.on_research_started(event)
    local root=common.peek();local research=event.research
    if not (common.enabled() and root and research and research.valid and root.instant_research[research.force.index]) then return end
    local infinite=research.prototype.max_level==4294967295
    root.infinite_completed=root.infinite_completed or {}
    local key=research.force.index..":"..research.name
    if infinite and root.infinite_completed[key] then
        if event.last_research and event.last_research.name==research.name then return end
        root.infinite_completed[key]=nil
    end
    local owner=root.instant_research[research.force.index]
    root.research_due[research.force.index]={technology=research.name,tick=event.tick+1,infinite=infinite,key=key,
        force=research.force,actor_index=type(owner)=="table" and owner.actor_index or nil}
end

function model.on_configuration_changed(tick)
    local enabled=common.enabled();local root=common.peek()
    if enabled then root=common.state() end
    if not root then return end
    if not enabled then
        targeting.cleanup(tick)
        for index in pairs(root.sessions) do gui.close(index,true) end
        lib.camera_close_owner("admin")
        root.instant_research={};root.research_due={};root.inspection=nil;root.dirty={};root.policy_due=nil
        root.auto_refresh_buckets=nil;root.auto_refresh_due_tick=nil
        if root.speed_before~=nil then game.speed=root.speed_before;root.speed_before=nil end
    end
    restrictions.on_configuration_changed(enabled,tick)
    players.on_configuration_changed(tick,enabled);world.configure_cleanup(tick,enabled)
    if enabled then
        for index,session in pairs(root.sessions) do
            if session.page=="players" and session.root and session.root.valid and session.root.visible then
                root.dirty=root.dirty or {};root.dirty[index]=true
            end
        end
    end
    for _,player in pairs(game.players) do gui.launcher(player) end
end

function model.on_player_event(event)
    players.on_player_event(event);restrictions.on_player_event(event);targeting.on_player_event(event);lib.camera_window.on_player_changed(event)
    local player=game.get_player(event.player_index)
    if not player then return end
    if not common.authorize(player) then
        targeting.cancel(player,event.tick,true);gui.close(player.index,true);lib.camera_close_owner("admin",player.index)
    end
    gui.launcher(player)
end
function model.on_player_left_game(event)
    players.on_player_left_game(event)
    restrictions.on_player_left(event)
    local player=game.get_player(event.player_index);if player then targeting.cancel(player,event.tick,true) end
    gui.close(event.player_index);lib.camera_window.on_player_left(event)
end
function model.on_player_removed(event)
    players.on_player_removed(event);restrictions.on_player_removed(event)
    local player=game.get_player(event.player_index);if player then targeting.cancel(player,event.tick,true) end
    gui.close(event.player_index,true);lib.camera_window.on_player_left(event)
    local root=common.peek()
    if root then root.sessions[event.player_index]=nil;root.pending_selection[event.player_index]=nil end
end
function model.on_permission_group_edited(event) players.on_permission_group_edited(event);restrictions.on_permission_group_edited(event) end
function model.on_permission_group_deleted(event) players.on_permission_group_deleted(event);restrictions.on_permission_group_deleted(event) end
function model.on_gui_opened(event) return restrictions.on_gui_opened(event) end
function model.on_selected_entity_changed(event) restrictions.on_player_event(event) end
function model.on_gui_click(event) return gui.on_gui_click(event) or lib.camera_window.on_gui_click(event) end
function model.on_gui_change(event) return gui.on_gui_change(event) end
function model.on_gui_closed(event) restrictions.on_gui_closed(event);gui.on_gui_closed(event);lib.camera_window.on_gui_closed(event) end
function model.on_built_entity(event) restrictions.on_built_entity(event) end
function model.on_object_destroyed(event) restrictions.on_object_destroyed(event) end
function model.on_area_order(event) return restrictions.on_area_order(event) end
function model.on_entity_interaction(event) restrictions.on_entity_interaction(event) end
function model.on_display_changed(event) players.on_display_changed(event);gui.on_display_changed(event) end
function model.on_cursor_changed(event) targeting.on_cursor_changed(event) end
function model.on_selected_area(event) return targeting.on_selected_area(event) end
function model.on_forces_merged(event) players.on_forces_merged(event) end
function model.on_surface_created(event)
    world.on_surface_created(event)
    if common.enabled() then
        local root=common.state();root.policy_due=root.policy_due or {}
        root.policy_due[event.surface_index]={surface=game.get_surface(event.surface_index),tick=event.tick+1}
    end
end
---@param surface LuaSurface
---@param newly_created boolean Existing legacy surfaces retain their native default.
function model.on_planet_surface_ready(surface,newly_created)
    if not (common.enabled() and surface and surface.valid and surface.planet)
        or surface.name:find("^ei%-admin%-") then return end
    if newly_created and settings.global[config.peaceful_setting].value
        and world.get_policy(surface).peaceful_override==nil then surface.peaceful_mode=true end
    world.apply_policy(surface)
    local root=common.peek()
    if root and root.policy_due then root.policy_due[surface.index]=nil end
end
function model.on_surface_deleted(event) players.on_surface_deleted(event);targeting.on_surface_deleted(event);world.on_surface_deleted(event) end
function model.on_chunk_generated(event) world.on_chunk_generated(event) end
function model.on_chunk_charted(event) world.on_chunk_charted(event) end
function model.on_biter_base_built(event) world.on_biter_base_built(event) end

function model.has_tick_work(tick)
    if players.has_tick_work(tick) or world.has_tick_work() or registry.has_tick_work() or restrictions.has_tick_work(tick) then return true end
    local root=common.peek()
    if root and root.ui_due_tick and tick>=root.ui_due_tick then return true end
    if root and root.auto_refresh_due_tick and tick>=root.auto_refresh_due_tick then return true end
    return root and ((root.dirty and next(root.dirty)) or next(root.research_due) or (root.policy_due and next(root.policy_due))
        or (root.restriction_dirty and next(root.restriction_dirty)))~=nil or false
end
function model.updater(event)
    local tick=event.tick
    if players.has_tick_work(tick) then players.updater(tick) end
    if world.has_tick_work() then world.updater(tick) end
    if registry.has_tick_work() then registry.updater(event) end
    if restrictions.has_tick_work(tick) then restrictions.updater(tick) end
    local root=common.peek();if not root then return end
    local refreshed=0
    for index in pairs(root.restriction_dirty or {}) do
        root.restriction_dirty[index]=nil
        local player=game.get_player(index);if player then restrictions.refresh(player,tick) end
        refreshed=refreshed+1;if refreshed>=16 then break end
    end
    if root.ui_due_tick and tick>=root.ui_due_tick then gui.refresh_visible(tick) end
    if root.auto_refresh_due_tick and tick>=root.auto_refresh_due_tick then gui.refresh_automatically(tick) end
    for index,pending in pairs(root.policy_due or {}) do
        if tick>=pending.tick then
            root.policy_due[index]=nil
            local surface=pending.surface
            model.on_planet_surface_ready(surface,true)
        end
    end
    for index,pending in pairs(root.research_due) do
        if tick>=pending.tick then
            root.research_due[index]=nil
            local force=pending.force
            local actor=pending.actor_index and game.get_player(pending.actor_index)
            if common.authorize(actor) and root.instant_research[index] and force and force.valid and force.current_research and force.current_research.name==pending.technology then
                if pending.infinite then root.infinite_completed[pending.key]=true end
                finish_research(force)
            end
        end
    end
    if tick%30==0 then
        for index in pairs(root.dirty or {}) do gui.refresh(index,tick) end
        root.dirty={}
    end
end

function model.repair_runtime_state(_,tick) model.on_configuration_changed(tick);return true end
function model.open(player,page,tick) gui.open(player,page,tick) end
function model.peek_runtime_summary(tick) return {enabled=common.enabled(),world=world.peek_summary(),players=players.peek_summary(tick),restrictions=restrictions.peek_summary()} end
function model.register_commands()
    commands.add_command("ei-admin",{"ei-admin.command-help"},function(event)
        local actor=event.player_index and game.get_player(event.player_index)
        local ok,message=common.authorize(actor)
        if ok then gui.open(actor,event.parameter,event.tick) else common.notify(event.player_index,message) end
    end)
    local function repair(event,id) model.execute(event.player_index and game.get_player(event.player_index),"repair",{module_id=id or event.parameter},event.tick) end
    commands.add_command("ei-admin-repair",{"ei-admin.repair-help"},function(event) repair(event) end)
    for _,entry in ipairs(registry.list()) do
        if entry.repair then local id=entry.id;commands.add_command("ei-admin-repair-"..id,{"ei-admin.repair-help"},function(event) repair(event,id) end) end
    end
end
model.world=world
model.registry=registry
return model
