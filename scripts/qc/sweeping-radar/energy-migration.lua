-- Save with pre-change hardware, reload with current prototypes/configuration.
-- Keep all radars paused so the only change in stored joules is native standby.
local loaded=false
local tick
local function call(name,...) return remote.call("esir_radar_qc",name,tick,...) end
script.on_init(function() storage.pending=true end)
script.on_load(function() loaded=true end)
---@param event EventData.on_tick
script.on_event(defines.events.on_tick,function(event)
    tick=event.tick
    if storage.pending then
        storage.pending=nil;storage.started=tick;storage.radars={}
        local surface=game.create_surface("radar-energy-migration",{autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
        for i,name in ipairs{"ei-sweeping-radar","ei-phased-array-radar"} do
            local radar=surface.create_entity{name=name,position={16*i,16},quality="legendary",force="player",raise_built=true}
            call("settings",radar,{run=0})
            storage.radars[i]=radar
        end
        return
    end
    if not storage.checkpoint and tick-storage.started==60 then
        storage.checkpoint={}
        for index,radar in ipairs(storage.radars) do
            local record=call("snapshot",radar);record.power.energy=1000000
            assert(record.power.electric_buffer_size==({4000000,2000000})[index]
                and record.maximum==({16,24})[index] and record.rate==({2,8})[index]
                and record.cost==({2000000,1000000})[index],"Checkpoint must use pre-change source")
            storage.checkpoint[index]={energy=record.power.energy,maximum=record.maximum,rate=record.rate,cost=record.cost}
        end
        storage.paid=call("snapshot").counters.paid_joules
        helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=true,checkpoint=storage.checkpoint}),false)
        game.server_save("radar-transition")
    elseif loaded and storage.checkpoint and not storage.reloaded then
        storage.reloaded=tick;storage.no_free_energy=true;storage.joules_preserved=true;storage.loaded_energy={}
        for index,radar in ipairs(storage.radars) do
            local energy=call("snapshot",radar).energy;storage.loaded_energy[index]=energy
            storage.no_free_energy=storage.no_free_energy and energy<=storage.checkpoint[index].energy
            -- The save/load boundary can include two native consumption ticks.
            storage.joules_preserved=storage.joules_preserved and energy>=storage.checkpoint[index].energy-({1000000,2000000})[index]/30-1
        end
    elseif storage.reloaded and tick-storage.reloaded==30 then
        local tests={}
        for index,radar in ipairs(storage.radars) do
            local record=call("snapshot",radar)
            tests[#tests+1]={name="migrated-capabilities-"..index,pass=record.maximum==({20,28})[index]
                and record.rate==({3,12})[index] and math.abs(record.cost-({6400000,4000000})[index])<.01
                and record.settings.modes[1].radius==12 and record.settings.run==0}
            tests[#tests+1]={name="expanded-buffer-keeps-joules-"..index,pass=record.power.electric_buffer_size==({16000000,10000000})[index]
                and record.energy<=storage.checkpoint[index].energy and record.power.quality.name=="normal"
                and math.abs(record.power.power_usage-({1000000,2000000})[index]/60)<.01,
                capacity=record.power.electric_buffer_size,standby_per_tick=record.power.power_usage,energy=record.energy}
        end
        local passed=storage.no_free_energy and storage.joules_preserved and call("snapshot").counters.paid_joules==storage.paid
        for _,test in ipairs(tests) do passed=passed and test.pass end
        helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=passed,tests=tests,no_free_energy=storage.no_free_energy,
            joules_preserved=storage.joules_preserved,loaded_energy=storage.loaded_energy,checkpoint=storage.checkpoint}),false)
    end
end)
