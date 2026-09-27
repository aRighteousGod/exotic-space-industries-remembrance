-- Staging-only differential probes. Run in Factorio 2.0.77; host Lua is an
-- additional fast check, never evidence for LuaObject or engine behavior.
return function(before, after)
    local saved = storage.ei
    local checks = 0
    local function copy(value)
        if type(value) ~= "table" then return value end
        local out = {}
        for k,v in pairs(value) do out[k] = copy(v) end
        return out
    end
    local function equal(a,b,path)
        assert(type(a)==type(b), path..": type "..type(a).." / "..type(b))
        if type(a)~="table" then assert(a==b,path..": "..tostring(a).." / "..tostring(b));return end
        for k,v in pairs(a) do equal(v,b[k],path.."."..tostring(k)) end
        for k in pairs(b) do assert(a[k]~=nil,path..": extra "..tostring(k)) end
    end
    local function snapshot()
        local state=copy(storage.ei)
        -- Derived earliest-due metadata has no gameplay payload.
        state.damage_tick_next_due_tick=nil;state.spawner_next_due_tick=nil
        return state
    end
    local function parity(name,seed,action)
        storage.ei=copy(seed)
        local first={action(before)};local state=snapshot()
        storage.ei=copy(seed)
        local second={action(after)}
        equal(first,second,name..".result");equal(state,snapshot(),name..".state")
        checks=checks+1
    end
    local function profile(name,seed,action,iterations)
        for repetition=1,6 do
        local sides=repetition%2==1 and {{"baseline",before},{"candidate",after}} or {{"candidate",after},{"baseline",before}}
        for _,side in ipairs(sides) do
            storage.ei=copy(seed);action(side[2])
            local profiler=game.create_profiler()
            for _=1,iterations do action(side[2]) end
            profiler.stop()
            log({"","CONTROL_UPS PROFILE "..name.." "..side[1].." repetition="..repetition.." calls="..iterations.." elapsed=",profiler})
        end
        end
    end
    local function run()
        local neutron="neutron-collector"
        parity("neutron-new",{},function(m)return copy(m[neutron].check_global())end)
        storage.ei={};after[neutron].check_global();local warm=copy(storage.ei)
        parity("neutron-distinct-wire-buckets",{},function(m)
            local buckets=m[neutron].check_global().wire_output_buckets
            for i=0,59 do for j=i+1,59 do assert(buckets[i]~=buckets[j],"aliased wire buckets") end end
            buckets[0][1]="sentinel";assert(next(buckets[1])==nil,"wire bucket mutation leaked")
        end)
        for key in pairs(warm.neutron_runtime) do
            local seed=copy(warm);seed.neutron_runtime[key]=nil
            parity("neutron-missing-"..key,seed,function(m)return copy(m[neutron].check_global())end)
        end
        for _,key in ipairs({"open_by_player","watchers_by_unit","wire_output_buckets","wire_output_index_by_unit","gui_refresh_buckets"}) do
            local seed=copy(warm);seed.neutron_runtime[key]=false
            parity("neutron-malformed-"..key,seed,function(m)return copy(m[neutron].check_global())end)
        end
        for _,key in ipairs({"prefer_poll_next","runtime_rebuild_in_progress","needs_rebuild","runtime_version"}) do
            for _,value in ipairs({false,true,0,6,7}) do
                local seed=copy(warm);seed.neutron_runtime[key]=value
                parity("neutron-scalar-"..key,seed,function(m)return copy(m[neutron].check_global())end)
            end
        end
        profile("neutron-warm",warm,function(m)m[neutron].check_global()end,10000)

        local tesla="teslas-legacy"
        local jobs={{},{[1]={force_index=1,last_surface_index=5,pending=true,restart_requested=false}},
            {["1"]={force_index="1",last_surface_index="7",pending=1,restart_requested=true},
             [1]={force_index=1,last_surface_index=-5,pending=true,extra=4},bad=false},
            {[2]={last_surface_index="bad"},[3]={force_index="bad"},[4]=true}}
        for i,j in ipairs(jobs) do
            parity("tesla-"..i,{tesla_legacy={variant_sync_jobs=j}},function(m)return copy(m[tesla].qc_ensure())end)
        end
        profile("tesla-empty",{},function(m)m[tesla].qc_ensure()end,100000)

        local emerald="emerald-apocalypse-hover-tank"
        parity("emerald-new",{},function(m)return copy(m[emerald].qc_ensure())end)
        storage.ei={};after[emerald].qc_ensure();local emerald_warm=copy(storage.ei)
        for key in pairs(emerald_warm.emerald_apocalypse_hover_tank.qc.counters) do
            local seed=copy(emerald_warm);seed.emerald_apocalypse_hover_tank.qc.counters[key]=nil
            parity("emerald-missing-"..key,seed,function(m)return copy(m[emerald].qc_ensure())end)
        end
        parity("emerald-schema",{emerald_apocalypse_hover_tank={version=-1,tank_settings_by_unit={}}},function(m)return copy(m[emerald].qc_ensure())end)
        local preserved=copy(emerald_warm)
        preserved.emerald_apocalypse_hover_tank.qc.counters={unknown=17,invalid_purges=false,direct_damage=42}
        parity("emerald-preserved-counters",preserved,function(m)m[emerald].qc_ensure();return copy(m[emerald].qc_ensure())end)
        profile("emerald-warm",emerald_warm,function(m)m[emerald].qc_ensure()end,10000)

        local fumarole="vulcanus-fumaroles"
        local states={{},{backfill_bootstrapped=false,next_surface_probe_tick=13},
            {backfill_bootstrapped=true,pending_eligibility_refresh=true,next_surface_probe_tick=121},
            {backfill_bootstrapped=true},{backfill_bootstrapped=true,backfill_queue={items={1},head=1,tail=1}},
            {backfill_bootstrapped=true,dormant_delayed_buckets={[1800]={1}}},
            {backfill_bootstrapped=true,dormant_chunks={a=true}},
            {backfill_bootstrapped=true,active={a=true}},
            {backfill_bootstrapped=true,breach_fires={a=true}},
            {backfill_bootstrapped=true,active={a=true},dormant_chunks={a=true},breach_fires={a=true}}}
        for i,state in ipairs(states) do
            parity("fumarole-"..i,{vulcanus_fumaroles=state},function(m)
                local trace={};for tick=0,3600 do trace[#trace+1]=m[fumarole].has_tick_work{tick=tick} end;return trace
            end)
        end
        local dormant={};for i=1,256 do dormant[i]={i} end
        profile("fumarole-future",{vulcanus_fumaroles={backfill_bootstrapped=true,dormant_delayed_buckets=dormant}},function(m)m[fumarole].has_tick_work{tick=1}end,10000)

        local orbital="orbital-combinator"
        for _,n in ipairs({0,1,2,3,4,7,8,64}) do
            for _,cursor in ipairs({false,1,2,"2","10","stale"}) do
                for _,advance in ipairs({false,true}) do
                    for _,due in ipairs({false,true}) do
                        local seed={orbital_combinator_banks={},orbital_combinator_bank_count=n,
                            orbital_combinator_connection_audit_break_point=cursor or nil,
                            orbital_combinator_surface_state={},orbital_combinator_surface_bank_index={},
                            orbital_combinator_hot_surface_break_point=cursor or nil,
                            orbital_combinator_cold_surface_break_point=cursor or nil}
                        for i=1,n do
                            local key=i%2==0 and tostring(i) or i
                            seed.orbital_combinator_banks[key]={id=key,last_connection_audit_tick=due and i or 1000,wired=true}
                            seed.orbital_combinator_surface_state[key]={force_index=1,surface_name="s"..i,last_hot_audit_tick=due and i or 1000,last_cold_audit_tick=due and i or 1000}
                            -- Some stale surfaces must be removed during the probe.
                            if i%3~=0 then seed.orbital_combinator_surface_bank_index["1:s"..i]={key} end
                        end
                        parity("orbital-"..n.."-"..tostring(cursor).."-"..tostring(advance).."-"..tostring(due),seed,function(m)
                            local trace={}
                            for tick=0,3600,60 do
                                local bank=m[orbital].qc_bank(tick,advance)
                                trace[#trace+1]={bank=bank and bank.id,state=snapshot()}
                                local hot=m[orbital].qc_surface(tick,"hot",advance)
                                trace[#trace+1]={hot=hot,state=snapshot()}
                                local cold=m[orbital].qc_surface(tick,"cold",advance)
                                trace[#trace+1]={cold=cold,state=snapshot()}
                            end
                            return trace
                        end)
                    end
                end
            end
        end
        for _,count in ipairs({false,0,1,5,8,17}) do
            for _,due_id in ipairs({1,4,8}) do
                local seed={orbital_combinator_bank_count=count or nil,orbital_combinator_banks={}}
                for i=1,8 do seed.orbital_combinator_banks[i]={id=i,last_connection_audit_tick=i==due_id and -1000 or 1000} end
                seed.orbital_combinator_banks[true]={id="boolean",last_connection_audit_tick=1000}
                parity("orbital-cached-count",seed,function(m)
                    local trace={};for _=1,12 do local bank=m[orbital].qc_bank(1,true);trace[#trace+1]={id=bank and bank.id,state=snapshot()} end;return trace
                end)
            end
        end
        for _,n in ipairs({1,8,64,256}) do
            local seed={orbital_combinator_banks={},orbital_combinator_bank_count=n}
            for i=1,n do seed.orbital_combinator_banks[i]={last_connection_audit_tick=1000} end
            profile("orbital-not-due-"..n,seed,function(m)m[orbital].qc_bank(1,false)end,100)
            seed.orbital_combinator_banks[1].last_connection_audit_tick=-1000
            profile("orbital-first-due-"..n,seed,function(m)m[orbital].qc_bank(1,false)end,100)
        end

        -- Water's budget includes queue tombstones. Compare every intermediate
        -- state, including legacy empty-queue normalization and sparse buckets.
        for _,shape in ipairs({{}, {items={},queued={},head=1,tail=0},
            {items={[50]=7},queued={},head=1,tail=0},
            {items={[50]=7},queued={[7]=true},head=9,tail=3},
            {items={1,2,3,4,5},queued={[1]=true},head=1,tail=5}}) do
            local seed={water_turret={count=1,records={},registrations={},power_due={[1]={}},fire_due={[1]={}},fire_queue=shape,counters={}}}
            parity("water-queues",seed,function(m)
                local trace={};for tick=1,5 do m["water-turret"].updater{tick=tick};trace[#trace+1]=snapshot() end;return trace
            end)
        end
        local queue={items={},queued={},head=1,tail=100}
        for i=1,100 do queue.items[i]=i;queue.queued[i]=true end
        parity("water-budget",{water_turret={count=1,records={},registrations={},power_due={},fire_due={},fire_queue=queue,counters={}}},function(m)
            local trace={};for tick=1,5 do m["water-turret"].updater{tick=tick};trace[#trace+1]=snapshot() end;return trace
        end)
        profile("water-empty-active",{water_turret={count=1,records={},power_due={},fire_due={},fire_queue={items={},queued={},head=1,tail=0}}},function(m)m["water-turret"].updater{tick=1}end,100000)
        for _,buckets in ipairs({false,{[1]=false}}) do
            parity("water-malformed-due",{water_turret={count=1,records={},power_due=buckets,fire_due=buckets,fire_queue={}}},function(m)m["water-turret"].updater{tick=1}end)
        end

        for _,spec in ipairs({{"gaia","damage_tick_buckets","damage_ticks","has_damage_tick_work"},
            {"alien-spawner","spawner_buckets","spawner_queue","has_tick_work"}}) do
            local name,bucket_key,legacy_key,guard=table.unpack(spec)
            for _,buckets in ipairs({false,{}, {[0]={{id=1}},[5]={[3]={id=2}},[9]={},[12]=false,[15]={{id=3}}}}) do
                for _,legacy in ipairs({{},{{id=4,tick=-1,update_tick=-1},{id=5,tick=7,update_tick=7}}}) do
                    parity(name.."-delayed",{[bucket_key]=buckets,[legacy_key]=legacy},function(m)
                        local api=m[name];local trace={}
                        for tick=0,30 do
                            if tick==1 then
                                -- A later insertion must not postpone an earlier bucket.
                                local later={id=500,tick=25,update_tick=25}
                                if name=="gaia" then api.qc_schedule(later,25,tick) else api.qc_schedule(later,tick) end
                            end
                            if tick==3 or tick==6 or tick==19 then
                                local entry={id=100+tick,tick=tick+1,update_tick=tick+1}
                                if name=="gaia" then api.qc_schedule(entry,tick+1,tick) else api.qc_schedule(entry,tick) end
                            end
                            local due=api[guard]{tick=tick};local entries={}
                            if due then entries=api.qc_take(api.qc_ensure(tick),tick) end
                            trace[#trace+1]={due=due,entries=copy(entries),state=snapshot()}
                            if tick==5 then
                                local immediate={id=501,tick=tick,update_tick=tick}
                                if name=="gaia" then api.qc_schedule(immediate,tick,tick) else api.qc_schedule(immediate,tick) end
                                local again=api[guard]{tick=tick}
                                trace[#trace+1]={due=again,entries=copy(api.qc_take(api.qc_ensure(tick),tick)),state=snapshot()}
                            end
                            if tick==7 then storage.ei=copy(storage.ei) end
                        end
                        return trace
                    end)
                end
            end
            local buckets={};for i=1,256 do buckets[1000+i]={{id=i}} end
            profile(name.."-future",{[bucket_key]=buckets},function(m)m[name][guard]{tick=1}end,10000)
        end

        -- Exact floating point geometry, including rotated and degenerate boxes.
        local lance="singularity-lance"
        for _,direction in ipairs({{1,0},{0,1},{-1,0},{0,-1}}) do
            for _,edge in ipairs({-1e-12,0,1e-12,.5-1e-12,.5,.5+1e-12,8-1e-12,8,8+1e-12}) do
                local entity={bounding_box={left_top={x=edge,y=edge},right_bottom={x=edge+1,y=edge+1}}}
                equal(before[lance].qc_corridor(entity,{x=0,y=0},direction[1],direction[2],8),after[lance].qc_corridor(entity,{x=0,y=0},direction[1],direction[2],8),"lance-boundary")
                checks=checks+1
            end
        end
        for _,orientation in ipairs({0,.125,.25,.333,.5,.875}) do
            for _,width in ipairs({0,.5,2,8}) do
                for angle=0,31 do
                    local ux,uy=math.cos(angle*math.pi/16),math.sin(angle*math.pi/16)
                    for x=-5,10 do for y=-3,3 do
                        local entity={bounding_box={left_top={x=x-width,y=y-.5},right_bottom={x=x+width,y=y+.5},orientation=orientation}}
                        equal(before[lance].qc_corridor(entity,{x=0,y=0},ux,uy,8),after[lance].qc_corridor(entity,{x=0,y=0},ux,uy,8),"lance-geometry")
                        checks=checks+1
                    end end
                end
            end
        end
        local diagonal_box={bounding_box={left_top={x=2,y=1},right_bottom={x=6,y=3},orientation=.125}}
        local origin={x=0,y=0}
        profile("lance-diagonal-clip",{},function(m)m[lance].qc_corridor(diagonal_box,origin,.8,.6,8)end,100000)
        log("CONTROL_UPS ALL_COMPLETE checks="..checks)
    end
    local ok,err=pcall(run)
    storage.ei=saved
    if not ok then error(err) end
end
