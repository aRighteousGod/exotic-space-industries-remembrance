-- Appended to the private core control; the private owner bridge provides QC only.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local loaded=true
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        local root=storage.esir_qc_auric21
        if not root then
            root={phase='prepare'};storage.esir_qc_auric21=root
            remote.call('ei-gleba-vat-qc','prepare')
            root.before=remote.call('ei-gleba-vat-qc','checkpoint')
            game.server_save('auric-prepared')
            loaded=false
        elseif loaded and root.phase=='prepare' then
            loaded=false
            remote.call('ei-gleba-vat-qc','verify_checkpoint',root.before)
            root.bands=remote.call('ei-gleba-vat-qc','run')
            root.phase='cycling';root.started=event.tick
            if game.is_multiplayer() then game.speed=50 end
        elseif root.phase=='cycling' then
            if remote.call('ei-gleba-vat-qc','service_cycle') then
                root.after=remote.call('ei-gleba-vat-qc','checkpoint')
                root.phase='complete'
                local report=remote.call('ei-gleba-vat-qc','report')
                report.passed=true;report.engine=script.active_mods.base
                helpers.write_file('auric-native-complete.json',helpers.table_to_json(report),false)
                game.server_save('auric-completed')
                log('AURIC NATIVE COMPLETE')
            end
            assert(event.tick-root.started<18000,'Auric real cycle timed out')
        elseif loaded and root.phase=='complete' then
            loaded=false
            remote.call('ei-gleba-vat-qc','verify_checkpoint',root.after)
            local report=remote.call('ei-gleba-vat-qc','report')
            report.passed=true;report.engine=script.active_mods.base;report.second_reload=true
            helpers.write_file('auric-native-reload.json',helpers.table_to_json(report),false)
            if game.is_multiplayer() then game.server_save('auric-reloaded') end
            log('AURIC NATIVE RELOAD COMPLETE')
        end
    end)
end
