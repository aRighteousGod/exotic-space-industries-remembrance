-- Diagnose noise, tile and initial-unit contributions to legacy Gaia placement.
-- This runs only on throwaway, unassociated surfaces in a private stage.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local config=require('lib/planet-enemies-config')
    local names={'flying-electric-unit-spawner','walker-electric-unit-spawner'}
    local jobs={}
    for _,seed in ipairs{1000,421337} do
        for _,mode in ipairs{'normal','sparse','flat','flat-no-units'} do jobs[#jobs+1]={seed=seed,mode=mode} end
    end
    local positions={}
    for _,center in ipairs{{0,0},{1024,1024},{2048,0},{0,2048}} do
        for x=center[1]-96,center[1]+127 do for y=center[2]-96,center[2]+127 do positions[#positions+1]={x,y} end end
    end
    local index=0
    local result={engine=script.active_mods.base,positions=#positions,cases={},
        prototypes=prototypes.mod_data['esir-qc-gaia-spawner-prototypes'].data}
    script.on_event(defines.events.on_tick,function(event)
        previous(event);index=index+1
        local job=jobs[index];if not job then return end
        local defaults=prototypes.space_location.gaia.map_gen_settings
        local mgs=table.deepcopy(defaults);mgs.seed=job.seed
        if config.legacy_revision then
            mgs.property_expression_names[config.revision_property]=config.legacy_revision
            config.merge_generation_aliases(mgs.property_expression_names,defaults.property_expression_names or {},'gaia',config.legacy_revision)
        end
        if job.mode~='normal' then
            mgs.autoplace_settings.entity={treat_missing_as_default=false,settings={}}
            mgs.autoplace_settings.decorative={treat_missing_as_default=false,settings={}}
            mgs.cliff_settings.richness=0
            for _,name in ipairs(names) do
                local selected=job.mode=='flat-no-units' and 'esir-qc-empty-'..name or name
                mgs.autoplace_settings.entity.settings[selected]={}
                mgs.property_expression_names['entity:'..selected..':probability']=mgs.property_expression_names['entity:'..name..':probability']
            end
        end
        if job.mode=='flat' or job.mode=='flat-no-units' then
            mgs.autoplace_settings.tile={treat_missing_as_default=false,settings={['grass-1']={}}}
            mgs.property_expression_names['tile:grass-1:probability']=1
        end
        local surface=game.create_surface('esir-qc-gaia-generation-probe',mgs)
        local row={seed=job.seed,mode=job.mode,entities={},counts={}}
        if job.mode=='normal' then
            row.values=surface.calculate_tile_properties({'entity:'..names[1]..':probability','entity:'..names[2]..':probability'},positions)
        end
        for _,position in ipairs{{0,0},{1024,1024},{2048,0},{0,2048}} do surface.request_to_generate_chunks(position,3) end
        surface.force_generate_chunk_requests()
        for _,entity in pairs(surface.find_entities()) do
            row.counts[entity.type]=(row.counts[entity.type] or 0)+1
            if entity.type=='unit-spawner' then row.entities[#row.entities+1]=entity.name:gsub('esir%-qc%-empty%-','')..':'..entity.position.x..':'..entity.position.y end
        end
        table.sort(row.entities)
        if job.mode=='normal' then
            row.tiles={}
            for _,position in ipairs(positions) do row.tiles[#row.tiles+1]=surface.get_tile(position).name end
        end
        result.cases[#result.cases+1]=row;game.delete_surface(surface)
        if index==#jobs then
            helpers.write_file('gaia-generation-probe.json',helpers.table_to_json(result),false)
            log('GAIA GENERATION PROBE COMPLETE')
        end
    end)
end
