-- Staging-only engine serialization fixture. Production handlers drain the queues.
do
    local gaia = require("scripts/control/gaia")
    local alien = require("scripts/control/alien-spawner")
    local presets = require("lib/spawner-presets")
    local scheduler = require("lib/runtime-scheduler")
    gaia.entity_damage_ticks["steel-chest"] = 25
    presets.entity_presets["control-ups-queue"] = {rarity="common", force="player",
        tiles={{name="stone-path",position={x=0,y=0}}},
        structure={{name="wooden-chest",position={x=0,y=0},destructible=true}}}
    local loaded = false
    local configured = false
    script.on_load(function()
        if __control_ups_load then __control_ups_load() end
        loaded = storage.control_ups_queue and storage.control_ups_queue.saved or false
    end)
    local old_config = assert(__control_ups_config)
    script.on_configuration_changed(function(event)
        old_config(event)
        configured = true
        local q=storage.control_ups_queue
        if q then
            assert(storage.ei.damage_tick_next_due_tick==nil and storage.ei.spawner_next_due_tick==nil,
                "configuration failed to invalidate minima")
            q.configuration_reloaded = true
        end
    end)
    local function record(kind, value)
        local q=storage.control_ups_queue
        q.trace[#q.trace+1]={kind=kind,value=value}
    end
    gaia.qc_trace_due = function(tick, jobs)
        local q=storage.control_ups_queue
        if not q then return end
        for _,job in ipairs(jobs) do
            for label,entity in pairs(q.entities) do
                if entity==job.entity then
                    record("gaia",{tick=tick-q.start,label=label,damage=job.damage,valid=entity.valid})
                    break
                end
            end
        end
    end
    alien.qc_trace_due = function(tick, jobs)
        local q=storage.control_ups_queue
        if not q then return end
        for _,job in ipairs(jobs) do
            if job.preset=="control-ups-queue" then
                assert(job.surface.valid and job.surface==q.surface,"saved surface reference lost")
                record("alien",{tick=tick-q.start,x=job.pos.x,tiles=job.tiles})
                if job.pos.x==16 and job.tiles and not q.rescheduled_in_drain then
                    q.rescheduled_in_drain=true
                    -- Insert work for the current tick after the due snapshot was taken.
                    alien.qc_schedule({preset="control-ups-queue",surface=q.surface,pos={x=24,y=16},tick=tick,tiles=false},tick)
                end
            end
        end
    end
    local function schedule_gaia(label,due,damage)
        local q=storage.control_ups_queue
        gaia.qc_schedule({entity=q.entities[label],damage=damage or 30},q.start+due,game.tick)
    end
    local function schedule_alien(x,due,tiles)
        local q=storage.control_ups_queue
        alien.qc_schedule({preset="control-ups-queue",surface=q.surface,pos={x=x,y=16},tick=q.start+due,tiles=tiles},game.tick)
    end
    local function setup(tick)
        local surface=game.create_surface("control-ups-queue",{width=64,height=64})
        surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do entity.destroy() end
        local tiles={}
        for x=-31,31 do for y=-31,31 do tiles[#tiles+1]={name="stone-path",position={x,y}} end end
        surface.set_tiles(tiles)
        local q={start=tick,surface=surface,entities={},trace={},saved=false,reload_observed=false}
        storage.control_ups_queue=q
        for i,label in ipairs({"legacy","late","early","immediate","invalid"}) do
            q.entities[label]=surface.create_entity{name="steel-chest",position={i*4-16,0},force="player"}
            assert(q.entities[label] and q.entities[label].valid)
        end
        -- Explicit legacy payloads: Gaia currently has no ordinary new producer.
        storage.ei.damage_ticks={{entity=q.entities.legacy,damage=40,update_tick=tick+40}}
        storage.ei.damage_tick_buckets={};storage.ei.damage_tick_next_due_tick=nil
        storage.ei.spawner_queue={{preset="control-ups-queue",surface=surface,pos={x=-16,y=16},tick=tick+40,tiles=true}}
        storage.ei.spawner_buckets={};storage.ei.spawner_next_due_tick=nil
        gaia.qc_ensure(tick);alien.qc_ensure(tick)
        schedule_gaia("late",100);schedule_gaia("invalid",65)
        schedule_alien(-8,100,true)
        gaia.has_damage_tick_work{tick=tick};alien.has_tick_work{tick=tick}
    end
    local previous=script.get_event_handler(defines.events.on_tick)
    script.on_event(defines.events.on_tick,function(event)
        if not storage.control_ups_queue then setup(event.tick) end
        local q=storage.control_ups_queue
        local relative=event.tick-q.start
        if loaded and q.saved and not q.reload_observed then
            q.reload_observed=true
            assert(q.surface.valid and q.entities.legacy.valid,"LuaObject references did not survive save/load")
            assert(relative==11,"unexpected save tick: "..relative)
            q.reload_kind=configured and "configuration" or "ordinary"
            if not configured then
                assert((storage.ei.damage_tick_next_due_tick or false)==q.saved_minima.gaia,"Gaia cached minimum changed across ordinary reload")
                assert((storage.ei.spawner_next_due_tick or false)==q.saved_minima.alien,"alien cached minimum changed across ordinary reload")
            end
            -- Earlier and later insertions after restoring already-cached minima.
            schedule_gaia("early",25);schedule_alien(0,25,true)
            schedule_alien(8,110,false)
        end
        if relative==30 then
            schedule_gaia("immediate",30,20)
            schedule_alien(16,30,true)
        end
        if relative==52 then q.entities.invalid.destroy() end
        previous(event)
        if relative==10 and not q.saved then
            q.saved=true
            q.saved_minima={gaia=storage.ei.damage_tick_next_due_tick or false,alien=storage.ei.spawner_next_due_tick or false}
            game.server_save("control-ups-pending")
            log("CONTROL_UPS_QUEUE SAVE_REQUEST tick="..event.tick)
        end
        if relative==155 and q.reload_observed then
            assert(scheduler.delayed_item_count(storage.ei.damage_tick_buckets)==0,"Gaia jobs left behind")
            assert(scheduler.delayed_item_count(storage.ei.spawner_buckets)==0,"alien jobs left behind")
            local chests=q.surface.count_entities_filtered{name="wooden-chest"}
            assert(chests==6 and q.rescheduled_in_drain,"missing or duplicate spawned objects: "..chests)
            local result={complete=true,reload_kind=q.reload_kind,saved_minima=q.saved_minima,trace=q.trace,spawned_chests=chests}
            helpers.write_file("control-ups-queue.json",helpers.table_to_json(result),false)
            log("CONTROL_UPS_QUEUE ALL_COMPLETE "..helpers.table_to_json(result))
        end
    end)
end
