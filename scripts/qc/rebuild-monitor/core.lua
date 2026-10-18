local model={}
function model.run(scheduler,tick)
    local checks={}
    local function check(name,ok) checks[#checks+1]={name=name,ok=not not ok};assert(ok,name) end
    local previous=storage.ei;storage.ei={}
    local empty=scheduler.peek_rebuilds(0)
    check("pure absent snapshot",#empty.active==0 and storage.ei.runtime_scheduler==nil)
    local a=scheduler.begin_rebuild("alpha","rebuild","world",{phase="scan",completed=0,total=100},0)
    check("tick zero retained",scheduler.peek_rebuilds(0).active[1].start_tick==0)
    scheduler.update_rebuild(a,{completed=10},60)
    local sample=scheduler.peek_rebuilds(60)
    check("rate ETA",sample.active[1].eta_ticks==540)
    sample.active[1].completed=999
    check("snapshot detached",scheduler.peek_rebuilds(60).active[1].completed==10)
    scheduler.update_rebuild(a,{eta_blocked=true},61)
    check("partial blocker withholds ETA",scheduler.peek_rebuilds(61).active[1].eta_ticks==nil)
    scheduler.update_rebuild(a,{state="waiting",waiting_reason="power"},62)
    check("waiting excluded publicly",scheduler.peek_rebuilds(62).public_count==0)
    local episode=scheduler.peek_rebuilds(62).episode
    scheduler.update_rebuild(a,{state="running",eta_blocked=false,waiting_reason=false},70)
    check("resumption episode",scheduler.peek_rebuilds(70).episode==episode+1)
    check("resumption resets rate",scheduler.peek_rebuilds(70).active[1].eta_ticks==nil)
    scheduler.update_rebuild(a,{total=false},130)
    check("unknown total cleared",scheduler.peek_rebuilds(130).active[1].total==nil)
    scheduler.update_rebuild(a,{total=200,completed=20},190)
    check("scope change resets rate",scheduler.peek_rebuilds(190).active[1].eta_ticks==nil)
    scheduler.update_rebuild(a,{completed=30},250)
    check("new scope rate",scheduler.peek_rebuilds(250).active[1].eta_ticks==1020)
    check("stale rate withdrawn",scheduler.peek_rebuilds(550).active[1].eta_ticks==nil)
    local b=scheduler.begin_rebuild("beta","rebuild","world",{total=2},251)
    check("simultaneous owners",#scheduler.peek_rebuilds(251).active==2)
    check("owner filtering",#scheduler.peek_rebuilds(251,"beta").active==1)
    scheduler.finish_rebuild(b,"completed",252)
    local before=scheduler.peek_rebuilds(253).episode
    scheduler.finish_rebuild(a,"superseded",253)
    local replacement=scheduler.begin_rebuild("alpha","rebuild","world",{total=7},253)
    check("atomic supersession preserves episode",scheduler.peek_rebuilds(253).episode==before)
    check("stale update rejected",not scheduler.update_rebuild(a,{completed=8},254))
    check("stale finish rejected",not scheduler.finish_rebuild(a,"completed",254))
    scheduler.report_rebuild("alpha","rebuild","world",a,{phase="scan",completed=90,total=100},254)
    local stale_snapshot=scheduler.peek_rebuilds(254)
    check("stale convenience publisher cannot replace new generation",#stale_snapshot.active==1 and stale_snapshot.active[1].id==replacement)
    scheduler.finish_rebuild(replacement,"completed",254)
    check("terminal counts",scheduler.peek_rebuilds(254).history[1].completed==7)
    for i=1,40 do
        local id=scheduler.begin_rebuild("history","repair",i,{synchronous=true,total=1},300+i)
        scheduler.finish_rebuild(id,i==40 and "failed" or "completed",300+i)
    end
    local history=scheduler.peek_rebuilds(400)
    check("bounded recent history",#history.history==32 and history.history[1].outcome=="failed")
    check("synchronous repairs never public",history.public_count==0)
    check("all jobs retired",#history.active==0)
    local saved=helpers.table_to_json(history)
    check("snapshot serializable",#saved>0)
    storage.ei=previous
    return checks
end
return model
