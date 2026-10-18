-- Staging-only Factorio 2.0.77 fixture. Never imported by the shipping pack.
do
    local model = require("scripts/control/vulcanus-fumaroles")
    local scheduler = require("lib/runtime-scheduler")
    -- The fixture also runs before the separate rebuild-monitor feature ships.
    local monitor_available = type(scheduler.peek_rebuilds) == "function"
    local qc = assert(model.qc)
    local loaded, configured = false, false
    local function check(name, ok)
        assert(ok, "AURIC_QC: " .. name)
        local checks = storage.auric_rebuild_qc.checks
        checks[#checks + 1] = name
    end
    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, entry in pairs(value) do result[key] = copy(entry) end
        return result
    end
    local function equal(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end
    local function difference(a, b, path)
        if type(a)~=type(b) then return path .. " types " .. type(a) .. "/" .. type(b) end
        if type(a)~="table" then
            if a~=b then return path .. " values " .. tostring(a) .. "/" .. tostring(b) end
            return
        end
        for key, value in pairs(a) do
            local found = difference(value,b[key],path .. "." .. tostring(key))
            if found then return found end
        end
        for key in pairs(b) do if a[key]==nil then return path .. " extra " .. tostring(key) end end
    end
    local function state() return storage.ei.vulcanus_fumaroles end
    local function snapshot()
        local s = state()
        local active = {}
        local reports = {}
        if monitor_available then
            for _, record in ipairs(scheduler.peek_rebuilds(game.tick,"vulcanus-fumaroles").active) do
                reports[#reports+1] = {id=record.id,state=record.state,phase=record.phase,
                    completed=record.completed,total=record.total,reason=record.reason}
            end
        end
        for key, record in pairs(s.active) do
            active[key] = {key=record.key, surface_index=record.surface_index,
                chunk_x=record.chunk_x, chunk_y=record.chunk_y, band_name=record.band_name,
                position=copy(record.position), initial_amount=record.initial_amount,
                touched=record.touched, spawn_tick=record.spawn_tick,
                untouched_deadline_tick=record.untouched_deadline_tick,
                valid=record.entity.valid, amount=record.entity.valid and record.entity.amount}
        end
        return {runtime=s.runtime_version, eligibility=s.eligibility_version,
            pending=s.pending_eligibility_refresh, bootstrapped=s.backfill_bootstrapped,
            queue=copy(s.backfill_queue), active=active, counts=copy(s.active_band_counts),
            dormant=copy(s.dormant_chunks), delayed=copy(s.dormant_delayed_buckets),
            history=copy(s.history_chunks), cooldown=copy(s.cooldown_chunks),
            processed=copy(s.processed_chunks), generated=copy(s.generated_band_counts),
            rebuild_id=s.backfill_rebuild_id, completed=s.backfill_rebuild_completed,
            report=reports}
    end
    local function unchanged(name, action)
        local s = state()
        local before, counters = snapshot(), copy(qc.counters)
        local queue, counts, dormant = s.backfill_queue, s.active_band_counts, s.dormant_chunks
        action()
        check(name .. " values", equal(before, snapshot()))
        check(name .. " identities", queue == s.backfill_queue and counts == s.active_band_counts and dormant == s.dormant_chunks)
        check(name .. " no scans", equal(counters, qc.counters))
    end
    local function write_report(kind)
        helpers.write_file("auric-rebuild-qc.json", helpers.table_to_json{
            all_pass=true, version=script.active_mods.base, kind=kind,
            monitor_integration_checked=monitor_available,
            checks=storage.auric_rebuild_qc.checks, counters=qc.counters,
            pending_backfill=scheduler.queue_length(state().backfill_queue)}, false)
        log("AURIC_QC ALL_COMPLETE " .. kind)
    end
    script.on_load(function()
        if __control_ups_load then __control_ups_load() end
        loaded = storage.auric_rebuild_qc and storage.auric_rebuild_qc.saved or false
    end)
    local old_config = assert(__control_ups_config)
    script.on_configuration_changed(function(event)
        if storage.auric_rebuild_qc and storage.auric_rebuild_qc.saved then
            unchanged("native configuration callback", function() old_config(event) end)
            check("native unrelated helper change", event.mod_changes["zzz-control-ups-lifecycle-qc"] ~= nil)
        else
            old_config(event)
        end
        configured = true
    end)
    local function map_controls_tests(surface, tick)
        local original_settings = surface.map_gen_settings
        local original_state = state()
        local prototype = prototypes.autoplace_control["ei-auric-fumarole"]
        check("native resource control with richness and checkbox", prototype and prototype.category=="resource" and prototype.richness and prototype.can_be_disabled)
        local initial = original_settings.autoplace_controls["ei-auric-fumarole"]
        check("Vulcanus creates surface with default control", initial and initial.frequency==1 and initial.size==1 and initial.richness==1)
        local function settings(frequency, size, richness)
            local map = surface.map_gen_settings
            map.autoplace_controls["ei-auric-fumarole"] = {frequency=frequency,size=size,richness=richness}
            surface.map_gen_settings = map
            return qc.controls(surface)
        end
        local function fresh()
            local s = qc.new_state()
            s.backfill_bootstrapped = true
            s.generated_band_counts[surface.index] = {["32+"]=10000}
            storage.ei.vulcanus_fumaroles = s
            return s
        end
        local mock = {valid=true,name="vulcanus",index=surface.index,map_gen_settings={}}
        local missing = qc.controls(mock)
        check("old-save missing control defaults", missing.enabled and missing.frequency==1 and missing.size==1 and missing.richness==1)
        mock.map_gen_settings.autoplace_controls = {["ei-auric-fumarole"]={size=0.5}}
        missing = qc.controls(mock)
        check("missing individual dimensions default", missing.frequency==1 and missing.size==0.5 and missing.richness==1)
        mock.map_gen_settings.autoplace_controls["ei-auric-fumarole"]={frequency=99,size=99,richness=99}
        local bounded = qc.controls(mock)
        check("scripted oversized values bounded", bounded.frequency==6 and bounded.size==6 and bounded.richness==6)

        local seed = surface.map_gen_settings.seed
        local base_controls = settings(1,1,1)
        local base_amount = qc.amount(surface,40,0,base_controls)
        check("new default reserve range", base_amount>=40000 and base_amount<=80000)
        local previous_hits = -1
        for _, multiplier in ipairs({0,1/6,0.5,1,2,6}) do
            local c = settings(multiplier,1,1)
            check("native frequency round trip "..multiplier, math.abs(c.frequency-multiplier)<0.000001)
            local hits, parity = 0, true
            for x=32,4127 do
                local actual = qc.immediate(surface,x,0,1,c)
                if actual then hits=hits+1 end
                if multiplier==1 and actual~=(qc.hash(seed,x,0,101)<0.025) then parity=false end
            end
            check("initial frequency monotonic "..multiplier, hits>=previous_hits and (multiplier~=0 or hits==0))
            check("default initial roll parity "..multiplier, parity)
            previous_hits = hits
            local totals = {[2]=0,[4]=0,[6]=0}
            for pulse=0,35 do
                for base in pairs(totals) do
                    local budget = qc.budget(base,pulse*1800,c)
                    totals[base]=totals[base]+budget
                    check("bounded budget "..multiplier.."/"..base.."/"..pulse, budget>=0 and budget<=base*6 and (multiplier~=1 or budget==base))
                end
            end
            for base,total in pairs(totals) do
                check("fractional budget total "..multiplier.."/"..base, math.abs(total-36*base*multiplier)<=1)
            end
            local s=fresh()
            c=settings(1,multiplier,1)
            check("population scaling "..multiplier, qc.target(s,surface.index,"32+",c)==math.ceil(100*multiplier))
            check("keepalive scaling "..multiplier, qc.floor(s,c)==math.ceil(2*multiplier))
            c=settings(1,1,multiplier)
            if multiplier>0 then
                local amount=qc.amount(surface,40,0,c)
                check("reserve scaling "..multiplier, amount==math.floor(base_amount*c.richness+0.5))
            else
                check("zero richness disables", not c.enabled)
            end
        end
        local s=fresh()
        s.generated_band_counts[surface.index]["32+"]=1
        check("keepalive capped by eligible target", qc.floor(s,settings(1,6,1))==1)

        -- Exercise production recovery/keepalive loops with observed placement calls;
        -- keep the many synthetic candidates out of the real generated world.
        local candidate_calls, spawn_calls = 0, 0
        qc.set_candidate(function() candidate_calls=candidate_calls+1; return {position={x=336,y=16}} end)
        qc.set_spawn(function() spawn_calls=spawn_calls+1; return false,"blocked" end)
        local function ready_candidates(c)
            local next_state=fresh()
            for x=40,79 do
                local key=qc.key(surface.index,x,0)
                next_state.dormant_chunks[key]={surface_index=surface.index,chunk_x=x,chunk_y=0,band_name="32+",due_tick=0}
                qc.ready(next_state,surface.index,key,"32+")
            end
            next_state.below_floor_since_tick=0
            return next_state
        end
        for _, frequency in ipairs({0,1/6,0.5,1,2,6}) do
            local c=settings(frequency,6,1)
            s=ready_candidates(c); spawn_calls=0
            qc.recovery(s,18000,c)
            check("recovery actual attempt count "..frequency, spawn_calls==qc.budget(6,18000,c))
            s=ready_candidates(c); spawn_calls=0
            qc.keepalive(s,18000,c)
            check("keepalive actual bounded attempts "..frequency, spawn_calls==qc.budget(2,18000,c)*8)
        end
        -- Find a deterministic dormant roll accepted at 100% but rejected at 50%.
        local chosen_tick
        for pulse=0,10000 do
            local roll=qc.hash(seed,40,0,2401+pulse)
            if roll>=0.00375 and roll<0.0075 then chosen_tick=pulse*1800; break end
        end
        check("dormant comparison sample exists", chosen_tick~=nil)
        for _, frequency in ipairs({0.5,1,2,6}) do
            local c=settings(frequency,1,1)
            s=ready_candidates(c); spawn_calls=0
            qc.one_dormant(s,qc.key(surface.index,40,0),chosen_tick,c)
            check("ordinary dormant frequency "..frequency, spawn_calls==(frequency==0.5 and 0 or 1))
        end
        qc.set_spawn(qc.spawn)
        for _, dimension in ipairs({"frequency","size","richness"}) do
            local values={frequency=1,size=1,richness=1}; values[dimension]=0
            local c=settings(values.frequency,values.size,values.richness)
            s=ready_candidates(c); candidate_calls=0
            local key=qc.key(surface.index,40,0)
            local before=copy(s.dormant_chunks)
            qc.pulse(18000,c); qc.recovery(s,18000,c); qc.keepalive(s,18000,c)
            qc.one_dormant(s,key,18000,c)
            local ok,reason=qc.spawn(surface,40,0,"recovery",18000,nil,c)
            qc.dormant(s,surface,100,0,54000,404,tick,c)
            check("disabled all paths "..dimension, not ok and reason=="disabled" and candidate_calls==0 and equal(before,s.dormant_chunks))
            qc.initial(surface,{x=16,y=3},"chunk-generated",tick,c)
            check("disabled new chunks admit no dormant work "..dimension, s.dormant_chunks[qc.key(surface.index,16,3)]==nil)
        end
        qc.set_candidate(qc.select_candidate)
        -- Actual resource creation verifies amount assignment, not just arithmetic.
        local position={x=336,y=80}
        for _, entity in pairs(surface.find_entities_filtered{area={{332,76},{340,84}}}) do
            if entity.type~="character" then entity.destroy() end
        end
        local tiles={}
        for x=332,340 do for y=76,84 do tiles[#tiles+1]={name="volcanic-smooth-stone",position={x,y}} end end
        surface.set_tiles(tiles)
        for _, richness in ipairs({0.5,1,2,6}) do
            s=fresh(); local c=settings(1,1,richness)
            local ok=qc.spawn(surface,10,2,"chunk-generated",tick,{position=position},c)
            local record=s.active[qc.key(surface.index,10,2)]
            check("native spawn reserve "..richness, ok and record and record.entity.amount==qc.amount(surface,10,2,c))
            record.entity.destroy()
        end
        surface.map_gen_settings=original_settings
        storage.ei.vulcanus_fumaroles=original_state
    end
    local function prepare(tick)
        storage.auric_rebuild_qc = {checks={}, start=tick}
        local surface = assert(game.surfaces.vulcanus)
        map_controls_tests(surface,tick)
        for _, entity in pairs(surface.find_entities_filtered{name="ei-auric-fumarole"}) do entity.destroy() end
        local fresh = qc.new_state()
        fresh.backfill_bootstrapped = true
        storage.ei.vulcanus_fumaroles = fresh
        local s = state()
        local function deposit(chunk_x)
            local position = {x=chunk_x*32+16, y=16}
            local tiles = {}
            for x=-2,2 do for y=-2,2 do tiles[#tiles+1]={name="volcanic-smooth-stone",position={position.x+x,position.y+y}} end end
            surface.set_tiles(tiles)
            return assert(surface.create_entity{name="ei-auric-fumarole",position=position,amount=5000})
        end
        local first = qc.register(s,surface,10,0,deposit(10),5000,tick)
        local second = qc.register(s,surface,12,0,deposit(12),5000,tick)
        first.touched = true
        first.entity.amount = 4321
        first.untouched_deadline_tick = tick+1000000
        local function count() return state().active_band_counts[surface.index]["6-16"] end
        check("registration increments twice", count()==2)
        local stranger = deposit(14)
        model.on_resource_depleted{entity=stranger,tick=tick}
        check("untracked depletion preserves count", count()==2)
        check("untracked depletion retains cooldown", s.cooldown_chunks[qc.key(surface.index,14,0)]~=nil)
        qc.close(s,second,"depleted",tick)
        check("tracked depletion decrements once", count()==1)
        qc.close(s,second,"depleted",tick)
        check("repeated stale closure cannot decrement", count()==1)
        local expiring = qc.register(s,surface,12,0,deposit(12),5000,tick)
        expiring.untouched_deadline_tick = tick
        qc.audit(tick)
        check("untouched expiry decrements once", count()==1 and not expiring.entity.valid)
        local prior = snapshot().active[first.key]
        check("adopts existing native resource", qc.adopt(s,surface,10,0,tick))
        check("repeated adoption preserves active metadata", count()==1 and equal(prior,snapshot().active[first.key]))
        qc.dormant(s,surface,11,1,54000,404,tick)
        s.history_chunks[qc.key(surface.index,11,1)] = true
        model.repair_runtime_state("auric-qc",tick)
        local queued = scheduler.queue_length(s.backfill_queue)
        qc.process(tick)
        check("fixture has partially consumed backfill", scheduler.queue_length(s.backfill_queue)>4 and scheduler.queue_length(s.backfill_queue)==queued-4)
        if monitor_available then check("monitor records partial backfill", s.backfill_rebuild_completed==4) end
        for name, changes in pairs({empty={},unrelated={example={old_version="1.0.0",new_version="1.0.1"}},
            esir={["exotic-space-industries-remembrance"]={old_version="1.3.41",new_version="1.3.42"}}}) do
            unchanged(name .. " configuration",function() model.on_configuration_changed{mod_changes=changes} end)
        end
        unchanged("repeated sanity and status",function()
            for _=1,20 do model.check_global(); model.get_runtime_status() end
        end)
        local before_recounts = qc.counters.recounts
        s.active_band_counts = nil
        model.check_global()
        check("missing count root reconstructed once", count()==1 and qc.counters.recounts==before_recounts+1)
        unchanged("repaired count root remains stable",model.check_global)
        for _, version in ipairs({"runtime_version","eligibility_version"}) do
            local old_id, admissions, recounts = s.backfill_rebuild_id,qc.counters.admissions,qc.counters.recounts
            local dormant, history, cooldown = s.dormant_chunks,s.history_chunks,s.cooldown_chunks
            s[version] = s[version]-1
            first.band_name = "stale-band"
            model.on_configuration_changed{mod_changes={}}
            check(version .. " admits one refresh", qc.counters.admissions==admissions+1 and qc.counters.recounts==recounts+1)
            if monitor_available then check(version .. " replaces monitor generation", s.backfill_rebuild_id~=old_id) end
            check(version .. " preserves active and history", count()==1 and first.band_name=="6-16" and s.history_chunks==history and s.cooldown_chunks==cooldown and first.entity.amount==4321)
            check(version .. " dormant policy", (version=="runtime_version" and s.dormant_chunks==dormant) or (version=="eligibility_version" and s.dormant_chunks~=dormant))
            unchanged(version .. " repeat",function() model.on_configuration_changed{mod_changes={example={}}} end)
        end
        surface.name = "auric-qc-away"
        s.runtime_version = s.runtime_version-1
        local admissions = qc.counters.admissions
        model.on_configuration_changed{mod_changes={}}
        check("absent Vulcanus defers refresh", s.pending_eligibility_refresh and qc.counters.admissions==admissions and s.next_surface_probe_tick>tick)
        surface.name = "vulcanus"
        model.updater{tick=s.next_surface_probe_tick}
        check("returning Vulcanus admits pending refresh once", not s.pending_eligibility_refresh and qc.counters.admissions==admissions+1)
        -- The absent-surface migration intentionally omitted its active records;
        -- explicit repair re-establishes their derived counts after the rename.
        s.active_band_counts[surface.index] = {["6-16"]=99}
        model.repair_runtime_state("auric-qc",tick)
        check("explicit admin repair fixes corrupt counts", count()==1)
        s.active_band_counts[surface.index]["6-16"] = 99
        qc.command{tick=tick}
        check("explicit console rescan fixes corrupt counts", count()==1)
        qc.process(tick)
        qc.dormant(s,surface,11,1,54000,404,tick)
        storage.auric_rebuild_qc.first = first.entity
        local map=surface.map_gen_settings
        map.autoplace_controls["ei-auric-fumarole"]={frequency=0.5,size=2,richness=2}
        surface.map_gen_settings=map
        storage.auric_rebuild_qc.map_controls=qc.controls(surface)
        storage.auric_rebuild_qc.snapshot = snapshot()
        storage.auric_rebuild_qc.saved = true
        storage.auric_rebuild_qc.save_tick = tick
        write_report("save")
        game.server_save("auric-pending")
    end
    local previous_chunk = script.get_event_handler(defines.events.on_chunk_generated)
    script.on_event(defines.events.on_chunk_generated,function(event)
        previous_chunk(event)
        local fixture = storage.auric_rebuild_qc
        if fixture and fixture.generating then fixture.last_chunk_tick = event.tick end
    end)
    local previous = script.get_event_handler(defines.events.on_tick)
    script.on_event(defines.events.on_tick,function(event)
        local fixture = storage.auric_rebuild_qc
        if not fixture then
            previous(event)
            storage.auric_rebuild_qc = {generating=true,start=event.tick,last_chunk_tick=event.tick}
            local surface = game.surfaces.vulcanus or game.planets.vulcanus.create_surface()
            surface.request_to_generate_chunks({352,16},4)
            surface.force_generate_chunk_requests()
            return
        end
        if fixture.generating then
            -- force_generate_chunk_requests can leave chunk callbacks deferred
            -- until after on_tick. Settle them before replacing module state.
            if event.tick-fixture.start>=10 and event.tick-fixture.last_chunk_tick>=2 then prepare(event.tick) end
            return
        end
        if not loaded then return end -- Keep the saved fixture stable until the server exits.
        if not fixture.reload_observed then
            local mismatch = difference(fixture.snapshot,snapshot(),"state")
            check("native reload before first service" .. (mismatch and ": " .. mismatch or ""), not mismatch)
            check("native entity reference survived", fixture.first.valid and fixture.first.amount==4321)
            check("selected map controls survive native reload", equal(fixture.map_controls,qc.controls(game.surfaces.vulcanus)))
            fixture.reload_observed = true
            fixture.initial_remaining = scheduler.queue_length(state().backfill_queue)
            fixture.saved_id = state().backfill_rebuild_id
            unchanged("reload sanity and status",function() model.check_global();model.get_runtime_status() end)
        end
        previous(event)
        local drain_deadline = fixture.save_tick+math.ceil(fixture.initial_remaining/4)*30+30
        if event.tick >= drain_deadline and not fixture.done then
            fixture.done = true
            check("production bounded backfill drained (initial " .. fixture.initial_remaining .. ")", scheduler.queue_length(state().backfill_queue)==0 and state().backfill_rebuild_id==nil)
            if monitor_available then
                local completed
                for _, record in ipairs(scheduler.peek_rebuilds(event.tick,"vulcanus-fumaroles").history) do
                    if record.id==fixture.saved_id then completed=record end
                end
                check("same monitor generation completed", completed and completed.outcome=="completed" and completed.completed==completed.total)
            end
            check("reload did not recount or enumerate", qc.counters.recounts==0 and qc.counters.admissions==0 and qc.counters.generated_scans==0)
            write_report(configured and "configuration-reload" or "ordinary-reload")
        end
    end)
end
