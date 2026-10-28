-- Private populated-surface migration acceptance, appended after ESIR owners.
-- No production hook, surface or persistent test state ships.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local modern=script.active_mods.base:sub(1,3)=='2.1'
    local config=require('lib/planet-enemies-config')
    local gaia_mapgen=require('scripts/control/gaia-mapgen-data')
    local loaded=true
    local function capture(surface)
        local result={name=surface.name,seed=surface.map_gen_settings.seed,entities={},tiles={},
            controls=surface.map_gen_settings.autoplace_controls,aliases=surface.map_gen_settings.property_expression_names}
        for _,entity in pairs(surface.find_entities_filtered{type='unit-spawner'}) do
            result.entities[#result.entities+1]={name=entity.name,unit=entity.unit_number,x=entity.position.x,y=entity.position.y,health=entity.health}
        end
        table.sort(result.entities,function(a,b)return a.unit<b.unit end)
        for x=960,1087 do for y=960,1087 do result.tiles[#result.tiles+1]=surface.get_tile(x,y).name end end
        return result
    end
    local function verify(root)
        local results={}
        for i,surface in ipairs(root.surfaces) do
            local before,after=root.before[i],capture(surface)
            for _,field in ipairs{'name','seed','entities','tiles','controls'} do
                assert(helpers.table_to_json{before[field]}==helpers.table_to_json{after[field]},'GENERATION MIGRATION changed '..field..' on '..surface.name)
            end
            assert(after.aliases[config.revision_property]==config.legacy_revision,'Legacy generation revision was not retained')
            for key,value in pairs(before.aliases) do
                -- The legacy marker is newly introduced; existing aliases are
                -- either the same authored identities or explicit overrides.
                assert(after.aliases[key]==value,'Saved generation alias changed '..key)
            end
            local rebuilt=gaia_mapgen.get_map_gen_settings(surface.map_gen_settings)
            assert(rebuilt.seed==before.seed,'Reforge settings changed seed')
            for key,value in pairs(after.aliases) do assert(rebuilt.property_expression_names[key]==value,'Reforge settings changed '..key) end
            results[#results+1]={name=surface.name,spawners=#after.entities,tiles=#after.tiles,
                seed=after.seed,revision=after.aliases[config.revision_property],aliases=after.aliases,reforge_settings_preserved=true}
        end
        local new=game.create_surface('esir-qc-native-generation',prototypes.space_location.gaia.map_gen_settings)
        assert(new.map_gen_settings.property_expression_names[config.revision_property]==config.native_revision,'New surface lacks native revision')
        game.delete_surface(new)
        return {passed=true,engine=script.active_mods.base,surfaces=results,new_surface_revision=config.native_revision,
            limits={'Actual reforge lifecycle and native generation placement parity remain separate'}}
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        local root=storage.esir_qc_generation_migration
        if not root then
            assert(not modern,'Create the populated donor on 2.0.77')
            root={surfaces={},before={}};storage.esir_qc_generation_migration=root
            local mgs=table.deepcopy(prototypes.space_location.gaia.map_gen_settings)
            mgs.seed=421337
            local actual=game.planets.gaia.surface or game.planets.gaia.create_surface()
            actual.map_gen_settings=mgs
            local custom_settings=table.deepcopy(mgs);custom_settings.seed=1000
            custom_settings.property_expression_names['entity:walker-electric-unit-spawner:probability']='0'
            custom_settings.autoplace_controls[config.gaia_control]={frequency=1.3,size=0.75,richness=1}
            local custom=game.create_surface('esir-qc-owned-gaia',custom_settings)
            storage.gaia_surfaces=storage.gaia_surfaces or {};storage.gaia_surfaces[custom.name]=true
            root.surfaces={actual,custom}
            for _,surface in ipairs(root.surfaces) do
                surface.request_to_generate_chunks({1024,1024},3);surface.force_generate_chunk_requests()
                root.before[#root.before+1]=capture(surface)
            end
            assert(#root.before[1].entities>0,'Populated Gaia donor has no nests')
            helpers.write_file('generation-migration-donor.json',helpers.table_to_json(root.before),false)
            game.server_save('generation-donor');loaded=false
        elseif modern and loaded then
            loaded=false
            local report=verify(root)
            local phase=root.adopted and 'second-reload' or 'adopted'
            root.adopted=true
            helpers.write_file('generation-migration-'..phase..'.json',helpers.table_to_json(report),false)
            if game.is_multiplayer() then game.server_save('generation-'..phase) end
            log('GENERATION MIGRATION PASSED '..phase)
        end
    end)
end
