-- Proposed helper-mod control.lua for a fresh native V2 stress run.
-- Driver setup is finite and excluded from the owner's updater profiler.
local function call(name,...) return remote.call("ei-terrain-v2-stress-qc",name,...) end
local BASELINE_TICKS=16000
local EXERCISE_TICKS=40000 -- >two complete full-registry inspection rotations.
local function write(result) helpers.write_file("terrain-qc.json",helpers.table_to_json(result),false) end
script.on_init(function() storage.v2_stress={phase="begin",cursor=0} end)
script.on_event(defines.events.on_tick,function(event)
    local s=storage.v2_stress;if not s or s.done then return end
    local ok,message=pcall(function()
        local tick=event.tick
        if s.phase=="begin" then call("begin");s.phase="planets";s.cursor=1
        elseif s.phase=="planets" then
            call("prepare_planet",s.cursor);s.cursor=s.cursor+1
            if s.cursor>6 then s.phase="forest" end
        elseif s.phase=="forest" then if call("seed_trees",128) then s.phase="working" end
        elseif s.phase=="working" then call("seed_working");s.phase="idle"
        elseif s.phase=="idle" then if call("seed_idle",128) then s.phase="chunks10";s.cursor=0 end
        elseif s.phase=="chunks10" then
            call("chunks",s.cursor,1000);s.cursor=s.cursor+1000
            if s.cursor==10000 then call("seed_active");call("resume_setup");s.ready_at=tick+600;s.phase="warmup" end
        elseif s.phase=="warmup" then
            if tick>=s.ready_at then
                call("freeze");s.phase="refill10"
            end
        elseif s.phase=="refill10" then
            if call("seed_trees",128) then
                call("maintenance");call("start","v2_ten_thousand_default");s.until_tick=tick+BASELINE_TICKS;s.phase="profile10"
            end
        elseif s.phase=="profile10" then
            if tick>=s.until_tick then call("stop");call("freeze");s.phase="chunks100";s.cursor=10000 end
        elseif s.phase=="chunks100" then
            call("chunks",s.cursor,1000);s.cursor=s.cursor+1000
            if s.cursor==100000 then s.phase="refill100" end
        elseif s.phase=="refill100" then
            if call("seed_trees",128) then
                call("maintenance");call("start","v2_hundred_thousand_default");s.until_tick=tick+BASELINE_TICKS;s.phase="profile100"
            end
        elseif s.phase=="profile100" then
            if tick>=s.until_tick then call("stop");call("freeze");s.phase="refill_exercise" end
        elseif s.phase=="refill_exercise" then
            if call("seed_trees",128) then call("exercise_setup");s.phase="burst" end
        elseif s.phase=="burst" then
            if call("burst_step") then
                call("maintenance");s.ready_until=tick+300;s.ready_at=tick+2;s.phase="exercise_ready"
            end
        elseif s.phase=="exercise_ready" then
            if tick>=s.ready_at then
                local status=call("working_status");s.ready_at=tick+10
                if status.count==8 then
                    call("start","v2_full_history_due_burst");s.until_tick=tick+EXERCISE_TICKS;s.phase="exercise"
                elseif tick>=s.ready_until then error("Native quarry readiness timeout: "..helpers.table_to_json(status)) end
            end
        elseif s.phase=="exercise" then
            if tick>=s.until_tick then call("stop");s.done=true;write(call("summary")) end
        else error("Unknown V2 stress phase: "..tostring(s.phase)) end
        if not s.done and s.phase~="begin" and tick%600==0 then call("maintenance") end
    end)
    if not ok then
        s.done=true
        local reported,report=pcall(call,"summary")
        if not reported then report={count=0,cases={}} end
        report.all_pass=false;report.count=report.count+1;report.phase=s.phase;report.tick=event.tick
        report.cases.fixture_exception={pass=false,detail=tostring(message)};write(report)
    end
end)
