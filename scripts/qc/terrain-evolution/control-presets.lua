-- Native dispatcher/cadence lane. Run separately from destructive helper lanes.
-- This checks actual ticks and finite allowances, not wall-clock performance.
local options=require("options")
local cases={"ultra-low","low","lean","balanced","detailed","high-fidelity","ultra-high-fidelity","custom"}
local function check(name,ok,detail)
    local previous=storage.results[name]
    storage.results[name]={pass=ok==true and (not previous or previous.pass),detail=detail}
end
local function report(done)
    local pass,count=true,0
    for _,value in pairs(storage.results) do count=count+1;pass=pass and value.pass end
    helpers.write_file("terrain-qc.json",helpers.table_to_json{all_pass=pass and done,count=count,cases=storage.results,complete=done},false)
end
local function start_case(index,tick)
    storage.index=index
    local name=cases[index]
    if not name then storage.done=true;report(true);return end
    local values=name=="custom" and {interval=11,search_interval=32} or nil
    local state=remote.call("ei-terrain-preset-qc","select",name,values)
    storage.cfg=state.config;storage.pass=state.pass;storage.samples=state.samples
    storage.service_tick=nil;storage.query_tick=nil;storage.lanes={};storage.services=0;storage.grants=0
    storage.deadline=tick+math.max(24*state.config.interval,6*state.config.search_interval)
    check(name..":selected",state.config.performance==name)
end
local function initialize() storage.results={};storage.start=game.tick;storage.index=0;storage.done=false end
script.on_init(initialize)
script.on_configuration_changed(initialize)
script.on_event(defines.events.on_tick,function(event)
    if storage.done then return end
    if storage.index==0 then start_case(1,event.tick);return end
    local name=cases[storage.index]
    local state=remote.call("ei-terrain-preset-qc","inspect")
    if state.pass~=storage.pass then
        local last,cfg=state.last,storage.cfg
        check(name..":one-pass",state.pass==storage.pass+1)
        check(name..":current-tick",last.tick==event.tick)
        if storage.service_tick then check(name..":cadence",event.tick-storage.service_tick==cfg.interval) end
        storage.service_tick=event.tick;storage.services=storage.services+1
        check(name..":total-samples",state.samples-storage.samples<=cfg.cold_chunks+cfg.active_chunks)
        for field,max in pairs({candidates=cfg.candidates,writes=cfg.writes,searches=cfg.searches,
            events=cfg.events,histories=cfg.histories,active_samples=cfg.active_chunks}) do
            check(name..":cap-"..field,last[field]<=max,last[field])
        end
        if last.search_allowance>0 then
            if storage.query_tick then check(name..":search-cadence",event.tick-storage.query_tick>=cfg.search_interval) end
            check(name..":grant-size",last.search_allowance==cfg.searches)
            storage.query_tick=event.tick;storage.grants=storage.grants+1;storage.lanes[last.query_lane]=true
        else check(name..":no-intermediate-search",last.searches==0) end
        storage.pass=state.pass;storage.samples=state.samples
    end
    if event.tick>=storage.deadline then
        check(name..":services-observed",storage.services>=6)
        check(name..":queries-observed",storage.grants>=4)
        check(name..":all-priorities",storage.lanes[0] and storage.lanes[1] and storage.lanes[2])
        start_case(storage.index+1,event.tick)
    end
    if not storage.done and event.tick-storage.start>=options.ticks-2 then
        check("fixture-completed",false,"Increase finite tick window; all presets must finish")
        storage.done=true;report(false)
    end
end)
