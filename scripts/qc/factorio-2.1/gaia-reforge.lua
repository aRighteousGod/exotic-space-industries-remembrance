-- Actual reforge lifecycle on a disposable copy of the migrated donor only.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local config=require('lib/planet-enemies-config')
    local loaded=true
    local function verify(root)
        local surface=assert(game.planets.gaia.surface)
        local after=surface.map_gen_settings
        assert(surface.valid and surface.name=='gaia' and surface.index~=root.old_index,'Reforge did not replace the surface')
        assert(not game.surfaces['gaia-reforge-staging'],'Staging surface leaked')
        assert(after.seed==root.before.seed,'Reforge changed the saved seed')
        assert(helpers.table_to_json(after.autoplace_controls)==helpers.table_to_json(root.before.autoplace_controls),'Reforge changed controls')
        for key,value in pairs(root.before.property_expression_names) do assert(after.property_expression_names[key]==value,'Reforge changed alias '..key) end
        assert(after.property_expression_names[config.revision_property]==config.legacy_revision,'Reforge lost legacy revision')
        return {passed=true,seed=after.seed,aliases=after.property_expression_names,old_surface_index=root.old_index,
            new_surface_index=surface.index,phases=root.phases,engine=script.active_mods.base,
            limits={'No connected-player evacuation or remote-view interaction in this fixture'}}
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        local root=storage.esir_qc_gaia_reforge
        if not root then
            local surface=assert(game.planets.gaia.surface)
            local settings=surface.map_gen_settings
            settings.property_expression_names['entity:walker-electric-unit-spawner:probability']='0'
            settings.autoplace_controls[config.gaia_control]={frequency=1.3,size=0.75,richness=1}
            surface.map_gen_settings=settings
            root={old_index=surface.index,before=surface.map_gen_settings,started=event.tick,phases={}}
            storage.esir_qc_gaia_reforge=root
            -- Exercise the real destructive branch only in this private save.
            for _,resource in pairs(surface.find_entities_filtered{type='resource'}) do resource.destroy() end
            ei_gaia.reforge_gaia_surface(event)
        elseif root.complete then
            if loaded then
                loaded=false
                helpers.write_file('gaia-reforge-reload.json',helpers.table_to_json(verify(root)),false)
                log('GAIA REFORGE RELOAD PASSED')
            end
        elseif storage.ei.reforge_gaia then
            local phase=storage.ei.reforge_gaia.phase
            if root.phases[#root.phases]~=phase then root.phases[#root.phases+1]=phase end
            assert(event.tick-root.started<3600,'Reforge lifecycle timed out')
        else
            root.complete=true;loaded=false
            local report=verify(root)
            report.ticks=event.tick-root.started
            helpers.write_file('gaia-reforge-complete.json',helpers.table_to_json(report),false)
            game.server_save('gaia-reforged')
            log('GAIA REFORGE COMPLETE')
        end
    end)
end
