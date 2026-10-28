-- Focused raw-value evidence for cross-engine differences found by the matrix.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local config=require('lib/planet-enemies-config')
    local jobs={}
    for _,seed in ipairs{1000,421337} do
        for _,planet in ipairs{'vulcanus','aquilo','gaia'} do jobs[#jobs+1]={seed=seed,planet=planet} end
    end
    local positions={}
    for x=-2048,4096,64 do for y=-2048,4096,64 do positions[#positions+1]={x,y} end end
    local index=0
    local results={engine=script.active_mods.base,cases={},spawners={}}
    for _,name in ipairs{'flying-electric-unit-spawner','walker-electric-unit-spawner'} do
        local prototype=prototypes.entity[name]
        results.spawners[name]={health=prototype.get_max_health('normal'),order=prototype.order,
            autoplace=prototype.autoplace_specification}
    end
    script.on_event(defines.events.on_tick,function(event)
        previous(event);index=index+1
        local job=jobs[index];if not job then return end
        local defaults=prototypes.space_location[job.planet].map_gen_settings
        local mgs=table.deepcopy(defaults);mgs.seed=job.seed
        if config.legacy_revision then
            mgs.property_expression_names=mgs.property_expression_names or {}
            mgs.property_expression_names[config.revision_property]=config.legacy_revision
            config.merge_generation_aliases(mgs.property_expression_names,defaults.property_expression_names or {},job.planet,config.legacy_revision)
        end
        local surface=game.create_surface('esir-generation-sample',mgs)
        local properties={'elevation'}
        if job.planet=='vulcanus' then properties[#properties+1]='demolisher_territory_expression' end
        if job.planet=='gaia' then
            properties[#properties+1]='entity:flying-electric-unit-spawner:probability'
            properties[#properties+1]='entity:walker-electric-unit-spawner:probability'
        end
        local record={planet=job.planet,seed=job.seed,values=surface.calculate_tile_properties(properties,positions),entities={},territories={}}
        for _,position in ipairs{{0,0},{1024,1024},{2048,0},{0,2048}} do surface.request_to_generate_chunks(position,3) end
        surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities_filtered{type={'unit-spawner','turret'}}) do
            record.entities[#record.entities+1]=entity.name..':'..entity.position.x..':'..entity.position.y
        end
        table.sort(record.entities)
        for _,territory in pairs(surface.get_territories()) do
            local chunks,units={},{}
            for _,chunk in pairs(territory.get_chunks()) do chunks[#chunks+1]=chunk.x..':'..chunk.y end
            for _,unit in pairs(territory.get_segmented_units()) do units[#units+1]=unit.prototype.name end
            table.sort(chunks);table.sort(units);record.territories[#record.territories+1]={chunks=chunks,units=units}
        end
        table.sort(record.territories,function(a,b)return table.concat(a.chunks,',')<table.concat(b.chunks,',') end)
        results.cases[#results.cases+1]=record;game.delete_surface(surface)
        if index==#jobs then
            helpers.write_file('generation-samples.json',helpers.table_to_json(results),false)
            log('GENERATION SAMPLES COMPLETE')
        end
    end)
end
