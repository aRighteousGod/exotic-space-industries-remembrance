-- Offline report/ownership transitions using the production passage owner and
-- scheduler. Surface objects are mocked; native geometry has separate receipts.
package.path="exotic-space-industries-remembrance/?.lua;"..package.path
settings={startup={},global={["ei-factory-passage-update-budget"]={value=1}}}
settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=true}
settings.global["ei-factory-passage-circuit-scan-budget"]={value=1}
for _,name in ipairs{"enabled","production","power","logistics","turrets"} do settings.startup["ei-factory-passage-"..name]={value=true} end
settings.startup["ei-factory-passage-pipe-mode"]={value="esir"}
script={active_mods={},register_on_object_destroyed=function(entity) return entity.unit_number+1000 end}
package.loaded["lib/lib"]={entity_check=function(entity) return entity and entity.valid end}
prototypes={mod_data={["ei-factory-passage"]={data={pipe_names={"pipe"},pipes={pipe=true},walkable={},characters={}}}}}
local scheduler=require("lib/runtime-scheduler")
local checks=0
local function check(value,name) assert(value,name);checks=checks+1 end
local function load_owner()
    package.loaded["scripts/control/factory-passage"]=nil
    return require("scripts/control/factory-passage")
end
local function surface(index)
    local result={index=index,pipes={},helpers={}}
    result.find_entities_filtered=function(filter)
        if filter.type then return {} end
        if filter.name[1]=="pipe" then return result.pipes end
        local found={};for _,helper in pairs(result.helpers) do if helper.valid then found[#found+1]=helper end end
        return found
    end
    return result
end
local function seed()
    settings.startup["ei-factory-passage-enabled"].value=true
    settings.startup["ei-factory-passage-pipe-mode"].value="esir"
    script.active_mods={};storage={ei={}};game={connected_players={},surfaces={[1]=surface(1),[2]=surface(2)}}
    local owner=load_owner();owner.rebuild_runtime_state("init",0)
    local s=storage.ei.factory_passage
    local helper={valid=true};helper.destroy=function() helper.valid=false end
    game.surfaces[1].helpers={helper}
    s.helper_count=1;s.joint_count=1;s.blocked_count=1
    s.joints.joint={a=1,b=2,surface=1,helper=helper,registration=1003,blocked=true}
    s.registrations[1003]={joint="joint"}
    for id=1,2 do
        s.endpoints[id]={id=id,name="pipe",surface=1,entity={valid=false},joints={joint=true},registration=id+1000,
            due=1,box={left_top={x=0,y=0},right_bottom={x=1,y=1}}}
        s.registrations[id+1000]={endpoint=id};scheduler.queue_push_unique(s.dirty,id)
    end
    s.dirty_count=2;s.pending_count=1;scheduler.queue_push_unique(s.pending,"joint")
    local id=scheduler.begin_rebuild("factory-passage","joint-reconciliation","global",{completed=0,total=false},1)
    s.rebuild={id=id,active=true,completed=0,phase="joint-reconciliation",reason="fixture"}
    return owner,s,id,helper
end
local function outcome(id,wanted,tick)
    local matches=0
    for _,row in ipairs(scheduler.peek_rebuilds(tick,"factory-passage").history) do
        if row.id==id and row.outcome==wanted then matches=matches+1 end
    end
    check(matches==1,"report retires exactly once as "..wanted)
end
do
    local owner,s,id,helper=seed()
    owner.on_surface_removed{surface_index=1,tick=2}
    check(not next(s.endpoints) and not next(s.joints) and not next(s.registrations),"surface ownership removed")
    check(not helper.valid and s.helper_count==0 and s.blocked_count==0,"surface helper and occupancy removed")
    check(s.dirty_count==2 and s.pending_count==1,"surface tombstones retained for bounded drain")
    check(s.rebuild.active and s.rebuild.phase=="joint-reconciliation","stale tokens are not character waiting")
    for tick=3,10 do
        local before=s.counters.processed;owner.updater(1,{tick=tick})
        check(s.counters.processed-before<=1,"surface cleanup respects budget one")
    end
    check(s.dirty_count==0 and s.pending_count==0 and not s.rebuild.active,"surface cleanup completes")
    check(#scheduler.peek_rebuilds(10,"factory-passage").active==0,"surface report retired")
    outcome(id,"completed",10)
end
for _,mode in ipairs{"vanilla","squeak-through","master-disabled","companion"} do
    local owner,s,id,helper=seed()
    if mode=="master-disabled" then settings.startup["ei-factory-passage-enabled"].value=false
    elseif mode=="companion" then script.active_mods["squeak-through-2"]="0.2.0"
    else settings.startup["ei-factory-passage-pipe-mode"].value=mode end
    owner=load_owner();owner.rebuild_runtime_state("configuration-changed",3)
    local now=owner.status()
    check(not helper.valid and now.helpers==0 and now.dirty==0 and now.pending==0 and now.watchers==0,"inactive cleanup: "..mode)
    check(not now.enabled and not now.rebuild.active and now.update_budget==1,"inactive retains setting without work: "..mode)
    check(now.inactive_reason==((mode=="vanilla" or mode=="squeak-through") and "pipe-mode" or mode),"inactive reason: "..mode)
    check(#scheduler.peek_rebuilds(3,"factory-passage").active==0,"inactive has no asynchronous report: "..mode)
    outcome(id,"superseded",3)
end
do
    local owner,s,id=seed()
    s.endpoints[77]={id=77,name="pipe",surface=2,entity={valid=false},joints={},registration=1077,due=1000000}
    s.registrations[1077]={endpoint=77};scheduler.queue_push_unique(s.dirty,77);s.dirty_count=s.dirty_count+1
    local imported={valid=true,unit_number=501,name="pipe",type="pipe",surface=game.surfaces[1],position={x=4,y=4},
        bounding_box={left_top={x=3.8,y=3.8},right_bottom={x=4.2,y=4.2}},fluids_count=0,prototype={}}
    game.surfaces[1].pipes={imported}
    owner.on_surface_imported{surface_index=1,tick=4}
    check(s.endpoints[77]~=nil and s.endpoints[501]~=nil,"import retains other surface and admits imported pipe")
    check(s.endpoints[1]==nil and s.endpoints[2]==nil and s.blocked_count==0,"import clears old surface ownership")
    local active=scheduler.peek_rebuilds(4,"factory-passage").active
    check(#active==1 and active[1].id==s.rebuild.id and active[1].operation=="joint-reconciliation" and active[1].scope=="global","import has one global replacement report")
    check(active[1].total==nil and active[1].eta_ticks==nil,"import backlog has unknown total and no ETA")
    outcome(id,"superseded",4)
    s.service_cursor=5;local report=s.rebuild.id
    owner=load_owner()
    check(storage.ei.factory_passage==s and s.service_cursor==5 and s.rebuild.id==report,"module reload does not mutate cursor or report")
end
print("PASS "..checks.." factory passage report lifecycle checks (offline Lua)")
