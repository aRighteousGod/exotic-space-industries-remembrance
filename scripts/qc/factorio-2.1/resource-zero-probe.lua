-- Read-only policy diagnosis on disposable surfaces; no shipping changes.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local done=false
    script.on_event(defines.events.on_tick,function(event)
        previous(event);if done then return end;done=true
        local results={engine=script.active_mods.base,cases={}}
        for _,mode in ipairs{'zero-richness','zero-richness-off','zero-frequency-positive-richness','zero-size-zero-richness','zero-size-positive-richness','zero-richness-zero-probability','positive','positive-dense'} do
            if mode~='zero-frequency-positive-richness' or prototypes.mod_data['esir-qc-resource-zero-safe'] then
            local mgs=table.deepcopy(prototypes.space_location.nauvis.map_gen_settings)
            mgs.seed=1000;mgs.autoplace_controls=mgs.autoplace_controls or {}
            mgs.autoplace_controls['iron-ore']={frequency=(mode=='zero-richness-off' or mode=='zero-frequency-positive-richness') and 0 or (mode=='positive-dense' and 3 or 1),
                size=(mode=='zero-richness-off' or mode:find('zero-size',1,true)) and 0 or 1,
                richness=(mode=='positive' or mode=='positive-dense' or mode=='zero-size-positive-richness' or mode=='zero-frequency-positive-richness') and 1 or 0}
            if mode=='zero-richness-zero-probability' then
                mgs.property_expression_names=mgs.property_expression_names or {}
                mgs.property_expression_names['entity:iron-ore:probability']='0'
            end
            local ok,surface=pcall(game.create_surface,'esir-qc-zero-'..mode,mgs)
            local row={mode=mode,created=ok,error=not ok and tostring(surface) or nil}
            if ok then
                local sampled,values=pcall(surface.calculate_tile_properties,{'entity:iron-ore:probability','entity:iron-ore:richness'},{{0,0},{128,128},{1024,1024}})
                row.sampled=sampled;row.values=sampled and values or nil;row.error=not sampled and tostring(values) or nil
                if sampled then
                    surface.request_to_generate_chunks({0,0},8);surface.force_generate_chunk_requests()
                    row.iron_entities=surface.count_entities_filtered{name='iron-ore'}
                    if mode=='positive' or mode=='positive-dense' then
                        local positions={}
                        for x=-512,512,16 do for y=-512,512,16 do positions[#positions+1]={x,y} end end
                        row.dense=surface.calculate_tile_properties({'entity:iron-ore:probability','entity:iron-ore:richness'},positions)
                    end
                end
                game.delete_surface(surface)
            end
            results.cases[#results.cases+1]=row
            end
        end
        helpers.write_file('resource-zero-probe.json',helpers.table_to_json(results),false)
        log('RESOURCE ZERO PROBE COMPLETE')
    end)
end
