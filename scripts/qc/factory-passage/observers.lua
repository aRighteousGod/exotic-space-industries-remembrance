-- Offline admission/session/migration checks against the production owner.
package.path="exotic-space-industries-remembrance/?.lua;"..package.path
settings={startup={},global={["ei-factory-passage-update-budget"]={value=256}}}
settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=true}
settings.global["ei-factory-passage-circuit-scan-budget"]={value=1}
for _,key in ipairs{"enabled","production","power","logistics","turrets"} do settings.startup["ei-factory-passage-"..key]={value=true} end
settings.startup["ei-factory-passage-pipe-mode"]={value="esir"}
defines={control_behavior={type={assembling_machine=1}}}
script={active_mods={},register_on_object_destroyed=function(entity) return entity.unit_number+100 end}
package.loaded["lib/lib"]={entity_check=function(e) return e and e.valid and e.object_name=="LuaEntity" end}
prototypes={mod_data={["ei-factory-passage"]={data={pipe_names={"pipe"},pipes={pipe=true},walkable={},characters={}}}}}
local scheduler=require("lib/runtime-scheduler")
local owner=require("scripts/control/factory-passage")
local checks,tick,queries=0,0,0
local function check(value,message) assert(value,message);checks=checks+1 end
local players={}
local surface={index=1}
local near=true
local function entity(id,kind)
    local e={valid=true,object_name="LuaEntity",unit_number=id,name=kind,type=kind,surface=surface,position={x=id*4,y=0},
        bounding_box={left_top={x=0,y=0},right_bottom={x=1,y=1}},prototype={fluidbox_prototypes={true}},fluids_count=0}
    e.get_recipe=function() return e.recipe and {name=e.recipe},nil end
    e.behavior={valid=true,type=1,circuit_set_recipe=false}
    e.get_control_behavior=function() return e.behavior end
    return e
end
local pipe=entity(1,"pipe")
local machine=entity(2,"assembling-machine")
surface.find_entities_filtered=function(filter)
    queries=queries+1
    if filter.type then return {machine} end
    if filter.name[1]=="pipe" and near then return {pipe} end
    return {}
end
game={surfaces={[1]=surface},connected_players={},get_player=function(index) return players[index] end}
storage={ei={}}
owner.rebuild_runtime_state("init",0)
local function drain(count)
    for _=1,count or 12 do tick=tick+1;if owner.has_work(tick) then owner.updater(256,{tick=tick}) end end
end
local function refresh(e) owner.refresh_entity(e or machine,tick,true);drain() end
local function open(index,e)
    players[index]=players[index] or {valid=true,connected=true,index=index}
    players[index].opened=e;owner.on_gui_opened{player_index=index,tick=tick};drain()
end
local function close(index)
    players[index].opened=nil;owner.on_gui_closed{player_index=index,tick=tick};drain()
