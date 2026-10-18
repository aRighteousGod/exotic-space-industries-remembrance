-- Append to frozen baseline AND candidate control.lua. Unassociated surfaces
-- deliberately bypass runtime policy: this measures native generation itself.
do
    local previous = script.get_event_handler(defines.events.on_tick)
    local planets = {"nauvis", "vulcanus", "aquilo", "fulgora", "gaia", "gleba"}
    local controls = {vulcanus="ei-vulcanus-explosive-enemies", aquilo="ei-aquilo-cold-enemies",
        fulgora="electric_enemies",gaia="ei-gaia-electric-enemies",gleba="gleba_enemy_base"}
    local cases = {{"default"},{"off",0,0},{"frequency-zero",0,1},{"size-zero",1,0},{"foreign-off"},
        {"explosive-only-off"},{"demolisher-only-off"},{"low",0.5,0.5},{"high",2,2},
        {"frequency-low",0.5,1},{"frequency-high",2,1},{"size-low",1,0.5},{"size-high",1,2},
        {"extreme-small",6,0.1666667},{"extreme-large",0.1666667,6}}
    local candidate = prototypes.autoplace_control["ei-vulcanus-demolishers"] ~= nil
    local jobs, result = {}, {candidate=candidate,cases={}}
    for _,seed in ipairs({1000,421337}) do
        for _,planet in ipairs(planets) do
            for _,case in ipairs(cases) do
                if case[1]=="default" or (candidate and (planet~="nauvis" or case[1]=="foreign-off")
                    and (not case[1]:find("only",1,true) or planet=="vulcanus")) then
                    jobs[#jobs+1] = {seed=seed,planet=planet,case=case}
                end
            end
        end
    end
    local index=0
    script.on_event(defines.events.on_tick,function(event)
        previous(event)
        index=index+1
        local job=jobs[index]
        if not job then return end
        local settings=table.deepcopy(prototypes.space_location[job.planet].map_gen_settings)
        settings.seed=job.seed
        local case=job.case
        if case[2] then
            settings.autoplace_controls[controls[job.planet]]={frequency=case[2],size=case[3],richness=1}
            if job.planet=="vulcanus" then
                settings.autoplace_controls["ei-vulcanus-demolishers"]={frequency=case[2],size=case[3],richness=1}
            end
        end
        if case[1]=="foreign-off" then
            for planet,control in pairs(controls) do
                if planet~=job.planet then settings.autoplace_controls[control]={frequency=0,size=0,richness=1} end
            end
            if job.planet~="vulcanus" then settings.autoplace_controls["ei-vulcanus-demolishers"]={frequency=0,size=0,richness=1} end
        elseif case[1]=="explosive-only-off" then
            settings.autoplace_controls[controls.vulcanus]={frequency=0,size=0,richness=1}
        elseif case[1]=="demolisher-only-off" then
            settings.autoplace_controls["ei-vulcanus-demolishers"]={frequency=0,size=0,richness=1}
        end
        local surface=game.create_surface("planet-enemy-qc",settings)
        local properties={"elevation","temperature","moisture"}
        for name,proto in pairs(prototypes.entity) do
            local family = (job.planet=="vulcanus" and name:find("explosive",1,true))
                or (job.planet=="aquilo" and name:find("cold",1,true))
                or ((job.planet=="fulgora" or job.planet=="gaia") and name:find("electric-unit",1,true))
                or (job.planet=="gleba" and name:find("gleba-spawner",1,true))
                or (job.planet=="nauvis" and settings.autoplace_settings.entity.settings[name])
            if family and proto.autoplace_specification and (proto.type=="unit-spawner" or proto.type=="turret") then
                properties[#properties+1]="entity:"..name..":probability"
            end
        end
        if job.planet=="vulcanus" then
            for _,property in ipairs({"demolisher_territory_radius","demolisher_territory_expression","demolisher_variation_expression"}) do
                properties[#properties+1]=property
            end
        end
        table.sort(properties)
        local positions={}
        for x=-2048,4096,64 do for y=-2048,4096,64 do positions[#positions+1]={x,y} end end
        local noise=surface.calculate_tile_properties(properties,positions)
        for _,name in ipairs(properties) do
            if not noise[name] and (case[2]==0 or case[3]==0 or case[1]=="explosive-only-off") and name:find("entity:",1,true)==1 then
                -- Native disabled controls omit the corresponding placement task.
                noise[name]={}
                for i=1,#positions do noise[name][i]=-1 end
            end
            assert(noise[name],"Missing noise "..name.." on "..job.planet.."/"..case[1])
        end
        local record={planet=job.planet,seed=job.seed,case=case[1],noise=noise,entities={},territories={}}
        -- Default, Off and high include actual native nests and territory boundaries.
        if case[1]=="default" or case[1]=="off" or case[1]=="high" then
            for _,position in ipairs({{0,0},{1024,1024},{2048,0},{0,2048}}) do
                surface.request_to_generate_chunks(position,3)
            end
            surface.force_generate_chunk_requests()
            for _,entity in pairs(surface.find_entities_filtered{type={"unit-spawner","turret"}}) do
                record.entities[#record.entities+1]=entity.name..":"..entity.position.x..":"..entity.position.y
            end
            table.sort(record.entities)
            for _,territory in pairs(surface.get_territories()) do
                local chunks,names={},{}
                for _,chunk in pairs(territory.get_chunks()) do chunks[#chunks+1]=chunk.x..":"..chunk.y end
                for _,unit in pairs(territory.get_segmented_units()) do names[#names+1]=unit.prototype.name end
                table.sort(chunks);table.sort(names)
                record.territories[#record.territories+1]={chunks=chunks,units=names}
            end
            table.sort(record.territories,function(a,b)return table.concat(a.chunks,",")<table.concat(b.chunks,",")end)
        end
        local roundtrip=helpers.parse_map_exchange_string(surface.get_map_exchange_string()).map_gen_settings
        record.roundtrip_values={original=surface.map_gen_settings.autoplace_controls,restored=roundtrip.autoplace_controls}
        record.roundtrip=true
        for name,values in pairs(surface.map_gen_settings.autoplace_controls) do
            local restored=roundtrip.autoplace_controls[name] or {}
            for _,field in ipairs({"frequency","size","richness"}) do
                if (values[field] or 1)~=(restored[field] or 1) then record.roundtrip=false end
            end
        end
        result.cases[#result.cases+1]=record
        game.delete_surface(surface)
        if index==#jobs then
            helpers.write_file("planet-enemies-generation.json",helpers.table_to_json(result),false)
            log("PLANET_ENEMY_GENERATION COMPLETE "..#jobs)
        end
    end)
end
