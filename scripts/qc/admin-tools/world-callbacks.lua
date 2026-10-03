-- Actual raised-build callbacks test authorization/cancellation between creations.
-- Travel checks simulate a saved stale catalog signature on real native GUI nodes.
local model={}
local function call(name,...)return remote.call("esir-admin-qc",name,...)end
local function arm(player,surface,tick,mode,check)
    local state={player=player.index,surface=surface.index,start=tick,mode=mode,created=0}
    storage.admin_callback_qc=state
    local ok,message=call("execute",player.index,"place_entities",{surface_index=surface.index,force_index=player.force.index,
        position={x=32,y=mode=="revoke" and 36 or 24},place_item={name="wooden-chest",quality="normal"},quantity=4,direction=0},tick)
    check("callback "..mode.." creation job admitted",ok,message)
    for _,job in ipairs(call("world_summary").jobs) do
        if job.actor_index==player.index and job.kind=="place_entities" and job.surface_index==surface.index then state.job_id=job.id end
    end
    assert(state.job_id,"Callback fixture job missing")
end
function model.start(player,surface,tick,check)arm(player,surface,tick,"revoke",check)end
function model.on_built(event)
    local state=storage.admin_callback_qc
    local entity=event.entity
    if not (state and entity and entity.valid and entity.name=="wooden-chest" and entity.surface.index==state.surface) then return end
    state.created=state.created+1
    if state.created~=1 then return end
    local player=assert(game.get_player(state.player))
    if state.mode=="revoke" then player.admin=false
    else state.cancelled=call("execute",player.index,"cancel_job",{job_id=state.job_id},event.tick) end
end
function model.tick(tick,check)
    local state=assert(storage.admin_callback_qc)
    if tick-state.start<8 then return false end
    if state.mode=="explicit-spawn" then
        local surface=game.get_surface(state.surface)
        check("explicit admin wave works while natural spawning is disabled",
            surface.no_enemies_mode and surface.peaceful_mode
            and surface.count_entities_filtered{name="small-biter",force="enemy"}==2)
        storage.admin_callback_qc=nil
        return true
    end
    check("callback "..state.mode.." stops creation after first entity",state.created==1,state.created)
    local active=false
    for _,job in ipairs(call("world_summary").jobs) do if job.id==state.job_id then active=true end end
    check("callback "..state.mode.." removes queued creation job",not active)
    local player=assert(game.get_player(state.player));player.admin=true
    if state.mode=="revoke" then arm(player,game.get_surface(state.surface),tick,"cancel",check);return false end
    check("callback cancellation succeeds during raised build",state.cancelled)
    for _,entry in ipairs(call("travel_catalog_fixture",player.index,tick)) do check(entry.name,entry.ok,entry.detail) end
    call("execute",player.index,"planet_spawning",{surface_index=state.surface,enabled=false},tick)
    call("execute",player.index,"planet_peaceful",{surface_index=state.surface,enabled=true},tick)
    local ok,message=call("execute",player.index,"spawn_enemies",{surface_index=state.surface,
        position={x=-24,y=-24},enemy_mix={{name="small-biter",count=2}}},tick)
    check("explicit wave admitted under peaceful no-enemies policy",ok,message)
    state.mode="explicit-spawn";state.start=tick
    return false
end
local function find(parent,predicate)
    for _,child in ipairs(parent.children) do
        if predicate(child.tags) then return child end
        local nested=find(child,predicate);if nested then return nested end
    end
end
function model.travel(admin,gui,common,player,tick)
    local checks={}
    local function check(name,ok,detail)checks[#checks+1]={name=name,ok=not not ok,detail=detail}end
    admin.open(player,"players",tick)
    local session=common.state().sessions[player.index]
    local root=session.root;local field=session.fields.x
    local mode=assert(find(session.pages.players,function(t)return t.action=="execute" and t.operation=="god" end))
    field.text="17.25";gui.on_gui_change{player_index=player.index,element=field,tick=tick}
    local destinations=assert(session.travel_destinations)
    local expected=#admin.planets();local original=assert(destinations.children[1])
    gui.refresh(player.index,tick)
    check("unchanged planet catalog retains destination row",original.valid and destinations.children[1]==original)
    session.travel_signature="fixture:previous-mod-catalog"
    original.destroy()
    gui.refresh(player.index,tick)
    check("stale travel catalog rebuilds all native planet rows",#destinations.children==expected)
    check("travel reconciliation retains root controls and drafts",session.root==root and root.valid and mode.valid
        and session.fields.x==field and field.text=="17.25" and session.drafts.x=="17.25")
    local current=assert(destinations.children[1])
    gui.close(player.index)
    session.travel_signature="fixture:second-mod-catalog"
    gui.refresh(player.index,tick)
    check("closed travel menu does not reconcile catalog",not root.visible and current.valid and destinations.children[1]==current)
    admin.open(player,"players",tick)
    check("reopened travel menu reconciles only destination rows",root.valid and root.visible and not current.valid
        and mode.valid and field.valid and #destinations.children==expected)
    return checks
end
return model
