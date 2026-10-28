-- Private native generation evidence, appended to both preserved 2.0 and 2.1.
-- No associated planet is created: production lifecycle cannot rewrite a case.
do
    local previous=script.get_event_handler(defines.events.on_tick)
    local config=require('lib/planet-enemies-config')
    local modern=script.active_mods.base:sub(1,3)=='2.1'
    local families={'ordinary','explosive','cold','arachnid','toxic','armoured'}
    local planets={'nauvis','vulcanus','aquilo','fulgora','gaia','gleba'}
    local controls={nauvis={ordinary='enemy-base',explosive='hot_enemy_base',cold='frost_enemy_base',
        arachnid='ei-nauvis-arachnid-enemies',toxic='ei-nauvis-toxic-enemies',armoured='ei-nauvis-armoured-enemies'},
        vulcanus={explosive='ei-vulcanus-explosive-enemies',demolisher='ei-vulcanus-demolishers'},
        aquilo={cold='ei-aquilo-cold-enemies'},fulgora={electric='electric_enemies'},
        gaia={electric='ei-gaia-electric-enemies'},gleba={pentapod='gleba_enemy_base'}}
    local variants={{'off',0,0},{'frequency-zero',0,1},{'size-zero',1,0},
        {'frequency-low',1/6,1},{'frequency-high',6,1},{'size-low',1,1/6},{'size-high',1,6},
        {'extreme-small',6,1/6},{'extreme-large',1/6,6}}
    local jobs,results={}, {engine=script.active_mods.base,cases={}}
    for _,revision in ipairs(modern and {'legacy20','native21'} or {'legacy20'}) do
        for _,seed in ipairs{1000,421337} do
            for _,planet in ipairs(planets) do
                jobs[#jobs+1]={planet=planet,seed=seed,case='default',revision=revision}
                local names={};for family in pairs(controls[planet]) do names[#names+1]=family end;table.sort(names)
                for _,family in ipairs(names) do
                    for _,variant in ipairs(variants) do
                        jobs[#jobs+1]={planet=planet,seed=seed,revision=revision,family=family,
                            control=controls[planet][family],case=variant[1],frequency=variant[2],size=variant[3]}
                    end
                end
            end
            for a=1,#families do for b=a+1,#families do
                jobs[#jobs+1]={planet='nauvis',seed=seed,revision=revision,
                    case='mixed-'..families[a]..'-'..families[b],mixed={families[a],families[b]}}
            end end
        end
    end
    local positions={}
    for x=-2048,4096,64 do for y=-2048,4096,64 do positions[#positions+1]={x,y} end end
    local function digest(values)
        local h1,h2,positive=0,0,0
        for _,value in ipairs(values) do
            assert(value==value and math.abs(value)<math.huge,'nonfinite generation noise')
            if value>0 then positive=positive+1 end
            local text=string.format('%.17g;',value)
            for i=1,#text do h1=(h1*131+text:byte(i))%2147483647;h2=(h2*137+text:byte(i))%2147483629 end
        end
        return {hash=h1..':'..h2,positive=positive,count=#values}
    end
    local index=0
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        index=index+1
        local job=jobs[index];if not job then return end
        local defaults=prototypes.space_location[job.planet].map_gen_settings
        local mgs=table.deepcopy(defaults);mgs.seed=job.seed
        if modern then
            local revision=job.revision=='legacy20' and config.legacy_revision or config.native_revision
            mgs.property_expression_names=mgs.property_expression_names or {}
            mgs.property_expression_names[config.revision_property]=revision
            config.merge_generation_aliases(mgs.property_expression_names,defaults.property_expression_names or {},job.planet,revision)
        end
        if job.control then mgs.autoplace_controls[job.control]={frequency=job.frequency,size=job.size,richness=1} end
        for _,family in ipairs(job.mixed or {}) do mgs.autoplace_controls[controls.nauvis[family]]={frequency=6,size=1,richness=1} end
        local surface=game.create_surface('esir-upgrade-generation',mgs)
        local properties={'elevation','temperature','moisture'}
        local family_map={}
        for name,prototype in pairs(prototypes.entity) do
            if prototype.autoplace_specification and (prototype.type=='unit-spawner' or prototype.type=='turret')
                and (mgs.autoplace_settings.entity.settings[name] or
                    (prototype.autoplace_specification.control and mgs.autoplace_controls[prototype.autoplace_specification.control])) then
                local property='entity:'..name..':probability'
                properties[#properties+1]=property
                family_map[property]=config.family(name,prototype.type)
            end
        end
        if job.planet=='vulcanus' then
            for _,property in ipairs{'demolisher_territory_radius','demolisher_territory_expression','demolisher_variation_expression'} do
                properties[#properties+1]=property;family_map[property]='demolisher'
            end
        end
        table.sort(properties)
        local noise=surface.calculate_tile_properties(properties,positions)
        local record={planet=job.planet,seed=job.seed,case=job.case,revision=job.revision,family=job.family,mixed=job.mixed,
            noise={},families=family_map,entities={},aliases=surface.map_gen_settings.property_expression_names}
        for _,property in ipairs(properties) do
            if noise[property] then record.noise[property]=digest(noise[property])
            else assert(job.control and (job.frequency==0 or job.size==0),property);record.noise[property]={omitted=true,positive=0} end
        end
        if job.case=='default' or job.case=='off' then
            for _,position in ipairs{{0,0},{1024,1024},{2048,0},{0,2048}} do surface.request_to_generate_chunks(position,3) end
            surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities_filtered{type={'unit-spawner','turret'}}) do
                record.entities[#record.entities+1]=entity.name..':'..entity.position.x..':'..entity.position.y
            end
            table.sort(record.entities)
        end
        local restored=helpers.parse_map_exchange_string(surface.get_map_exchange_string()).map_gen_settings
        record.roundtrip=true
        for name,values in pairs(surface.map_gen_settings.autoplace_controls) do
            for _,field in ipairs{'frequency','size','richness'} do
                if (values[field] or 1)~=((restored.autoplace_controls[name] or {})[field] or 1) then record.roundtrip=false end
            end
        end
        for name,value in pairs(record.aliases or {}) do
            assert(restored.property_expression_names[name]==value,'Generation alias lost in exchange: '..name)
        end
        results.cases[#results.cases+1]=record;game.delete_surface(surface)
        if index%20==0 or index==#jobs then
            helpers.write_file('upgrade-generation.json',helpers.table_to_json(results),false)
            log('UPGRADE GENERATION '..index..'/'..#jobs)
        end
        if index==#jobs then log('UPGRADE GENERATION COMPLETE '..index) end
    end)
end
