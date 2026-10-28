-- Private native 2.0 donor -> 2.1 conversion -> second reload acceptance.
do
    local maps=require('scripts/control/map-settings')
    local previous=script.get_event_handler(defines.events.on_tick)
    local modern=script.active_mods.base:sub(1,3)=='2.1'
    local loaded=true
    local function capture(surface)
        local result={tiles={},ores={}}
        for x=-16,15 do for y=-16,15 do result.tiles[#result.tiles+1]=surface.get_tile(x,y).name end end
        for _,entity in pairs(surface.find_entities_filtered{type='resource'}) do
            result.ores[#result.ores+1]={name=entity.name,x=entity.position.x,y=entity.position.y,amount=entity.amount}
        end
        table.sort(result.ores,function(a,b) return a.x<b.x or a.x==b.x and (a.y<b.y or a.y==b.y and a.name<b.name) end)
        return result
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        if not loaded then return end
        loaded=false
        local root=storage.esir_qc_resource_off
        local surface=game.surfaces.nauvis
        if not root then
            assert(not modern,'Create this donor on exact 2.0.77')
            surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
            local mgs=surface.map_gen_settings
            mgs.seed=231337
            mgs.autoplace_controls['iron-ore']={frequency=0,size=0,richness=0}
            mgs.autoplace_controls['copper-ore']={frequency=0,size=2,richness=1.25}
            mgs.autoplace_controls.coal={frequency=1.25,size=0,richness=2}
            mgs.autoplace_controls.stone={frequency=2,size=3,richness=1.5}
            surface.map_gen_settings=mgs
            storage.ei.map_settings=storage.ei.map_settings or {overrides={},enabled={}}
            storage.ei.map_settings.enabled['planet:nauvis']={['iron-ore']={frequency=3,size=2,richness=0}}
            root={before=capture(surface),controls=mgs.autoplace_controls};storage.esir_qc_resource_off=root
            assert(#root.before.ores>0,'Donor needs existing resources')
            helpers.write_file('resource-off-donor.json',helpers.table_to_json(root),false)
            game.server_save('resource-off-donor')
            return
        end
        assert(modern,'Adopt the donor on exact 2.1.23')
        assert(helpers.table_to_json{root.before}==helpers.table_to_json{capture(surface)},'Existing terrain or resources changed')
        assert(surface.map_gen_settings.seed==231337,'Seed changed')
        local controls=surface.map_gen_settings.autoplace_controls
        local expected={['iron-ore']={0,0,0},['copper-ore']={0,root.adopted and 0 or 2,1.25},coal={1.25,0,2},stone={2,3,1.5}}
        for name,values in pairs(expected) do
            local actual=controls[name]
            assert(actual.frequency==values[1] and actual.size==values[2] and actual.richness==values[3],'Converted values changed: '..name)
        end
        local function apply(changes)
            local snap=assert(maps.snapshot{surface_index=surface.index})
            local ok,message=maps.apply(snap.target,snap.values,changes,event.tick)
            assert(ok,serpent.line(message))
        end
        for name,values in pairs{['iron-ore']={3,2,0},['copper-ore']={1,2,1.25}} do
            local id='control/'..name..'/'
            assert(not maps.snapshot{surface_index=surface.index}.values[id..'enabled'],'Off state lost')
            apply{[id..'enabled']=true}
            local actual=surface.map_gen_settings.autoplace_controls[name]
            assert(actual.frequency==values[1] and actual.size==values[2] and actual.richness==values[3],'On restore changed: '..name)
            apply{[id..'enabled']=false}
        end
        -- Creation/reforge can receive an old copied control record too.
        local copied=table.deepcopy(surface.map_gen_settings)
        copied.autoplace_controls['copper-ore'].frequency=0
        local prepared=maps.prepare_creation('nauvis',copied)
        assert(prepared.autoplace_controls['copper-ore'].frequency==0 and prepared.autoplace_controls['copper-ore'].size==0)
        assert(copied.autoplace_controls['copper-ore'].frequency==0,'Preparation mutated caller record')
        local probabilities=surface.calculate_tile_properties({'entity:iron-ore:probability','entity:copper-ore:probability'},{{1024,1024}})
        assert(probabilities['entity:iron-ore:probability'][1]==0 and probabilities['entity:copper-ore:probability'][1]==0,'Disabled ore probability is nonzero')
        local phase=root.adopted and 'second-reload' or 'adopted';root.adopted=true
        helpers.write_file('resource-off-'..phase..'.json',helpers.table_to_json{passed=true,engine=script.active_mods.base,
            tiles=#root.before.tiles,existing_ores=#root.before.ores,controls=surface.map_gen_settings.autoplace_controls,
            memory=storage.ei.map_settings.enabled['planet:nauvis'],restore_and_creation_passed=true},false)
        game.server_save('resource-off-'..phase)
        log('RESOURCE OFF MIGRATION PASSED '..phase)
    end)
end
