-- Preserve unpaid admission order independently from the existing paid-batch test.
local config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local loaded=false
local tick
local function call(name,...) return remote.call("esir_radar_qc",name,tick,...) end
script.on_init(function() storage.pending=true end)
script.on_load(function() loaded=true end)
script.on_event(defines.events.on_tick,function(event)
    tick=event.tick
    if storage.pending then
        storage.pending=nil;storage.started=tick;storage.radars={}
        local surface=game.create_surface("radar-generation-persistence",{autoplace_settings={entity={treat_missing_as_default=false}}})
        for i=1,4 do
            local x=1024*i+16
            local radar=surface.create_entity{name="ei-phased-array-radar",position={x,16},force="player",raise_built=true}
            local settings=config.defaults();settings.modes[1].radius=1
            call("settings",radar,settings)
            surface.create_entity{name="substation",position={x+2,16},force="player"}
            surface.create_entity{name="ei-radar-qc-source",position={x+2,20},force="player"}
            storage.radars[#storage.radars+1]=radar
        end
        call("hold_generation",300)
        return
    end
    local state=call("generation_state")
    if not storage.checkpoint then
        if #state.order==4 then
            assert(state.jobs==0 and state.paid==0,"Unpaid admission consumed a job or energy")
            storage.checkpoint=state
            helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=true,queued=#state.order,paid=state.paid}),false)
            game.server_save("radar-transition")
        end
        assert(tick-storage.started<250,"Did not capture all generation waiters before opening the gate")
    elseif loaded and not storage.finished then
        local before=storage.checkpoint
        if not storage.reloaded then
            storage.reloaded=true
            assert(state.cursor==before.cursor and state.deadline==before.deadline and state.paid==before.paid,"Admission cursor/deadline/payment changed on reload")
            for index,id in ipairs(before.order) do assert(state.order[index]==id,"Admission order changed on reload") end
        end
        if state.generated>before.generated then
            local admitted
            for _,radar in ipairs(storage.radars) do
                local p=call("pending",radar)
                if p.job and p.job.requested then admitted=radar.unit_number end
            end
            assert(admitted==before.cursor,"Oldest generation waiter did not receive the first grant")
            assert(state.generated==before.generated+1 and state.paid==before.paid+5000000,"Admission was not paid exactly once")
            storage.finished=true
            helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=true,ordered=true,unpaid_before=true,
                paid_once=true,admitted=admitted,queued=#state.order}),false)
        end
    end
end)
