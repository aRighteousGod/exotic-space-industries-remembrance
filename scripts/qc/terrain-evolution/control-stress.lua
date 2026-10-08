local function call(name,...)return remote.call("ei-terrain-stress-qc",name,...)end
script.on_init(function()storage.results={}end)
script.on_event(defines.events.on_tick,function(event)
    local t=event.tick
    if t==1 then storage.setup=call("prepare") end
    if t>=2 and t<=11 then call("chunks",(t-2)*1000,1000) end
    if t==12 then call("fill_active") end
    if t==1000 then call("start","ten_thousand") end
    if t==17000 then storage.results.ten_thousand=call("stop") end
    if t>=17100 and t<17190 then call("chunks",10000+(t-17100)*1000,1000) end
    if (t>=17300 and t<=17500) or (t>=18000 and t%64==0) then call("burst") end
    if t==18000 then call("start","hundred_thousand") end
    if t==33999 then
        storage.results.hundred_thousand=call("stop")
        local pass=true;for _,r in pairs(storage.results)do r.pass=r.caps and r.history_retained==32768;pass=pass and r.pass end
        helpers.write_file("terrain-qc.json",helpers.table_to_json{all_pass=pass,count=2,cases=storage.results,setup=storage.setup},false)
    end
end)