end
drain()
check(owner.status().watchers==0 and not owner.has_work(),"closed manual factory settles without observers")
local before_queries=queries;drain(20);check(queries==before_queries,"idle manual factory performs no spatial queries")
machine.recipe="changed-silently";drain();check(not owner.has_work(),"no fallback sweep for silent external changes")
refresh();check(not owner.has_work(),"explicit refresh reconciles then settles")
machine.behavior.circuit_set_recipe=true;refresh()
check(owner.status().watchers==1 and owner.status().circuit_watchers==1,"native circuit admission")
machine.recipe=nil;drain();check(owner.status().watchers==1,"recipe-less circuit machine stays observed")
local before=queries;drain(20);check(queries==before,"stable circuit observers do no proximity queries")
open(1,machine);open(2,machine)
check(owner.status().watchers==1 and owner.status().gui_watchers==1 and owner.status().gui_sessions==2,"two viewers and two reasons share one observer")
close(1);check(owner.status().gui_watchers==1,"one viewer closing retains second")
machine.behavior.circuit_set_recipe=false;drain()
check(owner.status().circuit_watchers==0 and owner.status().watchers==1,"disabling circuit keeps open GUI observer")
close(2);check(owner.status().watchers==0,"last viewer retires manual observer")
open(1,machine);owner.on_teleported{entity=machine,tick=tick};drain()
check(owner.status().gui_sessions==1 and owner.status().gui_watchers==1,"raised teleport preserves a live native viewer");close(1)
near=false;refresh();open(1,machine)
check(owner.status().watchers==0 and owner.status().gui_sessions==1,"open machine without pipes retains session only")
near=true;refresh(pipe);check(owner.status().gui_watchers==1,"first pipe admits existing GUI")
near=false;refresh();check(owner.status().watchers==0 and owner.status().gui_sessions==1,"last pipe retires observer without dropping GUI session")
near=true;refresh();open(1,nil);check(owner.status().watchers==0 and owner.status().gui_sessions==0,"unrelated open closes prior session")
near=false;local temporary=entity(9,"assembling-machine");open(1,temporary)
temporary.valid=false;owner.on_object_destroyed{registration_number=109,tick=tick};drain()
check(owner.status().gui_sessions==0,"pipe-less GUI session has silent destruction ownership")
near=true
open(1,machine);players[1].connected=false;drain()
check(owner.status().watchers==0 and owner.status().gui_sessions==0,"stale disconnected viewer retires during observer service")
players[1].connected=true;open(1,machine);owner.on_player_left{player_index=1,tick=tick};owner.on_player_left{player_index=1,tick=tick};drain()
check(owner.status().gui_sessions==0 and owner.status().gui_watchers==0,"exceptional close is idempotent")
local silo=entity(3,"rocket-silo");silo.get_control_behavior=function() error("rocket silo control must not be read as assembler") end
open(1,silo);check(owner.status().gui_watchers==1,"rocket silo GUI observation uses safe behavior guard");close(1)
open(1,machine);game.connected_players={players[1]};owner.rebuild_runtime_state("repair",tick);drain()
check(owner.status().gui_watchers==1 and owner.status().gui_sessions==1,"repair restores native GUI session")
local snapshot=owner.status();snapshot.rebuild.phase="bad";snapshot.counters.topology=-1
check(owner.status().rebuild.phase~="bad" and owner.status().counters.topology>=0,"diagnostics detached")
owner.on_surface_removed{surface_index=1,tick=tick};drain()
check(owner.status().gui_sessions==0 and owner.status().watchers==0,"surface cleanup retires sessions and watchers")
-- Exact old schema: keep a live report and scheduler object identities.
game.connected_players={};players[1].opened=nil;owner.rebuild_runtime_state("fixture",tick);drain()
local s=storage.ei.factory_passage;local record=s.endpoints[2]
s.version=1;s.gui_sessions=nil;s.gui_viewers=nil;s.gui_session_count=nil;s.circuit_watch_count=nil;s.gui_watch_count=nil;s.legacy_watch_count=nil
record.recipe="old::0";record.watch_classified=nil;record.watch_gui=nil;record.watch_circuit=nil;record.nearby=nil;record.watch_revision=nil;record.watch_service=nil
s.watch_count=1;scheduler.queue_push_unique(s.watchers,2);s.service_cursor=4
local dirty,pending,watchers=s.dirty,s.pending,s.watchers
local report={active=false,completed=17,id=123,phase="completed"};s.rebuild=report
owner.on_gui_closed{player_index=999,tick=tick}
check(s.service_cursor==4 and s.gui_restore_pending,"early migration preserves cursor and pending session restoration")
owner.updater(1,{tick=tick+1})
check(s.version==3 and s.legacy_watch_count==0 and s.watch_count==0,"legacy ordinary watcher classified within budget one")
check(s.dirty==dirty and s.pending==pending and s.watchers==watchers and s.rebuild==report and report.completed==17,"schema migration preserves queues and report")
check(s.service_cursor==1 and not s.gui_restore_pending,"watcher service advances cursor and completes session restoration")
storage={};local pure=owner.status();check(not storage.ei and pure.watchers==0,"status never initializes state")
for _,case in ipairs{
    {mode="vanilla",enabled=true},{mode="squeak-through",enabled=true},
    {mode="esir",enabled=false},{mode="esir",enabled=true,companion=true},
} do
    settings.startup["ei-factory-passage-pipe-mode"].value=case.mode
    settings.startup["ei-factory-passage-enabled"].value=case.enabled
    script.active_mods=case.companion and {["squeak-through-2"]="0.2.0"} or {}
    package.loaded["scripts/control/factory-passage"]=nil
    local inactive=require("scripts/control/factory-passage")
    for _,version in ipairs{1,2,3} do
        local legacy={version=version,gui_restore_pending=version==2,dirty_count=0,pending_count=0,watch_count=0}
        storage={ei={factory_passage=legacy}}
        check(not inactive.has_work() and legacy.version==version and legacy.gui_sessions==nil,
            "inactive legacy/restoration state admits no recurring work: "..case.mode.."/"..tostring(case.enabled).."/"..version)
    end
end
settings.startup["ei-factory-passage-pipe-mode"].value="esir";settings.startup["ei-factory-passage-enabled"].value=true;script.active_mods={}
package.loaded["scripts/control/factory-passage"]=nil;storage.ei.factory_passage.version=1
check(require("scripts/control/factory-passage").has_work(),"effective ESIR still admits legacy migration")
print("PASS "..checks.." factory passage observer/session checks (offline Lua)")
