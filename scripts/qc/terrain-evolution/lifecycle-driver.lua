-- Appended only to the isolated QC helper's control.lua.
local prior_terrain_qc_tick=script.get_event_handler(defines.events.on_tick)
script.on_event(defines.events.on_tick,function(event)
    prior_terrain_qc_tick(event)
    if event.tick-storage.start==2500 then
        local report=remote.call("ei-terrain-lifecycle-qc","run")
        for name,result in pairs(report.cases) do storage.results["lifecycle-"..name]=result end
        storage.terrain_lifecycle_pending=report.pending==true
    elseif event.tick-storage.start==2502 and storage.terrain_lifecycle_pending then
        local report=remote.call("ei-terrain-lifecycle-qc","finish_clear")
        for name,result in pairs(report.cases) do storage.results["lifecycle-"..name]=result end
        storage.terrain_lifecycle_pending=nil
    end
end)
