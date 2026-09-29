local config=require("__exotic-space-industries-remembrance__/lib/sweeping-radar-config")
local loaded=false
local configured_this_load=false
local current_tick
local function call(name,...) return remote.call("esir_radar_qc",name,current_tick,...) end
script.on_init(function() storage.pending=true end)
script.on_load(function() loaded=true end)
script.on_configuration_changed(function() configured_this_load=true end)
script.on_event(defines.events.on_tick,function(event)
    current_tick=event.tick
    if storage.pending then
        storage.pending=nil;storage.started=event.tick
        local surface=game.create_surface("radar-persistence",{autoplace_settings={entity={treat_missing_as_default=false}}})
        surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
        storage.radar=surface.create_entity{name="ei-phased-array-radar",position={16,16},force="player",raise_built=true}
        local settings=config.defaults();settings.mode=5;settings.modes[5].radius=1
        settings.speed=1
        call("settings",storage.radar,settings)
        surface.create_entity{name="substation",position={20,16},force="player"}
        surface.create_entity{name="ei-radar-qc-source",position={20,20},force="player"}
        -- Populate every intersected chunk so the first paid batch is nonempty.
        for x=-1,1 do for y=-1,1 do for i=1,128 do
            local target=surface.create_entity{name="gun-turret",position={x*32+16,y*32+16},force="enemy"}
            target.active=false
        end end end
        return
    end
    if loaded and storage.checkpoint and not storage.reload_tick then
        storage.reload_tick=event.tick
        local p=call("pending",storage.radar)
        storage.paid_once=p.paid==storage.checkpoint.paid
        storage.settings_kept=p.settings.mode==5 and p.settings.speed==1
        storage.ordered=p.epoch==storage.checkpoint.epoch and (p.cursor==storage.checkpoint.cursor or p.cursor==storage.checkpoint.cursor+1)
    end
    if not storage.checkpoint then
        local p=call("pending",storage.radar)
        if p.job and p.job.paid and p.batch then
            storage.checkpoint=p
            helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=true,checkpoint_tick=event.tick,
                paid=p.paid,batch_cursor=p.batch.cursor,samples=#p.batch.samples}),false)
            game.server_save("radar-transition")
        end
        assert(event.tick-storage.started<1800,"No pending paid batch captured")
    elseif storage.reload_tick and event.tick-storage.reload_tick==120 then
        local p=call("pending",storage.radar)
        local pass=storage.paid_once and storage.settings_kept and storage.ordered
            and p.observations==storage.checkpoint.observations+1 and p.paid==storage.checkpoint.paid
        helpers.write_file("radar-qc.json",helpers.table_to_json({all_pass=pass,paid_once=storage.paid_once,
            settings=storage.settings_kept,ordered=storage.ordered,configured=configured_this_load,
            observations=p.observations,paid=p.paid,cursor=p.cursor,epoch=p.epoch}),false)
    end
end)
