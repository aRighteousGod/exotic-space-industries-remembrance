script.on_event(defines.events.on_tick,function(event)
    if storage.v2_done then return end
    storage.v2_start=storage.v2_start or event.tick;storage.v2_phase=storage.v2_phase or 0
    if event.tick<storage.v2_start+60+storage.v2_phase*180 then return end
    local ok,result=pcall(remote.call,"ei-terrain-v2-qc","step",storage.v2_phase,event.tick)
    storage.v2_cases=storage.v2_cases or {}
    if ok then for name,value in pairs(result) do storage.v2_cases[name]=value end
    else storage.v2_cases.exception={pass=false,detail=tostring(result)} end
    storage.v2_phase=storage.v2_phase+1;storage.v2_done=not ok or storage.v2_phase>3
    local count,pass=0,true;for _,r in pairs(storage.v2_cases) do count=count+1;pass=pass and r.pass end
    helpers.write_file("terrain-qc.json",helpers.table_to_json{count=count,all_pass=pass and storage.v2_done,cases=storage.v2_cases,complete=storage.v2_done},false)
end)
