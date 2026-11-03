-- Deterministic heap, independent-budget, cooldown, transfer and migration checks.
package.path="exotic-space-industries-remembrance/?.lua;"..package.path
local scheduler=require("lib/runtime-scheduler")
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local heap=scheduler.ensure_deadline_queue();local expected={}
local random=37
for i=1,4000 do
    random=(random*48271)%2147483647;local id=random%127+1
    if i%4==0 then scheduler.deadline_remove(heap,id);expected[id]=nil
    else local due=random%311;scheduler.deadline_put(heap,id,due);expected[id]=due end
    local key,due,count=nil,nil,0
    for candidate,tick in pairs(expected) do
        count=count+1
        if not due or tick<due or tick==due and candidate<key then key,due=candidate,tick end
    end
    local actual,deadline=scheduler.deadline_peek(heap)
    check(actual==key and deadline==due and scheduler.deadline_count(heap)==count,"deadline ordering and unique membership")
    for index,node in ipairs(heap.nodes) do check(heap.indices[node.key]==index,"heap index integrity") end
end
local previous=-1
while scheduler.deadline_count(heap)>0 do
    local key,due=scheduler.deadline_pop_due(heap,1000)
    check(key and due>=previous,"deadline drain is ordered");previous=due
end
check(scheduler.deadline_peek(heap)==nil and scheduler.deadline_count(heap)==0,"deadline empty state")

settings={startup={},global={
    ["ei-factory-passage-update-budget"]={value=256},
    ["ei-factory-passage-circuit-scan-budget"]={value=1},
    ["ei-factory-passage-circuit-scanner-enabled"]={value=false}}}
for _,key in ipairs{"enabled","production","power","logistics","turrets"} do settings.startup["ei-factory-passage-"..key]={value=true} end
settings.startup["ei-factory-passage-pipe-mode"]={value="esir"}
defines={control_behavior={type={assembling_machine=1}}}
script={active_mods={},register_on_object_destroyed=function(e) return e.unit_number+100000 end}
package.loaded["lib/lib"]={entity_check=function(e) return e and e.valid and e.object_name=="LuaEntity" end}
prototypes={mod_data={["ei-factory-passage"]={data={pipe_names={"pipe"},pipes={pipe=true},walkable={},characters={}}}}}
local owner=require("scripts/control/factory-passage")
local players,machines,queries={}, {},0
local surface={index=1};local tick=0
local function entity(id,kind)
    local e={valid=true,object_name="LuaEntity",unit_number=id,type=kind,name=kind,surface=surface,position={x=id*4,y=0},
        bounding_box={left_top={x=0,y=0},right_bottom={x=1,y=1}},prototype={fluidbox_prototypes={true}},fluids_count=0,reads=0}
    e.behavior={valid=true,type=1,circuit_set_recipe=kind=="assembling-machine"}
    e.get_recipe=function() e.reads=e.reads+1;return e.recipe and {name=e.recipe},nil end
    e.get_control_behavior=function() return e.behavior end
    return e
end
local pipe=entity(1,"pipe")
surface.find_entities_filtered=function(filter)
    queries=queries+1
    if filter.type then return machines end
    if filter.name[1]=="pipe" then return {pipe} end
    return {}
end
game={surfaces={[1]=surface},connected_players={},get_player=function(index) return players[index] end}
local function step(at)
    tick=at or tick+1
    if owner.has_work(tick) then owner.updater(owner.update_budget(),{tick=tick}) end
