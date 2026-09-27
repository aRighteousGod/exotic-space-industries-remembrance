-- Injected before return model in the staged runtime module only.
local qc_timers
local qc_desired=desired
desired=function(entity)
    if not qc_timers then return qc_desired(entity) end
    local timer=game.create_profiler()
    local result=qc_desired(entity)
    timer.stop();qc_timers.checks.add(timer)
    return result
end
local qc_replace=replace
replace=function(record,target)
    if not qc_timers then return qc_replace(record,target) end
    local timer=game.create_profiler()
    local ok,reason=qc_replace(record,target)
    timer.stop();qc_timers.replacements.add(timer)
    return ok,reason
end
local qc_updater=model.updater
model.updater=function(event,service_interval)
    if not qc_timers then return qc_updater(event,service_interval) end
    local timer=game.create_profiler()
    qc_updater(event,service_interval)
    timer.stop();qc_timers.total.add(timer)
end
model.qc_profile=function(action)
    if action=="start" then
        qc_timers={checks=game.create_profiler(true),replacements=game.create_profiler(true),total=game.create_profiler(true)}
    else
        for name,timer in pairs(qc_timers or {}) do helpers.write_file("flame-"..action.."-"..name..".txt",{"",timer},false) end
    end
end
