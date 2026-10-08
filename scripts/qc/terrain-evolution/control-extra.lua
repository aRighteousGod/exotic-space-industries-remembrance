local extra=require("extra-tests")
local options=require("options")
local function check(name,pass,detail)
    local old=storage.results[name]
    storage.results[name]={pass=pass==true and (not old or old.pass),detail=detail}
end
script.on_init(function() storage.results={} end)
script.on_configuration_changed(function() storage.results={} end)
script.on_event(defines.events.on_resource_depleted,extra.on_resource_depleted)
script.on_event(defines.events.on_tick,function(event)
    extra.on_tick(event,check)
    if event.tick==options.ticks-1 then
        check("scenario-completed",extra.complete())
        local all,count=true,0
        for _,r in pairs(storage.results) do count=count+1;all=all and r.pass end
        helpers.write_file("terrain-qc.json",helpers.table_to_json{all_pass=all,count=count,cases=storage.results},false)
    end
end)
