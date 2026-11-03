-- Offline control-flow checks against the production owner and shared scheduler.
-- Native geometry, persistence and GUI acceptance remain separate fixtures.
package.path="exotic-space-industries-remembrance/?.lua;"..package.path
settings={startup={},global={["ei-factory-passage-update-budget"]={value=256}}}
settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=true}
settings.global["ei-factory-passage-circuit-scan-budget"]={value=1}
for _,name in ipairs{"enabled","production","power","logistics","turrets"} do settings.startup["ei-factory-passage-"..name]={value=true} end
settings.startup["ei-factory-passage-pipe-mode"]={value="esir"}
script={active_mods={}}
defines={control_behavior={type={assembling_machine=1}}}
game={connected_players={},get_player=function() return nil end}
package.loaded["lib/lib"]={entity_check=function(e) return e and e.valid end}
local scheduler=require("lib/runtime-scheduler")
local passage=require("scripts/control/factory-passage")
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function seed()
    storage={ei={}}
    local s={endpoints={},joints={},registrations={},dirty=scheduler.ensure_queue(),pending=scheduler.ensure_queue(),watchers=scheduler.ensure_queue(),
        dirty_count=4096,pending_count=4096,blocked_count=0,watch_count=4096,joint_count=0,helper_count=0,service_cursor=1,
        counters={topology=0,processed=0,max_processed=0,created=0,destroyed=0,native=0,unsupported=0}}
    storage.ei.factory_passage=s
    for i=1,4096 do
        scheduler.queue_push_unique(s.dirty,i);s.endpoints[i]={due=1000000}
        scheduler.queue_push_unique(s.pending,i);s.joints[i]={a=-1,b=-2}
        scheduler.queue_push_unique(s.watchers,i+10000)
        s.endpoints[i+10000]={id=i+10000,recipe="::0",entity={valid=true,type="assembling-machine",prototype={fluidbox_prototypes={true}},fluids_count=0,
            get_control_behavior=function() return {valid=true,type=1,circuit_set_recipe=true} end,get_recipe=function() return nil,nil end}}
    end
    return s
end
for _,budget in ipairs{1,2,7,8,31,32,63,64,65,256,1024} do
    local s=seed();settings.global["ei-factory-passage-update-budget"]={value=budget}
    for tick=1,8 do
        local before=s.counters.processed
        local pending=s.counters.pending_attempts or 0;local watched=s.counters.watchers_attempts or 0
        passage.updater(budget,{tick=tick})
        check(s.counters.processed-before==budget,"combined budget "..budget)
        check((s.counters.pending_attempts or 0)-pending<=math.ceil(budget/8),"pending share")
        check((s.counters.watchers_attempts or 0)-watched<=math.ceil(budget/8),"watcher share")
    end
    check(s.counters.dirty_attempts>0 and s.counters.pending_attempts>0 and s.counters.watchers_attempts>0,"all classes progress at "..budget)
    if budget==256 or budget==1024 then
        check(s.counters.dirty_attempts==budget*6,"six dirty shares")
        check(s.counters.pending_attempts==budget and s.counters.watchers_attempts==budget,"one pending and watcher share")
    end
    local before=s.counters.processed
    settings.global["ei-factory-passage-update-budget"]={value=1}
    passage.updater(1024,{tick=20})
    check(s.counters.processed-before==1,"live setting overrides stale caller budget")
    local snapshot=passage.status();snapshot.counters.processed=-1
    check(s.counters.processed>=0,"status counters detached")
end
-- A watcher removed during interleaving can leave the queue shorter than its
-- start-of-tick allowance. Requeued survivors must only read their recipe once.
do
    local s=seed();settings.global["ei-factory-passage-update-budget"]={value=256}
    s.dirty_count=0;s.pending_count=0;s.watch_count=32;s.watchers=scheduler.ensure_queue()
    local calls=0
    local entity={valid=true,type="assembling-machine",prototype={fluidbox_prototypes={true}},fluids_count=0,
        get_control_behavior=function() return {valid=true,type=1,circuit_set_recipe=true} end,get_recipe=function() calls=calls+1;return nil,nil end}
    s.endpoints[99999]={id=99999,recipe="::0",entity=entity}
    scheduler.queue_push_unique(s.watchers,99999)
    passage.updater(256,{tick=30})
    check(calls==1,"compacted survivor observed once")
    check(s.counters.processed==32,"duplicate candidates still consume bounded allowance")
end
do
    local s=seed();s.dirty_count=0;s.watch_count=0;s.pending_count=2;s.pending=scheduler.ensure_queue()
    settings.global["ei-factory-passage-update-budget"]={value=256}
    prototypes={mod_data={["ei-factory-passage"]={data={walkable={},characters={character=true}}}}}
    local queries=0
    game={connected_players={},surfaces={[1]={find_entities_filtered=function() queries=queries+1;return {{is_flying=false,name="character"}} end}}}
    local a={valid=true,type="pump",name="pump",bounding_box={left_top={x=-0.2,y=-0.2},right_bottom={x=0.2,y=0.2}}}
    local b={valid=true,type="pump",name="pump",bounding_box={left_top={x=0.8,y=-0.2},right_bottom={x=1.2,y=0.2}}}
    s.endpoints[1]={entity=a};s.endpoints[2]={entity=b}
    local joint={a=1,b=2,surface=1,horizontal=true,position={x=0.5,y=0},p={x=0,y=0},q={x=1,y=0}}
    s.joints[1]=joint;s.joints[2]=joint
    scheduler.queue_push_unique(s.pending,1);scheduler.queue_push_unique(s.pending,2)
    passage.updater(256,{tick=40})
    check(queries==1 and s.blocked_count==1,"same joint queried once despite duplicate candidates")
    check(s.counters.pending_attempts==2,"skipped duplicate joint still consumes allowance")
    s.endpoints[1]=nil
    passage.updater(256,{tick=40})
    check(s.blocked_count==0 and s.pending_count==0,"same-tick terminal success clears blocked state")
end
print("PASS "..checks.." factory passage fairness/status checks (offline Lua)")
