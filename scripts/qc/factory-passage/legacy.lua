-- Load the real frozen legacy owner's populated checkpoint with the current owner.
-- Deliberately no on_load handler: adoption occurs only through budgeted service.
local passage=require("scripts/control/factory-passage")
local scheduler=require("lib/runtime-scheduler")
local started,checks,original,dirty,pending,report,helper_ids
local function check(value,name)
    checks[#checks+1]={name=name,passed=not not value};assert(value,name)
end
script.on_event(defines.events.on_object_destroyed,passage.on_object_destroyed)
script.on_event(defines.events.on_tick,function(e)
    if started==false then return end
    local s=storage.ei.factory_passage
    if not started then
        started=e.tick;checks={};original=s;dirty=s.dirty;pending=s.pending;report=serpent.line(s.rebuild);helper_ids={}
        check(s.version==1 or s.version==2,"real legacy save retains old subsystem revision until service")
        check(s.watch_count==1000,"legacy checkpoint contains one thousand permanent observers")
        for _,joint in pairs(s.joints) do if joint.helper then helper_ids[joint.helper.unit_number]=true end end
        settings.global["ei-factory-passage-update-budget"]={value=1}
        settings.global["ei-factory-passage-circuit-scan-budget"]={value=1}
        settings.global["ei-factory-passage-circuit-scanner-enabled"]={value=true}
    end
    local before_main=s.counters.processed;local before_circuit=s.counters.circuit_attempts or 0
    local before_topology=s.counters.topology;local before_created=s.counters.created;local before_destroyed=s.counters.destroyed
    if passage.has_work(e.tick) then passage.updater(passage.update_budget(),e) end
    check(s==original and s==storage.ei.factory_passage and s.dirty==dirty and s.pending==pending,"adoption preserves owner and reconciliation queues")
    check(s.counters.processed-before_main<=1 and (s.counters.circuit_attempts or 0)-before_circuit<=1,"independent one-plus-one native attempt caps")
    check(s.counters.topology==before_topology and s.counters.created==before_created and s.counters.destroyed==before_destroyed,"classification and unchanged scans cause no topology work or churn")
    if e.tick-started==1200 then
        check(s.version==3 and s.legacy_watch_count==0 and s.shared_watch_count==0,"native legacy classification completes")
        check(s.watch_count==100 and s.circuit_watch_count==100 and scheduler.deadline_count(s.circuit_deadlines)==100,"only ten-percent native circuit population remains")
        check(serpent.line(s.rebuild)==report,"observer migration does not create or replace rebuild reports")
        local count=0;for _,joint in pairs(s.joints) do if joint.helper then check(helper_ids[joint.helper.unit_number],"native helper identity preserved");count=count+1 end end
        check(count==s.helper_count,"no orphan or missing helper after migration")
        helpers.write_file("factory-passage/observer-legacy.json",helpers.table_to_json{passed=true,engine=script.active_mods.base,
            checks=checks,status=passage.status(),ticks=1201},false)
        started=false
    end
end)