end
local function seed(n)
    machines={};players={};game.connected_players={};storage={ei={}}
    settings.global["ei-factory-passage-update-budget"].value=256
    settings.global["ei-factory-passage-circuit-scanner-enabled"].value=false
    settings.global["ei-factory-passage-circuit-scan-budget"].value=1
    for id=2,n+1 do machines[#machines+1]=entity(id,"assembling-machine") end
    owner.rebuild_runtime_state("fixture",tick)
    repeat step() until owner.status().dirty==0
    return storage.ei.factory_passage
end
local s=seed(1);local record=s.endpoints[2];local fresh=record.last_reconciled_tick
local reads=machines[1].reads;local before_queries=queries
settings.global["ei-factory-passage-circuit-scanner-enabled"].value=true
check(not owner.has_work(fresh+59),"cooling machine admits no recurring work")
step(fresh+59);check(machines[1].reads==reads and queries==before_queries,"cooldown performs no native or spatial reads")
step(fresh+60);check(machines[1].reads==reads+1 and s.counters.circuit_scans==1,"exact60 deadline scans once")
step(fresh+61);check(machines[1].reads==reads+1,"unchanged scan restarts cooldown")
machines[1].recipe="event-change";owner.refresh_entity(machines[1],tick,true);step()
check(record.recipe=="event-change::0" and record.last_reconciled_tick==tick,"explicit refresh bypasses cooldown and synchronizes signature")
local identity=s.circuit_deadlines;local count=s.counters.created
settings.global["ei-factory-passage-circuit-scanner-enabled"].value=false
owner.on_settings_changed{setting="ei-factory-passage-circuit-scanner-enabled",setting_type="runtime-global",tick=tick}
step(tick+100);check(not owner.has_work(tick) and s.circuit_deadlines==identity and s.counters.created==count,"scanner Off parks without helper churn")
settings.global["ei-factory-passage-circuit-scanner-enabled"].value=true
step();check(s.counters.circuit_scans==2,"reenabling services overdue candidate")

players[1]={valid=true,connected=true,index=1,opened=machines[1]};game.connected_players={players[1]}
owner.on_gui_opened{player_index=1,tick=tick}
check(s.shared_watch_count==1 and s.circuit_candidate_count==0,"GUI immediately owns cached eligible machine before deferred work")
step()
check(s.watch_count==1 and s.shared_watch_count==1 and s.circuit_candidate_count==0,"GUI owns overlapping reasons exclusively")
local circuit_attempts=s.counters.circuit_attempts
machines[1].recipe="gui-change";step();step()
check(record.recipe=="gui-change::0" and s.counters.circuit_attempts==circuit_attempts,"GUI remains responsive inside circuit cooldown")
players[2]={valid=true,connected=true,index=2,opened=machines[1]};owner.on_gui_opened{player_index=2,tick=tick};step()
players[1].opened=nil;owner.on_gui_closed{player_index=1,tick=tick};step()
check(s.gui_session_count==1 and s.gui_watch_count==1,"second viewer retains GUI service")
players[2].opened=nil;owner.on_gui_closed{player_index=2,tick=tick};step()
local _,due=scheduler.deadline_peek(s.circuit_deadlines)
check(s.shared_watch_count==0 and s.circuit_candidate_count==1 and due==tick+60,"last close hands fresh signature to circuit deadline")

s=seed(1200)
for i=1,4096 do local id=200000+i;s.endpoints[id]={due=10000000};scheduler.queue_push_unique(s.dirty,id) end
s.dirty_count=4096
settings.global["ei-factory-passage-circuit-scanner-enabled"].value=true
for _,base in ipairs{1,2,7,8,31,32,63,64,65,256,1024} do
    for _,circuit in ipairs{1,2,31,32,33,256,1024} do
        settings.global["ei-factory-passage-update-budget"].value=base
        settings.global["ei-factory-passage-circuit-scan-budget"].value=circuit
        local main_before=s.counters.processed;local scan_before=s.counters.circuit_attempts or 0
        step(tick+1000)
        check(s.counters.processed-main_before==base,"main allowance remains independent")
        check(s.counters.circuit_attempts-scan_before==circuit,"separate circuit allowance and live pace")
        check(s.counters.processed-main_before+s.counters.circuit_attempts-scan_before==base+circuit,"additional combined bound")
    end
end
check(s.circuit_candidate_count==1200,"deadline rescheduling does not duplicate candidates")

s=seed(8);local dirty,pending=s.dirty,s.pending;s.service_cursor=8
s.version=2;s.circuit_deadlines=nil;s.circuit_candidate_count=nil;s.shared_watch_count=nil;s.watchers=scheduler.ensure_queue()
for _,e in ipairs(machines) do local r=s.endpoints[e.unit_number];r.watch_revision=nil;r.watch_service=nil;r.last_signature_tick=nil;r.last_reconciled_tick=nil;scheduler.queue_push_unique(s.watchers,e.unit_number) end
settings.global["ei-factory-passage-update-budget"].value=1
step();check(s.version==3 and s.legacy_watch_count==7 and s.circuit_candidate_count==1,"version2 migration is budgeted while scanner Off")
check(s.dirty==dirty and s.pending==pending and s.service_cursor==1,"migration retains queues and advances the existing rotation through its observer slot")
for _=1,7 do step() end
check(s.legacy_watch_count==0 and s.shared_watch_count==0 and s.watch_count==8 and not owner.has_work(tick),"migration finishes with parked circuit population")
local before=queries;local status=owner.status();status.counters.circuit_attempts=900
check(queries==before and (s.counters.circuit_attempts or 0)==0,"scanner status is pure and detached")
print("PASS "..checks.." deadline/circuit scanner checks (offline Lua)")
