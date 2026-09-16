-- Injected before the staged module's return, never into the shipped module.
local qc_search_time
local qc_search_targets=search_targets
search_targets=function(record,tick)
    if not qc_search_time then return qc_search_targets(record,tick) end
    local timer=game.create_profiler()
    local result=qc_search_targets(record,tick)
    timer.stop();qc_search_time.add(timer)
    return result
end
model.qc_start_search_profile=function() qc_search_time=game.create_profiler(true) end
model.qc_write_search_profile=function() helpers.write_file("spider-search-profile.txt",{"",qc_search_time},false) end
