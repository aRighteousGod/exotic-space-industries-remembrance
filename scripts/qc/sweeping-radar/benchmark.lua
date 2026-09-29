local config=require("test-config")
local defaults=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local current_tick
local function call(name,...) return remote.call("esir_radar_qc",name,current_tick,...) end
local workloads={"idle","warm","exploration","dense","churn","completion"}
local populations={1,10,50,100}
local warmup,measure=600,config.measure_ticks or 2400
local phases={}
for _,population in ipairs(populations) do for _,workload in ipairs(workloads) do
    phases[#phases+1]={population=population,workload=workload}
end end
if config.single then phases={{population=config.population,workload=config.workload}} end
local function stats(values)
    table.sort(values)
    local sum=0
    for _,value in ipairs(values) do sum=sum+value end
    return {mean=#values>0 and sum/#values or 0,p95=values[math.max(1,math.ceil(#values*0.95))] or 0,
        maximum=values[#values] or 0,samples=#values}
end
local function setup_phase(index,tick)
    if storage.surface then game.delete_surface(storage.surface) end
    local spec=phases[index]
    local surface=game.create_surface("radar-benchmark-"..index,{autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
    storage.surface=surface;storage.radars={};storage.phase=index;storage.start=tick
    local force=game.forces["radar-benchmark"] or game.create_force("radar-benchmark")
    for _,player in pairs(game.players) do player.force=force end
    force.research_all_technologies()
    if spec.workload~="exploration" then surface.request_to_generate_chunks({0,0},12);surface.force_generate_chunk_requests() end
    for i=1,spec.population do
        local x=((i-1)%10)*6+16;local y=math.floor((i-1)/10)*6+16
        if spec.workload=="exploration" then x=x+index*2000 end
        if config.spread then x=x+i*1024 end
        local radar=surface.create_entity{name=i%2==0 and "ei-sweeping-radar" or "ei-phased-array-radar",position={x,y},force=force,raise_built=true}
        storage.radars[i]=radar
        local settings=defaults.defaults()
        settings.modes[1].radius=spec.workload=="completion" and 1 or 4
        settings.contacts=spec.workload=="completion" and 2 or 1
        if spec.workload=="idle" then settings.run=0 end
        call("settings",radar,settings)
        surface.create_entity{name="ei-radar-qc-source",position={x,y+2},force=force}
        surface.create_entity{name="substation",position={x+2,y},force=force}
    end
    if spec.workload=="dense" then
        for cx=-3,4 do for cy=-3,4 do for i=1,129 do
            local target=surface.create_entity{name="gun-turret",position={cx*32+16,cy*32+16},force="enemy"}
            target.active=false
        end end end
    end
    storage.samples={};storage.job_samples={};storage.generation_queue_samples={};storage.wait_max=0;storage.ready_wait_max=0;storage.age_samples={};storage.sample_ages={};storage.throttled=0;storage.unavailable=0
    storage.maximum={};storage.last_generation_tick=nil;storage.last_generated=call("snapshot").counters.generated
    storage.observations_before=0;storage.total_samples=0
end
script.on_init(function() storage.pending=true;storage.results={} end)
script.on_event(defines.events.on_tick,function(event)
    current_tick=event.tick
    if storage.pending then storage.pending=nil;setup_phase(1,event.tick);return end
    if storage.done then return end
    local t=event.tick-storage.start
    local spec=phases[storage.phase]
    if spec.workload=="churn" and t%5==0 then
        local i=(math.floor(t/5)%#storage.radars)+1
        local settings=defaults.defaults();settings.mode=2;settings.modes[2].radius=4
        settings.modes[2].start=t%360;settings.modes[2].stop=(t+90)%360
        call("settings",storage.radars[i],settings)
    end
    local data=call("metrics")
    if data.counters.generated>storage.last_generated then
        assert(data.counters.generated-storage.last_generated==1,"Multiple generation submissions in one tick")
        assert(not storage.last_generation_tick or event.tick-storage.last_generation_tick>=defaults.budget.generation_interval,
            "Generation submission interval exceeded")
        storage.last_generation_tick=event.tick;storage.last_generated=data.counters.generated
    end
    if t==warmup then
        storage.observations_before=data.counters.observations
        storage.radar_before={}
        for _,radar in ipairs(data.radars) do storage.radar_before[radar.id]=radar.observations end
        storage.sample_start=event.tick
    end
    if t>warmup then
        storage.total_samples=storage.total_samples+1
        storage.job_samples[#storage.job_samples+1]=data.jobs
        storage.generation_queue_samples[#storage.generation_queue_samples+1]=data.generation_waiters
        assert(data.jobs<=32)
        assert(data.generation_waiters<=spec.population)
        for key,value in pairs(data.last) do storage.maximum[key]=math.max(storage.maximum[key] or 0,value) end
        for key,limit in pairs{control=4,geometry=64,chart=2,query=2,snapshot=258,aggregate=64,maintenance=64,publish=2,generation=1} do
            assert((data.last[key] or 0)<=limit,"stage exceeded: "..key)
        end
        for stage,value in pairs(data.profiles) do
            local list=storage.samples[stage] or {};storage.samples[stage]=list
            list[#list+1]=tonumber(value:match("[%d%.]+")) or 0
        end
        local total=0
        for _,value in pairs(data.profiles) do total=total+(tonumber(value:match("[%d%.]+")) or 0) end
        storage.samples.total=storage.samples.total or {};table.insert(storage.samples.total,total)
        if t%30==0 then
            for _,radar in ipairs(data.radars) do
                storage.wait_max=math.max(storage.wait_max,radar.wait)
                storage.ready_wait_max=math.max(storage.ready_wait_max,radar.ready_wait)
                if radar.report_valid then
                    storage.age_samples[#storage.age_samples+1]=radar.age
                    storage.sample_ages[#storage.sample_ages+1]=radar.sample_age
                else storage.unavailable=storage.unavailable+1 end
                if radar.status=="capacity" or radar.status=="generation" or radar.status=="maintenance" then storage.throttled=storage.throttled+1 end
            end
        end
    end
    if t==warmup+measure then
        local stages={};for key,values in pairs(storage.samples) do stages[key]=stats(values) end
        local passes={};local observations={};local deltas={}
        for _,radar in ipairs(data.radars) do
            if radar.pass_ticks>0 then passes[#passes+1]=radar.pass_ticks/60 end
            observations[#observations+1]=radar.observations
            local delta=radar.observations-(storage.radar_before[radar.id] or 0)
            deltas[#deltas+1]=delta
            if not config.baseline and spec.workload~="idle" and spec.workload~="churn" then
                assert(delta>0,"No measurement-window progress for ready radar "..radar.id.." in "..spec.workload.." fleet "..spec.population)
            end
        end
        storage.results[#storage.results+1]={population=spec.population,workload=spec.workload,
            start_tick=storage.sample_start,end_tick=event.tick,stages=stages,
            observations_per_second=(data.counters.observations-storage.observations_before)/(measure/60),
            passes=stats(passes),queue=stats(storage.job_samples),maximum_wait_seconds=storage.wait_max/60,
            generation_queue=stats(storage.generation_queue_samples),
            maximum_ready_gap_seconds=storage.ready_wait_max/60,
            report_age=stats(storage.age_samples),sample_age=stats(storage.sample_ages),unavailable_samples=storage.unavailable,
            throttled_samples=storage.throttled,maximum=storage.maximum,
            per_radar_observations=observations,measurement_observations=deltas,force_players=#game.forces["radar-benchmark"].players}
        if storage.phase==#phases then
            storage.done=true
            helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=true,baseline=config.baseline,
                warmup=warmup,measurement=measure,spread=config.spread or false,results=storage.results}),false)
        else setup_phase(storage.phase+1,event.tick) end
    end
end)
